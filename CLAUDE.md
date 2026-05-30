# CLAUDE.md: AWS Cost Audit Skill

Contributor notes for the portability and discoverability layer. Keep them current when you touch the related files. Human-facing docs live in `README.md`; agent-invocation context lives in `AGENTS.md`.

## Skill-only, no MCP

This repo ships a single Claude Code skill, `aws-cost-audit`, and nothing else. There is **no MCP server**, no npm package, and no `agents/` directory. The skill loads `skills/aws-cost-audit/SKILL.md` into the host CLI's context and shells out to the AWS CLI (read-only by default). Because there is no MCP server, the installer carries no `--no-mcp` flag and prints no MCP hint: it only symlinks the skill directory.

### Host-agnostic agents (#167 rationale)

This repo has no `agents/` directory, so there is no `model:` frontmatter to strip. If agents are ever added, omit `model:` from their frontmatter so each host CLI falls back to its own default model. A literal `model: inherit` is a Claude-Code-only keyword that some hosts (for example OpenCode) reject as an unknown model id, which is why host-agnostic plugins carry only `name` and `description`. Today this note is precautionary only: there are no agents to fix.

## Multi-CLI installer target directories

`install.sh` and `install.ps1` symlink the single skill (`aws-cost-audit`) into a CLI's skills directory. Current map:

| Platform | Directory | Style |
|:--|:--|:--|
| gemini, codex, opencode, pi | `~/.agents/skills` | per-skill |
| vscode, copilot | `~/.copilot/skills` | per-skill |
| trae | `~/.trae/skills` | per-skill |
| vibe | `~/.vibe/skills` | per-skill |
| openclaw | `~/.openclaw/skills` | folder |
| antigravity | `~/.gemini/antigravity/skills` | folder |
| hermes, cline, kimi | `~/.<cli>/skills` | folder |

Because there is only one skill, the per-skill and folder styles both link `skills/aws-cost-audit` as `aws-cost-audit` in the target directory; the styles differ only in how multi-skill plugins lay out their links. These conventions change between CLI releases. When one drifts, update `install.sh` (`platform_target`), `install.ps1` (`Get-PlatformTarget`), and the install matrix in the README together.

## Manifests to keep in sync

Three plugin manifests must stay aligned on `name`, `version`, and `description`: `.claude-plugin/plugin.json`, `.cursor-plugin/plugin.json`, `.copilot-plugin/plugin.json`. The Claude Code manifest auto-discovers the skill from `skills/aws-cost-audit/` and therefore carries **no** `skills` field (the Claude Code plugin schema rejects one, `claude plugin validate` fails with `skills: Invalid input`). The Cursor and Copilot mirrors list `"skills": ["aws-cost-audit"]` because those formats expect an explicit list. None of the three carries an `mcp` block, because this is a skill-only plugin. There is **no** `.claude-plugin/marketplace.json` in this repo: the [10x marketplace](https://github.com/Aboudjem/10x) is canonical and holds the marketplace manifest.

## Version-bump checklist

When cutting a release, bump the version in every version-carrying file and add a `CHANGELOG.md` entry:

- `.claude-plugin/plugin.json`
- `.cursor-plugin/plugin.json`
- `.copilot-plugin/plugin.json`
- `CHANGELOG.md` (new dated section per Keep a Changelog)

There is no `package.json` to bump (no npm package). The installer, the discovery manifests, `READMEs/`, and `site/` are repo-only and are not published to any registry.

## GitHub Pages

`site/index.html` is deployed by `.github/workflows/deploy-pages.yml` (`concurrency: pages`). It reuses the already-shipped demo assets (`assets/demo.gif`, `assets/hero.svg`, `assets/dashboard-preview.png`) and the synthetic `examples/sample-dashboard.html`; it does not rebuild them. Pages must be set to deploy from GitHub Actions in the repo settings. Keep every `illustrative` / synthetic-data label intact: the demo and samples use no real AWS account.
