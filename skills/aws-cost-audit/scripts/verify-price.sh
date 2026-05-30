#!/usr/bin/env bash
# verify-price.sh: Look up the LIVE unit price for a service from the AWS
# Price List Query API. This proves "Law 1: never assume a price: verify it
# live for your exact region." This script hardcodes NO prices.
#
# Wrapper around `aws pricing get-products`. The Price List Query API is only
# served from two endpoints (us-east-1 and ap-south-1); the region you are
# PRICING is passed as a filter (regionCode), independent of the API endpoint.
# Ref: AWS Price List API: using the AWS Price List Query API.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
. "$HERE/_lib.sh"

usage() {
  cat <<'EOF'
Usage: verify-price.sh --service-code CODE --region-code REGION [filters...]

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
  -h, --help            Show this help

Examples:
  # Live price of a gp3 volume-GB in us-east-1:
  verify-price.sh --service-code AmazonEC2 --region-code us-east-1 \
    --filter productFamily="Storage" --filter volumeApiName=gp3

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
FILTER_ARGS=()

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
      ;;
    --raw) RAW=1; shift;;
    -h|--help) usage; exit 0;;
    *) die "Unknown argument: $1 (see --help)";;
  esac
done

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
