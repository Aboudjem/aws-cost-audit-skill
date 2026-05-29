#!/usr/bin/env bash
# _lib.sh — shared helpers for the aws-cost-audit scripts.
# Sourced by the other scripts; not meant to be run directly.
#
# Contains NO hardcoded account id, region, ARN, resource id, or price.
# Region is resolved from (in order): --region arg handled by caller,
# $AWS_REGION, $AWS_DEFAULT_REGION, `aws configure get region`.
# If none can be found the caller is told to set one — we never assume one.

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
  command -v jq >/dev/null 2>&1 || warn "jq not found — some output will be raw JSON."
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
