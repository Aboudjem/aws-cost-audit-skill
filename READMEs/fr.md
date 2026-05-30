<p align="center">
  <img src="https://raw.githubusercontent.com/Aboudjem/aws-cost-audit-skill/main/assets/hero.svg" alt="AWS Cost Audit: an executable, evidence-first AWS cost auditor for Claude Code" width="100%">
</p>

<h1 align="center">AWS Cost Audit Skill</h1>

<p align="center">
  <strong>Demandez à Claude d'auditer votre facture AWS. Obtenez un plan d'économies clair où chaque chiffre est vérifié face aux tarifs AWS en direct, et où rien n'est supprimé sans votre accord.</strong>
</p>

<p align="center">
  <a href="../LICENSE"><img src="https://img.shields.io/badge/license-MIT-green.svg" alt="MIT license"></a>
  <img src="https://img.shields.io/badge/Claude%20Code-skill-d97757" alt="Claude Code skill">
  <img src="https://img.shields.io/badge/AWS-cost%20optimization-ff9900" alt="AWS cost optimization">
  <a href="../CONTRIBUTING.md"><img src="https://img.shields.io/badge/PRs-welcome-brightgreen.svg" alt="PRs welcome"></a>
  <a href="https://github.com/Aboudjem/10x"><img src="https://img.shields.io/badge/part%20of-10x%20marketplace-f59e0b" alt="Part of the 10x marketplace"></a>
</p>

<p align="center">
  Fait partie de la <a href="https://github.com/Aboudjem/10x">marketplace <b>10x</b></a>, un ensemble soigné d'outils Claude Code qui livrent de la qualité.
</p>

<p align="center">
  <a href="../README.md">English</a> · <a href="zh-CN.md">简体中文</a> · <a href="ja.md">日本語</a> · <a href="es.md">Español</a> · <b>Français</b>
</p>

---

![aws-cost-audit demo](https://raw.githubusercontent.com/Aboudjem/aws-cost-audit-skill/main/assets/demo.gif)

<p align="center"><sub>Demandez à Claude d'auditer votre facture, obtenez un plan d'économies fondé sur des preuves. Tous les chiffres affichés sont <b>illustratifs</b> (données synthétiques, aucun compte réel).</sub></p>

---

## Qu'est-ce que c'est ?

C'est une skill [Claude Code](https://www.claude.com/product/claude-code) qui audite votre compte AWS à votre place.

Vous demandez à Claude quelque chose comme *"audite ma facture AWS"*. La skill lit votre compte en direct, détermine ce que coûte chaque chose et pourquoi, trouve le gaspillage, et vous remet un rapport en langage clair : ce que vous payez aujourd'hui, ce que vous pouvez couper sans risque, et son degré de certitude pour chaque point. Elle est en lecture seule par défaut. Elle ne devine jamais un prix, et elle ne supprime jamais rien de sa propre initiative.

Voyez-la comme un ingénieur FinOps rigoureux qui montre son travail.

**Qu'est-ce qu'un audit de coûts AWS ?** C'est une revue structurée d'un compte AWS qui détermine ce que vous payez, quelles ressources sont gaspillées ou surdimensionnées, et ce que vous pouvez retirer sans risque. Cette skill exécute cet audit pour vous et suit le [pilier d'optimisation des coûts du AWS Well-Architected Framework](https://docs.aws.amazon.com/wellarchitected/latest/cost-optimization-pillar/welcome.html) et le cadre de la [FinOps Foundation](https://www.finops.org/framework/), pour que la méthode ne soit pas inventée.

## Installation

Choisissez celle que vous préférez. Les trois installent la même skill.

**Depuis la [marketplace 10x](https://github.com/Aboudjem/10x)** (recommandé, elle y est soignée aux côtés d'autres outils Claude Code) :

```text
/plugin marketplace add Aboudjem/10x
/plugin install aws-cost-audit@10x
```

**Directement depuis ce dépôt :**

```text
/plugin marketplace add Aboudjem/aws-cost-audit-skill
/plugin install aws-cost-audit@aws-cost-audit-skill
```

**Comme skill autonome** (sans système de plugin) :

```bash
git clone https://github.com/Aboudjem/aws-cost-audit-skill
cp -r aws-cost-audit-skill/skills/aws-cost-audit ~/.claude/skills/aws-cost-audit
```

Il vous faut aussi l'[AWS CLI](https://aws.amazon.com/cli/) configurée avec un accès en lecture au compte que vous voulez auditer. `ReadOnlyAccess` suffit pour l'audit lui-même.

### Autres CLI d'IA (en une ligne)

C'est un plugin de type skill uniquement (pas de serveur MCP). L'installeur crée un lien symbolique de la skill `aws-cost-audit` dans le répertoire de skills d'une autre CLI :

```bash
curl -fsSL https://raw.githubusercontent.com/Aboudjem/aws-cost-audit-skill/main/install.sh | bash -s <platform>
```

| Plateforme | Répertoire de skills | Style de lien |
|:--|:--|:--|
| gemini, codex, opencode, pi | `~/.agents/skills` | par skill |
| vscode, copilot | `~/.copilot/skills` | par skill |
| trae | `~/.trae/skills` | par skill |
| vibe | `~/.vibe/skills` | par skill |
| openclaw | `~/.openclaw/skills` | dossier |
| antigravity | `~/.gemini/antigravity/skills` | dossier |
| hermes, cline, kimi | `~/.<cli>/skills` | dossier |

Passez `all` pour lier vers toutes les plateformes ci-dessus. Utilisez `--update` pour relier la dernière version, `--uninstall` pour retirer les liens.

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
<summary>Autres éditeurs (manuel)</summary>

La skill est du Markdown simple plus des scripts shell. Copiez `skills/aws-cost-audit/SKILL.md` et le dossier `references/` dans un répertoire de contexte que votre éditeur lit, puis exécutez directement les scripts d'aide dans `skills/aws-cost-audit/scripts/`. Ils ne dépendent que de l'AWS CLI.
</details>

## Utilisez-la en 3 étapes

1. **Installez-la** (ci-dessus).
2. **Demandez à Claude** d'*"auditer ma facture AWS"* ou de *"trouver mes ressources AWS inutilisées"*. La skill s'active d'elle-même.
3. **Lisez le plan.** Vous obtenez un rapport, et un tableau de bord HTML optionnel, montrant le coût, la cause, et un niveau de confiance pour chaque économie.

C'est tout. Rien n'est modifié dans votre compte sans votre demande, et même alors seulement après une vérification de sécurité et votre confirmation.

<p align="center">
  <img src="https://raw.githubusercontent.com/Aboudjem/aws-cost-audit-skill/main/assets/how-it-works.svg" alt="How it works: 1 re-baseline live, 2 hunt waste across every region, 3 evidence-backed savings plan" width="100%">
</p>

## Ce que vous obtenez

<p align="center">
  <img src="https://raw.githubusercontent.com/Aboudjem/aws-cost-audit-skill/main/assets/dashboard-preview.png" alt="Sample AWS cost audit dashboard: monthly run-rate, save-now-safely vs maximum-theoretical-save, with synthetic data" width="100%">
  <br><sub>Le tableau de bord optionnel (exemple montré, données synthétiques). Ouvrez <a href="../examples/sample-dashboard.html"><code>examples/sample-dashboard.html</code></a> pour le voir en direct.</sub>
</p>

- **Une ventilation des dépenses.** Ce que vous payez aujourd'hui, par service et par région, tiré en direct de Cost Explorer.
- **Une vue par ressource.** Pour chaque ressource : ce qu'elle coûte, ce qu'elle fait en mots simples, qui l'a créée, quand, et quand elle a été utilisée pour la dernière fois. Si un fait ne peut pas être vérifié, elle le dit au lieu de deviner.
- **Un plan d'économies en deux parties.** "Économiser maintenant sans risque" (forte confiance, réversible, faible risque) gardé séparé de "économie théorique maximale" (les coupes plus importantes qui exigent votre accord).
- **Un tableau de bord optionnel.** Une seule page HTML autonome qu'une personne non technique peut lire. Voir [`examples/sample-dashboard.html`](../examples/sample-dashboard.html) et un [exemple de rapport](../examples/sample-report.md).
- **Des garde-fous.** Elle vérifie si vous avez des budgets et des alertes d'anomalies de coûts, et vous aide à les configurer.

## À quoi ressemble une exécution

L'enregistrement ci-dessus (`assets/demo.gif`) est illustratif : il utilise des données synthétiques, pas un compte réel, car les appels AWS exigent des identifiants en direct (voir la note sur les éléments différés dans [CONTRIBUTING.md](../CONTRIBUTING.md)). Voici ce qui se passe étape par étape, reflété dans l'[exemple de rapport](../examples/sample-report.md) et le [tableau de bord d'exemple](../examples/sample-dashboard.html) (les deux utilisent des données synthétiques, clairement étiquetées) :

1. **Vérification d'identité.** `aws sts get-caller-identity` confirme le compte et la région avant tout le reste.
2. **Base de référence des dépenses.** Cost Explorer (`aws ce get-cost-and-usage`) tire les dépenses des 30 et 90 derniers jours, ventilées par service et par région. Vous voyez un tableau : service → $/mois → part du total.
3. **Inventaire des ressources.** La skill se déploie sur chaque région activée, listant les instances EC2, les volumes EBS, les instances RDS, les NAT Gateways, les load balancers, les buckets S3, les fonctions Lambda, les groupes de logs CloudWatch, les snapshots, les AMI, les Elastic IP, et plus. Rien n'est modifié.
4. **Détection du gaspillage.** Chaque ressource est confrontée à la liste de chasse (`skills/aws-cost-audit/references/hunt-list.md`) : CPU inactif, volumes non attachés, vieux snapshots, volumes gp2, logs trop conservés, couverture Savings Plan manquante, etc.
5. **Vérification des prix en direct.** Pour chaque économie candidate, la skill récupère le prix unitaire en direct, spécifique à la région, depuis l'AWS Price List Query API, sans tarif mémorisé. Elle montre `unit price → math → source` pour chaque chiffre en dollars.
6. **Rapport fondé sur des preuves.** Les constats sont écrits sous la forme `current $/mo → after $/mo → $ saved · confidence · evidence · reversibility`, séparés en "économiser maintenant sans risque" (forte confiance, réversible, testé) et "économie théorique maximale". Voir [`examples/sample-report.md`](../examples/sample-report.md) pour la forme exacte.
7. **Tableau de bord optionnel.** Un fichier HTML est généré à partir des constats, ouvrez-le dans n'importe quel navigateur. Voir [`examples/sample-dashboard.html`](../examples/sample-dashboard.html).

Une exécution réelle sur un compte AWS de taille moyenne fait généralement remonter des constats dans les quelques minutes suivant le premier appel à Cost Explorer. La phase en lecture seule s'achève avant toute suggestion de remédiation.

## Pourquoi vous pouvez faire confiance aux chiffres

La plupart des conseils pour "réduire votre facture AWS" sont génériques, ou bien c'est un outil qui cite un prix de mémoire. Cette skill est bâtie autour de cinq règles qu'elle ne transgressera pas :

1. **Aucun prix inventé.** Chaque dollar provient du prix AWS en direct pour *votre* région plus votre usage *réel*. Elle montre le prix unitaire, le calcul, et la source. Elle ne code en dur aucun prix nulle part.
2. **Attribuer chaque dollar, ou dire "inconnu".** Elle n'invente jamais un propriétaire, une date, ou une "dernière utilisation".
3. **Rien de destructif sans preuve.** Une modification ne s'exécute que si la ressource est prouvée inutilisée, l'action est réversible, elle a passé un essai à blanc, et le résultat est certain. Sinon elle reste une recommandation.
4. **Un échantillon n'est jamais toute la flotte.** Une passe sceptique séparée redérive les chiffres principaux depuis la source avant qu'ils ne soient publiés.
5. **Chaque constat montre sa preuve.** Coût actuel, coût après, dollars économisés, un niveau de confiance, la preuve, et comment l'annuler.

Ces règles existent parce que nous avons vu des agents *sans* la skill les transgresser. La base de référence enregistrée est dans [`docs/research/RED-baseline-findings.md`](../docs/research/RED-baseline-findings.md) : interrogés sur le même chiffre d'économies, deux modèles ont retourné avec aplomb deux chiffres erronés différents, de mémoire. La skill corrige cela.

## Comment elle se compare

| | Cette skill | Un audit manuel | Un tableau de bord SaaS de coûts |
|---|---|---|---|
| S'exécute sur votre compte en direct | Oui | Oui | Oui |
| Vous pouvez l'exécuter tout de suite, gratuitement | Oui | Oui | Généralement payant / par siège |
| Vérifie chaque prix en direct (pas de tarif mémorisé) | Oui | Dépend de la personne | Montre ses propres chiffres |
| Attribue coût, propriétaire, et dernière utilisation par ressource | Oui | Lent, à la main | Partiel |
| Peut agir sur les constats sans risque (encadré + réversible) | Oui | Manuel | Lecture seule |
| Génère un rapport + tableau de bord partageables | Oui | Manuel | Oui |
| Envoie vos données à un tiers | Non | Non | Souvent |
| Verrouillage | Aucun (MIT, votre compte) | Aucun | Fournisseur |

## FAQ

**Comment auditer ma facture AWS avec Claude ?**
Installez cette skill, puis demandez à Claude Code d'"auditer ma facture AWS". Elle lit votre compte avec l'AWS CLI et produit un rapport de coûts et un plan d'économies fondés sur des preuves.

**Est-ce sûr ? Va-t-elle supprimer quelque chose ?**
Elle est en lecture seule par défaut. Elle ne supprimera, n'arrêtera, ni ne modifiera rien de sa propre initiative. Toute action est encadrée : la ressource doit être prouvée inutilisée, la modification doit être réversible, elle doit passer un essai à blanc, et vous devez confirmer. Les actions irréversibles restent toujours des recommandations.

**A-t-elle besoin de mes clés AWS ?**
Non. Elle utilise vos identifiants AWS CLI existants sur votre propre machine. Rien n'est téléversé nulle part. `ReadOnlyAccess` suffit pour l'audit.

**Fonctionne-t-elle sur mon compte ?**
Oui. Elle est générique. Elle lit le compte vers lequel votre CLI pointe, sur toutes les régions, et est livrée sans aucun ID de compte, ARN, ou prix codé en dur.

**Code-t-elle en dur les prix AWS ?**
Non, volontairement. Les prix changent et varient selon la région, donc elle récupère toujours le prix en direct pour votre région et le combine avec votre usage réel.

**Que couvre-t-elle ?**
Ressources inactives et non attachées, gp2→gp3, vieux snapshots et AMI, coûts de NAT et de transfert de données, load balancers inactifs, rightsizing, couverture Savings Plans et Reserved Instances, cycle de vie S3, rétention des logs CloudWatch, restes inter-régions, et budgets/alertes manquants. La liste complète est dans [la liste de chasse](../skills/aws-cost-audit/references/hunt-list.md).

**Puis-je l'utiliser sans le système de plugin ?**
Oui. Copiez `skills/aws-cost-audit/` dans `~/.claude/skills/aws-cost-audit/` et elle fonctionne de la même façon.

## Comment elle fonctionne en interne

La skill est dans [`skills/aws-cost-audit/SKILL.md`](../skills/aws-cost-audit/SKILL.md). Les détails plus lourds ne sont chargés qu'au besoin, depuis `references/` :

- [`hunt-list.md`](../skills/aws-cost-audit/references/hunt-list.md) : chaque vérification à fort ROI, avec la commande en lecture seule pour la détecter.
- [`pricing-verification.md`](../skills/aws-cost-audit/references/pricing-verification.md) : comment elle tire un prix en direct, correct selon la région, et le revérifie.
- [`safety-and-gating.md`](../skills/aws-cost-audit/references/safety-and-gating.md) : le verrou executor → verifier → rollback, et ce qui ne peut jamais s'exécuter seul.
- [`output-and-reporting.md`](../skills/aws-cost-audit/references/output-and-reporting.md) : la forme du rapport et le contrat par constat.

Les scripts d'aide dans [`scripts/`](../skills/aws-cost-audit/scripts) sont en essai à blanc par défaut. Voir le [guide de démarrage](../docs/quickstart.md) pour une première exécution guidée.

## Prise en charge des éditeurs

Cette skill est conçue pour **Claude Code**. Elle fonctionne en chargeant `SKILL.md` dans le contexte de Claude Code et en appelant l'AWS CLI, donc elle requiert Claude Code comme runtime.

Les autres éditeurs d'IA (Cursor, VS Code avec Copilot, Windsurf, Codex, Gemini CLI) n'utilisent pas nativement le format de plugin ou de skill de Claude Code. Si vous utilisez l'un de ces éditeurs, la voie la plus pratique est :

1. Installez l'AWS CLI et configurez vos identifiants normalement.
2. Copiez `skills/aws-cost-audit/SKILL.md` et le dossier `references/` dans votre projet (ou un répertoire de contexte personnel que votre éditeur lit).
3. Pointez votre éditeur vers le contenu de SKILL.md comme prompt système ou instruction personnalisée.
4. Exécutez directement les scripts d'aide dans `skills/aws-cost-audit/scripts/`. Ce sont de simples scripts shell qui ne dépendent que de l'AWS CLI, pas de Claude Code.

La logique de la skill (Iron Laws, workflow, garde-fous de sécurité) est entièrement portable. Seul le *mécanisme d'installation* (système de plugin, auto-découverte `/skill`) est spécifique à Claude Code.

## Contribuer

Les issues et les PR sont les bienvenues. La seule règle ferme : cette skill est bâtie en test-first, donc une modification qui ajoute un comportement a besoin de la base de référence en échec qu'elle corrige. Voir [CONTRIBUTING.md](../CONTRIBUTING.md) et le [Code de conduite](../CODE_OF_CONDUCT.md).

## Star History

<a href="https://star-history.com/#Aboudjem/aws-cost-audit-skill&Date">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=Aboudjem/aws-cost-audit-skill&type=Date&theme=dark">
    <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=Aboudjem/aws-cost-audit-skill&type=Date">
    <img alt="Star history of Aboudjem/aws-cost-audit-skill" src="https://api.star-history.com/svg?repos=Aboudjem/aws-cost-audit-skill&type=Date">
  </picture>
</a>

## Licence

[MIT](../LICENSE). Utilisez-la, forkez-la, livrez-la.

---

<sub>Créée et maintenue par <a href="https://github.com/Aboudjem">Adam Boudjemaa</a>. Commandes vérifiées face à l'AWS CLI v2 et la documentation AWS en 2026. Vous repérez une commande obsolète ou une lacune ? <a href="https://github.com/Aboudjem/aws-cost-audit-skill/issues">Ouvrez une issue</a>.</sub>

---

<sub>Traduction assistée par machine. Une correction par un locuteur natif est la bienvenue : <a href="https://github.com/Aboudjem/aws-cost-audit-skill/issues">ouvrez une issue</a> ou une PR.</sub>
