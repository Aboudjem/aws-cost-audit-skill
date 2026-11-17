<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="../assets/hero-dark.svg">
    <source media="(prefers-color-scheme: light)" srcset="../assets/hero-light.svg">
    <img src="../assets/hero-dark.svg" alt="aws-cost-audit：砍掉 AWS 账单里的浪费，每个价格都在运行时向 AWS 查询" width="100%">
  </picture>
</p>

<h1 align="center">aws-cost-audit</h1>

<p align="center">
  <a href="../LICENSE"><img src="https://img.shields.io/github/license/Aboudjem/aws-cost-audit-skill" alt="MIT 许可证"></a>
  <a href="https://github.com/Aboudjem/aws-cost-audit-skill/actions/workflows/validate.yml"><img src="https://img.shields.io/github/actions/workflow/status/Aboudjem/aws-cost-audit-skill/validate.yml?branch=main&label=validate" alt="validate 工作流状态"></a>
  <a href="https://github.com/Aboudjem/10x"><img src="https://img.shields.io/badge/part%20of-10x-FFB341" alt="10x 市场的一部分"></a>
</p>

<p align="center">
  <a href="../README.md">English</a> · <b>简体中文</b> · <a href="ja.md">日本語</a> · <a href="es.md">Español</a> · <a href="fr.md">Français</a>
</p>

<p align="center">
  <strong>砍掉 AWS 账单里的浪费，价格实时查询。</strong>
</p>

<p align="center">
  让你的 agent 审计 AWS 账单，你会得到一个结论、最先要做的三项削减，以及每个价格的来源。
</p>

<p align="center">
  <a href="#示例报告">示例报告</a> · <a href="#为什么用它">为什么用它</a> · <a href="#安装">安装</a> · <a href="#工作原理">工作原理</a> · <a href="#验证">验证</a> · <a href="#常见问题">常见问题</a> · <a href="#限制">限制</a>
</p>

```bash
npx skills add Aboudjem/aws-cost-audit-skill -a claude-code
```

把 `claude-code` 换成你用的 agent：`codex`、`cursor`、`gemini-cli`、`github-copilot` 或 `opencode`。
不加 `-a`，CLI 会让你自己选。Claude Code 插件用户：见[安装](#安装)。

然后对你的 agent 说：`audit my AWS bill`。你的机器需要什么，见[安装](#安装)。

请给它只读凭证：skill 引导你的 agent，脚本强制要求输入 yes。

## 示例报告

每份报告都以这样的内容开头。这只是一个示意：虚构的账户，编造的数字，没有任何真实 AWS 数据。
可以在仓库里用 `bash skills/aws-cost-audit/scripts/findings-summary.sh examples/sample-findings.json` 重新打印它。

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
- Price sources: 9 Price List lookups, 4 Cost Explorer reads
Re-check the Price List prices live: verify-price.sh --recheck examples/sample-findings.json
Every figure above comes from the findings file. Nothing in your account was changed.
```

<!-- sample-report:end -->

完整报告还会继续列出：每项服务你花了多少钱、每条发现及其证据，以及如何撤销。
见 [`examples/sample-report.md`](../examples/sample-report.md) 和可选的 [HTML 仪表板](../examples/sample-dashboard.html)。

它适合没有 FinOps 专人、自己付 AWS 账单的开发者和小团队。
Cost Explorer 只给出总额，不告诉你该关掉什么。这个 skill 会点名该砍什么。
闲置的卷、永久保留的日志、没传完的上传：每条发现都附带证据，并说明能否撤销。
凡是不能同时满足“高置信度”和“可回滚”的项，都要等资源负责人签字确认。
必须开启 Cost Explorer，开启后 AWS 最多需要 24 小时才显示数据。

## 为什么用它

- **知道从哪里开始。** 一个以美元计的结论，然后是最先要做的三项削减。
  证明：上面的示例可用上面的命令重新打印，`make test` 会逐行比较两者。
- **数字可信。** 资源价格在运行时从 AWS Price List 获取，不来自记忆。
  带价格的发现如果没有记录这次查询，就会被拒绝。唯一存储的数字是审计自身的 Cost Explorer 请求费用。
  证明：`make test` 会拒绝没有查询记录的带价格发现；如果脚本里写死了价格，它也会失败。
- **不会意外改动。** 默认是 dry-run：改动脚本只打印它们将做什么。
  加上 `--apply` 后，它们先保存回滚文件，再要求你输入 yes。`--yes` 会跳过这个问题。
  试运行会在本地保存回滚文件，不会改动你账户里的任何东西。
  没有可提问的终端又没有 `--yes` 时，它们会拒绝。`make test` 在 EBS 脚本上检查这个顺序。

## 安装

在 Claude Code 里，从 [10x 市场](https://github.com/Aboudjem/10x)安装：

```bash
claude plugin marketplace add Aboudjem/10x
claude plugin install aws-cost-audit@10x
```

在其他任何 agent 里，用 [skills CLI](https://github.com/vercel-labs/skills)：

```bash
npx skills add Aboudjem/aws-cost-audit-skill
```

你还需要 [AWS CLI](https://aws.amazon.com/cli/)（对该账户有读取权限）和 `jq`。
AWS 托管策略 `ReadOnlyAccess` 加上账单读取权限（`ce:Get*`、`pricing:GetProducts`）就够了。

然后对你的 agent 说：`audit my AWS bill`。它会先检查你的环境，并指出缺少的东西。

签字确认（sign-off）是指，在任何改动之前，资源负责人要先同意。
凡是不能同时满足“高置信度”和“可回滚”的节省项，都需要签字确认。

### 支持的 agent

| Agent                | 安装命令                                                         | 测试日期   |
| :------------------- | :--------------------------------------------------------------- | :--------- |
| Claude Code (plugin) | `claude plugin install aws-cost-audit@10x`                       | 2026-11-17 |
| Claude Code (skill)  | `npx skills add Aboudjem/aws-cost-audit-skill -a claude-code`    | 2026-11-17 |
| Codex                | `npx skills add Aboudjem/aws-cost-audit-skill -a codex`          | 2026-11-17 |
| Cursor               | `npx skills add Aboudjem/aws-cost-audit-skill -a cursor`         | 2026-11-17 |
| Gemini CLI           | `npx skills add Aboudjem/aws-cost-audit-skill -a gemini-cli`     | 2026-11-17 |
| GitHub Copilot       | `npx skills add Aboudjem/aws-cost-audit-skill -a github-copilot` | 2026-11-17 |
| OpenCode             | `npx skills add Aboudjem/aws-cost-audit-skill -a opencode`       | 2026-11-17 |

“已测试”的意思是：安装命令跑通了，`SKILL.md` 也落在了 agent 会读取的位置。
CI 在每次推送时，都会对 Claude Code、Codex 和 Cursor 重复一遍安装。

已有文档但未做端到端测试：Pi、Mistral Vibe、Trae、OpenClaw、Antigravity、Hermes、Cline 和 Kimi。
2026-11-17，固定版本的 skills CLI 接受了它们的 agent 代码。请在克隆的仓库里用 `install.sh` 安装：

```bash
git clone https://github.com/Aboudjem/aws-cost-audit-skill && cd aws-cost-audit-skill
./install.sh pi
```

这会为你的整个用户配置安装。加上 `--project` 则只安装到当前文件夹。
各编辑器的路径见 [docs/editors.md](../docs/editors.md)。

<details>
<summary>改为手动复制 skill</summary>

这个 skill 就是一个装着 Markdown 和 shell 脚本的文件夹。把它复制到你的 agent 读取 skill 的位置：

```bash
git clone https://github.com/Aboudjem/aws-cost-audit-skill
mkdir -p ~/.claude/skills
cp -r aws-cost-audit-skill/skills/aws-cost-audit ~/.claude/skills/aws-cost-audit
```

这个仓库自己没有市场清单文件。插件方式请用上面的 10x 市场。
</details>

## 工作原理

<p align="center">
  <img src="../assets/how-it-works.svg" alt="工作原理：1 实时重新建立基线，2 在所有区域查找浪费，3 有证据支撑的省钱方案" width="100%">
</p>

1. **预检。** `doctor.sh` 检查 AWS CLI、凭证、`jq`、区域和输出文件夹。它不会改动任何东西。
2. **基线。** Cost Explorer 提供按服务、区域和用量类型划分的支出。脚本会统计每次请求，并在达到上限时停止。
3. **查找。** 它会扫描每个已启用的区域，找出闲置、配置过大或被遗忘的资源。检查项见[查找清单](../skills/aws-cost-audit/references/hunt-list.md)。
4. **定价。** 每个单价都来自你所在区域的 AWS Price List，再乘以你的真实用量。
   `verify-price.sh --record` 把这次查询保存进发现，校验器会拒绝没有查询记录的金额。
5. **分类。** 每条发现都是 KEEP、OPTIMIZE 或 SAFE-TO-DELETE，并附有置信度和证据。
6. **报告。** `findings-validate.sh` 先检查 `findings.json`，然后 `findings-summary.sh` 打印结论和三项行动。细节随后列出。

除非你要求，否则不会改动你的账户。有三个脚本可能产生改动，代码会强制执行以下规则：

- 不带 `--apply` 时，它们只打印试运行结果。
- 带 `--apply` 时，它们先保存回滚文件，再请你输入 `yes`。
- `--yes` 会跳过这个提问。如果没有终端可以提问，又没有 `--yes`，它们会在任何改动之前拒绝执行。

skill 还会要求你的 agent 先给你看“未使用”的证据和试运行结果，再等你说 yes。
它也会要求你的 agent 把不可逆的操作（比如购买 Savings Plan）只作为建议。

skill 本身是 [`SKILL.md`](../skills/aws-cost-audit/SKILL.md)：五条规则、各个步骤，以及按需加载的参考文件。

## 验证

下面每个数字，都由旁边的命令重新打印出来。

| 说明                         | 命令                                                         | 今天的输出                                                                    |
| :--------------------------- | :----------------------------------------------------------- | :---------------------------------------------------------------------------- |
| 离线测试套件通过             | `make test`                                                  | `Results: 167 passed, 0 failed`                                                |
| 上面的示例就是工具的真实输出 | `make test`（第 39 个用例逐行对比两者）                      | `[PASS] sample: the README sample report is the script output, line for line` |
| 插件清单有效                 | `claude plugin validate . --strict`                          | `✔ Validation passed`                                                         |
| 脚本里没有写死任何单价       | `make test`（no-hardcoded-price 用例）                       | `[PASS] no per-request price literal in any script`                           |
| 带价格的发现必须有查询记录   | `make test`（price rule 用例） | `[PASS] price rule: a dollar figure with no price_lookups exits 1` |

测试套件用桩替代了 `aws` 命令，所以不需要凭证，也不会调用任何 AWS 接口。
它还会检查 `delete-unattached-ebs.sh` 的安全顺序：确认之前不做任何改动。
CI 还会扫描每个脚本，查找写死的单价。
CI 在每次推送和 pull request 时运行，同时运行 shellcheck 和 skills CLI 安装。

脚本可以调用什么、绝不会往别处发送什么，见 [PRIVACY.md](../PRIVACY.md)。

## 常见问题

**它会自己删除东西吗？**
不会。默认只读。改动类脚本只有在带 `--apply` 时才会运行，先保存回滚文件，再请你输入 `yes`。
`--yes` 会跳过提问，而 skill 要求你的 agent 只有在你于聊天里说了 yes 之后才传它。
skill 要求你的 agent 先给你看“未使用”的证据和试运行结果。不可逆的操作只作为建议。

**需要我的 AWS 密钥吗？**
不需要。它使用你机器上已有的 AWS CLI 凭证。你的数据只会发给 AWS 和你的 agent，不会发到别处。

**跑一次审计要花多少钱？**
Cost Explorer 对每次 API 请求计费。脚本会统计每一页，并在达到 `AWS_COST_AUDIT_CE_BUDGET` 时停止，默认是 50。Price List 查询免费。

**为什么可以相信这些金额？**
每个金额都记录其来源：一次 Price List 查询，或在没有单一单价时的一次 Cost Explorer 读取。
`findings-validate.sh` 会拒绝没有来源的金额。无法核实的金额会写成“unknown”，并且不计入任何合计。

**示例里的数字是真的吗？**
不是。示例报告、仪表板和演示用的都是虚构账户。里面的内容没有一条是从真实 AWS 账单读取的。

**可以比较两次审计吗？**
可以。请求输出 `findings.json`。`findings-validate.sh` 会按固定的格式约定检查它，所以两次运行可以做差异对比。

更多解答见 [docs/faq.md](../docs/faq.md)。

## 限制

- 需要 AWS CLI v2、bash 和 `jq`。在 Windows 上，脚本需要 bash shell，见 [docs/editors.md](../docs/editors.md)。
- 基线需要开启 Cost Explorer。开启后，AWS 最多可能要 24 小时才会显示数据。
- skill 只是引导你的 agent。能力较弱的模型仍可能跳过某一步，所以请检查证据行。
- 价格以美元计，与 AWS 返回的一致。
- 校验器检查的是每条价格记录的格式，而不是 AWS 是否真的返回了它。`verify-price.sh --recheck findings.json` 会重新执行 Price List 查询。
- 阶梯价格（例如 S3 Standard 存储）和 Savings Plans 没有单一单价。这类发现记录的是一次 Cost Explorer 读取；每次读取都要计费，所以 `--recheck` 不会重跑它。
- 只有一个数字是存储的而不是查询的：审计自身的 Cost Explorer 请求费用，见 `references/pricing-verification.md`。
- agent 表里的“已测试”是指安装命令跑通、文件已落地。它不表示每个 agent 都被观察到加载了这个 skill。
- 改动之前的“未使用”证据和试运行，是 skill 要求你的 agent 做的步骤。脚本强制执行的是 `--apply`、回滚文件和 `yes`。

## 了解更多

- [快速开始](../docs/quickstart.md)：从凭证到仪表板，一步一步来。
- [编辑器与 agent 支持](../docs/editors.md)：每个 agent 一行，外加手动复制方法。
- [对比](../docs/comparison.md)：与人工审计和费用仪表板相比。
- [CHANGELOG](../CHANGELOG.md) · [CONTRIBUTING](../CONTRIBUTING.md) · [隐私](../PRIVACY.md) · [MIT 许可证](../LICENSE)

---

<sub>由 <a href="https://github.com/Aboudjem">Adam Boudjemaa</a> 开发和维护。发现过时的命令？<a href="https://github.com/Aboudjem/aws-cost-audit-skill/issues">提交 issue</a>。</sub>

<sub>本文为机器辅助翻译，以英文 README 为准。</sub>
