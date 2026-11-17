.PHONY: test lint

# The full offline suite: no AWS call, no credentials. Needs bash and jq.
test:
	bash tests/smoke.sh

# Shell lint at the level CI enforces. Warning level flags variables that
# _lib.sh reads (ASSUME_YES) and env prefixes in tests, which are false positives.
lint:
	shellcheck -S error install.sh skills/aws-cost-audit/scripts/*.sh tests/smoke.sh
