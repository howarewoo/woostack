#!/usr/bin/env bash
# Contract test: every fresh sweep verdict is classified before the blocking-only
# cap/no-progress backstops, including a verdict returned on the final allowed round.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../woostack-init/scripts/tests/assert.sh"
set +e

SKILL="$HERE/../../SKILL.md"
body="$(cat "$SKILL")"

loop="$(printf '%s' "$body" | awk '/^## The per-PR loop/{f=1; next} /^## Termination backstop/{f=0} f')"
loop_flat="$(printf '%s' "$loop" | tr '\n' ' ' | tr -s ' ')"
assert_contains "$loop_flat" "On every round, including the final allowed round" \
  "sweep classifies no-blocking verdicts on first, later, and final rounds"
assert_contains "$loop_flat" 'classify the fresh `STATUS_LINE` before evaluating `max_rounds` or the no-progress guard' \
  "fresh verdict classification precedes both blocking backstops"
assert_contains "$loop_flat" "**No blocking findings + zero unresolved threads**" \
  "a no-blocking verdict with no threads advances through the clean branch"
assert_contains "$loop_flat" "**No blocking findings + open threads**" \
  "a no-blocking verdict with threads advances through the done-with-findings branch"

termination="$(printf '%s' "$body" | awk '/^## Termination backstop/{f=1; next} /^## Per-PR outcome vocabulary/{f=0} f')"
termination_flat="$(printf '%s' "$termination" | tr '\n' ' ' | tr -s ' ')"
assert_contains "$termination_flat" "only while the latest receipt-backed verdict still has blocking findings" \
  "cap and no-progress may terminate only a still-blocking latest verdict"

hard="$(printf '%s' "$body" | awk '/^## Hard constraints/{f=1} f')"
assert_contains "$hard" "Verdict before backstop" \
  "verdict-first ordering is preserved in sweep Hard constraints"

finish
