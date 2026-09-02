# Output and reporting

How to turn verified findings into a report a non-technical reader can act on. This is the
implementation of **Law 5** (every finding carries its evidence) and **Law 2** (attribute every
dollar, or say "unknown"). Nothing here invents a price, every dollar comes from the live price
source plus actual usage (Law 1).

## The output contract (per finding)

Every finding states the same five things, in this order:

```
current $/mo  →  after $/mo  →  $ saved  →  confidence (High / Medium / Low)
   + evidence (the exact read-only command or metric that proves it)
   + reversibility (how to undo it, or "irreversible, sign-off required")
```

- **current $/mo**, verified from Cost Explorer / CUR for the user's account, reconciled to the
  unit price for their exact Region. Never from memory.
- **after $/mo**, what the line item becomes if the action is taken. Often `$0` (delete) or a lower
  rate (gp2→gp3, rightsizing). Show the math.
- **$ saved**, `current − after`. If you cannot verify `current`, you cannot state `$ saved`; write
  "unknown, could not verify the live cost" instead of a guess.
- **confidence**, High / Medium / Low. See the rubric below. The confidence level decides which
  total a finding rolls up into.
- **evidence**, the exact read-only command(s) or CloudWatch metric that proves the resource is
  unused / mis-sized / mis-priced. A reader (or a skeptic pass) must be able to re-run it.
- **reversibility**, the precise rollback (snapshot-first, re-attach, raise retention again,
  re-enable), or the words "irreversible, requires explicit owner sign-off" for EIP release,
  snapshot/AMI delete, terminate, and Savings Plan / RI purchase.

### Confidence rubric

| Confidence | Means | Rolls up into |
|---|---|---|
| **High** | Proven unused by multiple live signals over 30–90d, reversible, dry-run tested, blast radius 100% understood. | **Save now safely** |
| **Medium** | Strong signal but one gap, shorter look-back, single metric, needs an owner to confirm it is not a warm standby. | **Max theoretical save** (flagged) |
| **Low** | Plausible from one probe, not yet re-derived, or depends on a behavior change (commitment purchase, architecture change). | **Max theoretical save** (flagged, sign-off) |

## The two totals: "save now safely" vs "maximum theoretical save"

Split the headline number in two so nobody confuses "safe to do today" with "best case if
everything lines up." Never blend them into one figure.

- **Save now safely = $Y.** Sum of **High-confidence** findings only, reversible, tested, and (for
  anything destructive) snapshot-first. These are the items the gate (see
  `references/safety-and-gating.md`) would allow to auto-run.
- **Maximum theoretical save = $Z.** `$Y` plus all **Medium / Low** findings and anything needing
  owner sign-off (EIP release, snapshot/AMI delete, terminate, Savings Plan / RI purchase, rightsizing
  that needs a restart window). Every item in the `$Z − $Y` gap is **clearly flagged** with why it
  is not in `$Y` and what would have to be true to move it there. **Nothing in this bucket auto-runs.**

State both, always, e.g. *"Save now safely: $Y/mo. Maximum theoretical save: $Z/mo (the extra
$Z−$Y needs the sign-offs flagged below)."*

## Artifact 1: the per-item finding template (copy this block)

A reader can copy this fenced block per finding. Keep prose plain; no jargon a non-engineer would
not recognize.

```
### <plain-language name of the thing>: <KEEP | OPTIMIZE | SAFE-TO-DELETE>

- What it costs:   $<current $/mo, verified>  →  $<after $/mo>   =   $<saved>/mo saved
- Confidence:      <High | Medium | Low>
- What it is:      <one simple sentence a non-technical reader understands>
- Belongs to:      <app / repo name, or "unknown">
- Created by:      <CloudTrail username, or "unknown">
- Created when:    <date, or "unknown, predates the CloudTrail window">
- Last used:       <date / metric, or "unknown, could not verify">
- Why this verdict: <one line, the signal(s) that justify KEEP/OPTIMIZE/SAFE-TO-DELETE>
- Evidence:        <the exact read-only command(s) / metric that proves the above>
- Price source:    <Price List API filter used + the usage figure from Cost Explorer / CUR>
- Reversibility:   <exact rollback, or "irreversible, requires explicit owner sign-off">
```

Rules for filling it in:

- Any field you could not establish from an API is literally **"unknown, could not verify"** (Law 2).
  Never infer an owner from a resource name, never guess a date.
- `What it costs` must show the math trail in `Price source` so a skeptic can re-derive it (Law 4).
- The verdict tag matches the classification step: **KEEP** (in use / cost justified),
  **OPTIMIZE** (cheaper config, same function, e.g. gp2→gp3, raise log retention, rightsize),
  **SAFE-TO-DELETE** (proven unused; still only a *recommendation* until snapshot + dry-run + sign-off).

## Machine-readable contract: `findings.json`

Everything above is written for a person. A second audit cannot diff against the first from prose,
so a run may also emit `findings.json`. Treat it as the **machine-checkable core** of the contract
above, not a replacement for it. The prose contract still governs the `current -> after -> saved`
math trail and the price source; the JSON pins the fields a tool can check.

JSON, never YAML. The runtime here is bash plus `jq`, with no YAML parser in it, and adding one
would break the promise that the skill shells out to a CLI you already have. (CI runs Python, but
CI is not the runtime.)

Shape: an object with `schema_version` (string) and `findings` (array). Every finding carries these
nine keys.

| key | type | meaning |
|---|---|---|
| `id` | string | unique within the file. Keep it stable across runs so two audits can be diffed; the validator can only check uniqueness, not stability. |
| `resource` | string | the resource identifier, or a placeholder such as `vol-EXAMPLE` |
| `region` | string | the region the resource lives in |
| `service` | string | the AWS service it belongs to |
| `monthly_cost_estimate` | number or `null` | `null` is the machine form of "unknown, could not verify" (Law 2). Never write a guess here. |
| `evidence` | string | the exact read-only command or metric that proves the finding (Law 5) |
| `action` | string | `KEEP`, `OPTIMIZE`, or `SAFE-TO-DELETE` |
| `reversible` | boolean | `false` means the action needs explicit owner sign-off |
| `confidence` | string | `High`, `Medium`, or `Low`, per the rubric above |

Eight further keys are optional. They carry the rest of the Artifact 1 block when a run chooses to
emit it, and they are type-checked when present: `after_monthly_cost` and `monthly_saving` (number
or `null`), `purpose`, `owner`, `created_by`, `created_when`, `last_used`, and `price_source`
(strings). Any other key is rejected, so the file cannot drift into a private dialect.

Check a file before you publish it:

```bash
skills/aws-cost-audit/scripts/findings-validate.sh cost-audit-out/findings.json
```

Exit `0` means the file satisfies the contract and prints the finding count. Exit `1` prints one
`[FAIL]` line per problem, including every top-level problem rather than only the first. Exit `2`
prints `[ERROR]` and means the file could not be checked at all: no file, not readable as JSON, or
`jq` is not installed. A file is never reported valid unchecked.

Nothing in this repository, fixtures included, carries a monthly cost figure. `CONTRIBUTING.md`
forbids writing a unit price, a monthly cost, or a saved amount into the skill, a script, a
reference or an example, so the committed fixtures use `null` and the test that exercises the
numeric branch builds its file at run time from a computed value.

## Artifact 2: the report skeleton

Order matters: start with what they pay, then what is safe today, then the upside, then the detail,
then guardrails, then honesty about coverage. Sections:

```
# AWS cost audit: <account alias or "<your-account>">, <date>, region(s) inspected: <list>

## 1. What you pay today
- Total verified spend: $<total>/mo  (source: Cost Explorer, <date range>, reconciled to the dollar)
- By service (verified, USD/mo), largest first:
  | Service | $/mo | % of bill |
  |---|---|---|
  | <service> | $<n> | <n>% |
- By region / by usage-type breakdown attached as raw JSON: <path to saved Cost Explorer output>

## 2. Save now safely: $<Y>/mo
High-confidence, reversible, dry-run tested. Each item: current → after / $ saved / confidence /
evidence / rollback. (These are the only items the gate would let auto-run.)
  <one per-item finding block from Artifact 1 per finding, all High confidence>

## 3. Maximum theoretical save: $<Z>/mo
Everything in §2 PLUS Medium/Low findings and anything needing owner sign-off. Each extra item is
flagged with: why it is not yet "safe now", and what must be true to move it up.
  | Item | $/mo saved | Confidence | Why not in §2 | What it needs |
  |---|---|---|---|---|
  | <item> | $<n> | Med/Low | <reason> | <sign-off / restart window / longer look-back> |
  <full per-item finding blocks below the table>

## 4. Per-resource cards
One card per material resource (the Artifact-1 block), grouped by service or by app. This is the
"what is this and why am I paying for it" reference, readable by a non-technical owner.

## 5. Health, monitoring & guardrails
- Budgets: <exists? `aws budgets describe-budgets` result> → recommend a monthly budget + alert.
- Anomaly detection: <`aws ce get-anomaly-monitors` result> → recommend enabling if absent.
- Commitment coverage: Savings Plans / RI coverage & utilization (verified), and whether gaps exist.
- Tagging / attribution health: % of spend that is untagged or "unknown" owner.

## 6. Completeness pass: what we did NOT inspect
List every region, service, or cost driver not yet examined and why (no data, out of scope, blocked
by permissions). This section MUST end empty for a complete audit, if it is non-empty, the audit is
not done. Note any IAM permission that blocked a read so the user can grant it and re-run.
```

Formatting guidance: lead with the totals, keep tables skimmable, put the long evidence commands in
the per-item blocks (not in the summary tables), and never present `$Y` and `$Z` as one number.

## Artifact 3: worked mini example (models the no-hardcoded-price rule)

This shows the contract end to end. The price is left as a **placeholder** on purpose: in a real run
you replace `<live $/GB-mo from Price List API>` with the value returned for the user's exact Region,
and you show the query and the math. **Do not substitute a remembered price here.**

```
### Unattached 100 GB gp3 disk in <region>: SAFE-TO-DELETE

- What it costs:   $<live $/GB-mo from Price List API × 100 GB>/mo  →  $0/mo   =   $<same>/mo saved
- Confidence:      High
- What it is:      A 100 GB storage disk that is not connected to any server.
- Belongs to:      unknown (no tags on the volume)
- Created by:      unknown, predates the CloudTrail look-back window
- Created when:    unknown, predates the CloudTrail look-back window
- Last used:       no read or write activity for 90 days (CloudWatch VolumeReadOps/WriteOps = 0)
- Why this verdict: detached, zero I/O for 90 days, no references found, proven unused.
- Evidence:
    aws ec2 describe-volumes --region <region> \
      --filters Name=status,Values=available \
      --query 'Volumes[].{id:VolumeId,gb:Size,type:VolumeType}'
    aws cloudwatch get-metric-statistics --namespace AWS/EBS --metric-name VolumeReadOps \
      --dimensions Name=VolumeId,Value=vol-EXAMPLE --start-time <90d-ago> --end-time <now> \
      --period 86400 --statistics Sum --region <region>      # returns 0 across the window
- Price source:
    aws pricing get-products --service-code AmazonEC2 --region us-east-1 \
      --filters "Type=TERM_MATCH,Field=productFamily,Value=Storage" \
                "Type=TERM_MATCH,Field=volumeApiName,Value=gp3" \
                "Type=TERM_MATCH,Field=regionCode,Value=<region>" \
      --query 'PriceList' --output text
    # parse the per-GB-month USD rate from the returned JSON; multiply by 100 GB.
    # cross-check against the actual gp3 storage line in Cost Explorer (by usage-type) for this account.
- Reversibility:   Take a snapshot first, then delete. The disk is fully restorable from the snapshot.
```

How this models the rule: the dollar amount is never written as a literal. It is expressed as
`<live $/GB-mo from Price List API × 100 GB>`, the exact query that produces the rate is shown, and
it is cross-checked against the account's own usage. A skeptic pass (Law 4) re-runs the same query
to confirm the headline. If the Price List query cannot be run, the finding states the cost as
"unknown, could not verify the live cost" rather than guessing, and it does not roll up into `$Y`.
