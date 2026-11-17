#!/usr/bin/env bash
# verify-price.sh: Look up the LIVE unit price for a service from the AWS
# Price List Query API. This proves "Law 1: never assume a price: verify it
# live for your exact region." This script hardcodes NO prices.
#
# Wrapper around `aws pricing get-products`. The Price List Query API is only
# served from two endpoints (us-east-1 and ap-south-1); the region you are
# PRICING is passed as a filter (regionCode), independent of the API endpoint.
# Ref: AWS Price List API: using the AWS Price List Query API.
#
# Three modes:
#   default     print a table of every matching price
#   --record    print one price_lookups record for findings.json. It refuses
#               unless exactly one price matches, so the record names one SKU
#               and one unit price, with the time it was fetched.
#   --recheck   re-run every price-list record in a findings.json file and
#               report any price that no longer matches.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
. "$HERE/_lib.sh"

usage() {
  cat <<'EOF'
Usage: verify-price.sh --service-code CODE --region-code REGION [filters...] [--record]
       verify-price.sh --recheck FINDINGS.json

Prints live on-demand unit prices from the AWS Price List Query API.
Hardcodes no prices. Read-only.

Required:
  --service-code CODE   e.g. AmazonEC2, AmazonRDS, AmazonElastiCache,
                        AWSELB, AmazonEC2 (EBS uses AmazonEC2 with
                        productFamily=Storage), AmazonCloudWatch.
  --region-code REGION  The region you want pricing FOR, e.g. us-east-1.

Optional repeatable filters (TERM_MATCH):
  --filter FIELD=VALUE  e.g. --filter volumeApiName=gp3
                              --filter instanceType=t3.micro
                              --filter productFamily=Storage
  --api-region REGION   Price List API endpoint (default: us-east-1; the API is
                        only served from us-east-1 and ap-south-1).
  --raw                 Print raw PriceList JSON instead of a parsed summary.
  --record              Print one price_lookups record (JSON) for a finding in
                        findings.json. Needs jq. Refuses unless exactly one
                        price matches: add --filter until one is left.
  --recheck FILE        Re-run every price-list record in FILE live and compare
                        the unit price. Exit 0 if all match, 1 if any differ or
                        cannot be found. Cost Explorer records are listed as
                        not re-checked (each one would be a billed request).
  -h, --help            Show this help

Examples:
  # Live price of a gp3 volume-GB in us-east-1:
  verify-price.sh --service-code AmazonEC2 --region-code us-east-1 \
    --filter productFamily="Storage" --filter volumeApiName=gp3

  # The same lookup as a record to paste into a finding's price_lookups:
  verify-price.sh --service-code AmazonEC2 --region-code us-east-1 \
    --filter productFamily="Storage" --filter volumeApiName=gp3 --record

  # Re-check every recorded price in a findings file:
  verify-price.sh --recheck cost-audit-out/findings.json

  # Live price of a t3.micro Linux On-Demand instance:
  verify-price.sh --service-code AmazonEC2 --region-code us-east-1 \
    --filter instanceType=t3.micro --filter operatingSystem=Linux \
    --filter tenancy=Shared --filter preInstalledSw=NA --filter capacitystatus=Used
EOF
}

SERVICE_CODE=""
REGION_CODE=""
API_REGION="us-east-1"   # Price List Query API endpoint (NOT a default for pricing).
RAW=0
RECORD=0
RECHECK=""
FILTER_ARGS=()
FILTER_PAIRS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --service-code) SERVICE_CODE="$2"; shift 2;;
    --region-code)  REGION_CODE="$2"; shift 2;;
    --api-region)   API_REGION="$2"; shift 2;;
    --filter)
      f="$2"; shift 2
      field="${f%%=*}"; value="${f#*=}"
      [ "$field" = "$f" ] && die "Bad --filter '$f' (expected FIELD=VALUE)"
      FILTER_ARGS+=( "Type=TERM_MATCH,Field=${field},Value=${value}" )
      FILTER_PAIRS+=( "${field}=${value}" )
      ;;
    --raw) RAW=1; shift;;
    --record) RECORD=1; shift;;
    --recheck) RECHECK="${2:-}"; [ -n "$RECHECK" ] || die "--recheck needs a findings.json path"; shift 2;;
    -h|--help) usage; exit 0;;
    *) die "Unknown argument: $1 (see --help)";;
  esac
done

# Every OnDemand price dimension in a get-products answer, one object each.
# The PriceList entries are JSON strings, so each is parsed with fromjson.
DIMENSIONS_JQ='[ .PriceList[]? | fromjson | . as $p
  | ($p.terms.OnDemand // {}) | to_entries[]? | .value.priceDimensions | to_entries[]? | .value
  | { sku: ($p.product.sku // ""),
      unit: (.unit // ""),
      usd: (.pricePerUnit.USD // null),
      description: (.description // "") } ]'

# ---- --recheck: re-run every recorded price-list lookup ------------------------
if [ -n "$RECHECK" ]; then
  preflight
  require_cmd jq
  [ -f "$RECHECK" ] || die "No such file: $RECHECK"
  jq empty "$RECHECK" >/dev/null 2>&1 || die "$RECHECK is not valid JSON"
  RECORDS="$(jq -c '
    .findings[]? | select(type == "object") | .id as $id
    | (.price_lookups // []) | if type == "array" then .[] else empty end
    | select(type == "object") | . + {finding: $id}' "$RECHECK")"
  [ -n "$RECORDS" ] || die "No price_lookups records in $RECHECK. Nothing to re-check."
  CHECKED=0; MATCHED=0; BAD=0; SKIPPED=0
  while IFS= read -r rec; do
    [ -n "$rec" ] || continue
    fid="$(printf '%s' "$rec" | jq -r '.finding')"
    method="$(printf '%s' "$rec" | jq -r '.method // ""')"
    if [ "$method" != "price-list" ]; then
      printf '[SKIP] %s: %s record, not re-checked (a Cost Explorer read is a billed request)\n' "$fid" "$method"
      SKIPPED=$((SKIPPED + 1))
      continue
    fi
    CHECKED=$((CHECKED + 1))
    sc="$(printf '%s' "$rec" | jq -r '.service_code')"
    rc="$(printf '%s' "$rec" | jq -r '.region_code')"
    sku="$(printf '%s' "$rec" | jq -r '.sku')"
    args=()
    while IFS= read -r pair; do
      [ -n "$pair" ] || continue
      args+=( "Type=TERM_MATCH,Field=${pair%%=*},Value=${pair#*=}" )
    done < <(printf '%s' "$rec" | jq -r '.filters[]?')
    args+=( "Type=TERM_MATCH,Field=regionCode,Value=${rc}" )
    if ! live="$(aws pricing get-products --region "$API_REGION" --service-code "$sc" \
                  --filters "${args[@]}" --output json 2>/dev/null)"; then
      printf '[FAIL] %s: the lookup for %s %s failed (need pricing:GetProducts)\n' "$fid" "$sc" "$sku"
      BAD=$((BAD + 1))
      continue
    fi
    verdict="$(printf '%s' "$live" | jq -r --argjson rec "$rec" "$DIMENSIONS_JQ"'
      | map(select(.sku == $rec.sku))
      | if length == 0 then "MISSING"
        elif length > 1 then "AMBIGUOUS"
        elif (.[0].usd | tonumber? // null) == ($rec.price_per_unit_usd) and .[0].unit == $rec.unit then "OK"
        else "CHANGED \(.[0].usd) per \(.[0].unit)" end')"
    case "$verdict" in
      OK)
        printf '[OK] %s: %s %s still %s USD per %s\n' "$fid" "$sc" "$sku" \
          "$(printf '%s' "$rec" | jq -r '.price_per_unit_usd')" "$(printf '%s' "$rec" | jq -r '.unit')"
        MATCHED=$((MATCHED + 1));;
      MISSING)
        printf '[FAIL] %s: SKU %s is not in the live answer for these filters\n' "$fid" "$sku"
        BAD=$((BAD + 1));;
      AMBIGUOUS)
        printf '[FAIL] %s: SKU %s has more than one price dimension; it cannot be one unit price\n' "$fid" "$sku"
        BAD=$((BAD + 1));;
      *)
        printf '[CHANGED] %s: %s %s was %s USD per %s, live now %s\n' "$fid" "$sc" "$sku" \
          "$(printf '%s' "$rec" | jq -r '.price_per_unit_usd')" "$(printf '%s' "$rec" | jq -r '.unit')" \
          "${verdict#CHANGED }"
        BAD=$((BAD + 1));;
    esac
  done <<< "$RECORDS"
  printf 'Re-checked %s price-list record(s): %s match, %s do not. %s Cost Explorer record(s) not re-checked.\n' \
    "$CHECKED" "$MATCHED" "$BAD" "$SKIPPED"
  [ "$BAD" -eq 0 ] || exit 1
  exit 0
fi

[ -n "$SERVICE_CODE" ] || die "--service-code is required (see --help)"
[ -n "$REGION_CODE" ]  || die "--region-code is required (see --help)"

preflight

# regionCode is the canonical, region-agnostic filter on the Price List API.
FILTER_ARGS+=( "Type=TERM_MATCH,Field=regionCode,Value=${REGION_CODE}" )

info "Service:     $SERVICE_CODE"
info "Pricing for: $REGION_CODE"
info "API endpoint:$API_REGION"

RESULT="$(aws pricing get-products \
  --region "$API_REGION" \
  --service-code "$SERVICE_CODE" \
  --filters "${FILTER_ARGS[@]}" \
  --output json)" || die "pricing get-products failed (need pricing:GetProducts; API region must be us-east-1 or ap-south-1)"

# ---- --record: one price, as a record for findings.json -------------------------
if [ "$RECORD" = "1" ]; then
  require_cmd jq
  [ "${#FILTER_PAIRS[@]}" -gt 0 ] || die "--record needs at least one --filter, so the record says what was priced."
  DIMS="$(printf '%s' "$RESULT" | jq -c "$DIMENSIONS_JQ")"
  N="$(printf '%s' "$DIMS" | jq 'length')"
  if [ "$N" != "1" ]; then
    err "--record needs exactly one price, and this lookup matched $N."
    printf '%s' "$DIMS" | jq -r '.[:10][] | "  \(.sku)  \(.usd) USD per \(.unit)  \(.description)"' >&2
    die "Add --filter until one price is left. A tiered price cannot be recorded as one unit price."
  fi
  printf '%s' "$DIMS" | jq --arg sc "$SERVICE_CODE" --arg rc "$REGION_CODE" --arg ts "$(_ts)" \
    --argjson filters "$(jq -n '$ARGS.positional' --args "${FILTER_PAIRS[@]}")" '
    .[0] as $d
    | if ($d.usd | tonumber? // null) == null then error("the answer has no USD price") else . end
    | { method: "price-list",
        service_code: $sc,
        region_code: $rc,
        filters: $filters,
        sku: $d.sku,
        unit: $d.unit,
        price_per_unit_usd: ($d.usd | tonumber),
        fetched_at: $ts }'
  info "Add this record to the finding's price_lookups array in findings.json."
  exit 0
fi

COUNT="$(printf '%s' "$RESULT" | { command -v jq >/dev/null 2>&1 && jq '.PriceList | length' || echo '?'; })"
info "Matching products: $COUNT"

if [ "$RAW" = "1" ] || ! command -v jq >/dev/null 2>&1; then
  printf '%s\n' "$RESULT"
  [ "$RAW" = "1" ] || warn "jq not installed, printed raw JSON. Install jq for a parsed table."
  exit 0
fi

# Parse the (stringified) PriceList entries: each is a JSON string.
# Pull product attributes + on-demand price-per-unit. No prices are baked in;
# whatever AWS returns is what prints.
printf '%s' "$RESULT" | jq -r '
  .PriceList[]? | fromjson |
  . as $p |
  ($p.product.attributes // {}) as $a |
  ($p.terms.OnDemand // {}) | to_entries[]? | .value.priceDimensions | to_entries[]? | .value |
  [
    ($a.instanceType // $a.volumeApiName // $a.usagetype // "n/a"),
    ($a.location // "n/a"),
    (.unit // "n/a"),
    (.pricePerUnit | to_entries[0] | "\(.value) \(.key)"),
    (.description // "")
  ] | @tsv
' | awk -F'\t' 'BEGIN{
    printf "%-22s %-26s %-10s %-22s %s\n","SKU/TYPE","LOCATION","UNIT","PRICE/UNIT","DESCRIPTION"
  }{ printf "%-22s %-26s %-10s %-22s %s\n",$1,$2,$3,$4,$5 }' \
  || { warn "Could not parse; re-run with --raw."; }

printf '\nLaw 1 reminder: this price came LIVE from the AWS Price List API just now,\n'
printf 'for region %s. Re-run for your exact region/usage-type before sizing savings.\n' "$REGION_CODE"
