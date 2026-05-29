# Contributing to AWS Cost Audit Skill

Thanks for wanting to help. This is an executable Claude Code skill that audits a
**live AWS account** — any user's own account, read from their current AWS
credentials. Because it touches real billing data and can recommend real changes,
it is built carefully and tested-first. This guide explains how to add to it
without breaking that contract.

Contributions of every size are welcome: a new check, a sharper safety gate, a
clearer reference doc, a typo fix. Open an issue first if you want to discuss a
larger change.

## Repo layout

```
skills/aws-cost-audit/
  SKILL.md              the skill: Iron Laws, ordered workflow, decision gate,
                        highest-ROI checks, worked example
  references/           load-on-demand detail pulled in only when needed
    safety-and-gating.md
    output-and-reporting.md
    why-these-laws.md   the agent-failure baseline each Law fixes (the "RED" record)
  scripts/              generic, parameterized, dry-run-by-default helpers
    _lib.sh             shared helpers (region resolution, preflight, no hardcoded anything)
    00-baseline.sh, inventory-regions.sh, find-idle.sh, ...
  assets/               optional HTML dashboard template, generated from verified data
.claude-plugin/
  plugin.json           plugin manifest
  marketplace.json      marketplace manifest
docs/research/          background research behind the skill
examples/               worked example audit output
AGENTS.md               instructions for AI agents working in / invoking this repo
README.md               human-facing overview
LICENSE                 MIT
```

`AGENTS.md` is the source of truth for how the skill behaves and the safety rules
it enforces. Read it before changing anything in `skills/`.

## We build TEST-FIRST (RED → GREEN → REFACTOR)

This skill exists to fix specific, observed agent failures (for example: agents
confidently stating *memorized* AWS prices instead of verifying them live). Every
section of the skill traces back to a failure we watched happen first.

**The rule: no new skill section, Law, or behavioral guarantee lands without a
failing baseline test first.**

1. **RED — watch it fail.** Before you write skill text, run the scenario against
   an agent that does *not* have your change (or doesn't have the skill at all) and
   record what it does wrong, verbatim. Test the weak case too, not just a strong
   model — the skill must hold on cheaper models and under pressure. See
   `docs/research/RED-baseline-findings.md` and `references/why-these-laws.md` for
   the format: identical inputs, the wrong/inconsistent output, and *why* it's
   dangerous.
2. **GREEN — write the minimum that fixes it.** Add the skill text / gate /
   contract that makes that exact failure stop happening. Re-run the same scenario
   and show it now behaves. Map your change 1:1 to the baseline it fixes.
3. **REFACTOR — tighten.** Clean up wording, move detail into `references/` if
   `SKILL.md` is getting heavy, deduplicate — without changing behavior. Re-run to
   confirm the test still passes.

A PR that adds behavior but cites no baseline failure it fixes will be sent back
for a RED step. "I think an agent might…" is not a baseline; "here is the agent
doing it" is.

## Hard rules you must keep

These are non-negotiable. They mirror the skill's Iron Laws in `AGENTS.md` /
`SKILL.md`. Don't look for loopholes — violating the letter violates the spirit.

- **Generic and account-agnostic.** The skill must work on *any* user's account,
  read live from their credentials. Never assume an account, Region, service, or
  resource — read them. Parameterize the Region; never hardcode one as the default
  (use `us-east-1` only as a neutral *example*).
- **Zero secrets, zero account-specific data.** Never commit a 12-digit AWS account
  id, a concrete ARN, a public IP, or a concrete resource id (instance / volume /
  NAT / ENI / CloudFront / allocation id). Use placeholders: `<your-account>`,
  `$REGION`, `vol-EXAMPLE`, etc. The `.gitignore` already blocks audit output,
  credentials, and generated reports — don't override it.
- **ZERO hardcoded AWS prices — verify live.** Never write a unit price, a monthly
  cost, or a "$X saved" figure into the skill, a script, a reference, or an example.
  Every dollar must come from BOTH the live, Region-specific unit price (AWS Price
  List Query API or the service's pricing page) AND the user's actual usage (Cost
  Explorer / CUR), shown as `unit price → math → source`. Prices are Region-specific
  and change; a memorized price is a guess.
- **Nothing destructive without the gate.** Discovery is read-only (describe / list
  / get only). Anything that deletes, terminates, releases, detaches, expires, or
  purchases is allowed only when it is proven-unused (multiple live signals over
  30–90 days), reversible, tested in dry-run, and the blast radius is 100% known —
  and only behind the executor → verifier → rollback gate. Irreversible or uncertain
  actions are NEVER auto-run; they are recommendations needing explicit human
  sign-off. When in doubt, recommend — don't act.
- **Don't invent AWS facts.** No made-up CLI flags, service behaviors, or pricing.
  Cite AWS primary docs for any load-bearing claim.

## Testing locally

Before opening a PR, verify your change three ways:

1. **Validate the plugin.**
   ```bash
   claude plugin validate .
   ```
   This must pass. Also confirm `SKILL.md` front matter is valid YAML (`name`,
   `description`, `license`) and that `.claude-plugin/plugin.json` and
   `marketplace.json` are valid JSON naming `Aboudjem/aws-cost-audit-skill`.

2. **Run the skill for real.** Drop the skill into your local Claude Code and
   exercise the path you changed:
   ```bash
   cp -r skills/aws-cost-audit ~/.claude/skills/aws-cost-audit
   ```
   Then ask Claude Code to do the thing your change affects (e.g. "audit my AWS
   bill", "find my unused AWS resources"). Use a real account *you own* — never
   paste someone else's account data into the repo or a PR.

3. **Run scripts in dry-run.** The helper scripts are dry-run-by-default and must
   stay that way. Run them and confirm they only emit describe/list/get calls and
   never mutate anything unless an explicit, gated apply flag is set. Confirm region
   resolution still works with no Region hardcoded (`_lib.sh` resolves it from the
   argument, `$AWS_REGION`, `$AWS_DEFAULT_REGION`, or `aws configure get region`).

A quick self-check before pushing: `grep` your diff for any 12-digit number, ARN,
IP, dollar sign followed by a number, or concrete resource id. If you find one that
isn't a placeholder, fix it.

## Commit and PR etiquette

- Branch off the default branch; don't commit directly to it.
- Keep commits focused and messages descriptive (what changed and *why* — link the
  baseline failure your change fixes).
- One logical change per PR. Smaller PRs get reviewed faster.
- In the PR description, include: the RED baseline (the failure you observed), the
  GREEN fix, and how you verified it (validate output, a sample run, dry-run logs
  with any account-specific values redacted).
- Be kind in review. We give and receive feedback in good faith — see
  `CODE_OF_CONDUCT.md`.

## CI must pass

Every PR runs CI. It must be green before merge. CI enforces the same gates you
ran locally — plugin validation, manifest JSON validity, and a scan for hardcoded
secrets / account ids / prices. If CI fails, read the log and push a fix; don't ask
for a merge override.

Thanks again — careful contributions to a tool that touches people's real cloud
bills genuinely matter.
