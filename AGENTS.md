# AGENTS.md: AWS Cost Audit Skill

Instructions for AI agents and coding assistants working in or invoking this repository. Plain Markdown, no required fields (per the AGENTS.md convention: the agent simply parses the text below). Human-facing docs live in `README.md`; this file holds the extra context an agent needs.

## What this repo is

This repo is an executable agent skill, `aws-cost-audit`, that finds what to stop paying for on an AWS bill. It audits a live AWS account. It attributes every dollar, finds idle, orphaned or oversized resources, and checks Savings Plans and Reserved Instance coverage. It produces an evidence-backed savings plan with confidence levels and gated actions. It runs against **the account in the caller's current AWS credentials**, so it is account-agnostic and works on any user's own account. It is dry-run by default: the change scripts need `--apply`, save a rollback file, then ask for a typed `yes`. `--yes` skips the question; with no terminal and no `--yes`, they refuse. It takes each price from AWS during the audit (a Price List lookup, or a Cost Explorer read for tiered prices) and records each lookup. No script holds a resource price. MIT licensed.

The skill targets Claude Code and shells out to the AWS CLI. The skill definition is `skills/aws-cost-audit/SKILL.md`; supporting material is in `skills/aws-cost-audit/references/`.

**Editor support:** the plugin/skill installation mechanism is Claude Code-specific. For other AI editors (Cursor, VS Code with Copilot, Windsurf, Codex, Gemini CLI), copy `skills/aws-cost-audit/SKILL.md` and the `references/` folder as custom context/instructions, and run the helper scripts in `skills/aws-cost-audit/scripts/` directly; the audit scripts depend only on the AWS CLI, with `jq` optional for nicer output. The one exception is `findings-validate.sh`, which needs `jq` to do its job and exits 2 saying so rather than reporting a file as valid unchecked; it is a validation helper, not part of the audit path.

## How an agent should invoke the skill

- If running inside Claude Code with the skill installed: trigger it by describing the user's intent (e.g. "audit my AWS bill", "find unused AWS resources", "check our Savings Plans coverage", "where is my AWS money going"). Claude Code matches these to the skill's description and loads `SKILL.md`.
- To install via the [10x marketplace](https://github.com/Aboudjem/10x) (recommended): `/plugin marketplace add Aboudjem/10x` then `/plugin install aws-cost-audit@10x`.
- There is no direct-from-this-repo plugin path: this repo ships no `.claude-plugin/marketplace.json`, so `/plugin marketplace add Aboudjem/aws-cost-audit-skill` has nothing to resolve. Use 10x, `npx skills add Aboudjem/aws-cost-audit-skill -g` (recommended; all your projects, pick your agent in the menu; drop `-g` for one project), or the drop-in copy.
- To install as a drop-in skill: copy `skills/aws-cost-audit/` into `~/.claude/skills/aws-cost-audit/`.
- Prerequisite: a working AWS CLI configured with the user's own credentials. Confirm identity first with `aws sts get-caller-identity`. Never assume an account, Region, or resource; read them live. Parameterize the Region (do not hardcode one default).

## Safety rules an agent MUST honor

These are non-negotiable. They mirror the skill's five Iron Laws in `SKILL.md`. Do not look for loopholes; violating the letter violates the spirit.

1. **Read-only by default.** Run only describe/list/get-style commands during discovery. Treat any change as gated.
2. **Never run a destructive action ungated.** Anything that deletes, terminates, releases, detaches, expires, or purchases (delete snapshot/AMI, terminate instance, release Elastic IP, S3 lifecycle expiry, Savings Plan / RI purchase) is allowed only when the resource is proven-unused (multiple live signals over 30–90 days), reversible, tested in dry-run, and you are 100% sure of the blast radius, and only via an executor -> verifier -> rollback gate. Irreversible actions are NEVER auto-run; they are recommendations requiring explicit human sign-off. When in doubt, recommend, do not act.
3. **Never hardcode or guess a price; verify live.** Do not state any unit price, monthly cost, or "$X saved" from memory. Every dollar figure must come from BOTH the live, Region-specific unit price (AWS Price List Query API, recorded with `scripts/verify-price.sh --record`) AND the user's actual usage (Cost Explorer / CUR). Always show `unit price -> math -> source`. In `findings.json`, a dollar figure needs a `price_lookups` record, or `findings-validate.sh` rejects it. When no single unit price applies (a tiered price, a Savings Plan, a resource deleted outright), record the Cost Explorer read instead. Prices are Region-specific and change; a memorized price is a guess. Never write a price into the skill, a script, or a report.
4. **Attribute every dollar or say "unknown."** For each resource, report cost, purpose, owning app/repo, creator (CloudTrail), created-when, and last-used (CloudWatch / access logs / last-invocation). If any cannot be determined, write "unknown, could not verify". Never invent an owner, a date, or a last-used value.
5. **No single probe becomes a fleet-wide fact.** Fan out checks across resources and Regions. A separate skeptic pass must re-derive every load-bearing claim (the headline savings total, each "safe-to-delete" verdict) from the primary source, not from another agent's summary.
6. **Every finding carries its evidence.** Output contract per item: `current $/mo -> after $/mo -> $ saved -> confidence (High/Med/Low) + evidence + reversibility`. Split totals into "save now safely" (High-confidence, reversible, tested) vs "max theoretical save".

Additional hygiene for agents editing this repo: never commit a real 12-digit AWS account id, a concrete ARN, a public IP, or a concrete resource id (instance/volume/NAT/ENI/CloudFront/allocation id). Use generic placeholders (`$REGION`, `vol-EXAMPLE`, `<your-account>`) or parameters. Do not invent AWS CLI flags or AWS facts; cite AWS primary docs for any load-bearing fact.

## Where the skill and references live

- `skills/aws-cost-audit/SKILL.md`: the skill: Iron Laws, ordered workflow, the auto-execute-vs-recommend decision gate, highest-ROI checks, and a full worked example.
- `skills/aws-cost-audit/references/`: load-on-demand detail (hunt list, pricing verification, safety/gating, output/reporting, dashboard). `references/why-these-laws.md` records the agent-failure baseline each law fixes.
- `skills/aws-cost-audit/scripts/`: generic, parameterized, dry-run-by-default helpers (no hardcoded account/ARN/price), when present.
- `.claude-plugin/plugin.json`, `.cursor-plugin/plugin.json`, and `.copilot-plugin/plugin.json`: the plugin manifests for Claude Code, Cursor, and Copilot. The skill is distributed through the [10x marketplace](https://github.com/Aboudjem/10x), which holds the marketplace manifest; this repo ships none of its own.
- `examples/`: a SAMPLE report, dashboard and `findings.json` for a fictional account.
- Report order: the verdict, then the three things to do first, then the detail. Print the opening with `scripts/findings-summary.sh findings.json`.
- `assets/`: optional HTML dashboard template generated from verified data.
- `docs/research/`: background research behind the skill.
- `README.md`: human-facing overview; `LICENSE`: MIT.

## Validate before claiming done

- `SKILL.md` front matter parses (valid YAML: `name`, `description`, `license`).
- `.claude-plugin/plugin.json`, `.cursor-plugin/plugin.json`, and `.copilot-plugin/plugin.json` are valid JSON and name the repo `Aboudjem/aws-cost-audit-skill`.
- `make test` passes (offline suite, stubbed `aws`, needs `jq`) and `claude plugin validate . --strict` exits 0.
- No hardcoded price, account id, ARN, or concrete resource id anywhere in the repo. `examples/` holds the only figures: invented, marked SAMPLE.
- All AWS CLI commands are read-only unless explicitly inside the gated remediation path.

## Q&A

**How do I audit my AWS bill with Claude?**
Install this skill via the [10x marketplace](https://github.com/Aboudjem/10x) (recommended: `/plugin marketplace add Aboudjem/10x` then `/plugin install aws-cost-audit@10x`), in any other agent with `npx skills add Aboudjem/aws-cost-audit-skill -g` (recommended; installs for all your projects, pick your agent in the menu), or by dropping `skills/aws-cost-audit/` into `~/.claude/skills/aws-cost-audit/`. Make sure your AWS CLI is configured with your own credentials, then ask Claude Code to "audit my AWS bill" or "find my unused AWS resources." Claude verifies your identity, pulls Cost Explorer, inventories every Region and service, and returns an evidence-backed savings plan. It is read-only by default. Each unit price comes from the AWS Price List for your Region during the audit (tiered prices from a Cost Explorer read), and the validator rejects a dollar figure with no lookup record.

**Will it delete anything or change my account?**
Not on its own. The skill is read-only by default. Any change is gated and must be proven-unused, reversible, and tested first; irreversible or uncertain actions are only ever recommendations that need your explicit sign-off.

**Where do the dollar figures come from?**
From Region-specific unit prices the AWS Price List returns at run time, combined with your actual usage (Cost Explorer / CUR), shown as `unit price -> math -> source`. Each priced finding records that lookup, and `findings-validate.sh` rejects one that does not. When no single unit price applies, the finding records the Cost Explorer read instead. The one stored figure is the audit's own Cost Explorer request cost. No resource price is ever hardcoded or recalled from memory.

**Does it work on any AWS account?**
Yes. It is account-agnostic and runs against whatever account your AWS credentials point to. It stores no secrets and hardcodes no account-specific values.
