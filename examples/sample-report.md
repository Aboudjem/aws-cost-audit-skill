# AWS Cost Audit — Sample Report

> **SAMPLE — synthetic data, illustrative only.** Every figure, resource id, and date below is
> invented for a fictional account `<demo-account>`. Nothing here was read from a real AWS account.
> It exists only to show the *shape* and *discipline* of a real audit report. In a real run, every
> dollar is re-derived live from the AWS Price List Query API for your exact Region plus your actual
> usage (Cost Explorer / CUR); this skill hardcodes no prices.

**Account:** `<demo-account>` (12-digit id redacted) · **Primary Region:** `us-east-1` ·
**Audit window:** trailing 90 days · **Report date:** 2026-05-28 · **Mode:** read-only (no changes made)

---

## How to read this report

Every finding follows one output contract:

> **current $/mo → after $/mo → $ saved · confidence (High / Medium / Low) · evidence · reversibility**

- **Evidence** is the exact read-only command or metric that proves the claim — you can re-run it.
- **Reversibility** says whether you can undo the change, and how.
- **Dollars** carry a note like *(unit price from AWS Price List API, us-east-1, 2026-05-28)*. In this
  SAMPLE the prices are fake; in a real run they are live values. **No number here is a real AWS list price.**
- Totals are split into **Save now safely** (High-confidence, reversible, tested) and **Maximum
  theoretical save** (adds Medium/Low and items that need an owner's sign-off — never auto-run).

---

## 1. Pay today

**Verified current spend: `$4,812 / mo`** (reconciled to the dollar against Cost Explorer for the
trailing 30 days; figures below are SAMPLE).

> Evidence: `aws ce get-cost-and-usage --time-period Start=2026-04-28,End=2026-05-28 --granularity MONTHLY --metrics UnblendedCost --group-by Type=DIMENSION,Key=SERVICE`

| Service | $/mo (SAMPLE) | Share | Note |
|---|---:|---:|---|
| Amazon RDS | $1,640 | 34% | One oversized prod instance + one idle dev instance |
| Amazon EC2 (compute) | $1,205 | 25% | Mostly steady-state; on-demand, no Savings Plan |
| NAT Gateway | $612 | 13% | Hourly + per-GB data processing across 3 AZs |
| Amazon S3 | $498 | 10% | No lifecycle rules; old versions + incomplete uploads |
| Amazon EBS | $356 | 7% | gp2 volumes + unattached volumes |
| CloudWatch (logs + metrics) | $241 | 5% | Several log groups set to never expire |
| Elastic Load Balancing | $118 | 2% | Includes one ALB with no healthy targets |
| Data transfer (inter-AZ/out) | $96 | 2% | — |
| Everything else | $46 | 1% | Route 53, Secrets Manager, etc. |
| **Total** | **$4,812** | **100%** | *(all figures SAMPLE; verify live before acting)* |

> Price-source discipline: each $/mo above equals *(live unit price for us-east-1) × (your measured
> usage)*. Example for the gp2 line: `(gp2 $/GB-mo from Price List API) × (provisioned GB from
> describe-volumes)`. The unit prices in this SAMPLE are synthetic.

---

## 2. Save now safely

High-confidence, reversible, and dry-run-tested. Even these run **only after explicit confirmation**
and a snapshot/rollback where relevant — this skill is read-only by default.

**Subtotal — Save now safely: `$308 / mo` (≈ `$3,696 / yr`).** *(SAMPLE)*

### 2.1 Delete 4 unattached EBS volumes
- **current → after:** `$72/mo → $0/mo` · **saved: `$72/mo`**
- **confidence:** High — all four are `status=available` (detached) with `VolumeReadOps + VolumeWriteOps = 0`
  for the full 90-day window; no instance references them.
- **what it is:** Spare disks not attached to any server — you pay for the capacity even though nothing reads or writes them.
- **evidence:**
  - `aws ec2 describe-volumes --region us-east-1 --filters Name=status,Values=available --query 'Volumes[].{id:VolumeId,gb:Size,type:VolumeType,created:CreateTime}'`
  - `aws cloudwatch get-metric-statistics --namespace AWS/EBS --metric-name VolumeReadOps --dimensions Name=VolumeId,Value=vol-EXAMPLE1 --start-time <90d-ago> --end-time <now> --period 86400 --statistics Sum` → all zero
- **cost math:** `(gp2 $/GB-mo from AWS Price List API, us-east-1, 2026-05-28) × (40+30+20+10 GB) = $72/mo` *(SAMPLE unit price)*
- **reversibility:** **Reversible if snapshotted first.** Take an EBS snapshot of each volume, verify the
  snapshot completes, then delete. A snapshot restores the volume fully. Delete-without-snapshot is destructive.

### 2.2 Set retention on 9 "never-expire" CloudWatch log groups
- **current → after:** `$118/mo → $34/mo` · **saved: `$84/mo`**
- **confidence:** High — 9 log groups have no `retentionInDays` (stored forever); ingest is steady and
  these are debug/access logs with no compliance hold noted in tags.
- **what it is:** Application log buckets that keep every line forever. Old logs nobody reads still cost storage every month.
- **evidence:**
  - `aws logs describe-log-groups --region us-east-1 --query 'logGroups[?retentionInDays==null].[logGroupName,storedBytes]'`
- **cost math:** `(CloudWatch Logs storage $/GB-mo from Price List API, us-east-1, 2026-05-28) ×
  (stored GB that exceeds a 30-day retention)` *(SAMPLE unit price)*
- **reversibility:** **Fully reversible going forward** — `put-retention-policy` only changes future
  expiry; you can raise it again anytime. *Caveat:* logs already older than the new window are deleted
  at the next sweep, so confirm nothing has a legal/compliance hold before applying.

### 2.3 Migrate 6 gp2 volumes to gp3
- **current → after:** `$140/mo → $112/mo` · **saved: `$28/mo`** (same size, gp3 is cheaper per GB and includes baseline IOPS)
- **confidence:** High — these are attached, in active use, and gp3 covers their observed IOPS/throughput
  (max IOPS over 90d well under the gp3 3,000 baseline).
- **what it is:** Active server disks on the older gp2 type. gp3 is a newer, cheaper disk type with the same or better performance for this workload.
- **evidence:**
  - `aws ec2 describe-volumes --region us-east-1 --filters Name=volume-type,Values=gp2 --query 'Volumes[].{id:VolumeId,gb:Size,iops:Iops}'`
  - `aws cloudwatch get-metric-statistics --namespace AWS/EBS --metric-name VolumeReadOps ...` → peak IOPS confirms gp3 baseline is sufficient
- **cost math:** `[(gp2 $/GB-mo) − (gp3 $/GB-mo)] × (provisioned GB)` — both unit prices from
  *AWS Price List API, us-east-1, 2026-05-28* *(SAMPLE)*
- **reversibility:** **Reversible and online.** `modify-volume` changes type with no downtime; you can
  modify back to gp2 (subject to the 6-hour cooldown between modifications on the same volume).

### 2.4 Abort incomplete S3 multipart uploads + add a lifecycle rule
- **current → after:** `$58/mo → $0/mo` · **saved: `$58/mo`**
- **confidence:** High — orphaned multipart upload parts billed as storage; oldest is 240 days old and
  none belong to an in-flight transfer.
- **what it is:** Half-finished file uploads that were abandoned. The leftover pieces sit in S3 and bill as storage but are invisible in the normal bucket view.
- **evidence:**
  - `aws s3api list-multipart-uploads --bucket <demo-bucket> --query 'Uploads[].{key:Key,initiated:Initiated}'`
- **cost math:** `(S3 Standard $/GB-mo from Price List API, us-east-1, 2026-05-28) × (GB of orphaned parts)` *(SAMPLE)*
- **reversibility:** **Reversible via a lifecycle rule** — adding `AbortIncompleteMultipartUpload`
  (e.g. 7 days) is itself reversible (you can remove or change the rule). The one-time cleanup of parts
  already abandoned for 240 days is effectively non-recoverable, but those parts are unusable anyway
  (no completed object). Confirm no upload job is mid-flight before aborting.

---

## 3. Maximum theoretical save

Everything in section 2 **plus** Medium/Low-confidence items and changes that require an owner's
sign-off or a commitment. **These are recommendations only — none auto-run.** Items marked
**[SIGN-OFF REQUIRED]** change capacity, performance, or make a financial commitment and must be
approved by the resource owner.

**Theoretical ceiling (if every item below is approved and executed): `$308 + $1,512 = ~$1,820 / mo`
(≈ `$21,840 / yr`).** *(SAMPLE — upper bound, not a promise)*

| # | Recommendation | Est. $/mo saved (SAMPLE) | Confidence | Why gated |
|---|---|---:|---|---|
| 3.1 | **[SIGN-OFF REQUIRED]** Rightsize oversized prod RDS instance (one class down) | $410 | Medium | Capacity/perf change; needs load review + maintenance window |
| 3.2 | **[SIGN-OFF REQUIRED]** Stop/delete idle dev RDS instance (CPU <2%, 0 connections 60d) | $295 | Medium | Could still be someone's dev env; confirm owner before stopping |
| 3.3 | **[SIGN-OFF REQUIRED]** Purchase a Compute Savings Plan for steady EC2 baseline | $360 | Medium | **Irreversible 1- or 3-yr financial commitment** — finance approval |
| 3.4 | Consolidate NAT Gateways / route public traffic via gateway endpoints | $240 | Medium | Routing change; validate no asymmetric routing first |
| 3.5 | Apply S3 lifecycle: expire noncurrent versions + transition cold data to IA | $115 | Medium | Need owner confirmation that old versions aren't required |
| 3.6 | **[SIGN-OFF REQUIRED]** Delete 12 snapshots/AMIs older than 1 yr, unreferenced | $92 | Low | **Destructive** — confirm no DR/restore dependency |
| | **Additional theoretical save beyond section 2** | **~$1,512** | | |

> Confidence rationale (Law 4 — skeptic pass): items 3.1–3.2 are Medium because a single low-CPU
> reading is not proof a workload is idle; they were corroborated with Compute Optimizer +
> p99/max metrics, but final approval rests with the owner. Item 3.6 is Low because "unreferenced"
> was verified against current AMIs and launch templates only — a snapshot could still be a deliberate
> DR copy. Verify before acting.

> NAT detail (3.4) evidence: `aws ec2 describe-nat-gateways --region us-east-1` +
> `aws cloudwatch get-metric-statistics --namespace AWS/NATGateway --metric-name BytesOutToDestination ...`
> reconciled against `aws ce get-cost-and-usage ... --group-by Type=DIMENSION,Key=USAGE_TYPE`.

> Savings Plan detail (3.3): coverage/utilization read from
> `aws ce get-savings-plans-coverage` and `aws ce get-savings-plans-utilization`. A Savings Plan is a
> **1- or 3-year commitment and cannot be cancelled** — it is never auto-run and always requires
> explicit human sign-off.

---

## 4. Per-resource cards

Plain-language cards for a non-technical reader. Each answers: what it costs, what it is, which app it
belongs to, who made it, when, when it was last used, and the verdict.

### Card A — `vol-EXAMPLE1` (unattached disk)
- **What it costs:** **`$18/mo`** *(SAMPLE; gp2 $/GB-mo from Price List API, us-east-1, 2026-05-28 × 40 GB)*
- **What it is / does:** A 40 GB storage disk that is not connected to any server — so nothing is using it, but you still pay for the space.
- **Which app/repo:** **unknown** — no `Name`, `app`, or `team` tag present.
- **Who created it:** `dev-bob@<demo-account>` *(from CloudTrail `CreateVolume` event)*
- **When created:** 2025-11-03 *(CloudTrail)*
- **When last used:** Never in the 90-day window — `VolumeReadOps` and `VolumeWriteOps` both `0` *(CloudWatch)*
- **Verdict:** **SAFE-TO-DELETE** — saved `$18/mo`, **High** confidence, **reversible** (snapshot first, then delete).
  Auto-run only after snapshot + dry-run + confirmation.

### Card B — `<demo-account>` prod RDS `db-EXAMPLE-prod` (oversized database)
- **What it costs:** **`$980/mo`** *(SAMPLE; RDS instance + storage $/hr and $/GB-mo from Price List API, us-east-1, 2026-05-28 × hours/GB used)*
- **What it is / does:** The main production database for the customer-facing web app.
- **Which app/repo:** `web-app` *(from `app=web-app` tag)*
- **Who created it:** `terraform-ci@<demo-account>` *(CloudTrail `CreateDBInstance`)*
- **When created:** 2024-06-18 *(CloudTrail)*
- **When last used:** Actively in use — steady connections daily; but average CPU 11%, peak 38% over 90d *(CloudWatch `CPUUtilization`, `DatabaseConnections`)*
- **Verdict:** **OPTIMIZE** — one instance class smaller is likely safe, est. `$410/mo` saved, **Medium**
  confidence, **reversible** (instance class change in a maintenance window; can scale back up).
  **[SIGN-OFF REQUIRED]** — recommendation only; needs owner review + maintenance window.

### Card C — `<demo-account>` ALB `app/web-EXAMPLE/abc123` (load balancer with no healthy backends)
- **What it costs:** **`$23/mo`** *(SAMPLE; ALB-hour + LCU $/hr from Price List API, us-east-1, 2026-05-28 × hours)*
- **What it is / does:** A traffic distributor that is supposed to route web requests to servers — but all of its backend targets are unhealthy or gone, so it routes nothing.
- **Which app/repo:** **unknown** — no app tag; name suggests a retired `web-EXAMPLE` stack.
- **Who created it:** **unknown — predates CloudTrail 90-day lookup window** *(no `CreateLoadBalancer` event found)*
- **When created:** **unknown — could not verify** (older than the trail window)
- **When last used:** No healthy targets; `RequestCount ≈ 0` over 90d *(CloudWatch `RequestCount`, `HealthyHostCount`)*
- **Verdict:** **SAFE-TO-DELETE** — saved `$23/mo`, **High** confidence, but **destructive/irreversible**
  (recreating needs the listener/target config). Recommendation only; confirm the stack is retired,
  export the config, then delete with sign-off.

---

## 5. Health & monitoring snapshot

Guardrails so today's savings don't quietly erode. *(SAMPLE status)*

| Guardrail | Status | Evidence (read-only) | Recommendation |
|---|---|---|---|
| Cost anomaly detection | **Not configured** | `aws ce get-anomaly-monitors` → `[]` | Create a monitor + alert subscription |
| AWS Budgets | **1 of 2 needed** | `aws budgets describe-budgets --account-id <demo-account>` | Add a monthly budget + 80/100% alerts |
| Untagged spend | **18% of cost untagged** | `aws ce get-cost-and-usage --group-by Type=TAG,Key=app` | Adopt a tagging policy so attribution stops returning "unknown" |
| Savings Plan coverage | **0% (all on-demand)** | `aws ce get-savings-plans-coverage` | See 3.3 (sign-off required) |
| Compute Optimizer | **Enabled, 7 findings** | `aws compute-optimizer get-ec2-instance-recommendations` | Feed into rightsizing review |

---

## 6. Completeness pass

> **What Region / service / cost driver did we NOT inspect?**

- **Regions swept:** all 17 enabled Regions via `aws ec2 describe-regions --query 'Regions[].RegionName'`,
  then each service inventoried per Region.
- **Services reconciled:** every line that appears in Cost Explorer by-service is accounted for in
  section 1; "Everything else" ($46/mo) is itemized in the raw JSON.
- **Untagged spend (18%):** attributed to a resource where possible; where ownership could not be read
  from tags or CloudTrail it is marked **"unknown — could not verify"**, never guessed.
- **Result:** **No un-inspected Region, service, or material cost driver remains.** ✔

---

*End of SAMPLE report. In a real run, all unit prices are pulled live from the AWS Price List Query API
for your exact Region on the run date and multiplied by your measured usage; a separate skeptic pass
re-derives every headline number and every SAFE-TO-DELETE verdict from the primary source before it
ships. This skill makes no changes without your explicit confirmation.*
