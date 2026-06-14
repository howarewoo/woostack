#!/usr/bin/env bash
# Contract test (issue #349): woostack-sweep must require a real woostack-review receipt
# before marking a PR `clean`, and must never mark `clean` from a self/structural review.
# Pure-prose assertion: the SKILL.md contract carries the load-bearing tokens.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../woostack-init/scripts/tests/assert.sh"
set +e

SKILL="$HERE/../../SKILL.md"
body="$(cat "$SKILL")"

# Part A — the clean verdict must be backed by a review receipt, not synthesized.
assert_contains "$body" "review receipt" \
  "sweep SKILL.md states a review-receipt requirement before clean"
assert_contains "$body" "self-review" \
  "sweep SKILL.md forbids marking clean from a self/structural review"

# The receipt rule must also be restated in Hard constraints (survives summarization /
# low-effort drivers), per gate-needs-hard-barrier. Scope the check to the Hard constraints
# section.
hard="$(printf '%s' "$body" | awk '/^## Hard constraints/{f=1} f')"
assert_contains "$hard" "receipt" \
  "the receipt rule is restated in sweep Hard constraints, not only in loop prose"

finish
