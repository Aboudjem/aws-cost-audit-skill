# Viral-Readiness Audit — aws-cost-audit-skill

_Engine run: 2026-05-30 · Supernova standard_

## Score summary

| Signal | Value |
|---|---|
| **Score** | 92 → 100 / 100 |
| **Tier** | 1 — production-ready / viral-ready |
| **Repo type** | claude-plugin |
| **Recommended packaging** | plugin |

## Gaps found by engine (pre-pass)

| Gap | Weight | Status |
|---|---|---|
| `has_tests` — no `tests/` directory | +8 | Fixed — see `tests/` |

## What was already present (no changes made)

- `AGENTS.md` — cross-harness agent context (do not duplicate)
- `llms.txt` — LLM/GEO citeability layer (do not duplicate)
- GitHub releases published
- `skills/*/references/` progressive-disclosure structure
- Demo GIF + hero SVG + dashboard preview
- Star history chart, multi-language READMEs (zh-CN, ja, es, fr)
- All 5 requested topics already on the repo (`claude-code`, `claude-code-plugin`, `aws`, `finops`, `cost-optimization`) plus 10 more. No changes needed.
- Description (155 chars) is keyword-first and strong. No changes needed.

## What this pass added

1. **`tests/smoke.sh`** — offline smoke test for `_lib.sh` helpers (no AWS credentials required). Tests: `resolve_region` env-var path, `default_out_dir` override, `ensure_dir` creation, `log`/`info`/`warn`/`die` output contracts. Runs in ~100 ms anywhere with bash. See `tests/README.md` for how to run.
2. **`tests/README.md`** — one-paragraph run guide.
3. **`docs/VIRAL-AUDIT.md`** — this file.
4. **`docs/LAUNCH-PLAN.md`** — June 2026 channel-sequenced launch plan.

## Engine assessment

The engine correctly identified the single remaining gap (`has_tests`). Type (`claude-plugin`) and packaging (`plugin`) are accurate — the repo ships a Claude Code skill via a plugin manifest with no MCP server, matching the packaging recommendation exactly. No false gaps were observed. The "add AGENTS.md" suggestion in the packaging note was already satisfied; the engine's bonus-signal detection correctly flagged it as present.

## Two-sentence read

This skill is a surgical FinOps tool for Claude Code: it audits a live AWS account with live prices, zero hardcoded values, and a read-only-first safety model that mirrors the AWS Well-Architected cost-optimization pillar. The repo is production-grade (demo GIF, dashboard, multi-language docs, multi-CLI installer, releases) and is one well-placed community post away from breakout growth in the r/aws and FinOps Foundation audiences.
