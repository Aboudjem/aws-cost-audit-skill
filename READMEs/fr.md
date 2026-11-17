<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="../assets/hero-dark.svg">
    <source media="(prefers-color-scheme: light)" srcset="../assets/hero-light.svg">
    <img src="../assets/hero-dark.svg" alt="aws-cost-audit : voir ce qu'il faut arrêter de payer. Une barre de facture d'exemple, avec trois économies sorties : 84 $, 72 $ et 58 $ par mois, chacune avec la source de son prix. Tampon SAMPLE: fictional account." width="100%">
  </picture>
</p>

<h1 align="center">aws-cost-audit</h1>

<p align="center">
  <a href="../LICENSE"><img src="https://img.shields.io/github/license/Aboudjem/aws-cost-audit-skill" alt="Licence MIT"></a>
  <a href="https://github.com/Aboudjem/aws-cost-audit-skill/actions/workflows/validate.yml"><img src="https://img.shields.io/github/actions/workflow/status/Aboudjem/aws-cost-audit-skill/validate.yml?branch=main&label=validate" alt="statut du workflow validate"></a>
  <a href="https://github.com/Aboudjem/10x"><img src="https://img.shields.io/badge/part%20of-10x-FFB341" alt="Fait partie de la marketplace 10x"></a>
</p>

<p align="center">
  <a href="../README.md">English</a> · <a href="zh-CN.md">简体中文</a> · <a href="ja.md">日本語</a> · <a href="es.md">Español</a> · <b>Français</b>
</p>

<p align="center"><strong>Trouvez ce qu'il faut arrêter de payer sur votre facture AWS.</strong></p>

<p align="center">Votre agent lit votre compte AWS et classe ce qu'il faut couper.</p>

| Facture AWS plus basse | Prix vérifiés auprès d'AWS | Retour arrière avant tout changement |
|:--|:--|:--|
| Chaque rapport commence par un verdict en dollars et les trois économies à faire d'abord. | Chaque prix enregistre sa recherche AWS. `make test` montre qu'un montant sans elle est rejeté. | Les scripts simulent par défaut. `--apply` enregistre d'abord un fichier de retour arrière, puis demande, sauf avec `--yes`. |

**Compatible avec :** tout agent qui lit les skills. Installation testée : Claude Code, Codex, Cursor, Gemini CLI, GitHub Copilot, OpenCode.
C'est du Markdown et du bash, donc ce n'est lié à aucun modèle.

```bash
npx skills add Aboudjem/aws-cost-audit-skill -g -a claude-code -y
# donnez-lui des identifiants AWS en lecture seule, puis demandez à votre agent : audit my AWS bill
```

Cela installe pour tous vos projets. Les autres agents et le plugin Claude Code sont sous [Installation](#installation).

C'est un skill pour votre agent IA, avec des scripts qui lisent votre compte AWS.
Utilisez-le quand votre facture monte et que vous ne savez pas pourquoi.

Vous obtenez une liste classée d'économies. Chacune montre sa preuve et l'origine de son prix.

## Exemple de rapport

Chaque rapport commence ainsi. Celui-ci est une illustration : compte fictif, chiffres inventés, aucune donnée AWS réelle.
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

Réimprimez-le avec `bash skills/aws-cost-audit/scripts/findings-summary.sh examples/sample-findings.json`.

Il faut l'AWS CLI, `jq` et Cost Explorer. Les nouvelles données de Cost Explorer peuvent mettre 24 heures à apparaître.

## Installation

**Choisissez votre agent.** Chaque commande installe pour tous vos projets.

[![Claude Code](https://img.shields.io/badge/Claude_Code-D97757?style=for-the-badge&logo=claude&logoColor=white)](#claude-code) [![Codex](https://img.shields.io/badge/Codex-000000?style=for-the-badge&logo=data%3Aimage%2Fsvg%2Bxml%3Bbase64%2CPHN2ZyBmaWxsPSJ3aGl0ZSIgcm9sZT0iaW1nIiB2aWV3Qm94PSIwIDAgMjQgMjQiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI%2BPHRpdGxlPk9wZW5BSTwvdGl0bGU%2BPHBhdGggZD0iTTIyLjI4MTkgOS44MjExYTUuOTg0NyA1Ljk4NDcgMCAwIDAtLjUxNTctNC45MTA4IDYuMDQ2MiA2LjA0NjIgMCAwIDAtNi41MDk4LTIuOUE2LjA2NTEgNi4wNjUxIDAgMCAwIDQuOTgwNyA0LjE4MThhNS45ODQ3IDUuOTg0NyAwIDAgMC0zLjk5NzcgMi45IDYuMDQ2MiA2LjA0NjIgMCAwIDAgLjc0MjcgNy4wOTY2IDUuOTggNS45OCAwIDAgMCAuNTExIDQuOTEwNyA2LjA1MSA2LjA1MSAwIDAgMCA2LjUxNDYgMi45MDAxQTUuOTg0NyA1Ljk4NDcgMCAwIDAgMTMuMjU5OSAyNGE2LjA1NTcgNi4wNTU3IDAgMCAwIDUuNzcxOC00LjIwNTggNS45ODk0IDUuOTg5NCAwIDAgMCAzLjk5NzctMi45MDAxIDYuMDU1NyA2LjA1NTcgMCAwIDAtLjc0NzUtNy4wNzI5em0tOS4wMjIgMTIuNjA4MWE0LjQ3NTUgNC40NzU1IDAgMCAxLTIuODc2NC0xLjA0MDhsLjE0MTktLjA4MDQgNC43NzgzLTIuNzU4MmEuNzk0OC43OTQ4IDAgMCAwIC4zOTI3LS42ODEzdi02LjczNjlsMi4wMiAxLjE2ODZhLjA3MS4wNzEgMCAwIDEgLjAzOC4wNTJ2NS41ODI2YTQuNTA0IDQuNTA0IDAgMCAxLTQuNDk0NSA0LjQ5NDR6bS05LjY2MDctNC4xMjU0YTQuNDcwOCA0LjQ3MDggMCAwIDEtLjUzNDYtMy4wMTM3bC4xNDIuMDg1MiA0Ljc4MyAyLjc1ODJhLjc3MTIuNzcxMiAwIDAgMCAuNzgwNiAwbDUuODQyOC0zLjM2ODV2Mi4zMzI0YS4wODA0LjA4MDQgMCAwIDEtLjAzMzIuMDYxNUw5Ljc0IDE5Ljk1MDJhNC40OTkyIDQuNDk5MiAwIDAgMS02LjE0MDgtMS42NDY0ek0yLjM0MDggNy44OTU2YTQuNDg1IDQuNDg1IDAgMCAxIDIuMzY1NS0xLjk3MjhWMTEuNmEuNzY2NC43NjY0IDAgMCAwIC4zODc5LjY3NjVsNS44MTQ0IDMuMzU0My0yLjAyMDEgMS4xNjg1YS4wNzU3LjA3NTcgMCAwIDEtLjA3MSAwbC00LjgzMDMtMi43ODY1QTQuNTA0IDQuNTA0IDAgMCAxIDIuMzQwOCA3Ljg3MnptMTYuNTk2MyAzLjg1NThMMTMuMTAzOCA4LjM2NCAxNS4xMTkyIDcuMmEuMDc1Ny4wNzU3IDAgMCAxIC4wNzEgMGw0LjgzMDMgMi43OTEzYTQuNDk0NCA0LjQ5NDQgMCAwIDEtLjY3NjUgOC4xMDQydi01LjY3NzJhLjc5Ljc5IDAgMCAwLS40MDctLjY2N3ptMi4wMTA3LTMuMDIzMWwtLjE0Mi0uMDg1Mi00Ljc3MzUtMi43ODE4YS43NzU5Ljc3NTkgMCAwIDAtLjc4NTQgMEw5LjQwOSA5LjIyOTdWNi44OTc0YS4wNjYyLjA2NjIgMCAwIDEgLjAyODQtLjA2MTVsNC44MzAzLTIuNzg2NmE0LjQ5OTIgNC40OTkyIDAgMCAxIDYuNjgwMiA0LjY2ek04LjMwNjUgMTIuODYzbC0yLjAyLTEuMTYzOGEuMDgwNC4wODA0IDAgMCAxLS4wMzgtLjA1NjdWNi4wNzQyYTQuNDk5MiA0LjQ5OTIgMCAwIDEgNy4zNzU3LTMuNDUzN2wtLjE0Mi4wODA1TDguNzA0IDUuNDU5YS43OTQ4Ljc5NDggMCAwIDAtLjM5MjcuNjgxM3ptMS4wOTc2LTIuMzY1NGwyLjYwMi0xLjQ5OTggMi42MDY5IDEuNDk5OHYyLjk5OTRsLTIuNTk3NCAxLjQ5OTctMi42MDY3LTEuNDk5N1oiLz48L3N2Zz4%3D)](#codex) [![Cursor](https://img.shields.io/badge/Cursor-000000?style=for-the-badge&logo=cursor&logoColor=white)](#cursor) [![Gemini CLI](https://img.shields.io/badge/Gemini_CLI-8E75B2?style=for-the-badge&logo=googlegemini&logoColor=white)](#gemini-cli) [![GitHub Copilot](https://img.shields.io/badge/GitHub_Copilot-24292F?style=for-the-badge&logo=githubcopilot&logoColor=white)](#github-copilot) [![OpenCode](https://img.shields.io/badge/OpenCode-333333?style=for-the-badge&logo=opencode&logoColor=white)](#opencode)

### Claude Code

Installation testée. Ajoutez le plugin depuis la [marketplace 10x](https://github.com/Aboudjem/10x). Il s'installe pour votre utilisateur, dans tous les projets.

```bash
claude plugin marketplace add Aboudjem/10x
claude plugin install aws-cost-audit@10x
```

Ou comme skill : `npx skills add Aboudjem/aws-cost-audit-skill -g -a claude-code -y`.

### Codex

Installation testée.

```bash
npx skills add Aboudjem/aws-cost-audit-skill -g -a codex -y
```

### Cursor

Installation testée.

```bash
npx skills add Aboudjem/aws-cost-audit-skill -g -a cursor -y
```

### Gemini CLI

Installation testée.

```bash
npx skills add Aboudjem/aws-cost-audit-skill -g -a gemini-cli -y
```

### GitHub Copilot

Installation testée.

```bash
npx skills add Aboudjem/aws-cost-audit-skill -g -a github-copilot -y
```

### OpenCode

Installation testée.

```bash
npx skills add Aboudjem/aws-cost-audit-skill -g -a opencode -y
```

Seulement ce projet : retirez `-g`. Un autre agent : mettez son code après `-a`. Sans `-a`, l'installateur demande.

### Ce qu'il faut

1. L'[AWS CLI](https://aws.amazon.com/cli/) v2 avec un accès en lecture au compte, et `jq`.
2. Des droits en lecture seule : la politique gérée AWS `ReadOnlyAccess` plus la lecture de la facturation (`ce:Get*`, `pricing:GetProducts`).
3. Demandez ensuite à votre agent : `audit my AWS bill`. Il vérifie d'abord votre configuration et nomme ce qui manque.

### Compatible avec

| Agent | Commande d'installation (tous vos projets) | Installation testée |
| :-- | :-- | :-- |
| Claude Code (plugin) | `claude plugin install aws-cost-audit@10x` | 2026-11-17 |
| Claude Code (skill) | `npx skills add Aboudjem/aws-cost-audit-skill -g -a claude-code -y` | 2026-11-17 |
| Codex | `npx skills add Aboudjem/aws-cost-audit-skill -g -a codex -y` | 2026-11-17 |
| Cursor | `npx skills add Aboudjem/aws-cost-audit-skill -g -a cursor -y` | 2026-11-17 |
| Gemini CLI | `npx skills add Aboudjem/aws-cost-audit-skill -g -a gemini-cli -y` | 2026-11-17 |
| GitHub Copilot | `npx skills add Aboudjem/aws-cost-audit-skill -g -a github-copilot -y` | 2026-11-17 |
| OpenCode | `npx skills add Aboudjem/aws-cost-audit-skill -g -a opencode -y` | 2026-11-17 |

« Installation testée » signifie que l'installation a tourné et que `SKILL.md` est arrivé là où l'agent le lit.
La CI refait l'installation pour Claude Code, Codex et Cursor à chaque push.

Documentés, mais pas testés de bout en bout : Pi, Mistral Vibe, Trae, OpenClaw, Antigravity, Hermes, Cline et Kimi.
Leurs codes d'agent ont été acceptés par la CLI skills épinglée le 2026-11-17. Installez-les avec `install.sh`, depuis un clone :

```bash
git clone https://github.com/Aboudjem/aws-cost-audit-skill && cd aws-cost-audit-skill
./install.sh pi
```

Cela installe pour tout votre profil utilisateur. Ajoutez `--project` pour installer dans le dossier courant seulement.
Les chemins par éditeur sont dans [docs/editors.md](../docs/editors.md).

<details>
<summary>Copier le skill à la main</summary>

Le skill est un dossier de Markdown et de scripts shell. Copiez-le là où votre agent lit les skills :

```bash
git clone https://github.com/Aboudjem/aws-cost-audit-skill
mkdir -p ~/.claude/skills
cp -r aws-cost-audit-skill/skills/aws-cost-audit ~/.claude/skills/aws-cost-audit
```

Ce dépôt n'a pas de manifeste de marketplace propre. Pour le plugin, passez par la marketplace 10x ci-dessus.
</details>

## Comment ça marche

Il lit votre compte, chiffre chaque gaspillage trouvé et imprime d'abord un verdict. Rien ne change sans votre demande.

<p align="center">
  <img src="../assets/how-it-works.svg" alt="Comment ça marche : 1 lire vos coûts, 2 trouver le gaspillage dans chaque région activée, 3 un plan d'économies avec preuves" width="100%">
</p>

1. **Contrôle préalable.** `doctor.sh` vérifie l'AWS CLI, les identifiants, `jq`, la région et le dossier de sortie. Il ne change rien.
2. **Base de référence.** Cost Explorer donne vos dépenses par service, région et type d'usage. Les scripts comptent chaque requête et s'arrêtent à un plafond.
3. **Chasse.** Il vérifie chaque région activée pour trouver les ressources inactives, surdimensionnées ou oubliées. Les contrôles sont dans [la liste de chasse](../skills/aws-cost-audit/references/hunt-list.md).
4. **Prix.** Chaque prix vient d'AWS pendant l'audit, pas de la mémoire. C'est une recherche dans la Price List pour votre région, multipliée par votre usage réel.
   Pour les prix par paliers, c'est une lecture Cost Explorer. `verify-price.sh --record` enregistre la recherche dans le constat.
5. **Tri.** Chaque constat est KEEP, OPTIMIZE ou SAFE-TO-DELETE, avec un niveau de confiance et ses preuves.
6. **Rapport.** `findings-validate.sh` vérifie `findings.json`, puis `findings-summary.sh` imprime le verdict et les trois actions.

Le rapport complet montre ensuite ce que vous payez par service. Chaque constat a sa preuve et la façon de l'annuler.
Voir [`examples/sample-report.md`](../examples/sample-report.md) et le [tableau de bord HTML](../examples/sample-dashboard.html) optionnel.

### Pour qui

C'est pour les développeurs et les petites équipes sans expert des coûts (FinOps).
Cost Explorer montre le total. Il ne dit pas quoi arrêter. Ce skill, si.
Il trouve les disques inutilisés, les logs gardés pour toujours et les envois inachevés. Chaque constat montre sa preuve et s'il peut être annulé.

### Ce qu'il ne fait jamais tout seul

Trois scripts peuvent modifier quelque chose. Le code impose ces règles :

1. Sans `--apply`, ils font seulement une simulation. Une simulation enregistre un fichier de retour arrière en local et ne change rien dans votre compte.
2. Avec `--apply`, ils enregistrent d'abord un fichier de retour arrière, puis vous demandent de taper `yes`.
3. `--yes` saute cette question. Sans terminal pour demander et sans `--yes`, ils refusent avant tout changement.

`make test` vérifie cet ordre sur le script de suppression EBS.
Une économie qui n'est pas à la fois sûre (confiance élevée) et réversible demande d'abord l'accord du propriétaire (une validation).
Le skill demande à votre agent de vous montrer d'abord la preuve de non-utilisation et la simulation, puis d'attendre votre accord.
Il lui demande aussi de garder les actions impossibles à annuler, comme l'achat d'un Savings Plan, comme simples conseils.

Le skill lui-même est [`SKILL.md`](../skills/aws-cost-audit/SKILL.md) : cinq règles, les étapes, et des fichiers de référence chargés au besoin.

## Preuves

Chaque chiffre ci-dessous est réimprimé par la commande placée à côté.

| Affirmation                                | Commande                                                     | Résultat aujourd'hui                                                          |
| :----------------------------------------- | :----------------------------------------------------------- | :---------------------------------------------------------------------------- |
| La suite hors ligne passe                  | `make test`                                                  | `Results: 167 passed, 0 failed`                                                |
| L'exemple ci-dessus est la vraie sortie de l'outil | `make test` (le cas 39 les compare ligne à ligne)    | `[PASS] sample: the README sample report is the script output, line for line` |
| Le manifeste du plugin est valide          | `claude plugin validate . --strict`                          | `✔ Validation passed`                                                         |
| Aucun prix unitaire n'est écrit dans un script | `make test` (cas « no-hardcoded-price »)                 | `[PASS] no per-request price literal in any script`                           |
| Un constat chiffré exige sa fiche de recherche | `make test` (cas « price rule ») | `[PASS] price rule: a dollar figure with no price_lookups exits 1` |

La suite simule la commande `aws`, donc elle n'a besoin d'aucun identifiant et ne fait aucun appel AWS.
Elle vérifie aussi l'ordre de sécurité de `delete-unattached-ebs.sh` : aucun changement avant la confirmation.
La CI la lance à chaque push et pull request. La CI lance aussi shellcheck, une recherche de prix codés en dur et l'installation par la CLI skills.

Ce que les scripts peuvent appeler, et ce qu'ils n'envoient jamais ailleurs, est décrit dans [PRIVACY.md](../PRIVACY.md).

## FAQ

**Supprimera-t-il quelque chose tout seul ?**
Non. Il lit par défaut. Un script de modification ne tourne qu'avec `--apply`, enregistre un fichier de retour arrière, puis vous demande de taper `yes`.
`--yes` saute la question, et le skill demande à votre agent de ne le passer qu'après votre accord dans le chat.
Le skill demande à votre agent de montrer d'abord la preuve de non-utilisation et la simulation. Les actions impossibles à annuler restent de simples conseils.

**A-t-il besoin de mes clés AWS ?**
Non. Il utilise les identifiants de l'AWS CLI déjà présents sur votre machine. Vos données vont à AWS et à votre agent, nulle part ailleurs.

**Combien coûte un audit ?**
Cost Explorer facture chaque requête d'API. Les scripts comptent chaque page et s'arrêtent à `AWS_COST_AUDIT_CE_BUDGET`, 50 par défaut. Les recherches dans la Price List sont gratuites.

**Pourquoi se fier aux montants en dollars ?**
Chacun enregistre sa source : une recherche dans la Price List, ou la lecture Cost Explorer quand aucun prix unitaire unique ne s'applique.
`findings-validate.sh` rejette un montant sans source. Un montant impossible à vérifier est écrit « unknown » et reste hors de tous les totaux.

**Les chiffres de l'exemple sont-ils réels ?**
Non. Le rapport d'exemple, le tableau de bord et la démo utilisent un compte fictif. Rien n'y a été lu dans une vraie facture AWS.

**Puis-je comparer deux audits ?**
Oui. Demandez `findings.json`. `findings-validate.sh` le vérifie selon un contrat fixe, donc vous pouvez comparer deux exécutions ligne à ligne.

D'autres réponses sont dans [docs/faq.md](../docs/faq.md).

## Limites

- Il faut l'AWS CLI v2, bash et `jq`. Sous Windows, les scripts demandent un shell bash ; voir [docs/editors.md](../docs/editors.md).
- Activez d'abord Cost Explorer. AWS peut mettre jusqu'à 24 heures à afficher les données.
- Le skill guide votre agent. Un modèle plus faible peut encore sauter une étape, alors vérifiez les lignes de preuve.
- Les prix sont en USD, tels que AWS les renvoie.
- Le validateur vérifie la forme de chaque fiche de prix, pas qu'AWS l'ait renvoyée. `verify-price.sh --recheck findings.json` relance les recherches dans la Price List.
- Les prix par paliers, comme le stockage S3 Standard, et les Savings Plans n'ont pas de prix unitaire unique. Ces constats enregistrent une lecture Cost Explorer, que `--recheck` ne relance pas car chaque lecture est facturée.
- Un seul chiffre est stocké au lieu d'être récupéré : le coût des requêtes Cost Explorer de l'audit lui-même, dans `references/pricing-verification.md`.
- « Installation testée » dans le tableau des agents signifie que l'installation a tourné et que les fichiers sont arrivés. Cela ne veut pas dire qu'on a vu chaque agent charger le skill.
- La preuve de non-utilisation et la simulation avant un changement sont des étapes que le skill demande à votre agent. Les scripts imposent `--apply`, le fichier de retour arrière et le `yes`.

## En savoir plus

- [Démarrage rapide](../docs/quickstart.md) : des identifiants au tableau de bord, pas à pas.
- [Support des éditeurs et agents](../docs/editors.md) : une ligne par agent, plus la copie manuelle.
- [Comparaison](../docs/comparison.md) : face à un audit manuel et à un tableau de bord de coûts.
- [CHANGELOG](../CHANGELOG.md) · [CONTRIBUTING](../CONTRIBUTING.md) · [Confidentialité](../PRIVACY.md) · [Licence MIT](../LICENSE)

---

<sub>Créé et maintenu par <a href="https://github.com/Aboudjem">Adam Boudjemaa</a>. Une commande périmée ? <a href="https://github.com/Aboudjem/aws-cost-audit-skill/issues">Ouvrez une issue</a>.</sub>

<sub>Traduction assistée par machine. En cas de doute, le README anglais fait foi.</sub>
