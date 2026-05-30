<p align="center">
  <img src="https://raw.githubusercontent.com/Aboudjem/aws-cost-audit-skill/main/assets/hero.svg" alt="AWS Cost Audit: an executable, evidence-first AWS cost auditor for Claude Code" width="100%">
</p>

<h1 align="center">AWS Cost Audit Skill</h1>

<p align="center">
  <strong>Claude に AWS の請求を監査してもらいましょう。すべての数字が AWS のライブ料金に照らして検証され、あなたの承認なしには何も削除されない、明快なコスト削減プランが得られます。</strong>
</p>

<p align="center">
  <a href="../LICENSE"><img src="https://img.shields.io/badge/license-MIT-green.svg" alt="MIT license"></a>
  <img src="https://img.shields.io/badge/Claude%20Code-skill-d97757" alt="Claude Code skill">
  <img src="https://img.shields.io/badge/AWS-cost%20optimization-ff9900" alt="AWS cost optimization">
  <a href="../CONTRIBUTING.md"><img src="https://img.shields.io/badge/PRs-welcome-brightgreen.svg" alt="PRs welcome"></a>
  <a href="https://github.com/Aboudjem/10x"><img src="https://img.shields.io/badge/part%20of-10x%20marketplace-f59e0b" alt="Part of the 10x marketplace"></a>
</p>

<p align="center">
  品質を届ける Claude Code ツールの厳選セット、<a href="https://github.com/Aboudjem/10x"><b>10x</b> マーケットプレイス</a>の一部です。
</p>

<p align="center">
  <a href="../README.md">English</a> · <a href="zh-CN.md">简体中文</a> · <b>日本語</b> · <a href="es.md">Español</a> · <a href="fr.md">Français</a>
</p>

---

![aws-cost-audit demo](https://raw.githubusercontent.com/Aboudjem/aws-cost-audit-skill/main/assets/demo.gif)

<p align="center"><sub>Claude に請求を監査してもらい、エビデンス重視のコスト削減プランを得ましょう。表示されるすべての数字は<b>例示用</b>です(合成データ、実アカウントなし)。</sub></p>

---

## これは何ですか?

これは、あなたの AWS アカウントを代わりに監査する [Claude Code](https://www.claude.com/product/claude-code) スキルです。

Claude に *"audit my AWS bill"* のように頼みます。スキルはあなたのライブアカウントを読み取り、各項目のコストとその理由を割り出し、無駄を見つけ、平易な言葉のレポートを渡します:今いくら払っているか、安全に削れるものは何か、そして各項目についてどれだけ確信があるか。既定では読み取り専用です。価格を推測することはなく、自分の判断で何かを削除することもありません。

作業の過程を示す慎重な FinOps エンジニアだと考えてください。

**AWS コスト監査とは?** AWS アカウントを構造的にレビューし、何に対して支払っているか、どのリソースが無駄または過大であるか、何を安全に取り除けるかを見つけることです。このスキルはその監査を代わりに実行し、[AWS Well-Architected Framework のコスト最適化の柱](https://docs.aws.amazon.com/wellarchitected/latest/cost-optimization-pillar/welcome.html)と [FinOps Foundation](https://www.finops.org/framework/) のフレームワークに従うため、その手法は適当に作られたものではありません。

## インストール

好きなものを選んでください。3 つとも同じスキルをインストールします。

**[10x マーケットプレイス](https://github.com/Aboudjem/10x)から**(推奨。他の Claude Code ツールと並べて厳選されています):

```text
/plugin marketplace add Aboudjem/10x
/plugin install aws-cost-audit@10x
```

**このリポジトリから直接:**

```text
/plugin marketplace add Aboudjem/aws-cost-audit-skill
/plugin install aws-cost-audit@aws-cost-audit-skill
```

**ドロップイン型スキルとして**(プラグインシステムなし):

```bash
git clone https://github.com/Aboudjem/aws-cost-audit-skill
cp -r aws-cost-audit-skill/skills/aws-cost-audit ~/.claude/skills/aws-cost-audit
```

監査したいアカウントへの読み取りアクセスを持つ [AWS CLI](https://aws.amazon.com/cli/) も必要です。監査自体には `ReadOnlyAccess` で十分です。

### 他の AI CLI(1 行で)

これはスキルのみのプラグインです(MCP サーバーなし)。インストーラーは `aws-cost-audit` スキルを別の CLI のスキルディレクトリにシンボリックリンクします:

```bash
curl -fsSL https://raw.githubusercontent.com/Aboudjem/aws-cost-audit-skill/main/install.sh | bash -s <platform>
```

| プラットフォーム | スキルディレクトリ | リンク方式 |
|:--|:--|:--|
| gemini, codex, opencode, pi | `~/.agents/skills` | スキルごと |
| vscode, copilot | `~/.copilot/skills` | スキルごと |
| trae | `~/.trae/skills` | スキルごと |
| vibe | `~/.vibe/skills` | スキルごと |
| openclaw | `~/.openclaw/skills` | フォルダ |
| antigravity | `~/.gemini/antigravity/skills` | フォルダ |
| hermes, cline, kimi | `~/.<cli>/skills` | フォルダ |

上記すべてのプラットフォームにリンクするには `all` を渡します。最新版を再リンクするには `--update`、リンクを削除するには `--uninstall` を使います。

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
<summary>その他のエディタ(手動)</summary>

このスキルはプレーンな Markdown とシェルスクリプトです。`skills/aws-cost-audit/SKILL.md` と `references/` フォルダを、エディタが読み込むコンテキストディレクトリにコピーし、`skills/aws-cost-audit/scripts/` 内のヘルパースクリプトを直接実行します。これらは AWS CLI のみに依存します。
</details>

## 3 ステップで使う

1. **インストールする**(上記)。
2. **Claude に頼む**:*"audit my AWS bill"* または *"find my unused AWS resources"*。スキルは自動的に有効になります。
3. **プランを読む。** レポートと、任意の HTML ダッシュボードが得られ、各削減項目についてコスト、原因、確信度が示されます。

それだけです。あなたが頼まない限りアカウントには何も変更されず、頼んだ場合でも安全チェックとあなたの確認の後に限られます。

<p align="center">
  <img src="https://raw.githubusercontent.com/Aboudjem/aws-cost-audit-skill/main/assets/how-it-works.svg" alt="How it works: 1 re-baseline live, 2 hunt waste across every region, 3 evidence-backed savings plan" width="100%">
</p>

## 得られるもの

<p align="center">
  <img src="https://raw.githubusercontent.com/Aboudjem/aws-cost-audit-skill/main/assets/dashboard-preview.png" alt="Sample AWS cost audit dashboard: monthly run-rate, save-now-safely vs maximum-theoretical-save, with synthetic data" width="100%">
  <br><sub>任意のダッシュボード(サンプル表示、合成データ)。<a href="../examples/sample-dashboard.html"><code>examples/sample-dashboard.html</code></a> を開いて実際に確認できます。</sub>
</p>

- **支出の内訳。** 今支払っている額を、サービス別・リージョン別に、Cost Explorer からライブで取得します。
- **リソース単位のビュー。** 各リソースについて:コスト、平易な言葉での用途、誰がいつ作ったか、最後に使われたのはいつか。事実が検証できない場合は、推測せずにその旨を述べます。
- **2 部構成のコスト削減プラン。** 「今すぐ安全に削減」(高い確信度、可逆、低リスク)を「理論上の最大削減」(あなたの承認が必要な大きめの削減)と分けて保ちます。
- **任意のダッシュボード。** 非技術者でも読める、単一の自己完結型 HTML ページ。[`examples/sample-dashboard.html`](../examples/sample-dashboard.html) と[サンプルレポート](../examples/sample-report.md)を参照。
- **ガードレール。** 予算とコスト異常アラートがあるかを確認し、設定を手助けします。

## 実行の様子

上のレコーディング(`assets/demo.gif`)は例示用です:AWS の呼び出しにはライブの認証情報が必要なため、実アカウントではなく合成データを使っています([CONTRIBUTING.md](../CONTRIBUTING.md) の先送り項目の注記を参照)。以下が段階ごとに起こることで、[サンプルレポート](../examples/sample-report.md)と[サンプルダッシュボード](../examples/sample-dashboard.html)に反映されています(どちらも合成データを使い、明示的にラベル付けされています):

1. **アイデンティティ確認。** `aws sts get-caller-identity` が、他の何かが実行される前にアカウントとリージョンを確認します。
2. **支出のベースライン。** Cost Explorer(`aws ce get-cost-and-usage`)が直近 30 日と 90 日の支出を取得し、サービス別・リージョン別に分解します。表が表示されます:サービス → $/月 → 全体に占める割合。
3. **リソースインベントリ。** スキルは有効な各リージョンに展開し、EC2 インスタンス、EBS ボリューム、RDS インスタンス、NAT Gateway、ロードバランサー、S3 バケット、Lambda 関数、CloudWatch ロググループ、スナップショット、AMI、Elastic IP などを列挙します。何も変更されません。
4. **無駄の検出。** 各リソースをハントリスト(`skills/aws-cost-audit/references/hunt-list.md`)と照合します:アイドル CPU、未アタッチのボリューム、古いスナップショット、gp2 ボリューム、過剰に保持されたログ、Savings Plan カバレッジの欠如など。
5. **ライブ価格検証。** 削減候補ごとに、スキルは AWS Price List Query API からリージョン別のライブ単価を取得し、記憶した料金は使いません。すべてのドル数値について `unit price → math → source` を表示します。
6. **エビデンス付きレポート。** 発見事項は `current $/mo → after $/mo → $ saved · confidence · evidence · reversibility` の形で書かれ、「今すぐ安全に削減」(高い確信度、可逆、テスト済み)と「理論上の最大削減」に分けられます。正確な形は [`examples/sample-report.md`](../examples/sample-report.md) を参照。
7. **任意のダッシュボード。** 発見事項から HTML ファイルが生成されます。任意のブラウザで開いてください。[`examples/sample-dashboard.html`](../examples/sample-dashboard.html) を参照。

中規模の AWS アカウントでの実際の実行では、最初の Cost Explorer 呼び出しから数分以内に発見事項が浮上するのが通常です。読み取り専用フェーズは、いかなる是正提案を行う前に完了します。

## 数字を信頼できる理由

「AWS の請求を削減する」助言のほとんどは一般論か、価格を記憶から引用するツールです。このスキルは、決して破らない 5 つのルールを軸に作られています:

1. **でっち上げの価格はない。** すべてのドルは、*あなたの*リージョンの AWS ライブ価格に*実際の*使用量を掛けたものに由来します。単価、計算、出典を示します。どこにも価格をハードコードしません。
2. **すべてのドルを帰属させるか、「不明」と言う。** 所有者、日付、「最終使用」を決して捏造しません。
3. **証拠なしに破壊的なことはしない。** 変更は、リソースが未使用と証明され、操作が可逆で、ドライランを通過し、結果が確実な場合にのみ実行されます。それ以外は推奨にとどまります。
4. **1 つのサンプルが艦隊全体になることはない。** 別の懐疑的パスが、公表前に主要な数字を出典から再導出します。
5. **すべての発見事項は証拠を示す。** 現在のコスト、変更後のコスト、削減額、確信度、証拠、そして元に戻す方法。

これらのルールは、スキル*なし*のエージェントがそれらを破るのを目撃したから存在します。記録されたベースラインは [`docs/research/RED-baseline-findings.md`](../docs/research/RED-baseline-findings.md) にあります:同じ削減額を尋ねられた 2 つのモデルが、記憶から自信たっぷりに 2 つの異なる誤った数字を返しました。スキルはそれを修正します。

## 比較

| | このスキル | 手動監査 | コスト SaaS ダッシュボード |
|---|---|---|---|
| ライブアカウントに対して実行 | はい | はい | はい |
| 今すぐ無料で実行できる | はい | はい | 通常は有料 / シート課金 |
| 各価格をライブ検証(記憶料金なし) | はい | 人による | 自前の数字を表示 |
| リソース単位でコスト・所有者・最終使用を帰属 | はい | 手作業で遅い | 部分的 |
| 発見事項に安全に対処できる(ゲート付き + 可逆) | はい | 手動 | 読み取り専用 |
| 共有可能なレポート + ダッシュボードを生成 | はい | 手動 | はい |
| データを第三者に送信 | いいえ | いいえ | しばしば |
| ロックイン | なし(MIT、あなたのアカウント) | なし | ベンダー |

## FAQ

**Claude で AWS の請求を監査するには?**
このスキルをインストールし、Claude Code に「audit my AWS bill」と頼みます。AWS CLI であなたのアカウントを読み取り、エビデンスに基づくコストレポートと削減プランを生成します。

**安全ですか? 何か削除されますか?**
既定では読み取り専用です。自分の判断で削除・停止・変更を行うことはありません。あらゆる操作はゲート付きです:リソースが未使用と証明され、変更が可逆で、ドライランを通過し、あなたが確認する必要があります。不可逆な操作は常に推奨として残されます。

**AWS のキーが必要ですか?**
いいえ。あなた自身のマシン上にある既存の AWS CLI 認証情報を使います。どこにもアップロードされません。監査には `ReadOnlyAccess` で十分です。

**自分のアカウントで動きますか?**
はい。汎用です。あなたの CLI が指すアカウントを全リージョンにわたって読み取り、アカウント ID、ARN、価格を一切埋め込まずに出荷されます。

**AWS の価格をハードコードしますか?**
いいえ、意図的にしません。価格は変動しリージョンによって異なるため、常にあなたのリージョンのライブ価格を取得し、実際の使用量と組み合わせます。

**何をカバーしますか?**
アイドル・未アタッチのリソース、gp2→gp3、古いスナップショットと AMI、NAT とデータ転送のコスト、アイドルのロードバランサー、ライトサイジング、Savings Plans と Reserved Instance のカバレッジ、S3 ライフサイクル、CloudWatch ログ保持、リージョン間の取り残し、欠落した予算 / アラート。完全な一覧は[ハントリスト](../skills/aws-cost-audit/references/hunt-list.md)にあります。

**プラグインシステムなしで使えますか?**
はい。`skills/aws-cost-audit/` を `~/.claude/skills/aws-cost-audit/` にコピーすれば、同じように動きます。

## 内部の仕組み

スキルは [`skills/aws-cost-audit/SKILL.md`](../skills/aws-cost-audit/SKILL.md) にあります。重い詳細は必要なときにだけ `references/` から読み込まれます:

- [`hunt-list.md`](../skills/aws-cost-audit/references/hunt-list.md):各高 ROI チェックと、それを検出する読み取り専用コマンド。
- [`pricing-verification.md`](../skills/aws-cost-audit/references/pricing-verification.md):リージョンに正しいライブ価格をどう取得し、再確認するか。
- [`safety-and-gating.md`](../skills/aws-cost-audit/references/safety-and-gating.md):executor → verifier → rollback のゲートと、決して単独で実行してはならないもの。
- [`output-and-reporting.md`](../skills/aws-cost-audit/references/output-and-reporting.md):レポートの形と、発見事項ごとの契約。

[`scripts/`](../skills/aws-cost-audit/scripts) 内のヘルパースクリプトは既定でドライランです。最初のガイド付き実行については[クイックスタート](../docs/quickstart.md)を参照してください。

## エディタのサポート

このスキルは **Claude Code** 向けに設計されています。`SKILL.md` を Claude Code のコンテキストに読み込み、AWS CLI を呼び出すことで動作するため、ランタイムとして Claude Code を必要とします。

他の AI エディタ(Cursor、Copilot 付き VS Code、Windsurf、Codex、Gemini CLI)は、Claude Code のプラグインやスキル形式をネイティブには使いません。これらのエディタを使っている場合、最も実用的な方法は次のとおりです:

1. AWS CLI をインストールし、通常どおり認証情報を設定します。
2. `skills/aws-cost-audit/SKILL.md` と `references/` フォルダを、プロジェクト(またはエディタが読む個人のコンテキストディレクトリ)にコピーします。
3. SKILL.md の内容をシステムプロンプトまたはカスタム指示としてエディタに指定します。
4. `skills/aws-cost-audit/scripts/` 内のヘルパースクリプトを直接実行します。これらは AWS CLI のみに依存し、Claude Code には依存しないプレーンなシェルスクリプトです。

スキルのロジック(Iron Laws、ワークフロー、安全ゲート)は完全に移植可能です。*インストールの仕組み*(プラグインシステム、`/skill` 自動検出)だけが Claude Code 固有です。

## コントリビュート

Issue と PR を歓迎します。1 つだけ固い決まり:このスキルはテストファーストで作られているため、振る舞いを追加する変更には、それが修正する失敗ベースラインが必要です。[CONTRIBUTING.md](../CONTRIBUTING.md) と[行動規範](../CODE_OF_CONDUCT.md)を参照してください。

## Star History

<a href="https://star-history.com/#Aboudjem/aws-cost-audit-skill&Date">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=Aboudjem/aws-cost-audit-skill&type=Date&theme=dark">
    <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=Aboudjem/aws-cost-audit-skill&type=Date">
    <img alt="Star history of Aboudjem/aws-cost-audit-skill" src="https://api.star-history.com/svg?repos=Aboudjem/aws-cost-audit-skill&type=Date">
  </picture>
</a>

## ライセンス

[MIT](../LICENSE)。使って、フォークして、出荷してください。

---

<sub><a href="https://github.com/Aboudjem">Adam Boudjemaa</a> が作成・保守しています。コマンドは 2026 年に AWS CLI v2 と AWS ドキュメントに照らして検証済みです。古いコマンドや抜けを見つけましたか? <a href="https://github.com/Aboudjem/aws-cost-audit-skill/issues">issue を開いてください</a>。</sub>

---

<sub>機械支援による翻訳です。ネイティブスピーカーによる修正を歓迎します:<a href="https://github.com/Aboudjem/aws-cost-audit-skill/issues">issue</a> または PR を開いてください。</sub>
