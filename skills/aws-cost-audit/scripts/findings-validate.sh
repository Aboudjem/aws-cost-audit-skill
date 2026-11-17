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
# current -> after -> saved math trail. The optional keys below carry that
# material when a run chooses to emit it, and they are type-checked when
# present.
#
# The price rule: a finding with any dollar figure (monthly_cost_estimate,
# after_monthly_cost or monthly_saving set to a number) must carry
# price_lookups, a non-empty array of records saying where each price came
# from. A "price-list" record is what `verify-price.sh --record` prints: the
# service code, region, filters, SKU, unit, unit price and fetch time. A
# "cost-explorer" record is the labelled escape for a figure with no unit
# price: it names the `aws ce` command it read and why no unit price applies.
# This checks the shape of each record. `verify-price.sh --recheck` re-runs the
# price-list records live.
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
  last_used, price_source, price_lookups

Price rule: a finding with a dollar figure needs price_lookups, an array of
records. Get a "price-list" record from:
  verify-price.sh --service-code CODE --region-code REGION --filter F=V --record
A figure with no unit price uses a "cost-explorer" record instead:
  {"method": "cost-explorer", "command": "aws ce ...",
   "reason": "why no unit price applies", "fetched_at": "YYYY-MM-DDTHH:MM:SSZ"}

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
     "created_when","last_used","price_source","price_lookups"];
  def money_keys: ["monthly_cost_estimate","after_monthly_cost","monthly_saving"];
  def pl_keys: ["method","service_code","region_code","filters","sku","unit",
                "price_per_unit_usd","fetched_at"];
  def ce_keys: ["method","command","reason","fetched_at"];
  # A UTC time in this exact form, and a real one: the round trip through
  # the jq date functions rejects month 13, day 32, hour 25 and February 30.
  def utc_ts: type == "string"
    and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$")
    and (. as $t | try (fromdateiso8601 | todateiso8601 == $t) catch false);
  # An AWS region code in any partition: us-east-1, eu-west-1, us-gov-west-1,
  # cn-north-1. Lower case, no Availability Zone letter.
  def region_code: type == "string" and test("^[a-z]{2}(-[a-z]+)+-[0-9]+$");
  # A Local Zone or Wavelength Zone code, which the Price List uses as a
  # regionCode: us-west-2-lax-1, us-east-1-wl1-bos-wlz-1.
  def zone_code: type == "string" and test("^[a-z]{2}(-[a-z]+)+-[0-9]+(-[a-z][a-z0-9]*)+-[0-9]+$");
  # The region a region or zone code belongs to.
  def parent_region: if region_code then . else capture("^(?<r>[a-z]{2}(-[a-z]+)+-[0-9]+)-").r end;
  def actions: ["KEEP","OPTIMIZE","SAFE-TO-DELETE"];
  def confidences: ["High","Medium","Low"];

  def nonempty_string($w; $k; $v):
    if ($v | type) == "string" and ($v | length) > 0 then []
    else ["\($w).\($k) must be a non-empty string, got \($v | type)"] end;

  def number_or_null($w; $k; $v):
    if ($v | type) == "number" or $v == null then []
    else ["\($w).\($k) must be a number or null, got \($v | type)"] end;

  def str_ok: type == "string" and length > 0;

  def check_record($w; $f; $r):
    if ($r | type) != "object" then ["\($w) must be an object"]
    elif $r.method == "price-list" then
      ((pl_keys - ($r | keys)) | map("\($w).\(.) is required in a price-list record but missing"))
      + ((($r | keys) - pl_keys) | map("\($w).\(.) is not a key of a price-list record"))
      + (["service_code","region_code","sku","unit"] | map(. as $k
          | if ($r | has($k)) and ($r[$k] | str_ok | not) then "\($w).\($k) must be a non-empty string" else empty end))
      + (if ($r | has("filters")) and ((($r.filters | type) != "array") or ($r.filters | length) == 0
             or ($r.filters | any(type != "string" or (test("^[^=]+=.+$") | not))))
         then ["\($w).filters must be a non-empty array of FIELD=VALUE strings"] else [] end)
      + (if ($r | has("price_per_unit_usd")) and ((($r.price_per_unit_usd | type) != "number") or $r.price_per_unit_usd < 0)
         then ["\($w).price_per_unit_usd must be a number, 0 or more"] else [] end)
      + (if ($r | has("fetched_at")) and ($r.fetched_at | utc_ts | not)
         then ["\($w).fetched_at must be a UTC time like 2026-01-31T09:30:00Z that exists on the calendar, got \($r.fetched_at | tojson)"] else [] end)
      + (if ($r | has("region_code")) and ($r.region_code | str_ok) and (($r.region_code | region_code) or ($r.region_code | zone_code) | not)
         then ["\($w).region_code must be an AWS region code such as us-east-1 (or a Local Zone code such as us-west-2-lax-1), got \($r.region_code | tojson)"]
         elif ($f.region | region_code) and ($r.region_code | region_code or zone_code) and ($r.region_code | parent_region) != $f.region
         then ["\($w).region_code is \($r.region_code) but the finding is in \($f.region): price the region the resource is in"] else [] end)
    elif $r.method == "cost-explorer" then
      ((ce_keys - ($r | keys)) | map("\($w).\(.) is required in a cost-explorer record but missing"))
      + ((($r | keys) - ce_keys) | map("\($w).\(.) is not a key of a cost-explorer record"))
      + (if ($r | has("command")) and ((($r.command | type) != "string") or ($r.command | startswith("aws ce ") | not))
         then ["\($w).command must be the aws ce command that was read, starting with \"aws ce \""] else [] end)
      + (if ($r | has("reason")) and ($r.reason | str_ok | not)
         then ["\($w).reason must say why no unit price applies"] else [] end)
      + (if ($r | has("fetched_at")) and ($r.fetched_at | utc_ts | not)
         then ["\($w).fetched_at must be a UTC time like 2026-01-31T09:30:00Z that exists on the calendar, got \($r.fetched_at | tojson)"] else [] end)
    else ["\($w).method must be price-list or cost-explorer, got \($r.method | tojson)"] end;

  def check_prices($w; $f):
    (if ($f | has("price_lookups")) then
       if ($f.price_lookups | type) != "array" or ($f.price_lookups | length) == 0
       then ["\($w).price_lookups must be a non-empty array of records"]
       else [$f.price_lookups | to_entries[] | check_record("\($w).price_lookups[\(.key)]"; $f; .value)] | add // []
       end
     else [] end)
    + (if (money_keys | any(. as $k | ($f[$k] | type) == "number")) and (($f | has("price_lookups")) | not)
       then ["\($w) has a dollar figure but no price_lookups. Run verify-price.sh --record and add its output, or add a cost-explorer record. See references/output-and-reporting.md"]
       else [] end);

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
      + check_prices($w; $f)
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
