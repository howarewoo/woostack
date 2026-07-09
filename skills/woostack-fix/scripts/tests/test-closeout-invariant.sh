#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"

skill="$ROOT/skills/woostack-fix/SKILL.md"
body="$(cat "$skill")"

assert_contains "$body" "## Completion invariant" "fix skill declares completion invariant"
assert_contains "$body" "Do not final-answer after implementation or tests" "invariant blocks early final handback"
assert_contains "$body" "PR is submitted or updated" "invariant requires submitted or updated PR"
assert_contains "$body" 'frontmatter is `status: in-review`' "invariant requires in-review lifecycle"
assert_contains "$body" "lifecycle update is committed and submitted" "invariant requires lifecycle commit/submit"
assert_contains "$body" "commits code, checklist, and execution lifecycle updates" "invariant pins execute commit ownership"
assert_contains "$body" '`woostack-fix` commits only the final' "invariant pins fix closeout commit ownership"
assert_contains "$body" "to the same PR before teardown" "invariant requires same-PR lifecycle update"
assert_contains "$body" "PR URL" "invariant requires PR URL handback"
assert_contains "$body" "verification summary" "invariant requires verification summary handback"
assert_contains "$body" "fix worktree is removed" "invariant requires worktree teardown"
assert_contains "$body" "leave the worktree in place" "invariant preserves failure recovery"
assert_contains "$body" "blocker and the fix worktree path" "invariant reports blocker and worktree path on failure"
assert_contains "$body" "Hand off" "approval gate offers a handoff option"
assert_contains "$body" "status: approved" "handoff records the approved lifecycle state"
assert_contains "$body" "--resume" "handoff returns a resume command"
assert_contains "$body" 'Go → execute via woostack-execute' "overview shows Go continues to execution"
assert_contains "$body" 'Hand off → commit approved plan, remove worktree, and stop before implementation' "overview shows Hand off stops before execution"
assert_contains "$body" 'INIT_SCRIPTS' "resume mode defines concrete resolver helper path"
assert_contains "$body" 'status: approved` → recreate or verify' "resume approved state continues execution"
assert_contains "$body" 'status: hardened` → recreate or verify' "resume hardened state returns to approval gate"
assert_contains "$body" 'status: executing`, `in-review`, or `done` → do not restart execution blindly' "resume active and terminal states do not restart blindly"
assert_contains "$body" 'Any missing branch, missing fix file, dirty resurrected worktree, or conflicting worktree' "resume blocker states leave recovery context intact"
assert_contains "$body" "Handoff does not satisfy the closeout invariant" "handoff is distinct from completed execution"
assert_contains "$body" "Submit PR, Mark In Review, And Tear Down Worktree" "step 6 heading is operational"

finish
