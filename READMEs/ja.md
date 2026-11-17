<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="../assets/hero-dark.svg">
    <source media="(prefers-color-scheme: light)" srcset="../assets/hero-light.svg">
    <img src="../assets/hero-dark.svg" alt="aws-cost-audit：払うのをやめるものが見える。サンプルの請求バーから 3 つの削減を取り出した図：月 84 ドル、72 ドル、58 ドル、それぞれ価格の出どころつき。SAMPLE: fictional account のスタンプ。" width="100%">
  </picture>
</p>

<h1 align="center">aws-cost-audit</h1>

<p align="center">
  <a href="../LICENSE"><img src="https://img.shields.io/github/license/Aboudjem/aws-cost-audit-skill" alt="MIT ライセンス"></a>
  <a href="https://github.com/Aboudjem/aws-cost-audit-skill/actions/workflows/validate.yml"><img src="https://img.shields.io/github/actions/workflow/status/Aboudjem/aws-cost-audit-skill/validate.yml?branch=main&label=validate" alt="validate ワークフローの状態"></a>
  <a href="https://github.com/Aboudjem/10x"><img src="https://img.shields.io/badge/part%20of-10x-FFB341" alt="10x マーケットプレイスの一部"></a>
</p>

<p align="center">
  <a href="../README.md">English</a> · <a href="zh-CN.md">简体中文</a> · <b>日本語</b> · <a href="es.md">Español</a> · <a href="fr.md">Français</a>
</p>

<p align="center"><strong>AWS の請求で、払うのをやめるものを見つける。</strong></p>

<p align="center">エージェントが AWS アカウントを読み、削るものを順位づけします。</p>

| AWS の請求を下げる | 価格は AWS で確認 | 変更の前にロールバック |
|:--|:--|:--|
| どのレポートもドルの結論と、最初にやる 3 つの削減で始まります。 | 各価格は AWS での照会を記録します。記録のない金額は拒否されることを `make test` が示します。 | スクリプトは既定でドライラン。`--apply` は先にロールバックファイルを保存し、確認します（`--yes` なら確認なし）。 |

**対応：** スキルを読むすべてのエージェント。インストールを確認済み：Claude Code、Codex、Cursor、Gemini CLI、GitHub Copilot、OpenCode。
Markdown と bash なので、特定のモデルに縛られません。

```bash
npx skills add Aboudjem/aws-cost-audit-skill -g
# メニューでエージェントを選び、読み取り専用の AWS 認証情報を渡して頼む：audit my AWS bill
```

これですべてのプロジェクトにインストールされます。1 つのエージェントだけ、または Claude Code プラグインは [インストール](#インストール) を見てください。

AI エージェント用のスキルで、AWS アカウントを読むスクリプトが付いています。
請求が増えて理由がわからないときに使います。

削減の順位つきリストが手に入ります。各項目に証拠と価格の出どころがあります。

## サンプルレポート

どのレポートも、この形で始まります。これは例です：架空のアカウント、作り物の数字で、実際の AWS データは含みません。
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

`bash skills/aws-cost-audit/scripts/findings-summary.sh examples/sample-findings.json` で再出力できます。

AWS CLI、`jq`、Cost Explorer が必要です。Cost Explorer の新しいデータは表示まで 24 時間かかることがあります。

## インストール

**おすすめ：Vercel の skills CLI。** `npx skills` は、エージェントスキル用の Vercel のオープンなインストーラーです。

```bash
npx skills add Aboudjem/aws-cost-audit-skill -g
```

70 を超えるエージェントで動きます：メニューで自分のものを選びます（[対応エージェント](https://github.com/vercel-labs/skills#supported-agents)）。
`-g` はすべてのプロジェクトにインストールします。このプロジェクトだけなら `-g` を外します。
端末ではエージェントのメニューを表示します。スクリプトではすべてのエージェントのフォルダに入れるので、`-a <agent>` を付けてください。

<a href="https://skills.sh/aboudjem/aws-cost-audit-skill"><img src="https://img.shields.io/badge/skills.sh-000000?style=flat-square&logo=vercel&logoColor=white" height="24" alt="skills.sh page for aws-cost-audit-skill"></a> Vercel のスキル一覧にあるページ： [skills.sh/aboudjem/aws-cost-audit-skill](https://skills.sh/aboudjem/aws-cost-audit-skill).

**または、1 つのエージェントに直接インストール。**

<p><a href="#claude-code"><img src="https://img.shields.io/badge/Claude_Code-D97757?style=flat-square&logo=claude&logoColor=white" height="24" alt="Claude Code"></a> <a href="#codex"><img src="https://img.shields.io/badge/Codex-000000?style=flat-square&logo=data%3Aimage%2Fsvg%2Bxml%3Bbase64%2CPHN2ZyBmaWxsPSJ3aGl0ZSIgcm9sZT0iaW1nIiB2aWV3Qm94PSIwIDAgMjQgMjQiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI%2BPHRpdGxlPk9wZW5BSTwvdGl0bGU%2BPHBhdGggZD0iTTIyLjI4MTkgOS44MjExYTUuOTg0NyA1Ljk4NDcgMCAwIDAtLjUxNTctNC45MTA4IDYuMDQ2MiA2LjA0NjIgMCAwIDAtNi41MDk4LTIuOUE2LjA2NTEgNi4wNjUxIDAgMCAwIDQuOTgwNyA0LjE4MThhNS45ODQ3IDUuOTg0NyAwIDAgMC0zLjk5NzcgMi45IDYuMDQ2MiA2LjA0NjIgMCAwIDAgLjc0MjcgNy4wOTY2IDUuOTggNS45OCAwIDAgMCAuNTExIDQuOTEwNyA2LjA1MSA2LjA1MSAwIDAgMCA2LjUxNDYgMi45MDAxQTUuOTg0NyA1Ljk4NDcgMCAwIDAgMTMuMjU5OSAyNGE2LjA1NTcgNi4wNTU3IDAgMCAwIDUuNzcxOC00LjIwNTggNS45ODk0IDUuOTg5NCAwIDAgMCAzLjk5NzctMi45MDAxIDYuMDU1NyA2LjA1NTcgMCAwIDAtLjc0NzUtNy4wNzI5em0tOS4wMjIgMTIuNjA4MWE0LjQ3NTUgNC40NzU1IDAgMCAxLTIuODc2NC0xLjA0MDhsLjE0MTktLjA4MDQgNC43NzgzLTIuNzU4MmEuNzk0OC43OTQ4IDAgMCAwIC4zOTI3LS42ODEzdi02LjczNjlsMi4wMiAxLjE2ODZhLjA3MS4wNzEgMCAwIDEgLjAzOC4wNTJ2NS41ODI2YTQuNTA0IDQuNTA0IDAgMCAxLTQuNDk0NSA0LjQ5NDR6bS05LjY2MDctNC4xMjU0YTQuNDcwOCA0LjQ3MDggMCAwIDEtLjUzNDYtMy4wMTM3bC4xNDIuMDg1MiA0Ljc4MyAyLjc1ODJhLjc3MTIuNzcxMiAwIDAgMCAuNzgwNiAwbDUuODQyOC0zLjM2ODV2Mi4zMzI0YS4wODA0LjA4MDQgMCAwIDEtLjAzMzIuMDYxNUw5Ljc0IDE5Ljk1MDJhNC40OTkyIDQuNDk5MiAwIDAgMS02LjE0MDgtMS42NDY0ek0yLjM0MDggNy44OTU2YTQuNDg1IDQuNDg1IDAgMCAxIDIuMzY1NS0xLjk3MjhWMTEuNmEuNzY2NC43NjY0IDAgMCAwIC4zODc5LjY3NjVsNS44MTQ0IDMuMzU0My0yLjAyMDEgMS4xNjg1YS4wNzU3LjA3NTcgMCAwIDEtLjA3MSAwbC00LjgzMDMtMi43ODY1QTQuNTA0IDQuNTA0IDAgMCAxIDIuMzQwOCA3Ljg3MnptMTYuNTk2MyAzLjg1NThMMTMuMTAzOCA4LjM2NCAxNS4xMTkyIDcuMmEuMDc1Ny4wNzU3IDAgMCAxIC4wNzEgMGw0LjgzMDMgMi43OTEzYTQuNDk0NCA0LjQ5NDQgMCAwIDEtLjY3NjUgOC4xMDQydi01LjY3NzJhLjc5Ljc5IDAgMCAwLS40MDctLjY2N3ptMi4wMTA3LTMuMDIzMWwtLjE0Mi0uMDg1Mi00Ljc3MzUtMi43ODE4YS43NzU5Ljc3NTkgMCAwIDAtLjc4NTQgMEw5LjQwOSA5LjIyOTdWNi44OTc0YS4wNjYyLjA2NjIgMCAwIDEgLjAyODQtLjA2MTVsNC44MzAzLTIuNzg2NmE0LjQ5OTIgNC40OTkyIDAgMCAxIDYuNjgwMiA0LjY2ek04LjMwNjUgMTIuODYzbC0yLjAyLTEuMTYzOGEuMDgwNC4wODA0IDAgMCAxLS4wMzgtLjA1NjdWNi4wNzQyYTQuNDk5MiA0LjQ5OTIgMCAwIDEgNy4zNzU3LTMuNDUzN2wtLjE0Mi4wODA1TDguNzA0IDUuNDU5YS43OTQ4Ljc5NDggMCAwIDAtLjM5MjcuNjgxM3ptMS4wOTc2LTIuMzY1NGwyLjYwMi0xLjQ5OTggMi42MDY5IDEuNDk5OHYyLjk5OTRsLTIuNTk3NCAxLjQ5OTctMi42MDY3LTEuNDk5N1oiLz48L3N2Zz4%3D" height="24" alt="Codex"></a> <a href="#cursor"><img src="https://img.shields.io/badge/Cursor-000000?style=flat-square&logo=cursor&logoColor=white" height="24" alt="Cursor"></a> <a href="#gemini-cli"><img src="https://img.shields.io/badge/Gemini-8E75B2?style=flat-square&logo=googlegemini&logoColor=white" height="24" alt="Gemini CLI"></a> <a href="#github-copilot"><img src="https://img.shields.io/badge/Copilot-24292F?style=flat-square&logo=githubcopilot&logoColor=white" height="24" alt="GitHub Copilot"></a> <a href="#opencode"><img src="https://img.shields.io/badge/OpenCode-333333?style=flat-square&logo=opencode&logoColor=white" height="24" alt="OpenCode"></a></p>

### Claude Code

インストールを確認済み。

```bash
npx skills add Aboudjem/aws-cost-audit-skill -g -a claude-code
```

### Codex

インストールを確認済み。

```bash
npx skills add Aboudjem/aws-cost-audit-skill -g -a codex
```

### Cursor

インストールを確認済み。

```bash
npx skills add Aboudjem/aws-cost-audit-skill -g -a cursor
```

### Gemini CLI

インストールを確認済み。

```bash
npx skills add Aboudjem/aws-cost-audit-skill -g -a gemini-cli
```

### GitHub Copilot

インストールを確認済み。

```bash
npx skills add Aboudjem/aws-cost-audit-skill -g -a github-copilot
```

### OpenCode

インストールを確認済み。

```bash
npx skills add Aboudjem/aws-cost-audit-skill -g -a opencode
```

ほかのエージェント：`-a` の後にそのコードを書きます。

### Claude Code プラグイン

同じスキルです。何も追加しません：コマンド、フック、MCP サーバーはありません。[10x マーケットプレイス](https://github.com/Aboudjem/10x) でプラグインを管理するなら使ってください。

```bash
claude plugin marketplace add Aboudjem/10x
claude plugin install aws-cost-audit@10x
```

ユーザー単位で、すべてのプロジェクトに入ります。

### 必要なもの

1. アカウントへの読み取り権限を持つ [AWS CLI](https://aws.amazon.com/cli/) v2 と `jq`。
2. 読み取り専用の権限：AWS 管理ポリシー `ReadOnlyAccess` と請求の読み取り（`ce:Get*`、`pricing:GetProducts`）。
3. そのあとエージェントに頼みます：`audit my AWS bill`。最初に環境を確認し、足りないものを伝えます。

### 対応エージェント

| エージェント | インストールコマンド（すべてのプロジェクト） | インストール確認 |
| :-- | :-- | :-- |
| Claude Code (plugin) | `claude plugin install aws-cost-audit@10x` | 2026-11-17 |
| Claude Code (skill) | `npx skills add Aboudjem/aws-cost-audit-skill -g -a claude-code` | 2026-11-17 |
| Codex | `npx skills add Aboudjem/aws-cost-audit-skill -g -a codex` | 2026-11-17 |
| Cursor | `npx skills add Aboudjem/aws-cost-audit-skill -g -a cursor` | 2026-11-17 |
| Gemini CLI | `npx skills add Aboudjem/aws-cost-audit-skill -g -a gemini-cli` | 2026-11-17 |
| GitHub Copilot | `npx skills add Aboudjem/aws-cost-audit-skill -g -a github-copilot` | 2026-11-17 |
| OpenCode | `npx skills add Aboudjem/aws-cost-audit-skill -g -a opencode` | 2026-11-17 |

「インストール確認」は、インストールが動き、`SKILL.md` がエージェントの読む場所に置かれたことを意味します。
CI は push のたびに Claude Code、Codex、Cursor でインストールを繰り返します。

ドキュメントはあるが、エンドツーエンドではテストしていないもの：Pi、Mistral Vibe、Trae、OpenClaw、Antigravity、Hermes、Cline、Kimi。
これらのエージェントコードは、2026-11-17 に、バージョン固定の skills CLI に受け付けられました。クローンしたリポジトリから `install.sh` でインストールします：

```bash
git clone https://github.com/Aboudjem/aws-cost-audit-skill && cd aws-cost-audit-skill
./install.sh pi
```

これはユーザープロファイル全体にインストールします。`--project` を付けると、現在のフォルダだけに入ります。
エディタごとのパスは [docs/editors.md](../docs/editors.md) にあります。

<details>
<summary>代わりに skill を手でコピーする</summary>

この skill は、Markdown とシェルスクリプトのフォルダです。エージェントが skill を読む場所にコピーしてください：

```bash
git clone https://github.com/Aboudjem/aws-cost-audit-skill
mkdir -p ~/.claude/skills
cp -r aws-cost-audit-skill/skills/aws-cost-audit ~/.claude/skills/aws-cost-audit
```

このリポジトリには、独自のマーケットプレイスマニフェストはありません。プラグインで使う場合は、上の 10x マーケットプレイスを使ってください。
</details>

## 仕組み

アカウントを読み、見つけたムダに価格をつけ、最初に結論を出します。頼まない限り何も変わりません。

<p align="center">
  <img src="../assets/how-it-works.svg" alt="仕組み：1 コストを読む、2 有効な全リージョンでムダを見つける、3 証拠つきの節約プラン" width="100%">
</p>

1. **事前チェック。** `doctor.sh` が AWS CLI、認証情報、`jq`、リージョン、出力フォルダを確認します。何も変えません。
2. **ベースライン。** Cost Explorer がサービス別、リージョン別、使用タイプ別の支出を返します。スクリプトはリクエストを数え、上限で止まります。
3. **探索。** 有効なすべてのリージョンで、使われていない、大きすぎる、忘れられたリソースを探します。チェック項目は [探索リスト](../skills/aws-cost-audit/references/hunt-list.md) にあります。
4. **価格。** 各価格は監査中に AWS から取り、記憶には頼りません。リージョンの Price List の照会に、実際の使用量を掛けます。
   段階料金では Cost Explorer の読み取りを使います。`verify-price.sh --record` が照会を所見に保存します。
5. **分類。** 各所見は KEEP、OPTIMIZE、SAFE-TO-DELETE のどれかで、確信度と証拠がつきます。
6. **レポート。** `findings-validate.sh` が `findings.json` を確認し、`findings-summary.sh` が結論と 3 つのアクションを出力します。

完全なレポートには、サービスごとの支払額が続きます。各所見に証拠と元に戻す方法があります。
[`examples/sample-report.md`](../examples/sample-report.md) と、任意の [HTML ダッシュボード](../examples/sample-dashboard.html) を見てください。

### 対象

コストの専門家（FinOps）がいない開発者や小さなチーム向けです。
Cost Explorer は合計を見せます。何を止めるかは言いません。このスキルは言います。
使われていないディスク、ずっと残るログ、終わっていないアップロードを見つけます。各所見に証拠と、元に戻せるかどうかがあります。

### 自分からは決してしないこと

何かを変更できるスクリプトは 3 つです。コードが次のルールを守らせます：

1. `--apply` がなければドライランだけです。ドライランはローカルにロールバックファイルを保存し、アカウントは何も変えません。
2. `--apply` があると、先にロールバックファイルを保存し、`yes` の入力を求めます。
3. `--yes` はその質問を飛ばします。確認できる端末がなく `--yes` もなければ、変更の前に拒否します。

`make test` が EBS 削除スクリプトでこの順序を確認します。
確実（確信度が高い）かつ元に戻せる、の両方でない削減は、先に所有者の OK（承認）が必要です。
スキルはエージェントに、まず未使用の証拠とドライランを見せ、あなたの yes を待つよう指示します。
Savings Plan の購入のように元に戻せない操作は、助言のままにするよう指示します。

スキル本体は [`SKILL.md`](../skills/aws-cost-audit/SKILL.md) です：5 つのルール、手順、必要なときに読む参照ファイル。

## 検証

下の数字はすべて、横にあるコマンドで再出力されます。

| 主張                                       | コマンド                                                     | 今日の出力                                                                    |
| :----------------------------------------- | :----------------------------------------------------------- | :---------------------------------------------------------------------------- |
| オフラインのテストスイートが通る           | `make test`                                                  | `Results: 167 passed, 0 failed`                                                |
| 上のサンプルはツールの実際の出力           | `make test`（ケース 39 が 1 行ずつ比較）                     | `[PASS] sample: the README sample report is the script output, line for line` |
| プラグインのマニフェストが有効             | `claude plugin validate . --strict`                          | `✔ Validation passed`                                                         |
| 単価がスクリプトに書き込まれていない       | `make test`（no-hardcoded-price ケース）                     | `[PASS] no per-request price literal in any script`                           |
| 価格付きの検出結果には照会記録が必要       | `make test`（price rule ケース） | `[PASS] price rule: a dollar figure with no price_lookups exits 1` |

テストスイートは `aws` コマンドをスタブに置き換えるので、認証情報は不要で、AWS への呼び出しもありません。
`delete-unattached-ebs.sh` の安全な順序も検査します：確認の前には何も変更しません。
CI は push とプルリクエストのたびにこれを実行します。CI は shellcheck、単価の直書きのスキャン、skills CLI のインストールも実行します。

スクリプトが呼び出してよいもの、そして外部に絶対に送らないものは、[PRIVACY.md](../PRIVACY.md) にあります。

## よくある質問

**勝手に何かを削除しますか？**
いいえ。デフォルトでは読み取りだけです。変更用のスクリプトは `--apply` を付けたときだけ動き、ロールバックファイルを保存してから `yes` の入力を求めます。
`--yes` は質問を省きます。skill はエージェントに、チャットであなたが yes と言った後にだけ渡すよう指示しています。
skill はエージェントに、先に未使用の証拠とドライランを見せるよう指示しています。元に戻せない操作は推奨にとどまります。

**AWS のキーは必要ですか？**
いいえ。マシンにすでにある AWS CLI の認証情報を使います。データの送り先は AWS とあなたのエージェントだけで、ほかには送りません。

**1 回の監査にいくらかかりますか？**
Cost Explorer は API リクエストごとに課金します。スクリプトはすべてのページを数え、`AWS_COST_AUDIT_CE_BUDGET` で止まります。デフォルトは 50 です。Price List の検索は無料です。

**なぜ金額を信用できますか？**
どの金額も出典を記録します。Price List の照会、または単一の単価がない場合は Cost Explorer の読み取りです。
`findings-validate.sh` は出典のない金額を却下します。検証できない金額は「unknown」と書かれ、どの合計にも含まれません。

**サンプルの数字は本物ですか？**
いいえ。サンプルレポート、ダッシュボード、デモは架空のアカウントを使っています。実際の AWS 請求から読み取ったものは何もありません。

**2 回の監査を比べられますか？**
はい。`findings.json` を出すよう頼んでください。`findings-validate.sh` が固定の契約に照らして検査するので、2 回分を差分で比べられます。

ほかの回答は [docs/faq.md](../docs/faq.md) にあります。

## 制限事項

- AWS CLI v2、bash、`jq` が必要です。Windows では、スクリプトに bash シェルが必要です。[docs/editors.md](../docs/editors.md) を見てください。
- 先に Cost Explorer を有効にしてください。AWS がデータを表示するまで最大 24 時間かかることがあります。
- skill はエージェントを導くだけです。能力の低いモデルは、手順を飛ばすことがあります。証拠の行を確認してください。
- 価格は、AWS が返すとおり USD です。
- バリデーターが確認するのは各価格記録の形式で、AWS が実際に返したかどうかではありません。`verify-price.sh --recheck findings.json` で Price List の照会をやり直せます。
- S3 Standard ストレージのような段階制の価格や Savings Plans には、単一の単価がありません。その検出結果は Cost Explorer の読み取りを記録します。読み取りは課金されるため、`--recheck` はやり直しません。
- 取得ではなく保存されている数字は一つだけです。監査自身の Cost Explorer リクエスト費用で、`references/pricing-verification.md` にあります。
- エージェント表の「インストール確認」は、インストールが実行されファイルが置かれたことを意味します。各エージェントが skill を読み込むところまで確認した、という意味ではありません。
- 変更前の未使用の証拠とドライランは、skill がエージェントに求める手順です。スクリプトが強制するのは `--apply`、ロールバックファイル、`yes` です。

## 詳しくは

- [クイックスタート](../docs/quickstart.md)：認証情報からダッシュボードまで、順を追って説明します。
- [エディタとエージェントの対応](../docs/editors.md)：エージェントごとに 1 行、手動コピーの方法もあります。
- [比較](../docs/comparison.md)：手作業の監査やコストダッシュボードとの比較です。
- [CHANGELOG](../CHANGELOG.md) · [CONTRIBUTING](../CONTRIBUTING.md) · [プライバシー](../PRIVACY.md) · [MIT ライセンス](../LICENSE)

---

<sub><a href="https://github.com/Aboudjem">Adam Boudjemaa</a> が作成、保守しています。古くなったコマンドを見つけたら、<a href="https://github.com/Aboudjem/aws-cost-audit-skill/issues">issue を開いてください</a>。</sub>

<sub>この文書は機械翻訳を補助に使っています。内容に違いがある場合は、英語版 README を正とします。</sub>
