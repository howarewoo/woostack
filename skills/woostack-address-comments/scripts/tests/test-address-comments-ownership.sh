#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
ADDRESS_SKILL="$ROOT/skills/woostack-address-comments/SKILL.md"
REVIEW_SKILL="$ROOT/skills/woostack-review/SKILL.md"
ADDRESS_PROMPT="$ROOT/skills/woostack-address-comments/prompts/address.md"
ADDRESS_SCRIPTS="$ROOT/skills/woostack-address-comments/scripts"

assert_contains() {
  local file="$1"
  local pattern="$2"
  if ! rg -q "$pattern" "$file"; then
    echo "missing pattern in ${file#$ROOT/}: $pattern" >&2
    exit 1
  fi
}

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  if rg -q "$pattern" "$file"; then
    echo "unexpected pattern in ${file#$ROOT/}: $pattern" >&2
    exit 1
  fi
}

assert_contains "$ADDRESS_SKILL" "## Workflow"
assert_contains "$ADDRESS_SKILL" "Lifecycle"
assert_contains "$ADDRESS_SKILL" "WOO_ADDRESS_ACTION_PATH"
assert_contains "$ADDRESS_PROMPT" "Optional worker fan-out"
assert_contains "$ADDRESS_PROMPT" "fix_plan"

# issue #282: the verdict gate must be a prominent, summary/skim-resistant STOP barrier and be
# restated in Hard constraints — not soft body prose a low-effort model collapses past. Pin the
# barrier tag, the hard-constraint restatement, and the Phase 2 STOP cue (ASCII tokens per the
# skill-test-assert-ascii-token convention).
assert_contains "$ADDRESS_SKILL" "<HARD-GATE>"
assert_contains "$ADDRESS_SKILL" "Silence is not a yes"
assert_contains "$ADDRESS_PROMPT" "do not act until approved"

for script in prefetch.sh fetch-threads.sh resolve-thread.sh memory-record.sh memory-append.sh resolve-outdir.sh; do
  if [ ! -f "$ADDRESS_SCRIPTS/$script" ]; then
    echo "missing address-comments script: $script" >&2
    exit 1
  fi
done

assert_not_contains "$ADDRESS_SKILL" "Delegates to the woostack-review address verb"
assert_not_contains "$ADDRESS_SKILL" "woostack-review address"
assert_not_contains "$ADDRESS_SKILL" "No duplicate engine"
assert_not_contains "$ADDRESS_SKILL" "review prefetch"
assert_not_contains "$REVIEW_SKILL" "woostack-review address"
assert_not_contains "$REVIEW_SKILL" "Addressing Reviews"
