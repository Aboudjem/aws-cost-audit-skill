# Practitioner AWS Cost-Cutting Intel — Non-Obvious Wins & Footguns

> Research note for a generic, reference-grade "AWS cost audit" Claude Code skill.
> Scope: the recurring "this saved us the most" moves, the silent top costs that surprise people, and the footguns (deletes/commitments that bite).
> **Access date for all sources: 2026-05-28.**
>
> **Discipline notes:**
> - Every load-bearing claim has a source URL. Claims confirmed by an AWS primary doc are labeled accordingly.
> - **No specific AWS dollar prices are stated as fact in this note.** Where community/blog sources quoted prices, this note describes the *mechanism* and *direction* of the charge (e.g., "per-hour charge", "per-GB data-processing charge") and points to the AWS pricing page for current numbers. Pricing changes and varies by region; always read the live pricing page.
> - Corroboration labels: **[community-endorsed]** = multiple independent sources / repeated community theme; **[single-anecdote]** = one report, do NOT treat as fleet-wide fact; **[AWS-primary]** = confirmed by official AWS docs/announcement.
> - `UNVERIFIED` marks anything not confirmed from a primary/authoritative source.

---

## 1. The recurring "this saved us the most" moves

### 1.1 Stop routing AWS-API / S3 / DynamoDB traffic through the NAT Gateway — use VPC endpoints
- **[community-endorsed] + [AWS-primary]** The single most-repeated "non-obvious win" is realizing that EC2/Lambda/container traffic to AWS services (S3, DynamoDB, ECR, CloudWatch, SQS/SNS) defaults to going *through the NAT Gateway*, incurring both NAT data-processing and (if it leaves to the internet) egress charges. Adding a **gateway VPC endpoint** for S3 and DynamoDB is free and routes that traffic over the AWS private network instead, removing it from the NAT path. **Interface (PrivateLink) endpoints** cover ECR, CloudWatch, SQS, SNS, etc.
  - AWS re:Post knowledge-center guidance "Reduce data transfer charges for a NAT gateway": https://repost.aws/knowledge-center/vpc-reduce-nat-gateway-transfer-costs (note: WebFetch returned HTTP 403 on this URL during research, but the title/guidance was surfaced via search and the mechanism is corroborated below)
  - Practitioner write-up: https://oneuptime.com/blog/post/2026-02-12-reduce-nat-gateway-data-transfer-costs/view
  - HN thread "A $1k AWS mistake" — the canonical anecdote: a dev put EC2 in a private subnet talking to S3 *through* a NAT Gateway instead of an S3 gateway endpoint; ~20TB got billed and produced an ~$1k surprise. Multiple commenters say the S3 gateway endpoint should be deployed "by default when your VPC is created": https://news.ycombinator.com/item?id=45977744
  - **Caveat / [single-anecdote] from same thread:** the exact bill figure and TB volume are one person's report — treat as illustrative, not a benchmark.

### 1.2 NAT Gateway alternatives for cost-sensitive / low-bandwidth workloads (fck-nat / NAT instances)
- **[community-endorsed]** For workloads where the managed NAT Gateway's per-hour + per-GB charges dominate, the community frequently recommends a self-managed NAT instance, most notably the open-source **fck-nat** AMI ("feasible cost konfigurable NAT").
  - Project repo: https://github.com/AndrewGuenther/fck-nat ; docs: https://fck-nat.dev/v1.4.0/ ; HN discussion: https://news.ycombinator.com/item?id=39164010
  - Blog claims of "up to 90%"/"99%" NAT savings exist (https://www.mechanicalrock.io/blog/aws-nat-gateways-are-robbing-you , https://nimbusstack.com/cut-aws-nat-gateway-costs-by-over-99-with-fck-nat/) — these are vendor/blog figures, `UNVERIFIED` as a universal number; the *direction* (a small `t4g.nano`-class instance is far cheaper than a managed NAT when idle/low-bandwidth) is well corroborated.
  - **Documented trade-off [community-endorsed]:** a NAT instance is self-managed — you own patching, monitoring, HA, and there's a bandwidth ceiling (fck-nat docs cite up to ~5 Gbps burst on small instances); above that, the managed NAT Gateway is recommended. Reference: https://dev.to/dhoang1905/introducing-fck-nat-cost-optimized-alternative-to-aws-nat-gateways-24a

### 1.3 Turn off non-prod environments outside business hours ("scheduling")
- **[community-endorsed]** Dev/staging/QA commonly run 24/7 but are used ~8x5. Automated stop/start (instance scheduler, Lambda+EventBridge) is repeatedly cited as a large, low-risk win. FinOps blog cites 40–65% savings on those environments: https://tasrieit.com/blog/finops-consulting-aws-cost-reduction-guide-2026 (vendor figure — `UNVERIFIED` as a guaranteed number, but the pattern is universally endorsed).

### 1.4 Right-size BEFORE committing (and migrate generations)
- **[community-endorsed]** Most EC2/RDS are oversized because someone picked a "safe" type at setup and never revisited. Right-sizing first, then committing, is the consistent advice. Sources: https://www.hyperglance.com/blog/aws-ec2-cost-optimization/ , https://tasrieit.com/blog/finops-consulting-aws-cost-reduction-guide-2026
- **[community-endorsed]** Migrating to newer/Graviton (ARM) instance generations is a repeated price-performance win for EC2/RDS/Aurora. Specific percentage gains are vendor/blog figures and vary by workload — treat as directional: https://zircon.tech/blog/the-2025-finops-playbook-graviton-4-wins-quick-rds-gains-and-net-java-migration-strategy/

### 1.5 EBS gp2 → gp3 migration
- **[AWS-primary]** AWS's own storage blog states migrating gp2→gp3 saves "up to 20%" on per-GiB storage cost (gp3 lower per-GiB than gp2), with **3,000 IOPS / 125 MiB/s baseline regardless of size**, and the migration is done with Elastic Volumes **without detaching or restarting** (no downtime). For over-provisioned gp2, savings can exceed 20% (AWS gives a ~50% example). Source: https://aws.amazon.com/blogs/storage/migrate-your-amazon-ebs-volumes-from-gp2-to-gp3-and-save-up-to-20-on-costs/
  - **Footgun:** if you naively "match" gp2's burst behavior by over-provisioning gp3 IOPS/throughput, you can erase the savings. Provision IOPS/throughput only above the free baseline when measured demand requires it (same source).

### 1.6 S3 lifecycle to colder classes + S3 Bucket Keys for KMS
- **[community-endorsed]** S3 lifecycle policies to Standard-IA / Glacier / Deep Archive for cold data is a classic large storage win (see §3 for the footguns). Example case (vendor blog, `UNVERIFIED` numbers): https://tasrieit.com/blog/finops-consulting-aws-cost-reduction-guide-2026
- **[AWS-primary]** **S3 Bucket Keys** reduce **SSE-KMS request costs by up to 99%** by generating a short-lived bucket-level key in S3 instead of calling KMS per object. Enable on the bucket; **existing objects are not retroactively covered** (re-encrypt to benefit). Sources: https://aws.amazon.com/blogs/storage/reducing-aws-key-management-service-costs-by-up-to-99-with-s3-bucket-keys/ and https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucket-key.html

### 1.7 Use the FREE native cost tooling first
- **[community-endorsed] + [AWS-primary]** Before paying for a FinOps SaaS, enable the free AWS stack: **Cost Explorer, AWS Budgets, Cost Anomaly Detection, Compute Optimizer, Trusted Advisor.** Cost Anomaly Detection is free and ML-based; AWS now enables it by default for new Cost Explorer users.
  - AWS Cost Anomaly Detection (free): https://aws.amazon.com/aws-cost-management/aws-cost-anomaly-detection/ and FAQ https://aws.amazon.com/aws-cost-management/aws-cost-anomaly-detection/faqs/
  - "Enabled by default for new Cost Explorer users": https://aws.amazon.com/blogs/aws-cloud-financial-management/new-aws-cost-explorer-users-can-now-automatically-detect-cost-anomalies/
  - Practitioner framing ("free stack finds 60–80% of waste paid tools find"): https://leanopstech.com/blog/aws-cost-management-tools-free-2026/ (vendor figure — directional, `UNVERIFIED` as exact %)
  - Note: Anomaly Detection needs a baseline (works within ~24h, more accurate after a few weeks of data).

---

## 2. The silent top costs people get surprised by

### 2.1 NAT Gateway (data processing + cross-AZ) — the perennial #1 surprise
- **[community-endorsed]** NAT Gateway is the most-cited "set-and-forget" silent cost: it bills a **per-hour charge per gateway** PLUS a **per-GB data-processing charge** on everything that flows through it. See §1.1. Live pricing: https://aws.amazon.com/vpc/pricing/
- **[community-endorsed] cross-AZ footgun:** a single NAT Gateway serving instances in other AZs incurs **cross-AZ data-transfer charges in each direction**. With one NAT serving 3 AZs, ~2/3 of traffic pays the cross-AZ fee. Fix: a NAT per AZ and route intra-AZ — but that adds per-gateway hourly charges, so it's a volume trade-off. Sources: https://www.cloudzero.com/blog/reduce-nat-gateway-costs/ , https://medium.com/@jvishnuprasad/regional-nat-gateway-vs-per-az-nat-gateway-which-one-is-actually-costing-you-more-5bc425594116

### 2.2 Data transfer / egress generally (the "inside cloud" boundary)
- **[community-endorsed]** Data transfer out to the internet, cross-region, and cross-AZ are repeatedly the line items people forget. For read-heavy systems, S3 egress can exceed storage cost. A common trap: writing/reading a *public* S3 bucket in another region routes over the internet (egress pricing), not the cheaper cross-region path. Sources: https://cloudcostkit.com/guides/aws-s3-data-transfer/ , https://www.bitsand.cloud/posts/slashing-data-transfer-costs/
- **Mitigation:** PrivateLink / VPC endpoints keep inter-service (and some inter-region) traffic on the AWS network. AWS storage blog example (Salesforce) cites ~70% data-movement reduction via S3 Multi-Region Access Points + interface endpoints (`UNVERIFIED` as a general number, it's one customer case): https://aws.amazon.com/blogs/storage/how-to-use-amazon-s3-multi-region-access-points-to-streamline-and-reduce-the-cost-of-writing-across-aws-regions/

### 2.3 CloudWatch Logs & Metrics — pay 3x and high-cardinality blowups
- **[community-endorsed]** CloudWatch Logs charges separately for **ingestion, storage, and query/scan** — people only budget for one. Sources: https://cloudburn.io/blog/amazon-cloudwatch-pricing , AWS pricing https://aws.amazon.com/cloudwatch/pricing/
- **[community-endorsed] retention footgun (see also §3.5):** log groups default to **"Never Expire"**, so storage grows forever ("zombie storage"). Set retention per log group (1 day–10 years). Sources: https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/Working-with-log-groups-and-streams.html , https://www.binadox.com/blog/binadox-finops-article-cloudwatch-log-retention-optimization/ , aws-samples retention setter: https://github.com/aws-samples/amazon-cloudwatch-retention-period-setter
- **[community-endorsed] high-cardinality custom metrics:** publishing a custom metric with a high-cardinality dimension (e.g., `userId`, `requestId`) creates one billable metric *per unique value* — thousands of metrics from one metric name. The specific "$3,000/month for 10,000 values" figure is a blog illustration (`UNVERIFIED` exact number), but the *mechanism* (per-unique-dimension billing) is real. Source: https://cloudburn.io/blog/amazon-cloudwatch-pricing
- **[community-endorsed] orphaned alarms:** alarms on terminated/deleted resources don't auto-clean and keep billing. Same source.

### 2.4 Public IPv4 addresses — the Feb 2024 change that surprised everyone
- **[AWS-primary]** Effective **Feb 1, 2024**, AWS charges **$0.005/IP/hour for ALL public IPv4 addresses — whether or not they're attached/in-use** (previously only *un*attached EIPs were charged). Applies broadly: EC2, RDS, EKS nodes, etc. A 12-month Free Tier of 750 hours/month was added for new accounts. AWS also shipped **Public IP Insights** (in VPC IPAM) to find them. (Rate as of Feb 2024; prices change and vary by Region, so verify live before quoting.) Sources: https://aws.amazon.com/blogs/aws/new-aws-public-ipv4-address-charge-public-ip-insights/ and https://aws.amazon.com/about-aws/whats-new/2024/02/aws-free-tier-750-hours-free-public-ipv4-addresses/
  - **Pre-2024 historical note:** older blogs say "EIP is only charged when *not* associated." That's now outdated — since Feb 2024 even an in-use public IPv4 carries the per-hour charge. Flag this in the skill so it doesn't repeat stale advice.

### 2.5 Idle / forgotten / orphaned resources
- **[community-endorsed]** The classic cleanup list, all repeatedly cited: unattached **EBS volumes**, old **EBS snapshots** (no retention policy), **EIPs / public IPv4** not in use, **idle load balancers**, idle EC2/RDS, **idle/old AMIs**, orphaned alarms. Industry repeats "~30–35% of cloud spend is wasted on idle/unused" (vendor stat, `UNVERIFIED` as a hard number). Sources: https://oneuptime.com/blog/post/2026-02-12-identify-idle-and-unused-aws-resources/view , https://www.nops.io/blog/23-stunning-finops-statistics/ , AWS Cloud Ops on unused EBS: https://aws.amazon.com/blogs/mt/controlling-your-aws-costs-by-deleting-unused-amazon-ebs-volumes/

### 2.6 KMS request costs (beyond S3)
- **[community-endorsed]** KMS bills per **API request** (encrypt/decrypt/GenerateDataKey). High-throughput services hitting a CMK per operation rack up request charges; S3 Bucket Keys (§1.6) is the S3-specific fix. Live pricing/concept: https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucket-key.html ; general KMS pricing should be read live.

### 2.7 Aurora / RDS opaque pricing
- **[community-endorsed]** Aurora's split of **storage + I/O** (and the choice between standard I/O vs I/O-Optimized) is repeatedly flagged as hard to estimate; surprise I/O charges are common on I/O-heavy workloads. Source (HN, multiple commenters): https://news.ycombinator.com/item?id=45977744 (community theme; specific bill impact is per-workload, `UNVERIFIED` as a general figure).

---

## 3. Footguns — deletes and commitments that bite

### 3.1 Snapshot ↔ AMI dependency (you can't delete what you think you deleted)
- **[AWS-primary]** You **cannot delete an EBS snapshot while it's still referenced by a registered AMI** — you get "The snapshot is currently in use by an AMI." You must **deregister the AMI first**. Deregistering an AMI does **not** delete its backing snapshots — so you keep paying snapshot storage unless you also delete them. Sources: https://repost.aws/knowledge-center/snapshot-in-use-error , https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/deregister-ami.html , https://docs.aws.amazon.com/ebs/latest/userguide/ebs-deleting-snapshot.html
- **[AWS-primary] hidden-blocker variant:** a **disabled AMI** still blocks its snapshot from deletion, and disabled AMIs are **not shown in the console / DescribeImages by default** — so a snapshot can be "in use by an AMI" that you can't see until you switch the filter to "Disabled images." Source: https://repost.aws/articles/ARcOiSQa0QRxeImuPWRv3_qQ/why-do-i-get-an-error-the-snapshot-is-currently-in-use-by-ami-when-i-try-to-delete-an-ebs-snapshot-even-though-there-is-no-ami-on-the-account ; disable-AMI behavior: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/disable-an-ami.html

### 3.2 Savings Plans / Reserved Instances commitment lock-in
- **[community-endorsed]** The headline footgun: **commit, then shrink/right-size**, and you're stuck paying for capacity you no longer use for 1–3 years. Correct order is **right-size FIRST, then commit to the new lower baseline.** Sources: https://hykell.com/knowledge-base/aws-reserved-instance-planning-guide/ , https://cloudcostdown.eu/aws-savings-plans-vs-reserved-instances
- **[AWS-primary] flexibility/exit facts to verify against live docs:**
  - Compute Savings Plans apply across instance family/size/region/OS/tenancy and to Fargate/Lambda; EC2 Instance Savings Plans are narrower but deeper-discount. Reference: https://docs.aws.amazon.com/savingsplans/latest/userguide/sp-ris.html
  - **Standard RIs can be sold on the RI Marketplace** (an exit valve); **Savings Plans cannot be sold or cancelled** — community sources cite a **7-day return window** for Savings Plans. The 7-day window is widely repeated (https://www.nops.io/blog/aws-reserved-instance-and-savings-plan-changes-for-2025/) but `UNVERIFIED` against a primary AWS doc in this research — **verify on AWS docs before asserting in the skill.**
- **[community-endorsed] practical guidance:** default to **Compute Savings Plans** for flexibility; size commitments to a conservative baseline (not peak) so you stay highly utilized; "Database Savings Plans" became available in 2025 (re:Invent FinOps coverage): https://www.synyega.com/insights/aws-database-savings-plans-and-other-new-finops-releases

### 3.3 Glacier / Deep Archive early-deletion & minimum-duration fees
- **[community-endorsed] + AWS docs** Archive classes have **minimum storage durations**; delete/overwrite/transition *before* the minimum and you pay a **prorated early-deletion fee for the remaining days**. Commonly cited minimums: S3 Glacier Deep Archive **180 days** (and shorter minimums for other IA/Glacier classes — read the live class table). The fee is per-object, and **overwrite/transition counts**, not just delete. Sources: https://docs.aws.amazon.com/AmazonS3/latest/userguide/lifecycle-transition-general-considerations.html , https://docs.aws.amazon.com/AmazonS3/latest/userguide/archival-storage.html , https://www.repost.aws/questions/QUXN4-OJkTReG5j7p_nK63vA/s3-glacier-deep-archive-early-delete-fee
  - **Footgun for lifecycle "optimization":** aggressively transitioning short-lived objects into Glacier/Deep Archive can cost MORE than leaving them in Standard, because of both the per-object transition request cost and the minimum-duration charge if they're deleted early.

### 3.4 S3 Intelligent-Tiering on tiny objects (mostly fixed, but know the history)
- **[AWS-primary]** Since **Sept 2021**, objects **< 128 KB** incur **no monitoring/automation charge** and are kept in the Frequent Access tier (not auto-tiered). So the old "tiny objects pay monitoring fees for no benefit" footgun is largely removed for those sizes. Sources: https://aws.amazon.com/about-aws/whats-new/2021/09/amazon-s3-intelligent-tiering-automates-storage-savings/ , https://aws.amazon.com/s3/storage-classes/intelligent-tiering/
  - **Residual nuance [community-endorsed]:** Intelligent-Tiering adds a per-object monitoring charge for objects ≥128 KB; for buckets with *huge counts of small-but-≥128KB* objects, monitoring can exceed the tiering benefit — S3 Standard + explicit lifecycle may win. Treat the exact break-even as workload-specific (`UNVERIFIED` general number): https://cloudfix.com/blog/aws-s3-intelligent-tiering/

### 3.5 CloudWatch Logs "Never Expire" default
- Covered in §2.3 — listed here too because it's a *deletion/retention* footgun: nothing ever ages out unless you explicitly set retention. Primary: https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/Working-with-log-groups-and-streams.html

### 3.6 No hard spend cap — runaway-job risk
- **[community-endorsed]** AWS does **not** offer a true hard budget cap that stops services; Budgets/Anomaly Detection **alert** but don't halt spend. A runaway/forgotten job (e.g., an abandoned ML pipeline reprocessing uploads) can quietly bill until noticed. Mitigation: Budgets + Anomaly Detection + Budget Actions (which *can* trigger automated responses like applying a restrictive IAM policy or stopping instances) — but you must wire that up. Sources: HN thread anecdote (one user reported losing weekend earnings to an abandoned job — **[single-anecdote]**): https://news.ycombinator.com/item?id=45977744 ; Budgets/Anomaly Detection: https://aws.amazon.com/aws-cost-management/aws-cost-anomaly-detection/

### 3.7 Deleting something still referenced (general pattern)
- **[community-endorsed]** Beyond snapshot↔AMI: AWS frequently *blocks* deletion of in-use resources (e.g., a security group still attached, a subnet with ENIs) rather than letting you orphan them — which is protective, but the inverse bites for cost: deregistering/"deleting" the visible object (AMI, launch template version) often leaves billable backing artifacts (snapshots, EBS volumes, EIPs) behind. The audit rule: **after deleting a compute object, sweep for orphaned storage/IPs it leaves behind.** Corroborated by the AMI/snapshot docs in §3.1 and the orphaned-resource sources in §2.5.

---

## 4. Synthesis: what an audit skill should check (prioritized by corroboration)

**Tier 1 — community-endorsed, high-impact, low-risk:**
1. S3 + DynamoDB **gateway VPC endpoints** present; AWS-service traffic not flowing through NAT (§1.1).
2. **NAT Gateway** review: data-processing volume, cross-AZ routing, NAT-per-AZ vs single (§2.1); consider NAT-instance for low-bandwidth (§1.2).
3. **CloudWatch Logs retention** not "Never Expire"; check high-cardinality custom metrics & orphaned alarms (§2.3).
4. **Public IPv4 / EIP** inventory — every public IPv4 now bills (post-Feb-2024) (§2.4).
5. **Idle/orphaned sweep:** unattached EBS, old snapshots, idle LBs/RDS/EC2, old AMIs (§2.5, §3.1).
6. **gp2→gp3** EBS migration (§1.5); **S3 Bucket Keys** for SSE-KMS buckets (§1.6).
7. **Non-prod scheduling** (§1.3).
8. Enable the **free native tooling** (Cost Explorer/Budgets/Anomaly Detection/Compute Optimizer/Trusted Advisor) (§1.7).

**Tier 1 — footgun guardrails the skill must SURFACE before recommending a delete/commit:**
- Right-size BEFORE buying Savings Plans/RIs; prefer Compute SP for flexibility; SPs are largely non-cancellable (§3.2).
- Deregister AMI before deleting snapshots; remember disabled AMIs are hidden blockers; deleting an AMI doesn't free its snapshots (§3.1).
- Glacier/Deep Archive minimum-duration & early-delete fees; don't lifecycle short-lived objects into archive (§3.3).
- No hard cap exists — recommend Budgets + Anomaly Detection + Budget Actions (§3.6).
- After deleting compute, sweep for orphaned storage/IP it leaves behind (§3.7).

---

## 5. Things to VERIFY against live AWS docs before the skill states them as fact
- All **dollar prices** — region-specific and change over time. The skill should describe charge *mechanisms* and link the live pricing page, not hardcode numbers.
- **Savings Plans 7-day return window** — widely repeated by community but not confirmed from a primary AWS doc in this research (§3.2). `UNVERIFIED`.
- **Exact Glacier minimum-duration days** per storage class (Deep Archive 180d is well-cited; confirm IA/Flexible Retrieval minimums on the live class table) (§3.3).
- **fck-nat "90–99% savings"** — vendor/blog figures, workload-dependent; the *direction* is sound, the magnitude is `UNVERIFIED` as universal (§1.2).
- Any **"% of cloud spend wasted"** stat (e.g., 30–35%) — vendor surveys, cite as directional not authoritative (§2.5).
- Per-customer case studies (Salesforce 70%, media-company 80%) are single cases, not benchmarks (§1.6, §2.2).

---

## Sources
*(All accessed 2026-05-28.)*

**AWS primary (docs / blogs / announcements):**
- NAT gateway data-transfer reduction (re:Post KB; 403 via WebFetch, surfaced via search): https://repost.aws/knowledge-center/vpc-reduce-nat-gateway-transfer-costs
- gp2→gp3 migration & savings (AWS Storage Blog): https://aws.amazon.com/blogs/storage/migrate-your-amazon-ebs-volumes-from-gp2-to-gp3-and-save-up-to-20-on-costs/
- S3 Bucket Keys reduce KMS up to 99% (AWS Storage Blog): https://aws.amazon.com/blogs/storage/reducing-aws-key-management-service-costs-by-up-to-99-with-s3-bucket-keys/
- S3 Bucket Keys (S3 User Guide): https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucket-key.html
- Public IPv4 charge + Public IP Insights (AWS News Blog): https://aws.amazon.com/blogs/aws/new-aws-public-ipv4-address-charge-public-ip-insights/
- Free Tier 750h public IPv4 (What's New): https://aws.amazon.com/about-aws/whats-new/2024/02/aws-free-tier-750-hours-free-public-ipv4-addresses/
- Snapshot "in use by AMI" (re:Post KB): https://repost.aws/knowledge-center/snapshot-in-use-error
- Deregister AMI (EC2 User Guide): https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/deregister-ami.html
- Disable AMI (EC2 User Guide): https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/disable-an-ami.html
- Delete EBS snapshot (EBS User Guide): https://docs.aws.amazon.com/ebs/latest/userguide/ebs-deleting-snapshot.html
- Disabled-AMI hidden blocker (re:Post article): https://repost.aws/articles/ARcOiSQa0QRxeImuPWRv3_qQ/why-do-i-get-an-error-the-snapshot-is-currently-in-use-by-ami-when-i-try-to-delete-an-ebs-snapshot-even-though-there-is-no-ami-on-the-account
- S3 lifecycle transition considerations: https://docs.aws.amazon.com/AmazonS3/latest/userguide/lifecycle-transition-general-considerations.html
- S3 archival storage (Glacier minimums): https://docs.aws.amazon.com/AmazonS3/latest/userguide/archival-storage.html
- S3 Glacier Deep Archive early-delete fee (re:Post): https://www.repost.aws/questions/QUXN4-OJkTReG5j7p_nK63vA/s3-glacier-deep-archive-early-delete-fee
- S3 Intelligent-Tiering small-object monitoring removed (What's New 2021): https://aws.amazon.com/about-aws/whats-new/2021/09/amazon-s3-intelligent-tiering-automates-storage-savings/
- S3 Intelligent-Tiering class page: https://aws.amazon.com/s3/storage-classes/intelligent-tiering/
- CloudWatch Logs log groups (retention default): https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/Working-with-log-groups-and-streams.html
- CloudWatch pricing: https://aws.amazon.com/cloudwatch/pricing/
- Compute Savings Plans vs RIs (Savings Plans User Guide): https://docs.aws.amazon.com/savingsplans/latest/userguide/sp-ris.html
- Cost Anomaly Detection (product + FAQ): https://aws.amazon.com/aws-cost-management/aws-cost-anomaly-detection/ , https://aws.amazon.com/aws-cost-management/aws-cost-anomaly-detection/faqs/
- Anomaly Detection on by default for new Cost Explorer users: https://aws.amazon.com/blogs/aws-cloud-financial-management/new-aws-cost-explorer-users-can-now-automatically-detect-cost-anomalies/
- Controlling cost by deleting unused EBS (Cloud Ops Blog): https://aws.amazon.com/blogs/mt/controlling-your-aws-costs-by-deleting-unused-amazon-ebs-volumes/
- S3 Multi-Region Access Points cost (Storage Blog): https://aws.amazon.com/blogs/storage/how-to-use-amazon-s3-multi-region-access-points-to-streamline-and-reduce-the-cost-of-writing-across-aws-regions/
- VPC pricing: https://aws.amazon.com/vpc/pricing/
- aws-samples CloudWatch retention setter: https://github.com/aws-samples/amazon-cloudwatch-retention-period-setter

**Community / practitioner (Reddit-adjacent, HN, blogs, GitHub):**
- HN "A $1k AWS mistake" (NAT/S3, Aurora, runaway job, no hard cap): https://news.ycombinator.com/item?id=45977744
- HN fck-nat discussion: https://news.ycombinator.com/item?id=39164010
- fck-nat repo: https://github.com/AndrewGuenther/fck-nat ; docs: https://fck-nat.dev/v1.4.0/
- fck-nat intro (DEV): https://dev.to/dhoang1905/introducing-fck-nat-cost-optimized-alternative-to-aws-nat-gateways-24a
- fck-nat savings claims (vendor blogs): https://www.mechanicalrock.io/blog/aws-nat-gateways-are-robbing-you , https://nimbusstack.com/cut-aws-nat-gateway-costs-by-over-99-with-fck-nat/
- NAT cost cutting: https://www.cloudzero.com/blog/reduce-nat-gateway-costs/ , https://oneuptime.com/blog/post/2026-02-12-reduce-nat-gateway-data-transfer-costs/view
- NAT regional vs per-AZ: https://medium.com/@jvishnuprasad/regional-nat-gateway-vs-per-az-nat-gateway-which-one-is-actually-costing-you-more-5bc425594116
- VPC endpoint vs NAT cost comparison: https://pcg.io/insights/vpc-endpoints-explanation-and-cost-comparison/ , https://cloudburn.io/blog/amazon-vpc-pricing
- CloudWatch hidden cost / high cardinality: https://cloudburn.io/blog/amazon-cloudwatch-pricing
- CloudWatch retention FinOps: https://www.binadox.com/blog/binadox-finops-article-cloudwatch-log-retention-optimization/
- S3 data transfer surprises: https://cloudcostkit.com/guides/aws-s3-data-transfer/ , https://www.bitsand.cloud/posts/slashing-data-transfer-costs/
- Idle/unused resource sweeps: https://oneuptime.com/blog/post/2026-02-12-identify-idle-and-unused-aws-resources/view , https://squareops.com/blog/find-delete-unused-ebs-volumes-snapshots-elastic-ips-aws/
- FinOps consulting case studies (vendor): https://tasrieit.com/blog/finops-consulting-aws-cost-reduction-guide-2026
- Graviton/right-size playbook: https://zircon.tech/blog/the-2025-finops-playbook-graviton-4-wins-quick-rds-gains-and-net-java-migration-strategy/
- EC2 cost optimization: https://www.hyperglance.com/blog/aws-ec2-cost-optimization/
- Free AWS cost tools: https://leanopstech.com/blog/aws-cost-management-tools-free-2026/
- FinOps statistics (waste %): https://www.nops.io/blog/23-stunning-finops-statistics/
- Savings Plans vs RIs (startup guide): https://cloudcostdown.eu/aws-savings-plans-vs-reserved-instances
- RI planning guide: https://hykell.com/knowledge-base/aws-reserved-instance-planning-guide/
- RI/SP changes & 7-day window claim: https://www.nops.io/blog/aws-reserved-instance-and-savings-plan-changes-for-2025/
- Database Savings Plans (2025): https://www.synyega.com/insights/aws-database-savings-plans-and-other-new-finops-releases
- S3 Intelligent-Tiering break-even (vendor): https://cloudfix.com/blog/aws-s3-intelligent-tiering/
