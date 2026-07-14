#!/usr/bin/env bash
# Contract test: an expected bottom-up restack conflict enters autonomous semantic
# recovery; only a conflict that cannot be resolved and verified safely blocks.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../woostack-init/scripts/tests/assert.sh"
set +e

SKILL="$HERE/../../SKILL.md"
body="$(cat "$SKILL")"

restack="$(printf '%s' "$body" | awk '/^4\. \*\*Restack this stack only\*\*/{f=1} /^5\. \*\*Re-review/{f=0} f')"
restack_flat="$(printf '%s' "$restack" | tr '\n' ' ' | tr -s ' ')"
assert_contains "$restack_flat" 'git status --short' \
  "restack recovery enumerates the paused worktree state"
assert_contains "$restack_flat" 'git ls-files -u' \
  "restack recovery inspects every unmerged index stage"
assert_contains "$restack_flat" 'git diff --cc' \
  "restack recovery inspects the semantic combined diff"
assert_contains "$restack_flat" 'git rebase --show-current-patch' \
  "restack recovery reads the descendant commit being replayed"
assert_contains "$restack_flat" 'focused verification' \
  "restack recovery verifies the reconciled behavior"
assert_contains "$restack_flat" 'git add -- <paths>' \
  "restack recovery stages only explicit resolved paths"
assert_contains "$restack_flat" '`gt continue`' \
  "restack recovery resumes the halted Graphite command"
assert_contains "$restack_flat" 'Repeat' \
  "later descendant conflicts re-enter the recovery loop"
assert_contains "$restack_flat" 'before `gt submit --stack`' \
  "stack submission follows successful conflict continuation"
assert_contains "$restack_flat" 'Never resolve by choosing an entire `ours` or `theirs` side' \
  "semantic recovery cannot discard one side wholesale"
assert_contains "$restack_flat" 'never `git add -A` or `gt continue -a`' \
  "recovery cannot stage unrelated worktree changes"
assert_not_contains "$restack_flat" 'A restack/rebase conflict is a **blocker**.' \
  "the mere occurrence of a restack conflict is not a blocker"

blockers="$(printf '%s' "$body" | awk '/^## Blocker & terminal state/{f=1; next} /^## Config/{f=0} f')"
blockers_flat="$(printf '%s' "$blockers" | tr '\n' ' ' | tr -s ' ')"
assert_contains "$blockers_flat" 'ambiguous' \
  "an ambiguous conflict remains a blocker"
assert_contains "$blockers_flat" 'cannot be verified safely' \
  "an unverifiable conflict remains a blocker"
assert_contains "$blockers_flat" '`gt continue` fails' \
  "a failed Graphite continuation remains a blocker"
assert_contains "$blockers_flat" 'unresolved paths and failed command' \
  "a conflict blocker reports actionable evidence"
assert_contains "$blockers_flat" 'leave the paused worktree and rebase state intact' \
  "a conflict blocker preserves recoverable state"

hard="$(printf '%s' "$body" | awk '/^## Hard constraints/{f=1} f')"
assert_contains "$hard" 'Resolve expected restack conflicts' \
  "Hard constraints preserve autonomous conflict recovery"
assert_contains "$hard" 'Stop only when conflict intent is ambiguous or unsafe' \
  "Hard constraints preserve the safe stop boundary"

finish
