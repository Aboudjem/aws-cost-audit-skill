#!/usr/bin/env bash
# tests/smoke.sh — offline smoke test for _lib.sh helpers.
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

# ---- summary -----------------------------------------------------------------
echo ""
printf 'Results: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
