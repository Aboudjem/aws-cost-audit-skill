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
  if printf '%s' "$haystack" | grep -qF "$needle"; then
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
  for b in bash env dirname date head mkdir rm; do
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

# ---- summary -----------------------------------------------------------------
echo ""
printf 'Results: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
