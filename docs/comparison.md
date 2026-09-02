# How it compares

Three ways to find waste in an AWS bill: this skill, a person with a terminal, and a hosted cost
dashboard. None of them is wrong. They differ in who checks the arithmetic and where your data
goes.

| | aws-cost-audit | A manual audit | A hosted cost dashboard |
|:--|:--|:--|:--|
| Runs against your live account | Yes | Yes | Yes |
| Cost to start | None, MIT licensed | None | Usually a paid plan |
| Verifies each price live | Yes, per region, per run | Depends on the person | Shows its own figures |
| Attributes cost, owner, and last used per resource | Yes | Slow, by hand | Partial |
| Can act on a finding | Yes, gated and reversible | Yes, manually | Read-only |
| Produces a shareable report | Yes, Markdown and HTML | By hand | Yes |
| Sends your data to a third party | No | No | Usually |
| Lock-in | None | None | Vendor |

## The single differentiator

Every dollar carries its own arithmetic. A finding is not "you could save about $40 a month on
this volume", it is the live unit price for your region, the usage that price was multiplied by,
the API the price came from, and how to reverse the change. That is checkable by someone who did
not run the audit, which is the part a dashboard screenshot cannot give you.

## Where the other tools are genuinely better

- **Hosted dashboards** see your organisation's negotiated discounts and can aggregate savings
  across accounts. A per-resource audit run from one CLI session cannot.
- **A person who knows the account** knows which idle instance is idle on purpose. The skill
  marks a resource unused only on evidence, so it is deliberately conservative, and it will
  leave findings on the table that a human would clear in a minute.
- **Policy engines** such as Cloud Custodian keep rules in version control and re-run them on a
  schedule. This skill runs when you ask it to.

## What it deliberately does not do

- It does not delete anything on its own, however safe the resource looks. Every destructive
  path is gated behind proven-unused, reversible, dry-run, and your confirmation.
- It does not cache or hardcode prices to save API calls. Region-specific prices drift, and a
  remembered price is the failure this skill exists to prevent.
- It does not depend on a hosted service or an MCP server at runtime. It shells out to the AWS
  CLI you already have, so there is no new trust boundary.
