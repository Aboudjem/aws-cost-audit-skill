#!/usr/bin/env bash
# tests/smoke.sh: offline smoke test for the aws-cost-audit scripts.
#
# Tests the pure-bash helper functions in skills/aws-cost-audit/scripts/_lib.sh
# WITHOUT making any AWS API calls. No credentials are required.
#
# Usage:
#   bash tests/smoke.sh
#
# Exit code: 0 = all tests passed, non-zero = at least one failure.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$HERE/../skills/aws-cost-audit/scripts/_lib.sh"

PASS=0
FAIL=0

# ---- mini test harness -------------------------------------------------------
ok() {
  local desc="$1"
  PASS=$((PASS + 1))
  printf '[PASS] %s\n' "$desc"
}

fail() {
  local desc="$1" got="${2:-}" expected="${3:-}"
  FAIL=$((FAIL + 1))
  printf '[FAIL] %s\n' "$desc"
  [ -n "$got" ]      && printf '       got:      %s\n' "$got"
  [ -n "$expected" ] && printf '       expected: %s\n' "$expected"
}

assert_eq() {
  local desc="$1" got="$2" expected="$3"
  if [ "$got" = "$expected" ]; then
    ok "$desc"
  else
    fail "$desc" "$got" "$expected"
  fi
}

assert_contains() {
  local desc="$1" haystack="$2" needle="$3"
  # -e so a needle that starts with "-" is not read as a grep option.
  if printf '%s' "$haystack" | grep -qF -e "$needle"; then
    ok "$desc"
  else
    fail "$desc" "(did not contain '$needle')" "$needle"
  fi
}

# ---- load _lib.sh in a sub-shell (set -e is active there) -------------------
# We source it inside a function so 'die' can be tested without killing the
# test runner.
_source_lib() {
  # Override 'die' so we can test it without exit 1 killing the runner.
  # The override must come AFTER sourcing because _lib.sh defines die().
  # shellcheck source=../skills/aws-cost-audit/scripts/_lib.sh
  . "$LIB"
  die() { printf '[ERROR] %s\n' "$*" >&2; return 1; }
}

# ---- tests -------------------------------------------------------------------

# 1. resolve_region: --region arg takes priority
T1=$(
  _source_lib
  RESULT="$(resolve_region "eu-west-1")"
  printf '%s' "$RESULT"
)
assert_eq "resolve_region: explicit arg overrides env" "$T1" "eu-west-1"

# 2. resolve_region: AWS_REGION env var used when no arg
T2=$(
  _source_lib
  AWS_REGION="us-west-2" AWS_DEFAULT_REGION="" RESULT="$(resolve_region "")"
  printf '%s' "$RESULT"
)
assert_eq "resolve_region: AWS_REGION env picked up" "$T2" "us-west-2"

# 3. resolve_region: AWS_DEFAULT_REGION fallback
T3=$(
  _source_lib
  AWS_REGION="" AWS_DEFAULT_REGION="ap-southeast-1" RESULT="$(resolve_region "")"
  printf '%s' "$RESULT"
)
assert_eq "resolve_region: AWS_DEFAULT_REGION fallback" "$T3" "ap-southeast-1"

# 4. default_out_dir: respects OUT_DIR override
T4=$(
  _source_lib
  OUT_DIR="/tmp/test-audit-out" RESULT="$(default_out_dir)"
  printf '%s' "$RESULT"
)
assert_eq "default_out_dir: respects OUT_DIR env" "$T4" "/tmp/test-audit-out"

# 5. default_out_dir: falls back to ./cost-audit-out
T5=$(
  _source_lib
  unset OUT_DIR 2>/dev/null || true
  RESULT="$(default_out_dir)"
  printf '%s' "$RESULT"
)
assert_eq "default_out_dir: default value" "$T5" "./cost-audit-out"

# 6. ensure_dir: creates a directory
TMPDIR_TEST="$(mktemp -d)"
T6_DIR="$TMPDIR_TEST/nested/audit"
(
  _source_lib
  ensure_dir "$T6_DIR"
)
if [ -d "$T6_DIR" ]; then
  ok "ensure_dir: creates nested directory"
else
  fail "ensure_dir: directory not created" "not found" "$T6_DIR"
fi
rm -rf "$TMPDIR_TEST"

# 7. log: writes to stderr (not stdout)
T7_OUT=$(
  _source_lib
  log "hello from log" 2>&1 1>/dev/null
)
assert_contains "log: output goes to stderr" "$T7_OUT" "hello from log"

# 8. info: prefixes [INFO]
T8_OUT=$(
  _source_lib
  info "check prefix" 2>&1
)
assert_contains "info: [INFO] prefix present" "$T8_OUT" "[INFO]"

# 9. warn: prefixes [WARN]
T9_OUT=$(
  _source_lib
  warn "check warn" 2>&1
)
assert_contains "warn: [WARN] prefix present" "$T9_OUT" "[WARN]"

# 10. die: prefixes [ERROR] and returns non-zero
T10_RC=0
T10_OUT=$(
  _source_lib
  die "fatal thing" 2>&1
) || T10_RC=$?
assert_contains "die: [ERROR] prefix present" "$T10_OUT" "[ERROR]"
if [ "$T10_RC" -ne 0 ]; then
  ok "die: returns non-zero exit code"
else
  fail "die: should return non-zero" "$T10_RC" "non-zero"
fi

# ---- doctor.sh --------------------------------------------------------------
# doctor.sh is exercised for real, but only offline: --offline skips every call
# that needs credentials, and the Cost Explorer probe is opt-in, so nothing here
# reaches AWS. PATH is replaced with a stub directory holding a fake `aws` plus
# symlinks to the handful of real binaries the script needs, which makes "jq is
# absent" deterministic instead of depending on the machine.
DOCTOR="$HERE/../skills/aws-cost-audit/scripts/doctor.sh"
BASH_BIN="$(command -v bash)"

# make_stub_path <dir> <region-for-aws-configure>
# Builds a stub PATH in <dir> and echoes it. The fake `aws` answers --version
# and `configure get region`; everything else returns empty with status 1.
make_stub_path() {
  local dir="$1" region="${2:-}" real b
  mkdir -p "$dir"
  for b in bash env dirname date head mkdir rm rmdir; do
    real="$(command -v "$b" 2>/dev/null || true)"
    [ -n "$real" ] && ln -sf "$real" "$dir/$b"
  done
  cat > "$dir/aws" <<STUB
#!/usr/bin/env bash
if [ "\$1" = "--version" ]; then
  echo "aws-cli/0.0.0-stub"
  exit 0
fi
if [ "\$1" = "configure" ] && [ "\$2" = "get" ] && [ "\$3" = "region" ]; then
  [ -n "$region" ] && echo "$region"
  exit 0
fi
exit 1
STUB
  chmod +x "$dir/aws"
  printf '%s' "$dir"
}

# 12. doctor.sh: healthy offline environment exits 0
D12="$(mktemp -d)"
D12_RC=0
D12_OUT=$(
  PATH="$(make_stub_path "$D12/bin" "")" \
  AWS_REGION="eu-west-1" AWS_DEFAULT_REGION="" OUT_DIR="$D12/out" \
  "$BASH_BIN" "$DOCTOR" --offline 2>&1
) || D12_RC=$?
if [ "$D12_RC" -eq 0 ]; then
  ok "doctor.sh: healthy offline environment exits 0"
else
  fail "doctor.sh: healthy offline environment should exit 0" "$D12_RC" "0"
fi
assert_contains "doctor.sh: reports the resolved region" "$D12_OUT" "region resolves to eu-west-1"
assert_contains "doctor.sh: reports no blockers when healthy" "$D12_OUT" "No blockers"

# 13. doctor.sh: jq absent is a WARN, not a blocker
assert_contains "doctor.sh: missing jq warns" "$D12_OUT" "[WARN] jq not found"

# 14. doctor.sh: the billed Cost Explorer probe is off by default
assert_contains "doctor.sh: Cost Explorer probe is opt-in" "$D12_OUT" "[SKIP] Cost Explorer probe"

# 15. doctor.sh: the credentials check is genuinely skipped offline
assert_contains "doctor.sh: --offline skips the identity call" "$D12_OUT" "[SKIP] caller identity"
rm -rf "$D12"

# 16. doctor.sh: no resolvable region is a blocker and exits 1
D16="$(mktemp -d)"
D16_RC=0
D16_OUT=$(
  PATH="$(make_stub_path "$D16/bin" "")" \
  AWS_REGION="" AWS_DEFAULT_REGION="" OUT_DIR="$D16/out" \
  "$BASH_BIN" "$DOCTOR" --offline 2>&1
) || D16_RC=$?
if [ "$D16_RC" -eq 1 ]; then
  ok "doctor.sh: unresolvable region exits 1"
else
  fail "doctor.sh: unresolvable region should exit 1" "$D16_RC" "1"
fi
assert_contains "doctor.sh: names the region blocker" "$D16_OUT" "[FAIL] no region could be resolved"
assert_contains "doctor.sh: prints a Blockers list" "$D16_OUT" "Blockers:"
rm -rf "$D16"

# 17. doctor.sh: a region from `aws configure get region` is picked up
D17="$(mktemp -d)"
D17_RC=0
D17_OUT=$(
  PATH="$(make_stub_path "$D17/bin" "ap-south-1")" \
  AWS_REGION="" AWS_DEFAULT_REGION="" OUT_DIR="$D17/out" \
  "$BASH_BIN" "$DOCTOR" --offline 2>&1
) || D17_RC=$?
assert_eq "doctor.sh: configured region resolves, exit 0" "$D17_RC" "0"
assert_contains "doctor.sh: uses aws configure get region" "$D17_OUT" "region resolves to ap-south-1"
rm -rf "$D17"

# 18a. doctor.sh: --region is a real flag, so the blocker's advice can be followed.
D18="$(mktemp -d)"
D18_RC=0
D18_OUT=$(
  PATH="$(make_stub_path "$D18/bin" "")" \
  AWS_REGION="" AWS_DEFAULT_REGION="" OUT_DIR="$D18/out" \
  "$BASH_BIN" "$DOCTOR" --offline --region eu-central-1 2>&1
) || D18_RC=$?
assert_eq "doctor.sh: --region is accepted, exit 0" "$D18_RC" "0"
assert_contains "doctor.sh: --region wins over the empty environment" \
  "$D18_OUT" "region resolves to eu-central-1"
rm -rf "$D18"

# 18b. doctor.sh: a missing aws CLI is a named blocker, not a crash.
D18B="$(mktemp -d)"
mkdir -p "$D18B/bin"
for b in bash env dirname date head mkdir rm rmdir; do
  real="$(command -v "$b" 2>/dev/null || true)"
  [ -n "$real" ] && ln -sf "$real" "$D18B/bin/$b"
done
D18B_RC=0
D18B_OUT=$(
  PATH="$D18B/bin" AWS_REGION="eu-west-1" OUT_DIR="$D18B/out" \
  "$BASH_BIN" "$DOCTOR" --offline 2>&1
) || D18B_RC=$?
assert_eq "doctor.sh: a missing aws CLI exits 1" "$D18B_RC" "1"
assert_contains "doctor.sh: names the missing aws CLI as the blocker" \
  "$D18B_OUT" "[FAIL] aws CLI not found on PATH"
rm -rf "$D18B"

# 18c. doctor.sh: an unwritable output directory is a blocker.
D18C="$(mktemp -d)"
mkdir -p "$D18C/locked"
chmod 500 "$D18C/locked"
D18C_RC=0
D18C_OUT=$(
  PATH="$(make_stub_path "$D18C/bin" "")" \
  AWS_REGION="eu-west-1" \
  "$BASH_BIN" "$DOCTOR" --offline --output "$D18C/locked/out" 2>&1
) || D18C_RC=$?
assert_eq "doctor.sh: an unwritable output directory exits 1" "$D18C_RC" "1"
assert_contains "doctor.sh: names the output directory blocker" \
  "$D18C_OUT" "[FAIL] output directory not writable"
chmod 700 "$D18C/locked"
rm -rf "$D18C"

# 18d. doctor.sh: it reports on the environment, it does not furnish it.
D18D="$(mktemp -d)"
D18D_TARGET="$D18D/created-by-doctor"
(
  PATH="$(make_stub_path "$D18D/bin" "")" \
  AWS_REGION="eu-west-1" \
  "$BASH_BIN" "$DOCTOR" --offline --output "$D18D_TARGET" >/dev/null 2>&1
)
if [ -d "$D18D_TARGET" ]; then
  fail "doctor.sh: should not leave an output directory behind" "$D18D_TARGET exists" "removed"
else
  ok "doctor.sh: leaves no output directory behind"
fi
rm -rf "$D18D"

# ---- ce_call: Cost Explorer request budget ----------------------------------
# Offline. A fake `aws` records every invocation to a log file and prints a
# Cost Explorer shaped response, so the tests can prove both the counting and
# the refusal without ever reaching AWS.

# make_ce_stub <dir> <calls-log> [paging]
# With paging=1 the first response carries a NextPageToken so ce_paged_call has
# a second page to fetch.
make_ce_stub() {
  local dir="$1" calls="$2" paging="${3:-0}"
  mkdir -p "$dir"
  cat > "$dir/aws" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$calls"
if [ "$paging" = "1" ] && ! printf '%s' "\$*" | grep -q -- '--next-page-token'; then
  printf '{"ResultsByTime":[{"page":1}],"NextPageToken":"tok-2"}\n'
else
  printf '{"ResultsByTime":[{"page":2}]}\n'
fi
exit 0
STUB
  chmod +x "$dir/aws"
}

# 18-21. ce_call counts, passes --no-paginate, and stops at the budget.
CE1="$(mktemp -d)"
CE1_CALLS="$CE1/calls.log"
make_ce_stub "$CE1/bin" "$CE1_CALLS" 0
CE1_OUT=$(
  _source_lib
  PATH="$CE1/bin:$PATH"
  export AWS_COST_AUDIT_CE_BUDGET=2
  rc1=0; ce_call ce get-cost-and-usage >/dev/null 2>&1 || rc1=$?
  rc2=0; ce_call ce get-cost-and-usage >/dev/null 2>&1 || rc2=$?
  rc3=0; ce_call ce get-cost-and-usage >/dev/null 2>&1 || rc3=$?
  printf 'count=%s rc1=%s rc2=%s rc3=%s' "$CE_CALL_COUNT" "$rc1" "$rc2" "$rc3"
)
assert_eq "ce_call: counts each request and refuses the one over budget" \
  "$CE1_OUT" "count=2 rc1=0 rc2=0 rc3=2"
assert_eq "ce_call: the over-budget request never reaches aws" \
  "$(wc -l < "$CE1_CALLS" | tr -d ' ')" "2"
assert_contains "ce_call: passes --no-paginate so one call is one billed request" \
  "$(cat "$CE1_CALLS")" "--no-paginate"
rm -rf "$CE1"

# 22-24. ce_report prints the count and the price read from the reference doc.
CE2="$(mktemp -d)"
make_ce_stub "$CE2/bin" "$CE2/calls.log" 0
CE2_OUT=$(
  _source_lib
  PATH="$CE2/bin:$PATH"
  export AWS_COST_AUDIT_CE_BUDGET=50
  ce_call ce get-cost-and-usage >/dev/null 2>&1
  ce_call ce get-cost-and-usage >/dev/null 2>&1
  ce_report 2>&1
)
assert_contains "ce_report: prints the request count and the budget" \
  "$CE2_OUT" "Cost Explorer requests this run: 2 (budget 50)"
assert_contains "ce_report: prices the run from the reference doc, not from the script" \
  "$CE2_OUT" "2 requests x"
assert_contains "ce_report: names the price source" "$CE2_OUT" "Price source: https://"
rm -rf "$CE2"

# 25-26. The price figure lives in the reference doc, never in a script.
CE3_MARKER="$(grep -c 'ce-request-price:' "$HERE/../skills/aws-cost-audit/references/pricing-verification.md" || true)"
assert_eq "ce price marker present in references/pricing-verification.md" "$CE3_MARKER" "1"
CE3_HITS="$( { grep -rlE '(usd|USD)[= ]*[0-9]+\.[0-9]+' "$HERE/../skills/aws-cost-audit/scripts/" 2>/dev/null || true; } | wc -l | tr -d ' ')"
assert_eq "no per-request price literal in any script" "$CE3_HITS" "0"

# 27-28. ce_paged_call walks pages explicitly and counts every page.
CE4="$(mktemp -d)"
CE4_CALLS="$CE4/calls.log"
make_ce_stub "$CE4/bin" "$CE4_CALLS" 1
CE4_OUT=$(
  _source_lib
  PATH="$CE4/bin:$PATH"
  export AWS_COST_AUDIT_CE_BUDGET=50
  ce_paged_call "$CE4/out.json" ce get-cost-and-usage >/dev/null 2>&1
  printf '%s' "$CE_CALL_COUNT"
)
assert_eq "ce_paged_call: a two-page result counts as two billed requests" "$CE4_OUT" "2"
assert_contains "ce_paged_call: fetches page two with --next-page-token" \
  "$(cat "$CE4_CALLS")" "--next-page-token tok-2"
rm -rf "$CE4"

# 29b. A malformed budget must not switch the ceiling off.
CE5="$(mktemp -d)"
CE5_CALLS="$CE5/calls.log"
make_ce_stub "$CE5/bin" "$CE5_CALLS" 0
CE5_OUT=$(
  _source_lib
  PATH="$CE5/bin:$PATH"
  export AWS_COST_AUDIT_CE_BUDGET="not-a-number"
  printf 'budget=%s' "$(ce_budget 2>/dev/null)"
)
assert_eq "ce_budget: a malformed budget falls back to the default, it does not disable the cap" \
  "$CE5_OUT" "budget=50"
CE5_WARN=$(
  _source_lib
  PATH="$CE5/bin:$PATH"
  export AWS_COST_AUDIT_CE_BUDGET="-5"
  ce_budget 2>&1 >/dev/null
)
assert_contains "ce_budget: says out loud that it ignored a bad budget" \
  "$CE5_WARN" "not a non-negative whole number"
rm -rf "$CE5"

# 29c. ce_report still runs when a script exits early, via the EXIT trap.
CE6="$(mktemp -d)"
make_ce_stub "$CE6/bin" "$CE6/calls.log" 0
cat > "$CE6/early-exit.sh" <<EOS
set -euo pipefail
. "$LIB"
trap 'ce_report' EXIT
ce_call ce get-cost-and-usage >/dev/null 2>&1
exit 3
EOS
CE6_RC=0
CE6_OUT=$(
  PATH="$CE6/bin:$PATH" "$BASH_BIN" "$CE6/early-exit.sh" 2>&1
) || CE6_RC=$?
assert_eq "ce_report trap: the early exit code survives" "$CE6_RC" "3"
assert_contains "ce_report trap: the spend is reported even on an early exit" \
  "$CE6_OUT" "Cost Explorer requests this run: 1"
rm -rf "$CE6"

# 29d. 00-baseline.sh end to end against a stubbed aws: every pull is counted
# and the run reports its Cost Explorer spend.
BL="$(mktemp -d)"
mkdir -p "$BL/bin"
cat > "$BL/bin/aws" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$BL_CALLS"
if printf '%s' "$*" | grep -q 'sts get-caller-identity'; then
  printf 'acct-stub\n'
  exit 0
fi
printf '{"ResultsByTime":[{"Total":{"UnblendedCost":{"Amount":"12.50","Unit":"USD"}}}]}\n'
exit 0
STUB
chmod +x "$BL/bin/aws"
BL_RC=0
BL_OUT=$(
  BL_CALLS="$BL/calls.log" PATH="$BL/bin:$PATH" \
  "$BASH_BIN" "$HERE/../skills/aws-cost-audit/scripts/00-baseline.sh" --output "$BL/out" 2>&1
) || BL_RC=$?
assert_eq "00-baseline.sh: runs to completion against a stubbed aws" "$BL_RC" "0"
assert_contains "00-baseline.sh: reports its Cost Explorer spend" \
  "$BL_OUT" "Cost Explorer requests this run: 6"
assert_contains "00-baseline.sh: every Cost Explorer call carries --no-paginate" \
  "$(grep -c -- '--no-paginate' "$BL/calls.log" | tr -d ' ')" "6"
rm -rf "$BL"

# ---- findings-validate.sh ---------------------------------------------------
# Offline. Runs the validator over a good fixture and a deliberately broken one.
VALIDATE="$HERE/../skills/aws-cost-audit/scripts/findings-validate.sh"
FIX_GOOD="$HERE/fixtures/findings-good.json"
FIX_BAD="$HERE/fixtures/findings-bad.json"

# 29. A file that cannot be checked is never reported valid.
FV0="$(mktemp -d)"
FV0_RC=0
FV0_OUT=$(
  PATH="$(make_stub_path "$FV0/bin" "")" \
  "$BASH_BIN" "$VALIDATE" "$FIX_GOOD" 2>&1
) || FV0_RC=$?
assert_eq "findings-validate: exits 2 when jq is missing, never 0" "$FV0_RC" "2"
assert_contains "findings-validate: says why it could not check" "$FV0_OUT" "jq is not installed"
FV0S_RC=0
FV0S_OUT=$(
  PATH="$(make_stub_path "$FV0/bin2" "")" \
  "$BASH_BIN" "$HERE/../skills/aws-cost-audit/scripts/findings-summary.sh" "$FIX_GOOD" 2>/dev/null
) || FV0S_RC=$?
assert_eq "findings-summary: exits 2 when jq is missing, never 0" "$FV0S_RC" "2"
assert_eq "findings-summary: prints no summary when it could not check" "$FV0S_OUT" ""
rm -rf "$FV0"

if command -v jq >/dev/null 2>&1; then
  # 30. The good fixture satisfies the contract.
  FV1_RC=0
  FV1_OUT=$(bash "$VALIDATE" "$FIX_GOOD" 2>&1) || FV1_RC=$?
  assert_eq "findings-validate: good fixture exits 0" "$FV1_RC" "0"
  assert_contains "findings-validate: counts the findings" "$FV1_OUT" "3 finding(s)"

  # 31. The bad fixture fails, and every planted problem is named.
  FV2_RC=0
  FV2_OUT=$(bash "$VALIDATE" "$FIX_BAD" 2>&1) || FV2_RC=$?
  assert_eq "findings-validate: bad fixture exits 1" "$FV2_RC" "1"
  assert_contains "findings-validate: catches the missing required key" \
    "$FV2_OUT" "findings[0].evidence is required but missing"
  assert_contains "findings-validate: catches the value outside the enum" \
    "$FV2_OUT" "confidence must be one of High, Medium, Low"
  assert_contains "findings-validate: catches the duplicate id" \
    "$FV2_OUT" "duplicate id: duplicated-example"
  assert_contains "findings-validate: catches a key that is not in the contract" \
    "$FV2_OUT" "estimated_savings_percent is not a key in the contract"
  assert_contains "findings-validate: catches the wrong type for a cost" \
    "$FV2_OUT" "monthly_cost_estimate must be a number or null"
  assert_contains "findings-validate: catches the wrong type for reversible" \
    "$FV2_OUT" "reversible must be true or false"

  # 32. An unknown top-level key is caught, and top-level problems are not
  # reported one at a time.
  FV3="$(mktemp -d)"
  printf '{"schema_version":1,"findings":[],"extra":true}' > "$FV3/tl.json"
  FV3_RC=0
  FV3_OUT=$(bash "$VALIDATE" "$FV3/tl.json" 2>&1) || FV3_RC=$?
  assert_eq "findings-validate: a bad top level exits 1" "$FV3_RC" "1"
  assert_contains "findings-validate: catches an unknown top-level key" \
    "$FV3_OUT" "top-level key extra is not in the contract"
  assert_contains "findings-validate: reports every top-level problem, not just the first" \
    "$FV3_OUT" "schema_version must be a string"
  rm -rf "$FV3"

  # A price-list record, as verify-price.sh --record prints it. The unit price
  # is computed at run time, so no price is committed to this file.
  PL_PRICE="0.0$(( (RANDOM % 89) + 10 ))"
  PL_REC='{"method": "price-list", "service_code": "AmazonEC2", "region_code": "us-east-1",
    "filters": ["productFamily=Storage", "volumeApiName=gp3"], "sku": "SKUEXAMPLE",
    "unit": "GB-Mo", "price_per_unit_usd": '"$PL_PRICE"', "fetched_at": "2026-11-17T09:00:00Z"}'

  # 33. A numeric cost is accepted. The number is computed at run time and the
  # file is temporary, because CONTRIBUTING.md forbids writing a monthly cost
  # figure into any committed script, reference, example or fixture.
  FV4="$(mktemp -d)"
  FV4_N=$(( (RANDOM % 900) + 100 ))
  cat > "$FV4/numeric.json" <<JSON
{
  "schema_version": "1.0",
  "findings": [
    {
      "id": "numeric-type-case",
      "resource": "vol-EXAMPLE",
      "region": "<region>",
      "service": "Amazon EC2",
      "monthly_cost_estimate": $FV4_N,
      "evidence": "aws ec2 describe-volumes --region <region>",
      "price_lookups": [$PL_REC],
      "action": "OPTIMIZE",
      "reversible": true,
      "confidence": "Low"
    }
  ]
}
JSON
  FV4_RC=0
  FV4_OUT=$(bash "$VALIDATE" "$FV4/numeric.json" 2>&1) || FV4_RC=$?
  assert_eq "findings-validate: accepts a numeric cost as well as null" "$FV4_RC" "0"
  assert_contains "findings-validate: counts the numeric-case finding" "$FV4_OUT" "1 finding(s)"

  # 33b. The price rule. A dollar figure without a lookup record is rejected,
  # and the message names the command that makes one.
  pv_case() { # pv_case <file> <price_lookups JSON, or "" for none> [region]
    local lookups="" region="${3:-us-east-1}"
    [ -n "$2" ] && lookups="\"price_lookups\": $2,"
    cat > "$1" <<JSON
{"schema_version": "1.1", "findings": [
  {"id": "priced", "resource": "vol-EXAMPLE", "region": "$region", "service": "Amazon EBS",
   "monthly_cost_estimate": $FV4_N, "evidence": "aws ec2 describe-volumes", $lookups
   "action": "OPTIMIZE", "reversible": true, "confidence": "High"}]}
JSON
  }
  pv_run() { PV_RC=0; PV_OUT=$(bash "$VALIDATE" "$1" 2>&1) || PV_RC=$?; }

  pv_case "$FV4/none.json" ""
  pv_run "$FV4/none.json"
  assert_eq "price rule: a dollar figure with no price_lookups exits 1" "$PV_RC" "1"
  assert_contains "price rule: the rejection names the finding and the missing record" \
    "$PV_OUT" "[FAIL] findings[0] has a dollar figure but no price_lookups."
  assert_contains "price rule: the rejection names the command to run" \
    "$PV_OUT" "Run verify-price.sh --record and add its output"

  FV4_SRC_N=$FV4_N; FV4_N=null
  pv_case "$FV4/null.json" ""
  pv_run "$FV4/null.json"
  assert_eq "price rule: a finding with no dollar figure needs no record" "$PV_RC" "0"
  FV4_N=$FV4_SRC_N

  pv_case "$FV4/pl.json" "[$PL_REC]"
  pv_run "$FV4/pl.json"
  assert_eq "price rule: accepted with a price-list record" "$PV_RC" "0"

  pv_case "$FV4/ce.json" '[{"method": "cost-explorer",
    "command": "aws ce get-cost-and-usage-with-resources --group-by Type=DIMENSION,Key=RESOURCE_ID",
    "reason": "deleted outright, so the saving is its whole billed cost",
    "fetched_at": "2026-11-17T09:00:00Z"}]'
  pv_run "$FV4/ce.json"
  assert_eq "price rule: the labelled cost-explorer escape is accepted" "$PV_RC" "0"

  pv_case "$FV4/ce-bad.json" '[{"method": "cost-explorer", "command": "from memory",
    "fetched_at": "yesterday"}]'
  pv_run "$FV4/ce-bad.json"
  assert_eq "price rule: an escape with no source command or reason exits 1" "$PV_RC" "1"
  assert_contains "price rule: the escape must name the aws ce command it read" \
    "$PV_OUT" "command must be the aws ce command that was read"
  assert_contains "price rule: the escape must say why no unit price applies" \
    "$PV_OUT" "reason is required in a cost-explorer record but missing"
  assert_contains "price rule: the escape must carry a UTC fetch time" \
    "$PV_OUT" "fetched_at must be a UTC time"

  pv_case "$FV4/pl-bad.json" '[{"method": "price-list", "service_code": "AmazonEC2",
    "region_code": "us-east-1", "filters": [], "unit": "GB-Mo",
    "price_per_unit_usd": "cheap", "fetched_at": "2026-11-17T09:00:00Z"}]'
  pv_run "$FV4/pl-bad.json"
  assert_eq "price rule: an incomplete price-list record exits 1" "$PV_RC" "1"
  assert_contains "price rule: a price-list record needs the SKU" \
    "$PV_OUT" "sku is required in a price-list record but missing"
  assert_contains "price rule: a price-list record needs its filters" \
    "$PV_OUT" "filters must be a non-empty array of FIELD=VALUE strings"
  assert_contains "price rule: the unit price must be a number" \
    "$PV_OUT" "price_per_unit_usd must be a number"

  pv_case "$FV4/str.json" '"aws pricing get-products, trust me"'
  pv_run "$FV4/str.json"
  assert_eq "price rule: a free-text price source is not a record" "$PV_RC" "1"

  pv_case "$FV4/other.json" '[{"method": "memory"}]'
  pv_run "$FV4/other.json"
  assert_contains "price rule: only the two methods exist" \
    "$PV_OUT" "method must be price-list or cost-explorer"

  pv_case "$FV4/region.json" "[$PL_REC]" "eu-west-1"
  pv_run "$FV4/region.json"
  assert_eq "price rule: a price from another region exits 1" "$PV_RC" "1"
  assert_contains "price rule: and says to price the resource's own region" \
    "$PV_OUT" "region_code is us-east-1 but the finding is in eu-west-1"

  # 33c. region_code must BE a region code, whatever the finding says.
  pl_with() { # pl_with <region_code> <fetched_at>: PL_REC with two fields swapped
    printf '%s' "$PL_REC" | jq -c --arg rc "$1" --arg ts "$2" '.region_code = $rc | .fetched_at = $ts'
  }
  for bad_rc in anywhere EU-WEST-1 eu-west-1a; do
    pv_case "$FV4/rc.json" "[$(pl_with "$bad_rc" 2026-11-17T09:00:00Z)]" "eu-west-1"
    pv_run "$FV4/rc.json"
    assert_eq "price rule: region_code \"$bad_rc\" exits 1" "$PV_RC" "1"
    assert_contains "price rule: and says region_code must be a region code ($bad_rc)" \
      "$PV_OUT" "region_code must be an AWS region code such as us-east-1"
  done
  pv_case "$FV4/rc.json" "[$(pl_with anywhere 2026-11-17T09:00:00Z)]" "global"
  pv_run "$FV4/rc.json"
  assert_eq "price rule: a non-region region_code is rejected even when the finding has no region code" "$PV_RC" "1"
  pv_case "$FV4/rc.json" "[$(pl_with us-east-1 2026-11-17T09:00:00Z)]" "global"
  pv_run "$FV4/rc.json"
  assert_eq "price rule: a global finding priced in us-east-1 is accepted" "$PV_RC" "0"
  pv_case "$FV4/rc.json" "[$(pl_with us-west-2-lax-1 2026-11-17T09:00:00Z)]" "us-west-2"
  pv_run "$FV4/rc.json"
  assert_eq "price rule: a Local Zone price for a resource in its parent region is accepted" "$PV_RC" "0"
  pv_case "$FV4/rc.json" "[$(pl_with us-west-2-lax-1 2026-11-17T09:00:00Z)]" "us-east-1"
  pv_run "$FV4/rc.json"
  assert_contains "price rule: a Local Zone of another region is a region mismatch" \
    "$PV_OUT" "region_code is us-west-2-lax-1 but the finding is in us-east-1"

  # 33d. fetched_at must be a time that exists, not only the right shape.
  for bad_ts in 2099-99-99T99:99:99Z 2026-13-01T00:00:00Z 2026-01-32T00:00:00Z \
                2026-01-01T25:00:00Z 2026-02-30T00:00:00Z; do
    pv_case "$FV4/ts.json" "[$(pl_with us-east-1 "$bad_ts")]"
    pv_run "$FV4/ts.json"
    assert_eq "price rule: fetched_at $bad_ts exits 1" "$PV_RC" "1"
    assert_contains "price rule: and names the impossible time ($bad_ts)" \
      "$PV_OUT" "fetched_at must be a UTC time like 2026-01-31T09:30:00Z that exists on the calendar, got \"$bad_ts\""
  done
  pv_case "$FV4/ts.json" "[$(pl_with us-east-1 2024-02-29T23:59:59Z)]"
  pv_run "$FV4/ts.json"
  assert_eq "price rule: a leap day is a real fetched_at" "$PV_RC" "0"
  rm -rf "$FV4"
  # ---- findings-summary.sh --------------------------------------------------
  # The report order is fixed: verdict, then the three things to do, then the
  # detail. These cases pin that order and the arithmetic behind the verdict.
  SUMMARY="$HERE/../skills/aws-cost-audit/scripts/findings-summary.sh"
  ROOT="$HERE/.."
  # Whole dollars with thousands separators, the way the summary prints them.
  usd() {
    local n="$1" out=""
    while [ "${#n}" -gt 3 ]; do out=",${n: -3}$out"; n="${n:0:${#n}-3}"; done
    printf '$%s' "$n$out"
  }

  # 34. Totals. Every number is computed at run time, so no cost figure is
  # committed here. A is a stated saving, B is cost minus after, C is the cost
  # of a SAFE-TO-DELETE finding that needs a sign-off, D has no verified cost.
  FS1="$(mktemp -d)"
  FS_A=$(( (RANDOM % 300) + 500 ))
  FS_B=$(( (RANDOM % 200) + 200 ))
  FS_C=$(( (RANDOM % 100) + 50 ))
  FS_COST=$(( FS_B + 40 ))
  cat > "$FS1/f.json" <<JSON
{
  "schema_version": "1.0",
  "findings": [
    {"id": "b-second", "resource": "res-B", "region": "<region>", "service": "Svc B",
     "monthly_cost_estimate": $FS_COST, "after_monthly_cost": 40,
     "evidence": "cmd b", "price_lookups": [$PL_REC], "action": "OPTIMIZE", "reversible": true, "confidence": "High"},
    {"id": "c-gated", "resource": "res-C", "region": "<region>", "service": "Svc C",
     "monthly_cost_estimate": $FS_C,
     "evidence": "cmd c", "price_lookups": [$PL_REC], "action": "SAFE-TO-DELETE", "reversible": false, "confidence": "High"},
    {"id": "a-first", "resource": "res-A", "region": "<region>", "service": "Svc A",
     "monthly_cost_estimate": null, "monthly_saving": $FS_A,
     "evidence": "cmd a", "price_lookups": [$PL_REC], "action": "OPTIMIZE", "reversible": true, "confidence": "High"},
    {"id": "d-unknown", "resource": "res-D", "region": "<region>", "service": "Svc D",
     "monthly_cost_estimate": null,
     "evidence": "cmd d", "action": "OPTIMIZE", "reversible": true, "confidence": "Low"},
    {"id": "k-keep", "resource": "res-K", "region": "<region>", "service": "Svc K",
     "monthly_cost_estimate": $FS_A,
     "evidence": "cmd k", "price_lookups": [$PL_REC], "action": "KEEP", "reversible": false, "confidence": "High"}
  ]
}
JSON
  FS1_RC=0
  FS1_OUT=$(bash "$SUMMARY" "$FS1/f.json" 2>/dev/null) || FS1_RC=$?
  assert_eq "findings-summary: exits 0 on a valid file" "$FS1_RC" "0"
  assert_eq "findings-summary: line 1 is the verdict, with both totals" \
    "$(printf '%s\n' "$FS1_OUT" | sed -n 1p)" \
    "VERDICT: save $(usd $(( FS_A + FS_B )))/mo now, safely. Up to $(usd $(( FS_A + FS_B + FS_C )))/mo with sign-offs."
  assert_eq "findings-summary: line 2 counts safe, sign-off and keep" \
    "$(printf '%s\n' "$FS1_OUT" | sed -n 2p)" \
    "4 findings to act on: 2 safe now, 2 need sign-off. 1 to keep."
  assert_contains "findings-summary: an unknown saving is named and kept out of the totals" \
    "$FS1_OUT" "1 finding has no verified cost and is in no total."
  assert_eq "findings-summary: action 1 is the largest safe saving" \
    "$(printf '%s\n' "$FS1_OUT" | grep '^1\. ')" \
    "1. OPTIMIZE res-A (Svc A, <region>): saves \$$FS_A/mo. High confidence, reversible."
  assert_eq "findings-summary: action 2 is the next safe saving, cost minus after" \
    "$(printf '%s\n' "$FS1_OUT" | grep '^2\. ')" \
    "2. OPTIMIZE res-B (Svc B, <region>): saves \$$FS_B/mo. High confidence, reversible."
  assert_eq "findings-summary: action 3 is a sign-off item, and says so" \
    "$(printf '%s\n' "$FS1_OUT" | grep '^3\. ')" \
    "3. SAFE-TO-DELETE res-C (Svc C, <region>): saves \$$FS_C/mo. High confidence, not reversible, needs sign-off."
  FS1_ORDER="$(printf '%s\n' "$FS1_OUT" | grep -n -E '^(VERDICT:|Do these three first:|Detail:)' | cut -d: -f2 | tr '\n' ' ')"
  assert_eq "findings-summary: order is verdict, three actions, detail" \
    "$FS1_ORDER" "VERDICT Do these three first Detail "
  assert_contains "findings-summary: counts the price records behind the figures" \
    "$FS1_OUT" "- Price sources: 4 Price List lookups, 0 Cost Explorer reads"
  assert_contains "findings-summary: names the command that re-checks them" \
    "$FS1_OUT" "Re-check the Price List prices live: verify-price.sh --recheck $FS1/f.json"
  assert_contains "findings-summary: a KEEP finding is never listed as an action" \
    "$(printf '%s\n' "$FS1_OUT" | grep -c 'res-K' | tr -d ' ')" "0"
  rm -rf "$FS1"

  # 35. Money is printed with thousands separators and with cents when needed.
  FS2="$(mktemp -d)"
  FS_BIG=$(( 1000 * 1000 + 2345 ))
  cat > "$FS2/f.json" <<JSON
{"schema_version": "1.0", "findings": [
  {"id": "big", "resource": "res-big", "region": "<region>", "service": "Svc",
   "monthly_cost_estimate": null, "monthly_saving": $FS_BIG.5,
   "evidence": "cmd", "price_lookups": [$PL_REC], "action": "OPTIMIZE", "reversible": true, "confidence": "High"}]}
JSON
  FS2_OUT=$(bash "$SUMMARY" "$FS2/f.json" 2>/dev/null) || true
  assert_eq "findings-summary: formats thousands and cents" \
    "$(printf '%s\n' "$FS2_OUT" | sed -n 1p)" \
    "VERDICT: save \$1,002,345.50/mo now, safely. No further saving needs a sign-off."
  assert_contains "findings-summary: one action is announced as one" "$FS2_OUT" "Do this first:"
  rm -rf "$FS2"

  # 36. No verified cost anywhere: the verdict says unknown and prints no dollar.
  FS3_RC=0
  FS3_OUT=$(bash "$SUMMARY" "$FIX_GOOD" 2>/dev/null) || FS3_RC=$?
  assert_eq "findings-summary: the null-cost fixture exits 0" "$FS3_RC" "0"
  assert_eq "findings-summary: with no verified cost the verdict says unknown" \
    "$(printf '%s\n' "$FS3_OUT" | sed -n 1p)" \
    "VERDICT: 2 findings to act on, saving unknown, could not verify."
  assert_eq "findings-summary: with no verified cost no dollar figure is printed" \
    "$(printf '%s\n' "$FS3_OUT" | grep -c '\$' | tr -d ' ')" "0"

  # 37. A file that breaks the contract gets no summary at all.
  FS4_RC=0
  FS4_OUT=$(bash "$SUMMARY" "$FIX_BAD" 2>/dev/null) || FS4_RC=$?
  assert_eq "findings-summary: a file that breaks the contract exits 1" "$FS4_RC" "1"
  assert_eq "findings-summary: and prints no summary" "$FS4_OUT" ""

  # 38. Nothing to act on.
  FS5="$(mktemp -d)"
  cat > "$FS5/f.json" <<'JSON'
{"schema_version": "1.0", "findings": [
  {"id": "k", "resource": "res-K", "region": "<region>", "service": "Svc",
   "monthly_cost_estimate": null,
   "evidence": "cmd", "action": "KEEP", "reversible": false, "confidence": "High"}]}
JSON
  FS5_OUT=$(bash "$SUMMARY" "$FS5/f.json" 2>/dev/null) || true
  assert_eq "findings-summary: all KEEP means nothing to act on" \
    "$(printf '%s\n' "$FS5_OUT" | sed -n 1p)" \
    "VERDICT: nothing to act on. 1 finding checked, all marked KEEP."
  rm -rf "$FS5"

  # 39. The synthetic sample is valid, and the README shows exactly what the
  # script prints for it. A README sample that drifts from the tool fails here.
  FS6_RC=0
  bash "$VALIDATE" "$ROOT/examples/sample-findings.json" >/dev/null 2>&1 || FS6_RC=$?
  assert_eq "sample: examples/sample-findings.json satisfies the contract" "$FS6_RC" "0"
  # 2>&1: the README must match what a terminal shows, stderr included. Run
  # from the repo root with the same relative path the README tells you to use.
  FS6_OUT=$(cd "$ROOT" && bash "$SUMMARY" examples/sample-findings.json 2>&1) || true
  FS6_README=$(awk '/<!-- sample-report:begin -->/{f=1;next} /<!-- sample-report:end -->/{f=0} f' \
    "$ROOT/README.md" | grep -v '^```' | sed '/./,$!d' || true)
  assert_eq "sample: the README sample report is the script output, line for line" \
    "$FS6_README" "$FS6_OUT"
  assert_eq "sample: examples/sample-report.md opens with the same verdict" \
    "$(grep -m1 '^VERDICT:' "$ROOT/examples/sample-report.md")" \
    "$(printf '%s\n' "$FS6_OUT" | sed -n 1p)"

  # 39b. In a terminal the verdict is the very first line; the validator's [OK]
  # line appears only with --verbose, and only after the summary.
  assert_eq "findings-summary: in a terminal, line 1 is the verdict (stderr included)" \
    "$(printf '%s\n' "$FS6_OUT" | sed -n 1p | cut -c1-8)" "VERDICT:"
  assert_eq "findings-summary: no [OK] contract line without --verbose" \
    "$(printf '%s\n' "$FS6_OUT" | grep -c '^\[OK\]' | tr -d ' ')" "0"
  FS7_OUT=$(cd "$ROOT" && bash "$SUMMARY" --verbose examples/sample-findings.json 2>&1) || true
  assert_eq "findings-summary: --verbose still opens on the verdict" \
    "$(printf '%s\n' "$FS7_OUT" | sed -n 1p | cut -c1-8)" "VERDICT:"
  assert_contains "findings-summary: --verbose prints the [OK] line last" \
    "$(printf '%s\n' "$FS7_OUT" | tail -1)" "[OK] "
  FS8_ERR=$(bash "$SUMMARY" "$FIX_BAD" 2>&1 >/dev/null) || true
  assert_contains "findings-summary: a broken file still shows the validator's [FAIL] lines" \
    "$FS8_ERR" "[FAIL]"

  # 40. The report template the skill follows is verdict first.
  first_line() { grep -n -m1 -e "$2" "$1" | cut -d: -f1; }
  for f in skills/aws-cost-audit/references/output-and-reporting.md examples/sample-report.md; do
    V=$(first_line "$ROOT/$f" '^## Verdict')
    T=$(first_line "$ROOT/$f" '^## Do these three first')
    D=$(first_line "$ROOT/$f" '^## 1\. ')
    if [ -n "$V" ] && [ -n "$T" ] && [ -n "$D" ] && [ "$V" -lt "$T" ] && [ "$T" -lt "$D" ]; then
      ok "report order: $f puts the verdict, then three actions, then the detail"
    else
      fail "report order: $f puts the verdict, then three actions, then the detail" \
        "verdict line ${V:-none}, actions line ${T:-none}, detail line ${D:-none}" "verdict < actions < detail"
    fi
  done
else
  printf '[SKIP] findings-validate and findings-summary cases: jq is not installed on this machine\n'
fi

# ---- verify-price.sh --record and --recheck ----------------------------------
# A stubbed `aws` answers pricing get-products with one product whose price is
# chosen at run time, and logs every call. No AWS call is made.
if command -v jq >/dev/null 2>&1; then
  VP="$HERE/../skills/aws-cost-audit/scripts/verify-price.sh"
  make_pricing_stub() { # make_pricing_stub <bin-dir> <calls-log>
    mkdir -p "$1"
    cat > "$1/aws" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$2"
case "\$1 \$2" in
  "pricing get-products")
    jq -n --arg usd "\$STUB_USD" --argjson dims "\${STUB_DIMS:-1}" '
      [range(\$dims) | {("RATE" + tostring): {unit: "GB-Mo", pricePerUnit: {USD: \$usd},
                         description: "stub dimension"}}] | add as \$pd
      | {PriceList: [ {product: {sku: "SKUSTUB"},
                       terms: {OnDemand: {"SKUSTUB.TERM": {priceDimensions: \$pd}}}} | tojson ]}'
    ;;
  *) echo "unexpected call: \$*" >&2; exit 9;;
esac
STUB
    chmod +x "$1/aws"
  }
  VP_DIR="$(mktemp -d)"
  make_pricing_stub "$VP_DIR/bin" "$VP_DIR/calls"
  VP_USD="0.0$(( (RANDOM % 89) + 10 ))"

  # 46. --record prints one record that the validator accepts in a finding.
  VP_RC=0
  VP_REC=$(PATH="$VP_DIR/bin:$PATH" STUB_USD="$VP_USD" bash "$VP" --service-code AmazonEC2 \
    --region-code us-east-1 --filter productFamily=Storage --filter volumeApiName=gp3 --record 2>/dev/null) || VP_RC=$?
  assert_eq "verify-price --record: exits 0 when one price matches" "$VP_RC" "0"
  assert_eq "verify-price --record: records the live unit price as a number" \
    "$(printf '%s' "$VP_REC" | jq -r '.price_per_unit_usd == ($u | tonumber)' --arg u "$VP_USD")" "true"
  assert_eq "verify-price --record: records the SKU, unit, filters and region" \
    "$(printf '%s' "$VP_REC" | jq -c '[.method, .sku, .unit, .region_code, .filters]')" \
    '["price-list","SKUSTUB","GB-Mo","us-east-1",["productFamily=Storage","volumeApiName=gp3"]]'
  assert_eq "verify-price --record: stamps the fetch time in UTC" \
    "$(printf '%s' "$VP_REC" | jq -r '.fetched_at | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z$")')" "true"
  VP_N=$(( (RANDOM % 900) + 100 ))
  printf '{"schema_version": "1.1", "findings": [{"id": "e2e", "resource": "vol-EXAMPLE",
    "region": "us-east-1", "service": "Amazon EBS", "monthly_cost_estimate": %s,
    "evidence": "aws ec2 describe-volumes", "price_lookups": [%s],
    "action": "OPTIMIZE", "reversible": true, "confidence": "High"}]}' "$VP_N" "$VP_REC" > "$VP_DIR/f.json"
  VP_RC=0; bash "$HERE/../skills/aws-cost-audit/scripts/findings-validate.sh" "$VP_DIR/f.json" >/dev/null 2>&1 || VP_RC=$?
  assert_eq "verify-price --record: its output satisfies the price rule as it is" "$VP_RC" "0"

  # 46b. A record from another partition: GovCloud and China region codes are
  # region codes too, so what --record prints there passes as it is.
  for vp_region in us-gov-west-1 cn-north-1; do
    VP_REC2=$(PATH="$VP_DIR/bin:$PATH" STUB_USD="$VP_USD" bash "$VP" --service-code AmazonEC2 \
      --region-code "$vp_region" --filter productFamily=Storage --filter volumeApiName=gp3 --record 2>/dev/null)
    printf '{"schema_version": "1.1", "findings": [{"id": "part", "resource": "vol-EXAMPLE",
      "region": "%s", "service": "Amazon EBS", "monthly_cost_estimate": %s,
      "evidence": "aws ec2 describe-volumes", "price_lookups": [%s],
      "action": "OPTIMIZE", "reversible": true, "confidence": "High"}]}' "$vp_region" "$VP_N" "$VP_REC2" > "$VP_DIR/p.json"
    VP_RC=0; bash "$HERE/../skills/aws-cost-audit/scripts/findings-validate.sh" "$VP_DIR/p.json" >/dev/null 2>&1 || VP_RC=$?
    assert_eq "verify-price --record: a $vp_region record satisfies the price rule" "$VP_RC" "0"
  done

  # 47. --record refuses a lookup that matched more than one price.
  VP_RC=0
  VP_OUT=$(PATH="$VP_DIR/bin:$PATH" STUB_USD="$VP_USD" STUB_DIMS=2 bash "$VP" --service-code AmazonS3 \
    --region-code us-east-1 --filter storageClass=General --record 2>&1) || VP_RC=$?
  assert_eq "verify-price --record: two matching prices exit 1" "$VP_RC" "1"
  assert_contains "verify-price --record: and says to narrow the filters" "$VP_OUT" "Add --filter until one price is left"
  assert_eq "verify-price --record: and prints no record" "$(printf '%s' "$VP_OUT" | grep -c '"method"' | tr -d ' ')" "0"

  # 48. --recheck: an unchanged price passes, a changed one fails and says so.
  : > "$VP_DIR/calls"
  VP_RC=0
  VP_OUT=$(PATH="$VP_DIR/bin:$PATH" STUB_USD="$VP_USD" bash "$VP" --recheck "$VP_DIR/f.json" 2>/dev/null) || VP_RC=$?
  assert_eq "verify-price --recheck: an unchanged price exits 0" "$VP_RC" "0"
  assert_contains "verify-price --recheck: reports the match" "$VP_OUT" "[OK] e2e: AmazonEC2 SKUSTUB still"
  assert_eq "verify-price --recheck: makes only Price List calls" \
    "$(grep -vc '^pricing get-products ' "$VP_DIR/calls" | tr -d ' ')" "0"
  VP_RC=0
  VP_OUT=$(PATH="$VP_DIR/bin:$PATH" STUB_USD="9$VP_USD" bash "$VP" --recheck "$VP_DIR/f.json" 2>/dev/null) || VP_RC=$?
  assert_eq "verify-price --recheck: a changed price exits 1" "$VP_RC" "1"
  assert_contains "verify-price --recheck: and names the finding and the new price" "$VP_OUT" "[CHANGED] e2e:"

  # 49. --recheck lists a cost-explorer record without calling Cost Explorer.
  jq '.findings[0].price_lookups += [{"method": "cost-explorer", "command": "aws ce get-cost-and-usage",
       "reason": "no unit price", "fetched_at": "2026-11-17T09:00:00Z"}]' "$VP_DIR/f.json" > "$VP_DIR/g.json"
  : > "$VP_DIR/calls"
  VP_OUT=$(PATH="$VP_DIR/bin:$PATH" STUB_USD="$VP_USD" bash "$VP" --recheck "$VP_DIR/g.json" 2>/dev/null) || true
  assert_contains "verify-price --recheck: a Cost Explorer record is listed as not re-checked" \
    "$VP_OUT" "[SKIP] e2e: cost-explorer record, not re-checked"
  assert_eq "verify-price --recheck: and no billed Cost Explorer call is made" \
    "$(grep -c '^ce ' "$VP_DIR/calls" | tr -d ' ')" "0"
  rm -rf "$VP_DIR"
else
  printf '[SKIP] verify-price.sh --record and --recheck cases: jq is not installed on this machine\n'
fi

# ---- delete-unattached-ebs.sh gating -------------------------------------------
# A stubbed `aws` logs every call. Each case checks which calls ran, so "no
# change before the confirmation" is tested, not assumed. stdin is /dev/null,
# so there is no TTY.
EBS="$HERE/../skills/aws-cost-audit/scripts/delete-unattached-ebs.sh"
make_ebs_stub() {
  local dir="$1" calls="$2"
  mkdir -p "$dir"
  cat > "$dir/aws" <<STUB
#!/usr/bin/env bash
echo "\$*" >> "$calls"
case "\$1 \$2" in
  "ec2 describe-volumes") echo '{"id": "vol-TEST", "state": "available", "size": 8, "az": "eu-west-1a", "type": "gp3", "attachments": []}';;
  "ec2 create-snapshot") echo "snap-TEST";;
esac
exit 0
STUB
  chmod +x "$dir/aws"
}
ebs_run() {
  local d="$1"; shift
  PATH="$d/bin:$PATH" AWS_REGION="eu-west-1" "$BASH_BIN" "$EBS" --volume-id vol-TEST --output "$d/out" "$@" </dev/null >"$d/log" 2>&1
}
ebs_changes() { grep -c -E '^ec2 (create-snapshot|wait|delete-volume)' "$1" 2>/dev/null | tr -d ' ' || true; }

# 41. Dry run: no change, rollback metadata saved.
E1="$(mktemp -d)"; make_ebs_stub "$E1/bin" "$E1/calls"
E1_RC=0; ebs_run "$E1" || E1_RC=$?
assert_eq "delete-ebs: the dry run exits 0" "$E1_RC" "0"
assert_eq "delete-ebs: the dry run changes nothing" "$(ebs_changes "$E1/calls")" "0"
assert_eq "delete-ebs: the dry run saves a rollback file" "$(ls "$E1/out" | grep -c '^rollback-ebs-delete-vol-TEST' | tr -d ' ')" "1"
rm -rf "$E1"

# 42. --apply with no TTY and no --yes: refused before the snapshot.
E2="$(mktemp -d)"; make_ebs_stub "$E2/bin" "$E2/calls"
E2_RC=0; ebs_run "$E2" --apply || E2_RC=$?
assert_eq "delete-ebs: --apply without a TTY or --yes is refused" "$E2_RC" "1"
assert_contains "delete-ebs: and says why" "$(cat "$E2/log")" "without a TTY and without --yes"
assert_eq "delete-ebs: and nothing changed, not even a snapshot" "$(ebs_changes "$E2/calls")" "0"
assert_eq "delete-ebs: the rollback file was saved before the refusal" "$(ls "$E2/out" | grep -c '^rollback-ebs-delete-vol-TEST' | tr -d ' ')" "1"
rm -rf "$E2"

# 43. --no-snapshot --apply without --yes: refused, as the help says.
E3="$(mktemp -d)"; make_ebs_stub "$E3/bin" "$E3/calls"
E3_RC=0; ebs_run "$E3" --no-snapshot --apply || E3_RC=$?
assert_eq "delete-ebs: --no-snapshot --apply without --yes is refused" "$E3_RC" "1"
assert_contains "delete-ebs: and names the rule" "$(cat "$E3/log")" "Refusing --no-snapshot with --apply unless --yes"
assert_eq "delete-ebs: and nothing changed" "$(ebs_changes "$E3/calls")" "0"
rm -rf "$E3"

# 44. --apply --yes: snapshot, wait, then delete, in that order.
E4="$(mktemp -d)"; make_ebs_stub "$E4/bin" "$E4/calls"
E4_RC=0; ebs_run "$E4" --apply --yes || E4_RC=$?
assert_eq "delete-ebs: --apply --yes exits 0" "$E4_RC" "0"
assert_eq "delete-ebs: snapshot, wait, then delete" \
  "$(grep -E '^ec2 (create-snapshot|wait|delete-volume)' "$E4/calls" | cut -d' ' -f2 | tr '\n' ' ')" \
  "create-snapshot wait delete-volume "
assert_contains "delete-ebs: the rollback file records the snapshot id" \
  "$(cat "$E4/out"/rollback-ebs-delete-vol-TEST-*.json)" '"snapshotId": "snap-TEST"'
rm -rf "$E4"

# 45. --no-snapshot --apply --yes: deletes with no snapshot call.
E5="$(mktemp -d)"; make_ebs_stub "$E5/bin" "$E5/calls"
E5_RC=0; ebs_run "$E5" --no-snapshot --apply --yes || E5_RC=$?
assert_eq "delete-ebs: --no-snapshot --apply --yes exits 0" "$E5_RC" "0"
assert_eq "delete-ebs: and only deletes, no snapshot" \
  "$(grep -E '^ec2 (create-snapshot|wait|delete-volume)' "$E5/calls" | cut -d' ' -f2 | tr '\n' ' ')" "delete-volume "
rm -rf "$E5"

# ---- version parity ------------------------------------------------------------
# The three plugin manifests and SKILL.md metadata.version carry one version.
PARITY_ROOT="$HERE/.."
manifest_version() { sed -n 's/^ *"version": *"\([^"]*\)".*/\1/p' "$1" | head -1; }
V_CLAUDE="$(manifest_version "$PARITY_ROOT/.claude-plugin/plugin.json")"
V_SKILL="$(awk '/^---$/{n++; next} n==1 && /^metadata:/{m=1; next} n==1 && m && /^  version:/{gsub(/[" ]/,"",$2); print $2; exit}' FS=: "$PARITY_ROOT/skills/aws-cost-audit/SKILL.md")"
assert_eq "version parity: SKILL.md metadata.version matches .claude-plugin/plugin.json" "$V_SKILL" "$V_CLAUDE"
assert_eq "version parity: .cursor-plugin/plugin.json matches .claude-plugin/plugin.json" \
  "$(manifest_version "$PARITY_ROOT/.cursor-plugin/plugin.json")" "$V_CLAUDE"
assert_eq "version parity: .copilot-plugin/plugin.json matches .claude-plugin/plugin.json" \
  "$(manifest_version "$PARITY_ROOT/.copilot-plugin/plugin.json")" "$V_CLAUDE"

# ---- summary -----------------------------------------------------------------
echo ""
printf 'Results: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
