#!/usr/bin/env bash
# _lib.sh: shared helpers for the aws-cost-audit scripts.
# Sourced by the other scripts; not meant to be run directly.
#
# Contains NO hardcoded account id, region, ARN, resource id, or price.
# Region is resolved from (in order): --region arg handled by caller,
# $AWS_REGION, $AWS_DEFAULT_REGION, `aws configure get region`.
# If none can be found the caller is told to set one: we never assume one.

set -euo pipefail

# ---- output helpers ---------------------------------------------------------
_ts()   { date -u +%Y-%m-%dT%H:%M:%SZ; }
log()   { printf '%s\n' "$*" >&2; }
info()  { printf '[INFO] %s\n' "$*" >&2; }
warn()  { printf '[WARN] %s\n' "$*" >&2; }
err()   { printf '[ERROR] %s\n' "$*" >&2; }
die()   { err "$*"; exit 1; }

# ---- dependency checks ------------------------------------------------------
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

# Call once near the top of every script that talks to AWS.
preflight() {
  require_cmd aws
  # jq is optional but recommended; warn rather than fail.
  command -v jq >/dev/null 2>&1 || warn "jq not found, some output will be raw JSON."
}

# ---- region resolution ------------------------------------------------------
# Usage: REGION="$(resolve_region "${REGION_ARG:-}")"
# Never defaults to a specific account's region; if nothing is set, it dies
# with instructions. Prints the resolved region to stdout.
resolve_region() {
  local arg="${1:-}"
  local r=""
  if [ -n "$arg" ]; then
    r="$arg"
  elif [ -n "${AWS_REGION:-}" ]; then
    r="$AWS_REGION"
  elif [ -n "${AWS_DEFAULT_REGION:-}" ]; then
    r="$AWS_DEFAULT_REGION"
  else
    r="$(aws configure get region 2>/dev/null || true)"
  fi
  if [ -z "$r" ]; then
    die "No region set. Pass --region <region>, or export AWS_REGION, or run 'aws configure'."
  fi
  printf '%s' "$r"
}

# ---- identity ---------------------------------------------------------------
# Echo the current account id (caller may want it for output dirs / filenames).
account_id() {
  aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "unknown-account"
}

# ---- output / rollback dirs -------------------------------------------------
# Default output dir, overridable by --output / $OUT_DIR.
default_out_dir() {
  printf '%s' "${OUT_DIR:-./cost-audit-out}"
}

ensure_dir() {
  mkdir -p "$1"
}

# Write a rollback artifact. Args: <dir> <filename> ; reads JSON/text from stdin.
# Returns the full path on stdout.
save_rollback() {
  local dir="$1" name="$2"
  ensure_dir "$dir"
  local path="$dir/$name"
  cat > "$path"
  printf '%s' "$path"
}

# ---- Cost Explorer request budget -------------------------------------------
# AWS bills every Cost Explorer API request, and every page of a paginated
# result counts as its own request. The AWS CLI auto-paginates by default
# ("--no-paginate (boolean) Disable automatic pagination. If automatic
# pagination is disabled, the AWS CLI will only make one call, for the first
# page of results." -- aws ce get-cost-and-usage help), so a wrapper that
# counted CLI invocations would undercount what AWS charges for.
#
# ce_call therefore passes --no-paginate and counts exactly one request per
# call. ce_paged_call walks the pages itself so that every billed request goes
# through the same counter and the same ceiling.
#
# The ceiling is AWS_COST_AUDIT_CE_BUDGET (default 50). Reaching it stops the
# next request before it is sent; it never changes what a script asks for.
#
# Scope, stated plainly: this counts requests the scripts make. It cannot count
# an `aws ce ...` command you or an agent type directly.
CE_CALL_COUNT=0
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
CE_PRICE_DOC="${CE_PRICE_DOC:-$_LIB_DIR/../references/pricing-verification.md}"

ce_budget() { printf '%s' "${AWS_COST_AUDIT_CE_BUDGET:-50}"; }

# One Cost Explorer request. Args are passed to `aws` verbatim.
# Returns 2 without sending anything when the budget is already spent.
ce_call() {
  local budget
  budget="$(ce_budget)"
  if [ "$CE_CALL_COUNT" -ge "$budget" ]; then
    warn "Cost Explorer request budget reached ($budget requests); refusing another request."
    warn "Raise it with AWS_COST_AUDIT_CE_BUDGET=<n> if you accept the extra cost."
    return 2
  fi
  CE_CALL_COUNT=$((CE_CALL_COUNT + 1))
  aws "$@" --no-paginate
}

# Extract a NextPageToken from a Cost Explorer response file. Uses jq when it is
# there, falls back to a grep so the paging still works without jq.
ce_next_token() {
  local file="$1" tok=""
  [ -f "$file" ] || { printf ''; return 0; }
  if command -v jq >/dev/null 2>&1; then
    tok="$(jq -r '.NextPageToken // empty' "$file" 2>/dev/null || true)"
  else
    tok="$(grep -o '"NextPageToken"[[:space:]]*:[[:space:]]*"[^"]*"' "$file" 2>/dev/null \
           | head -1 | sed 's/.*:[[:space:]]*"//; s/"$//' || true)"
  fi
  printf '%s' "$tok"
}

# ce_paged_call <out-file> <aws args...>
# One Cost Explorer result set with the pages walked explicitly. Page 1 lands in
# <out-file>, later pages in <out-file>.page2, .page3 and so on. Every page is
# one counted, billed request. With jq present the pages are merged back into
# <out-file>; without jq the page files are left in place and a warning says so.
ce_paged_call() {
  local out="$1"; shift
  local page=1 tok pages="$out"
  ce_call "$@" > "$out" || return $?
  tok="$(ce_next_token "$out")"
  while [ -n "$tok" ]; do
    page=$((page + 1))
    local next="${out}.page${page}"
    if ! ce_call "$@" --next-page-token "$tok" > "$next"; then
      rm -f "$next"
      warn "Stopped paging $(basename "$out") at page $((page - 1)); the saved result is incomplete."
      return 2
    fi
    pages="$pages $next"
    tok="$(ce_next_token "$next")"
  done
  [ "$page" -eq 1 ] && return 0
  if command -v jq >/dev/null 2>&1; then
    # shellcheck disable=SC2086
    if jq -s '{
          ResultsByTime: (map(.ResultsByTime // []) | add),
          GroupDefinitions: (.[0].GroupDefinitions // []),
          DimensionValueAttributes: (map(.DimensionValueAttributes // []) | add)
        }' $pages > "${out}.merged" 2>/dev/null; then
      mv "${out}.merged" "$out"
      rm -f "${out}".page*
      info "Merged $page Cost Explorer pages into $(basename "$out")."
    else
      rm -f "${out}.merged"
      warn "Could not merge the $page pages of $(basename "$out"); the page files are kept."
    fi
  else
    warn "Install jq to merge the $page pages of $(basename "$out"); the page files are kept."
  fi
  return 0
}

# The per-request price is never written into a script. It is read from the
# reference document, which carries the figure with its AWS source URL.
ce_price_field() {
  local field="$1" line
  [ -f "$CE_PRICE_DOC" ] || { printf ''; return 0; }
  line="$(grep -o "ce-request-price:[^>]*" "$CE_PRICE_DOC" 2>/dev/null | head -1 || true)"
  [ -n "$line" ] || { printf ''; return 0; }
  printf '%s' "$line" | tr ' ' '\n' | grep "^${field}=" | head -1 | sed "s/^${field}=//"
}

# Print how many Cost Explorer requests this run made, and what that costs.
ce_report() {
  local budget usd src total
  budget="$(ce_budget)"
  info "Cost Explorer requests this run: $CE_CALL_COUNT (budget $budget)"
  usd="$(ce_price_field usd)"
  src="$(ce_price_field source)"
  if [ -z "$usd" ]; then
    info "Per-request price not found in $(basename "$CE_PRICE_DOC"); reporting the count only."
    return 0
  fi
  if command -v awk >/dev/null 2>&1; then
    total="$(awk -v n="$CE_CALL_COUNT" -v p="$usd" 'BEGIN { printf "%.2f", n * p }')"
    info "Estimated Cost Explorer API cost: $CE_CALL_COUNT requests x \$$usd = \$$total"
  else
    info "Estimated Cost Explorer API cost: $CE_CALL_COUNT requests x \$$usd per request"
  fi
  [ -n "$src" ] && info "Price source: $src (verify it live, prices change)"
  return 0
}

# ---- apply / dry-run gating -------------------------------------------------
# Parse a leading --apply anywhere; export APPLY=1 if present. Other flags are
# handled by each script's own getopts loop, so this is just a convenience for
# scripts that take no other options.
is_apply() {
  [ "${APPLY:-0}" = "1" ]
}

# Print a standard mutation banner.
mutate_banner() {
  if is_apply; then
    warn "APPLY MODE: this WILL modify your AWS account."
  else
    info "DRY-RUN (default): no changes will be made. Pass --apply to execute."
  fi
}

# Interactive confirmation for destructive ops. Honors --yes / $ASSUME_YES.
confirm() {
  local prompt="${1:-Proceed?}"
  if [ "${ASSUME_YES:-0}" = "1" ]; then
    info "Auto-confirmed (--yes): $prompt"
    return 0
  fi
  if [ ! -t 0 ]; then
    die "Refusing destructive action without a TTY and without --yes."
  fi
  read -r -p "$prompt [type 'yes' to continue]: " ans
  [ "$ans" = "yes" ] || die "Aborted by user."
}
