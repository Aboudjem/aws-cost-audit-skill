# Tests

Offline smoke tests for the `aws-cost-audit` scripts. No AWS credentials are required and no
network call is made. The suite exercises the pure-bash helpers in
`skills/aws-cost-audit/scripts/_lib.sh` and runs `doctor.sh` against a stubbed `aws` binary.

## Run

```bash
bash tests/smoke.sh
```

Expected output: `Results: 62 passed, 0 failed` and exit code `0`.

## What is tested

- `resolve_region`: explicit arg, `AWS_REGION` env, `AWS_DEFAULT_REGION` fallback
- `default_out_dir`: `OUT_DIR` override and default value
- `ensure_dir`: creates nested directories
- `log` / `info` / `warn`: output contracts (stderr, correct prefix)
- `die`: `[ERROR]` prefix, non-zero exit
- `doctor.sh`: exits 0 on a healthy stubbed environment, exits 1 with a named blocker when no
  region resolves, treats a missing `jq` as a warning rather than a blocker, skips the identity
  call under `--offline`, and leaves the billed Cost Explorer probe off unless it is asked for.
  It also accepts `--region`, names a missing `aws` CLI and an unwritable output directory as
  blockers, and removes an output directory it had to create, since it reports on an
  environment rather than furnishing one

- `ce_call` / `ce_paged_call` / `ce_report`: each Cost Explorer request is counted, the request
  over `AWS_COST_AUDIT_CE_BUDGET` is refused before it is sent, `--no-paginate` is always passed so
  one call is one billed request, a two-page result counts as two, and the per-request price is
  read from `references/pricing-verification.md` rather than hardcoded anywhere in a script. A
  malformed `AWS_COST_AUDIT_CE_BUDGET` falls back to the default instead of switching the cap
  off, and the spend is still reported when a script exits early, through an `EXIT` trap
- `00-baseline.sh` end to end against a stubbed `aws`: it completes, all six pulls carry
  `--no-paginate`, and the run reports six counted Cost Explorer requests

- `findings-validate.sh`: the good fixture passes, the deliberately broken one fails with every
  planted problem named (missing required key, value outside an enum, wrong type, unknown key,
  duplicate id, wrong boolean type, unknown top-level key), a machine without `jq` gets exit 2
  rather than a false pass, and a numeric cost is accepted as well as `null`

Fixtures live in `tests/fixtures/`. They use placeholders such as `vol-EXAMPLE` and `<region>`, so
no real account id, ARN, or resource id is committed, and every cost field is `null`, because
`CONTRIBUTING.md` forbids writing a monthly cost figure into any script, reference, example or
fixture. The case that exercises the numeric branch builds its file at run time from a computed
value, so no number is committed either.

`doctor.sh` is run with a replaced `PATH` pointing at a temporary directory that holds a fake `aws`
plus symlinks to the few real binaries the script needs. That makes "jq is absent" deterministic
rather than dependent on the machine running the suite.

AWS-connected behaviour (Cost Explorer calls, resource inventory, price verification) requires live
credentials and is covered by the skill's integration workflow described in
[CONTRIBUTING.md](../CONTRIBUTING.md).
