# 02 — Claude Code Plugin + Marketplace Spec (LOAD-BEARING)

> Research note for shipping a generic "AWS cost audit" Claude Code skill as a public GitHub repo.
> Goal: the install path MUST actually work. Everything below is sourced from the OFFICIAL Claude Code docs.
>
> **Important doc-location fact (verified):** The canonical docs now live at **`code.claude.com/docs/en/...`**.
> The older `docs.claude.com/en/docs/claude-code/plugins` and `.../plugins-marketplaces` URLs **301-redirect**
> to `code.claude.com/docs/en/plugins` and the marketplace page now lives at `code.claude.com/docs/en/plugin-marketplaces`
> (note: **no trailing `-marketplaces` plural on the old slug** — the new slug is `plugin-marketplaces`).
> Access date for all sources: **2026-05-28**.

---

## TL;DR — the exact install path a user runs

Two shippable distribution shapes. Both are confirmed by official docs.

### A) As a plugin via a GitHub marketplace (recommended for a public repo)

```shell
/plugin marketplace add <owner>/<repo>
/plugin install <plugin-name>@<marketplace-name>
/reload-plugins
```

- `<owner>/<repo>` is the GitHub repo that contains `.claude-plugin/marketplace.json` at its root.
- `<marketplace-name>` is the `name` field **inside `marketplace.json`** (NOT the repo name).
- After install, plugin skills are **namespaced**: `/<plugin-name>:<skill-name>`.

### B) As a plain drop-in skill (no plugin, no marketplace)

```
~/.claude/skills/<skill-name>/SKILL.md      # personal, all projects
.claude/skills/<skill-name>/SKILL.md        # project-scoped, this repo only
```

- The **directory name** becomes the command: `~/.claude/skills/aws-cost-audit/SKILL.md` → `/aws-cost-audit`.
- No install command needed; Claude Code auto-discovers it. Live change detection picks up new/edited skills within the session (a brand-new top-level skills dir requires a restart to begin being watched).

---

## (a) `.claude-plugin/marketplace.json` — exact fields + real example

**Location (verbatim):** "Create `.claude-plugin/marketplace.json` in your repository root."
Source: code.claude.com/docs/en/plugin-marketplaces

### Required top-level fields (verbatim table)

| Field     | Type   | Description |
| :-------- | :----- | :---------- |
| `name`    | string | Marketplace identifier (kebab-case, no spaces). This is public-facing: users see it when installing plugins (for example, `/plugin install my-tool@your-marketplace`). |
| `owner`   | object | Marketplace maintainer information (see owner fields) |
| `plugins` | array  | List of available plugins |

**Owner fields:** `name` (string, **required**), `email` (string, optional).

### Optional top-level fields (verbatim)
`$schema` (string — "JSON Schema URL for editor autocomplete and validation. Claude Code ignores this field at load time."), `description` (string), `version` (string), `metadata.pluginRoot` (string — base directory prepended to relative plugin source paths), `allowCrossMarketplaceDependenciesOn` (array). Note: "`description` and `version` are also accepted under `metadata` for backward compatibility."

### Reserved marketplace names (cannot be used by third parties) — verbatim
`claude-code-marketplace`, `claude-code-plugins`, `claude-plugins-official`, `anthropic-marketplace`, `anthropic-plugins`, `agent-skills`, `anthropic-agent-skills`, `knowledge-work-plugins`, `life-sciences`, `claude-for-legal`, `claude-for-financial-services`, `financial-services-plugins`. Names that impersonate official marketplaces (e.g. `official-claude-plugins`, `anthropic-tools-v2`) are also blocked.

### Plugin entry — required + key optional fields (verbatim)
Required per entry: `name` (string, kebab-case, public-facing) and `source` (string|object).
Marketplace-specific optional fields: `source`, `category`, `tags`, `strict`, plus you may include any field from the plugin manifest schema (`description`, `version`, `author`, `displayName`, `homepage`, `repository`, `license`, `keywords`, `defaultEnabled`, and component-path fields `skills`/`commands`/`agents`/`hooks`/`mcpServers`/`lspServers`).

`strict` (boolean, default `true`): "Controls whether `plugin.json` is the authority for component definitions." `true` = `plugin.json` is authority and marketplace entry can supplement (merged). `false` = the marketplace entry is the entire definition; if the plugin also has a `plugin.json` declaring components, that's a conflict and the plugin fails to load.

### Real example — minimal walkthrough marketplace.json (verbatim from docs)

```json
{
  "name": "my-plugins",
  "owner": {
    "name": "Your Name"
  },
  "plugins": [
    {
      "name": "quality-review-plugin",
      "source": "./plugins/quality-review-plugin",
      "description": "Adds a quality-review skill for quick code reviews"
    }
  ]
}
```

### Real example — fuller marketplace.json (verbatim from docs)

```json
{
  "name": "company-tools",
  "owner": {
    "name": "DevTools Team",
    "email": "devtools@example.com"
  },
  "plugins": [
    {
      "name": "code-formatter",
      "source": "./plugins/formatter",
      "description": "Automatic code formatting on save",
      "version": "2.1.0",
      "author": {
        "name": "DevTools Team"
      }
    },
    {
      "name": "deployment-tools",
      "source": {
        "source": "github",
        "repo": "company/deploy-plugin"
      },
      "description": "Deployment automation tools"
    }
  ]
}
```

### Plugin `source` types (verbatim table)

| Source        | Type   | Fields | Notes |
| :------------ | :----- | :----- | :---- |
| Relative path | `string` (e.g. `"./my-plugin"`) | none | Local directory within the marketplace repo. **Must start with `./`.** Resolved relative to the marketplace **root**, not the `.claude-plugin/` directory. |
| `github`      | object | `repo`, `ref?`, `sha?` | |
| `url`         | object | `url`, `ref?`, `sha?` | Git URL source |
| `git-subdir`  | object | `url`, `path`, `ref?`, `sha?` | Subdirectory within a git repo (sparse clone) |
| `npm`         | object | `package`, `version?`, `registry?` | Installed via `npm install` |

GitHub source example (verbatim): `{ "name": "github-plugin", "source": { "source": "github", "repo": "owner/plugin-repo" } }`. `ref` = branch/tag; `sha` = full 40-char commit SHA.

**Relative-path caveat (verbatim):** "Relative paths only work when users add your marketplace via Git (GitHub, GitLab, or git URL). If users add your marketplace via a direct URL to the `marketplace.json` file, relative paths will not resolve correctly." → For a public GitHub repo where users run `/plugin marketplace add owner/repo`, relative `./plugins/...` sources work because the whole repo is cloned.

---

## (b) `plugin.json` — exact fields + real example, and how it points at skills

**Location (verbatim):** "The manifest file at `.claude-plugin/plugin.json` defines your plugin's identity."
The manifest is **optional**: "If omitted, Claude Code auto-discovers components in default locations and derives the plugin name from the directory name."
Source: code.claude.com/docs/en/plugins , code.claude.com/docs/en/plugins-reference

### Required field (verbatim)
"If you include a manifest, `name` is the only required field." `name` = unique identifier (kebab-case, no spaces). "This name is used for namespacing components." e.g. agent `agent-creator` in plugin `plugin-dev` appears as `plugin-dev:agent-creator`.

### Quickstart manifest example (verbatim)

```json
{
  "name": "my-first-plugin",
  "description": "A greeting plugin to learn the basics",
  "version": "1.0.0",
  "author": {
    "name": "Your Name"
  }
}
```

Field notes from quickstart table (verbatim):
- `name` — "Unique identifier and skill namespace. Skills are prefixed with this (e.g., `/my-first-plugin:hello`)."
- `description` — "Shown in the plugin manager when browsing or installing plugins."
- `version` — "Optional. If set, users only receive updates when you bump this field. If omitted and your plugin is distributed via git, the commit SHA is used and every commit counts as a new version."
- `author` — "Optional. Helpful for attribution."

### Complete plugin.json schema (verbatim from plugins-reference)

```json
{
  "name": "plugin-name",
  "displayName": "Plugin Name",
  "version": "1.2.0",
  "description": "Brief plugin description",
  "author": {
    "name": "Author Name",
    "email": "author@example.com",
    "url": "https://github.com/author"
  },
  "homepage": "https://docs.example.com/plugin",
  "repository": "https://github.com/author/plugin",
  "license": "MIT",
  "keywords": ["keyword1", "keyword2"],
  "skills": "./custom/skills/",
  "commands": ["./custom/commands/special.md"],
  "agents": ["./custom/agents/reviewer.md"],
  "hooks": "./config/hooks.json",
  "mcpServers": "./mcp-config.json",
  "outputStyles": "./styles/",
  "lspServers": "./.lsp.json",
  "experimental": {
    "themes": "./themes/",
    "monitors": "./monitors.json"
  },
  "dependencies": [
    "helper-lib",
    { "name": "secrets-vault", "version": "~2.1.0" }
  ]
}
```

Metadata fields (verbatim): `$schema`, `displayName` (v2.1.143+, human-readable, may contain spaces, NOT used for namespacing), `version`, `description`, `author`, `homepage`, `repository`, `license`, `keywords`, `defaultEnabled` (boolean, v2.1.154+, default `true`; set `false` to install disabled).
"Claude Code ignores top-level fields it does not recognize." `claude plugin validate` reports unrecognized fields as warnings, not errors; wrong types still fail.

### How `plugin.json` points at / includes skills (load-bearing for our repo)

The plugin does **not** need to list skills explicitly. Default auto-discovery (verbatim file-locations table):

| Component | Default Location | Purpose |
| :-------- | :--------------- | :------ |
| Manifest  | `.claude-plugin/plugin.json` | Plugin metadata (optional) |
| Skills    | `skills/` | Skills with `<name>/SKILL.md` structure |
| Commands  | `commands/` | Skills as flat Markdown files. Use `skills/` for new plugins |
| Agents    | `agents/` | Subagent Markdown files |
| Hooks     | `hooks/hooks.json` | Hook configuration |
| MCP servers | `.mcp.json` | MCP server definitions |
| LSP servers | `.lsp.json` | Language server configurations |

Quickstart, verbatim: "Skills live in the `skills/` directory. Each skill is a folder containing a `SKILL.md` file. The folder name becomes the skill name, prefixed with the plugin's namespace (`hello/` in a plugin named `my-first-plugin` creates `/my-first-plugin:hello`)."

So for our AWS cost audit plugin, the minimal layout is:
```
aws-cost-audit/                 (plugin root)
├── .claude-plugin/
│   └── plugin.json             (name: "aws-cost-audit", ...)
└── skills/
    └── aws-cost-audit/
        └── SKILL.md            → invoked as /aws-cost-audit:aws-cost-audit
```

**Custom skill path override** (verbatim): `skills` field = "Custom skill directories containing `<name>/SKILL.md` (**in addition to** default `skills/`)." Path behavior rule: `skills` **adds to** the default (`skills/` is always scanned). By contrast `commands`/`agents`/`outputStyles`/`experimental.themes`/`experimental.monitors` **replace** their defaults. All path fields must be relative and start with `./`.

**Single-skill plugin shortcut** (verbatim): "A plugin that has a `SKILL.md` at its root, no `skills/` subdirectory, and no `skills` manifest field is automatically loaded as a single-skill plugin in Claude Code v2.1.142 and later." The invocation name = frontmatter `name`, or directory basename as fallback.

**CRITICAL layout warning** (verbatim): "Don't put `commands/`, `agents/`, `skills/`, or `hooks/` inside the `.claude-plugin/` directory. Only `plugin.json` goes inside `.claude-plugin/`. All other directories must be at the plugin root level."

**CLAUDE.md note** (verbatim): "A `CLAUDE.md` file at the plugin root is not loaded as project context... To ship instructions that load into Claude's context, put them in a skill."

---

## (c) EXACT commands to add a marketplace + install a plugin

Source: code.claude.com/docs/en/discover-plugins and code.claude.com/docs/en/plugin-marketplaces

### Add a marketplace from a GitHub repo (verbatim)

```shell
/plugin marketplace add anthropics/claude-code
```

"Add a GitHub repository that contains a `.claude-plugin/marketplace.json` file using the `owner/repo` format—where `owner` is the GitHub username or organization and `repo` is the repository name."

Other add forms (verbatim):
- Git URL (any host): `/plugin marketplace add https://gitlab.com/company/plugins.git`
- SSH: `/plugin marketplace add git@gitlab.com:company/plugins.git`
- Pin a branch/tag (git URL): append `#ref` → `/plugin marketplace add https://gitlab.com/company/plugins.git#v1.0.0`
- Local dir: `/plugin marketplace add ./my-marketplace`
- Local file: `/plugin marketplace add ./path/to/marketplace.json`
- Remote URL: `/plugin marketplace add https://example.com/marketplace.json`
- Shortcuts: "You can use `/plugin market` instead of `/plugin marketplace`, and `rm` instead of `remove`."

### Install a plugin (verbatim)

```shell
/plugin install plugin-name@marketplace-name
```

"Once you've added marketplaces, you can install plugins directly (installs to user scope by default)." Concrete example from docs: `/plugin install commit-commands@claude-code-plugins`.

### Activate / manage (verbatim)
- After installing: `/reload-plugins` — "reloads all active plugins and shows counts for plugins, skills, agents, hooks, plugin MCP servers, and plugin LSP servers."
- Disable: `/plugin disable plugin-name@marketplace-name`
- Enable: `/plugin enable plugin-name@marketplace-name`
- Uninstall: `/plugin uninstall plugin-name@marketplace-name`
- List marketplaces: `/plugin marketplace list`
- Update a marketplace: `/plugin marketplace update marketplace-name`
- Remove a marketplace: `/plugin marketplace remove marketplace-name` ("Removing a marketplace will uninstall any plugins you installed from it.")
- Interactive UI: run `/plugin` → tabs **Discover / Installed / Marketplaces / Errors**.

### Non-interactive CLI equivalents (verbatim)
`claude plugin marketplace add <source> [--scope user|project|local] [--sparse <paths...>]`,
`claude plugin install formatter@my-marketplace --scope project`,
`claude plugin uninstall ...`, `claude plugin list`, `claude plugin details <name>`, `claude plugin validate .` / `/plugin validate .`.

### Team / repo-level auto-config (verbatim)
In `.claude/settings.json`:
```json
{
  "extraKnownMarketplaces": {
    "my-team-tools": {
      "source": {
        "source": "github",
        "repo": "your-org/claude-plugins"
      }
    }
  }
}
```
And to enable specific plugins by default (verbatim):
```json
{
  "enabledPlugins": {
    "code-formatter@company-tools": true,
    "deployment-tools@company-tools": true
  }
}
```
"When team members trust the repository folder, Claude Code prompts them to install these marketplaces and plugins."

### Validate before shipping (verbatim)
```bash
claude plugin validate .
```
or `/plugin validate .`. "When pointed at a marketplace directory, the validator checks `marketplace.json` only." Validate a single plugin with `claude plugin validate ./plugins/my-plugin`. `--strict` treats warnings as errors (good for CI).

### Community marketplace (verbatim, for optional public listing)
```shell
/plugin marketplace add anthropics/claude-plugins-community
/plugin install <plugin-name>@claude-community
```
Submit via in-app forms (claude.ai/settings/plugins/submit or platform.claude.com/plugins/submit). "Run `claude plugin validate` locally before you submit."

---

## (d) Plain drop-in skill install — exact path

Source: code.claude.com/docs/en/skills

### Where skills live (verbatim table)

| Location   | Path | Applies to |
| :--------- | :--- | :--------- |
| Enterprise | See managed settings | All users in your organization |
| Personal   | `~/.claude/skills/<skill-name>/SKILL.md` | All your projects |
| Project    | `.claude/skills/<skill-name>/SKILL.md` | This project only |
| Plugin     | `<plugin>/skills/<skill-name>/SKILL.md` | Where plugin is enabled |

Verbatim quickstart: `mkdir -p ~/.claude/skills/summarize-changes` then save `SKILL.md` to `~/.claude/skills/summarize-changes/SKILL.md`. "The directory name becomes the command you type." → `/summarize-changes`.

Override precedence (verbatim): "enterprise overrides personal, and personal overrides project. Plugin skills use a `plugin-name:skill-name` namespace, so they cannot conflict with other levels."

### SKILL.md frontmatter — fields (verbatim)

```yaml
---
name: my-skill
description: What this skill does
disable-model-invocation: true
allowed-tools: Read Grep
---

Your skill instructions here...
```

"All fields are optional. Only `description` is recommended so Claude knows when to use the skill."

| Field | Required | Notes (verbatim/condensed) |
| :---- | :------- | :------------------------- |
| `name` | No | Display name in listings. Defaults to directory name. (Does NOT change the typed command except for a plugin-root `SKILL.md`.) |
| `description` | Recommended | What the skill does + when to use it. If omitted, uses first paragraph of content. **Combined `description` + `when_to_use` is truncated at 1,536 characters** in the skill listing. |
| `when_to_use` | No | Extra trigger context; appended to `description`; counts toward the 1,536-char cap. |
| `argument-hint` | No | Autocomplete hint, e.g. `[issue-number]`. |
| `arguments` | No | Named positional args for `$name` substitution. |
| `disable-model-invocation` | No | `true` = only the user can invoke (manual `/name`). Default `false`. |
| `user-invocable` | No | `false` = hide from `/` menu (Claude-only). Default `true`. |
| `allowed-tools` | No | Tools Claude may use without prompting while skill is active. Space/comma string or YAML list. Does NOT restrict the tool pool. |
| `disallowed-tools` | No | Tools removed from pool while skill active. |
| `model` | No | Model override for the turn. |
| `effort` | No | `low`/`medium`/`high`/`xhigh`/`max`. |
| `context` | No | `fork` = run in a forked subagent context. |
| `agent` | No | Subagent type when `context: fork`. |
| `hooks` | No | Hooks scoped to skill lifecycle. |
| `paths` | No | Glob patterns limiting auto-activation. |
| `shell` | No | `bash` (default) or `powershell`. |

**Command-name source (verbatim):** for a skill dir under `~/.claude/skills/` or `.claude/skills/`, the **directory name** is the command (e.g. `.claude/skills/deploy-staging/SKILL.md` → `/deploy-staging`). Frontmatter `name` is only the display label there. The one exception is a **plugin-root `SKILL.md`**, where frontmatter `name` sets the command (with plugin dir name as fallback).

**Useful for an AWS cost-audit skill:**
- `allowed-tools: Bash(aws *)` would pre-approve AWS CLI calls (syntax form `Skill(name *)` / `Bash(cmd *)` confirmed in docs). UNVERIFIED that `Bash(aws *)` specifically is documented — the docs show `Bash(git add *)`, `Bash(git commit *)`, `Bash(python3 *)`, `Bash(gh *)`; the pattern generalizes but the exact `aws` example is not in the docs.
- Dynamic context injection: `` !`<command>` `` runs a shell command and inlines its output before Claude sees the skill (verbatim). Multi-line via a fenced ```` ```! ```` block. Can be disabled org-wide via `"disableSkillShellExecution": true`.
- `${CLAUDE_SKILL_DIR}` resolves to the skill's own directory (verbatim) — use it to call bundled scripts regardless of CWD; works at personal/project/plugin levels.
- Keep `SKILL.md` under 500 lines (doc Tip); move reference material to supporting files.

---

## Plugin installation scopes (verbatim)

| Scope     | Settings file | Use case |
| :-------- | :------------ | :------- |
| `user`    | `~/.claude/settings.json` | Personal plugins across all projects (default) |
| `project` | `.claude/settings.json` | Team plugins shared via version control |
| `local`   | `.claude/settings.local.json` | Project-specific, gitignored |
| `managed` | Managed settings | Read-only, update only |

---

## Version management (verbatim, distilled)

Version resolves from the first set of: (1) `version` in `plugin.json`; (2) `version` in the marketplace entry; (3) the git commit SHA of the source (for `github`/`url`/`git-subdir`/relative-path-in-git sources); (4) `unknown` for `npm`/non-git local dirs.
- Set `version` = pinned; you MUST bump it every release or users get nothing on new commits.
- Omit `version` = every new commit is a new version (best for actively-developed repos).
- Do NOT set `version` in both `plugin.json` and the marketplace entry — `plugin.json` wins silently.

---

## ${CLAUDE_PLUGIN_ROOT} and friends (verbatim)
- `${CLAUDE_PLUGIN_ROOT}` — absolute path to the plugin's install dir; use for bundled scripts/configs in hooks, monitors, MCP/LSP. Changes on update; do NOT store state here.
- `${CLAUDE_PLUGIN_DATA}` — persistent dir surviving updates (resolves to `~/.claude/plugins/data/{id}/`).
- `${CLAUDE_PROJECT_DIR}` — project root.
- Plugins are copied to a cache (`~/.claude/plugins/cache`) on install, so paths that traverse outside the plugin root (`../shared-utils`) do NOT work.

---

## Decisions / recommendations for the AWS cost-audit repo

1. **Ship as a marketplace-in-the-same-repo plugin.** Repo root has `.claude-plugin/marketplace.json` (one plugin entry, `"source": "./<plugin-dir>"`), and the plugin dir has `.claude-plugin/plugin.json` + `skills/aws-cost-audit/SKILL.md`. Users: `/plugin marketplace add <owner>/<repo>` then `/plugin install aws-cost-audit@<marketplace-name>`.
2. **Also document the drop-in path** for users who don't want a plugin: `~/.claude/skills/aws-cost-audit/SKILL.md`. Same `SKILL.md` works in both shapes.
3. **Use a kebab-case name** for both the plugin and the marketplace; avoid the reserved names list above.
4. **Run `claude plugin validate . --strict` in CI** before publishing.
5. **Keep `description` keyword-rich but under the 1,536-char cap.**

---

## Sources

All accessed **2026-05-28**. Old `docs.claude.com/en/docs/claude-code/*` URLs 301-redirect to these `code.claude.com/docs/en/*` URLs.

- Create plugins: https://code.claude.com/docs/en/plugins (redirected from https://docs.claude.com/en/docs/claude-code/plugins)
- Create and distribute a plugin marketplace: https://code.claude.com/docs/en/plugin-marketplaces (old slug `plugins-marketplaces` now 404s; this is the live page)
- Plugins reference (complete schemas): https://code.claude.com/docs/en/plugins-reference
- Discover and install prebuilt plugins: https://code.claude.com/docs/en/discover-plugins
- Extend Claude with skills: https://code.claude.com/docs/en/skills
- Settings (scopes; plugin settings section not captured in fetched window — see uncertainties): https://code.claude.com/docs/en/settings
