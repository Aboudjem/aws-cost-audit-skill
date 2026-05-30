#!/usr/bin/env bash
# 00-baseline.sh: Read-only Cost Explorer baseline snapshot.
#
# Pulls (all read-only, all into an output dir as JSON):
#   - total unblended cost for a period
#   - cost grouped by SERVICE
#   - cost grouped by REGION
#   - cost grouped by USAGE_TYPE
#   - a daily 90-day trend
#   - a cost forecast for the next month
#
# Cost Explorer is a global (us-east-1-only) endpoint, so the ce calls below
# pin --region us-east-1 ON PURPOSE; that is an AWS requirement, not your
# account's region. See: AWS Cost Explorer API reference (GetCostAndUsage /
# GetCostForecast operate against the us-east-1 endpoint).
#
# Enabling Cost Explorer and the cost data itself can take up to 24h after first
# enable. ce:Get* permissions are required.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
. "$HERE/_lib.sh"

usage() {
  cat <<'EOF'
Usage: 00-baseline.sh [--output DIR] [--days N] [--granularity DAILY|MONTHLY]

Read-only. Writes Cost Explorer JSON snapshots to the output dir.

Options:
  --output DIR     Output directory (default: ./cost-audit-out or $OUT_DIR)
  --days N         Trend look-back window in days (default: 90)
  --granularity G  DAILY (default) or MONTHLY for the trend/by-group pulls
  -h, --help       Show this help

Notes:
  * Cost Explorer is a global service queried via the us-east-1 endpoint.
  * This script makes NO mutations and has no --apply flag.
  * Requires Cost Explorer to be enabled and ce:Get* IAM permissions.
  * MONTHLY granularity splits the window on calendar-month boundaries, so the
    headline figure is the WINDOW TOTAL summed across buckets (printed at the
    end), not any single row.
EOF
}

OUT_DIR="$(default_out_dir)"
DAYS=90
GRAN=DAILY
while [ $# -gt 0 ]; do
  case "$1" in
    --output) OUT_DIR="$2"; shift 2;;
    --days)   DAYS="$2"; shift 2;;
    --granularity) GRAN="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) die "Unknown argument: $1 (see --help)";;
  esac
done

preflight
ensure_dir "$OUT_DIR"

# Cost Explorer endpoint is global; pin to us-east-1 as the API requires.
CE_REGION=us-east-1

# Portable UTC date math (works on both BSD/macOS and GNU/Linux date).
_date_days_ago() {
  local n="$1"
  if date -u -v-1d +%Y-%m-%d >/dev/null 2>&1; then
    date -u -v-"${n}"d +%Y-%m-%d      # BSD/macOS
  else
    date -u -d "-${n} days" +%Y-%m-%d # GNU/Linux
  fi
}
_date_plus_days() {
  local n="$1"
  if date -u -v+1d +%Y-%m-%d >/dev/null 2>&1; then
    date -u -v+"${n}"d +%Y-%m-%d
  else
    date -u -d "+${n} days" +%Y-%m-%d
  fi
}

TODAY="$(date -u +%Y-%m-%d)"
START="$(_date_days_ago "$DAYS")"
FCAST_END="$(_date_plus_days 30)"

info "Account:     $(account_id)"
info "Output dir:  $OUT_DIR"
info "Trend window: $START .. $TODAY ($DAYS days, $GRAN)"

run_ce() {
  # $1 = label/filename ; remaining args = ce subcommand + flags
  local label="$1"; shift
  local out="$OUT_DIR/baseline-${label}.json"
  info "-> $label"
  if aws "$@" --region "$CE_REGION" > "$out" 2>"$out.err"; then
    rm -f "$out.err"
    log "   saved: $out"
  else
    warn "   FAILED ($label), see $out.err (Cost Explorer may not be enabled / missing ce:Get* perms)"
  fi
}

# 1) Total unblended cost over the window
run_ce total ce get-cost-and-usage \
  --time-period Start="$START",End="$TODAY" \
  --granularity "$GRAN" \
  --metrics UnblendedCost

# 2) By SERVICE
run_ce by-service ce get-cost-and-usage \
  --time-period Start="$START",End="$TODAY" \
  --granularity "$GRAN" \
  --metrics UnblendedCost \
  --group-by Type=DIMENSION,Key=SERVICE

# 3) By REGION
run_ce by-region ce get-cost-and-usage \
  --time-period Start="$START",End="$TODAY" \
  --granularity "$GRAN" \
  --metrics UnblendedCost \
  --group-by Type=DIMENSION,Key=REGION

# 4) By USAGE_TYPE
run_ce by-usage-type ce get-cost-and-usage \
  --time-period Start="$START",End="$TODAY" \
  --granularity "$GRAN" \
  --metrics UnblendedCost \
  --group-by Type=DIMENSION,Key=USAGE_TYPE

# 5) 90d daily trend (always DAILY regardless of --granularity)
run_ce trend-daily ce get-cost-and-usage \
  --time-period Start="$START",End="$TODAY" \
  --granularity DAILY \
  --metrics UnblendedCost

# 6) Forecast next 30 days
run_ce forecast ce get-cost-forecast \
  --time-period Start="$TODAY",End="$FCAST_END" \
  --granularity MONTHLY \
  --metric UNBLENDED_COST

# Headline WINDOW TOTAL: sum across all buckets. MONTHLY granularity splits the
# window on calendar-month boundaries, so the true total for the window is the
# SUM of the ResultsByTime rows, never a single row.
if command -v jq >/dev/null 2>&1 && [ -f "$OUT_DIR/baseline-total.json" ]; then
  WINDOW_TOTAL="$(jq -r '[.ResultsByTime[].Total.UnblendedCost.Amount | tonumber] | add // 0' "$OUT_DIR/baseline-total.json" 2>/dev/null || echo "")"
  UNIT="$(jq -r '.ResultsByTime[0].Total.UnblendedCost.Unit // "USD"' "$OUT_DIR/baseline-total.json" 2>/dev/null || echo "USD")"
  if [ -n "$WINDOW_TOTAL" ]; then
    info "WINDOW TOTAL ($START .. $TODAY): $(printf '%.2f' "$WINDOW_TOTAL") $UNIT  (summed across all $GRAN buckets)"
  fi
else
  warn "Install jq to print a summed WINDOW TOTAL; otherwise sum ResultsByTime[].Total.UnblendedCost yourself ($GRAN granularity splits on calendar months)."
fi

info "Done. JSON snapshots in: $OUT_DIR"
info "Tip: pretty-print with 'jq . $OUT_DIR/baseline-by-service.json'"
