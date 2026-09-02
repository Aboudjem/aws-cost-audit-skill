# Launch Plan: aws-cost-audit-skill

_June 2026 · borrowed-reach first_

## Situation

- **Repo type:** Claude Code plugin (skill-only, no MCP server)
- **Audience:** AWS account owners, FinOps practitioners, DevOps/platform engineers
- **Differentiator:** evidence-first, live prices, read-only-default, Well-Architected aligned
- **Star baseline:** early-stage; target +150 stars in first 30 days
- **Constraint:** no cold Show HN as the opening move, borrow reach first

---

## Phase 1: Seed (June 2–6): warm audiences only

Goal: 5–10 organic shares before any public post. These people already care; no selling required.

| Action | Channel | Owner |
|---|---|---|
| Post in r/ClaudeAI "I built an AWS cost-audit skill for Claude Code" | r/ClaudeAI | Adam |
| Share in r/aws weekly "What are you building?" thread | r/aws | Adam |
| Drop in FinOps Foundation Slack `#tools` channel with a one-paragraph note | FinOps Slack | Adam |
| Ping 2–3 FinOps practitioners on LinkedIn who post about AWS cost tooling | LinkedIn DM | Adam |

**Post angle:** "I ran Claude against my AWS bill. Here's what it found, and how I built the skill so it never guesses a price." Lead with a concrete dollar figure from the sample report.

---

## Phase 2: Amplify (June 9–13): community posts with borrowed reach

Goal: +80–120 stars. Each post references real evidence (sample report, sample dashboard).

### r/aws (primary)

Title: `I taught Claude Code to audit AWS bills: prices verified live, nothing deleted without proof`

- Lead with the comparison table (skill vs manual audit vs SaaS dashboard)
- Embed the sample dashboard screenshot
- Link to the sample report so skeptics can read the output before starring
- Do NOT over-sell. Engineers trust evidence, not claims.

### r/devops

Title: `Read-only AWS cost auditor for Claude Code: every dollar has a source, nothing runs unconfirmed`

- Angle: safety model (Iron Laws, dry-run by default, executor→verifier→rollback gate)
- This audience cares about blast radius more than savings %

### FinOps Foundation community forum / LinkedIn group

- Write a short "how we applied the FinOps framework in a Claude Code skill" note
- Reference the FinOps Foundation framework and Well-Architected cost pillar explicitly
- Link the `docs/research/RED-baseline-findings.md`, the recorded failure baseline is compelling

### LinkedIn article (Adam's feed)

Title: `Why I built an AI cost auditor that refuses to guess an AWS price`

- 400-word article, not a link post
- Hook: "Two models, same question, two different wrong numbers from memory."
- Body: the five Iron Laws, why each one exists, one concrete example saving
- CTA: GitHub link + "try it on your own account in 10 minutes"

---

## Phase 3: Second wave (June 16–20): SEO + GEO long tail

Goal: passive inbound from searches and AI citations.

| Action | Rationale |
|---|---|
| Ensure `llms.txt` is indexed (it is, already shipped) | AI search engines cite it directly |
| Open a "Community savings reports" discussion on GitHub Discussions | Social proof accumulates; users share what they found |
| Submit to Awesome Claude Code list (if one exists) and Awesome FinOps | Passive referral traffic |
| Write a `site/` blog post: "How the skill verifies an AWS price in 3 steps" | Targets long-tail query "aws cost audit ai tool" |
| Post a short LinkedIn update with a before/after screenshot (synthetic data) | Triggers algorithm amplification for prior article readers |

---

## What NOT to do

- **No cold Show HN as the opener.** HN rewards novelty + technical depth; wait until there are real community saves to quote, then post as "Show HN: an AWS cost-audit skill for Claude Code, here's what real users found."
- **No generic "check out my project" posts.** Every post must lead with evidence: a dollar figure, a screenshot, a failure the skill prevents.
- **No mass-DM campaigns.** One thoughtful DM to a relevant practitioner > 50 generic ones.

---

## Realistic star expectation

| Phase | Stars |
|---|---|
| After Phase 1 (seed) | +5–15 |
| After Phase 2 (community posts) | +80–140 |
| After Phase 3 (second wave + SEO) | +30–60 additional |
| **30-day total** | **~120–200** |

The ceiling is higher if one r/aws post hits the front page (r/aws has 2M+ members; a well-timed post with a compelling title routinely reaches 500+ upvotes). The floor is ~50 if posts land on low-traffic days.

---

## Launch checklist

- [x] Warm channels first (community before cold outreach)
- [x] Evidence-led posts (sample report + dashboard as social proof)
- [x] Cross-platform (Reddit + LinkedIn + FinOps Slack + GitHub Discussions)
- [x] Second wave planned (SEO/GEO + community saves accumulation)
- [x] Realistic expectations (no "go viral overnight" assumption)
