#!/usr/bin/env bash
# doctor.sh: read-only preflight check. Tells you what is missing BEFORE an audit
# starts, so you do not discover a broken environment halfway through a run.
#
# Checks, in order, printing one [OK] / [WARN] / [FAIL] line each:
#   1. aws CLI on PATH
#   2. aws sts get-caller-identity reachable   (skipped with --offline)
#   3. jq present                              (WARN only, jq is a soft dependency)
#   4. a region resolves through the usual chain
#   5. the output directory is writable
#   6. Cost Explorer is enabled                (OFF by default, see below)
#
# The Cost Explorer probe is opt-in behind --check-cost-explorer because AWS
# bills every Cost Explorer API request. See the AWS Cost Explorer pricing page:
# https://aws.amazon.com/aws-cost-management/aws-cost-explorer/pricing/
#
# NO mutations. NO --apply. Exits 0 when nothing FAILed (WARNs are tolerated),
# 1 otherwise, after printing the list of blockers and how to fix each one.
#
# Note on _lib.sh: require_cmd and resolve_region call die(), which exits on the
# spot. doctor.sh must reach the end and print every line, so it probes with its
# own non-fatal wrappers and calls resolve_region inside a guarded subshell.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
. "$HERE/_lib.sh"

usage() {
  cat <<'EOF'
Usage: doctor.sh [--offline] [--check-cost-explorer] [--output DIR]

Read-only environment check. Changes nothing, has no --apply flag.

Options:
  --offline              Skip every call that needs AWS credentials or network.
                         Also set by AWS_COST_AUDIT_DOCTOR_OFFLINE=1.
  --check-cost-explorer  Also probe whether Cost Explorer is enabled. This makes
                         one billed Cost Explorer request, which is why it is
                         off by default. Also set by AWS_COST_AUDIT_DOCTOR_CE=1.
  --output DIR           Directory to test for writability (default: $OUT_DIR or
                         ./cost-audit-out).
  -h, --help             Show this help

Exit code: 0 if there are no blockers, 1 if there is at least one.
EOF
}

OFFLINE="${AWS_COST_AUDIT_DOCTOR_OFFLINE:-0}"
CHECK_CE="${AWS_COST_AUDIT_DOCTOR_CE:-0}"
OUT_DIR_ARG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --offline) OFFLINE=1; shift;;
    --check-cost-explorer) CHECK_CE=1; shift;;
    --output) OUT_DIR_ARG="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) err "Unknown argument: $1 (see --help)"; exit 1;;
  esac
done

BLOCKERS=""
pass() { printf '[OK]   %s\n' "$*"; }
soft() { printf '[WARN] %s\n' "$*"; }
hard() {
  printf '[FAIL] %s\n' "$1"
  BLOCKERS="${BLOCKERS}  - ${1}
      fix: ${2}
"
}
skipped() { printf '[SKIP] %s\n' "$*"; }

printf 'aws-cost-audit doctor\n\n'

# ---- 1. aws CLI on PATH -----------------------------------------------------
HAVE_AWS=0
if command -v aws >/dev/null 2>&1; then
  HAVE_AWS=1
  AWS_VER="$(aws --version 2>&1 | head -1 || true)"
  pass "aws CLI found: ${AWS_VER:-unknown version}"
else
  hard "aws CLI not found on PATH" \
       "install the AWS CLI v2, https://aws.amazon.com/cli/"
fi

# ---- 2. caller identity -----------------------------------------------------
if [ "$OFFLINE" = "1" ]; then
  skipped "caller identity (--offline)"
elif [ "$HAVE_AWS" = "0" ]; then
  skipped "caller identity (no aws CLI)"
else
  ACCT="$(aws sts get-caller-identity --query Account --output text 2>/dev/null)" || ACCT=""
  if [ -n "$ACCT" ] && [ "$ACCT" != "None" ]; then
    # Print only the last 4 digits. A full account id should not end up in a
    # pasted log, an issue, or a committed file.
    pass "credentials work, account ending ...${ACCT: -4}"
  else
    hard "aws sts get-caller-identity failed" \
         "run 'aws configure', or export AWS_PROFILE, or refresh your SSO session"
  fi
fi

# ---- 3. jq (soft dependency) ------------------------------------------------
if command -v jq >/dev/null 2>&1; then
  pass "jq found: $(jq --version 2>/dev/null || echo present)"
else
  soft "jq not found. Scripts still run, output stays raw JSON, and findings-validate.sh cannot run."
fi

# ---- 4. region --------------------------------------------------------------
# resolve_region dies when nothing resolves, so guard the subshell.
REGION="$(resolve_region "" 2>/dev/null)" || REGION=""
if [ -n "$REGION" ]; then
  pass "region resolves to $REGION"
else
  hard "no region could be resolved" \
       "pass --region, or export AWS_REGION, or run 'aws configure'"
fi

# ---- 5. writable output dir -------------------------------------------------
OUT_TARGET="${OUT_DIR_ARG:-$(default_out_dir)}"
WROTE=0
if mkdir -p "$OUT_TARGET" 2>/dev/null; then
  PROBE="$OUT_TARGET/.doctor-write-probe.$$"
  if : > "$PROBE" 2>/dev/null; then
    rm -f "$PROBE"
    WROTE=1
  fi
fi
if [ "$WROTE" = "1" ]; then
  pass "output directory writable: $OUT_TARGET"
else
  hard "output directory not writable: $OUT_TARGET" \
       "pick another with --output DIR or \$OUT_DIR, or fix the permissions"
fi

# ---- 6. Cost Explorer enabled (opt-in, billed) ------------------------------
if [ "$CHECK_CE" != "1" ]; then
  skipped "Cost Explorer probe (opt in with --check-cost-explorer; the request is billed)"
elif [ "$OFFLINE" = "1" ]; then
  skipped "Cost Explorer probe (--offline)"
elif [ "$HAVE_AWS" = "0" ]; then
  skipped "Cost Explorer probe (no aws CLI)"
else
  # Cost Explorer is a global service reached through the us-east-1 endpoint.
  # ce_call adds --no-paginate and counts the request, so this is exactly one.
  CE_END="$(date -u +%Y-%m-%d)"
  if date -u -v-1d +%Y-%m-%d >/dev/null 2>&1; then
    CE_START="$(date -u -v-1d +%Y-%m-%d)"
  else
    CE_START="$(date -u -d '-1 day' +%Y-%m-%d)"
  fi
  if ce_call ce get-cost-and-usage \
       --time-period Start="$CE_START",End="$CE_END" \
       --granularity DAILY --metrics UnblendedCost \
       --region us-east-1 >/dev/null 2>&1; then
    pass "Cost Explorer answered (1 billed request made)"
  else
    hard "Cost Explorer did not answer" \
         "enable Cost Explorer in the billing console (data can take up to 24h) and grant ce:Get*"
  fi
fi

# ---- summary ----------------------------------------------------------------
printf '\n'
if [ -z "$BLOCKERS" ]; then
  printf 'No blockers. This environment can run an audit.\n'
  exit 0
fi
printf 'Blockers:\n%s' "$BLOCKERS"
exit 1
