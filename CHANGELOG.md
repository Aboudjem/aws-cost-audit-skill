# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project uses
[semantic versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.1] - 2026-09-03

A motion identity, and the literal synthwave scenery removed. No behaviour changes.

### Changed

- **Every asset is rebuilt around one principle:** the whole mark is drawn once as a muted track,
  and a single bright element travels over it, so no frame of the loop is an incomplete logo and
  the reduced-motion resting frame is the finished mark. This plugin's motion is
  a cost curve bending down over a coin while the figures beneath it count down.
- **The scenery is gone.** No sun disc, no horizon line, no perspective grid and no band cuts in
  any tracked SVG. The palette, the soft dual-tone wash, the restrained glow and the mono eyebrows
  stay.
- **Zero SMIL.** Every animation is now CSS, gradient colour drift included, so the
  `prefers-reduced-motion` guard reaches all of it. Verified by phase offset in a single page load,
  not by two renders at different virtual-time budgets, which gives a false negative.
- **More vibrant, still readable.** The ground is lifted off near-black and tinted with this
  plugin's own hue, every gradient drifts between two accents, and every text fill was re-measured
  against the ground it actually ships on. Tightest pair in this repo: 5.53:1.

### Added

- `assets/logo-mark-animated.svg` and `assets/logo-mark-animated-light.svg`, a 256x256 animated mark on a
  rounded tile, under 6 KB each, with dark and light variants.
- `logo-mark.png`, `logo-mark-512.png` and `social-preview.png` are now headless-Chrome renders of
  the mark's reduced-motion resting frame, so the raster is reproducible from the vector by one
  command and cannot drift from it.

## [0.3.0] - 2026-09-02

Three helpers that make a run checkable before, during, and after it happens, plus a new visual
identity and a README rebuilt around it. No change to the Iron Laws: the skill is still read-only
by default and still refuses to quote a price from memory.

### Added

- `skills/aws-cost-audit/scripts/doctor.sh`: a preflight check that names what is missing before
  an audit starts. It probes the AWS CLI, caller identity, `jq`, region resolution, and a writable
  output directory, then lists any blocker and exits 1. `--offline` skips everything needing
  credentials; the Cost Explorer probe is behind `--check-cost-explorer` because that request is
  billed. It has no apply flag and removes the probe file it wrote. Covered by
  `tests/smoke.sh`.
- A Cost Explorer request budget in `scripts/_lib.sh`. `ce_call` counts each request and refuses
  the one past `AWS_COST_AUDIT_CE_BUDGET` (default 50) before sending it; `ce_paged_call` walks
  pages explicitly so every billed page is counted; `ce_report` prints the count and the estimated
  spend. `00-baseline.sh` routes its pulls through the wrapper. Covered by `tests/smoke.sh` with a
  stubbed `aws` on `PATH`.
- A machine-readable `findings.json` contract, pinned in `references/output-and-reporting.md`:
  nine required keys per finding, eight optional ones, unknown keys rejected.
  `scripts/findings-validate.sh` checks a file with jq and exits 0 valid, 1 with one line per
  problem, 2 when it could not check at all. Fixtures and cases in `tests/`.
- `docs/editors.md`: one install line per agent for Claude Code, Cursor, Codex, GitHub Copilot,
  Gemini CLI, OpenCode, Windsurf, Zed and Kimi Code CLI, the platform-id map, Windows, the manual
  copy path, and a plain statement that this plugin ships no MCP server.
- `docs/faq.md` and `docs/comparison.md`, holding the FAQ, the five Iron Laws in short form, and
  the comparison table that used to sit in the README.
- A Neon Noir visual identity: `assets/logo-dark.svg`, `logo-light.svg`, `hero-dark.svg`,
  `hero-light.svg`, `social-preview.svg`, the raster mark `logo-mark.png` and `logo-mark-512.png`,
  and a regenerated 1280x640 `social-preview.png`.
- Release workflow: pushing a `vX.Y.Z` tag now creates the GitHub release and tells the 10x
  marketplace to re-sync (`.github/workflows/release.yml`).

### Changed

- `install.sh` now delegates to the Vercel skills CLI by default, running
  `npx --yes skills@1.5.23 add Aboudjem/aws-cost-audit-skill -a <agent>` for the platform you name.
  All thirteen platform ids map to a supported agent code. `--legacy` keeps the original symlink
  logic reachable and is the automatic fallback when `npx` is missing. `--update` and `--uninstall`
  work on both paths.
- README rewritten to 161 lines from 254: a light and dark hero, jump links, the install command
  above the first heading, one install table instead of seven code blocks, and one line per
  improvement. The seven-step walkthrough moved into `docs/quickstart.md`, the FAQ into
  `docs/faq.md`, the comparison into `docs/comparison.md`. Star History removed.
- The four localized READMEs in `READMEs/` rewritten from the new English text.
- `assets/hero.svg` and `assets/how-it-works.svg` restyled in place on the new palette. Every SVG
  keeps its `prefers-reduced-motion` guard and carries no `<script>` and no external reference.
- `install.ps1` now states in its own output that PowerShell is the legacy symlink path.
- Version moved to 0.3.0 in `.claude-plugin/plugin.json`, `.cursor-plugin/plugin.json`, and
  `.copilot-plugin/plugin.json`.

### Fixed

- A malformed `AWS_COST_AUDIT_CE_BUDGET` used to switch the ceiling off, because the integer test
  errored on a non-numeric operand and the caller read that as "under budget". The value is now
  validated, and `ce_report` runs on an early exit as well as at the end of a run, which is when
  the number matters most.
- `doctor.sh` advised passing `--region` when the region could not be resolved, but had no such
  option. It now accepts `--region REGION`. It also used to leave behind an output directory it
  had created, and now removes one it had to create.
- The `findings.json` test fixtures carried monthly cost figures, which `CONTRIBUTING.md` forbids
  in any script, reference, or example. Every cost field in a committed fixture is now `null`, and
  the case that exercises the numeric branch builds its file at run time.

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

[0.3.0]: https://github.com/Aboudjem/aws-cost-audit-skill/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/Aboudjem/aws-cost-audit-skill/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/Aboudjem/aws-cost-audit-skill/releases/tag/v0.1.0
