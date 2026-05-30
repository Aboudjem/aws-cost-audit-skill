# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project uses
[semantic versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-05-30

Portability, discoverability, and presentation. No change to the skill's behaviour or its Iron Laws.

### Added

- Multi-CLI installer (`install.sh` and a PowerShell mirror `install.ps1`) that symlinks the
  `aws-cost-audit` skill into Gemini, Codex, OpenCode, pi, vibe, VS Code/Copilot, Trae, OpenClaw,
  Antigravity, Hermes, Cline, and Kimi. Skill-only, so it carries no MCP hint.
- Cross-editor plugin manifests `.cursor-plugin/plugin.json` and `.copilot-plugin/plugin.json`,
  mirroring `.claude-plugin/plugin.json` (no MCP block, since this is a skill-only plugin).
- A GitHub Pages landing page (`site/index.html`) and its deploy workflow
  (`.github/workflows/deploy-pages.yml`), reusing the shipped demo asset and the synthetic sample
  dashboard, every figure clearly labelled illustrative.
- Localized READMEs in `READMEs/` (Simplified Chinese, Japanese, Spanish, French), a language-switcher
  row, an install matrix, and a Star History chart in the README.
- `CLAUDE.md` contributor notes: the skill-only / no-MCP rationale, the installer target table, the
  manifest-sync list, and a version-bump checklist.
- Demo video: `assets/demo.gif` plus an `.mp4`.

### Changed

- Led the marketplace description with "read-only", and stated read-only in the SVG art.

### Fixed

- Animated SVGs now respect `prefers-reduced-motion` (and fixed a blank-step risk in the how-it-works diagram).
- Removed sentence-break em-dashes from every committed doc and from the script comments, replacing
  them with commas, colons, or parentheses.
- README no longer denies that a demo recording exists; the `assets/demo.gif` recording is now
  described as illustrative (synthetic data), keeping the synthetic-figures caveat intact.

### Removed

- The stray `.claude-plugin/marketplace.json`: its shape was inconsistent and the
  [10x marketplace](https://github.com/Aboudjem/10x) is canonical. The repo ships no marketplace
  manifest of its own.

## [0.1.0] - 2026-05-29

Initial release.

### Added

- The `aws-cost-audit` skill (`skills/aws-cost-audit/SKILL.md`): five Iron Laws, an ordered audit
  workflow, an auto-execute-vs-recommend decision gate, a quick-reference of the highest-ROI checks,
  one worked example, a rationalization table, and a red-flags list.
- Reference docs loaded on demand: `hunt-list.md`, `pricing-verification.md`, `safety-and-gating.md`,
  `output-and-reporting.md`, `dashboard.md`, and `why-these-laws.md` (the recorded baseline the Laws fix).
- Generic, parameterized helper scripts, dry-run by default with an explicit `--apply` gate and
  rollback artifacts: baseline pull, all-region inventory, idle finder, live price lookup, log-retention
  setter, gp2 to gp3, and gated unattached-EBS deletion.
- An optional HTML dashboard template plus a synthetic sample dashboard and sample report.
- Two install paths: a Claude Code plugin (`marketplace.json` + `plugin.json`) and a drop-in skill.
- GEO/AEO files (`llms.txt`, `AGENTS.md`), an animated SVG hero and "how it works" diagram, a social
  preview card, and a CI workflow that validates frontmatter, JSON, links, and scans for hardcoded
  prices, account IDs, and secrets.

[0.2.0]: https://github.com/Aboudjem/aws-cost-audit-skill/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/Aboudjem/aws-cost-audit-skill/releases/tag/v0.1.0
