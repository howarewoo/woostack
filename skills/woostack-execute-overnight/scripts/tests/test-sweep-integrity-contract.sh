#!/usr/bin/env bash
# Contract test (issue #349): woostack-execute-overnight must not let an autonomous driver
# silently downgrade the contracted review sweep to a self-review and record `clean`.
# Three load-bearing prose clauses must be present:
#   B. pre-flight review feasibility (static infeasible -> refused-to-start)
#   C. a first-class `sweep-unavailable` run-level outcome (mid-run infeasible)
#   D. a driver rule: resolve-or-log-and-continue never means downgrade a contracted review
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../woostack-init/scripts/tests/assert.sh"
set +e

SKILL="$HERE/../../SKILL.md"
body="$(cat "$SKILL")"

# B — pre-flight feasibility gate for the review swarm.
assert_contains "$body" "review feasibility" \
  "overnight pre-flight checks review-swarm feasibility before going autonomous"

# C — the morning-report outcome enum gains a first-class sweep-unavailable value.
assert_contains "$body" "sweep-unavailable" \
  "overnight has a first-class sweep-unavailable outcome for an un-runnable contracted sweep"

# D — the no-downgrade driver rule, and it is restated in Hard constraints.
assert_contains "$body" "downgrade a contracted review" \
  "overnight forbids downgrading a contracted review under autonomy"
hard="$(printf '%s' "$body" | awk '/^## Hard constraints/{f=1} f')"
assert_contains "$hard" "downgrade" \
  "the no-downgrade rule is restated in overnight Hard constraints"

finish
