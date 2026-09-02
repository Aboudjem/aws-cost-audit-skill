<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/hero-dark.svg">
    <source media="(prefers-color-scheme: light)" srcset="assets/hero-light.svg">
    <img src="assets/hero-dark.svg" alt="aws-cost-audit: a savings plan you can check, with every number verified against live AWS pricing" width="100%">
  </picture>
</p>

<h1 align="center">aws-cost-audit</h1>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/github/license/Aboudjem/aws-cost-audit-skill" alt="MIT license"></a>
  <a href="https://github.com/Aboudjem/aws-cost-audit-skill/actions/workflows/validate.yml"><img src="https://img.shields.io/github/actions/workflow/status/Aboudjem/aws-cost-audit-skill/validate.yml?branch=main&label=validate" alt="validate workflow status"></a>
  <a href="https://github.com/Aboudjem/aws-cost-audit-skill/stargazers"><img src="https://img.shields.io/github/stars/Aboudjem/aws-cost-audit-skill" alt="GitHub stars"></a>
  <a href="https://github.com/Aboudjem/10x"><img src="https://img.shields.io/badge/part%20of-10x-FFB341" alt="Part of the 10x marketplace"></a>
</p>

<p align="center">
  <b>English</b> · <a href="READMEs/zh-CN.md">简体中文</a> · <a href="READMEs/ja.md">日本語</a> · <a href="READMEs/es.md">Español</a> · <a href="READMEs/fr.md">Français</a>
</p>

<p align="center">
  <strong>Ask Claude to audit your AWS bill. Every number is checked against live AWS pricing.</strong>
</p>

<p align="center">
  <a href="#what-it-does">What it does</a> · <a href="#install">Install</a> · <a href="#use-it">Use it</a> · <a href="#what-you-get">What you get</a> · <a href="#works-in-your-editor">Works in your editor</a> · <a href="#good-to-know">Good to know</a>
</p>

![aws-cost-audit demo](assets/demo.gif)

<p align="center"><sub>Every figure in the recording is <b>illustrative</b>: synthetic data, no real account.</sub></p>

```bash
claude plugin marketplace add Aboudjem/10x
claude plugin install aws-cost-audit@10x
```

## What it does

It is a skill for [Claude Code](https://www.claude.com/product/claude-code): a Markdown instruction file, six reference documents it loads only when it needs them, and ten bash helper scripts. Claude picks it up when you ask about AWS spend.

You say "audit my AWS bill". It reads your account through the AWS CLI you already have, works out what each resource costs and why, and hands you a plan. It reads only by default. It never quotes a price from memory, and it never deletes anything on its own.

- **A spend breakdown.** What you pay per service and per region, pulled live from Cost Explorer.
- **A per-resource view.** What each thing costs, what it does in plain words, who made it, and when it was last used. If a fact cannot be verified it says so instead of guessing.
- **A savings plan in two halves.** "Save now safely" (reversible, high confidence) kept apart from "maximum theoretical save", which needs your sign-off.

The method follows the [AWS Well-Architected cost-optimization pillar](https://docs.aws.amazon.com/wellarchitected/latest/cost-optimization-pillar/welcome.html) and the [FinOps Foundation](https://www.finops.org/framework/) framework, so it is not something the skill made up.

## Install

Inside Claude Code, from the [10x marketplace](https://github.com/Aboudjem/10x):

```bash
claude plugin marketplace add Aboudjem/10x
claude plugin install aws-cost-audit@10x
```

In any other agent, through the [Vercel skills CLI](https://github.com/vercel-labs/skills):

```bash
npx skills add Aboudjem/aws-cost-audit-skill
```

You also need the [AWS CLI](https://aws.amazon.com/cli/) configured with read access to the account you want to audit. The AWS managed `ReadOnlyAccess` policy plus billing read is enough for the audit itself.

<details>
<summary>Copy the skill by hand instead</summary>

Skip the plugin system entirely. The skill is a directory of Markdown and shell scripts, so copying it into a directory your agent reads is enough:

```bash
git clone https://github.com/Aboudjem/aws-cost-audit-skill
mkdir -p ~/.claude/skills
cp -r aws-cost-audit-skill/skills/aws-cost-audit ~/.claude/skills/aws-cost-audit
```

This repo carries no marketplace manifest of its own, so `claude plugin marketplace add Aboudjem/aws-cost-audit-skill` will not resolve. The 10x marketplace above is the plugin path. Windows and the per-editor paths are in [docs/editors.md](docs/editors.md).
</details>

## Use it

**1. Check the environment.** `doctor.sh` names what is missing before an audit starts. It makes no AWS call that changes anything, it has no apply flag, and it removes the probe file it writes:

```bash
bash skills/aws-cost-audit/scripts/doctor.sh --offline
```

```text
aws-cost-audit doctor

[OK]   aws CLI found: aws-cli/2.33.9 Python/3.13.12 Darwin/25.3.0 source/arm64
[SKIP] caller identity (--offline)
[OK]   jq found: jq-1.7.1-apple
[OK]   region resolves to ap-southeast-1
[OK]   output directory writable: ./cost-audit-out
[SKIP] Cost Explorer probe (opt in with --check-cost-explorer; the request is billed)

No blockers. This environment can run an audit.
```

**2. Ask Claude.** Say `audit my AWS bill`, or `find my unused AWS resources`. The skill is written to trigger on that phrasing. Tell it which profile and regions to look at if you have more than one account.

**3. Read the plan.** You get a report and, if you want one, an HTML dashboard. Nothing in your account changes unless you ask, and even then only after a dry run and your confirmation.

<p align="center">
  <img src="assets/how-it-works.svg" alt="How it works: 1 re-baseline live, 2 hunt waste across every region, 3 evidence-backed savings plan" width="100%">
</p>

The full walkthrough, from credentials to dashboard, is in the [quickstart](docs/quickstart.md).

## What you get

- **A report.** Each finding reads `current $/mo -> after $/mo -> $ saved`, with the evidence, a confidence level, and how to undo it. See [`examples/sample-report.md`](examples/sample-report.md).
- **A dashboard, optionally.** One HTML file a non-technical person can open. It pulls its font and its chart library from a CDN, so it looks right on a machine with a network. See [`examples/sample-dashboard.html`](examples/sample-dashboard.html).
- **A machine-readable `findings.json`, on request.** `findings-validate.sh` checks it against a pinned structural contract, which is what makes two audits comparable instead of re-read.
- **A live price for every dollar.** Unit price, the math, and the source, looked up for your region. The Price List Query API is the first stop; where a figure cannot be verified it stays marked unknown.
- **Guardrails.** It reports whether you have budgets and cost-anomaly alerts, and helps you set them.

## Works in your editor

| Agent | One-line install |
|:--|:--|
| Claude Code | `claude plugin install aws-cost-audit@10x` |
| Any of 70+ other agents | `npx skills add Aboudjem/aws-cost-audit-skill` |
| Codex, Gemini CLI, OpenCode, Pi | `./install.sh codex` (or `gemini`, `opencode`, `pi`) |
| VS Code with Copilot | `./install.sh copilot` |
| Everything else | see [docs/editors.md](docs/editors.md) |

Works in Claude Code, Cursor, Codex, Copilot, Gemini CLI, and 70+ other agents through `npx skills add`. `install.sh` is the wrapper for the thirteen editor ids this repo has always supported, and it now delegates to that same CLI:

```bash
curl -fsSL https://raw.githubusercontent.com/Aboudjem/aws-cost-audit-skill/main/install.sh | bash -s codex
```

This plugin ships no MCP server, on purpose. It shells out to the AWS CLI you already have, so there is no extra process to run and nothing to add to an `.mcp.json`.

## Good to know

> [!IMPORTANT]
> It is read-only by default. It will not delete, stop, or change anything on its own. Any action is gated: the resource must be proven unused, the change must be reversible, it must pass a dry run, and you must confirm. Irreversible actions stay recommendations.

- **No prices from memory.** Every dollar comes from the live AWS price for your region times your real usage. No resource price is written into a script or into a finding, and CI fails the build if one appears. The single price this repo records is Cost Explorer's own per-request API charge, which is what the audit costs to run, not the price of anything it reports on. It sits in a reference document with its AWS source.
- **Cost Explorer requests are counted and capped.** The scripts route their requests through one wrapper that counts each page and refuses the one past `AWS_COST_AUDIT_CE_BUDGET`. An `aws ce` call you make yourself is outside that count.
- **It talks to AWS and to nothing else.** It uses the AWS CLI credentials already on your machine, asks you for no keys, and sends your audit to no third party. The scripts need bash and the AWS CLI; `findings-validate.sh` also needs `jq`.

## Learn more

- [Quickstart](docs/quickstart.md): prerequisites, install, and what a full run does step by step.
- [Editor and agent support](docs/editors.md): one line per agent, plus the manual copy path.
- [FAQ](docs/faq.md): what it covers, what it costs to run, what it will not touch.
- [How it compares](docs/comparison.md): against a manual audit and against a cost dashboard.
- [The skill itself](skills/aws-cost-audit/SKILL.md): five Iron Laws, the workflow, and the reference documents it loads on demand.
- [CHANGELOG](CHANGELOG.md) · [CONTRIBUTING](CONTRIBUTING.md) · [MIT license](LICENSE)

---

<sub>Built and maintained by <a href="https://github.com/Aboudjem">Adam Boudjemaa</a>. Commands are written for AWS CLI v2. Spot a stale command or a gap? <a href="https://github.com/Aboudjem/aws-cost-audit-skill/issues">Open an issue</a>.</sub>
