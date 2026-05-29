# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project uses
[semantic versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-05-28

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

[Unreleased]: https://github.com/Aboudjem/aws-cost-audit-skill/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Aboudjem/aws-cost-audit-skill/releases/tag/v0.1.0
