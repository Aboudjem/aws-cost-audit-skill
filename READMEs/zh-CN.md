<p align="center">
  <img src="https://raw.githubusercontent.com/Aboudjem/aws-cost-audit-skill/main/assets/hero.svg" alt="AWS Cost Audit: an executable, evidence-first AWS cost auditor for Claude Code" width="100%">
</p>

<h1 align="center">AWS Cost Audit Skill</h1>

<p align="center">
  <strong>让 Claude 审计你的 AWS 账单。获得一份清晰的省钱方案,其中每个数字都对照实时 AWS 定价核验过,并且未经你的许可不会删除任何东西。</strong>
</p>

<p align="center">
  <a href="../LICENSE"><img src="https://img.shields.io/badge/license-MIT-green.svg" alt="MIT license"></a>
  <img src="https://img.shields.io/badge/Claude%20Code-skill-d97757" alt="Claude Code skill">
  <img src="https://img.shields.io/badge/AWS-cost%20optimization-ff9900" alt="AWS cost optimization">
  <a href="../CONTRIBUTING.md"><img src="https://img.shields.io/badge/PRs-welcome-brightgreen.svg" alt="PRs welcome"></a>
  <a href="https://github.com/Aboudjem/10x"><img src="https://img.shields.io/badge/part%20of-10x%20marketplace-f59e0b" alt="Part of the 10x marketplace"></a>
</p>

<p align="center">
  隶属于 <a href="https://github.com/Aboudjem/10x"><b>10x</b> 市场</a>,一套用心挑选、注重质量的 Claude Code 工具集。
</p>

<p align="center">
  <a href="../README.md">English</a> · <b>简体中文</b> · <a href="ja.md">日本語</a> · <a href="es.md">Español</a> · <a href="fr.md">Français</a>
</p>

---

![aws-cost-audit demo](https://raw.githubusercontent.com/Aboudjem/aws-cost-audit-skill/main/assets/demo.gif)

<p align="center"><sub>让 Claude 审计你的账单,获得一份以证据为先的省钱方案。所示的所有数字均为<b>示意</b>(合成数据,无真实账户)。</sub></p>

---

## 这是什么?

这是一个 [Claude Code](https://www.claude.com/product/claude-code) 技能,替你审计 AWS 账户。

你对 Claude 说类似 *"audit my AWS bill"* 的话。技能读取你的实时账户,算出每一项花了多少钱、为什么,找出浪费,然后递给你一份通俗易懂的报告:你今天在付什么、哪些可以安全削减、以及它对每一项有多大把握。默认只读。它从不猜测价格,也不会自作主张删除任何东西。

把它想成一位会展示推算过程的严谨 FinOps 工程师。

**什么是 AWS 成本审计?** 这是对一个 AWS 账户的结构化审查,查清你在为什么付费、哪些资源被浪费或配置过大、以及哪些可以安全移除。本技能替你执行该审计,并遵循 [AWS Well-Architected Framework 成本优化支柱](https://docs.aws.amazon.com/wellarchitected/latest/cost-optimization-pillar/welcome.html) 和 [FinOps Foundation](https://www.finops.org/framework/) 框架,因此其方法并非凭空编造。

## 安装

任选其一。三种方式安装的是同一个技能。

**从 [10x 市场](https://github.com/Aboudjem/10x)**(推荐,它在那里与其他 Claude Code 工具一同被精选):

```text
/plugin marketplace add Aboudjem/10x
/plugin install aws-cost-audit@10x
```

**直接从本仓库:**

```text
/plugin marketplace add Aboudjem/aws-cost-audit-skill
/plugin install aws-cost-audit@aws-cost-audit-skill
```

**作为即插即用的技能**(无需插件系统):

```bash
git clone https://github.com/Aboudjem/aws-cost-audit-skill
cp -r aws-cost-audit-skill/skills/aws-cost-audit ~/.claude/skills/aws-cost-audit
```

你还需要配置好对要审计账户具有只读访问权限的 [AWS CLI](https://aws.amazon.com/cli/)。对审计本身而言,`ReadOnlyAccess` 就足够了。

### 其他 AI CLI(一行命令)

这是一个仅含技能的插件(无 MCP 服务器)。安装脚本会把 `aws-cost-audit` 技能软链接到另一个 CLI 的技能目录:

```bash
curl -fsSL https://raw.githubusercontent.com/Aboudjem/aws-cost-audit-skill/main/install.sh | bash -s <platform>
```

| 平台 | 技能目录 | 链接方式 |
|:--|:--|:--|
| gemini, codex, opencode, pi | `~/.agents/skills` | 按技能 |
| vscode, copilot | `~/.copilot/skills` | 按技能 |
| trae | `~/.trae/skills` | 按技能 |
| vibe | `~/.vibe/skills` | 按技能 |
| openclaw | `~/.openclaw/skills` | 文件夹 |
| antigravity | `~/.gemini/antigravity/skills` | 文件夹 |
| hermes, cline, kimi | `~/.<cli>/skills` | 文件夹 |

传入 `all` 可链接到上述所有平台。用 `--update` 重新链接到最新版,用 `--uninstall` 移除链接。

<details>
<summary>Codex, Gemini, OpenCode, pi</summary>

```bash
curl -fsSL https://raw.githubusercontent.com/Aboudjem/aws-cost-audit-skill/main/install.sh | bash -s codex
```
</details>

<details>
<summary>VS Code (Copilot)</summary>

```bash
curl -fsSL https://raw.githubusercontent.com/Aboudjem/aws-cost-audit-skill/main/install.sh | bash -s copilot
```
</details>

<details>
<summary>Windows (PowerShell)</summary>

```powershell
git clone https://github.com/Aboudjem/aws-cost-audit-skill
./aws-cost-audit-skill/install.ps1 copilot
```
</details>

<details>
<summary>其他编辑器(手动)</summary>

该技能就是纯 Markdown 加 shell 脚本。把 `skills/aws-cost-audit/SKILL.md` 和 `references/` 文件夹复制到你的编辑器会读取的上下文目录,然后直接运行 `skills/aws-cost-audit/scripts/` 中的辅助脚本。它们仅依赖 AWS CLI。
</details>

## 三步上手

1. **安装它**(见上文)。
2. **请 Claude** *"audit my AWS bill"* 或 *"find my unused AWS resources"*。技能会自动启用。
3. **阅读方案。** 你会得到一份报告,以及一个可选的 HTML 仪表板,为每一项节省显示成本、原因和置信度。

就是这样。除非你提出要求,否则账户里什么都不会被改动,即便提出要求,也只会在安全检查并经你确认之后进行。

<p align="center">
  <img src="https://raw.githubusercontent.com/Aboudjem/aws-cost-audit-skill/main/assets/how-it-works.svg" alt="How it works: 1 re-baseline live, 2 hunt waste across every region, 3 evidence-backed savings plan" width="100%">
</p>

## 你会得到什么

<p align="center">
  <img src="https://raw.githubusercontent.com/Aboudjem/aws-cost-audit-skill/main/assets/dashboard-preview.png" alt="Sample AWS cost audit dashboard: monthly run-rate, save-now-safely vs maximum-theoretical-save, with synthetic data" width="100%">
  <br><sub>可选的仪表板(示例,合成数据)。打开 <a href="../examples/sample-dashboard.html"><code>examples/sample-dashboard.html</code></a> 即可实时查看。</sub>
</p>

- **支出明细。** 你今天的付费,按服务和按区域细分,实时取自 Cost Explorer。
- **逐资源视图。** 对每个资源:它的成本、用通俗的话说它的用途、谁创建的、何时创建、上次使用是何时。如果某个事实无法核验,它会如实说明,而不是猜测。
- **分两部分的省钱方案。** "现在安全省"(高置信、可逆、低风险)与"理论最大省"(需要你签字的更大削减)分开列出。
- **可选的仪表板。** 一个自包含的 HTML 页面,非技术人员也能读懂。参见 [`examples/sample-dashboard.html`](../examples/sample-dashboard.html) 和一份[示例报告](../examples/sample-report.md)。
- **护栏。** 它会检查你是否有预算和成本异常告警,并帮你设置。

## 一次运行是什么样的

上面的录屏(`assets/demo.gif`)是示意性的:它使用合成数据而非真实账户,因为 AWS 调用需要实时凭证(参见 [CONTRIBUTING.md](../CONTRIBUTING.md) 中关于推迟事项的说明)。以下是逐步发生的过程,与[示例报告](../examples/sample-report.md)和[示例仪表板](../examples/sample-dashboard.html)一致(两者都使用合成数据,并有清晰标注):

1. **身份检查。** `aws sts get-caller-identity` 在其他任何操作运行之前确认账户和区域。
2. **支出基线。** Cost Explorer(`aws ce get-cost-and-usage`)拉取过去 30 天和 90 天的支出,按服务和区域细分。你会看到一张表:服务 → $/月 → 占总额的比例。
3. **资源清点。** 技能在每个已启用的区域展开,列出 EC2 实例、EBS 卷、RDS 实例、NAT 网关、负载均衡器、S3 存储桶、Lambda 函数、CloudWatch 日志组、快照、AMI、Elastic IP 等等。不做任何修改。
4. **浪费检测。** 每个资源都对照狩猎清单(`skills/aws-cost-audit/references/hunt-list.md`)检查:空闲 CPU、未挂载的卷、旧快照、gp2 卷、过度保留的日志、缺失的 Savings Plan 覆盖等等。
5. **实时价格核验。** 对每一项候选节省,技能从 AWS Price List Query API 获取该区域的实时单价,不使用任何记忆中的费率。它为每个金额数字显示 `unit price → math → source`。
6. **以证据为依据的报告。** 发现项写成 `current $/mo → after $/mo → $ saved · confidence · evidence · reversibility`,分为"现在安全省"(高置信、可逆、已测试)和"理论最大省"。确切格式参见 [`examples/sample-report.md`](../examples/sample-report.md)。
7. **可选的仪表板。** 从发现项生成一个 HTML 文件,在任意浏览器中打开。参见 [`examples/sample-dashboard.html`](../examples/sample-dashboard.html)。

在中等规模的 AWS 账户上,一次真实运行通常在首次调用 Cost Explorer 后的几分钟内就会浮现发现项。只读阶段会在提出任何整改建议之前完成。

## 为什么你可以信任这些数字

大多数"削减你的 AWS 账单"的建议都很笼统,或者只是一个凭记忆报价的工具。本技能围绕五条它绝不会破坏的规则构建:

1. **没有编造的价格。** 每个金额都来自*你所在*区域的 AWS 实时价格,乘以你的*实际*用量。它展示单价、计算和出处。任何地方都不硬编码价格。
2. **为每个金额归因,否则写"未知"。** 它从不编造所有者、日期或"上次使用"。
3. **没有证据绝不做破坏性操作。** 只有在资源被证明未使用、操作可逆、通过演练、且结果确定时,变更才会执行。否则它仍只是一条建议。
4. **一个样本永远不等于整个机群。** 一个独立的"怀疑者"环节会在发布前从源头重新推导头条数字。
5. **每个发现项都展示其证据。** 当前成本、变更后成本、节省金额、置信度、证据,以及如何撤销。

这些规则之所以存在,是因为我们见过*没有*该技能的智能体破坏它们。记录下来的基线在 [`docs/research/RED-baseline-findings.md`](../docs/research/RED-baseline-findings.md):被问及同一个节省数字时,两个模型自信满满地凭记忆返回了两个不同的错误数字。技能修复了这一点。

## 横向对比

| | 本技能 | 人工审计 | 成本 SaaS 仪表板 |
|---|---|---|---|
| 对你的实时账户运行 | 是 | 是 | 是 |
| 现在就能免费运行 | 是 | 是 | 通常收费 / 按席位 |
| 每个价格实时核验(无记忆费率) | 是 | 取决于人 | 展示其自有数字 |
| 逐资源归因成本、所有者和上次使用 | 是 | 慢,靠手工 | 部分 |
| 能安全地对发现项采取行动(带门控 + 可逆) | 是 | 手动 | 只读 |
| 生成可共享的报告 + 仪表板 | 是 | 手动 | 是 |
| 把你的数据发给第三方 | 否 | 否 | 经常 |
| 锁定 | 无(MIT,你的账户) | 无 | 厂商 |

## FAQ

**如何用 Claude 审计我的 AWS 账单?**
安装本技能,然后让 Claude Code "audit my AWS bill"。它会用 AWS CLI 读取你的账户,并生成一份以证据为依据的成本报告和省钱方案。

**安全吗?会删除什么吗?**
默认只读。它不会自作主张删除、停止或更改任何东西。任何操作都带门控:资源必须被证明未使用、变更必须可逆、必须通过演练、并且你必须确认。不可逆的操作始终只作为建议保留。

**它需要我的 AWS 密钥吗?**
不需要。它使用你自己机器上现有的 AWS CLI 凭证。没有任何东西被上传到任何地方。审计用 `ReadOnlyAccess` 就够了。

**它能在我的账户上工作吗?**
能。它是通用的。它读取你的 CLI 所指向的任何账户,跨所有区域,并且发布时不内置任何账户 ID、ARN 或价格。

**它会硬编码 AWS 价格吗?**
不会,这是有意为之。价格会变动且因区域而异,所以它总是为你的区域获取实时价格,并与你的真实用量结合。

**它涵盖什么?**
空闲和未挂载的资源、gp2→gp3、旧快照和 AMI、NAT 和数据传输成本、空闲的负载均衡器、规格优化、Savings Plans 和预留实例覆盖、S3 生命周期、CloudWatch 日志保留、跨区域遗留物,以及缺失的预算 / 告警。完整清单见[狩猎清单](../skills/aws-cost-audit/references/hunt-list.md)。

**不用插件系统能用吗?**
能。把 `skills/aws-cost-audit/` 复制到 `~/.claude/skills/aws-cost-audit/`,它的工作方式完全一样。

## 内部如何工作

技能位于 [`skills/aws-cost-audit/SKILL.md`](../skills/aws-cost-audit/SKILL.md)。较重的细节只在需要时从 `references/` 加载:

- [`hunt-list.md`](../skills/aws-cost-audit/references/hunt-list.md):每一项高 ROI 检查,以及检测它的只读命令。
- [`pricing-verification.md`](../skills/aws-cost-audit/references/pricing-verification.md):它如何拉取一个区域正确的实时价格并复核。
- [`safety-and-gating.md`](../skills/aws-cost-audit/references/safety-and-gating.md):executor → verifier → rollback 门控,以及绝不能自行运行的内容。
- [`output-and-reporting.md`](../skills/aws-cost-audit/references/output-and-reporting.md):报告格式和逐发现项的契约。

[`scripts/`](../skills/aws-cost-audit/scripts) 中的辅助脚本默认是演练模式。首次的引导式运行请参见[快速开始](../docs/quickstart.md)。

## 编辑器支持

本技能为 **Claude Code** 设计。它通过把 `SKILL.md` 加载进 Claude Code 上下文并调用 AWS CLI 来工作,因此需要 Claude Code 作为运行时。

其他 AI 编辑器(Cursor、带 Copilot 的 VS Code、Windsurf、Codex、Gemini CLI)并不原生使用 Claude Code 的插件或技能格式。如果你在使用其中之一,最实用的路径是:

1. 安装 AWS CLI 并照常配置你的凭证。
2. 把 `skills/aws-cost-audit/SKILL.md` 和 `references/` 文件夹复制到你的项目(或编辑器会读取的个人上下文目录)。
3. 把 SKILL.md 的内容作为系统提示或自定义指令提供给你的编辑器。
4. 直接运行 `skills/aws-cost-audit/scripts/` 中的辅助脚本。它们是纯 shell 脚本,仅依赖 AWS CLI,不依赖 Claude Code。

技能的逻辑(Iron Laws、工作流、安全门控)完全可移植。只有*安装机制*(插件系统、`/skill` 自动发现)是 Claude Code 特有的。

## 贡献

欢迎提交 issue 和 PR。唯一的硬性规则:本技能采用测试先行构建,所以一个增加行为的变更需要附上它所修复的失败基线。参见 [CONTRIBUTING.md](../CONTRIBUTING.md) 和[行为准则](../CODE_OF_CONDUCT.md)。

## Star History

<a href="https://star-history.com/#Aboudjem/aws-cost-audit-skill&Date">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=Aboudjem/aws-cost-audit-skill&type=Date&theme=dark">
    <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=Aboudjem/aws-cost-audit-skill&type=Date">
    <img alt="Star history of Aboudjem/aws-cost-audit-skill" src="https://api.star-history.com/svg?repos=Aboudjem/aws-cost-audit-skill&type=Date">
  </picture>
</a>

## 许可证

[MIT](../LICENSE)。用它、fork 它、发布它。

---

<sub>由 <a href="https://github.com/Aboudjem">Adam Boudjemaa</a> 构建并维护。命令已于 2026 年对照 AWS CLI v2 和 AWS 文档核验。发现了过时的命令或缺口? <a href="https://github.com/Aboudjem/aws-cost-audit-skill/issues">提交一个 issue</a>。</sub>

---

<sub>本译文由机器辅助翻译。欢迎母语者校正:<a href="https://github.com/Aboudjem/aws-cost-audit-skill/issues">提交 issue</a> 或 PR。</sub>
