# Pricing Verification: Live Prices, Real Usage, and the Skeptic Re-Derivation

> **Why this file exists:** Every dollar figure in a cost-audit finding must be *derived*, never
> guessed. This reference is the procedure for getting (1) a **live, region-correct unit price**
> from AWS and (2) the user's **actual usage**, then combining them into a savings number whose
> math is fully shown, followed by a **separate skeptic pass** that re-derives each load-bearing
> figure from the primary source.
>
> **HARD RULE: no hardcoded prices.** Do not write any `$/unit` rate into a finding from memory or
> from this file. AWS prices change and vary by Region. Always pull the rate live for the user's
> exact `regionCode` at audit time, and show where it came from.

---

## 1. Live unit price: AWS Price List Query API

### 1.1 The endpoint-vs-target-region gotcha (read this first)

The **Price List Query API is only served from a few Regions** (commonly `us-east-1` and
`ap-south-1`). This is the API *endpoint* location, it has nothing to do with which Region's
prices you get.

- Call the API with `--region us-east-1` (or `ap-south-1`) so the request reaches an endpoint.
- Select the **target Region's prices** with a `regionCode` filter, e.g.
  `Type=TERM_MATCH,Field=regionCode,Value=$REGION`.

If you instead pass the target region to `--region` and it is not a Price List endpoint, the call
fails with an endpoint/connection error. Endpoint location and priced Region are independent.
(AWS Billing docs: "Using the AWS Price List Query API"; `pricing get-products` CLI reference.)

### 1.2 Discover the service code

Prices are grouped by **service code** (note: not always the obvious name, EBS volumes live under
`AmazonEC2`, not a separate EBS code; S3 is `AmazonS3`; RDS is `AmazonRDS`).

```bash
# List every priceable service code (endpoint region us-east-1):
aws pricing describe-services --region us-east-1 \
  --query 'Services[].ServiceCode' --output text

# Confirm one service and see its filterable attribute names:
aws pricing describe-services --service-code AmazonEC2 --region us-east-1 \
  --query 'Services[0].AttributeNames'
```

`AttributeNames` is the list of fields you may filter on for that service (e.g. for `AmazonEC2`:
`volumeApiName`, `regionCode`, `productFamily`, `instanceType`, `tenancy`, `operatingSystem`, ...).

### 1.3 Discover the allowed values for an attribute

```bash
# What values can volumeApiName take? -> gp2 gp3 io1 io2 sc1 st1 standard
aws pricing get-attribute-values --service-code AmazonEC2 \
  --attribute-name volumeApiName --region us-east-1 \
  --query 'AttributeValues[].Value' --output text
```

Use this whenever a filter returns 0 or too many rows, you almost always have a slightly-wrong
attribute name or value. (`get-attribute-values` CLI reference.)

### 1.4 Worked example: gp3 $/GB-month for a target Region

Goal: the per-GB-month On-Demand storage rate for gp3 in `$REGION` (set this to the user's actual
Region, e.g. `us-east-1` as a neutral example). The filter set below is verified to return exactly
**one** PriceList entry, which is what you want, one SKU, one rate.

```bash
REGION="$REGION"   # e.g. us-east-1 ; set to the user's Region, never hardcode a default
aws pricing get-products --service-code AmazonEC2 --region us-east-1 \
  --filters \
    "Type=TERM_MATCH,Field=volumeApiName,Value=gp3" \
    "Type=TERM_MATCH,Field=regionCode,Value=$REGION" \
    "Type=TERM_MATCH,Field=productFamily,Value=Storage" \
  --query 'PriceList[0]' --output text
```

`PriceList` items are **JSON strings**. Parse the On-Demand unit rate at this path:

```
terms.OnDemand.<offerTermCode>.priceDimensions.<rateCode>.pricePerUnit.USD
```

The keys under `OnDemand` and `priceDimensions` are opaque codes, so glob over them. Extract the
rate and its unit with `jq` (pipe the single JSON-string row in):

```bash
aws pricing get-products --service-code AmazonEC2 --region us-east-1 \
  --filters \
    "Type=TERM_MATCH,Field=volumeApiName,Value=gp3" \
    "Type=TERM_MATCH,Field=regionCode,Value=$REGION" \
    "Type=TERM_MATCH,Field=productFamily,Value=Storage" \
  --query 'PriceList[0]' --output text \
| jq -r '
    .terms.OnDemand
    | to_entries[0].value.priceDimensions
    | to_entries[0].value
    | "\(.pricePerUnit.USD) USD per \(.unit), \(.description)"'
```

Verified output shape for this SKU: `unit` = `GB-Mo`, `pricePerUnit` carries a `USD` key, and the
human `description` even restates the rate (e.g. "... per GB-month of General Purpose (gp3)
provisioned storage, <Region>"). Use the parsed `pricePerUnit.USD` as the load-bearing number;
the `description` is a useful cross-check.

The same recipe generalizes, change service code + filters:

- **gp2 vs gp3 delta:** run the query twice (`Value=gp2`, then `Value=gp3`), subtract the two
  `pricePerUnit.USD` rates.
- **S3 storage class $/GB:** `--service-code AmazonS3 --filters Field=regionCode,...
  Field=storageClass,Value=...` then the same JSON path.
- **NAT/endpoint/data-transfer:** `--service-code AmazonVPC` (or `AmazonEC2` for some transfer
  types); discover attributes with `describe-services`/`get-attribute-values` first.

> **The service code and product family are not always obvious.** Some line items do not map to a
> tidy SKU: CloudWatch **Logs** storage, for example, is not under an `AmazonCloudWatch` `Storage`
> family. When a filter returns 0 rows, run `describe-services` then `get-attribute-values` to find
> the real attribute names/values for that service. If the Price List still does not yield a clean
> per-unit rate, fall back to the **Cost Explorer usage-type cost** for that line item (the
> `UnblendedCost / UsageQuantity` for its `USAGE_TYPE`) as the effective rate, and say which method
> you used. Never substitute a remembered rate.

> The On-Demand path above is for usage-priced resources. Commitment products (Savings Plans/RIs)
> have a separate Price List structure and are better sized from
> `aws ce get-savings-plans-purchase-recommendation` (see the cost-tactics reference). Do not try
> to hand-derive SP/RI break-evens from the unit Price List.

---

## 2. Actual usage: Cost Explorer (and resource-level data)

A live unit price alone is not a saving. You need the **usage delta** that the action removes or
re-rates. Get it from Cost Explorer; never assume a quantity.

### 2.0 Cost Explorer requests are billed, so they are counted and capped

Cost Explorer is the one part of this audit that costs money to run. AWS charges per Cost Explorer
API request, and **every page of a paginated result is its own request**. On a custom billing view
the charge is per source, so a multi-source view multiplies it. The console UI is free; the API is
not.

The AWS CLI auto-paginates by default, which means one CLI command can quietly issue several billed
requests. Its own help says so:

> `--no-paginate` (boolean) Disable automatic pagination. If automatic pagination is disabled, the
> AWS CLI will only make one call, for the first page of results.

So `scripts/_lib.sh` wraps every Cost Explorer call:

- `ce_call` passes `--no-paginate` and counts exactly one request per call.
- `ce_paged_call` walks the pages itself with `--next-page-token`, so every billed page goes
  through the same counter, then merges the pages back into one file when `jq` is available.
- The ceiling is `AWS_COST_AUDIT_CE_BUDGET`, default 50 requests. Hitting it stops the next request
  before it is sent. Raise it only if you accept the extra cost.
- `ce_report` prints the count and the estimated spend at the end of a run.

The per-request figure is recorded here and nowhere else, never inside a script, so it stays a
documented, sourced, checkable number rather than a constant baked into code:

<!-- ce-request-price: usd=0.01 source=https://aws.amazon.com/aws-cost-management/aws-cost-explorer/pricing/ -->

**Verify it live before quoting it.** Like every price in this skill, that figure is a starting
point from AWS's published pricing page, not a promise. Check the source URL above.

One limit worth stating: the counter covers requests the scripts make. An `aws ce ...` command you
or an agent runs directly is billed the same way but is invisible to it.

### 2.1 Service- and usage-type-level cost (always available)

```bash
# Spend by service over a window (set Start/End to real ISO dates):
aws ce get-cost-and-usage \
  --time-period Start=2026-05-01,End=2026-06-01 \
  --granularity MONTHLY \
  --metrics UnblendedCost UsageQuantity \
  --group-by Type=DIMENSION,Key=SERVICE

# Drill into the line items behind a service (the USAGE_TYPE shows the priced unit,
# e.g. EBS:VolumeUsage.gp3, NatGateway-Bytes, DataTransfer-Out-Bytes):
aws ce get-cost-and-usage \
  --time-period Start=2026-05-01,End=2026-06-01 \
  --granularity MONTHLY \
  --metrics UnblendedCost UsageQuantity \
  --group-by Type=DIMENSION,Key=USAGE_TYPE \
  --filter '{"Dimensions":{"Key":"SERVICE","Values":["Amazon Elastic Compute Cloud - Compute"]}}'
```

`UsageQuantity` gives the billed quantity; the `USAGE_TYPE` name tells you its unit so you can line
it up against the Price List unit (e.g. `GB-Mo`). (Cost Explorer `get-cost-and-usage` reference.)

Pick the metric deliberately: `UnblendedCost` is the standard per-account actual; `AmortizedCost`
spreads SP/RI upfront fees, use it when commitments are in play so you don't double-count.

### 2.2 Per-resource cost (only if Cost Explorer resource-level data is enabled)

To attribute cost to a *specific* resource id you need resource-level data, which is **off by
default** and must be enabled in Cost Management preferences (and can be backfilled only forward).

```bash
# Requires resource-level Cost Explorer to be enabled; otherwise this errors / returns nothing useful.
aws ce get-cost-and-usage-with-resources \
  --time-period Start=2026-05-20,End=2026-05-28 \
  --granularity DAILY \
  --metrics UnblendedCost UsageQuantity \
  --group-by Type=DIMENSION,Key=RESOURCE_ID \
  --filter '{"Dimensions":{"Key":"SERVICE","Values":["Amazon Elastic Compute Cloud - Compute"]}}'
```

The richer alternative is the **Cost and Usage Report (CUR / CUR 2.0)**, which has a per-line-item
`resource_id`, `line_item_usage_amount`, and `line_item_unblended_cost`, the authoritative
per-resource truth when queried in Athena.

**When resource-level data is NOT enabled:** say so explicitly. State the figure at
**service / usage-type level only**, and label any single-resource attribution as **UNVERIFIED**.
Do **not** pro-rate a service-level total down to one resource by a guessed share, that invents a
number. Either get the real per-resource line (enable resource-level CE / query CUR) or keep the
claim at the level the data actually supports.

---

## 3. The math rule: always show unit price → math → source

Every dollar claim is computed as:

```
estimated_saving = live_unit_price  ×  actual_usage_delta
```

and is presented with all three of these, in order:

1. **Unit price**, the exact `pricePerUnit.USD` value, its `unit`, the `regionCode`, and the
   `get-products` filter that produced it.
2. **The math**, the usage delta (from Cost Explorer / CUR, with its source command) multiplied by
   the unit price, with units that cancel cleanly (e.g. `GB-Mo × USD/GB-Mo = USD/mo`).
3. **The source**, link/command for both the price (Price List API call) and the usage (CE/CUR
   query), plus the access date.

Worked shape (numbers are placeholders, fill from live calls):

```
Action: migrate a detached gp2 volume's data off / delete it.
  Unit price:  <USD>/GB-Mo for gp2 in $REGION
               (aws pricing get-products … volumeApiName=gp2 regionCode=$REGION; parsed
                terms.OnDemand.*.priceDimensions.*.pricePerUnit.USD; accessed <date>)
  Usage delta: <GB> provisioned, billed as <GB>-Mo
               (aws ce get-cost-and-usage … USAGE_TYPE=EBS:VolumeUsage.gp2; UsageQuantity)
  Math:        <GB>  ×  <USD>/GB-Mo  =  <USD>/mo  avoided
  Source:      Price List API call above + CE query above, both accessed <date>.
```

Rules that keep this honest:

- **Units must cancel.** If they don't, the figure is wrong, stop.
- **Match the metric to the claim.** Rate-optimization (gp2→gp3, storage class, SP/RI) needs the
  rate *delta*; usage-optimization (delete idle, schedule-off) needs the avoided *quantity × rate*.
- **Region-correct, every time.** Re-pull the price for the user's Region; never reuse another
  Region's rate or a remembered one.
- **No data → no number.** If usage at the required granularity isn't available, present the
  result at the available granularity and mark the rest UNVERIFIED.

---

## 4. The Skeptic Routine (separate re-derivation pass)

The skeptic pass is a **distinct pass from the one that produced the finding**, a separate review
lane, not self-approval in the same breath. Its job: independently re-derive every load-bearing
dollar figure **from the primary source**, not from any summary, table, or another agent's
conclusion.

### 4.1 Primary sources only

A figure is "re-derived from primary" only if it was recomputed from:

- the **raw `get-products` PriceList JSON** (re-run the call; re-parse
  `terms.OnDemand.*.priceDimensions.*.pricePerUnit.USD`), AND
- the **raw CUR line / `get-cost-and-usage` output** for the usage quantity.

Re-reading the finding's own summary, or trusting a previously-stated rate, does **not** count.
Re-run the commands.

### 4.2 Procedure (per load-bearing figure)

1. Re-run the `aws pricing get-products …` call for the stated service/attributes/`regionCode`.
   Parse the unit rate yourself. Compare to the rate in the finding.
2. Re-run the `aws ce …` (or re-query the CUR line) for the stated usage quantity and unit.
   Compare to the quantity in the finding.
3. Recompute `unit_price × usage_delta` independently. Confirm units cancel.
4. Confirm the Region in the price filter equals the Region of the usage.

### 4.3 Label each figure

Tag every load-bearing dollar figure with exactly one verdict:

- **CONFIRMED**, independent re-derivation from primary matches the finding (within rounding).
- **CORRECTED**, re-derivation disagrees; record the corrected number, the primary value it came
  from, and what the original got wrong (wrong Region, stale rate, wrong unit, pro-rated guess).
- **UNVERIFIED**, primary data unavailable (e.g. resource-level CE/CUR not enabled, or the Price
  List filter returns 0/many rows and the SKU can't be pinned). State the limitation; do **not**
  emit a confident dollar number.

A finding may ship only after every load-bearing figure is CONFIRMED or explicitly CORRECTED;
UNVERIFIED figures must be labeled as such in the output, never silently rounded into a total.

---

## Sources
*Verified against AWS CLI v2 (`aws pricing` / `aws ce`) and AWS docs; access date 2026-05-28.*

- AWS Price List Query API, finding services/products (`GetProducts`; endpoint Regions; `regionCode` filter): https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/using-price-list-query-api.html
- AWS CLI, `pricing get-products`: https://docs.aws.amazon.com/cli/latest/reference/pricing/get-products.html
- AWS CLI, `pricing describe-services`: https://docs.aws.amazon.com/cli/latest/reference/pricing/describe-services.html
- AWS CLI, `pricing get-attribute-values`: https://docs.aws.amazon.com/cli/latest/reference/pricing/get-attribute-values.html
- AWS Price List Bulk API (offline price list files): https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/price-changes.html
- AWS CLI, `ce get-cost-and-usage` (grouping by SERVICE / USAGE_TYPE; metrics): https://docs.aws.amazon.com/cli/latest/reference/ce/get-cost-and-usage.html
- AWS CLI, `ce get-cost-and-usage-with-resources` (resource-level; requires enablement): https://docs.aws.amazon.com/cli/latest/reference/ce/get-cost-and-usage-with-resources.html
- Cost Explorer, enabling resource-level data / hourly & resource granularity: https://docs.aws.amazon.com/cost-management/latest/userguide/ce-data.html
- AWS Cost and Usage Reports (CUR 2.0, per-line-item `resource_id`, `line_item_unblended_cost`): https://docs.aws.amazon.com/cur/latest/userguide/what-is-cur.html
- AWS Pricing Calculator (scenario modeling cross-check): https://calculator.aws/
