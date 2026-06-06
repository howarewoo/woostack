#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
PROMPT="$ROOT/skills/woostack-address-comments/prompts/address.md"
SKILL="$ROOT/skills/woostack-address-comments/SKILL.md"

assert_contains() {
  local file="$1"
  local pattern="$2"
  if ! rg -F -q "$pattern" "$file"; then
    echo "missing pattern in ${file#$ROOT/}: $pattern" >&2
    exit 1
  fi
}

assert_contains "$PROMPT" "worker"
assert_contains "$PROMPT" "reply"
assert_contains "$PROMPT" "fix_plan"
# the verdict gate must surface the fix plan to the user, not just the verdict:
# pin each Phase 2 sub-contract so the test fails if any one is dropped, not the
# loose "fix plan" phrase that survives even if a sub-contract is removed
assert_contains "$PROMPT" "option text"             # structured-host: fix plan carried in the FIX option
assert_contains "$PROMPT" "reasoning, **fix plan**" # plain-host: the fix-plan table column
assert_contains "$PROMPT" "for ACCEPT / CLARIFY"    # dash-cell rule for non-FIX verdicts
# an override that creates a FIX must derive + confirm its plan before applying
# (ASCII token from the override→FIX follow-up prose — robust to arrow encoding)
assert_contains "$PROMPT" "bounded confirm"
assert_contains "$PROMPT" "\$OUTDIR/address-threads.json"
assert_contains "$PROMPT" "\$OUTDIR/memory.md"
assert_contains "$PROMPT" "must not edit files"
assert_contains "$PROMPT" "must not commit"
assert_contains "$PROMPT" "must not push"
assert_contains "$PROMPT" "must not reply"
assert_contains "$PROMPT" "must not resolve"
assert_contains "$PROMPT" "must not write memory"
if rg -q "/tmp/pr-review/(address-threads|memory)\\.md|/tmp/pr-review/address-threads\\.json" "$PROMPT"; then
  echo "address prompt must use \$OUTDIR for prefetched address artifacts" >&2
  exit 1
fi
assert_contains "$SKILL" "fast workers"
assert_contains "$SKILL" "parent orchestrator"
