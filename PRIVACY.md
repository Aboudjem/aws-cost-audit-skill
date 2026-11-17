# Privacy and AWS access

Short answer: it reads your AWS account with the AWS CLI you already have. It sends nothing to
anyone else. It changes nothing unless a change script runs with `--apply` and you confirm.

## Who sees your data

| Data                         | Where it goes                                                                                    |
| :--------------------------- | :----------------------------------------------------------------------------------------------- |
| Your AWS credentials         | Stay in your AWS CLI config. The skill never asks for keys and never reads the credentials file. |
| Cost and inventory output    | JSON files in `./cost-audit-out` on your machine. `.gitignore` blocks them from a commit.        |
| The report and the dashboard | Files on your machine. The dashboard loads a font and a chart library from a CDN when opened.    |
| What your agent reads        | Your agent's model provider sees what the agent reads, as with any agent session.                |

No telemetry. No third-party API. The only network calls the scripts make are AWS CLI calls to AWS.

## What the scripts call

Read-only calls, used by `doctor.sh`, `00-baseline.sh`, `inventory-regions.sh`, `find-idle.sh`
and `verify-price.sh`:

- `sts get-caller-identity`, `configure get region`
- `ce get-cost-and-usage`, `ce get-cost-forecast` (billed per request, counted and capped)
- `pricing get-products` (the live unit price; also what `verify-price.sh --recheck` re-runs)
- `ec2 describe-regions`, `describe-instances`, `describe-volumes`, `describe-snapshots`,
  `describe-addresses`, `describe-nat-gateways`, `describe-volumes-modifications`
- `elbv2 describe-load-balancers`, `describe-target-groups`, `describe-target-health`,
  `describe-listeners`
- `rds describe-db-instances`, `describe-db-snapshots`
- `elasticache describe-cache-clusters`
- `logs describe-log-groups`

Calls that change something exist in three scripts only. The code enforces these rules:

- Without `--apply`, each script prints a dry run and changes nothing.
- With `--apply`, it saves a rollback file first, then asks you to type `yes`.
- `--yes` skips that question. With no terminal and no `--yes`, it refuses before any change.
- `delete-unattached-ebs.sh --no-snapshot --apply` is refused unless `--yes` is also passed.

The skill also tells your agent to show you proof of non-use and the dry run, then wait for your yes.
That part is an instruction to the agent, not a check in the code.

| Script                     | Calls                                           | Undo                                       |
| :------------------------- | :---------------------------------------------- | :----------------------------------------- |
| `set-log-retention.sh`     | `logs put-retention-policy`                     | Old value saved; `delete-retention-policy` |
| `gp2-to-gp3.sh`            | `ec2 modify-volume`                             | `modify-volume --volume-type gp2`          |
| `delete-unattached-ebs.sh` | `ec2 create-snapshot`, `ec2 wait snapshot-completed`, then `ec2 delete-volume` | `ec2 create-volume` from the snapshot      |

Following `SKILL.md`, your agent may also run read-only commands of its own, such as
`cloudwatch get-metric-statistics`, `cloudtrail lookup-events` or
`compute-optimizer get-ec2-instance-recommendations`. They are listed with their purpose in
[the hunt list](skills/aws-cost-audit/references/hunt-list.md).

## The least access that works

The AWS managed `ReadOnlyAccess` policy plus billing read (`ce:Get*`, `pricing:GetProducts`) is
enough for the audit. Grant a write permission only for the one gated action you choose to run.
