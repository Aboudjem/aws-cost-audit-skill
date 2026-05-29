# Quickstart

Audit your AWS bill with Claude Code in a few minutes. The skill reads your live
AWS account, finds waste, and writes an evidence-backed savings report.

**It is read-only by default.** It only runs read/describe/list calls unless you
explicitly approve a change. Nothing is deleted or modified without proof and your
sign-off. It never hardcodes prices — every dollar figure is verified live for your
exact region.

---

## 0. Prerequisites

You need three things before you start.

1. **Claude Code** — installed and working. (This is a Claude Code skill; it shells
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
region is just an example — use yours.

---

## 1. Install — Method A: plugin (recommended)

Run these three commands inside Claude Code:

```text
/plugin marketplace add Aboudjem/aws-cost-audit-skill
/plugin install aws-cost-audit@aws-cost-audit-skill
/reload-plugins
```

- The first command adds the marketplace from the GitHub repo.
- The second installs the plugin (`aws-cost-audit`) from that marketplace
  (`aws-cost-audit-skill`).
- `/reload-plugins` activates it. After this the skill is namespaced as
  `/aws-cost-audit:aws-cost-audit`.

To update later: `/plugin marketplace update aws-cost-audit-skill`. To remove:
`/plugin uninstall aws-cost-audit@aws-cost-audit-skill`.

---

## 2. Install — Method B: drop-in skill (no plugin)

If you would rather not use the plugin system, copy the skill folder into your
personal skills directory:

```shell
git clone https://github.com/Aboudjem/aws-cost-audit-skill.git
mkdir -p ~/.claude/skills
cp -R aws-cost-audit-skill/skills/aws-cost-audit ~/.claude/skills/aws-cost-audit
```

Claude Code auto-discovers it — no install command needed. The folder name becomes
the command: `/aws-cost-audit`. (A brand-new top-level skills directory may need a
Claude Code restart the first time before it is watched.)

---

## 3. Run it

Just ask Claude Code in plain language — the skill auto-triggers on cost/FinOps
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

## 4. What you get

- A **verified report**: every dollar attributed (cost, purpose, owner, created-when,
  last-used) or marked "unknown — could not verify". Each finding shows
  `current $/mo → after $/mo → $ saved → confidence + evidence + reversibility`, split
  into "save now safely" vs "max theoretical save".
- An **optional dashboard**: a self-contained HTML view of the findings you can open
  in a browser.

---

## 5. Safety

- **Read-only by default.** The skill describes and lists; it does not change your
  account on its own.
- **Nothing destructive without proof + your sign-off.** A resource is only proposed
  for deletion if it is proven-unused, reversible, and tested — otherwise it stays a
  recommendation, not an action. You approve each change.
- **Prices are verified live, never hardcoded.** Every figure is computed from the
  live unit price for your region times your actual usage, with the source shown.

That's it. Install, then say "audit my AWS bill".
