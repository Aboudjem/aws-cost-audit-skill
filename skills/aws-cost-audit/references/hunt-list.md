# Hunt List — the high-ROI AWS cost-audit checks

Every check below has a **verified read-only detection command**, why it saves, its
reversibility/risk, and **where to verify the price live** for the user's exact Region. This is the
working catalog the audit walks resource-by-resource (SKILL.md step 2).

> **Price discipline (Iron Law 1):** this file states **no dollar amount as fact**. Every "Price
> source" line points to the live, authoritative source — the AWS Price List Query API or the
> per-service pricing page — for the user's exact Region. Never hardcode a price.
>
> **Region discipline:** commands use `$REGION` as a parameter. Sweep **all** Regions (see
> [§22 Cross-Region ghosts](#22-cross-region-ghost-resources)); don't assume one default. The single
> exception is the Price List Query API, whose endpoint is reachable from a fixed set of Regions
> (commonly `us-east-1`) — that is an API-endpoint constraint, **not** the Region whose prices you
> are pricing. Always pass the *target* Region as a filter (`regionCode`).
>
> **Two levers:** **Rate optimization** = pay less per unit (Savings Plans, RIs, Spot, gp3, storage
> classes). **Usage optimization** = use fewer units (delete idle, rightsize, schedule-to-zero, cut
> data transfer). Most checks below are one or the other; a few are both.

---

## Contents

- [Run the managed detectors FIRST](#run-the-managed-detectors-first)
  - [AWS Cost Optimization Hub](#cost-optimization-hub)
  - [AWS Compute Optimizer](#compute-optimizer)
  - [AWS Trusted Advisor](#trusted-advisor)
- The hunt list
  1. [Idle / unassociated Elastic IPs (and the post-Feb-2024 public-IPv4 charge)](#1-idle--unassociated-elastic-ips-and-all-public-ipv4)
  2. [Unattached EBS volumes](#2-unattached-ebs-volumes)
  3. [gp2 → gp3 volume migration](#3-gp2--gp3-volume-migration)
  4. [Old EBS snapshots & orphaned AMIs](#4-old-ebs-snapshots--orphaned-amis)
  5. [NAT Gateway data-processing & cross-AZ transfer](#5-nat-gateway-data-processing--cross-az-transfer)
  6. [VPC endpoints — add gateway, remove idle interface](#6-vpc-endpoints--add-gateway-remove-idle-interface)
  7. [Idle ALB / NLB & empty target groups](#7-idle-alb--nlb--empty-target-groups)
  8. [Compute rightsizing (EC2 / ASG / RDS / ECS-Fargate)](#8-compute-rightsizing-ec2--asg--rds--ecs-fargate)
  9. [Over-provisioned Lambda memory](#9-over-provisioned-lambda-memory)
  10. [Dev/test running 24/7 → schedule to zero](#10-devtest-running-247--schedule-to-zero)
  11. [Stopped EC2 still paying for EBS](#11-stopped-ec2-still-paying-for-ebs)
  12. [Savings Plans / RI coverage + utilization](#12-savings-plans--ri-coverage--utilization)
  13. [Newer / Graviton generation migration](#13-newer--graviton-generation-migration)
  14. [S3 lifecycle — storage-class transitions](#14-s3-lifecycle--storage-class-transitions)
  15. [S3 incomplete multipart uploads](#15-s3-incomplete-multipart-uploads)
  16. [S3 versioning without lifecycle (noncurrent sprawl)](#16-s3-versioning-without-lifecycle-noncurrent-sprawl)
  17. [S3 Bucket Keys for SSE-KMS](#17-s3-bucket-keys-for-sse-kms)
  18. [CloudWatch Logs retention](#18-cloudwatch-logs-retention)
  19. [CloudWatch high-cardinality metrics & orphaned alarms](#19-cloudwatch-high-cardinality-metrics--orphaned-alarms)
  20. [CloudWatch Container Insights](#20-cloudwatch-container-insights)
  21. [Data transfer / egress](#21-data-transfer--egress)
  22. [Cross-Region ghost resources](#22-cross-region-ghost-resources)
  23. [Guardrails — Budgets + Cost Anomaly Detection](#23-guardrails--budgets--cost-anomaly-detection)
- [Reversibility / risk cheat-sheet](#reversibility--risk-cheat-sheet)
- [Where to verify prices](#where-to-verify-prices-never-hard-code)
- [Sources](#sources)

---

## Run the managed detectors FIRST

Before going resource-by-resource, three AWS services pre-compute most of this hunt list. Prefer
them: they net out your existing commitments and span Regions. The per-resource CLI in the hunt
list is for **verification**, for resources the managed services don't cover, and for accounts
where the managed services aren't enabled.

### Cost Optimization Hub

A feature of AWS Billing & Cost Management that consolidates and prioritizes cost-optimization
recommendations across AWS Organizations member accounts and Regions. It aggregates recommendation
types from **Cost Explorer** (RI / Savings Plans) and **Compute Optimizer** (rightsizing + idle),
and **accounts for your specific RIs/Savings Plans** so the displayed savings are net of existing
commitments.

```bash
aws cost-optimization-hub list-recommendations              # paginated
aws cost-optimization-hub list-recommendation-summaries
aws cost-optimization-hub get-recommendation --recommendation-id <id>
aws cost-optimization-hub list-enrollment-statuses
```

> Verified note: a `recommendationId` is valid only ~24h — recommendations refresh daily.

### Compute Optimizer

Rightsizing engine for EC2 / ASG / EBS / Lambda / ECS-on-Fargate / RDS. Analyzes config +
utilization and reports whether each resource is optimal, with cost/perf recommendations.

```bash
aws compute-optimizer get-ec2-instance-recommendations
aws compute-optimizer get-auto-scaling-group-recommendations
aws compute-optimizer get-ebs-volume-recommendations
aws compute-optimizer get-lambda-function-recommendations
aws compute-optimizer get-ecs-service-recommendations          # ECS on Fargate
```

**Verified output fields** for `get-ec2-instance-recommendations`: each item carries
`currentInstanceType`, `finding` (enum `OVER_PROVISIONED | UNDER_PROVISIONED | OPTIMIZED`),
`findingReasonCodes`, `utilizationMetrics`, and `recommendationOptions[]`. Each option carries
`savingsOpportunity` (`savingsOpportunityPercentage`, `estimatedMonthlySavings` →
`{currency, value}`), `savingsOpportunityAfterDiscounts`, and `migrationEffort`. Rank by
`estimatedMonthlySavings.value` — it is **AWS's own savings estimate**, good for ranking findings,
**not** a quoted price you may restate as fact.

### Trusted Advisor

Ships a catalog of **cost-optimization checks**. Each hunt-list item below names the matching check.
The richer checks require opting in to **Compute Optimizer** and **Cost Optimization Hub**; Trusted
Advisor surfaces those results. CLI access: `aws trustedadvisor list-recommendations` /
`list-checks`.

---

## 1. Idle / unassociated Elastic IPs (and all public IPv4)

- **What:** An allocated EIP not attached to a running resource. Note the **Feb 1, 2024** change:
  AWS now charges an hourly rate for **all public IPv4 addresses — attached or not** (previously
  only *un*associated EIPs were charged). This applies broadly (EC2, RDS, EKS nodes, etc.), so
  stale advice that "an EIP is only charged when unassociated" is **outdated** — flag it. A 12-month
  Free Tier of 750 IPv4-hours/month was added for new accounts.
- **Detect:** `aws ec2 describe-addresses --region "$REGION"`. An **unassociated** EIP is missing
  `AssociationId`, `InstanceId`, and `NetworkInterfaceId` (those appear only when associated). Use
  **Public IP Insights** (in VPC IPAM) to inventory *all* public IPv4 across the account. Trusted
  Advisor: **Unassociated Elastic IP Addresses**.
- **Why it saves:** Each idle EIP accrues an hourly charge; releasing it stops the charge
  immediately. Inventorying all public IPv4 catches the broader post-2024 charge.
- **Reversibility/risk:** Releasing is **not** reversible to the same IP — you lose that specific
  address (DNS / allowlist impact). Confirm the IP isn't referenced before `release-address`.
- **Price source:** Amazon VPC pricing page (public IPv4 address charges).

## 2. Unattached EBS volumes

- **What:** Volumes in `available` (detached) state still bill for provisioned GB.
- **Detect:** `aws ec2 describe-volumes --region "$REGION" --filters Name=status,Values=available`.
  The `status` filter values are `creating | available | in-use | deleting | deleted | error`;
  `available` = unattached. Trusted Advisor: **Underutilized Amazon EBS volumes** (flags unattached,
  or <1 IOPS/day for 7 days).
- **Why it saves:** You pay for provisioned capacity regardless of attachment.
- **Reversibility/risk:** Snapshot first, then `delete-volume`. Deletion is destructive — a detached
  volume may still hold needed data.
- **Price source:** Amazon EBS pricing page.

## 3. gp2 → gp3 volume migration

- **What:** gp3 decouples IOPS/throughput from size and is generally cheaper per GB than gp2 at the
  same baseline (rate optimization). AWS's storage blog frames gp2→gp3 as "save up to 20%" on
  per-GiB cost, with a 3,000 IOPS / 125 MiB/s baseline included regardless of size — confirm the
  exact included baseline and the per-GB / per-IOPS / per-throughput rates live.
- **Detect:** `aws ec2 describe-volumes --region "$REGION" --filters Name=volume-type,Values=gp2`.
  Compute Optimizer also surfaces EBS recommendations via `get-ebs-volume-recommendations`.
- **Migrate (verified):** `aws ec2 modify-volume --volume-id $VOL --volume-type gp3`
  (optionally `--iops`, `--throughput`). Modification is **online** for current-gen instances (no
  stop/detach). Constraints: up to 4 modifications per rolling 24h; a volume must reach `completed`
  before the next modification.
- **Why it saves:** Lower $/GB plus the included gp3 baseline.
- **Reversibility/risk:** Low risk; reversible (modify back). **Footgun:** if you "match" gp2 burst
  behaviour by over-provisioning gp3 IOPS/throughput above the free baseline, you can erase the
  savings — provision extra IOPS/throughput only when measured demand requires it.
- **Price source:** Amazon EBS pricing page (gp2 vs gp3 per-GB and per-IOPS/throughput).

## 4. Old EBS snapshots & orphaned AMIs

- **What:** Snapshots, and the snapshots backing deregistered/old AMIs, accrue storage cost.
- **Detect:** `aws ec2 describe-snapshots --owner-ids self --region "$REGION"`;
  `aws ec2 describe-images --owners self --region "$REGION"`. Cross-reference snapshot IDs against
  AMIs and in-use volumes to find orphans.
- **Clean up (verified):**
  - `aws ec2 deregister-image --image-id $AMI` (optionally `--delete-associated-snapshots`).
  - `aws ec2 delete-snapshot --snapshot-id $SNAP`.
- **Why it saves:** Snapshot storage is billed per GB of changed/stored data.
- **Reversibility/risk:** Destructive — snapshots are backups; verify no DR/compliance retention
  requirement first. Softer steps: **AMI archive** or **disable AMI**. Verified footguns:
  - You **cannot** delete a snapshot still referenced by a registered AMI ("the snapshot is
    currently in use by an AMI") — **deregister the AMI first**.
  - Deregistering an AMI does **not** delete its backing snapshots, so you keep paying for them
    unless you also delete them. After deleting any compute object, **sweep for orphaned
    snapshots/volumes/IPs it leaves behind.**
  - A **disabled** AMI still blocks its snapshot from deletion **and is hidden** from the console /
    `describe-images` by default — switch the filter to disabled images to find the blocker.
  - A snapshot shared by multiple AMIs is not deleted even if requested.
- **Price source:** Amazon EBS pricing page (snapshot storage).

## 5. NAT Gateway data-processing & cross-AZ transfer

- **What:** A NAT gateway bills a per-hour charge per gateway **plus** a per-GB data-processing
  charge **for every GB processed, regardless of source/destination**. The single most-repeated
  "non-obvious" silent cost: traffic from EC2/Lambda/containers to AWS services (S3, DynamoDB, ECR,
  CloudWatch, SQS/SNS) defaults to going *through* the NAT gateway, billing NAT processing (and
  egress if it leaves to the internet). A separate **cross-AZ footgun:** one NAT serving instances
  in other AZs incurs cross-AZ data-transfer charges in each direction (with one NAT serving 3 AZs,
  ~2/3 of traffic pays the cross-AZ fee).
- **Detect:** `aws ec2 describe-nat-gateways --region "$REGION"`; correlate with CloudWatch NAT
  metrics `BytesOutToDestination` / `BytesInFromDestination`. Trusted Advisor: **Idle NAT gateways**
  / **Inactive NAT Gateways**. Use Cost Explorer grouped by **Usage Type** to surface NAT
  data-processing line items.
- **Why it saves:** Traffic to S3/DynamoDB or chatty cross-AZ traffic routed through NAT is billed
  twice (NAT processing + transfer). Removing it from the NAT path removes both.
- **Fix:** Use **gateway VPC endpoints** for S3/DynamoDB (see §6); co-locate NAT in the same AZ as
  high-traffic instances and route intra-AZ (a NAT-per-AZ removes cross-AZ fees but adds per-gateway
  hourly charges — a volume trade-off). For low-bandwidth workloads, a self-managed NAT instance
  (e.g. the open-source **fck-nat** AMI) can be far cheaper than a managed NAT, at the cost of owning
  patching/HA and a bandwidth ceiling (small instances cap around a few Gbps burst); above that, the
  managed NAT gateway is recommended. The headline "90–99% NAT savings" blog figures are
  vendor-specific and workload-dependent — the *direction* is sound, the magnitude is unverified.
- **Reversibility/risk:** Removing/replacing NAT requires routing changes — test connectivity.
  Adding endpoints is low risk. A NAT instance shifts operational burden to you.
- **Price source:** Amazon VPC pricing page (NAT Gateway hourly + per-GB; cross-AZ data transfer).

## 6. VPC endpoints — add gateway, remove idle interface

- **What (two sub-tactics):**
  1. **Add gateway endpoints** for S3 and DynamoDB to bypass NAT data-processing. **Verified:**
     "There is no additional charge for using gateway endpoints," and gateway endpoints support
     **only S3 and DynamoDB**. Create with
     `aws ec2 create-vpc-endpoint --vpc-endpoint-type Gateway --service-name com.amazonaws.$REGION.s3 --route-table-ids ...`.
  2. **Remove idle interface (PrivateLink) endpoints** — interface endpoints carry an **hourly fee +
     per-GB** charge, so idle ones are pure waste. (Interface endpoints cover ECR, CloudWatch, SQS,
     SNS, etc., where they *are* needed.)
- **Detect:** `aws ec2 describe-vpc-endpoints --region "$REGION"`. Trusted Advisor: **Inactive VPC
  interface endpoints**, **Inactive Gateway Load Balancer endpoints**.
- **Why it saves:** Gateway endpoints eliminate NAT processing for S3/DynamoDB at zero endpoint
  cost; deleting idle interface endpoints removes hourly charges.
- **Reversibility/risk:** Adding a gateway endpoint rewrites route tables (auto-managed prefix-list
  routes you can't manually edit) — test S3/DynamoDB reachability. Deleting an interface endpoint
  breaks private DNS for that service — verify nothing depends on it.
- **Price source:** Amazon VPC pricing page (interface endpoint hourly + per-GB).

## 7. Idle ALB / NLB & empty target groups

- **What:** Any provisioned load balancer accrues charges even with no traffic; an empty target
  group signals an LB serving nothing.
- **Detect:** `aws elbv2 describe-load-balancers --region "$REGION"` +
  `aws elbv2 describe-target-groups --region "$REGION"` +
  `aws elbv2 describe-target-health --target-group-arn $TG_ARN` (no registered targets = idle).
  Trusted Advisor: **Idle Load Balancers**. **CloudWatch caveat (verified):** ELB publishes
  `RequestCount` **only when requests are flowing**, so the *absence* of `RequestCount` data points
  = no traffic; AWS recommends alarming on `UnHealthyHostCount`/host counts to detect "no registered
  targets."
- **Why it saves:** LB-hour + LCU charges with zero business value.
- **Reversibility/risk:** Deleting an LB breaks any DNS/Route 53 alias pointing at it — confirm it's
  truly unused.
- **Price source:** Elastic Load Balancing pricing page (per-hour + LCU).

## 8. Compute rightsizing (EC2 / ASG / RDS / ECS-Fargate)

- **What:** Over-provisioned compute — the biggest single usage-optimization lever for most
  accounts. Most instances are oversized because someone picked a "safe" type at setup and never
  revisited.
- **Detect (verified):** Compute Optimizer `get-ec2-instance-recommendations`,
  `get-auto-scaling-group-recommendations`, `get-ecs-service-recommendations` (Fargate). RDS
  rightsizing surfaces via Cost Optimization Hub / Trusted Advisor (**Amazon RDS cost optimization
  recommendations for DB instances**). Rank by
  `recommendationOptions[].savingsOpportunity.estimatedMonthlySavings.value`; weigh
  `finding`/`migrationEffort`.
- **Why it saves:** Move `OVER_PROVISIONED` resources to `OPTIMIZED` instance/family/size.
- **Reversibility/risk:** Resizing EC2/RDS usually needs a restart (downtime window); reversible.
  Validate against **peak-load** CloudWatch metrics (p99/max), not just averages — one low-CPU
  sample is not the fleet. **Right-size BEFORE committing** to Savings Plans/RIs (see §12).
- **Price source:** EC2 / RDS / Fargate pricing pages; Compute Optimizer's own
  `estimatedMonthlySavings` for prioritization only.

## 9. Over-provisioned Lambda memory

- **What:** Lambda bills on memory × duration; memory also scales CPU, so the cost-optimal memory
  isn't always the smallest.
- **Detect (verified):** `aws compute-optimizer get-lambda-function-recommendations`. (For an
  unqualified ARN it returns recommendations for `$LATEST`; a qualified ARN targets a specific
  version.) Trusted Advisor: **AWS Lambda over-provisioned functions for memory size**, **AWS Lambda
  functions with excessive timeouts**.
- **Why it saves:** Right-sized memory can cut cost and sometimes latency at once.
- **Reversibility/risk:** Low — a single config change
  (`update-function-configuration --memory-size`), instantly reversible. Re-test latency/timeout
  after the change.
- **Price source:** AWS Lambda pricing page.

## 10. Dev/test running 24/7 → schedule to zero

- **What:** Non-production EC2/RDS left running outside business hours. Dev/staging/QA commonly run
  24/7 but are used ~8×5 — repeatedly cited as a large, low-risk win.
- **Detect:** Inventory by tag/environment; look for instances with flat off-hours utilization.
  FinOps "Usage Optimization" explicitly calls out running resources "only when needed, particularly
  for pre-production environments."
- **Fix:** **Instance Scheduler on AWS** (an AWS Solution) uses resource tags + Lambda + EventBridge
  + a DynamoDB config table to stop/start EC2 and RDS on a schedule across Regions/accounts. AWS
  states business-hours-only scheduling can yield up to ~70% savings on those instances (vendor
  FinOps blogs cite 40–65% — directional, not guaranteed). Alternative: **Systems Manager Quick
  Setup → Resource Scheduler** for tag-based stop/start.
- **Why it saves:** Stopped EC2 stops compute charges (EBS still bills — see §2/§11); stopped RDS
  pauses compute (storage still bills).
- **Reversibility/risk:** Fully reversible (start instance). Caveats: a stopped RDS instance
  auto-restarts after 7 days; stopping breaks anything expecting 24/7 availability. Tag carefully so
  you never schedule prod.
- **Price source:** EC2 / RDS pricing pages.

## 11. Stopped EC2 still paying for EBS

- **What:** A stopped instance bills $0 compute, but its attached EBS volumes still bill.
- **Detect:** Trusted Advisor **Amazon EC2 instances stopped**;
  `aws ec2 describe-instances --region "$REGION" --filters Name=instance-state-name,Values=stopped`
  then map attached volumes.
- **Why it saves:** Long-stopped instances are often forgotten; snapshot + terminate drops the EBS
  cost.
- **Reversibility/risk:** Terminating is destructive (instance store lost; EBS deleted if
  `DeleteOnTermination=true`). Snapshot/AMI first.
- **Price source:** Amazon EBS pricing page.

## 12. Savings Plans / RI coverage + utilization

- **What (rate optimization):** Savings Plans / RIs trade a 1- or 3-year commitment for a lower rate
  vs On-Demand. Audit both **coverage** (how much eligible spend is committed) and **utilization**
  (how much of the commitment is actually used). The WAF notes SPs/RIs offer "up to 75% off
  On-Demand" and Spot "up to 90%" — confirm current figures on the pricing pages.
- **Detect (verified, under `aws ce`):**
  - `aws ce get-savings-plans-coverage` — eligible spend covered.
  - `aws ce get-savings-plans-utilization` — verified output: `Utilization` =
    `{TotalCommitment, UsedCommitment, UnusedCommitment, UtilizationPercentage}`; `Savings` =
    `{NetSavings, OnDemandCostEquivalent}`; plus `AmortizedCommitment`. **Low `UtilizationPercentage`
    / high `UnusedCommitment` = over-committed (waste).**
  - `aws ce get-savings-plans-utilization-details` — per-SP detail.
  - `aws ce get-reservation-coverage` / `aws ce get-reservation-utilization` — RI equivalents.
  - Purchase guidance: `aws ce get-savings-plans-purchase-recommendation`,
    `get-reservation-purchase-recommendation`. Trusted Advisor: **AWS Savings Plans purchase
    recommendations for compute**, **Amazon EC2 Reserved Instance optimization / lease expiration**.
- **Why it saves:** Coverage gaps = paying On-Demand unnecessarily; low utilization = paying for
  unused commitment.
- **Reversibility/risk:** **Commitments are largely irreversible.** Right-size **first**, then
  commit to the new lower baseline — commit-then-shrink leaves you paying for capacity you no longer
  use for 1–3 years. Prefer **Compute Savings Plans** for flexibility (they apply across instance
  family/size/Region/OS/tenancy and to Fargate/Lambda; EC2 Instance SPs are narrower but deeper);
  size to a conservative baseline, not peak. Exit valves to verify against live docs: Standard RIs
  can be sold on the RI Marketplace; Savings Plans cannot be sold or cancelled (a 7-day return
  window is widely repeated by the community but `UNVERIFIED` against a primary AWS doc — confirm
  before asserting). Watch **RI lease expiration** so coverage doesn't silently lapse. Never auto-run
  a purchase — always a recommendation requiring human sign-off.
- **Price source:** Savings Plans / EC2 / RDS pricing pages; `get-savings-plans-purchase-recommendation`
  for sizing.

## 13. Newer / Graviton generation migration

- **What:** Migrating EC2/RDS/Aurora to newer or **Graviton (ARM)** instance generations is a
  repeated price-performance win.
- **Detect:** Inventory current instance families (`describe-instances`, `rds describe-db-instances`)
  and compare against current-generation/Graviton equivalents; Compute Optimizer recommendations may
  point to newer families.
- **Why it saves:** Better price-performance per vCPU/GB on newer generations. Specific percentage
  gains are vendor/blog figures and vary by workload — treat as **directional**, verify live.
- **Reversibility/risk:** Requires an instance-type change (restart window) and, for Graviton, an
  **architecture change (x86 → ARM)** — validate that the workload/runtime/dependencies have ARM
  builds and re-test before switching. Reversible by changing the type back.
- **Price source:** EC2 / RDS / Aurora pricing pages (per-family rates).

## 14. S3 lifecycle — storage-class transitions

- **What:** Hot data sitting in S3 Standard that could move to IA / Glacier tiers, or be
  auto-deleted.
- **Detect:** `aws s3api get-bucket-lifecycle-configuration --bucket $BUCKET` (absence/error = no
  policy). Use **S3 Storage Lens** and **S3 Storage Class Analysis** to find cold data. Trusted
  Advisor: **Amazon S3 Bucket Lifecycle Policy Configured**.
- **Fix:** `aws s3api put-bucket-lifecycle-configuration` with `Transition`/`Expiration` rules; or
  enable **S3 Intelligent-Tiering** for unknown/changing access patterns. (Since Sept 2021, objects
  <128 KB incur no Intelligent-Tiering monitoring charge and stay in Frequent Access; for huge
  counts of small-but-≥128 KB objects, monitoring can exceed the tiering benefit — S3 Standard +
  explicit lifecycle may win. Break-even is workload-specific.)
- **Why it saves:** Lower per-GB rate on colder tiers; expiration deletes data you no longer need.
- **Reversibility/risk:** Transitions to deep-archive tiers add retrieval latency + retrieval fees;
  expiration deletes data permanently — model access patterns first. **Footgun:** archive classes
  have **minimum storage durations** (Deep Archive commonly 180 days; confirm IA/Flexible-Retrieval
  minimums on the live class table). Deleting, overwriting, **or transitioning** an object before
  its minimum incurs a prorated early-deletion fee. Aggressively lifecycling **short-lived** objects
  into Glacier/Deep Archive can cost MORE than leaving them in Standard (per-object transition
  request cost + minimum-duration charge).
- **Price source:** Amazon S3 pricing page (per-storage-class rates, retrieval, transition request
  fees, minimum-duration table).

## 15. S3 incomplete multipart uploads

- **What:** Failed/abandoned multipart uploads leave orphaned parts that bill as storage
  indefinitely.
- **Detect:** `aws s3api list-multipart-uploads --bucket $BUCKET`. Trusted Advisor: **Amazon S3
  Incomplete Multipart Upload Abort Configuration**.
- **Fix (verified):** Add a lifecycle rule with `AbortIncompleteMultipartUpload` →
  `DaysAfterInitiation` (e.g. 7) so S3 auto-aborts stale uploads and deletes their parts. Apply via
  `put-bucket-lifecycle-configuration`.
- **Why it saves:** Pure waste — billed parts that will never become an object.
- **Reversibility/risk:** Very low. Set the window longer than your largest legitimate upload
  duration so in-flight uploads aren't aborted.
- **Price source:** Amazon S3 pricing page (incomplete-upload parts bill as storage).

## 16. S3 versioning without lifecycle (noncurrent sprawl)

- **What:** Versioned buckets accumulate noncurrent versions forever without a lifecycle rule.
- **Detect:** Trusted Advisor **Amazon S3 version-enabled buckets without lifecycle policies
  configured**; check `aws s3api get-bucket-versioning --bucket $BUCKET` + the lifecycle config.
- **Fix:** Lifecycle rules with `NoncurrentVersionTransition` / `NoncurrentVersionExpiration`.
- **Why it saves:** Noncurrent versions are billed like any object.
- **Reversibility/risk:** Expiring noncurrent versions reduces rollback depth — set retention to
  match recovery needs. (Versioning + noncurrent-expiry actually makes deletes *reversible* during
  the retention window — a safety feature, not a cost of this tactic.)
- **Price source:** Amazon S3 pricing page.

## 17. S3 Bucket Keys for SSE-KMS

- **What:** Buckets using SSE-KMS call KMS once **per object** operation; KMS bills per API request,
  so high-throughput buckets rack up KMS request charges.
- **Detect:** `aws s3api get-bucket-encryption --bucket $BUCKET` — look for `SSEAlgorithm: aws:kms`
  and whether `BucketKeyEnabled` is set. Review KMS request volume in CloudWatch / Cost Explorer.
- **Fix:** Enable **S3 Bucket Keys** on the bucket — S3 generates a short-lived bucket-level key
  instead of calling KMS per object. AWS states this can reduce SSE-KMS request costs "up to 99%."
- **Why it saves:** Collapses many per-object KMS calls into far fewer bucket-level calls.
- **Reversibility/risk:** Low, and reversible (toggle off). **Footgun:** enabling Bucket Keys does
  **not** retroactively cover existing objects — re-encrypt/copy them to benefit.
- **Price source:** AWS KMS pricing page (per-request) and Amazon S3 pricing page.

## 18. CloudWatch Logs retention

- **What:** Log groups default to **never expire**, so ingested logs accrue archival storage cost
  forever ("zombie storage").
- **Detect:** `aws logs describe-log-groups --region "$REGION"` and inspect `retentionInDays` —
  **absent = never expire.** AWS Config managed rule `cw-loggroup-retention-period-check` flags this.
- **Fix (verified):** `aws logs put-retention-policy --log-group-name $GROUP --retention-in-days $N`.
  Valid `retentionInDays` values (per the `PutRetentionPolicy` API): `1, 3, 5, 7, 14, 30, 60, 90,
  120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653`. To restore
  "never expire," use `delete-retention-policy`. (`scripts/set-log-retention.sh` enforces this exact set.)
- **Why it saves:** Bounded retention caps ongoing storage spend; logs past the retention setting
  stop adding to archival storage cost.
- **Reversibility/risk:** Setting retention is reversible, but **already-expired data is gone**
  (deletion typically within ~72h of hitting the setting). Keep retention long enough for
  compliance/forensics. (Note: CloudWatch Logs bills separately for **ingestion, storage, and
  query/scan** — retention only addresses storage.)
- **Price source:** Amazon CloudWatch pricing page (logs ingestion + storage + query).

## 19. CloudWatch high-cardinality metrics & orphaned alarms

- **What:** Two adjacent CloudWatch wastes. **High-cardinality custom metrics:** publishing a custom
  metric with a high-cardinality dimension (e.g. `userId`, `requestId`) creates one billable metric
  *per unique value* — thousands of metrics from one metric name. **Orphaned alarms:** alarms on
  terminated/deleted resources don't auto-clean and keep billing.
- **Detect:** `aws cloudwatch list-metrics --region "$REGION"` — look for metric names with very many
  dimension values. `aws cloudwatch describe-alarms --region "$REGION"`, then check each alarm's
  dimensions against still-existing resources. Cost Explorer grouped by Usage Type for CloudWatch
  confirms the line item.
- **Why it saves:** Per-unique-dimension metric billing and forgotten alarms are pure waste.
- **Reversibility/risk:** Low. Removing a high-cardinality dimension changes how you can slice that
  metric — confirm nothing depends on the per-value breakdown first.
- **Price source:** Amazon CloudWatch pricing page (per-metric, per-alarm).

## 20. CloudWatch Container Insights

- **What:** Container Insights (EKS/ECS) can be a large CloudWatch line item. **Enhanced
  observability** for EKS bills **per observation** (observations scale with
  clusters/nodes/namespaces/services/workloads/pods/containers); ECS enhanced observability uses
  **flat metric pricing**; container **logs** are still billed at standard CloudWatch Logs
  rates and Container Insights adds metadata bytes per log line.
- **Detect:** Cost Explorer grouped by Usage Type for CloudWatch; review whether Container Insights /
  enhanced observability is enabled where it isn't needed; audit log retention (§18).
- **Why it saves:** Disabling on non-prod clusters, scoping metrics, and bounding log retention cut a
  frequently-oversized bill.
- **Reversibility/risk:** Reversible (toggle the feature). Don't disable observability you rely on
  for prod incident response.
- **Price source:** Amazon CloudWatch pricing page (per-observation EKS / flat ECS / logs).

## 21. Data transfer / egress

- **What:** Data transfer out to the internet, cross-Region, and cross-AZ are repeatedly the line
  items people forget. For read-heavy systems, S3 egress can exceed storage cost. A common trap:
  reading/writing a *public* S3 bucket in another Region routes over the internet (egress pricing),
  not the cheaper cross-Region path.
- **Detect:** Cost Explorer grouped by **Usage Type** / **Operation** (data-transfer line items are
  named per direction and AZ/Region boundary). Cross-reference with NAT metrics (§5) for the AWS-API
  portion.
- **Why it saves:** Egress is often a top driver that no single resource view exposes.
- **Fix:** PrivateLink / VPC endpoints (§6) keep inter-service traffic on the AWS network; gateway
  endpoints remove S3/DynamoDB from the NAT path (§5); co-locate chatty components in the same AZ.
- **Reversibility/risk:** Low for adding endpoints / re-architecting routing; test connectivity
  after route changes.
- **Price source:** Amazon VPC / EC2 / S3 pricing pages (data-transfer rates per boundary — vary by
  Region).

## 22. Cross-Region ghost resources

- **What:** Forgotten resources in Regions you don't actively use (leftover test stacks, EIPs,
  volumes, NAT GWs, endpoints, LBs).
- **Detect:** Iterate the hunt-list CLI calls across **all** Regions (`aws ec2 describe-regions` →
  loop), or use **AWS Resource Explorer** / **Config aggregator** / **Cost Explorer grouped by
  Region** to spot spend in unexpected Regions. Trusted Advisor and Cost Optimization Hub span
  Regions.
- **Why it saves:** Ghost resources are invisible in a single-Region console view but bill normally.
- **Reversibility/risk:** Same as the underlying resource type. Confirm a Region truly has no
  production footprint before sweeping.
- **Price source:** per-service pricing pages (rates vary by Region).

## 23. Guardrails — Budgets + Cost Anomaly Detection

- **What:** Detective/preventive controls so future waste is caught fast. **Important:** AWS does
  **not** offer a true hard cap that stops services — Budgets and Anomaly Detection **alert** but
  don't halt spend, so a runaway/forgotten job can bill until noticed. Wire up **Budget Actions**
  (which *can* trigger automated responses, e.g. applying a restrictive IAM policy or stopping
  instances) if you want enforcement.
- **AWS Budgets:** Set cost/usage/RI-SP-coverage/utilization budgets with alert thresholds:
  `aws budgets create-budget` / `create-notification`. Supports budget actions to auto-respond.
- **AWS Cost Anomaly Detection:** ML-based and free; create at least one **monitor** (by AWS
  Service / Linked Account / Cost Category / Cost Allocation Tag; managed or custom), attach **alert
  subscriptions** with dollar/percent thresholds delivered via SNS/email (individual or
  daily/weekly digests); begins working within ~24h, more accurate after a few weeks. Now enabled by
  default for new Cost Explorer users. CLI under `aws ce`: `create-anomaly-monitor`,
  `create-anomaly-subscription`, `get-anomalies` (and `get-anomaly-monitors` to check what exists).
- **Why it saves:** Turns one-time audit wins into durable control; catches regressions and surprise
  spend.
- **Reversibility/risk:** No resource risk. Tune thresholds to avoid alert fatigue.
- **Price source:** Cost Anomaly Detection and most Budgets usage are free per AWS; confirm current
  Budgets free-tier/limits on the AWS Cost Management pricing page.

---

## Reversibility / risk cheat-sheet

| Reversibility | Tactics |
|---|---|
| **Low risk, easily reversible** | gp2→gp3 (§3), Lambda memory (§9), dev scheduling (§10), add gateway endpoints (§6), S3 Bucket Keys (§17), log retention set (§18), high-cardinality metric/alarm cleanup (§19), Container Insights toggle (§20), Budgets/Anomaly Detection (§23) |
| **Reversible but needs a maintenance window** | EC2/RDS rightsizing & restart (§8), Graviton/newer-generation migration (§13) |
| **Destructive — snapshot/verify first** | Release EIP (§1), delete unattached EBS (§2), delete snapshots / deregister AMIs (§4), terminate stopped EC2 (§11), delete idle LB (§7), delete interface endpoint (§6), S3 expiration / transition to deep archive (§14/§16) |
| **Largely irreversible — commit cautiously, never auto-run** | Savings Plans / RI purchases (§12) |

---

## Where to verify prices (NEVER hard-code)

- **AWS Price List Query API** — programmatic, current public prices.
  `aws pricing get-products --service-code <code> --filters ...`; discover attributes via
  `describe-services` / `get-attribute-values`. Always pass the **target Region** as a
  `regionCode` filter (the API endpoint itself is reachable only from a fixed set of Regions, e.g.
  `us-east-1` — that is not the Region you are pricing). Use this in automation for live, per-Region
  rates.
- **AWS Price List Bulk API** — bulk price-list files for offline analysis.
- **AWS Pricing Calculator** (`calculator.aws`) — model scenarios / estimate before changes.
- **Per-service pricing pages** — EC2, EBS, S3, VPC (NAT + endpoints + data transfer), CloudWatch,
  Lambda, ELB, RDS, KMS, Savings Plans. Authoritative for the headline rates this file deliberately
  does not quote.
- **Compute Optimizer / Cost Optimization Hub `estimatedMonthlySavings`** — AWS's own savings
  estimates, good for **ranking** findings (estimates, not quotes you may restate as fact).

---

## Sources

*All accessed 2026-05-28. Carried from the research notes `docs/research/03-aws-cost-tactics.md` and
`docs/research/04-practitioner-intel.md` (which hold the corroboration labels). No dollar amount in
this file is stated as fact — verify every price live.*

**Frameworks**
- AWS Well-Architected Framework — Cost Optimization Pillar (welcome / design goals): https://docs.aws.amazon.com/wellarchitected/latest/cost-optimization-pillar/welcome.html
- AWS Well-Architected Framework — Cost Optimization pillar (framework page): https://docs.aws.amazon.com/wellarchitected/latest/framework/cost-optimization.html
- WAF COST08-BP03 Implement services to reduce data transfer costs: https://docs.aws.amazon.com/wellarchitected/latest/cost-optimization-pillar/cost_data_transfer_implement_services.html
- FinOps Foundation — Framework Overview: https://www.finops.org/framework/
- FinOps Foundation — Domains: https://www.finops.org/framework/domains/
- FinOps Foundation — Capabilities (incl. Usage Optimization): https://www.finops.org/framework/capabilities/
- FinOps Foundation — 2025 Framework (Scopes added): https://www.finops.org/insights/2025-finops-framework/

**Managed detectors**
- AWS Trusted Advisor — Cost optimization checks (check names): https://docs.aws.amazon.com/awssupport/latest/user/cost-optimization-checks.html
- AWS Trusted Advisor — opt in to Compute Optimizer for checks: https://docs.aws.amazon.com/awssupport/latest/user/compute-optimizer-with-trusted-advisor.html
- "Optimize Your AWS Spend with New Cost Savings Features in AWS Trusted Advisor" (Cost Optimization Hub), AWS Cloud Financial Management blog (June 5, 2025): https://aws.amazon.com/blogs/aws-cloud-financial-management/optimize-your-aws-spend-with-new-cost-savings-features-in-aws-trusted-advisor/
- AWS Cost Optimization Hub — CLI reference: https://docs.aws.amazon.com/cli/latest/reference/cost-optimization-hub/
- Cost Optimization Hub — list-recommendations: https://docs.aws.amazon.com/cli/latest/reference/cost-optimization-hub/list-recommendations.html
- Cost Optimization Hub — get-recommendation: https://docs.aws.amazon.com/cli/latest/reference/cost-optimization-hub/get-recommendation.html
- Compute Optimizer — get-ec2-instance-recommendations: https://docs.aws.amazon.com/cli/latest/reference/compute-optimizer/get-ec2-instance-recommendations.html
- Compute Optimizer — get-lambda-function-recommendations: https://docs.aws.amazon.com/cli/latest/reference/compute-optimizer/get-lambda-function-recommendations.html
- Compute Optimizer — get-ecs-service-recommendations: https://docs.aws.amazon.com/cli/latest/reference/compute-optimizer/get-ecs-service-recommendations.html
- Compute Optimizer — get-auto-scaling-group-recommendations: https://docs.aws.amazon.com/cli/latest/reference/compute-optimizer/get-auto-scaling-group-recommendations.html

**Per-tactic primary docs**
- EC2 describe-volumes (status filter values): https://docs.aws.amazon.com/cli/latest/reference/ec2/describe-volumes.html
- EC2 describe-addresses (EIP association fields): https://docs.aws.amazon.com/cli/latest/reference/ec2/describe-addresses.html
- Public IPv4 charge + Public IP Insights (AWS News Blog): https://aws.amazon.com/blogs/aws/new-aws-public-ipv4-address-charge-public-ip-insights/
- Free Tier 750h public IPv4 (What's New, Feb 2024): https://aws.amazon.com/about-aws/whats-new/2024/02/aws-free-tier-750-hours-free-public-ipv4-addresses/
- EC2 modify-volume (gp2→gp3, online modify, constraints): https://docs.aws.amazon.com/cli/latest/reference/ec2/modify-volume.html
- gp2→gp3 migration & savings (AWS Storage Blog): https://aws.amazon.com/blogs/storage/migrate-your-amazon-ebs-volumes-from-gp2-to-gp3-and-save-up-to-20-on-costs/
- EC2 deregister-image (--delete-associated-snapshots, constraints): https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/deregister-ami.html
- Disable AMI (hidden blocker): https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/disable-an-ami.html
- Disabled-AMI hidden-blocker (re:Post article): https://repost.aws/articles/ARcOiSQa0QRxeImuPWRv3_qQ/why-do-i-get-an-error-the-snapshot-is-currently-in-use-by-ami-when-i-try-to-delete-an-ebs-snapshot-even-though-there-is-no-ami-on-the-account
- Snapshot "in use by AMI" (re:Post KB): https://repost.aws/knowledge-center/snapshot-in-use-error
- EC2 delete-snapshot (constraints): https://docs.aws.amazon.com/ebs/latest/userguide/ebs-deleting-snapshot.html
- Controlling cost by deleting unused EBS (AWS Cloud Ops Blog): https://aws.amazon.com/blogs/mt/controlling-your-aws-costs-by-deleting-unused-amazon-ebs-volumes/
- VPC Gateway endpoints (no charge; S3/DynamoDB only; routing): https://docs.aws.amazon.com/vpc/latest/privatelink/gateway-endpoints.html
- Reduce data transfer charges for a NAT gateway (AWS re:Post KB): https://repost.aws/knowledge-center/vpc-reduce-nat-gateway-transfer-costs
- Amazon VPC Pricing (NAT GW, endpoints, IPv4, data transfer): https://aws.amazon.com/vpc/pricing/
- fck-nat (open-source NAT-instance alternative) — repo: https://github.com/AndrewGuenther/fck-nat ; docs: https://fck-nat.dev/v1.4.0/
- ELB — CloudWatch metrics for ALB (RequestCount only when traffic flows): https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-cloudwatch-metrics.html
- S3 — Configure lifecycle to delete incomplete multipart uploads (AbortIncompleteMultipartUpload / DaysAfterInitiation): https://docs.aws.amazon.com/AmazonS3/latest/userguide/mpu-abort-incomplete-mpu-lifecycle-config.html
- S3 — Examples of S3 Lifecycle configurations: https://docs.aws.amazon.com/AmazonS3/latest/userguide/lifecycle-configuration-examples.html
- S3 lifecycle transition considerations (minimum durations): https://docs.aws.amazon.com/AmazonS3/latest/userguide/lifecycle-transition-general-considerations.html
- S3 archival storage (Glacier minimums): https://docs.aws.amazon.com/AmazonS3/latest/userguide/archival-storage.html
- S3 Glacier Deep Archive early-delete fee (re:Post): https://www.repost.aws/questions/QUXN4-OJkTReG5j7p_nK63vA/s3-glacier-deep-archive-early-delete-fee
- S3 Intelligent-Tiering small-object monitoring removed (What's New 2021): https://aws.amazon.com/about-aws/whats-new/2021/09/amazon-s3-intelligent-tiering-automates-storage-savings/
- S3 Intelligent-Tiering class page: https://aws.amazon.com/s3/storage-classes/intelligent-tiering/
- S3 Bucket Keys reduce KMS up to 99% (AWS Storage Blog): https://aws.amazon.com/blogs/storage/reducing-aws-key-management-service-costs-by-up-to-99-with-s3-bucket-keys/
- S3 Bucket Keys (S3 User Guide): https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucket-key.html
- CloudWatch Logs — PutRetentionPolicy (default never expire; retentionInDays values): https://docs.aws.amazon.com/AmazonCloudWatchLogs/latest/APIReference/API_PutRetentionPolicy.html
- CloudWatch Logs — put-retention-policy CLI: https://docs.aws.amazon.com/cli/latest/reference/logs/put-retention-policy.html
- CloudWatch Logs — log groups & streams (retention default): https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/Working-with-log-groups-and-streams.html
- AWS Config — cw-loggroup-retention-period-check: https://docs.aws.amazon.com/config/latest/developerguide/cw-loggroup-retention-period-check.html
- Amazon CloudWatch pricing (logs ingestion/storage/query; per-observation EKS / flat ECS): https://aws.amazon.com/cloudwatch/pricing/
- "Diving into Container Insights cost optimizations for Amazon EKS" (AWS containers blog): https://aws.amazon.com/blogs/containers/diving-into-container-insights-cost-optimizations-for-amazon-eks/
- Amazon CloudWatch — Container Insights: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/ContainerInsights.html
- Cost Explorer — get-savings-plans-utilization (Utilization/Savings fields): https://docs.aws.amazon.com/cli/latest/reference/ce/get-savings-plans-utilization.html
- Cost Explorer — get-savings-plans-coverage: https://docs.aws.amazon.com/cli/latest/reference/ce/get-savings-plans-coverage.html
- Cost Explorer (ce) command index: https://docs.aws.amazon.com/cli/latest/reference/ce/
- Compute Savings Plans vs RIs (Savings Plans User Guide): https://docs.aws.amazon.com/savingsplans/latest/userguide/sp-ris.html
- Instance Scheduler on AWS — solution overview (stop/start EC2 & RDS; ~70% claim): https://docs.aws.amazon.com/solutions/latest/instance-scheduler-on-aws/solution-overview.html
- Systems Manager — Schedule stop/start via Quick Setup: https://docs.aws.amazon.com/systems-manager/latest/userguide/quick-setup-scheduler.html
- AWS Cost Anomaly Detection — getting started: https://docs.aws.amazon.com/cost-management/latest/userguide/getting-started-ad.html
- AWS Cost Anomaly Detection — product page + FAQ: https://aws.amazon.com/aws-cost-management/aws-cost-anomaly-detection/ , https://aws.amazon.com/aws-cost-management/aws-cost-anomaly-detection/faqs/
- Anomaly Detection on by default for new Cost Explorer users: https://aws.amazon.com/blogs/aws-cloud-financial-management/new-aws-cost-explorer-users-can-now-automatically-detect-cost-anomalies/
- AWS Price List Query API — finding services/products (GetProducts): https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/using-price-list-query-api.html
- AWS Pricing CLI — get-products: https://docs.aws.amazon.com/cli/latest/reference/pricing/get-products.html
