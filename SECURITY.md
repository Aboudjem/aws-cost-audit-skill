# Security Policy

This skill reads a **live AWS account** using the operator's own credentials, so security is part of
its design, not an afterthought.

## How the skill is built to be safe

- **Read-only by default.** Discovery uses only `describe` / `list` / `get` calls. Nothing is
  deleted, stopped, or changed unless you explicitly run a gated action and confirm it.
- **No secrets shipped.** The repo contains no credentials, no account IDs, no ARNs, and no API
  keys. It uses whatever AWS CLI credentials are already on your machine.
- **No data leaves your machine.** The skill runs locally and talks only to AWS. It does not send
  your account data to any third party, and it has no telemetry.
- **No hardcoded prices.** Every dollar figure is fetched live from the AWS Price List API for your
  region, so there is nothing stale or fabricated to mislead a cost decision.
- **Helper scripts are dry-run by default** and refuse destructive actions without an explicit
  `--apply` flag, a passed safety gate, and your confirmation.

## What counts as a security issue here

Please report any of the following:

- A script or instruction that could run a **destructive or mutating** AWS action without the gate
  (proven-unused + reversible + tested + confirmed).
- Anything that could **leak or log credentials**, account IDs, ARNs, or other sensitive data.
- A **hardcoded account-specific value or price** that slipped into the skill, a script, or an
  example.
- A path that could write your account's audit output somewhere it might be committed or shared.

## Reporting a vulnerability

**Please do not open a public issue for a security problem.**

Email **boudjemaa.adam@gmail.com** with:

- A description of the issue and its impact.
- Steps to reproduce (redact any real account IDs, ARNs, or IPs).

You will get a response within 48 hours. Once a fix is ready, the issue will be disclosed
responsibly with credit to the reporter if wanted.

## Your responsibility when running it

- Use credentials scoped to what you need. `ReadOnlyAccess` (plus Cost Explorer / Billing read) is
  enough for the audit itself.
- Never paste real account IDs, ARNs, or audit output into a public issue or pull request.
