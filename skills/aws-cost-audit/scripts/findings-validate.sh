#!/usr/bin/env bash
# findings-validate.sh: check a findings.json file against the machine-readable
# contract documented in ../references/output-and-reporting.md.
#
# JSON, never YAML: this is a bash toolchain with jq and no YAML parser, and
# adding one would break the promise that the skill shells out to a CLI you
# already have.
#
# The JSON file is the machine-checkable CORE of the prose output contract, not
# a replacement for it. The prose contract still governs the
# current -> after -> saved math trail and the price source. The eight optional
# keys below carry that material when a run chooses to emit it, and they are
# type-checked when present.
#
# Exit codes:
#   0  the file satisfies the contract; prints one [OK] line with the count
#   1  it does not; prints one [FAIL] line per problem, including every
#      top-level problem, not only the first
#   2  it could not be checked at all (no file, not JSON-readable, or jq is not
#      installed); prints [ERROR]. Never a pass.
#
# Read-only. Changes nothing, has no --apply flag.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
. "$HERE/_lib.sh"

usage() {
  cat <<'EOF'
Usage: findings-validate.sh <findings.json>

Validates one findings file against the contract in
references/output-and-reporting.md.

Required keys per finding:
  id, resource, region, service, monthly_cost_estimate, evidence, action,
  reversible, confidence

Optional keys, type-checked when present:
  after_monthly_cost, monthly_saving, purpose, owner, created_by, created_when,
  last_used, price_source

Exit: 0 valid, 1 invalid, 2 could not check.
EOF
}

FILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0;;
    -*) err "Unknown option: $1 (see --help)"; exit 2;;
    *) FILE="$1"; shift;;
  esac
done

[ -n "$FILE" ] || { usage; exit 2; }

if ! command -v jq >/dev/null 2>&1; then
  err "jq is not installed, so this file could not be checked."
  err "Install jq, then run this again. A file is never reported valid unchecked."
  exit 2
fi

if [ ! -f "$FILE" ]; then
  err "No such file: $FILE"
  exit 2
fi

if ! jq empty "$FILE" >/dev/null 2>&1; then
  printf '[FAIL] %s is not valid JSON\n' "$FILE"
  exit 1
fi

PROBLEMS="$(jq -r '
  def req_keys:
    ["id","resource","region","service","monthly_cost_estimate","evidence",
     "action","reversible","confidence"];
  def opt_keys:
    ["after_monthly_cost","monthly_saving","purpose","owner","created_by",
     "created_when","last_used","price_source"];
  def actions: ["KEEP","OPTIMIZE","SAFE-TO-DELETE"];
  def confidences: ["High","Medium","Low"];

  def nonempty_string($w; $k; $v):
    if ($v | type) == "string" and ($v | length) > 0 then []
    else ["\($w).\($k) must be a non-empty string, got \($v | type)"] end;

  def number_or_null($w; $k; $v):
    if ($v | type) == "number" or $v == null then []
    else ["\($w).\($k) must be a number or null, got \($v | type)"] end;

  def check_finding($w; $f):
    if ($f | type) != "object" then ["\($w) must be an object"]
    else
      ((req_keys - ($f | keys)) | map("\($w).\(.) is required but missing"))
      + ((($f | keys) - req_keys - opt_keys) | map("\($w).\(.) is not a key in the contract"))
      + (["id","resource","region","service","evidence"] | map(
          . as $k | if ($f | has($k)) then nonempty_string($w; $k; $f[$k]) else [] end) | add // [])
      + (["monthly_cost_estimate","after_monthly_cost","monthly_saving"] | map(
          . as $k | if ($f | has($k)) then number_or_null($w; $k; $f[$k]) else [] end) | add // [])
      + (["purpose","owner","created_by","created_when","last_used","price_source"] | map(
          . as $k | if ($f | has($k)) then nonempty_string($w; $k; $f[$k]) else [] end) | add // [])
      + (if ($f | has("action")) and (actions | index($f.action) | not)
         then ["\($w).action must be one of \(actions | join(", ")), got \($f.action | tojson)"] else [] end)
      + (if ($f | has("confidence")) and (confidences | index($f.confidence) | not)
         then ["\($w).confidence must be one of \(confidences | join(", ")), got \($f.confidence | tojson)"] else [] end)
      + (if ($f | has("reversible")) and (($f.reversible | type) != "boolean")
         then ["\($w).reversible must be true or false, got \($f.reversible | type)"] else [] end)
    end;

  if type != "object" then ["top level must be a JSON object, got \(type)"]
  else
    (if (.schema_version | type) != "string" then ["schema_version must be a string"] else [] end)
    + ((keys - ["schema_version","findings"]) | map("top-level key \(.) is not in the contract"))
    + (if (.findings | type) != "array" then ["findings must be an array"]
       else
         ([.findings | to_entries[]
           | check_finding("findings[\(.key)]"; .value)] | add // [])
         + ([.findings[]? | select(type == "object") | .id | select(type == "string")]
            | group_by(.) | map(select(length > 1)) | map("duplicate id: \(.[0])"))
       end)
  end
  | .[]
' "$FILE")"

if [ -z "$PROBLEMS" ]; then
  COUNT="$(jq -r '.findings | length' "$FILE")"
  printf '[OK] %s satisfies the findings contract (%s finding(s))\n' "$FILE" "$COUNT"
  exit 0
fi

printf '%s\n' "$PROBLEMS" | while IFS= read -r line; do
  [ -n "$line" ] && printf '[FAIL] %s\n' "$line"
done
exit 1
