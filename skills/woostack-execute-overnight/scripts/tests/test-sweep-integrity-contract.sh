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

# B — pre-flight feasibility gate for the review swarm. Scope to the Pre-flight
# section and pin a token unique to step 3, so deleting step 3 fails the test even
# if Hard constraints keeps the lowercase "review feasibility" phrase.
preflight="$(printf '%s' "$body" | awk '/^## Pre-flight/{f=1; next} /^## [A-Z]/{f=0} f')"
assert_contains "$preflight" "spawn the \`woostack-review\` sub-agents" \
  "overnight pre-flight step 3 checks review-swarm feasibility before going autonomous"

# C — the morning-report outcome enum gains a first-class sweep-unavailable value.
# Pin the slash-joined enum listing so moving the token to prose or Hard constraints
# (while dropping it from the Run summary enum) fails the test.
assert_contains "$body" "\`partial+blockers\` / \`sweep-unavailable\`" \
  "overnight Run summary enum lists sweep-unavailable as a first-class outcome"

# D — the no-downgrade driver rule, and it is restated in Hard constraints.
assert_contains "$body" "downgrade a contracted review" \
  "overnight forbids downgrading a contracted review under autonomy"
hard="$(printf '%s' "$body" | awk '/^## Hard constraints/{f=1} f')"
assert_contains "$hard" "downgrade" \
  "the no-downgrade rule is restated in overnight Hard constraints"

finish
