# GitHub Repository Discoverability / SEO (2025–2026)

Research note for shipping a generic, reference-grade "AWS cost audit" Claude Code skill as a public GitHub repo.

- **Access date:** 2026-05-28
- **Scope:** repo naming, About/description, topics/tags, README structure (rank + convert), social preview image.
- **Discipline:** Every load-bearing claim is cited. Items that could NOT be confirmed from a primary/authoritative source are labeled **UNVERIFIED** and collected in the Uncertainties section. No specific AWS dollar prices are stated.

---

## 0. TL;DR: Concrete recommendations for THIS repo

These are synthesized recommendations; the authoritative limits behind them are cited in the sections below.

- **Repo name (keyword-first, hyphenated):** `aws-cost-audit` (primary), or `aws-cost-audit-skill` / `claude-aws-cost-audit` if the bare name is taken. Hyphenated, lowercase, 3–5 words, keyword leads. (See §1.)
- **About / description:** Lead with the primary keyword, keep it concise. Example draft: "AWS cost audit skill for Claude Code, finds idle resources, unattached EBS/EIPs, and savings opportunities, read-only." Aim well under GitHub's display length (the GitHub-doc-backed hard fact is the topics limit, not a description char limit, see §2 caveat).
- **Topics (6–20, lowercase/hyphen, ≤50 chars each):** see the curated list in §3 and `recommendedTopics`.
- **README H1:** `# AWS Cost Audit` (or `# aws-cost-audit`), keyword in the H1; proper H1→H2→H3 hierarchy below it. (See §4.)
- **Social preview image:** export at **1280 × 640 px** PNG (GitHub's "best display" size), under 1 MB. (See §5, this is the single most authoritative hard fact in this note.)

---

## 1. Repository naming (keyword-first, hyphenated)

**Authoritative / hard facts (GitHub):** GitHub's own docs do not impose SEO naming rules, but the *topics* rules (lowercase, hyphens, ≤50 chars) reflect GitHub's general slug convention and are the closest primary signal (see §3).

**Dev-marketing consensus (2025–2026):**
- The repo name functions like an HTML title tag for search; it should be **descriptive, keyword-rich, concise, and memorable**, "say what the repo is about in 3–5 words max." [DEV "Ultimate Guide to GitHub SEO for 2025"], [GitDevTool GitHub SEO]
- **Use hyphens to separate words** for readability (e.g., `react-component-library`, `markdown-editor` not `my-cool-project`). [DEV GitHub SEO Guide]
- **Self-descriptive names outrank vague ones:** `react-calendar` ranks higher than `my-widget`; `ai-chatbot-framework` reportedly ranks #1 for "chatbot framework." [DEV GitHub SEO Guide], [Nakora GitHub SEO]
- **Put the target keyword in the name, the About, and the README**, keyword placement across all three is repeatedly cited as the core tactic. [DEV GitHub SEO Guide], [GitDevTool]
- Branded names can still work if you compensate elsewhere (About + topics + README carry the keywords). [Nakora GitHub SEO]

**Applied:** For an AWS cost-audit Claude skill the strongest keyword cluster is "aws cost" + "audit". `aws-cost-audit` leads with the exact phrase users search. Fallbacks keep the keyword first and append a disambiguator (`-skill`, or prefix `claude-`).

---

## 2. The About / description

**Authoritative (GitHub):** The repository **About** sidebar is edited via the **gear (⚙️) icon** on the repo main page; it holds a **Description** (short summary of what the project does), an optional **Website** URL, and **Topics**. ["How to update Description", GitHub community discussions]. GitHub Docs confirm topics are added/managed from the About area ("classifying your repository with topics"). [GitHub Docs, Topics]

> **Caveat:** GitHub's public docs (as surveyed) state a hard character limit for *topics* (≤50 chars each) but I did **not** find an official GitHub-doc-stated maximum character count for the *About description* field. The description-length numbers below come from dev-marketing sources, not GitHub primary docs, treat as guidance, not spec. (See Uncertainties.)

**Dev-marketing consensus (2025–2026):**
- **Lead with the primary keyword and stay concise.** [DEV GitHub SEO], [Nakora]
- Suggested lengths vary by source:
  - DEV guide: "between 5 to 15 words is ideal." [DEV GitHub SEO]
  - Nakora: "Less than 120 characters is ideal; 120–250 is acceptable; over 250 is too long." [Nakora]
- The description should answer **What is it? / Who's it for? / What's different?** Good real-world examples cited: tailwindcss ("A utility-first CSS framework for rapid UI development"), rendercv ("CV/resume generator for academics and engineers, YAML to PDF"). [Nakora]
- GitDevTool claims GitHub uses the repo name as the search **title** and the About as the **meta description**, and that the description is "heavily weighted by GitHub's search algorithm." [GitDevTool], **plausible but vendor-unconfirmed**; labeled UNVERIFIED.

**Applied draft About:** "AWS cost audit skill for Claude Code: read-only review that flags idle resources, unattached EBS volumes/EIPs, oversized instances, and savings opportunities." (Keyword "AWS cost audit" first; states what + who + what's different = read-only.)

---

## 3. Topics / tags

**Authoritative (GitHub Docs, "Classifying your repository with topics"):**
- **"Add no more than 20 topics."** (max 20) [GitHub Docs, Topics]
- **"Use 50 characters or less"** per topic. [GitHub Docs, Topics]
- **"Use lowercase letters, numbers, and hyphens."** [GitHub Docs, Topics]
- Topics should classify "the repository's intended purpose, subject area, community, or language." [GitHub Docs, Topics]
- GitHub **auto-suggests topics** by analyzing *public* repo content (admins accept/decline); private repos get no suggestions. [GitHub Docs, Topics]
- A curated set of **featured topics** lives in the `github/explore` repo. [GitHub Docs, Topics]

**Dev-marketing consensus on count + mix (2025–2026):**
- Use **at least ~6 topics (max 20)**; blend three semantic categories: **purpose**, **tech stack**, and **industry/domain**. [Nakora]
- Avoid bare **programming-language tags** (GitHub auto-detects/filters language) and junk tags like "beta-feature" / "draft." [Nakora]
- A simpler framing also seen: tech tags + category tags + community tags (e.g., `hacktoberfest`), ~10–20 total. [GitDevTool]

**Recommended concrete tag set for an "AWS cost audit Claude skill"** (all lowercase, hyphenated, ≤50 chars, ≤20 total, these satisfy GitHub's hard rules):

```
aws
aws-cost-optimization
cost-optimization
finops
cloud-cost-management
aws-cost-explorer
cost-management
claude
claude-code
claude-skill
anthropic
ai-agent
devops
cloud
infrastructure
audit
```

Rationale by category:
- **Purpose/domain:** `aws-cost-optimization`, `cost-optimization`, `cost-management`, `cloud-cost-management`, `finops`, `audit`.
- **Tech/ecosystem:** `aws`, `aws-cost-explorer`, `cloud`, `infrastructure`, `devops`.
- **Community/platform:** `claude`, `claude-code`, `claude-skill`, `anthropic`, `ai-agent`.

> Note: `finops` and `aws-cost-optimization` are well-established discovery terms; confirm against GitHub's live topic dropdown/suggestions at publish time so you ride existing high-traffic topic pages rather than minting orphan slugs. (GitHub's dropdown surfaces matching existing topics. [GitHub Docs, Topics])

---

## 4. README structure that ranks on Google AND converts

GitHub READMEs are indexed by Google, so the README doubles as the project's landing page. [Readmecodegen beginner-friendly guide]

### 4a. SEO / ranking elements (mostly dev-marketing consensus)
- **H1 contains the primary keyword;** maintain proper heading hierarchy **H1 → H2 → H3** so crawlers parse structure. [Nakora], [GitDevTool]
- **Put the target keyword naturally in the first paragraph / opening line.** Good: "A fast, lightweight markdown editor for React with live preview…"; bad: "My markdown project." [GitDevTool]
- Reinforce keyword placement across **name + About + README** (the recurring three-spot rule). [DEV GitHub SEO]
- **Keep the repo active / docs fresh**, regular updates signal trustworthiness to users and (claimed) ranking. [Nakora]

### 4b. Conversion elements (treat README as a landing page)
Recurring high-converting sections from awesome-readme exemplars + GitHub SEO guides:
- **H1 + one-line value proposition** (logo/banner optional). [matiassingers/awesome-readme], [Readmecodegen]
- **Badges** (build status, version, license, etc.), make the project look professional/maintained. [Readmecodegen beginner README guide], [Naereen/badges]
- **TL;DR / short summary** of what it does, who it's for, why it exists, near the top. [Readmecodegen]
- **One-line / copy-paste install** + usage code snippets (reduce friction). [GitDevTool], [Nakora]
- **Screenshots / demo GIF** for instant comprehension. [matiassingers/awesome-readme], [GitDevTool]
- **Table of contents** for longer READMEs. [Readmecodegen], [matiassingers/awesome-readme]
- **Contributing + License** sections (signal active, safe-to-adopt project). [GitDevTool]

### 4c. FAQ, comparison table, "why trust it" (landing-page / CRO evidence)
These come from general landing-page CRO research (not GitHub-specific), applied to the README-as-landing-page model:
- **FAQs and feature comparison tables are standard landing-page/comparison-page elements.** [FormAssembly converting landing pages]
- **Social proof ("why trust it") is the 2nd-most-tested landing-page element after the hero**, with measured lifts ~+5% to +22%; **specific** claims beat vague ones ("Trusted by 8 of the Fortune 50" > "trusted by thousands"). Generic "trusted by thousands" now performs ~like no social proof. [LanderLab social proof], [LanderLab 2026 landing-page study]
- **Specificity over generic claims**: named/specific proof converts; vagueness "decorates." [LanderLab]

**Applied README skeleton for the AWS cost audit skill:**
1. `# AWS Cost Audit` (H1, keyword) + one-line value prop ("A read-only Claude Code skill that audits an AWS account for cost savings.")
2. Badge row (license, version, "works with Claude Code", read-only/safe).
3. TL;DR (3–4 lines: what it finds, who it's for, why read-only matters).
4. One-line install (drop-in path or plugin add command).
5. Demo GIF / screenshot of an example audit run.
6. "What it checks" (idle/unattached resources, etc.), keyword-rich H2s.
7. Comparison table (vs. manual Cost Explorer review / vs. raw CLI), **claims must be defensible, no invented numbers**.
8. FAQ (Is it safe? Does it change anything? What permissions? Which services?).
9. "Why trust it", specific, verifiable proof (read-only by design, open source, what IAM actions it uses) rather than vague trust claims.
10. Contributing + License + Topics-aligned keywords in headings.

---

## 5. Social preview image (hard facts: GitHub official)

From **GitHub Docs, "Customizing your repository's social media preview"** (primary source):
- **Recommended size:** "**at least 640 by 320 pixels (1280 by 640 pixels for best display)**." → Export at **1280 × 640 px**. [GitHub Docs, Social media preview]
- **File:** "PNG, JPG, or GIF file **under 1 MB**." [GitHub Docs, Social media preview]
- **How GitHub uses it:** when someone shares the repo link on social media, GitHub shows this image; **without one, links expand to basic repo info + the owner's avatar.** [GitHub Docs, Social media preview]
- **Where to set it:** repo **Settings → "Social preview" → Edit → Upload an image.** [GitHub Docs, Social media preview]
- GitHub supports **PNG transparency**, useful because many chat platforms have dark mode. [GitHub Docs, Social media preview]

**General Open Graph context (for non-GitHub platforms, secondary):** the widely-cited OG image size is **1200 × 630 px** (1.91:1), min 600 × 315. Note this differs from GitHub's 1280 × 640 (2:1), **GitHub renders its own preview from the uploaded image at GitHub's spec**, so size to **1280 × 640** for GitHub specifically. [freeimages OG image size 2026], [GitHub Docs, Social media preview]

**Applied:** 1280 × 640 PNG, < 1 MB; put the repo name + keyword phrase ("AWS Cost Audit") and a short value prop in large readable type; keep critical text within a center-safe area since some platforms crop toward ~1.91:1.

---

## Sources

(All accessed 2026-05-28.)

**Primary / authoritative (GitHub):**
- GitHub Docs, Classifying your repository with topics: https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/classifying-your-repository-with-topics
- GitHub Docs, Customizing your repository's social media preview: https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/customizing-your-repositorys-social-media-preview
- GitHub Docs, Best practices for repositories: https://docs.github.com/en/repositories/creating-and-managing-repositories/best-practices-for-repositories
- GitHub community discussion, How to update repository Description (About sidebar / gear icon): https://github.com/orgs/community/discussions/54372

**Dev-marketing / SEO (secondary, 2025–2026):**
- DEV Community, The Ultimate Guide to GitHub SEO for 2025: https://dev.to/infrasity-learning/the-ultimate-guide-to-github-seo-for-2025-38kl
- GitDevTool, GitHub SEO Guide 2025: https://www.gitdevtool.com/blog/github-seo
- Nakora, GitHub SEO: Rank your repo and get adoption in 2026: https://nakora.ai/blog/github-seo

**README structure / examples (secondary):**
- matiassingers/awesome-readme (curated best READMEs): https://github.com/matiassingers/awesome-readme
- Readmecodegen, Beginner-Friendly README guide (2025): https://www.readmecodegen.com/blog/beginner-friendly-readme-guide-open-source-projects
- Naereen/badges (README badge reference): https://github.com/Naereen/badges

**Open Graph / social preview (secondary):**
- freeimages, Open Graph Image Size 2026: https://blog.freeimages.com/post/open-graph-image-size-2026-best-dimensions-for-perfect-social-previews

**Landing-page CRO (for README-as-landing-page, secondary):**
- FormAssembly, 20 High-Converting Landing Page Examples: https://www.formassembly.com/blog/20-converting-landing-pages/
- LanderLab, Social Proof Examples: https://landerlab.io/blog/social-proof-examples
- LanderLab, Landing Page Conversion: 2,000 Pages Tested (2026): https://landerlab.io/blog/landing-page-conversion-rate

---

## UNVERIFIED / could not confirm from primary source
- Exact maximum character count for the GitHub **About description** field, not found in GitHub primary docs; the 120-char / 5–15-word figures are dev-marketing guidance only.
- Claim that GitHub uses repo name as the Google **title tag** and About as the **meta description**, and that the description is "heavily weighted by GitHub's search algorithm", asserted by GitDevTool/DEV, not confirmed by GitHub docs.
- That specific topics measurably improve **Google** (vs. GitHub-internal) ranking, claimed by SEO guides, not vendor-confirmed.
- Specific keyword-ranking anecdotes (`ai-chatbot-framework` "#1 for chatbot framework", `react-calendar` outranking `my-widget`), illustrative claims from secondary blogs, not independently verified.
