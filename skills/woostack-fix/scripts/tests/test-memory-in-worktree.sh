#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"

skill="$ROOT/skills/woostack-fix/SKILL.md"
body="$(cat "$skill")"

# The distilled memory note must ride the fix commit (written in the worktree),
# never be dropped in the primary tree — matching the worktree contract §3/§5 and
# woostack-execute step 7. Needles with backticks are SINGLE-quoted so bash does not
# run `woostack-execute` as a command substitution.
assert_not_contains "$body" \
  'distill (run by `woostack-execute` in step 5) targets the primary tree' \
  "step 6 no longer claims the memory distill targets the primary tree"
assert_contains "$body" "ride the fix commit" \
  "step 6 says distilled memory rides the fix commit"
assert_contains "$body" "committed with the fix" \
  "step 6 says the durable learning is committed with the fix"
assert_contains "$body" "inside the fix worktree" \
  "step 6 pins the distill write to the fix worktree"

finish
