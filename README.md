<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/hero-dark.svg">
    <source media="(prefers-color-scheme: light)" srcset="assets/hero-light.svg">
    <img src="assets/hero-dark.svg" alt="aws-cost-audit: cut the waste in your AWS bill, with every price checked live against AWS" width="100%">
  </picture>
</p>

<h1 align="center">aws-cost-audit</h1>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/github/license/Aboudjem/aws-cost-audit-skill" alt="MIT license"></a>
  <a href="https://github.com/Aboudjem/aws-cost-audit-skill/actions/workflows/validate.yml"><img src="https://img.shields.io/github/actions/workflow/status/Aboudjem/aws-cost-audit-skill/validate.yml?branch=main&label=validate" alt="validate workflow status"></a>
  <a href="https://github.com/Aboudjem/10x"><img src="https://img.shields.io/badge/part%20of-10x-FFB341" alt="Part of the 10x marketplace"></a>
</p>

<p align="center">
  <b>English</b> · <a href="READMEs/zh-CN.md">简体中文</a> · <a href="READMEs/ja.md">日本語</a> · <a href="READMEs/es.md">Español</a> · <a href="READMEs/fr.md">Français</a>
</p>

<p align="center">
  <strong>Cut the waste in your AWS bill, priced live.</strong>
</p>

<p align="center">
  Ask your agent to audit your AWS bill and get a verdict, three cuts to make first, and a live price behind each.
</p>

<p align="center">
  <a href="#sample-report">Sample report</a> · <a href="#why-use-it">Why use it</a> · <a href="#install">Install</a> · <a href="#how-it-works">How it works</a> · <a href="#proof">Proof</a> · <a href="#faq">FAQ</a> · <a href="#limits">Limits</a>
</p>

```bash
npx skills add Aboudjem/aws-cost-audit-skill -a claude-code
```

Swap `claude-code` for your agent: `codex`, `cursor`, `gemini-cli`, `github-copilot` or `opencode`.
Drop `-a` and the CLI asks you to pick. Claude Code plugin users: see [Install](#install).

Then ask your agent: `audit my AWS bill`. What it needs on your machine is under [Install](#install).

Give it read-only credentials: the skill guides your agent, the scripts enforce the yes.

## Sample report

Every report opens like this. This one is an illustration: a fictional account, invented figures, no real AWS data.
Re-print it from the repo with `bash skills/aws-cost-audit/scripts/findings-summary.sh examples/sample-findings.json`.

<!-- sample-report:begin -->

```text
VERDICT: save $242/mo now, safely. Up to $1,777/mo with sign-offs.
11 findings to act on: 4 safe now, 7 need sign-off. 1 to keep.

Do these three first:
1. OPTIMIZE 9 log groups that never expire (Amazon CloudWatch Logs, us-east-1): saves $84/mo. High confidence, reversible.
2. SAFE-TO-DELETE 4 unattached EBS volumes (vol-EXAMPLE1 to vol-EXAMPLE4) (Amazon EBS, us-east-1): saves $72/mo. High confidence, reversible.
3. OPTIMIZE abandoned multipart uploads in <demo-bucket> (Amazon S3, us-east-1): saves $58/mo. High confidence, reversible.

Detail:
- Save now safely: 4 findings, $242/mo
- Needs sign-off: 7 findings, $1,535/mo
- No verified cost: 0 findings, in no total
- Keep: 1 finding
Every figure above comes from the findings file. Nothing in your account was changed.
```

<!-- sample-report:end -->

The full report goes on with what you pay per service, each finding with its evidence, and how to undo it.
See [`examples/sample-report.md`](examples/sample-report.md) and the optional [HTML dashboard](examples/sample-dashboard.html).

It is for developers and small teams who pay the AWS bill without a FinOps person.
Cost Explorer shows the total, not what to turn off. This skill names what to cut.
Idle volumes, logs kept forever, uploads nobody finished: each finding carries its evidence and says if it can be undone.
Anything not both high confidence and reversible waits for the owner's sign-off.
Cost Explorer must be on, and AWS can take up to 24 hours to show data.

## Why use it

- **Know where to start.** A verdict in dollars, then the three cuts to make first.
  Proof: the sample above re-prints with the command above it, and `make test` compares the two line by line.
- **Trust the numbers.** Prices come from AWS at run time, not from memory or a blog table.
  Proof: `make test` and a CI scan both fail if a script holds a price literal.
- **Nothing changes by surprise.** It is dry-run by default: change scripts only print what they would do.
  With `--apply` they save a rollback file, then ask you to type yes. `--yes` skips the question.
  With no terminal to ask in and no `--yes`, they refuse. `make test` checks that order on the EBS script.

## Install

Inside Claude Code, from the [10x marketplace](https://github.com/Aboudjem/10x):

```bash
claude plugin marketplace add Aboudjem/10x
claude plugin install aws-cost-audit@10x
```

In any other agent, with the [skills CLI](https://github.com/vercel-labs/skills):

```bash
npx skills add Aboudjem/aws-cost-audit-skill
```

You also need the [AWS CLI](https://aws.amazon.com/cli/) with read access to the account, and `jq`.
The AWS managed `ReadOnlyAccess` policy plus billing read (`ce:Get*`, `pricing:GetProducts`) is enough.

Then ask your agent: `audit my AWS bill`. It checks your setup first and names anything missing.

A sign-off means the resource owner agrees before anything changes.
Savings that are not both high confidence and reversible need one.

### Works with

| Agent                | Install command                                                  | Tested     |
| :------------------- | :--------------------------------------------------------------- | :--------- |
| Claude Code (plugin) | `claude plugin install aws-cost-audit@10x`                       | 2026-11-17 |
| Claude Code (skill)  | `npx skills add Aboudjem/aws-cost-audit-skill -a claude-code`    | 2026-11-17 |
| Codex                | `npx skills add Aboudjem/aws-cost-audit-skill -a codex`          | 2026-11-17 |
| Cursor               | `npx skills add Aboudjem/aws-cost-audit-skill -a cursor`         | 2026-11-17 |
| Gemini CLI           | `npx skills add Aboudjem/aws-cost-audit-skill -a gemini-cli`     | 2026-11-17 |
| GitHub Copilot       | `npx skills add Aboudjem/aws-cost-audit-skill -a github-copilot` | 2026-11-17 |
| OpenCode             | `npx skills add Aboudjem/aws-cost-audit-skill -a opencode`       | 2026-11-17 |

"Tested" means the install ran and `SKILL.md` landed where the agent reads it.
CI repeats the install for Claude Code, Codex and Cursor on every push.

Documented, not tested end to end: Pi, Mistral Vibe, Trae, OpenClaw, Antigravity, Hermes, Cline and Kimi.
Their agent codes were accepted by the pinned skills CLI on 2026-11-17. Install them with `install.sh`, from a clone:

```bash
git clone https://github.com/Aboudjem/aws-cost-audit-skill && cd aws-cost-audit-skill
./install.sh pi
```

That installs for your whole user profile. Add `--project` to install into the current folder only.
Per-editor paths are in [docs/editors.md](docs/editors.md).

<details>
<summary>Copy the skill by hand instead</summary>

The skill is a folder of Markdown and shell scripts. Copy it where your agent reads skills:

```bash
git clone https://github.com/Aboudjem/aws-cost-audit-skill
mkdir -p ~/.claude/skills
cp -r aws-cost-audit-skill/skills/aws-cost-audit ~/.claude/skills/aws-cost-audit
```

This repo has no marketplace manifest of its own. Use the 10x marketplace above for the plugin path.
</details>

## How it works

<p align="center">
  <img src="assets/how-it-works.svg" alt="How it works: 1 re-baseline live, 2 hunt waste across every region, 3 evidence-backed savings plan" width="100%">
</p>

1. **Preflight.** `doctor.sh` checks the AWS CLI, credentials, `jq`, the region and the output folder. It changes nothing.
2. **Baseline.** Cost Explorer gives your spend by service, region and usage type. The scripts count each request and stop at a cap.
3. **Hunt.** It sweeps every enabled region for idle, oversized or forgotten resources. The checks are in [the hunt list](skills/aws-cost-audit/references/hunt-list.md).
4. **Price.** Every dollar is the live unit price for your region times your real usage. No price comes from memory.
5. **Sort.** Each finding is KEEP, OPTIMIZE or SAFE-TO-DELETE, with a confidence level and its evidence.
6. **Report.** `findings-validate.sh` checks `findings.json`, then `findings-summary.sh` prints the verdict and the three actions. The detail follows.

Nothing changes in your account unless you ask. Three scripts can change something, and the code enforces this:

- Without `--apply` they only print a dry run.
- With `--apply` they save a rollback file first, then ask you to type `yes`.
- `--yes` skips that question. With no terminal to ask in and no `--yes`, they refuse before any change.

The skill also tells your agent to show you proof of non-use and the dry run first, then wait for your yes.
It tells your agent to keep irreversible actions, like a Savings Plan purchase, as recommendations.

The skill itself is [`SKILL.md`](skills/aws-cost-audit/SKILL.md): five rules, the steps, and reference files it loads on demand.

## Proof

Every number below is re-printed by the command next to it.

| Claim                                      | Command                                                      | Output today                                                                  |
| :----------------------------------------- | :----------------------------------------------------------- | :---------------------------------------------------------------------------- |
| The offline suite passes                   | `make test`                                                  | `Results: 106 passed, 0 failed`                                                |
| The sample above is the tool's real output | `make test` (case 39 compares them line by line)             | `[PASS] sample: the README sample report is the script output, line for line` |
| The plugin manifest is valid               | `claude plugin validate . --strict`                          | `✔ Validation passed`                                                         |
| No unit price is written into a script     | `make test` (no-hardcoded-price case)                        | `[PASS] no per-request price literal in any script`                           |

The suite stubs the `aws` command, so it needs no credentials and makes no AWS call.
It also checks the safety order of `delete-unattached-ebs.sh`: no change before the confirmation.
CI adds a scan of every script for a hardcoded unit price.
CI runs it on every push and pull request, with shellcheck and the skills CLI install.

What the scripts may call, and what they never send anywhere, is in [PRIVACY.md](PRIVACY.md).

## FAQ

**Will it delete anything on its own?**
No. It reads by default. A change script runs only with `--apply`, saves a rollback file, then asks you to type `yes`.
`--yes` skips the question, and the skill tells your agent to pass it only after you said yes in the chat.
The skill tells your agent to show proof of non-use and the dry run first. Irreversible actions stay recommendations.

**Does it need my AWS keys?**
No. It uses the AWS CLI credentials already on your machine. Your data goes to AWS and to your agent, nowhere else.

**What does one audit cost to run?**
Cost Explorer bills each API request. The scripts count every page and stop at `AWS_COST_AUDIT_CE_BUDGET`, 50 by default. Price List lookups are free.

**Why trust the dollar figures?**
Each one shows the unit price, the math and the source. A figure that cannot be verified is written "unknown" and stays out of every total.

**Are the sample figures real?**
No. The sample report, the dashboard and the demo use a fictional account. Nothing in them was read from a real AWS bill.

**Can I compare two audits?**
Yes. Ask for `findings.json`. `findings-validate.sh` checks it against a fixed contract, so two runs can be diffed.

More answers are in [docs/faq.md](docs/faq.md).

## Limits

- It needs the AWS CLI v2, bash and `jq`. On Windows, the scripts need a bash shell; see [docs/editors.md](docs/editors.md).
- The baseline needs Cost Explorer turned on. After you turn it on, AWS can take up to 24 hours to show data.
- The skill guides your agent. A weaker model can still skip a step, so check the evidence lines.
- Prices are in USD, as AWS returns them.
- "Tested" in the agent table means the install ran and the files landed. It does not mean each agent was seen loading the skill.
- Proof of non-use and the dry run before a change are steps the skill asks of your agent. The scripts enforce `--apply`, the rollback file and the `yes`.

## Learn more

- [Quickstart](docs/quickstart.md): from credentials to dashboard, step by step.
- [Editor and agent support](docs/editors.md): one line per agent, plus the manual copy.
- [How it compares](docs/comparison.md): against a manual audit and a cost dashboard.
- [CHANGELOG](CHANGELOG.md) · [CONTRIBUTING](CONTRIBUTING.md) · [Privacy](PRIVACY.md) · [MIT license](LICENSE)

---

<sub>Built and maintained by <a href="https://github.com/Aboudjem">Adam Boudjemaa</a>. Spot a stale command? <a href="https://github.com/Aboudjem/aws-cost-audit-skill/issues">Open an issue</a>.</sub>
