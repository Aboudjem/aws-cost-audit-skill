# 01 — Claude Code / Anthropic Agent Skill Authoring: Best Practices + Repo Teardown

**Research scope:** Official Anthropic Agent Skills docs, the agentskills.io open specification, and a teardown of real, popular Claude skill/plugin repos on GitHub. Goal: ground the design of a generic, reference-grade "AWS cost audit" skill that ships as a public repo.

**Access date:** 2026-05-28. All star counts fetched live from the GitHub REST API on this date.

> Verification discipline: every load-bearing claim cites a source URL. Items that could not be confirmed from a primary/authoritative source are labelled **UNVERIFIED** and collected in the Uncertainties section. No AWS dollar prices are stated.

---

## 1. What a Skill is (official)

An Agent Skill is a **directory** containing, at minimum, a `SKILL.md` file with YAML frontmatter plus a Markdown body, and optionally bundled `scripts/`, `references/`, and `assets/`. Skills package instructions, metadata, and optional resources that Claude loads **on demand** when relevant — unlike prompts (one-off) or CLAUDE.md (always loaded). Source: [Agent Skills overview](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview); [agentskills.io spec](https://agentskills.io/specification).

Claude Code-specific framing: create a skill "when you keep pasting the same instructions, checklist, or multi-step procedure into chat, or when a section of CLAUDE.md has grown into a procedure rather than a fact. Unlike CLAUDE.md content, a skill's body loads only when it's used." Custom commands have been **merged into skills** — `.claude/commands/deploy.md` and `.claude/skills/deploy/SKILL.md` both create `/deploy`. Source: [Claude Code skills doc](https://code.claude.com/docs/en/skills).

---

## 2. SKILL.md frontmatter — the authoritative field tables

There are **three overlapping field sets**. Knowing which applies where prevents over- or under-specifying frontmatter.

### 2a. Anthropic platform / API (the strict baseline)

Required fields are only `name` and `description`. Source: [Skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices); [overview](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview).

- **`name`**: max 64 characters; lowercase letters, numbers, and hyphens only; no XML tags; **cannot contain reserved words "anthropic" or "claude"**.
- **`description`**: non-empty; max 1024 characters; no XML tags; should state both what the skill does and when to use it.

### 2b. agentskills.io open standard (adds optional fields)

The agentskills.io spec backs Claude Code's skills, and Claude Code "extends the standard." Source: [agentskills.io spec](https://agentskills.io/specification); [Claude Code skills doc](https://code.claude.com/docs/en/skills).

| Field | Required | Constraints (verbatim from spec) |
|---|---|---|
| `name` | Yes | 1–64 chars; unicode lowercase `a-z`, `0-9`, hyphens; must not start/end with `-`; **no consecutive hyphens** (`--`); **must match the parent directory name**. |
| `description` | Yes | 1–1024 chars; non-empty; describe what + when; include trigger keywords. |
| `license` | No | License name or reference to a bundled license file. |
| `compatibility` | No | 1–500 chars if provided; environment requirements (intended product, system packages, network access). Most skills don't need it. |
| `metadata` | No | Arbitrary string→string map (e.g. `author`, `version`). Use unique key names to avoid conflicts. |
| `allowed-tools` | No | Space-separated string of pre-approved tools, e.g. `Bash(git:*) Bash(jq:*) Read`. **Experimental**; support varies by agent. |

### 2c. Claude Code extended frontmatter (richest — relevant for a shipped CC skill)

Claude Code supports a larger set; **all fields are optional**, and only `description` is recommended. Source: [Claude Code skills doc — Frontmatter reference](https://code.claude.com/docs/en/skills).

- **`name`**: display name in skill listings; defaults to the directory name. (Note: in Claude Code, the directory name — not `name` — is what you type after `/`, except for a plugin-root `SKILL.md`.)
- **`description`** (recommended): what + when. **Put the key use case first** — the combined `description` + `when_to_use` text is truncated at **1,536 characters** in the skill listing. If omitted, the first paragraph of body content is used.
- **`when_to_use`**: extra trigger phrases / example requests; appended to `description`, counts toward the 1,536-char cap.
- **`argument-hint`**: autocomplete hint, e.g. `[filename] [format]`.
- **`arguments`**: named positional args for `$name` substitution.
- **`disable-model-invocation: true`**: only the user can invoke (via `/name`); removes the description from Claude's context. Use for side-effecting workflows (`/commit`, `/deploy`). Also prevents preload into subagents.
- **`user-invocable: false`**: only Claude can invoke; hides from the `/` menu. Use for background knowledge.
- **`allowed-tools`**: tools usable without per-use permission prompts while the skill is active (does NOT restrict the pool). For project skills, takes effect after workspace trust is accepted.
- **`disallowed-tools`**: tools removed from the pool while active (e.g. block `AskUserQuestion` in a background loop).
- **`model`**: model override for the rest of the turn (same values as `/model`, or `inherit`).
- **`effort`**: `low` | `medium` | `high` | `xhigh` | `max` (availability depends on model).
- **`context: fork`**: run in a forked subagent context.
- **`agent`**: which subagent type when `context: fork` (built-ins `Explore`, `Plan`, `general-purpose`, or a custom `.claude/agents/` agent; defaults to `general-purpose`).
- **`hooks`**: hooks scoped to the skill lifecycle.
- **`paths`**: glob patterns that limit when the skill auto-activates.
- **`shell`**: `bash` (default) or `powershell` for inline `` !`command` `` blocks.

**Design takeaway for an AWS cost audit skill:** name `aws-cost-audit` (matches directory, no reserved words); a keyword-rich `description`; keep `allowed-tools` scoped to read-only AWS CLI patterns (e.g. `Bash(aws ce:*)`, `Bash(aws ec2 describe*:*)`) so an audit never mutates infrastructure; lean on the open-standard fields (`name`, `description`, optional `license`, `metadata`) for cross-tool portability rather than CC-only fields, so the skill also works on agentskills.io-compatible agents.

---

## 3. Progressive disclosure — the core design principle (3 levels)

Skills load progressively; structure to exploit it. Source: [overview — How Skills work](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview); [agentskills.io spec](https://agentskills.io/specification); [best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices).

| Level | When loaded | Token cost (official) | Content |
|---|---|---|---|
| **1: Metadata** | Always, at startup | ~100 tokens per skill | `name` + `description` from frontmatter, injected into system prompt |
| **2: Instructions** | When the skill triggers | Under ~5k tokens (recommended) | SKILL.md body |
| **3: Resources** | As needed, via bash | Effectively unlimited | Files in `scripts/`/`references/`/`assets/`; scripts executed (output only enters context), reference files read on demand |

Hard guidance:
- **Keep the SKILL.md body under 500 lines.** Split detail into separate files. ([best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices); [agentskills.io spec](https://agentskills.io/specification); [Claude Code skills doc](https://code.claude.com/docs/en/skills).)
- **Keep file references one level deep from SKILL.md.** Claude may only partially read (`head -100`) nested references, getting incomplete info. All reference files should link directly from SKILL.md. ([best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices).)
- **For reference files >100 lines, add a table of contents** at the top so partial reads still surface the full scope. ([best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices).)
- **No context penalty for bundled content until accessed** — bundle comprehensive API docs / large datasets freely. ([overview](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview).)

The official PDF skill (`anthropics/skills`) is a concrete model: a ~2,000-word body with sections (Overview, Quick Start, Python Libraries, Command-Line Tools, Common Tasks, Quick Reference, Next Steps) that defers `REFERENCE.md` (advanced) and `FORMS.md` (form-filling) until needed. Source: [pdf/SKILL.md](https://raw.githubusercontent.com/anthropics/skills/main/skills/pdf/SKILL.md).

---

## 4. Writing the `description` (most important authoring decision)

The description is **how the skill is discovered** — Claude uses it to pick from 100+ skills. Source: [best practices — Writing effective descriptions](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices).

- **Always third person.** It is injected into the system prompt; inconsistent POV causes discovery problems. Good: "Processes Excel files and generates reports." Avoid: "I can help you..." / "You can use this to...".
- **State both WHAT and WHEN**, and include specific trigger keywords. Official example: `Extract text and tables from PDF files, fill forms, merge documents. Use when working with PDF files or when the user mentions PDFs, forms, or document extraction.`
- **Avoid vague descriptions** ("Helps with documents", "Processes data").
- **Be "pushy" about triggers.** The official `skill-creator` advises including contexts where the skill applies "even if they don't explicitly ask for it," because Claude tends to **undertrigger** skills. Source: [skill-creator/SKILL.md](https://raw.githubusercontent.com/anthropics/skills/main/skills/skill-creator/SKILL.md).
- **Put the key use case first** — text is truncated (1,536 chars in Claude Code listings; 1,024 char hard cap on the field itself). Source: [Claude Code skills doc](https://code.claude.com/docs/en/skills); [best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices).

**Draft for the AWS cost audit skill** (third person, keyword-rich, WHAT+WHEN, real PDF-skill phrasing as the template):
> "Audits an AWS account for cost savings — finds idle/oversized resources, untagged spend, unused EBS volumes and Elastic IPs, old snapshots, and Savings Plan / Reserved Instance opportunities using Cost Explorer and read-only AWS CLI queries. Use whenever the user wants to reduce, review, or analyze their AWS bill or asks about AWS costs, FinOps, idle resources, or rightsizing."

---

## 5. Naming conventions (official)

Source: [best practices — Naming conventions](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices).

- Prefer **gerund form** (verb + -ing): `processing-pdfs`, `analyzing-spreadsheets`, `testing-code`.
- Acceptable: noun phrases (`pdf-processing`, `spreadsheet-analysis`) or action-oriented (`analyze-spreadsheets`).
- **Avoid**: vague (`helper`, `utils`, `tools`), overly generic (`documents`, `data`, `files`), reserved words (`anthropic-*`, `claude-*`), inconsistent patterns.
- Reminder: `name` is lowercase + numbers + hyphens only, and (per the open spec) must match the parent directory name.

> Note: real production skills don't always use the gerund form — the official skill is named `pdf`, not `processing-pdfs`. Gerund is a recommendation, not a hard rule. (`pdf` / `xlsx` / `docx` are the actual directory names: [anthropics/skills tree](https://github.com/anthropics/skills/tree/main/skills).)

---

## 6. Body authoring best practices (the high-value rules)

Source: [best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices) unless noted.

- **Concise is key.** "The context window is a public good." Default assumption: Claude is already smart — only add context it doesn't have. Challenge each line's token cost.
- **Set appropriate degrees of freedom**, matched to task fragility:
  - **High freedom** (text instructions) when multiple approaches are valid / context-dependent.
  - **Medium freedom** (pseudocode / parameterized scripts) when a preferred pattern exists.
  - **Low freedom** (exact scripts, "do not modify the command") when operations are fragile/destructive and consistency is critical. Analogy: narrow bridge vs. open field.
- **Use workflows + checklists** for complex multi-step tasks; have Claude copy a checklist and tick items.
- **Implement feedback loops**: run validator → fix errors → repeat (the "validator" can be a STYLE_GUIDE.md, not just a script).
- **Avoid time-sensitive info** ("after August 2025…"); use a collapsible "Old patterns" `<details>` section for legacy context.
- **Use consistent terminology** (one term per concept throughout).
- **Templates pattern**: provide output templates; match strictness ("ALWAYS use this exact template" vs. "sensible default, use judgment").
- **Examples pattern**: include concrete input/output pairs.
- **Conditional workflow pattern**: route at decision points ("Creating? → … / Editing? → …").

### Skills with executable code
- **Solve, don't punt**: scripts handle errors explicitly rather than failing for Claude to fix.
- **No "voodoo constants"**: justify/document every magic number.
- **Prefer utility scripts** for deterministic ops — more reliable, save tokens, ensure consistency. **Make execution intent explicit**: "Run `analyze_form.py`" (execute) vs. "See `analyze_form.py` for the algorithm" (read).
- **Create verifiable intermediate outputs** ("plan-validate-execute"): write a plan file, validate it with a script, then execute — for batch/destructive/high-stakes operations.
- **Don't assume tools are installed**: state `pip install …` / dependencies.
- **MCP tool references must be fully qualified**: `ServerName:tool_name` (e.g. `GitHub:create_issue`), else "tool not found."

### Anti-patterns
- **No Windows-style backslash paths** — always forward slashes (`scripts/helper.py`), cross-platform.
- **Don't offer too many options** — give one default with an escape hatch, not "pypdf or pdfplumber or PyMuPDF or…".

### Writing style (from skill-creator)
"Explain to the model **why** things are important" rather than heavy-handed capitalized commands; "leverage theory of mind to make skills general rather than narrow." Source: [skill-creator/SKILL.md](https://raw.githubusercontent.com/anthropics/skills/main/skills/skill-creator/SKILL.md).

---

## 7. Evaluation-driven development (official)

**Build evaluations BEFORE writing extensive documentation.** Source: [best practices — Evaluation and iteration](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices).

1. Identify gaps: run Claude on representative tasks without the skill; document failures.
2. Create evaluations: build **three** scenarios testing those gaps.
3. Establish a baseline (performance without the skill).
4. Write **minimal** instructions to pass the evals.
5. Iterate against the baseline.

Eval JSON shape (from the docs):
```json
{
  "skills": ["pdf-processing"],
  "query": "Extract all text from this PDF file and save it to output.txt",
  "files": ["test-files/document.pdf"],
  "expected_behavior": [
    "Successfully reads the PDF file using an appropriate PDF processing library or command-line tool",
    "Extracts text content from all pages without missing any pages",
    "Saves the extracted text to output.txt in a clear, readable format"
  ]
}
```
> The docs note there is **no built-in runner** for these evals — users build their own. The `skill-creator` workflow does spawn parallel with-skill vs. baseline test runs and an `eval-viewer/generate_review.py` browser review. ([skill-creator/SKILL.md](https://raw.githubusercontent.com/anthropics/skills/main/skills/skill-creator/SKILL.md).)

**The "Claude A / Claude B" loop**: develop the skill with one Claude (the author/refiner) and test it on a fresh Claude with the skill loaded; bring observed failures back to the author Claude. Checklist for completion is in §8.

---

## 8. Official "checklist for effective skills"

Source: [best practices — Checklist](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices).

**Core quality:** description is specific + has key terms; description has what AND when; body under 500 lines; details in separate files; no time-sensitive info (or in "old patterns"); consistent terminology; concrete (not abstract) examples; file references one level deep; progressive disclosure used; workflows have clear steps.
**Code/scripts:** scripts solve (don't punt); explicit error handling; no voodoo constants; required packages listed + verified; scripts documented; no Windows paths; validation steps for critical ops; feedback loops for quality-critical tasks.
**Testing:** ≥3 evaluations; tested with Haiku, Sonnet, and Opus; tested with real scenarios; team feedback incorporated.

---

## 9. Directory layout (official, canonical)

```
skill-name/                 # directory name == frontmatter `name`
├── SKILL.md                # required: frontmatter + instructions (the entrypoint)
├── REFERENCE.md            # optional: detailed reference (loaded on demand)
├── FORMS.md / examples.md  # optional: domain/usage docs (one level deep)
├── scripts/                # optional: executable code (run, not read)
├── references/             # optional: docs read on demand (e.g. finance.md, sales.md)
└── assets/                 # optional: templates, schemas, lookup tables, images
```
Sources: [agentskills.io spec](https://agentskills.io/specification); [overview](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview); [Claude Code skills doc](https://code.claude.com/docs/en/skills).

**Where skills live in Claude Code** (this determines who can use them):

| Location | Path | Applies to |
|---|---|---|
| Enterprise | managed settings | All org users |
| Personal | `~/.claude/skills/<skill-name>/SKILL.md` | All your projects |
| Project | `.claude/skills/<skill-name>/SKILL.md` | This project only |
| Plugin | `<plugin>/skills/<skill-name>/SKILL.md` | Where the plugin is enabled |

Precedence: enterprise > personal > project; plugin skills are namespaced `plugin-name:skill-name` and can't conflict. Project skills load from `.claude/skills/` in the start dir and every parent up to repo root (monorepo-friendly). Source: [Claude Code skills doc — Where skills live](https://code.claude.com/docs/en/skills).

---

## 10. Packaging as a plugin (for public-repo distribution)

To ship a skill as an installable Claude Code plugin + marketplace. Sources: [Create plugins](https://code.claude.com/docs/en/plugins); [anthropics/skills marketplace.json](https://github.com/anthropics/skills/blob/main/.claude-plugin/marketplace.json).

### Plugin manifest — `.claude-plugin/plugin.json`
```json
{
  "name": "my-plugin",
  "description": "Shown in the plugin manager",
  "version": "1.0.0",
  "author": { "name": "Your Name" }
}
```
Fields: `name` (unique id + skill namespace), `description`, `version` (optional — if set, users only get updates when bumped; if omitted with git distribution, the commit SHA is the version), `author` (optional). More fields (`homepage`, `repository`, `license`) in the plugins reference.

### Plugin directory structure
```
my-plugin/
├── .claude-plugin/
│   └── plugin.json         # ONLY plugin.json goes in .claude-plugin/
└── skills/
    └── aws-cost-audit/
        └── SKILL.md
```
**Common mistake (called out in the docs):** do NOT put `skills/`, `agents/`, `commands/`, or `hooks/` inside `.claude-plugin/` — they live at the **plugin root**.

### Marketplace — `.claude-plugin/marketplace.json`
The official `anthropics/skills` marketplace.json shape:
```json
{
  "name": "anthropic-agent-skills",
  "owner": { "name": "...", "email": "..." },
  "metadata": { "description": "...", "version": "..." },
  "plugins": [
    {
      "name": "document-skills",
      "description": "...",
      "source": "./",
      "strict": false,
      "skills": ["./skills/xlsx", "./skills/docx", "..."]
    }
  ]
}
```
Top-level keys: `name`, `owner`, `metadata`, `plugins[]`. Each plugin entry: `name`, `description`, `source`, `strict` (bool), `skills` (array of paths). Source: [anthropics/skills marketplace.json](https://github.com/anthropics/skills/blob/main/.claude-plugin/marketplace.json).

### Install / test commands (verbatim)
- Local dev/test: `claude --plugin-dir ./my-plugin` (also accepts a `.zip`; `claude --plugin-url <zip-url>`).
- Reload after edits: `/reload-plugins`.
- Add a marketplace: `/plugin marketplace add owner/repo` (official skills: `/plugin marketplace add anthropics/skills`).
- Install: `/plugin install <plugin>@<marketplace>` (e.g. `/plugin install document-skills@anthropic-agent-skills`).
- Validate before submitting: `claude plugin validate`.
- Community submission: forms at `claude.ai/settings/plugins/submit` or `platform.claude.com/plugins/submit`; the community marketplace is `anthropics/claude-plugins-community` (add with `/plugin marketplace add anthropics/claude-plugins-community`, install as `@claude-community`). The official `claude-plugins-official` marketplace is curated by Anthropic (no application process).

Sources: [Create plugins](https://code.claude.com/docs/en/plugins); [anthropics/skills README via overview](https://github.com/anthropics/skills).

**Design takeaway:** ship the repo BOTH ways — (a) drop-in: `skills/aws-cost-audit/SKILL.md` usable by copying to `~/.claude/skills/` or `.claude/skills/`; and (b) plugin: add `.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` so users can `/plugin marketplace add <you>/<repo>` then `/plugin install`. This mirrors what the most-installed repos do (§11).

---

## 11. Teardown of real, popular skill/plugin repos (live star counts, 2026-05-28)

Star counts via GitHub REST API on 2026-05-28. Ranked by relevance + reach.

| Repo | Stars | What it is | Layout / distribution | Notable for authoring |
|---|---:|---|---|---|
| [obra/superpowers](https://github.com/obra/superpowers) | **211,074** | "Agentic skills framework & software-development methodology." | `/skills` dir, one subdir + `SKILL.md` per skill. **No traditional marketplace.json shown** — uses per-agent install (Claude Code: `/plugin install superpowers@claude-plugins-official`; also Codex, Factory Droid `droid plugin marketplace add <repo>`, Gemini `gemini extensions install <repo>`, Copilot). 16 documented skills in 4 categories (Testing/Debugging/Collaboration/Meta). | README shape: Quickstart → How it works → Sponsorship → Installation → Basic Workflow → What's Inside → Philosophy → Contributing → License → Community. Emphasizes agent autonomy + verification and **anti-pattern references inside skills**. Multi-harness install is the headline differentiator. |
| [anthropics/skills](https://github.com/anthropics/skills) | **142,827** | Official Anthropic skills repo + the spec + a template. | Root: `.claude-plugin/`, `skills/`, `spec/`, `template/`, `README.md`, `THIRD_PARTY_NOTICES.md`. 17 example skills (`pdf`, `xlsx`, `docx`, `pptx`, `skill-creator`, `mcp-builder`, `brand-guidelines`, `webapp-testing`, `frontend-design`, `algorithmic-art`, etc.). Ships a real `marketplace.json` grouping skills into plugins (document-skills / example-skills / claude-api). | The canonical reference. Document skills are **source-available, not OSS** (`license: Proprietary. LICENSE.txt…`); example skills Apache-2.0. Template is minimal (`name` + `description` + "# Insert instructions below"). `skill-creator` is the meta-skill. |
| [hesreallyhim/awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code) | **45,076** | Curated list of skills, hooks, slash-commands, orchestrators, plugins. | Awesome-list (README index, not installable). | Reference for category taxonomy and how the community frames "skills vs hooks vs commands vs agents." |
| [wshobson/agents](https://github.com/wshobson/agents) | **36,089** | "Multi-harness agentic plugin marketplace" (Claude Code, Codex, Cursor, OpenCode, Gemini). | Plugin marketplace repo. | Reinforces the multi-harness distribution pattern (same as superpowers). |
| [davila7/claude-code-templates](https://github.com/davila7/claude-code-templates) | **27,646** | CLI tool for configuring/monitoring Claude Code (templates incl. skills/agents/commands). | CLI-distributed templates. | Shows an alternative distribution channel (a `npx`-style CLI) vs. plugin marketplace. |
| [alirezarezvani/claude-skills](https://github.com/alirezarezvani/claude-skills) | **16,445** | "337 Claude Code skills & agent skills & plugins" multi-tool bundle. | Large skill/agent/command bundle, multi-agent (Claude Code, Codex, Gemini, Cursor, +). | Example of a mega-collection; less useful as an authoring model (breadth over depth). |
| [travisvn/awesome-claude-skills](https://github.com/travisvn/awesome-claude-skills) | **12,979** | Curated awesome-list focused on Claude **Skills**. | README index. Sections: Getting Started (install across Claude.ai / CLI / API) → Official Skills (by category) → Community Skills (tables) → Skill Creation (skill-creator vs manual) → Docs → Updates → Skills-vs-other comparison → Tutorials/Articles/Security → Troubleshooting/FAQ. Skill entries = hyperlinked name + 2–3 sentence description; **no star counts or install commands per entry**. | Best model for a **README shape** for a single-skill repo's docs: lead with three-platform install (CLI `/plugin marketplace add anthropics/skills`, web Settings>Capabilities>Skills, API `/v1/skills`), then usage, then authoring, then troubleshooting/FAQ. |

> The "alirezarezvani has 5,200 stars / is the most comprehensive" figure that appears in some 2026 blog posts is stale — the live API shows 16,445 on 2026-05-28. Treat third-party blog star counts as UNVERIFIED; the GitHub API is authoritative.

### What the great ones do differently (synthesis)
1. **Multi-harness install up top.** The biggest repos (superpowers, wshobson/agents) present install commands for Claude Code AND Codex/Gemini/Cursor/Droid/Copilot. For maximum reach, document at least the Claude Code plugin install plus the generic agentskills.io drop-in.
2. **Ship both a marketplace and a drop-in.** anthropics/skills ships `marketplace.json`; community repos let you copy a `SKILL.md` directly. Doing both lowers friction.
3. **A template + a meta-creator.** anthropics/skills includes a `template/` and `skill-creator` skill — strong signal that scaffolding/onboarding matters.
4. **Anti-patterns live inside the skill** (superpowers), not just the README — the model reads them.
5. **Descriptions are keyword-stuffed and "pushy"** to beat undertriggering (skill-creator guidance), while staying third-person and WHAT+WHEN.
6. **Awesome-list README taxonomy**: Getting Started (multi-platform install) → Skills by category → Creation → Docs → Troubleshooting/FAQ — a proven structure to mirror.

---

## 12. Security & runtime constraints (affect an AWS skill directly)

- **Trust**: "Use Skills only from trusted sources." Malicious skills can exfiltrate data or misuse tools; skills that fetch external URLs are especially risky. Audit all bundled files. For an AWS skill (cloud credentials in scope), this is critical — scope `allowed-tools` to **read-only** AWS CLI verbs and avoid any network-fetch of remote instructions. Source: [overview — Security considerations](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview).
- **Runtime environment differs by surface**:
  - **Claude API**: NO network access, NO runtime package install — only pre-installed packages. (An AWS-CLI-dependent skill effectively targets **Claude Code**, where skills have full network access like any local program.)
  - **claude.ai**: variable network access by admin settings.
  - **Claude Code**: full network access; **global package install discouraged** — install locally only.
  Source: [overview — Limitations and constraints](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview).
- **Skills do not sync across surfaces** (claude.ai / API / Claude Code are separate); plan distribution per surface. Source: [overview](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview).
- **Skill content lifecycle (Claude Code)**: once invoked, the rendered SKILL.md stays in context for the session and is NOT re-read each turn — write standing instructions, not one-time steps. Auto-compaction re-attaches the first 5,000 tokens of each recently-invoked skill within a combined 25,000-token budget. Source: [Claude Code skills doc — Skill content lifecycle](https://code.claude.com/docs/en/skills).

---

## 13. Concrete recommendations for the AWS cost audit skill

1. **Name** `aws-cost-audit` (matches directory; no reserved word; noun-phrase acceptable per docs). Body **< 500 lines**; defer detail to `references/` (e.g. `references/savings-plans.md`, `references/idle-resources.md`, `references/tagging.md`) one level deep, each with a ToC if >100 lines.
2. **Description**: third person, WHAT+WHEN, key use case first, keyword-rich and "pushy" (see §4 draft).
3. **Lock down tools**: `allowed-tools` limited to read-only AWS CLI patterns (Cost Explorer `aws ce`, `describe*`/`list*`/`get*` calls). Never bundle mutating commands; if recommending remediations, use the **plan-validate-execute** pattern with a human-confirmed plan file, and keep destructive actions at **low freedom** (exact, do-not-modify commands) — or out of scope entirely.
4. **Progressive disclosure**: SKILL.md = overview + audit workflow checklist + navigation; bundle category references and any `scripts/` for deterministic queries/aggregation (execute, don't read). Document required tooling (`aws` CLI, `jq`) and that it targets **Claude Code** (network + local CLI), not the no-network Claude API.
5. **Evals first**: ≥3 scenarios (e.g. "find idle EC2", "summarize last-month spend by service", "list untagged resources"), baseline without the skill, then write minimal instructions. Test on Haiku/Sonnet/Opus.
6. **Ship both** drop-in (`skills/aws-cost-audit/`) and plugin (`.claude-plugin/plugin.json` + `marketplace.json`). README modeled on travisvn taxonomy: multi-platform install first, then usage, authoring/customization, security note, troubleshooting/FAQ. Include a `LICENSE` (open-source, e.g. MIT/Apache-2.0) and `metadata.version`.
7. **No time-sensitive facts and no specific AWS prices in the skill body** — costs change; have the skill compute from live Cost Explorer / pricing data instead. Use an "Old patterns" `<details>` block for any deprecated CLI flags.
8. **Validate** with `skills-ref validate ./aws-cost-audit` (agentskills.io) and `claude plugin validate` (Claude Code) before publishing.

---

## Sources

All accessed **2026-05-28**.

**Official Anthropic / Claude docs (primary)**
- Agent Skills — overview: https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview
- Skill authoring best practices: https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
- Claude Code — Extend Claude with skills: https://code.claude.com/docs/en/skills
- Claude Code — Create plugins: https://code.claude.com/docs/en/plugins
- Equipping agents for the real world with Agent Skills (engineering blog): https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills

**Open specification (authoritative)**
- agentskills.io specification: https://agentskills.io/specification

**Official repo + real skill source**
- anthropics/skills: https://github.com/anthropics/skills
- anthropics/skills — marketplace.json: https://github.com/anthropics/skills/blob/main/.claude-plugin/marketplace.json
- anthropics/skills — pdf/SKILL.md: https://raw.githubusercontent.com/anthropics/skills/main/skills/pdf/SKILL.md
- anthropics/skills — skill-creator/SKILL.md: https://raw.githubusercontent.com/anthropics/skills/main/skills/skill-creator/SKILL.md
- anthropics/skills — template/SKILL.md: https://github.com/anthropics/skills/blob/main/template/SKILL.md

**Popular repos torn down (live star counts via GitHub REST API, 2026-05-28)**
- obra/superpowers (211,074★): https://github.com/obra/superpowers
- hesreallyhim/awesome-claude-code (45,076★): https://github.com/hesreallyhim/awesome-claude-code
- wshobson/agents (36,089★): https://github.com/wshobson/agents
- davila7/claude-code-templates (27,646★): https://github.com/davila7/claude-code-templates
- alirezarezvani/claude-skills (16,445★): https://github.com/alirezarezvani/claude-skills
- travisvn/awesome-claude-skills (12,979★): https://github.com/travisvn/awesome-claude-skills
- anthropics/claude-plugins-community (138★, community marketplace): https://github.com/anthropics/claude-plugins-community

---

## Uncertainties / UNVERIFIED

- **`anthropics/skills` star count (142,827).** Verified live via GitHub API on 2026-05-28, but the figure is surprisingly high for a skills repo and a WebFetch summary independently reported ~143k; plausibly inflated by the repo's prominence. Treated as accurate per the API but flagged for re-confirmation.
- **superpowers 211,074★** likewise far exceeds typical skill repos; verified via API but unusually large — re-confirm before quoting in marketing.
- **Third-party blog star figures** (e.g. "alirezarezvani ~5,200★", "seo-geo-claude-skills 864★", "Pika-Skills 704★") are from secondary sources and conflict with live API numbers; UNVERIFIED — use the GitHub API as the source of truth.
- **superpowers having "no marketplace.json"** is from a WebFetch summary of the README, not a direct file listing; the repo may still contain a `.claude-plugin/marketplace.json`. UNVERIFIED — confirm by listing the repo tree if this detail is load-bearing.
- **Exact `~100 tokens` / `<5k tokens` / `25,000-token compaction budget` / `5,000-token re-attach` figures** are quoted from official docs as written; actual runtime token accounting may vary by model and version.
- **`allowed-tools` semantics differ** between the agentskills.io spec ("experimental, varies by agent") and Claude Code (well-defined permission grant). The cross-tool behavior of `allowed-tools` outside Claude Code is not guaranteed.
- **No specific AWS prices, CLI flags, or service feature names were asserted** in this note about AWS itself; any AWS-specific commands in §13 are illustrative patterns to be verified against current AWS CLI docs during the build phase, not confirmed facts.
