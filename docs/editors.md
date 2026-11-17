# Editor and agent support

`aws-cost-audit` is a skill-only plugin. There is no MCP server, no npm package, and no daemon.
The whole plugin is one `SKILL.md` plus reference documents and bash helper scripts, so any agent
that reads a `SKILL.md` can run it. The only runtime requirement is the AWS CLI, configured with
read access to the account you want to audit.

## One line per agent

The [Vercel skills CLI](https://github.com/vercel-labs/skills) installs this repo into whichever
agent you name with `-a`. `-g` installs for all your projects (your user profile). Drop `-g` to install into the current project only.

| Agent | Command | Where the skill lands (project / global) |
|:--|:--|:--|
| Claude Code | `npx skills add Aboudjem/aws-cost-audit-skill -g -a claude-code -y` | `.claude/skills/` / `~/.claude/skills/` |
| Cursor | `npx skills add Aboudjem/aws-cost-audit-skill -g -a cursor -y` | `.agents/skills/` / `~/.agents/skills/` |
| Codex | `npx skills add Aboudjem/aws-cost-audit-skill -g -a codex -y` | `.agents/skills/` / `~/.agents/skills/` |
| GitHub Copilot | `npx skills add Aboudjem/aws-cost-audit-skill -g -a github-copilot -y` | `.agents/skills/` / `~/.agents/skills/` |
| Gemini CLI | `npx skills add Aboudjem/aws-cost-audit-skill -g -a gemini-cli -y` | `.agents/skills/` / `~/.agents/skills/` |
| OpenCode | `npx skills add Aboudjem/aws-cost-audit-skill -g -a opencode -y` | `.agents/skills/` / `~/.agents/skills/` |
| Windsurf | `npx skills add Aboudjem/aws-cost-audit-skill -g -a windsurf -y` | `.windsurf/skills/` / `~/.codeium/windsurf/skills/` |
| Zed | `npx skills add Aboudjem/aws-cost-audit-skill -g -a zed -y` | `.agents/skills/` / `~/.agents/skills/` |
| Kimi Code CLI | `npx skills add Aboudjem/aws-cost-audit-skill -g -a kimi-code-cli -y` | `.agents/skills/` / `~/.agents/skills/` |

Omit `-a` and the CLI detects the agents you already have installed and asks which to use.
`npx skills add Aboudjem/aws-cost-audit-skill --list` prints what it found without installing.
The first six rows were installed with `-g` into a clean home folder with skills@1.9.0 on
2026-11-17; the global paths shown are where `SKILL.md` landed. The last three rows come from the
skills CLI's own supported-agents table and were not installed here. That table covers many more
agents, so check it if yours is missing.

## Claude Code plugin install

Claude Code can also install this as a plugin through the 10x marketplace, which is the path the
README leads with:

```bash
claude plugin marketplace add Aboudjem/10x
claude plugin install aws-cost-audit@10x
```

There is no direct-from-this-repo plugin path. This repo ships no
`.claude-plugin/marketplace.json` (the 10x marketplace is canonical), so
`claude plugin marketplace add Aboudjem/aws-cost-audit-skill` has nothing to resolve. Use the
10x marketplace, the skills CLI, or the manual copy below.

## install.sh

`install.sh <platform>` is the wrapper for the thirteen platform ids this repo has always
supported. It now delegates to `npx skills add` with the matching agent code:

```bash
curl -fsSL https://raw.githubusercontent.com/Aboudjem/aws-cost-audit-skill/main/install.sh | bash -s codex
```

| Platform id | skills CLI agent code |
|:--|:--|
| `gemini` | `gemini-cli` |
| `codex` | `codex` |
| `opencode` | `opencode` |
| `pi` | `pi` |
| `vibe` | `mistral-vibe` |
| `vscode` | `github-copilot` |
| `copilot` | `github-copilot` |
| `trae` | `trae` |
| `openclaw` | `openclaw` |
| `antigravity` | `antigravity` |
| `hermes` | `hermes-agent` |
| `cline` | `cline` |
| `kimi` | `kimi-code-cli` |

`all` applies to every platform. `--update` reinstalls the current version, `--uninstall` removes
it. `--legacy` skips the skills CLI entirely and uses the original symlink logic, which is what you
want on a machine with no `npx` or no network.

## Windows

`install.ps1` mirrors the legacy symlink behaviour for PowerShell:

```powershell
git clone https://github.com/Aboudjem/aws-cost-audit-skill
./aws-cost-audit-skill/install.ps1 copilot
```

Creating symlinks on Windows needs Developer Mode or an elevated shell. If it fails, copy the
skill directory by hand as described below.

## Manual copy

Nothing here is magic. Copy the skill directory into whatever context folder your agent reads:

```bash
git clone https://github.com/Aboudjem/aws-cost-audit-skill
cp -r aws-cost-audit-skill/skills/aws-cost-audit ~/.claude/skills/aws-cost-audit
```

The helper scripts under `skills/aws-cost-audit/scripts/` run on their own too. They need bash and
the AWS CLI, with `jq` recommended. Start with `doctor.sh`, which tells you what is missing before
an audit begins.

## No MCP server

Some plugins in the 10x marketplace ship an MCP server. This one does not, deliberately: it shells
out to the AWS CLI you already have, so there is no extra process, no extra trust boundary, and
nothing to configure in `.mcp.json`, `.cursor/mcp.json`, or `~/.codex/config.toml`. If an editor
asks you for an MCP command for this plugin, there is not one.
