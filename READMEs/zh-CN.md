<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="../assets/hero-dark.svg">
    <source media="(prefers-color-scheme: light)" srcset="../assets/hero-light.svg">
    <img src="../assets/hero-dark.svg" alt="aws-cost-audit：一份可以核对的省钱方案，每个数字都对照 AWS 实时价格验证" width="100%">
  </picture>
</p>

<h1 align="center">aws-cost-audit</h1>

<p align="center">
  <a href="../LICENSE"><img src="https://img.shields.io/github/license/Aboudjem/aws-cost-audit-skill" alt="MIT license"></a>
  <a href="https://github.com/Aboudjem/aws-cost-audit-skill/actions/workflows/validate.yml"><img src="https://img.shields.io/github/actions/workflow/status/Aboudjem/aws-cost-audit-skill/validate.yml?branch=main&label=validate" alt="validate workflow status"></a>
  <a href="https://github.com/Aboudjem/aws-cost-audit-skill/stargazers"><img src="https://img.shields.io/github/stars/Aboudjem/aws-cost-audit-skill" alt="GitHub stars"></a>
  <a href="https://github.com/Aboudjem/10x"><img src="https://img.shields.io/badge/part%20of-10x-FFB341" alt="Part of the 10x marketplace"></a>
</p>

<p align="center">
  <a href="../README.md">English</a> · <b>简体中文</b> · <a href="ja.md">日本語</a> · <a href="es.md">Español</a> · <a href="fr.md">Français</a>
</p>

<p align="center">
  <strong>让 Claude 审计你的 AWS 账单。每个数字都对照 AWS 实时价格核对过。</strong>
</p>

<p align="center">
  <a href="#它能做什么">它能做什么</a> · <a href="#安装">安装</a> · <a href="#开始使用">开始使用</a> · <a href="#你会得到什么">你会得到什么</a> · <a href="#在你的编辑器里可用">在你的编辑器里可用</a> · <a href="#需要知道的事">需要知道的事</a>
</p>

![aws-cost-audit demo](../assets/demo.gif)

<p align="center"><sub>录屏中的每个数字都是<b>示意性的</b>：合成数据，不涉及任何真实账户。</sub></p>

```bash
claude plugin marketplace add Aboudjem/10x
claude plugin install aws-cost-audit@10x
```

## 它能做什么

这是一个 [Claude Code](https://www.claude.com/product/claude-code) 技能：一个 Markdown 指令文件、六份按需加载的参考文档，以及十个 bash 辅助脚本。当你问起 AWS 支出时，Claude 会把它调起来。

你说一句"审计我的 AWS 账单"。它会通过你本来就有的 AWS CLI 读取账户，算出每项资源花了多少钱、为什么花，然后给你一份方案。它默认只读。它从不凭记忆报价，也绝不会自作主张删除任何东西。

- **一份支出明细。** 按服务和按区域列出你当前的花费，数据实时来自 Cost Explorer。
- **一份逐资源视图。** 每样东西花了多少钱、用大白话说它是干什么的、谁创建的、上次使用是什么时候。如果某个事实无法核实，它会直言无法核实，而不是猜。
- **一份分成两半的省钱方案。**"现在就能安全省下的"（可回滚、高置信度）与"理论最大可省"分开列出，后者需要你签字同意。

方法遵循 [AWS Well-Architected 成本优化支柱](https://docs.aws.amazon.com/wellarchitected/latest/cost-optimization-pillar/welcome.html)和 [FinOps Foundation](https://www.finops.org/framework/) 框架，不是这个技能自己编出来的。

## 安装

在 Claude Code 里，从 [10x 市场](https://github.com/Aboudjem/10x)安装：

```bash
claude plugin marketplace add Aboudjem/10x
claude plugin install aws-cost-audit@10x
```

在其他任何智能体里，通过 [Vercel skills CLI](https://github.com/vercel-labs/skills) 安装：

```bash
npx skills add Aboudjem/aws-cost-audit-skill
```

你还需要配置好 [AWS CLI](https://aws.amazon.com/cli/)，并对想审计的账户具备读权限。AWS 托管的 `ReadOnlyAccess` 策略加上账单读取权限，就足够跑完审计本身。

<details>
<summary>改为手动复制技能目录</summary>

完全绕开插件系统。这个技能就是一个装着 Markdown 和 shell 脚本的目录，把它复制到你的智能体会读取的目录里就够了：

```bash
git clone https://github.com/Aboudjem/aws-cost-audit-skill
mkdir -p ~/.claude/skills
cp -r aws-cost-audit-skill/skills/aws-cost-audit ~/.claude/skills/aws-cost-audit
```

本仓库自身不带 marketplace 清单，因此 `claude plugin marketplace add Aboudjem/aws-cost-audit-skill` 无法解析。上面的 10x 市场才是插件安装路径。Windows 以及各编辑器的具体路径见 [docs/editors.md](../docs/editors.md)。
</details>

## 开始使用

**1. 检查运行环境。** `doctor.sh` 会在审计开始前指出缺了什么。它不会发出任何会改动东西的 AWS 调用，没有 apply 参数，并且会删掉自己写下的探测文件：

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

**2. 让 Claude 开工。** 说 `audit my AWS bill`，或者 `find my unused AWS resources`。技能就是按这种说法触发的。如果你有多个账户，告诉它用哪个 profile、看哪些区域。

**3. 读方案。** 你会得到一份报告，以及一个可选的 HTML 仪表板。除非你要求，否则账户里什么都不会变，即便要求了，也要先通过演练并经你确认。

<p align="center">
  <img src="../assets/how-it-works.svg" alt="How it works: 1 re-baseline live, 2 hunt waste across every region, 3 evidence-backed savings plan" width="100%">
</p>

从凭证配置到仪表板的完整流程，见[快速上手](../docs/quickstart.md)。

## 你会得到什么

- **一份报告。** 每条发现的形式是 `current $/mo -> after $/mo -> $ saved`，附带证据、置信度，以及如何撤销。见 [`examples/sample-report.md`](../examples/sample-report.md)。
- **一个可选的仪表板。** 一个 HTML 文件，非技术同事也能打开来看。它的字体和图表库来自 CDN，所以要在联网的机器上才显示正常。见 [`examples/sample-dashboard.html`](../examples/sample-dashboard.html)。
- **可按需生成机器可读的 `findings.json`。** 由 `findings-validate.sh` 按固定的结构契约校验，正因如此两次审计才能直接比对，而不用重读一遍。
- **每一笔金额都有实时价格。** 单价、算式、来源，按你所在区域查得。首选 Price List Query API；查不到的数字会一直标为未知。
- **护栏。** 它会报告你是否配置了预算和成本异常告警，并帮你把它们建起来。

## 在你的编辑器里可用

| 智能体 | 一行安装命令 |
|:--|:--|
| Claude Code | `claude plugin install aws-cost-audit@10x` |
| 其余 70 多种智能体 | `npx skills add Aboudjem/aws-cost-audit-skill` |
| Codex、Gemini CLI、OpenCode、Pi | `./install.sh codex`（或 `gemini`、`opencode`、`pi`） |
| 装了 Copilot 的 VS Code | `./install.sh copilot` |
| 其他所有情况 | 见 [docs/editors.md](../docs/editors.md) |

可在 Claude Code、Cursor、Codex、Copilot、Gemini CLI 中使用，并通过 `npx skills add` 支持另外 70 多种智能体。`install.sh` 是本仓库一直支持的十三个编辑器 id 的包装脚本，现在它会转交给同一个 CLI 来完成安装：

```bash
curl -fsSL https://raw.githubusercontent.com/Aboudjem/aws-cost-audit-skill/main/install.sh | bash -s codex
```

这个插件刻意不提供 MCP 服务器。它直接调用你本来就有的 AWS CLI，因此没有额外进程要跑，也没有东西需要写进 `.mcp.json`。

## 需要知道的事

> [!IMPORTANT]
> 它默认只读。它不会自作主张删除、停止或修改任何东西。任何动作都有闸门：资源必须被证明未被使用，改动必须可回滚，必须通过演练，而且必须由你确认。不可逆的动作永远只停留在建议阶段。

- **绝不凭记忆报价。** 每一笔金额都来自你所在区域的实时 AWS 价格乘以你的真实用量。任何脚本、任何一条发现里都不会写死资源价格，一旦出现，CI 就会让构建失败。本仓库记录的唯一一个价格是 Cost Explorer 自身的每次请求 API 费用，那是跑一次审计的成本，而不是它所报告对象的价格。它连同 AWS 来源一起存放在一份参考文档里。
- **Cost Explorer 请求会被计数并设上限。** 脚本的请求统一走一个包装函数，它对每一页计数，并拒绝超出 `AWS_COST_AUDIT_CE_BUDGET` 的那一次请求。你自己手动发起的 `aws ce` 调用不在这个计数之内。
- **它只和 AWS 通信，不和别的任何一方通信。** 它在本地使用你机器上已有的 AWS CLI 凭证，不向你索要密钥，也不会把你的审计结果发给任何第三方。脚本只需要 bash 和 AWS CLI；`findings-validate.sh` 还需要 `jq`。

## 延伸阅读

- [快速上手](../docs/quickstart.md)：前置条件、安装，以及一次完整运行会逐步做些什么。
- [编辑器与智能体支持](../docs/editors.md)：每个智能体一行命令，外加手动复制的路径。
- [常见问题](../docs/faq.md)：它覆盖什么、跑一次要花多少钱、它不会碰什么。
- [横向对比](../docs/comparison.md)：与人工审计、与成本仪表板的对比。
- [技能本身](../skills/aws-cost-audit/SKILL.md)：五条铁律、工作流，以及它按需加载的参考文档。
- [CHANGELOG](../CHANGELOG.md) · [CONTRIBUTING](../CONTRIBUTING.md) · [MIT 许可证](../LICENSE)

---

<sub>由 <a href="https://github.com/Aboudjem">Adam Boudjemaa</a> 开发与维护。命令是针对 AWS CLI v2 编写的。发现命令过时或有缺漏？<a href="https://github.com/Aboudjem/aws-cost-audit-skill/issues">提一个 issue</a>。</sub>

<sub>本文档由机器辅助翻译，如与英文版有出入，以英文版为准。</sub>
