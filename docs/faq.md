# FAQ

Short answers to the questions that come up before the first run. The
[quickstart](quickstart.md) has the long version.

## How do I audit my AWS bill with Claude?

Install the skill, then ask Claude Code to "audit my AWS bill". It reads your account with the
AWS CLI and produces an evidence-backed cost report and a savings plan. Other phrasings that
trigger it: "where is my AWS money going", "find unused AWS resources", "cut my AWS costs",
"check my Savings Plans coverage".

## Is it safe? Will it delete anything?

It is read-only by default. It will not delete, stop, or change anything on its own. Any action
is gated: the resource must be proven unused, the change must be reversible, it must pass a dry
run, and you must confirm. Irreversible actions are always left as recommendations.

## Does it need my AWS keys?

No. It uses your existing AWS CLI credentials on your own machine. Your audit goes to no third
party, and the only network traffic the scripts make is the AWS CLI talking to AWS. The AWS
managed `ReadOnlyAccess` policy plus billing read is enough for the audit.

## Does it work on my account?

Yes. It is generic. It reads whatever account your CLI is pointed at, across every enabled
region, and ships with no account ids, ARNs, or prices baked in.

## Does it hardcode AWS prices?

No, on purpose. Prices change and vary by region, so it fetches the live price for your region
and combines it with your real usage. The one figure this repo records is Cost Explorer's own
per-request API charge, which is the cost of running the audit rather than the price of anything
the audit reports on. It lives in
[`references/pricing-verification.md`](../skills/aws-cost-audit/references/pricing-verification.md)
with its AWS source, and it never enters a finding.

## What does an audit cost to run?

Cost Explorer bills per paginated API request. The scripts route every request through one
wrapper that counts pages and refuses the one past `AWS_COST_AUDIT_CE_BUDGET`, which defaults to
50. At the end of a run, and on an early exit, the wrapper prints the count and the estimated
spend. An `aws ce` call you make yourself, outside the scripts, is not in that count. Price List
API lookups, the usual source for a unit price, are free.

## What does it cover?

Idle and unattached resources, gp2 to gp3 migration, old snapshots and AMIs, NAT and
data-transfer costs, idle load balancers, rightsizing, Savings Plans and Reserved Instance
coverage, S3 lifecycle, CloudWatch log retention, cross-region leftovers, and missing budgets or
alerts. The full list, with the read-only command that detects each one, is in
[the hunt list](../skills/aws-cost-audit/references/hunt-list.md).

## Can I use it without the plugin system?

Yes. Copy `skills/aws-cost-audit/` into `~/.claude/skills/aws-cost-audit/` and it works the same
way. The helper scripts under `skills/aws-cost-audit/scripts/` also run on their own, with bash
and the AWS CLI. `findings-validate.sh` additionally needs `jq`.

## Why should I trust the numbers?

The skill is built around five rules it will not break. They are stated in full in
[`SKILL.md`](../skills/aws-cost-audit/SKILL.md) and argued in
[`why-these-laws.md`](../skills/aws-cost-audit/references/why-these-laws.md).

1. **No made-up prices.** Every dollar comes from the live AWS price for your region plus your
   actual usage, shown as unit price, then the math, then the source.
2. **Attribute every dollar, or say "unknown".** It never invents an owner, a date, or a
   last-used timestamp.
3. **Nothing destructive without proof.** A change runs only if the resource is proven unused,
   the action is reversible, it passed a dry run, and the result is certain. Otherwise it stays
   a recommendation.
4. **One sample is never the whole fleet.** A separate skeptic pass re-derives the headline
   numbers from the source before they ship.
5. **Every finding shows its evidence.** Current cost, cost after, dollars saved, a confidence
   level, the proof, and how to undo it.

These rules exist because the same questions were put to agents without the skill and the
answers did not hold up. The recorded baseline is in
[`docs/research/RED-baseline-findings.md`](research/RED-baseline-findings.md): asked for the same
savings number, two models confidently returned two different wrong figures from memory.

## Can I diff two audits?

Yes, when a run emits `findings.json`. The contract is pinned in
[`references/output-and-reporting.md`](../skills/aws-cost-audit/references/output-and-reporting.md):
nine required keys per finding, eight optional ones, and unknown keys rejected. Check a file
before you diff it:

```bash
bash skills/aws-cost-audit/scripts/findings-validate.sh findings.json
```

It exits 0 when the file is valid, 1 with one line per problem, and 2 when it could not check at
all, which is what a missing `jq` gives you rather than a false pass.

## Are the demo figures real?

No. The recording in the README, the sample report, and the sample dashboard all use synthetic
data on no real account, and every figure in them is labelled illustrative. AWS calls need live
credentials, so a recorded run against a real bill would publish someone's account.
