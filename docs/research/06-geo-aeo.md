# Research Note 06 — GEO / AEO + llms.txt and AGENTS.md conventions

> Scope: How to make a public skill repo (an "AWS cost audit" Claude Code skill) discoverable
> and citable by AI answer engines (ChatGPT, Claude, Perplexity, Google AI Overviews), and how
> to author the two machine-facing convention files — `llms.txt` and `AGENTS.md`.
> Access date for all sources below: **2026-05-28**.

DISCIPLINE NOTE: Every load-bearing claim is cited inline. Where a claim could not be verified
from a primary/authoritative source it is labelled **UNVERIFIED** and repeated in the
Uncertainties section. No specific dollar prices are asserted anywhere in this note.

---

## 1. llms.txt — the proposal, exact format, and current adoption reality

### 1.1 What it is and where it came from

`llms.txt` is a proposal by **Jeremy Howard / Answer.AI**, published **3 September 2024**, to add a
single Markdown file at the root path `/llms.txt` that gives LLMs a curated, concise index of a
site's most useful content. The spec is maintained at **llmstxt.org**. It is loosely analogous to
`robots.txt` / `sitemap.xml` but is aimed at LLM retrieval/inference pipelines rather than search
crawlers, and it *recommends priority* content rather than granting or denying access.
([Answer.AI proposal](https://www.answer.ai/posts/2024-09-03-llmstxt.html); [llmstxt.org](https://llmstxt.org/))

The rationale: at inference time a model has a limited context window, and naively crawling a whole
sitemap and stuffing every page in is wasteful and ambiguous. Site authors "know best" which clean,
structured resources to surface, so they curate them in one file.
([Answer.AI proposal](https://www.answer.ai/posts/2024-09-03-llmstxt.html))

Markdown — not XML/JSON — is used deliberately "because we expect many of these files to be read by
language models and agents," while the strict structure still allows standard programmatic parsing.
([llmstxt.org](https://llmstxt.org/))

### 1.2 Exact file format (verbatim from the spec)

The file MUST contain the following, **in this order** (only the H1 is strictly required):

1. **H1** — the name of the project or site. *"This is the only required section."*
2. **Blockquote** — a short summary of the project, "containing key information necessary for
   understanding the rest of the file."
3. **Zero or more Markdown sections** (paragraphs, lists, etc.) of **any type except headings**,
   giving more detail about the project and how to interpret the linked files.
4. **Zero or more H2-delimited sections** ("file lists") containing lists of links to further detail.
   Each link uses the format: `- [name](url): optional notes`.
5. A special **`## Optional`** section: URLs there "can be skipped if a shorter context is needed."
([llmstxt.org](https://llmstxt.org/); [Answer.AI proposal](https://www.answer.ai/posts/2024-09-03-llmstxt.html))

Canonical skeleton (from the proposal, verbatim shape):

```markdown
# Title

> Optional description goes here

Optional details go here

## Section name

- [Link title](https://link_url): Optional link details

## Optional

- [Skippable link](https://link_url): Lower-priority, drop if context is tight
```
([Answer.AI proposal](https://www.answer.ai/posts/2024-09-03-llmstxt.html))

### 1.3 Companion conventions

- **Clean Markdown versions of pages.** Provide a Markdown version of each HTML page at the same URL
  with `.md` appended (e.g. `page.html` → `page.html.md`). This gives LLMs boilerplate-free content.
  ([Answer.AI proposal](https://www.answer.ai/posts/2024-09-03-llmstxt.html))
- **Expanded context files.** Tooling can expand `llms.txt` into context files: `llms-ctx.txt`
  (the linked content, excluding `## Optional`) and `llms-ctx-full.txt` (including optional links).
  ([llmstxt.org](https://llmstxt.org/))
- Note: a commonly-referenced sibling file **`llms-full.txt`** (a single file inlining all docs) is
  **widely used by docs platforms in practice but is NOT part of the llmstxt.org spec** as written;
  the spec's own expanded-context filenames are `llms-ctx.txt` / `llms-ctx-full.txt`. Treat
  `llms-full.txt` as a community convention. **UNVERIFIED** against the primary spec text.

### 1.4 Adoption reality — important caveat for our repo

As of 2025–2026, **no major AI lab (OpenAI, Google, Anthropic, Meta, Mistral) has publicly
committed to reading or acting on `llms.txt` in production.**
([Search Engine Land](https://searchengineland.com/does-llms-txt-matter-467740);
[Longato 2025 crawler audit](https://www.longato.ch/llms-recommendation-2025-august/))

- Google's **John Mueller** stated in 2025 that no Google Search system reads or acts on `llms.txt`,
  comparing it to the deprecated keywords meta tag (a self-declaration that engines must re-verify
  anyway). ([Longato audit](https://www.longato.ch/llms-recommendation-2025-august/);
  [Semrush](https://www.semrush.com/blog/llms-txt/))
- Crawler-log audits show `llms.txt` receives a negligible share of AI-bot traffic (one 90-day audit:
  84 of ~62,100 AI bot visits, ~0.1%). ([Longato audit](https://www.longato.ch/llms-recommendation-2025-august/))
- A 10-site tracking study found no measurable citation lift attributable to `llms.txt`.
  ([Search Engine Land](https://searchengineland.com/does-llms-txt-matter-467740))

**Recommendation for the skill repo:** include a small, spec-correct `llms.txt` because it is cheap,
harmless, and well-formed (and some doc-aware agents/tools do consume it), but do **not** rely on it
for AI visibility. The real GEO/AEO wins come from on-page structure (Section 3) and the README.
The figures above are third-party measurements, not vendor statements — treat them as directional.

---

## 2. AGENTS.md — what to put in it for a skill repo

### 2.1 What it is

`AGENTS.md` is "a simple, open format for guiding coding agents" — a "README for agents": a
dedicated, predictable place for the context and instructions an AI coding agent needs to work on a
project. It complements `README.md` (which is for humans) by holding build steps, tests, and
conventions that would clutter a README. ([agents.md](https://agents.md/))

It is **plain standard Markdown with no required fields**: *"AGENTS.md is just standard Markdown. Use
any headings you like; the agent simply parses the text you provide."* ([agents.md FAQ](https://agents.md/))

### 2.2 Recommended sections (all optional; pick what carries real content)

Commonly recommended content blocks: **Project overview; Build and test commands; Code style
guidelines; Testing instructions; Security considerations**; plus commit/PR guidelines, deployment
steps, and large-dataset/external-service notes. ([agents.md](https://agents.md/))

Verbatim example blocks shown on the official site / repo:

```markdown
## Dev environment tips
- Use `pnpm dlx turbo run where <project_name>` to jump to a package instead of scanning with ls.
- Run `pnpm install --filter <project_name>` to add the package to your workspace ...

## Testing instructions
- Find the CI plan in the .github/workflows folder.
- Run `pnpm turbo run test --filter <project_name>` ...
- From the package root you can just call `pnpm test`. ...
- Fix any test or type errors until the whole suite is green.

## PR instructions
- Title format: [<project_name>] <Title>
- Always run `pnpm lint` and `pnpm test` before committing.
```
([agents.md GitHub README](https://github.com/agentsmd/agents.md))

### 2.3 Resolution and coexistence rules (from the FAQ)

- **Nearest file wins.** *"The closest AGENTS.md to the edited file wins; explicit user chat prompts
  override everything."* Monorepos can ship nested per-package `AGENTS.md` files for tailored
  instructions. ([agents.md FAQ](https://agents.md/))
- **Relation to README.** *"README.md files are for humans...; AGENTS.md complements this by
  containing the extra, sometimes detailed context coding agents need."* ([agents.md FAQ](https://agents.md/))
- **Existing files (e.g. CLAUDE.md, .cursorrules).** Migration guidance: rename existing files to
  `AGENTS.md` and create **symbolic links** for backward compatibility. ([agents.md FAQ](https://agents.md/))
- **Adoption.** The site lists 20+ supporting tools (OpenAI Codex, Google Jules, Cursor, VS Code,
  Devin, etc.) and reports tens of thousands of open-source projects using the format. ([agents.md](https://agents.md/))
  (Exact tool/project counts are vendor-reported and shift over time — see Uncertainties.)

**Recommendation for the skill repo:** ship a root `AGENTS.md` with: a 1-line project summary;
exact lint/test/validate commands for the skill; the skill's directory layout and where
`SKILL.md`/scripts live; "done" criteria the agent can verify; and commit conventions. If a
`CLAUDE.md` already exists, keep it and symlink `AGENTS.md → CLAUDE.md` (or vice versa) so both
ecosystems read the same source of truth.

---

## 3. GEO / AEO — on-page patterns that get content quoted by AI engines

### 3.1 Definitions (canonical)

- **GEO (Generative Engine Optimization):** optimizing content to be surfaced and **cited** inside
  AI-generated answers (ChatGPT, Claude, Perplexity, Google AI Overviews, Copilot). The term and
  framework come from the peer-reviewed paper **"GEO: Generative Engine Optimization"** (Aggarwal,
  Murahari, Rajpurohit, Kalyan, Narasimhan, Deshpande), accepted to **KDD 2024**
  (arXiv 2311.09735). ([arXiv](https://arxiv.org/abs/2311.09735))
- **AEO (Answer Engine Optimization):** the practitioner term for the same goal — structuring content
  so an answer engine can extract a self-contained, citable passage that directly answers a query.
  ([CXL AEO guide](https://cxl.com/blog/answer-engine-optimization-aeo-the-comprehensive-guide/);
  [Frase AEO guide](https://www.frase.io/blog/what-is-answer-engine-optimization-the-complete-guide-to-getting-cited-by-ai))
- Industry shorthand: *"SEO gets you clicked; GEO gets you quoted."*
  ([Frase GEO guide](https://www.frase.io/blog/what-is-generative-engine-optimization-geo))

### 3.2 The primary-source evidence (Princeton/Georgia Tech KDD 2024)

From the paper's abstract (verbatim): *"...we demonstrate that GEO can boost visibility by up to 40%
in generative engine responses. Moreover, we show the efficacy of these strategies varies across
domains, underscoring the need for domain-specific optimization methods."* The study introduced
**GEO-bench**, a large-scale benchmark of diverse queries across multiple domains.
([arXiv abstract](https://arxiv.org/abs/2311.09735))

The methods that **measurably increased visibility** (per widely-reported figures from the paper):
- Adding **authoritative source citations** (~+30%)
- Adding **quotations** (e.g. expert quotes) (~+41%)
- Adding **statistics / numeric data** (~+32%)
These require restructuring, not redesign. Conversely, naive **keyword stuffing** did **not** help.
([The HOTH summary](https://www.thehoth.com/blog/generative-engine-optimization/);
[Mersel AI](https://www.mersel.ai/generative-engine-optimization))
Note: the specific +30/+32/+41% per-method numbers are reported by secondary write-ups summarizing
the paper; the abstract itself states only the headline "up to 40%." Treat per-method figures as
**paper-derived but secondary-sourced** (see Uncertainties).

### 3.3 On-page patterns AI answer engines reward (2025–2026 practitioner consensus)

1. **Answer-first / self-contained passages.** Lead each section with the direct answer in the first
   ~40–60 words; AI engines parse **by section/passage, not by page**, and extract the opening
   sentences. Each section must stand alone and be citable on its own.
   ([CXL](https://cxl.com/blog/answer-engine-optimization-aeo-the-comprehensive-guide/);
   [Surfer SEO](https://surferseo.com/blog/answer-engine-optimization/))
2. **One self-contained claim → one source.** Back each claim with evidence (a citation, a stat, or a
   quote). High fact-density is a citation signal. ([Frase AEO](https://www.frase.io/blog/what-is-answer-engine-optimization-the-complete-guide-to-getting-cited-by-ai))
3. **Q&A blocks + question-based headings.** Phrase H2/H3s as the questions users ask ("What is X?",
   "How do I do Y?") and answer immediately beneath. FAQ-style structure maps directly to the
   question→answer pattern models use. ([HubSpot AEO](https://blog.hubspot.com/marketing/answer-engine-optimization-trends);
   [Surfer SEO](https://surferseo.com/blog/answer-engine-optimization/))
4. **Canonical definitions.** Provide a crisp, dictionary-style definition of each key term up front
   (good for "What is …" extraction). ([Frase GEO](https://www.frase.io/blog/what-is-generative-engine-optimization-geo))
5. **Comparison tables / structured data.** Tables (X vs Y, option matrices) are easy for engines to
   lift verbatim; pair with Schema.org structured data where on a real website (FAQPage / Article).
   ([CXL](https://cxl.com/blog/answer-engine-optimization-aeo-the-comprehensive-guide/))
6. **Clear semantic heading hierarchy.** Strict H1 → H2 → H3 nesting; one H1; descriptive headings.
   ([Surfer SEO](https://surferseo.com/blog/answer-engine-optimization/))
7. **Dated, current content + visible authorship (E-E-A-T).** Named author + bio, visible publish/
   update dates, inline references. Freshness matters (Perplexity especially rewards recency).
   ([almcorp GEO guide](https://almcorp.com/blog/how-to-rank-on-chatgpt-perplexity-ai-search-engines-complete-guide-generative-engine-optimization/);
   [SEO Tuners playbook](https://seotuners.com/blog/seo/generative-engine-optimization-geo-in-2025-the-complete-playbook-to-win-ai-overviews-chatgpt-copilot-perplexity/))
8. **No marketing fluff.** Plain, factual, declarative prose; engines extract clean factual claims,
   not promotional adjectives. (Consistent across the AEO/GEO guides cited above.)
9. **Platform nuance.** ChatGPT favors encyclopedic, well-structured reference content (and its web
   search historically leans on **Bing's** index — so a Bing-indexable presence helps); Perplexity
   rewards recency and examples; Google AI Overviews tend to draw from already top-ranking pages.
   ([AI Magicx](https://www.aimagicx.com/blog/generative-engine-optimization-chatgpt-perplexity-2026);
   [SEO Tuners](https://seotuners.com/blog/seo/generative-engine-optimization-geo-in-2025-the-complete-playbook-to-win-ai-overviews-chatgpt-copilot-perplexity/))
   The Bing-index/ChatGPT linkage is widely reported by practitioners but not a current vendor
   statement here — see Uncertainties.

### 3.4 How this maps to OUR repo content (README + docs)

- Open the README H1 with the exact problem phrase a user would search ("AWS cost audit"), and put a
  one-sentence canonical definition + the answer-first value prop in the first 100 words.
- Use question-style H2s ("What does this skill check?", "How do I run an AWS cost audit?") with the
  answer immediately beneath.
- Use comparison tables (e.g. "before/after this skill", or "check → savings lever") and bullet
  claims, each tied to an AWS-doc citation where a fact is asserted.
- Keep AWS facts generic and link to AWS primary docs; never assert specific dollar prices.
- Show a visible "last updated" date.

---

## 4. GitHub repo discoverability (SEO) — because the repo is the artifact

Primary GitHub ranking inputs: **repository name, About description, topics, and README content.**
([GitHub SEO guide 2025](https://dev.to/infrasity-learning/the-ultimate-guide-to-github-seo-for-2025-38kl);
[GitDevTool](https://www.gitdevtool.com/blog/github-seo))

- **Name:** keyword-rich, hyphenated, specific (e.g. `aws-cost-audit-skill` beats a vague name).
- **About/description:** one clear keyword-bearing sentence; it appears in GitHub search and on topic
  pages.
- **Topics:** up to **20** topics; use relevant tags, avoid the primary language as a tag and avoid
  junk tags like version numbers or "beta". ([GitDevTool](https://www.gitdevtool.com/blog/github-seo))
- **README:** strict H1/H2/H3, primary keyword in the first ~100 words, screenshots/diagrams/GIFs.
- **Freshness + engagement:** recent commits and stars/forks act as ranking/social-proof signals.
([GitHub SEO 2025](https://dev.to/infrasity-learning/the-ultimate-guide-to-github-seo-for-2025-38kl))

### Recommended GitHub topics for this skill repo
`claude-code`, `claude-skill`, `agent-skill`, `aws`, `aws-cost-optimization`, `finops`,
`cost-optimization`, `cloud-cost-management`, `aws-cost-explorer`, `devops`, `cli`, `audit`.
(Keep total ≤ 20; drop any that don't match the final feature set. The "20 topics max" and topic
hygiene advice is from the GitHub-SEO sources above.)

---

## 5. Practitioner takeaways (action list for the build)

1. Ship a spec-correct `llms.txt` (H1 → blockquote → optional intro → H2 link sections → `## Optional`)
   but treat it as low-leverage; do not depend on it.
2. Ship a root `AGENTS.md` (project overview, exact build/test/validate commands, layout, done-criteria,
   commit/PR rules). If `CLAUDE.md` exists, symlink the two.
3. Write the README and docs **answer-first**: canonical definitions, question H2s, one-claim-one-source,
   comparison tables, strict heading hierarchy, visible dates, zero marketing fluff, no invented prices.
4. Optimize the repo for GitHub search: specific hyphenated name, keyword About line, ≤20 relevant
   topics, keyword in first 100 words of README, keep it fresh.

---

## Sources

All accessed **2026-05-28**.

Primary / authoritative:
- Answer.AI — Jeremy Howard, "The /llms.txt file" proposal: https://www.answer.ai/posts/2024-09-03-llmstxt.html
- llms.txt specification — llmstxt.org: https://llmstxt.org/
- AGENTS.md — official site & FAQ: https://agents.md/
- AGENTS.md — official GitHub repo (agentsmd/agents.md): https://github.com/agentsmd/agents.md
- "GEO: Generative Engine Optimization" (KDD 2024), arXiv 2311.09735: https://arxiv.org/abs/2311.09735

Reputable secondary (GEO/AEO/llms.txt adoption & GitHub SEO):
- Does llms.txt matter? (10-site study) — Search Engine Land: https://searchengineland.com/does-llms-txt-matter-467740
- LLMs.txt crawler audit — Flavio Longato: https://www.longato.ch/llms-recommendation-2025-august/
- What Is LLMs.txt & Should You Use It? — Semrush: https://www.semrush.com/blog/llms-txt/
- What is Generative Engine Optimization (GEO)? — Frase: https://www.frase.io/blog/what-is-generative-engine-optimization-geo
- Answer Engine Optimization (AEO) complete guide — Frase: https://www.frase.io/blog/what-is-answer-engine-optimization-the-complete-guide-to-getting-cited-by-ai
- Answer Engine Optimization (AEO) comprehensive guide — CXL: https://cxl.com/blog/answer-engine-optimization-aeo-the-comprehensive-guide/
- AEO trends 2026 — HubSpot: https://blog.hubspot.com/marketing/answer-engine-optimization-trends
- Answer Engine Optimization 2026 — Surfer SEO: https://surferseo.com/blog/answer-engine-optimization/
- GEO: Getting cited in ChatGPT, Claude, Perplexity — AI Magicx: https://www.aimagicx.com/blog/generative-engine-optimization-chatgpt-perplexity-2026
- GEO 2025 playbook — SEO Tuners: https://seotuners.com/blog/seo/generative-engine-optimization-geo-in-2025-the-complete-playbook-to-win-ai-overviews-chatgpt-copilot-perplexity/
- How to rank on ChatGPT/Perplexity — almcorp: https://almcorp.com/blog/how-to-rank-on-chatgpt-perplexity-ai-search-engines-complete-guide-generative-engine-optimization/
- GEO for B2B 2026 (paper per-method figures) — Mersel AI: https://www.mersel.ai/generative-engine-optimization
- GEO research deep dive — The HOTH: https://www.thehoth.com/blog/generative-engine-optimization/
- The Ultimate Guide to GitHub SEO 2025 — DEV: https://dev.to/infrasity-learning/the-ultimate-guide-to-github-seo-for-2025-38kl
- GitHub SEO Guide 2025 — GitDevTool: https://www.gitdevtool.com/blog/github-seo
