# Why these Iron Laws exist (the recorded baseline)

This skill was built test-first. Before writing it, we ran realistic cost-audit pressure scenarios
on agents that did **not** have the skill, on two model tiers, and recorded exactly how they failed.
Each Iron Law fixes a failure we actually observed. Full transcript-level evidence:
`docs/research/RED-baseline-findings.md` in the repo.

## What the baseline got wrong

**1. Price hallucination, fired every time a dollar figure was requested, on every model tier.**
Asked "how much will I save migrating ~2 TB gp2→gp3 and deleting 8 RDS snapshots?", agents stated
memorized unit prices (gp2 `$0.10`, gp3 `$0.08`, RDS backup `$0.095` per GB-mo) with no live
verification, and produced different confident headline numbers from the *same inputs*: one model
answered **"~$40/month"**, another **"$71.36/month"** (~78% apart). The weaker model also dropped
all caveats and confidence labels, rationalizing: *"these are publicly documented rates… rounded to
$71 for slide readability."* Memorized prices are Region-specific and change over time.
→ **Law 1: no unverified price, ever.**

**2. No standardized evidence contract.** Each agent invented its own output shape. Confidence,
evidence, and reversibility appeared on the strong model but were **omitted entirely** by the weak
one. A reader had no guarantee of getting per-item confidence + evidence + rollback.
→ **Law 5: every finding carries its evidence; fixed per-item contract.**

**3. Ad-hoc, incomplete coverage.** Each agent reconstructed a *different, partial* method from
scratch. None produced a complete all-Region/all-service hunt list, a "save-now-safely vs
max-theoretical" split, a generated dashboard, a health view, or a skeptic re-derivation.
→ **Workflow + hunt list + completeness pass; Law 4 (fan-out + skeptic).**

**4. Safety held on strong models, but is not guaranteed.** The strong baseline refused blatant
"just delete it" requests and demanded reversibility; good. But this is a model *instinct*, the
first thing to slip under pressure or on cheaper models. The skill makes the gate explicit so it
holds regardless of model.
→ **Law 3: nothing destructive unless proven-unused + reversible + tested + 100% sure.**

## The point

The skill turns an ad-hoc, model-dependent, price-hallucinating response into a complete,
consistent, evidence-first, live-verified audit that behaves the same way on Haiku, Sonnet, and
Opus. The rationalization table and red-flags list in `SKILL.md` are the exact excuses the baseline
used, kept close to hand so future runs catch themselves.
