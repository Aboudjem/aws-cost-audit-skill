#!/usr/bin/env bash
# set-log-retention.sh — Gated put-retention-policy on CloudWatch log group(s).
#
# Default is DRY-RUN. Pass --apply to actually set retention. Before changing a
# group it saves the group's CURRENT retention to a rollback artifact so you can
# revert (reversible: re-apply the old value, or remove the policy entirely).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
. "$HERE/_lib.sh"

usage() {
  cat <<'EOF'
Usage: set-log-retention.sh --days N (--log-group NAME | --all-never-expire)
                            [--region REGION] [--output DIR] [--apply] [--yes]

Sets CloudWatch Logs retention. DRY-RUN unless --apply. Reversible.

Required:
  --days N            Retention in days. Must be a value CloudWatch accepts
                      (1,3,5,7,14,30,60,90,120,150,180,365,400,545,731,
                       1096,1827,2192,2557,2922,3288,3653).

Target (choose one):
  --log-group NAME    A single log group name.
  --all-never-expire  Apply to ALL log groups in the region that currently
                      have NO retention set (never-expire).

Options:
  --region REGION     Region (else $AWS_REGION / config).
  --output DIR        Rollback artifact dir (default ./cost-audit-out or $OUT_DIR).
  --apply             Actually set retention (omit for dry-run).
  --yes               Skip interactive confirm (for automation).
  -h, --help          Show this help

Rollback: a JSON file with each group's prior retention is written before any
change. To revert, re-run with the old --days, or delete the policy with
'aws logs delete-retention-policy --log-group-name NAME'.
EOF
}

DAYS=""
LOG_GROUP=""
ALL_NEVER=0
REGION_ARG=""
OUT_DIR="$(default_out_dir)"
APPLY=0
ASSUME_YES=0

VALID_DAYS=" 1 3 5 7 14 30 60 90 120 150 180 365 400 545 731 1096 1827 2192 2557 2922 3288 3653 "

while [ $# -gt 0 ]; do
  case "$1" in
    --days) DAYS="$2"; shift 2;;
    --log-group) LOG_GROUP="$2"; shift 2;;
    --all-never-expire) ALL_NEVER=1; shift;;
    --region) REGION_ARG="$2"; shift 2;;
    --output) OUT_DIR="$2"; shift 2;;
    --apply) APPLY=1; shift;;
    --yes) ASSUME_YES=1; shift;;
    -h|--help) usage; exit 0;;
    *) die "Unknown argument: $1 (see --help)";;
  esac
done

[ -n "$DAYS" ] || die "--days is required (see --help)"
case "$VALID_DAYS" in *" $DAYS "*) :;; *) die "--days $DAYS is not a valid CloudWatch retention value (see --help)";; esac
if [ "$ALL_NEVER" = "0" ] && [ -z "$LOG_GROUP" ]; then
  die "Specify --log-group NAME or --all-never-expire."
fi
if [ "$ALL_NEVER" = "1" ] && [ -n "$LOG_GROUP" ]; then
  die "Use either --log-group or --all-never-expire, not both."
fi

preflight
REGION="$(resolve_region "$REGION_ARG")"
ensure_dir "$OUT_DIR"
mutate_banner
info "Region: $REGION  Target days: $DAYS"

# Build the target list.
TARGETS=()
if [ "$ALL_NEVER" = "1" ]; then
  info "Finding log groups with no retention set..."
  while IFS= read -r g; do
    [ -n "$g" ] && TARGETS+=( "$g" )
  done < <(aws logs describe-log-groups --region "$REGION" \
            --query 'logGroups[?retentionInDays==`null`].logGroupName' --output text | tr '\t' '\n')
else
  TARGETS+=( "$LOG_GROUP" )
fi

[ "${#TARGETS[@]}" -gt 0 ] || { info "No matching log groups. Nothing to do."; exit 0; }
info "Will operate on ${#TARGETS[@]} log group(s)."

# Save rollback (current retention per group) BEFORE mutating.
ROLLBACK="$OUT_DIR/rollback-log-retention-$(date -u +%Y%m%dT%H%M%SZ).json"
{
  echo "{"
  echo "  \"region\": \"$REGION\","
  echo "  \"capturedAt\": \"$(_ts)\","
  echo "  \"groups\": ["
  first=1
  for g in "${TARGETS[@]}"; do
    cur="$(aws logs describe-log-groups --region "$REGION" --log-group-name-prefix "$g" \
            --query "logGroups[?logGroupName=='$g'].retentionInDays | [0]" --output text 2>/dev/null || echo "None")"
    [ "$first" = "1" ] || echo ","
    first=0
    printf '    {"logGroupName": "%s", "priorRetentionInDays": "%s"}' "$g" "$cur"
  done
  echo
  echo "  ]"
  echo "}"
} > "$ROLLBACK"
info "Rollback artifact saved: $ROLLBACK"

if [ "$APPLY" != "1" ]; then
  for g in "${TARGETS[@]}"; do
    echo "DRY-RUN would: aws logs put-retention-policy --log-group-name '$g' --retention-in-days $DAYS --region $REGION"
  done
  info "DRY-RUN complete. Re-run with --apply to set retention."
  exit 0
fi

confirm "Set retention to ${DAYS}d on ${#TARGETS[@]} log group(s) in ${REGION}?"
for g in "${TARGETS[@]}"; do
  info "Setting ${DAYS}d retention on: $g"
  aws logs put-retention-policy --log-group-name "$g" --retention-in-days "$DAYS" --region "$REGION"
done
info "DONE. Rollback data in $ROLLBACK"
