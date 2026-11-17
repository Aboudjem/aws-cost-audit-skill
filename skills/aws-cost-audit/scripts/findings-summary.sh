#!/usr/bin/env bash
# findings-summary.sh: print the top of the report from a findings.json file.
#
# The report order is fixed: the verdict, then the three things to do first,
# then the detail. This script prints the first two parts and the counts, so
# the order does not depend on how an agent chooses to write that day.
#
# It reads the contract documented in ../references/output-and-reporting.md and
# runs findings-validate.sh first. A file that fails the contract is never
# summarised.
#
# How a finding is counted:
#   to act on      action is OPTIMIZE or SAFE-TO-DELETE
#   safe now       to act on, confidence High, reversible true
#   needs sign-off to act on, and not safe now
#   saving         monthly_saving when it is a number; else
#                  monthly_cost_estimate - after_monthly_cost when both are
#                  numbers; else monthly_cost_estimate for a SAFE-TO-DELETE
#                  finding; else unknown
# An unknown saving is never guessed and never added to a total (Law 2).
#
# Exit codes:
#   0  summary printed
#   1  the file does not satisfy the findings contract
#   2  the file could not be checked at all (no file, or jq is not installed)
#
# Read-only. Calls no AWS API, changes nothing, has no --apply flag.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
. "$HERE/_lib.sh"

usage() {
  cat <<'EOF'
Usage: findings-summary.sh [--verbose] <findings.json>

Prints the top of the report from one findings file:
  line 1    the verdict: what you can save now, and the ceiling with sign-offs
  then      the three things to do first, largest verified saving first
  then      the counts behind the verdict, and how many price records back
            them (Price List lookups and Cost Explorer reads)

The file is checked with findings-validate.sh first. A file that breaks the
contract gets the validator's [FAIL] lines on stderr and no summary.

Options:
  -v, --verbose   After the summary, also print the validator's [OK] line
                  on stderr. Without it, the first line you see is the verdict.

Exit: 0 summary printed, 1 file breaks the contract, 2 could not check.
EOF
}

FILE=""
VERBOSE=0
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0;;
    -v|--verbose) VERBOSE=1; shift;;
    -*) err "Unknown option: $1 (see --help)"; exit 2;;
    *) FILE="$1"; shift;;
  esac
done

[ -n "$FILE" ] || { usage; exit 2; }

# The validator owns every "could not check" and "breaks the contract" message.
# Its output is held back so the verdict is the first line in a terminal. On a
# failure it goes to stderr; on success only --verbose prints it, after the
# summary.
VALIDATE_RC=0
VALIDATE_OUT="$(bash "$HERE/findings-validate.sh" "$FILE" 2>&1)" || VALIDATE_RC=$?
if [ "$VALIDATE_RC" -ne 0 ]; then
  printf '%s\n' "$VALIDATE_OUT" >&2
  err "No summary printed: fix the problems above, then run this again."
  exit "$VALIDATE_RC"
fi

jq -r --arg file "$FILE" '
  def commas: if length > 3 then (.[:-3] | commas) + "," + .[-3:] else . end;
  def money:
    if . < 0 then "-" + (-. | money)
    else
      (. * 100 | round) as $c
      | (($c - ($c % 100)) / 100) as $d
      | ($c % 100) as $r
      | "$" + ($d | tostring | commas)
        + (if $r == 0 then "" else "." + (if $r < 10 then "0" else "" end) + ($r | tostring) end)
    end;
  def plural($n; $one; $many): "\($n) \(if $n == 1 then $one else $many end)";

  def saving:
    if (.monthly_saving | type) == "number" then .monthly_saving
    elif (.monthly_cost_estimate | type) == "number" and (.after_monthly_cost | type) == "number"
      then .monthly_cost_estimate - .after_monthly_cost
    elif .action == "SAFE-TO-DELETE" and (.monthly_cost_estimate | type) == "number"
      then .monthly_cost_estimate
    else null end;

  # Largest verified saving first; an unknown saving sorts last.
  def ranked: sort_by([(if .saving == null then 1 else 0 end), -(.saving // 0), .id]);
  def total: map(.saving // 0) | add // 0;
  # A bucket whose findings all lack a verified cost has no figure to show.
  def bucket($all; $known; $sum):
    plural($all | length; "finding"; "findings") + ", "
    + (if ($all | length) > 0 and ($known | length) == 0 then "saving unknown, could not verify"
       else "\($sum | money)/mo" end);

  [.findings[] | (.price_lookups // [])[] | .method] as $methods
  | ($methods | map(select(. == "price-list")) | length) as $n_pl
  | ($methods | map(select(. == "cost-explorer")) | length) as $n_ce
  | [.findings[] | . + {saving: saving}] as $all
  | ($all | map(select(.action != "KEEP"))) as $act
  | ($all | map(select(.action == "KEEP"))) as $keep
  | ($act | map(select(.confidence == "High" and .reversible == true))) as $safe
  | ($act | map(select((.confidence == "High" and .reversible == true) | not))) as $gated
  | ($act | map(select(.saving == null))) as $unknown
  | ($safe | map(select(.saving != null))) as $safe_known
  | ($gated | map(select(.saving != null))) as $gated_known
  | ($safe_known | total) as $y
  | ($y + ($gated_known | total)) as $z
  | (($safe | ranked) + ($gated | ranked) | .[:3]) as $top

  | (if ($act | length) == 0 then
       "VERDICT: nothing to act on. \(plural($all | length; "finding"; "findings")) checked, all marked KEEP."
     elif (($safe_known | length) + ($gated_known | length)) == 0 then
       "VERDICT: \(plural($act | length; "finding"; "findings")) to act on, saving unknown, could not verify."
     elif ($safe_known | length) == 0 then
       "VERDICT: nothing is safe to do today. Up to \($z | money)/mo with sign-offs."
     elif $z > $y then
       "VERDICT: save \($y | money)/mo now, safely. Up to \($z | money)/mo with sign-offs."
     else
       "VERDICT: save \($y | money)/mo now, safely. No further saving needs a sign-off."
     end),
    "\(plural($act | length; "finding"; "findings")) to act on: \($safe | length) safe now, \($gated | length) \(if ($gated | length) == 1 then "needs" else "need" end) sign-off. \($keep | length) to keep.",
    (if ($unknown | length) > 0 then
       "\(plural($unknown | length; "finding has"; "findings have")) no verified cost and \(if ($unknown | length) == 1 then "is" else "are" end) in no total."
     else empty end),
    (if ($top | length) > 0 then
       "",
       (if ($top | length) >= 3 then "Do these three first:"
        elif ($top | length) == 2 then "Do these two first:"
        else "Do this first:" end),
       ($top | to_entries[] | .key as $i | .value
        | "\($i + 1). \(.action) \(.resource) (\(.service), \(.region)): "
          + (if .saving == null then "saving unknown, could not verify" else "saves \(.saving | money)/mo" end)
          + ". \(.confidence) confidence, "
          + (if .confidence == "High" and .reversible == true then "reversible."
             elif .reversible == true then "reversible, needs sign-off."
             else "not reversible, needs sign-off." end))
     else empty end),
    "",
    "Detail:",
    "- Save now safely: \(bucket($safe; $safe_known; $y))",
    "- Needs sign-off: \(bucket($gated; $gated_known; $z - $y))",
    "- No verified cost: \(plural($unknown | length; "finding"; "findings")), in no total",
    "- Keep: \(plural($keep | length; "finding"; "findings"))",
    "- Price sources: \(plural($n_pl; "Price List lookup"; "Price List lookups")), \(plural($n_ce; "Cost Explorer read"; "Cost Explorer reads"))",
    (if $n_pl > 0 then "Re-check the Price List prices live: verify-price.sh --recheck \($file)" else empty end),
    "Every figure above comes from the findings file. Nothing in your account was changed."
' "$FILE"

if [ "$VERBOSE" = "1" ]; then
  printf '%s\n' "$VALIDATE_OUT" >&2
fi
