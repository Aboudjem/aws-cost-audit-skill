<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="../assets/hero-dark.svg">
    <source media="(prefers-color-scheme: light)" srcset="../assets/hero-light.svg">
    <img src="../assets/hero-dark.svg" alt="aws-cost-audit : un plan d'économies vérifiable, chaque montant recoupé avec les tarifs AWS en direct" width="100%">
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
  <a href="../README.md">English</a> · <a href="zh-CN.md">简体中文</a> · <a href="ja.md">日本語</a> · <a href="es.md">Español</a> · <b>Français</b>
</p>

<p align="center">
  <strong>Demandez à Claude d'auditer votre facture AWS. Chaque montant est recoupé avec les tarifs AWS en direct.</strong>
</p>

<p align="center">
  <a href="#ce-quil-fait">Ce qu'il fait</a> · <a href="#installation">Installation</a> · <a href="#lutiliser">L'utiliser</a> · <a href="#ce-que-vous-obtenez">Ce que vous obtenez</a> · <a href="#compatible-avec-votre-éditeur">Compatible avec votre éditeur</a> · <a href="#bon-à-savoir">Bon à savoir</a>
</p>

![aws-cost-audit demo](../assets/demo.gif)

<p align="center"><sub>Tous les montants de l'enregistrement sont <b>indicatifs</b> : données synthétiques, aucun compte réel.</sub></p>

```bash
claude plugin marketplace add Aboudjem/10x
claude plugin install aws-cost-audit@10x
```

## Ce qu'il fait

C'est une compétence pour [Claude Code](https://www.claude.com/product/claude-code) : un fichier Markdown d'instructions, six documents de référence chargés seulement quand ils servent, et dix scripts bash. Claude s'en saisit quand vous l'interrogez sur vos dépenses AWS.

Vous dites « audite ma facture AWS ». Il lit votre compte via l'AWS CLI que vous avez déjà, calcule ce que coûte chaque ressource et pourquoi, puis vous rend un plan. Par défaut, il ne fait que lire. Il ne cite jamais un tarif de mémoire et ne supprime jamais rien de lui-même.

- **Une ventilation des dépenses.** Ce que vous payez par service et par région, récupéré en direct depuis Cost Explorer.
- **Une vue par ressource.** Ce que coûte chaque élément, à quoi il sert en clair, qui l'a créé et quand il a servi pour la dernière fois. Si un fait ne peut pas être vérifié, il le dit au lieu de deviner.
- **Un plan d'économies en deux moitiés.** « À économiser tout de suite sans risque » (réversible, confiance élevée), séparé de « l'économie théorique maximale », qui demande votre accord.

La méthode suit le [pilier optimisation des coûts d'AWS Well-Architected](https://docs.aws.amazon.com/wellarchitected/latest/cost-optimization-pillar/welcome.html) et le cadre de la [FinOps Foundation](https://www.finops.org/framework/) : ce n'est pas une méthode inventée par la compétence.

## Installation

Dans Claude Code, depuis la [place de marché 10x](https://github.com/Aboudjem/10x) :

```bash
claude plugin marketplace add Aboudjem/10x
claude plugin install aws-cost-audit@10x
```

Dans n'importe quel autre agent, via la [CLI skills de Vercel](https://github.com/vercel-labs/skills) :

```bash
npx skills add Aboudjem/aws-cost-audit-skill
```

Il vous faut aussi l'[AWS CLI](https://aws.amazon.com/cli/) configurée avec un accès en lecture au compte à auditer. La politique gérée `ReadOnlyAccess` d'AWS plus la lecture de la facturation suffisent pour l'audit lui-même.

<details>
<summary>Copier la compétence à la main à la place</summary>

Passez-vous complètement du système de plugins. La compétence n'est qu'un dossier de Markdown et de scripts shell : la copier dans un dossier que votre agent lit suffit.

```bash
git clone https://github.com/Aboudjem/aws-cost-audit-skill
mkdir -p ~/.claude/skills
cp -r aws-cost-audit-skill/skills/aws-cost-audit ~/.claude/skills/aws-cost-audit
```

Ce dépôt ne porte pas de manifeste de place de marché qui lui soit propre, donc `claude plugin marketplace add Aboudjem/aws-cost-audit-skill` ne résoudra rien. La voie plugin, c'est la place de marché 10x ci-dessus. Windows et les chemins propres à chaque éditeur sont dans [docs/editors.md](../docs/editors.md).
</details>

## L'utiliser

**1. Vérifiez l'environnement.** `doctor.sh` nomme ce qui manque avant qu'un audit ne démarre. Il ne passe aucun appel AWS qui modifie quoi que ce soit, n'a pas d'option d'application, et supprime le fichier de sonde qu'il écrit :

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

**2. Demandez à Claude.** Dites `audit my AWS bill`, ou `find my unused AWS resources`. La compétence est écrite pour se déclencher sur cette formulation. Si vous avez plusieurs comptes, précisez le profil et les régions à examiner.

**3. Lisez le plan.** Vous obtenez un rapport et, si vous le souhaitez, un tableau de bord HTML. Rien ne change dans votre compte sans que vous le demandiez, et même alors, seulement après une simulation et votre confirmation.

<p align="center">
  <img src="../assets/how-it-works.svg" alt="How it works: 1 re-baseline live, 2 hunt waste across every region, 3 evidence-backed savings plan" width="100%">
</p>

Le parcours complet, des identifiants au tableau de bord, est dans le [guide de démarrage](../docs/quickstart.md).

## Ce que vous obtenez

- **Un rapport.** Chaque constat se lit `current $/mo -> after $/mo -> $ saved`, avec la preuve, un niveau de confiance et la marche à suivre pour revenir en arrière. Voir [`examples/sample-report.md`](../examples/sample-report.md).
- **Un tableau de bord, si vous en voulez un.** Un seul fichier HTML qu'une personne non technique peut ouvrir. Il tire sa police et sa bibliothèque de graphiques d'un CDN, donc il s'affiche correctement sur une machine connectée. Voir [`examples/sample-dashboard.html`](../examples/sample-dashboard.html).
- **Un `findings.json` lisible par une machine, sur demande.** Contrôlé par `findings-validate.sh` face à un contrat structurel figé, ce qui est précisément ce qui permet de comparer deux audits au lieu de les relire.
- **Un tarif en direct pour chaque montant.** Prix unitaire, le calcul et la source, cherchés pour votre région. L'API Price List Query est le premier recours ; ce qui ne peut pas être vérifié reste marqué inconnu.
- **Des garde-fous.** Il indique si vous avez des budgets et des alertes d'anomalie de coût, et vous aide à les mettre en place.

## Compatible avec votre éditeur

| Agent | Installation en une ligne |
|:--|:--|
| Claude Code | `claude plugin install aws-cost-audit@10x` |
| N'importe lequel des 70+ autres agents | `npx skills add Aboudjem/aws-cost-audit-skill` |
| Codex, Gemini CLI, OpenCode, Pi | `./install.sh codex` (ou `gemini`, `opencode`, `pi`) |
| VS Code avec Copilot | `./install.sh copilot` |
| Tout le reste | voir [docs/editors.md](../docs/editors.md) |

Fonctionne dans Claude Code, Cursor, Codex, Copilot, Gemini CLI et 70+ autres agents via `npx skills add`. `install.sh` est l'enveloppe des treize identifiants d'éditeur que ce dépôt a toujours pris en charge, et il délègue désormais à cette même CLI :

```bash
curl -fsSL https://raw.githubusercontent.com/Aboudjem/aws-cost-audit-skill/main/install.sh | bash -s codex
```

Ce plugin ne fournit pas de serveur MCP, volontairement. Il appelle l'AWS CLI que vous avez déjà : aucun processus supplémentaire à lancer, rien à ajouter dans un `.mcp.json`.

## Bon à savoir

> [!IMPORTANT]
> Par défaut, il ne fait que lire. Il ne supprime, n'arrête et ne modifie rien de lui-même. Toute action passe par un verrou : la ressource doit être prouvée inutilisée, le changement doit être réversible, il doit passer une simulation, et vous devez confirmer. Les actions irréversibles restent toujours des recommandations.

- **Aucun tarif de mémoire.** Chaque montant vient du tarif AWS en direct pour votre région multiplié par votre usage réel. Aucun prix de ressource n'est écrit dans un script ni dans un constat, et la CI fait échouer la construction s'il en apparaît un. Le seul prix que ce dépôt enregistre est le coût par requête de l'API Cost Explorer elle-même, c'est-à-dire ce que coûte l'exécution de l'audit, pas le prix de ce qu'il rapporte. Il est conservé dans un document de référence avec sa source AWS.
- **Les requêtes Cost Explorer sont comptées et plafonnées.** Les scripts font passer leurs requêtes par une seule enveloppe qui compte chaque page et refuse celle qui dépasserait `AWS_COST_AUDIT_CE_BUDGET`. Un appel `aws ce` que vous lancez vous-même sort de ce décompte.
- **Il parle à AWS et à personne d'autre.** Il utilise en local les identifiants AWS CLI que vous avez déjà, ne réclame aucune clé et n'envoie votre audit à aucun tiers. Les scripts ont besoin de bash et de l'AWS CLI ; `findings-validate.sh` demande en plus `jq`.

## Pour aller plus loin

- [Guide de démarrage](../docs/quickstart.md) : prérequis, installation, et ce qu'une exécution complète fait étape par étape.
- [Prise en charge des éditeurs et des agents](../docs/editors.md) : une ligne par agent, plus la copie manuelle.
- [FAQ](../docs/faq.md) : ce qu'il couvre, ce que coûte une exécution, ce à quoi il ne touche pas.
- [Comparaison](../docs/comparison.md) : face à un audit manuel et face à un tableau de bord de coûts.
- [La compétence elle-même](../skills/aws-cost-audit/SKILL.md) : les cinq lois d'airain, le flux de travail et les documents de référence chargés à la demande.
- [CHANGELOG](../CHANGELOG.md) · [CONTRIBUTING](../CONTRIBUTING.md) · [Licence MIT](../LICENSE)

---

<sub>Créé et maintenu par <a href="https://github.com/Aboudjem">Adam Boudjemaa</a>. Les commandes sont écrites pour AWS CLI v2. Vous repérez une commande obsolète ou un manque ? <a href="https://github.com/Aboudjem/aws-cost-audit-skill/issues">Ouvrez une issue</a>.</sub>

<sub>Ce document a été traduit avec l'aide d'un outil automatique. En cas de divergence, la version anglaise fait foi.</sub>
