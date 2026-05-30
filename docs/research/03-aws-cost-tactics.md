# AWS Cost-Optimization Tactics: The High-ROI Audit "Hunt List"

> Research note for a generic, reference-grade "AWS cost audit" Claude Code skill.
> All load-bearing claims are cited to primary/authoritative sources (see `## Sources`).
> **Access date: 2026-05-28.**
>
> **PRICE DISCIPLINE:** This note states NO specific dollar amounts as fact. Where money
> matters, it points to the live, authoritative price source (AWS Price List API / Pricing
> Calculator / the per-service pricing page). Always confirm prices live, per-Region.

---

## 0. Framing: where these tactics come from

Two authoritative frameworks anchor the hunt list:

### AWS Well-Architected Framework: Cost Optimization Pillar
The pillar organizes cost work into five goal areas (quoted from the pillar whitepaper,
publication date June 27, 2024):

- **Practice Cloud Financial Management**
- **Expenditure and usage awareness**
- **Cost effective resources**
- **Manage demand and supply resources**
- **Optimize over time**

A cost-optimized workload "fully utilizes all resources, achieves an outcome at the lowest
possible price point, and meets your functional requirements." (WAF Cost Optimization Pillar,
`welcome.html`.) Pricing-model tactics (Savings Plans, RIs, Spot) live under *Cost effective
resources*; idle/unused-resource cleanup and scheduling live under *Manage demand and supply*
and *Expenditure and usage awareness*.

### FinOps Foundation Framework (2025)
The 2025 Framework has **four Domains** (`finops.org/framework/domains/`):

1. **Understand Usage & Cost**, Data Ingestion, Allocation, Reporting & Analytics, Anomaly Management
2. **Quantify Business Value**, Planning & Estimating, Forecasting, Budgeting, KPIs & Benchmarking, Unit Economics
3. **Optimize Usage & Cost**, Architecting & Workload Placement, **Rate Optimization**, **Usage Optimization**, Sustainability, Licensing & SaaS
4. **Manage the FinOps Practice**, FinOps Practice Operations; Governance, Policy & Risk; FinOps Assessment; Automation, Tools & Services; FinOps Education & Enablement; Invoicing & Chargeback; Intersecting Disciplines; Executive Strategy Alignment

The 2025 revision adds **Scopes** as a core element (a defined segment of tech spend aligned to
business constructs). The **Usage Optimization** capability is defined as "a set of practices
that ensure resources across all FinOps Scopes are properly selected, correctly sized, only run
when needed, appropriately configured, and highly utilized." (`finops.org/framework/capabilities/`
, Usage Optimization page.) This is the FinOps analog of the WAF *Manage demand and supply* +
*Cost effective resources* work and maps directly onto the hunt list below.

**Two big levers, framework-agnostic:**
- **Rate optimization** = pay less per unit (Savings Plans, RIs, Spot, gp3, storage classes). FinOps "Rate Optimization."
- **Usage optimization** = use fewer units (delete idle, rightsize, schedule-to-zero, cut data transfer). FinOps "Usage Optimization."

---

## 1. Cross-cutting detection tooling (run these FIRST)

Before going resource-by-resource, three AWS services pre-compute most of the hunt list. Prefer
them; the per-resource CLI below is for verification, for resources the managed services don't
cover, and for environments where the managed services aren't enabled.

### AWS Trusted Advisor: Cost Optimization category
Trusted Advisor ships a large catalog of **cost optimization checks**. Exact check names verified
from the AWS Support docs (`awssupport/.../cost-optimization-checks.html`) include:

- **Low utilization Amazon EC2 instances**
- **Idle Load Balancers**
- **Underutilized Amazon EBS volumes**
- **Unassociated Elastic IP Addresses**
- **Amazon RDS idle DB instances**
- **AWS Savings Plans purchase recommendations for compute**
- **Amazon EC2 Reserved Instance optimization** / **Amazon EC2 Reserved Instance lease expiration**
- **Idle NAT gateways** / **Inactive NAT Gateways**
- **Inactive VPC interface endpoints** / **Inactive Gateway Load Balancer endpoints**
- **Amazon S3 Bucket Lifecycle Policy Configured** / **Amazon S3 Incomplete Multipart Upload Abort Configuration** / **Amazon S3 version-enabled buckets without lifecycle policies configured**
- **Amazon ECR Repository without lifecycle policy configured**
- Compute-Optimizer-backed: **Amazon EC2 / RDS / Lambda / EBS / Auto Scaling / Fargate cost optimization recommendations**, **over-provisioned** variants, etc.
- **Amazon EC2 instances stopped** (stopped instances still incur EBS storage)

> Many of the richer checks require opting in to **AWS Compute Optimizer** and **Cost Optimization Hub**; Trusted Advisor surfaces those results. (AWS Support docs; "Optimize Your AWS Spend with New Cost Savings Features in AWS Trusted Advisor", AWS Cloud Financial Management blog.)
> CLI access: `aws trustedadvisor list-recommendations` / `list-checks` (TrustedAdvisor API).

### AWS Cost Optimization Hub
A feature of AWS Billing & Cost Management that **"consolidates and prioritizes cost optimization
recommendations across AWS Organizations member accounts and AWS Regions."** It aggregates 16+
recommendation types from **Cost Explorer** (RI / Savings Plans) and **Compute Optimizer**
(rightsizing + idle), and **accounts for your specific RIs/Savings Plans** so the displayed savings
are net of existing commitments. (AWS Cloud Financial Management blog, Cost Optimization Hub, dated June 5, 2025.)

CLI (verified to exist in `cli/latest/reference/cost-optimization-hub/`):
```bash
aws cost-optimization-hub list-recommendations            # paginated
aws cost-optimization-hub list-recommendation-summaries
aws cost-optimization-hub get-recommendation --recommendation-id <id>
aws cost-optimization-hub list-enrollment-statuses
```
> Note (verified): `get-recommendation`'s `recommendationId` is valid only up to ~24h, > recommendations refresh daily.

### AWS Compute Optimizer (rightsizing engine for EC2 / ASG / EBS / Lambda / ECS-on-Fargate / RDS)
Analyzes config + utilization and reports whether resources are optimal, with cost/perf
recommendations. (Compute Optimizer docs.) Key CLI (all verified in `cli/latest/reference/compute-optimizer/`):
```bash
aws compute-optimizer get-ec2-instance-recommendations
aws compute-optimizer get-auto-scaling-group-recommendations
aws compute-optimizer get-ebs-volume-recommendations
aws compute-optimizer get-lambda-function-recommendations
aws compute-optimizer get-ecs-service-recommendations          # ECS on Fargate
```
**Verified output fields** for `get-ec2-instance-recommendations`: each item has `currentInstanceType`,
`finding` (API enum values `OVER_PROVISIONED` | `UNDER_PROVISIONED` | `OPTIMIZED`), `findingReasonCodes`,
`utilizationMetrics`, and `recommendationOptions[]`. Each option carries `savingsOpportunity`
(`savingsOpportunityPercentage`, `estimatedMonthlySavings` → `{currency, value}`) and
`savingsOpportunityAfterDiscounts`, plus `migrationEffort`. Use `estimatedMonthlySavings.value`
for ranking, it is a savings *estimate from AWS*, not a quoted price.

---

## 2. The Hunt List (tactic-by-tactic)

For each: **What** · **Detect** (verified CLI/API/metric) · **Why it saves** · **Reversibility/risk** · **Price source**.

### 2.1 Idle / unassociated Elastic IPs (EIPs)
- **What:** An allocated EIP that is not attached to a running resource. AWS charges for idle/unassociated public IPv4.
- **Detect:** `aws ec2 describe-addresses`. An **unassociated** EIP is missing `AssociationId`, `InstanceId`, and `NetworkInterfaceId` in the output (those fields are present only when associated). Trusted Advisor check: **Unassociated Elastic IP Addresses**.
- **Why:** Each idle EIP accrues an hourly charge; releasing it stops the charge immediately.
- **Reversibility/risk:** Releasing is **not** reversible to the same IP, you lose that specific address (DNS/allowlist impact). Confirm the IP isn't referenced before `release-address`.
- **Price source:** Amazon VPC pricing page (public IPv4 address charges).

### 2.2 Unattached EBS volumes
- **What:** Volumes in `available` (detached) state still bill for provisioned GB.
- **Detect (verified):** `aws ec2 describe-volumes --filters Name=status,Values=available`. The `status` filter values are `creating | available | in-use | deleting | deleted | error`; `available` = unattached. Trusted Advisor: **Underutilized Amazon EBS volumes** (yellow when unattached or <1 IOPS/day for 7 days).
- **Why:** You pay for provisioned capacity regardless of attachment.
- **Reversibility/risk:** Snapshot first, then `delete-volume`. Deletion is destructive; a detached volume may still hold needed data.
- **Price source:** Amazon EBS pricing page.

### 2.3 gp2 → gp3 volume migration (rate optimization)
- **What:** gp3 decouples IOPS/throughput from size and is generally cheaper per GB than gp2 at the same baseline.
- **Detect:** `aws ec2 describe-volumes --filters Name=volume-type,Values=gp2`. Compute Optimizer also surfaces EBS recommendations via `get-ebs-volume-recommendations`.
- **Migrate (verified):** `aws ec2 modify-volume --volume-id vol-... --volume-type gp3` (optionally `--iops`, `--throughput`). Modification is **online** for current-gen instances (no stop/detach needed). Constraints (verified): up to 4 modifications per rolling 24h; a volume must reach `completed` before the next modification.
- **Why:** Lower $/GB plus 3000 IOPS / 125 MiB/s baseline included on gp3 (verify exact included baseline + price on the EBS pricing page).
- **Reversibility/risk:** Low risk; reversible (modify back). Validate that workloads needing gp2 burst credits get adequate gp3 baseline.
- **Price source:** Amazon EBS pricing page (gp2 vs gp3 per-GB and per-IOPS/throughput).

### 2.4 Old EBS snapshots & orphaned AMIs
- **What:** Snapshots and the snapshots backing deregistered/old AMIs accrue storage cost.
- **Detect:** `aws ec2 describe-snapshots --owner-ids self`; `aws ec2 describe-images --owners self`. Cross-reference snapshot IDs against AMIs and in-use volumes to find orphans.
- **Clean up (verified):**
  - `aws ec2 deregister-image --image-id ami-...` (optionally `--delete-associated-snapshots`).
  - `aws ec2 delete-snapshot --snapshot-id snap-...`.
  - **Constraint (verified):** you can't delete a snapshot of an AMI's root device until the AMI is deregistered; a snapshot shared by multiple AMIs is not deleted even if requested.
- **Why:** Snapshot storage is billed per GB of changed/stored data.
- **Reversibility/risk:** Destructive. Snapshots are backups, verify no DR/compliance retention requirement first. Consider **AMI archive** (`ami-archive`) or **disable AMI** as softer steps.
- **Price source:** Amazon EBS pricing page (snapshot storage).

### 2.5 NAT Gateway data-processing & data-transfer
- **What:** NAT gateways bill an hourly charge per NAT-Gateway-hour **plus** a per-GB data-processing charge **for every GB processed, regardless of source/destination**. (VPC docs / AWS re:Post knowledge center.)
- **Detect:** `aws ec2 describe-nat-gateways`; correlate with CloudWatch NAT GW `BytesOutToDestination` / `BytesInFromDestination`. Trusted Advisor: **Idle NAT gateways** / **Inactive NAT Gateways**. Use Cost Explorer grouped by **Usage Type** to surface NAT data-processing line items.
- **Why:** A common silent cost, traffic to S3/DynamoDB or chatty cross-AZ traffic routed through NAT is billed twice (NAT processing + transfer).
- **Fix:** Use **Gateway VPC Endpoints** for S3/DynamoDB (see 2.6); co-locate NAT GWs in the same AZ as high-traffic instances to avoid cross-AZ transfer; consolidate where appropriate.
- **Reversibility/risk:** Removing/replacing NAT requires routing changes, test connectivity. Adding endpoints is low risk.
- **Price source:** Amazon VPC pricing page (NAT Gateway hourly + per-GB; data transfer).

### 2.6 VPC Endpoints: add gateway endpoints, remove unused interface endpoints
- **What (two sub-tactics):**
  1. **Add Gateway endpoints** for S3 and DynamoDB to bypass NAT data-processing. **Verified:** "There is no additional charge for using gateway endpoints." Gateway endpoints support **only S3 and DynamoDB**. Create with `aws ec2 create-vpc-endpoint --vpc-endpoint-type Gateway --service-name com.amazonaws.<region>.s3 --route-table-ids ...`.
  2. **Remove unused interface (PrivateLink) endpoints**, interface endpoints carry an **hourly fee + per-GB** charge, so idle ones are pure waste.
- **Detect:** `aws ec2 describe-vpc-endpoints`. Trusted Advisor: **Inactive VPC interface endpoints**, **Inactive Gateway Load Balancer endpoints**.
- **Why:** Gateway endpoints eliminate NAT processing for S3/DynamoDB at zero endpoint cost; deleting idle interface endpoints removes hourly charges.
- **Reversibility/risk:** Adding gateway endpoints rewrites route tables (auto-managed prefix-list routes; you can't manually edit those routes). Test S3/DynamoDB reachability. Deleting an interface endpoint breaks private DNS for that service, verify nothing depends on it.
- **Price source:** Amazon VPC pricing page (interface endpoint hourly + per-GB).

### 2.7 Idle ALBs / NLBs and empty target groups
- **What:** Any provisioned load balancer accrues charges even with no traffic; empty target groups signal an LB serving nothing.
- **Detect:** `aws elbv2 describe-load-balancers` + `aws elbv2 describe-target-groups` + `aws elbv2 describe-target-health --target-group-arn ...` (no registered targets = idle). Trusted Advisor: **Idle Load Balancers**. CloudWatch caveat (verified): ELB publishes `RequestCount` **only when requests are flowing**, so absence of `RequestCount` data points = no traffic; AWS recommends alarming on `UnHealthyHostCount`/host counts to detect "no registered targets."
- **Why:** LB-hour + LCU charges with zero business value.
- **Reversibility/risk:** Deleting an LB breaks any DNS/Route 53 alias pointing at it, confirm it's truly unused.
- **Price source:** Elastic Load Balancing pricing page (per-hour + LCU).

### 2.8 Compute rightsizing (EC2 / ASG / RDS / ECS-Fargate / Lambda)
- **What:** Over-provisioned compute. The biggest single usage-optimization lever for most accounts.
- **Detect (verified):** Compute Optimizer `get-ec2-instance-recommendations`, `get-auto-scaling-group-recommendations`, `get-ecs-service-recommendations` (Fargate), `get-lambda-function-recommendations`. RDS rightsizing surfaces via Cost Optimization Hub / Trusted Advisor (**Amazon RDS cost optimization recommendations for DB instances**). Rank by `recommendationOptions[].savingsOpportunity.estimatedMonthlySavings.value` and weigh `finding`/`migrationEffort`.
- **Why:** Move from `OVER_PROVISIONED` to `OPTIMIZED` instance/family/size.
- **Reversibility/risk:** Resizing EC2/RDS usually needs a restart (downtime window); reversible. Validate against peak-load CloudWatch metrics, not just averages, before downsizing.
- **Price source:** EC2 / RDS / Fargate / Lambda pricing pages; Compute Optimizer's own `estimatedMonthlySavings` for prioritization.

### 2.9 Over-provisioned Lambda memory
- **What:** Lambda bills on memory × duration; memory also scales CPU, so the cost-optimal memory isn't always the smallest.
- **Detect (verified):** `aws compute-optimizer get-lambda-function-recommendations`. (For unqualified ARNs it returns recommendations for `$LATEST`; a qualified ARN targets a specific version.) Trusted Advisor: **AWS Lambda over-provisioned functions for memory size**, **AWS Lambda functions with excessive timeouts**.
- **Why:** Right-sized memory can cut cost and sometimes latency simultaneously.
- **Reversibility/risk:** Low, a single config change (`update-function-configuration --memory-size`), instantly reversible. Re-test latency/timeout after change.
- **Price source:** AWS Lambda pricing page.

### 2.10 Dev/test resources running 24/7 → schedule to zero
- **What:** Non-production EC2/RDS left running outside business hours.
- **Detect:** Inventory by tag/environment; look for instances with flat off-hours utilization. FinOps "Usage Optimization" explicitly calls out scheduling resources "to run only when needed, particularly for pre-production environments."
- **Fix:** **Instance Scheduler on AWS** (AWS Solution) uses resource tags + Lambda + EventBridge + a DynamoDB config table to stop/start EC2 and RDS on a defined schedule across Regions/accounts. AWS states stopping outside business hours can yield up to ~70% savings for business-hours-only instances. Alternative: **Systems Manager Quick Setup → Resource Scheduler** for tag-based stop/start.
- **Why:** Stopped EC2 stops compute charges (EBS still bills, see 2.2/2.11); stopped RDS pauses compute (storage still bills).
- **Reversibility/risk:** Fully reversible (start instance). Caveats: stopped RDS auto-restarts after 7 days; stopping breaks anything expecting 24/7 availability. Tag carefully to avoid scheduling prod.
- **Price source:** EC2 / RDS pricing pages.

### 2.11 Stopped EC2 instances still paying for EBS
- **What:** A stopped instance bills $0 compute but its attached EBS volumes still bill.
- **Detect:** Trusted Advisor **Amazon EC2 instances stopped**; `aws ec2 describe-instances --filters Name=instance-state-name,Values=stopped` then map attached volumes.
- **Why:** Long-stopped instances are often forgotten; snapshot + terminate to drop EBS cost.
- **Reversibility/risk:** Terminating is destructive (instance store lost; EBS deleted if `DeleteOnTermination=true`). Snapshot/AMI first.
- **Price source:** Amazon EBS pricing page.

### 2.12 Savings Plans & Reserved Instances: coverage + utilization
- **What (rate optimization):** Savings Plans/RIs trade a 1- or 3-year commitment for a lower rate vs On-Demand. Audit both **coverage** (how much eligible spend is committed) and **utilization** (how much of the commitment is actually used). WAF notes SPs/RIs offer "savings of up to 75% off On-Demand"; Spot "up to 90%", confirm current figures on the pricing pages.
- **Detect (verified CLI in `cli/latest/reference/ce/`):**
  - `aws ce get-savings-plans-coverage`, eligible spend covered.
  - `aws ce get-savings-plans-utilization`, verified output: `Utilization` = `{TotalCommitment, UsedCommitment, UnusedCommitment, UtilizationPercentage}`; `Savings` = `{NetSavings, OnDemandCostEquivalent}`; plus `AmortizedCommitment`. **Low `UtilizationPercentage` / high `UnusedCommitment` = over-committed (waste).**
  - `aws ce get-savings-plans-utilization-details`, per-SP detail.
  - `aws ce get-reservation-coverage` and `aws ce get-reservation-utilization`, RI equivalents.
  - Purchase guidance: `aws ce get-savings-plans-purchase-recommendation`, `get-reservation-purchase-recommendation`. Trusted Advisor: **AWS Savings Plans purchase recommendations for compute**, **Amazon EC2 Reserved Instance optimization/lease expiration**.
- **Why:** Coverage gaps = paying On-Demand unnecessarily; low utilization = paying for unused commitment.
- **Reversibility/risk:** **Commitments are largely irreversible** (1/3-year). Start with low-risk Compute Savings Plans sized to a conservative baseline; don't over-commit. Watch **RI lease expiration** so coverage doesn't silently lapse.
- **Price source:** Savings Plans / EC2 / RDS pricing pages; `get-savings-plans-purchase-recommendation` for sizing.

### 2.13 S3 lifecycle: storage class transitions
- **What:** Hot data sitting in S3 Standard that could move to IA / Glacier tiers, or be auto-deleted.
- **Detect:** `aws s3api get-bucket-lifecycle-configuration --bucket <b>` (absence/error = no policy). Use **S3 Storage Lens** and **S3 Storage Class Analysis** to find cold data. Trusted Advisor: **Amazon S3 Bucket Lifecycle Policy Configured**.
- **Fix:** `aws s3api put-bucket-lifecycle-configuration` with `Transition`/`Expiration` rules; or enable **S3 Intelligent-Tiering** for unknown/changing access patterns.
- **Why:** Lower per-GB rate on colder tiers; expiration deletes data you no longer need.
- **Reversibility/risk:** Transitions to deep-archive tiers add retrieval latency + retrieval fees; expiration deletes data permanently. Model access patterns first.
- **Price source:** Amazon S3 pricing page (per-storage-class rates, retrieval, transition request fees).

### 2.14 S3 incomplete multipart uploads
- **What:** Failed/abandoned multipart uploads leave orphaned parts that bill as storage indefinitely.
- **Detect:** `aws s3api list-multipart-uploads --bucket <b>`. Trusted Advisor: **Amazon S3 Incomplete Multipart Upload Abort Configuration**.
- **Fix (verified):** Add a lifecycle rule with `AbortIncompleteMultipartUpload` → `DaysAfterInitiation` (e.g. 7) so S3 auto-aborts stale uploads and deletes their parts. Apply via `put-bucket-lifecycle-configuration`.
- **Why:** Pure waste, billed parts that will never become an object.
- **Reversibility/risk:** Very low. Set the window longer than your largest legitimate upload duration so in-flight uploads aren't aborted.
- **Price source:** Amazon S3 pricing page (incomplete-upload parts bill as storage).

### 2.15 S3 versioning without lifecycle (noncurrent version sprawl)
- **What:** Versioned buckets accumulate noncurrent versions forever without a lifecycle rule.
- **Detect:** Trusted Advisor **Amazon S3 version-enabled buckets without lifecycle policies configured**; check `get-bucket-versioning` + lifecycle config.
- **Fix:** Lifecycle rules with `NoncurrentVersionTransition` / `NoncurrentVersionExpiration`.
- **Why:** Noncurrent versions are billed like any object.
- **Reversibility/risk:** Expiring noncurrent versions reduces rollback depth, set retention to match recovery needs. (NOTE from project memory: versioning + noncurrent-expiry makes deletes *reversible* during the retention window, which is a safety feature, not a cost of this tactic.)
- **Price source:** Amazon S3 pricing page.

### 2.16 CloudWatch Logs retention
- **What:** Log groups default to **never expire** ("Never" retention), so ingested logs accrue archival storage cost forever. (CloudWatch Logs docs.)
- **Detect:** `aws logs describe-log-groups` and inspect `retentionInDays`, **absent = never expire**. AWS Config managed rule `cw-loggroup-retention-period-check` flags this.
- **Fix (verified):** `aws logs put-retention-policy --log-group-name <g> --retention-in-days <N>`. Valid `retentionInDays` values (per the `PutRetentionPolicy` API): `1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653`. To restore "never expire," use `delete-retention-policy`.
- **Why:** Logs marked for deletion stop adding to archival storage cost (verified), bounded retention caps ongoing storage spend.
- **Reversibility/risk:** Setting retention is reversible, but **already-expired data is gone** (deletion typically within ~72h of hitting the retention setting). Keep retention long enough for compliance/forensics.
- **Price source:** Amazon CloudWatch pricing page (logs ingestion + storage).

### 2.17 CloudWatch Container Insights cost control
- **What:** Container Insights (EKS/ECS) can be a large CloudWatch line item. **Enhanced observability** for EKS bills **per observation** (number of observations scales with clusters/nodes/namespaces/services/workloads/pods/containers); ECS enhanced observability uses **flat metric pricing**; container **logs** are still billed at standard CloudWatch Logs ingestion/storage rates and Container Insights adds metadata bytes per log line. (CloudWatch / ECS / EKS docs + AWS containers blog.)
- **Detect:** Cost Explorer grouped by Usage Type for CloudWatch; review whether Container Insights / enhanced observability is enabled where not needed; audit log retention (2.16).
- **Why:** Disabling on non-prod clusters, scoping metrics, and bounding log retention cut a frequently-oversized bill.
- **Reversibility/risk:** Reversible (toggle the feature). Don't disable observability you rely on for prod incident response.
- **Price source:** Amazon CloudWatch pricing page (per-observation EKS / flat ECS / logs).

### 2.18 Cross-region "ghost" resources
- **What:** Forgotten resources in Regions you don't actively use (left-over test stacks, EIPs, volumes, NAT GWs, endpoints, LBs).
- **Detect:** Iterate the hunt-list CLI calls across **all** Regions (`aws ec2 describe-regions` → loop), or use **AWS Resource Explorer** / **Config aggregator** / **Cost Explorer grouped by Region** to spot spend in unexpected Regions. Trusted Advisor and Cost Optimization Hub span Regions.
- **Why:** Ghost resources are invisible in a single-Region console view but bill normally.
- **Reversibility/risk:** Same as the underlying resource type. Confirm a Region truly has no production footprint before sweeping.
- **Price source:** per-service pricing pages (rates vary by Region).

### 2.19 Guardrails: AWS Budgets + Cost Anomaly Detection
- **What:** Detective/preventive controls so future waste is caught fast (WAF *Expenditure and usage awareness*; FinOps *Anomaly Management*).
- **AWS Budgets:** Set cost/usage/RI-SP-coverage/utilization budgets with alert thresholds; `aws budgets create-budget` / `create-notification`. Supports budget actions to auto-respond.
- **AWS Cost Anomaly Detection:** ML-based; create at least one **monitor** (by AWS Service / Linked Account / Cost Category / Cost Allocation Tag; managed vs custom), attach **alert subscriptions** with dollar/percent thresholds (e.g. only alert above a set $ impact AND % increase), delivered via SNS/email; individual or daily/weekly digests; begins working within ~24h. (AWS Cost Management docs + AWS Cost Anomaly Detection product page.) CLI lives under `aws ce` (`create-anomaly-monitor`, `create-anomaly-subscription`, `get-anomalies`).
- **Why:** Turns one-time audit wins into durable control; catches regressions and surprise spend.
- **Reversibility/risk:** No resource risk. Tune thresholds to avoid alert fatigue.
- **Price source:** Cost Anomaly Detection and most Budgets usage are free per AWS; confirm current Budgets free-tier/limits on the AWS Cost Management pricing page.

---

## 3. Where to verify prices (NEVER hard-code dollar amounts)

- **AWS Price List Query API**, programmatic, current public prices. `aws pricing get-products --service-code <code> --filters ...`; discover attributes via `describe-services` / `get-attribute-values`. (AWS Billing docs: "Finding services and products using AWS Price List Query API"; `GetProducts` API.) Use this in automation to fetch live, per-Region rates.
- **AWS Price List Bulk API**, bulk price list files for offline analysis. (AWS Billing docs.)
- **AWS Pricing Calculator** (`calculator.aws`), model scenarios / estimate before changes.
- **Per-service pricing pages**, EC2, EBS, S3, VPC (NAT + endpoints + data transfer), CloudWatch, Lambda, ELB, RDS, Savings Plans. Authoritative for the headline rates this note deliberately does not quote.
- **Compute Optimizer / Cost Optimization Hub `estimatedMonthlySavings`**, AWS's own savings estimates, good for *ranking* findings (still estimates, not quotes).

---

## 4. Risk / reversibility cheat-sheet (for the skill's output)

| Reversibility | Tactics |
|---|---|
| **Low risk, easily reversible** | gp2→gp3 (2.3), Lambda memory (2.9), dev scheduling (2.10), add gateway endpoints (2.6), log retention set (2.16), Container Insights toggle (2.17), Budgets/Anomaly Detection (2.19) |
| **Reversible but needs a maintenance window** | EC2/RDS rightsizing & restart (2.8) |
| **Destructive, snapshot/verify first** | Release EIP (2.1), delete unattached EBS (2.2), delete snapshots/deregister AMIs (2.4), terminate stopped EC2 (2.11), delete idle LB (2.7), delete interface endpoint (2.6), S3 expiration/transition to deep archive (2.13/2.15) |
| **Largely irreversible, commit cautiously** | Savings Plans / RI purchases (2.12) |

---

## Sources
*All accessed 2026-05-28.*

- AWS Well-Architected Framework, Cost Optimization Pillar (welcome / design goals): https://docs.aws.amazon.com/wellarchitected/latest/cost-optimization-pillar/welcome.html
- AWS Well-Architected Framework, Cost optimization pillar (framework page): https://docs.aws.amazon.com/wellarchitected/latest/framework/cost-optimization.html
- WAF COST08-BP03 Implement services to reduce data transfer costs: https://docs.aws.amazon.com/wellarchitected/latest/cost-optimization-pillar/cost_data_transfer_implement_services.html
- FinOps Foundation, Framework Overview: https://www.finops.org/framework/
- FinOps Foundation, Domains: https://www.finops.org/framework/domains/
- FinOps Foundation, Capabilities (incl. Usage Optimization): https://www.finops.org/framework/capabilities/
- FinOps Foundation, 2025 Framework (Scopes added): https://www.finops.org/insights/2025-finops-framework/
- AWS Trusted Advisor, Cost optimization checks (check names): https://docs.aws.amazon.com/awssupport/latest/user/cost-optimization-checks.html
- AWS Trusted Advisor, opt in to Compute Optimizer for checks: https://docs.aws.amazon.com/awssupport/latest/user/compute-optimizer-with-trusted-advisor.html
- "Optimize Your AWS Spend with New Cost Savings Features in AWS Trusted Advisor" (Cost Optimization Hub), AWS Cloud Financial Management blog (June 5, 2025): https://aws.amazon.com/blogs/aws-cloud-financial-management/optimize-your-aws-spend-with-new-cost-savings-features-in-aws-trusted-advisor/
- AWS Cost Optimization Hub, CLI reference: https://docs.aws.amazon.com/cli/latest/reference/cost-optimization-hub/
- Cost Optimization Hub, list-recommendations: https://docs.aws.amazon.com/cli/latest/reference/cost-optimization-hub/list-recommendations.html
- Cost Optimization Hub, get-recommendation: https://docs.aws.amazon.com/cli/latest/reference/cost-optimization-hub/get-recommendation.html
- AWS Compute Optimizer, get-ec2-instance-recommendations: https://docs.aws.amazon.com/cli/latest/reference/compute-optimizer/get-ec2-instance-recommendations.html
- AWS Compute Optimizer, get-lambda-function-recommendations: https://docs.aws.amazon.com/cli/latest/reference/compute-optimizer/get-lambda-function-recommendations.html
- AWS Compute Optimizer, get-ecs-service-recommendations: https://docs.aws.amazon.com/cli/latest/reference/compute-optimizer/get-ecs-service-recommendations.html
- AWS Compute Optimizer, get-auto-scaling-group-recommendations: https://docs.aws.amazon.com/cli/latest/reference/compute-optimizer/get-auto-scaling-group-recommendations.html
- EC2 describe-volumes (status filter values): https://docs.aws.amazon.com/cli/latest/reference/ec2/describe-volumes.html
- EC2 describe-addresses (EIP association fields): https://docs.aws.amazon.com/cli/latest/reference/ec2/describe-addresses.html
- EC2 modify-volume (gp2→gp3, online modify, constraints): https://docs.aws.amazon.com/cli/latest/reference/ec2/modify-volume.html
- EC2 deregister-image (--delete-associated-snapshots, constraints): https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/deregister-ami.html
- EC2 delete-snapshot (constraints): https://docs.aws.amazon.com/ebs/latest/userguide/ebs-deleting-snapshot.html
- VPC Gateway endpoints (no charge; S3/DynamoDB only; routing): https://docs.aws.amazon.com/vpc/latest/privatelink/gateway-endpoints.html
- Reduce data transfer charges for a NAT gateway (AWS re:Post): https://aws.amazon.com/premiumsupport/knowledge-center/vpc-reduce-nat-gateway-transfer-costs/
- Amazon VPC Pricing (NAT GW, endpoints, IPv4, data transfer): https://aws.amazon.com/vpc/pricing/
- ELB, CloudWatch metrics for Application Load Balancer (RequestCount only when traffic flows): https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-cloudwatch-metrics.html
- S3, Configure lifecycle to delete incomplete multipart uploads (AbortIncompleteMultipartUpload / DaysAfterInitiation): https://docs.aws.amazon.com/AmazonS3/latest/userguide/mpu-abort-incomplete-mpu-lifecycle-config.html
- S3, Examples of S3 Lifecycle configurations: https://docs.aws.amazon.com/AmazonS3/latest/userguide/lifecycle-configuration-examples.html
- CloudWatch Logs, PutRetentionPolicy (default never expire; retentionInDays values): https://docs.aws.amazon.com/AmazonCloudWatchLogs/latest/APIReference/API_PutRetentionPolicy.html
- CloudWatch Logs, put-retention-policy CLI: https://docs.aws.amazon.com/cli/latest/reference/logs/put-retention-policy.html
- AWS Config, cw-loggroup-retention-period-check: https://docs.aws.amazon.com/config/latest/developerguide/cw-loggroup-retention-period-check.html
- Cost Explorer, get-savings-plans-utilization (Utilization/Savings fields): https://docs.aws.amazon.com/cli/latest/reference/ce/get-savings-plans-utilization.html
- Cost Explorer, get-savings-plans-coverage: https://docs.aws.amazon.com/cli/latest/reference/ce/get-savings-plans-coverage.html
- Cost Explorer (ce) command index: https://docs.aws.amazon.com/cli/latest/reference/ce/
- Instance Scheduler on AWS, solution overview (stop/start EC2 & RDS; ~70% claim): https://docs.aws.amazon.com/solutions/latest/instance-scheduler-on-aws/solution-overview.html
- Systems Manager, Schedule stop/start via Quick Setup: https://docs.aws.amazon.com/systems-manager/latest/userguide/quick-setup-scheduler.html
- AWS Cost Anomaly Detection, getting started: https://docs.aws.amazon.com/cost-management/latest/userguide/getting-started-ad.html
- AWS Cost Anomaly Detection, product page: https://aws.amazon.com/aws-cost-management/aws-cost-anomaly-detection/
- AWS Price List Query API, finding services/products (GetProducts): https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/using-price-list-query-api.html
- AWS Pricing CLI, get-products: https://docs.aws.amazon.com/cli/latest/reference/pricing/get-products.html
- CloudWatch Container Insights, pricing model (per-observation EKS / flat ECS): https://aws.amazon.com/cloudwatch/pricing/
- "Diving into Container Insights cost optimizations for Amazon EKS", AWS containers blog: https://aws.amazon.com/blogs/containers/diving-into-container-insights-cost-optimizations-for-amazon-eks/
- Amazon CloudWatch, Container Insights: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/ContainerInsights.html
