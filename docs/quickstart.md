# Quickstart

Audit your AWS bill with Claude Code in a few minutes. The skill reads your live
AWS account, finds waste, and writes an evidence-backed savings report.

**It is read-only by default.** It only runs read/describe/list calls unless you
explicitly approve a change. Nothing is deleted or modified without proof and your
sign-off. It never hardcodes prices, every dollar figure is verified live for your
exact region.

---

## 0. Prerequisites

You need three things before you start.

1. **Claude Code**, installed and working. (This is a Claude Code skill; it shells
   out to the AWS CLI.)

2. **AWS CLI v2**, configured with credentials that can READ your account. Check:

   ```shell
   aws --version          # should say aws-cli/2.x
   aws sts get-caller-identity   # should print your account id + a role/user ARN
   ```

   If `aws` is missing, install AWS CLI v2 from the AWS docs, then run `aws configure`
   (or set up an SSO profile) for the account and region you want to audit.

3. **Read access + Cost Explorer.** The audit only needs read permissions. The
   simplest safe setup is the AWS managed **`ReadOnlyAccess`** policy, plus billing
   read access (the **`Billing`** managed policy or equivalent Cost Explorer / CUR
   read permissions). Make sure **Cost Explorer is enabled** in the account
   (Billing console → Cost Explorer → enable; it can take up to ~24h to backfill the
   first time). Without Cost Explorer the skill can still inventory resources but
   cannot attribute spend.

Tip: if you manage several accounts, audit one at a time. Pick the AWS profile and
region up front, e.g. `export AWS_PROFILE=my-account AWS_REGION=us-east-1`. The
region is just an example, use yours.

---

## 1. Install: Method A: plugin (recommended)

**Recommended: via the [10x marketplace](https://github.com/Aboudjem/10x)**, a
curated set of Claude Code tools. Run these two commands inside Claude Code:

```text
/plugin marketplace add Aboudjem/10x
/plugin install aws-cost-audit@10x
```

- The first command adds the 10x marketplace.
- The second installs the `aws-cost-audit` plugin from it. After activation the
  skill is namespaced as `/aws-cost-audit:aws-cost-audit`.

There is no direct-from-this-repo plugin path. This repo ships no marketplace
manifest of its own, so `/plugin marketplace add Aboudjem/aws-cost-audit-skill`
has nothing to resolve. Use 10x, the skills CLI, or the drop-in copy below.

To update later: `/plugin marketplace update 10x`. To remove:
`/plugin uninstall aws-cost-audit@10x`.

---

## 2. Install: Method B: drop-in skill (no plugin)

If you would rather not use the plugin system, copy the skill folder into your
personal skills directory:

```shell
git clone https://github.com/Aboudjem/aws-cost-audit-skill.git
mkdir -p ~/.claude/skills
cp -R aws-cost-audit-skill/skills/aws-cost-audit ~/.claude/skills/aws-cost-audit
```

Claude Code auto-discovers it, no install command needed. The folder name becomes
the command: `/aws-cost-audit`. (A brand-new top-level skills directory may need a
Claude Code restart the first time before it is watched.)

---

## 3. Run it

Just ask Claude Code in plain language, the skill auto-triggers on cost/FinOps
phrasing:

```text
audit my AWS bill
```

Other prompts that trigger it: "where is my AWS money going?", "find unused AWS
resources", "cut my AWS costs", "check my Savings Plans coverage". Or invoke it
directly: `/aws-cost-audit:aws-cost-audit` (plugin) or `/aws-cost-audit` (drop-in).

Helpful things to tell it: which **profile/region(s)** to audit, and whether you
want a quick scan or a full account-wide pass.

---

## 4. What a run does, step by step

Nothing below changes your account. Steps 1 to 6 are read, describe, and list calls only.

1. **Identity check.** `aws sts get-caller-identity` confirms which account and region you are
   pointed at before anything else runs.
2. **Environment check.** `skills/aws-cost-audit/scripts/doctor.sh` reports the AWS CLI version,
   `jq`, the resolved region, and a writable output directory, then lists any blocker. It has no
   apply flag and removes the probe file it wrote.
3. **Spend baseline.** Cost Explorer (`aws ce get-cost-and-usage`) pulls the trailing 30 and
   90-day spend by service and by region. Every request goes through a wrapper that counts pages
   and stops at `AWS_COST_AUDIT_CE_BUDGET`, so a wide fan-out cannot quietly run up the per
   request charge.
4. **Resource inventory.** The skill fans out across every enabled region and lists EC2
   instances, EBS volumes, RDS instances, NAT gateways, load balancers, S3 buckets, Lambda
   functions, CloudWatch log groups, snapshots, AMIs, Elastic IPs, and more.
5. **Waste detection.** Each resource is checked against
   [the hunt list](../skills/aws-cost-audit/references/hunt-list.md): idle CPU, unattached
   volumes, old snapshots, gp2 volumes, over-retained logs, missing Savings Plan coverage, and
   the rest.
6. **Live price verification.** For every candidate saving, the skill fetches the current,
   region-specific unit price from the AWS Price List Query API. Those lookups are free. It
   shows unit price, then the math, then the source, for every dollar figure.
7. **Report.** Findings are written as `current $/mo -> after $/mo -> $ saved`, each with a
   confidence level, the evidence, and how to reverse it, split into "save now safely" and
   "maximum theoretical save". See [`examples/sample-report.md`](../examples/sample-report.md)
   for the exact shape, and [`findings.json`](../skills/aws-cost-audit/references/output-and-reporting.md)
   if you want the machine-readable form.
8. **Dashboard, if you want one.** A single HTML file generated from the findings. It pulls its
   font and chart library from a CDN. See
   [`examples/sample-dashboard.html`](../examples/sample-dashboard.html).

Both samples use synthetic data on no real account, clearly labelled.

---

## 5. What you get

- A **verified report**: every dollar attributed (cost, purpose, owner, created-when,
  last-used) or marked "unknown, could not verify". Each finding shows
  `current $/mo → after $/mo → $ saved → confidence + evidence + reversibility`, split
  into "save now safely" vs "max theoretical save".
- An **optional dashboard**: a single HTML view of the findings you can open in a
  browser.

---

## 6. Safety

- **Read-only by default.** The skill describes and lists; it does not change your
  account on its own.
- **Nothing destructive without proof + your sign-off.** A resource is only proposed
  for deletion if it is proven-unused, reversible, and tested, otherwise it stays a
  recommendation, not an action. You approve each change.
- **Prices are verified live, never hardcoded.** Every figure is computed from the
  live unit price for your region times your actual usage, with the source shown.

That's it. Install, then say "audit my AWS bill".
