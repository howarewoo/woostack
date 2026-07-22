---
name: schema-unions-need-positive-branch-coverage
type: pattern
scope: tooling/evals/scripts/aggregate/**,tooling/evals/scripts/tests/test-aggregate.sh
tags: tests, schema, union, telemetry, identity, regression-coverage
hook: A schema union is not covered when tests exercise only one successful branch and invalid forms of the other — add a positive contract case for every supported branch.
updated: 2026-07-17
source: pr-538
---

When a persisted contract permits distinct valid representations, rejection tests for the unused
representation do not prove its success path. Keep at least one complete fixture for every supported
branch. For the eval aggregator this means both `model` and `sessionIdentity` completion identities,
and both concrete token telemetry and the `unavailable` sentinel.

Assert the downstream behavior, not only schema acceptance: successful aggregation, preserved
per-result values, and computed overall metrics or deltas. The same boundary rule applies to safety
authorities: pair the happy path with focused rejection cases for containment and private-parent
requirements, including an assertion that rejection leaves no published or temporary file.
