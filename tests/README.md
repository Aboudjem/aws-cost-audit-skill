# Tests

Offline smoke tests for the `aws-cost-audit` helper library. No AWS credentials are required — these tests exercise pure-bash helper logic in `skills/aws-cost-audit/scripts/_lib.sh` only.

## Run

```bash
bash tests/smoke.sh
```

Expected output: `Results: 10 passed, 0 failed` and exit code `0`.

## What is tested

- `resolve_region` — explicit arg, `AWS_REGION` env, `AWS_DEFAULT_REGION` fallback
- `default_out_dir` — `OUT_DIR` override and default value
- `ensure_dir` — creates nested directories
- `log` / `info` / `warn` — output contracts (stderr, correct prefix)
- `die` — `[ERROR]` prefix, non-zero exit

AWS-connected behaviour (Cost Explorer calls, resource inventory, price verification) requires live credentials and is covered by the skill's integration workflow described in [CONTRIBUTING.md](../CONTRIBUTING.md).
