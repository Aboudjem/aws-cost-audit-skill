# AGENTS.md — AWS Cost Audit Skill

Instructions for AI agents and coding assistants working in or invoking this repository. Plain Markdown, no required fields (per the AGENTS.md convention: the agent simply parses the text below). Human-facing docs live in `README.md`; this file holds the extra context an agent needs.

## What this repo is

This repo is an executable Claude Code skill, `aws-cost-audit`, that audits a live AWS account: it attributes every dollar, finds idle/orphaned/over-provisioned resources, checks Savings Plans and Reserved Instance coverage, and produces an evidence-backed savings plan with confidence levels and reversible, gated actions. It runs against **the account in the caller's current AWS credentials** — it is account-agnostic and works on any user's own account. It is read-only by default, verifies prices live, and never hardcodes a price. MIT licensed.

The skill targets Claude Code and shells out to the AWS CLI. The skill definition is `skills/aws-cost-audit/SKILL.md`; supporting material is in `skills/aws-cost-audit/references/`.

## How an agent should invoke the skill

- If running inside Claude Code with the skill installed: trigger it by describing the user's intent (e.g. "audit my AWS bill", "find unused AWS resources", "check our Savings Plans coverage", "where is my AWS money going"). Claude Code matches these to the skill's description and loads `SKILL.md`.
- To install via the [10x marketplace](https://github.com/Aboudjem/10x) (recommended): `/plugin marketplace add Aboudjem/10x` then `/plugin install aws-cost-audit@10x`.
- To install directly from this repo: `/plugin marketplace add Aboudjem/aws-cost-audit-skill` then `/plugin install aws-cost-audit@aws-cost-audit-skill`.
- To install as a drop-in skill: copy `skills/aws-cost-audit/` into `~/.claude/skills/aws-cost-audit/`.
- Prerequisite: a working AWS CLI configured with the user's own credentials. Confirm identity first with `aws sts get-caller-identity`. Never assume an account, Region, or resource — read them live. Parameterize the Region (do not hardcode one default).

## Safety rules an agent MUST honor

These are non-negotiable. They mirror the skill's five Iron Laws in `SKILL.md`. Do not look for loopholes; violating the letter violates the spirit.

1. **Read-only by default.** Run only describe/list/get-style commands during discovery. Treat any change as gated.
2. **Never run a destructive action ungated.** Anything that deletes, terminates, releases, detaches, expires, or purchases (delete snapshot/AMI, terminate instance, release Elastic IP, S3 lifecycle expiry, Savings Plan / RI purchase) is allowed only when the resource is proven-unused (multiple live signals over 30–90 days), reversible, tested in dry-run, and you are 100% sure of the blast radius — and only via an executor -> verifier -> rollback gate. Irreversible actions are NEVER auto-run; they are recommendations requiring explicit human sign-off. When in doubt, recommend, do not act.
3. **Never hardcode or guess a price — verify live.** Do not state any unit price, monthly cost, or "$X saved" from memory. Every dollar figure must come from BOTH the live, Region-specific unit price (AWS Price List Query API, or the service's pricing page) AND the user's actual usage (Cost Explorer / CUR). Always show `unit price -> math -> source`. Prices are Region-specific and change; a memorized price is a guess. Never write a price into the skill, a script, or a report.
4. **Attribute every dollar or say "unknown."** For each resource, report cost, purpose, owning app/repo, creator (CloudTrail), created-when, and last-used (CloudWatch / access logs / last-invocation). If any cannot be determined, write "unknown — could not verify". Never invent an owner, a date, or a last-used value.
5. **No single probe becomes a fleet-wide fact.** Fan out checks across resources and Regions. A separate skeptic pass must re-derive every load-bearing claim (the headline savings total, each "safe-to-delete" verdict) from the primary source, not from another agent's summary.
6. **Every finding carries its evidence.** Output contract per item: `current $/mo -> after $/mo -> $ saved -> confidence (High/Med/Low) + evidence + reversibility`. Split totals into "save now safely" (High-confidence, reversible, tested) vs "max theoretical save".

Additional hygiene for agents editing this repo: never commit a real 12-digit AWS account id, a concrete ARN, a public IP, or a concrete resource id (instance/volume/NAT/ENI/CloudFront/allocation id). Use generic placeholders (`$REGION`, `vol-EXAMPLE`, `<your-account>`) or parameters. Do not invent AWS CLI flags or AWS facts; cite AWS primary docs for any load-bearing fact.

## Where the skill and references live

- `skills/aws-cost-audit/SKILL.md` — the skill: Iron Laws, ordered workflow, the auto-execute-vs-recommend decision gate, highest-ROI checks, and a full worked example.
- `skills/aws-cost-audit/references/` — load-on-demand detail (hunt list, pricing verification, safety/gating, output/reporting, dashboard). `references/why-these-laws.md` records the agent-failure baseline each law fixes.
- `skills/aws-cost-audit/scripts/` — generic, parameterized, dry-run-by-default helpers (no hardcoded account/ARN/price), when present.
- `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` — plugin and marketplace manifests.
- `examples/` — worked example audit runs.
- `assets/` — optional HTML dashboard template generated from verified data.
- `docs/research/` — background research behind the skill.
- `README.md` — human-facing overview; `LICENSE` — MIT.

## Validate before claiming done

- `SKILL.md` front matter parses (valid YAML: `name`, `description`, `license`).
- `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` are valid JSON and name the repo `Aboudjem/aws-cost-audit-skill`.
- No hardcoded price, account id, ARN, or concrete resource id anywhere in the repo.
- All AWS CLI commands are read-only unless explicitly inside the gated remediation path.

## Q&A

**How do I audit my AWS bill with Claude?**
Install this skill — via the [10x marketplace](https://github.com/Aboudjem/10x) (recommended: `/plugin marketplace add Aboudjem/10x` then `/plugin install aws-cost-audit@10x`), directly from this repo (`/plugin marketplace add Aboudjem/aws-cost-audit-skill` then `/plugin install aws-cost-audit@aws-cost-audit-skill`), or by dropping `skills/aws-cost-audit/` into `~/.claude/skills/aws-cost-audit/` — make sure your AWS CLI is configured with your own credentials, then ask Claude Code to "audit my AWS bill" or "find my unused AWS resources." Claude verifies your identity, pulls Cost Explorer, inventories every Region and service, and returns an evidence-backed savings plan. It is read-only by default and verifies every price live for your exact Region.

**Will it delete anything or change my account?**
Not on its own. The skill is read-only by default. Any change is gated and must be proven-unused, reversible, and tested first; irreversible or uncertain actions are only ever recommendations that need your explicit sign-off.

**Where do the dollar figures come from?**
From live, Region-specific unit prices (AWS Price List Query API / the service pricing page) combined with your actual usage (Cost Explorer / CUR), shown as `unit price -> math -> source`. No price is ever hardcoded or recalled from memory.

**Does it work on any AWS account?**
Yes. It is account-agnostic and runs against whatever account your AWS credentials point to. It stores no secrets and hardcodes no account-specific values.
