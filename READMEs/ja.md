<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="../assets/hero-dark.svg">
    <source media="(prefers-color-scheme: light)" srcset="../assets/hero-light.svg">
    <img src="../assets/hero-dark.svg" alt="aws-cost-audit: 検証できる削減プラン。すべての金額を AWS の実価格と突き合わせます" width="100%">
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
  <a href="../README.md">English</a> · <a href="zh-CN.md">简体中文</a> · <b>日本語</b> · <a href="es.md">Español</a> · <a href="fr.md">Français</a>
</p>

<p align="center">
  <strong>AWS の請求書の監査を Claude に頼んでください。すべての金額は AWS の実価格で検証されます。</strong>
</p>

<p align="center">
  <a href="#できること">できること</a> · <a href="#インストール">インストール</a> · <a href="#使ってみる">使ってみる</a> · <a href="#得られるもの">得られるもの</a> · <a href="#お使いのエディタで動きます">お使いのエディタで動きます</a> · <a href="#知っておきたいこと">知っておきたいこと</a>
</p>

![aws-cost-audit demo](../assets/demo.gif)

<p align="center"><sub>録画中の数値はすべて<b>説明用</b>です。合成データであり、実アカウントは使っていません。</sub></p>

```bash
claude plugin marketplace add Aboudjem/10x
claude plugin install aws-cost-audit@10x
```

## できること

[Claude Code](https://www.claude.com/product/claude-code) のスキルです。中身は 1 つの Markdown 指示ファイル、必要になったときだけ読み込まれる 6 つの参考文書、そして 10 個の bash ヘルパースクリプトです。AWS の支出について尋ねると Claude がこれを拾い上げます。

「AWS の請求書を監査して」と言うだけです。すでに手元にある AWS CLI を通じてアカウントを読み取り、各リソースがいくら、なぜかかっているのかを割り出し、プランを返します。既定では読み取りのみです。記憶から価格を答えることはなく、勝手に何かを削除することもありません。

- **支出の内訳。** サービス別・リージョン別の現在の支払額を、Cost Explorer から実データで取得します。
- **リソース単位のビュー。** それぞれの費用、何をしているのかの平易な説明、誰が作ったのか、最後に使われたのはいつか。裏付けの取れない事実は、推測せずに「確認できない」と明記します。
- **2 つに分けた削減プラン。**「今すぐ安全に削減できる分」(元に戻せる、確度が高い) を「理論上の最大削減額」と分けて示します。後者にはあなたの承認が必要です。

手法は [AWS Well-Architected のコスト最適化の柱](https://docs.aws.amazon.com/wellarchitected/latest/cost-optimization-pillar/welcome.html)と [FinOps Foundation](https://www.finops.org/framework/) のフレームワークに従っています。スキルが独自に考え出したものではありません。

## インストール

Claude Code 内で、[10x マーケットプレイス](https://github.com/Aboudjem/10x)から:

```bash
claude plugin marketplace add Aboudjem/10x
claude plugin install aws-cost-audit@10x
```

その他のエージェントでは、[Vercel skills CLI](https://github.com/vercel-labs/skills) 経由で:

```bash
npx skills add Aboudjem/aws-cost-audit-skill
```

あわせて、監査したいアカウントへの読み取り権限を持つ [AWS CLI](https://aws.amazon.com/cli/) の設定が必要です。監査そのものには、AWS マネージドの `ReadOnlyAccess` ポリシーと請求情報の読み取り権限があれば十分です。

<details>
<summary>代わりにスキルを手動でコピーする</summary>

プラグインの仕組みは使わなくても構いません。このスキルは Markdown とシェルスクリプトが入ったディレクトリにすぎないので、エージェントが読むディレクトリにコピーするだけで足ります:

```bash
git clone https://github.com/Aboudjem/aws-cost-audit-skill
mkdir -p ~/.claude/skills
cp -r aws-cost-audit-skill/skills/aws-cost-audit ~/.claude/skills/aws-cost-audit
```

このリポジトリは独自のマーケットプレイスマニフェストを持たないため、`claude plugin marketplace add Aboudjem/aws-cost-audit-skill` は解決しません。プラグイン経路は上の 10x マーケットプレイスです。Windows とエディタごとのパスは [docs/editors.md](../docs/editors.md) にあります。
</details>

## 使ってみる

**1. 実行環境を確認する。** `doctor.sh` は監査を始める前に不足しているものを挙げます。変更を伴う AWS 呼び出しは一切行わず、apply フラグもなく、自分で書いたプローブファイルは削除します:

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

**2. Claude に頼む。** `audit my AWS bill` または `find my unused AWS resources` と伝えてください。スキルはこの言い回しで起動するように書かれています。アカウントが複数あるなら、どのプロファイルとどのリージョンを見るかを伝えましょう。

**3. プランを読む。** レポートと、必要なら HTML ダッシュボードが得られます。あなたが頼まない限りアカウントには何の変更も入りません。頼んだ場合でも、ドライランとあなたの確認を経てからです。

<p align="center">
  <img src="../assets/how-it-works.svg" alt="How it works: 1 re-baseline live, 2 hunt waste across every region, 3 evidence-backed savings plan" width="100%">
</p>

認証情報の準備からダッシュボードまでの通しの手順は[クイックスタート](../docs/quickstart.md)にあります。

## 得られるもの

- **レポート。** 各指摘は `current $/mo -> after $/mo -> $ saved` の形式で、根拠、確度、元に戻す手順が付きます。[`examples/sample-report.md`](../examples/sample-report.md) を参照してください。
- **任意のダッシュボード。** 技術者でない人でも開ける HTML ファイル 1 つ。フォントとチャートライブラリを CDN から読み込むので、ネットワークのあるマシンで正しく表示されます。[`examples/sample-dashboard.html`](../examples/sample-dashboard.html) を参照してください。
- **求めれば機械可読な `findings.json`。** 固定された構造契約に対して `findings-validate.sh` が検証します。だからこそ 2 回の監査を読み直さずに比べられます。
- **すべての金額に実価格。** 単価、計算式、出典を、お使いのリージョンについて調べます。まず Price List Query API を当たり、確認できない数値は unknown のままにします。
- **ガードレール。** 予算とコスト異常検出のアラートが設定されているかを報告し、設定を手伝います。

## お使いのエディタで動きます

| エージェント | 1 行のインストールコマンド |
|:--|:--|
| Claude Code | `claude plugin install aws-cost-audit@10x` |
| その他 70 以上のエージェント | `npx skills add Aboudjem/aws-cost-audit-skill` |
| Codex、Gemini CLI、OpenCode、Pi | `./install.sh codex` (または `gemini`、`opencode`、`pi`) |
| Copilot 入りの VS Code | `./install.sh copilot` |
| それ以外すべて | [docs/editors.md](../docs/editors.md) を参照 |

Claude Code、Cursor、Codex、Copilot、Gemini CLI で動作し、`npx skills add` を通じてさらに 70 以上のエージェントに対応します。`install.sh` はこのリポジトリが以前から対応している 13 のエディタ id 向けのラッパーで、現在は同じ CLI に処理を委ねます:

```bash
curl -fsSL https://raw.githubusercontent.com/Aboudjem/aws-cost-audit-skill/main/install.sh | bash -s codex
```

このプラグインは意図的に MCP サーバーを提供しません。すでに手元にある AWS CLI を呼び出すだけなので、余分なプロセスも、`.mcp.json` に書き足すものもありません。

## 知っておきたいこと

> [!IMPORTANT]
> 既定では読み取りのみです。自らの判断で削除、停止、変更を行うことはありません。あらゆる操作にはゲートがあります。対象が未使用であると証明され、変更が元に戻せて、ドライランを通り、そのうえであなたが確認する必要があります。元に戻せない操作は常に提案のままにとどまります。

- **記憶から価格を答えません。** すべての金額は、あなたのリージョンの実価格に実使用量を掛けたものです。スクリプトにも個々の指摘にもリソース価格は書き込まれておらず、書き込まれれば CI がビルドを失敗させます。このリポジトリが記録している唯一の価格は Cost Explorer 自体のリクエスト単価、つまり監査を実行する費用であって、監査が報告する対象の価格ではありません。AWS の出典とともに参考ドキュメントに置かれています。
- **Cost Explorer のリクエストは数えられ、上限が掛かります。** スクリプトのリクエストは 1 つのラッパーを通り、ページごとに数えたうえで `AWS_COST_AUDIT_CE_BUDGET` を超える 1 回を拒否します。あなたが自分で打つ `aws ce` はこの計数の外です。
- **通信相手は AWS だけです。** 手元にある既存の AWS CLI 認証情報をローカルで使い、キーを要求せず、監査結果をどの第三者にも送りません。スクリプトに必要なのは bash と AWS CLI で、`findings-validate.sh` にはさらに `jq` が要ります。

## さらに詳しく

- [クイックスタート](../docs/quickstart.md): 前提条件、インストール、そして 1 回の実行が何を順に行うか。
- [エディタとエージェントの対応](../docs/editors.md): エージェントごとに 1 行、手動コピーの手順も。
- [FAQ](../docs/faq.md): 何を対象にするか、実行にいくらかかるか、何に触れないか。
- [他との比較](../docs/comparison.md): 手作業の監査、コストダッシュボードとの比較。
- [スキル本体](../skills/aws-cost-audit/SKILL.md): 5 つの鉄則、ワークフロー、必要に応じて読み込む参考文書。
- [CHANGELOG](../CHANGELOG.md) · [CONTRIBUTING](../CONTRIBUTING.md) · [MIT ライセンス](../LICENSE)

---

<sub><a href="https://github.com/Aboudjem">Adam Boudjemaa</a> が開発・保守しています。コマンドは AWS CLI v2 向けに書かれています。古いコマンドや抜けを見つけたら <a href="https://github.com/Aboudjem/aws-cost-audit-skill/issues">issue を立ててください</a>。</sub>

<sub>この文書は機械翻訳を用いて作成されています。英語版との相違がある場合は英語版が優先されます。</sub>
