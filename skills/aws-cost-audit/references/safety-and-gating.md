# Safety and gating

How a cost-audit change goes from "found waste" to "safely applied" without ever risking the user's
account. This file expands Iron Law 3 (nothing destructive unless proven-unused + reversible + tested
+ 100% sure) into a concrete, repeatable model. The auto-execute-vs-recommend flowchart lives in
`SKILL.md`, this file is the mechanics behind it.

Default posture: **read-only**. An audit produces findings and recommendations. A *change* is a
separate, deliberate, gated act, never a side effect of auditing.

## The gate: executor → verifier → rollback

Every change passes through three roles. Keep them as **separate passes**, the thing that makes a
change is not the thing that approves it.

1. **Executor**, performs the mutation, but only after the preconditions below are met. It is
   dry-run by default and refuses to mutate without an explicit `--apply` flag.
2. **Verifier**, a *separate* pass that re-derives the outcome from a primary source: did spend
   actually drop, did nothing else break, is the rollback artifact valid? The verifier never trusts
   the executor's own summary (Law 4: a separate skeptic re-derives load-bearing claims).
3. **Rollback**, the recorded, tested path back. If the verifier finds the blast radius was wrong,
   you restore from the artifact the executor saved *before* it touched anything.

A change is "done" only when the verifier confirms it from primaries, not when the executor exits 0.

### Preconditions before the executor may run (the gate criteria)

All four must hold. If any is "no" or "unsure", it is a **recommendation**, not an action.

- **Proven-unused via MULTIPLE signals over 30–90 days.** Not one probe, not "looks idle". Combine
  independent signals: zero relevant CloudWatch metric (e.g. request count, I/O ops, invocations,
  connections) over the window, no associations/references, no recent access-log entries, no recent
  CloudTrail activity. One green signal is a hint; several agreeing over 30–90d is evidence.
- **Reversible** by a concrete technique (see below). If the only way back is "hope", stop.
- **Tested in dry-run**, the exact command path ran read-only first and printed precisely what it
  would change, and you reviewed that output.
- **100% sure of the blast radius**, you can name every resource affected and every consumer of it.
  Any uncertainty downgrades to recommendation.

## Script conventions that enforce the gate

These are the patterns to reproduce in any generated remediation helper. Keep scripts generic and
parameterized (`$REGION`, resource id as an argument or env var), never hardcode an account id, ARN,
resource id, or price.

### 1. Dry-run by default, explicit `--apply` to mutate

The script does nothing destructive unless the caller passes `--apply`. With no flag it prints what
it *would* do and exits. Make the default safe so an accidental run is harmless.

```bash
set -euo pipefail
APPLY="${1:-}"
REGION="${REGION:?set REGION, e.g. export REGION=us-east-1}"

# ... read-only inspection / detection here, always runs ...

if [ "$APPLY" = "--apply" ]; then
  echo "APPLYING: <action>"
  # save rollback artifact FIRST (see below), then mutate
else
  echo "DRY-RUN. Pass --apply to execute."
fi
```

### 2. Save a rollback artifact BEFORE any mutation

The first thing the `--apply` branch does, before it deletes, detaches, or modifies, is persist the
current state to a file, so the resource can be reconstructed. For a load balancer that means saving
its listeners and target groups; for any resource, the relevant `describe-*` JSON.

```bash
if [ "$APPLY" = "--apply" ]; then
  # capture state to reconstruct from, BEFORE touching anything
  aws elbv2 describe-listeners --load-balancer-arn "$ARN" --region "$REGION" \
    > "rollback-${NAME}-listeners.json"
  aws elbv2 describe-target-groups --load-balancer-arn "$ARN" --region "$REGION" \
    > "rollback-${NAME}-tgs.json"
  aws elbv2 delete-load-balancer --load-balancer-arn "$ARN" --region "$REGION"
  echo "DONE. Rollback files saved to rollback-${NAME}-*.json"
fi
```

The rollback artifact is what the verifier checks and what a human restores from. No artifact → no
mutation.

### 3. Pre-flight guards that ABORT if a precondition fails

Before mutating, actively prove the resource is safe to touch. The strongest guard checks that **no
production consumer still references it** and aborts loudly if one does. This catches the classic
trap: a "dev" resource that a prod service is quietly still pointing at.

```bash
# Guard: confirm prod does NOT still reference the resource we're about to remove.
PROD_REF=$(aws <service> describe-... --region "$REGION" \
  --query '<path to the env var / endpoint that might point at this resource>' \
  --output text 2>/dev/null || echo "")
if echo "$PROD_REF" | grep -qi "<this-resource-marker>"; then
  echo "ERROR: a live service still references this resource. Re-route it first. Aborting."
  exit 1
fi
```

A guard that aborts on a failed precondition is worth more than any amount of caution in prose.
Re-check, in the script, the assumption that makes the action safe.

### 4. Per-item existence check + skip (idempotent, no surprises)

When acting on a list, verify each item still exists and report found/not-found before doing anything;
in the `--apply` pass, skip the ones that are gone. This keeps a re-run safe and makes the printed
plan match reality.

```bash
for ID in "${TARGETS[@]}"; do
  EXISTS=$(aws <service> describe-... --<id-flag> "$ID" \
    --query '<identifier>' --output text 2>/dev/null || echo "")
  if [ "$EXISTS" = "$ID" ]; then echo "  - $ID (found)"; else echo "  - $ID (NOT FOUND, skip)"; fi
done
```

### 5. Flag irreversible actions "CANNOT BE UNDONE" and exclude them from run-all

If an action cannot be rolled back, say so in the script header and in any summary table, and **keep
it out of any "run all" aggregator**. Irreversible steps run only by hand, one at a time, after the
operator reviews the exact list.

```bash
# <action>: CANNOT BE UNDONE. Review the list before --apply. Excluded from run-all.
```

A run-all helper composes only the reversible, gated scripts; irreversible ones are referenced with a
note to run them manually after review.

### Header convention

Each remediation script states, in its header, what it does, the savings *source* (where to verify
the dollar figure live, never a hardcoded price), the risk, and the rollback path. Example shape:

```bash
#!/usr/bin/env bash
# <action>. Verify savings live (Price List API / pricing page) for your region.
# Risk: <none/low/...>. Rollback: <recreate from rollback-*.json / re-enable / resize back>.
```

## Reversibility techniques

A change qualifies as reversible only if one of these concrete paths back exists and you have tested
it. "It's probably fine" is not reversibility.

- **Snapshot-before-delete.** Take a snapshot/backup of the volume or database, confirm it completed,
  *then* delete. Restore = create-from-snapshot. (Note: deleting the snapshot itself later is
  irreversible, see the never-auto-run list.)
- **S3 versioning + noncurrent-version retention.** With versioning on, a delete writes a delete
  marker and an object expiry moves the version to noncurrent rather than erasing it; a noncurrent-
  version retention window keeps it recoverable for N days. This makes object cleanup and lifecycle
  expiry **reversible within the window**. Verify deletes at the S3 origin, not via a CDN, because an
  edge cache can keep serving an object after it is removed at origin.
- **Detach-before-delete.** Detach the resource from its consumer first and run on the now-detached
  state for a while; if nothing breaks, then delete. The detached interval is your safety margin and
  the detach is itself trivially reversible (re-attach).
- **Deregister-AMI-before-snapshot-delete.** An AMI and its backing snapshots are linked; deregister
  the AMI before deleting the snapshots so the operation is ordered and inspectable. (The end state,   no AMI, no snapshot, is still irreversible; this only makes the path deliberate.)
- **Reversible config flips.** Retention changes (e.g. setting CloudWatch log `retentionInDays`),
  toggling enhanced monitoring/insights, disabling provisioned concurrency, scaling a non-prod
  service to zero, downsizing an instance, all restore by re-applying the prior value, which you
  saved in the rollback artifact. Low-risk and recoverable, but still go through dry-run first.

## The NEVER-AUTO-RUN list

These are **always recommendations requiring explicit human sign-off**, regardless of how confident
the evidence is. They are either irreversible or financially committing. They are excluded from any
run-all and never executed by the skill on its own:

- **Release an Elastic IP**, the address is gone and cannot be reclaimed.
- **Delete a snapshot or AMI**, the point-in-time data is unrecoverable.
- **Terminate an instance**, destroys instance state; instance-store data is lost.
- **Delete a bucket or its objects**, without (and even with) versioning, treat as destructive and
  sign-off-gated; verify at origin.
- **Purchase a Savings Plan or Reserved Instance**, a multi-month/multi-year financial commitment
  that cannot be undone. Always a recommendation with the math, never an auto-action.

For each, the skill outputs a labeled recommendation with current → after, the live-verified savings
math, confidence, evidence, and the explicit note that a human must approve and run it.

## Auto-execute vs recommend: quick recap

Full decision flow is the flowchart in `SKILL.md`. In short:

- **May auto-run** (via executor → verifier → rollback): items that are proven-unused by multiple
  signals over 30–90d **and** reversible by a tested technique **and** dry-run-tested **and** 100%
  certain of blast radius, and **not** on the never-auto-run list.
- **Recommend only** (report it with confidence + evidence + reversibility; do not run): anything
  unproven, unsure, irreversible, on the never-auto-run list, or financially committing.
- **When in doubt, recommend.** Downgrading a borderline action to a recommendation costs a little
  savings; a wrong destructive action costs data or uptime. The asymmetry always favors recommend.
