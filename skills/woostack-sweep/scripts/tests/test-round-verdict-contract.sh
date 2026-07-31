#!/usr/bin/env bash
# Structural contract: fresh verdicts are issue-recorded before classification, and an address pass
# cannot move a descendant until current ownership, exact-ID lifecycle, and bounded authorization verify.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../woostack-init/scripts/tests/assert.sh"
set +e

SKILL="$HERE/../../SKILL.md"
body="$(cat "$SKILL")"

loop="$(printf '%s' "$body" | awk '/^## The per-PR loop/{f=1; next} /^## Termination backstop/{f=0} f')"
loop_flat="$(printf '%s' "$loop" | tr '\n' ' ' | tr -s ' ')"
assert_contains "$loop_flat" "**Record, verify, then classify**" \
  "sweep writes and verifies the issue result before classifying it"
assert_contains "$loop_flat" "On every round, including the final allowed round" \
  "first, later, and final rounds use verdict-first ordering"
assert_contains "$loop_flat" 'classify the fresh `STATUS_LINE` before evaluating `max_rounds` or the no-progress guard' \
  "fresh verdict classification precedes both blocking backstops"
assert_contains "$loop_flat" "Independently re-read the exact comment and complete issue" \
  "the Linear reviewResult receipt precedes outcome classification"
assert_contains "$loop_flat" 'readable data contains exactly `issueId`, `pullRequestNumber`' \
  "reviewResult records the exact canonical post-PR payload"
assert_contains "$loop_flat" "native GitHub full-review receipt IDs" \
  "reviewResult records and relates the GitHub receipt"
assert_contains "$loop_flat" "issue-wide pre-commit \`precommitReview\` cannot substitute" \
  "precommit review is separate from post-PR reviewResult"
assert_contains "$loop_flat" "**No blocking findings + zero unresolved threads**" \
  "a fully receipt-backed no-blocking verdict can become clean"
assert_contains "$loop_flat" "**No blocking findings + open threads**" \
  "nits take one address pass and remain non-terminal"
assert_contains "$loop_flat" "**Blocking findings**" \
  "only blocking findings enter the re-review loop"

restack="$(printf '%s' "$loop" | awk '/^4\. \*\*Restack this stack only\*\*/{f=1} /^5\. \*\*Re-review/{f=0} f')"
restack_flat="$(printf '%s' "$restack" | tr '\n' ' ' | tr -s ' ')"
assert_contains "$restack_flat" "inventory the **exact descendant set**" \
  "a lower-PR fix first determines every descendant issue it could move"
assert_contains "$restack_flat" 'current owner-authored authorization' \
  "the exact current descendant owner authors canonical bounded authority"
assert_contains "$restack_flat" 'complete stable/native' \
  "each restack authorization has a reproducible independently read receipt"
assert_contains "$restack_flat" 'same one operation/controller/expiry' \
  "all authorizations bind the exact operation and controller"
assert_contains "$restack_flat" 'missing, wrong-controller, wrong-operation' \
  "missing or wrong descendant authorization blocks before mutation"
assert_contains "$restack_flat" "pinned lead's matching project \`decision\`" \
  "cross-issue project authorization uses a current pinned-lead decision"
assert_contains "$restack_flat" '`handoff` without owner transfer cannot satisfy' \
  "ownership handoff cannot stand in for no-owner-change authorization"
assert_contains "$restack_flat" "Owner/assignment drift" \
  "a stale owner cannot authorize another issue branch rewrite"
assert_contains "$restack_flat" "active incompatible" \
  "a conflicting descendant checkout is classified before Graphite mutation"
assert_contains "$restack_flat" "exact-ID claim collision" \
  "the exact native issue registry/path claim cannot collide"
assert_contains "$restack_flat" 'blocks **without `gt restack` or any ref mutation**' \
  "descendant collisions and authority gaps stop before restack"
assert_contains "$restack_flat" 'canonical claim/worktree or verified review-reopen' \
  "only an existing exact claim or verified review-reopen can operate"
assert_contains "$restack_flat" "Only after every descendant preflight" \
  "a fully authorized and isolated descendant set remains restackable"
assert_contains "$restack_flat" 'issue to remain `inReview` after prior verified teardown' \
  "review-reopen reproduces the canonical teardown state"
assert_contains "$restack_flat" "branch checked out nowhere" \
  "review-reopen rejects conflicting checkouts"
assert_contains "$restack_flat" "no other checkout, worktree, claim, operation, or collision" \
  "review-reopen proves collision-free exclusivity"
assert_contains "$restack_flat" "Never generic release/reclaim" \
  "generic release/reclaim cannot bypass the reopen proof"
assert_contains "$restack_flat" 'passing `verification`, passing `precommitReview`' \
  "rewritten evidence keeps assignment, verification, precommit review, and project relations"
assert_contains "$restack_flat" 'add exactly the authorization native comment' \
  "rewritten evidence adds only the bounded authorization relation"
assert_contains "$restack_flat" 'historical bound implementation evidence/head A' \
  "consumption preserves validation of the historical authorized input"
assert_contains "$restack_flat" 'current-B read-back consume the authorization' \
  "authorization is consumed only after resulting evidence reads back"
assert_contains "$restack_flat" 'No assignee/delegate mutation or replacement `assignmentAccepted` occurs' \
  "bounded restack produces no ownership transfer"
assert_contains "$restack_flat" 'authorizationTime < completionTime <= expiresAt' \
  "consumed restack completion stays within expiry"
assert_contains "$restack_flat" "Only after every moved issue has that post-restack evidence" \
  "stack submission waits for every rewritten issue receipt"
assert_contains "$restack_flat" "independently refetch every moved canonical PR by its retained" \
  "resulting same-PR heads and ancestry are re-read after submission"
assert_contains "$restack_flat" 'exactly one canonical PR with its retained number/URL/repository/base' \
  "restack submission re-proves each sole canonical PR at historical head A"
assert_contains "$restack_flat" 'exactly one stable native Linear PR relation with its retained ID' \
  "restack submission binds the historical native relation identity"
assert_contains "$restack_flat" 'same sole number/URL/repository/explicit branch/base from A now has finalized head B' \
  "post-submit read-back proves the same canonical PR at B"
assert_contains "$restack_flat" 'native Linear PR relation is stable across head revisions' \
  "restack retains rather than rewrites the canonical relation"
assert_contains "$restack_flat" 'Independently read its retained native ID and the complete issue relation collection' \
  "stable relation validation has exact-ID and collection read-back"
assert_contains "$restack_flat" 'Mixed A/B state, unexpected head C' \
  "stale or mixed submission state cannot create a replacement PR"
assert_contains "$restack_flat" 'canonical `precommitReview`' \
  "conflict review is recorded before the rewritten commit"
assert_contains "$restack_flat" 'neither event contains a future head/diff, PR, or GitHub' \
  "precommit evidence has no future or post-PR dependency"
assert_contains "$body" 'One preallocated RFC 4122 `operationId`' \
  "restack operationId is constrained to RFC 4122"
termination="$(printf '%s' "$body" | awk '/^## Termination backstop/{f=1; next} /^## Per-issue outcome vocabulary/{f=0} f')"
termination_flat="$(printf '%s' "$termination" | tr '\n' ' ' | tr -s ' ')"
assert_contains "$termination_flat" "only while the latest receipt-backed verdict still" \
  "cap and no-progress terminate only a still-blocking latest verdict"
assert_contains "$termination_flat" "same" \
  "unchanged blocking fingerprints trip the no-progress guard"
assert_contains "$termination_flat" "Nits never enter this loop" \
  "non-blocking findings cannot burn bounded rounds"

outcomes="$(printf '%s' "$body" | awk '/^## Per-issue outcome vocabulary/{f=1; next} /^## /{f=0} f')"
assert_contains "$outcomes" "exact native issue ID and" \
  "each outcome is issue-scoped"
assert_contains "$outcomes" "Linear" \
  "each outcome carries the verified reviewResult receipt"
assert_contains "$outcomes" "Outcome text without that complete issue-scoped receipt set is \`blocked\`" \
  "a prose-only result cannot cross the acceptance barrier"

hard="$(printf '%s' "$body" | awk '/^## Hard constraints/{f=1} f' | tr '\n' ' ' | tr -s ' ')"
assert_contains "$hard" "Verdict before backstop" \
  "verdict-first ordering is repeated in Hard constraints"
assert_contains "$hard" "review result and classify the fresh verdict" \
  "the hard barrier includes Linear read-back before the bounds"
assert_contains "$hard" "Bounded" \
  "maximum rounds and no-progress behavior remain load-bearing"
assert_contains "$hard" "stale-owner" \
  "the condensed restack gate rejects stale ownership"
assert_contains "$hard" 'unconsumed `restackAuthorized` revision' \
  "the condensed restack gate requires a current single-use authorization"
assert_contains "$hard" "matching project \`decision\`" \
  "the condensed restack gate requires pinned-lead project authority"
assert_contains "$hard" "exact-ID claim collision" \
  "the condensed restack gate rejects descendant claim collisions"
assert_contains "$hard" "Existing exact claim or verified review-reopen only" \
  "the condensed restack gate retains only canonical worktree states"
assert_contains "$hard" "no other checkout/worktree/operation/collision" \
  "the condensed reopen gate rejects conflicting state"
assert_contains "$hard" "owner/assignment never changes" \
  "bounded authorization has no reassignment side effects"

finish
