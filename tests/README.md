# Tests

Offline smoke tests for the `aws-cost-audit` scripts. No AWS credentials are required and no
network call is made. The suite exercises the pure-bash helpers in
`skills/aws-cost-audit/scripts/_lib.sh` and runs `doctor.sh` against a stubbed `aws` binary.

## Run

```bash
bash tests/smoke.sh
```

Expected output: `Results: 32 passed, 0 failed` and exit code `0`.

## What is tested

- `resolve_region`: explicit arg, `AWS_REGION` env, `AWS_DEFAULT_REGION` fallback
- `default_out_dir`: `OUT_DIR` override and default value
- `ensure_dir`: creates nested directories
- `log` / `info` / `warn`: output contracts (stderr, correct prefix)
- `die`: `[ERROR]` prefix, non-zero exit
- `doctor.sh`: exits 0 on a healthy stubbed environment, exits 1 with a named blocker when no
  region resolves, treats a missing `jq` as a warning rather than a blocker, skips the identity
  call under `--offline`, and leaves the billed Cost Explorer probe off unless it is asked for

- `ce_call` / `ce_paged_call` / `ce_report`: each Cost Explorer request is counted, the request
  over `AWS_COST_AUDIT_CE_BUDGET` is refused before it is sent, `--no-paginate` is always passed so
  one call is one billed request, a two-page result counts as two, and the per-request price is
  read from `references/pricing-verification.md` rather than hardcoded anywhere in a script

`doctor.sh` is run with a replaced `PATH` pointing at a temporary directory that holds a fake `aws`
plus symlinks to the few real binaries the script needs. That makes "jq is absent" deterministic
rather than dependent on the machine running the suite.

AWS-connected behaviour (Cost Explorer calls, resource inventory, price verification) requires live
credentials and is covered by the skill's integration workflow described in
[CONTRIBUTING.md](../CONTRIBUTING.md).
