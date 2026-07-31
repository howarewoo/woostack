#!/usr/bin/env bash
# Structural contract: terminal taxonomy, sweep outcomes, and descendant branch rewrites are
# exact-issue operations backed by independently read worker, authorization, GitHub, and Linear receipts.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../woostack-init/scripts/tests/assert.sh"
set +e

SKILL="$HERE/../../SKILL.md"
body="$(cat "$SKILL")"
BACKENDS="$HERE/../../../woostack-init/references/artifact-backends.md"
backends="$(cat "$BACKENDS")"
WORKTREES="$HERE/../../../woostack-init/references/worktrees.md"
worktrees="$(cat "$WORKTREES")"

resolution="$(printf '%s' "$body" | awk '/^## Resolve the stack/{f=1; next} /^## /{f=0} f' | tr '\n' ' ' | tr -s ' ')"
assert_contains "$resolution" 'final raw `Linear-Issue:` trailer' \
  "each PR resolves one exact Linear issue through canonical attribution"
assert_contains "$resolution" "stable client UUID" \
  "sweep retains stable and native issue identity"
assert_contains "$resolution" "current issue events/state" \
  "sweep verifies issue evidence and native state"
assert_contains "$resolution" "Never infer membership or ancestry" \
  "Graphite adjacency cannot replace Linear issue relations"

assert_contains "$backends" 'assignmentAccepted | verification | precommitReview | implementationEvidence |' \
  "precommitReview is part of the exact canonical issue-event taxonomy"
assert_contains "$backends" 'restackAuthorized | decisionRequest | decisionResponse | reviewResult | acceptance |' \
  "decision response, post-PR review, and terminal events remain in the canonical taxonomy"
assert_contains "$backends" '### Canonical issue-event dispatch and pre-commit evidence' \
  "all canonical issue events have one central dispatcher"
assert_contains "$backends" 'Readers dispatch every managed issue comment solely by its canonical `event` value' \
  "event kind selects one strict actor payload and relation contract"
assert_contains "$backends" '`precommitReview` contains exactly `issueId`' \
  "issue-wide precommit review has an exact payload"
assert_contains "$backends" 'No producer may relate to a future event' \
  "canonical relations are producible without a forward edge"
assert_contains "$backends" 'post-PR `reviewResult` instead relates back' \
  "reviewResult is separated from commit-time implementation evidence"
assert_contains "$backends" 'revision named by that ID' \
  "historical relations resolve an exact native event revision"
assert_contains "$backends" 'never substitutes the latest event of that kind' \
  "historical validation never drifts to latest-by-kind"
assert_contains "$backends" '### Bounded `restackAuthorized` delegation' \
  "the canonical authority distinguishes bounded delegation from ownership handoff"
assert_contains "$backends" '`handoff` is an ownership-transfer event' \
  "handoff retains its reassignment semantics"
assert_contains "$backends" 'Its readable data contains exactly `operationId`' \
  "authorization has one exact readable payload contract"
assert_contains "$backends" 'exactly empty for an issue-local,' \
  "zero-relation review and address authorization is representable"
assert_contains "$backends" 'cross-issue relation rewrite' \
  "cross-issue relation rewrites require exact nonempty relations"
assert_contains "$backends" 'inactive append-only' \
  "expired unconsumed authority is harmless inactive history"
assert_contains "$backends" '`authorizationTime < completionTime <= expiresAt`' \
  "consumed authority must complete inside its temporal window"
assert_contains "$backends" 'no reassignment or replacement' \
  "bounded restack delegation leaves ownership unchanged"
assert_contains "$backends" 'preallocated RFC 4122 UUID' \
  "restack operation identity is a valid RFC 4122 UUID"
assert_contains "$backends" 'passing `verification`, passing `precommitReview`' \
  "finalized evidence relates the two precommit producer receipts"
assert_contains "$backends" 'first validate' \
  "consumed authorization remains valid against its historical pre-restack evidence"
assert_contains "$backends" 'current resulting evidence/head B' \
  "consumption separately validates the current resulting head"
assert_contains "$backends" '### Canonical non-phase project events' \
  "canonical project event authority is defined centrally"
assert_contains "$backends" 'native author matches the freshly re-resolved pinned project lead' \
  "project event actors are pinned-lead-authorized"
assert_contains "$backends" '`predecessorId` is the native ID of the current unsuperseded phase event' \
  "non-phase project events remain attached to the current phase"
assert_contains "$backends" '`progress` relates exactly the affected native issue IDs' \
  "progress relations are exact"
assert_contains "$backends" '`blockerOpened` relates exactly the affected native issue IDs' \
  "project blockers relate exact issue failure evidence"
assert_contains "$backends" '`blockerResolved` relates exactly the open `blockerOpened`' \
  "project blocker resolution relates the exact open blocker"
assert_contains "$backends" 'project `handoff` relates exactly the current native issue-event IDs' \
  "project handoff relations preserve current issue evidence"
assert_contains "$backends" 'never invents readable fields' \
  "project readers do not fabricate producer payload fields"
assert_contains "$backends" 'Its actor is the same freshly' \
  "issueDone uses the freshly verified type-aware acceptance authority"
assert_contains "$backends" 'its sorted `relatedIds` are exactly the current' \
  "issueDone relates the exact current acceptance, implementation, review, verification, and PR evidence"
assert_contains "$backends" 'readable data contains exactly `pullRequestNumber` and' \
  "issueDone carries only independently verified PR and merge identity"
assert_contains "$backends" 'a second complete issue read must contain the same current' \
  "terminal reconciliation independently reads back event and state"

assert_contains "$worktrees" '**Inactive history:**' \
  "worktree discovery classifies fully validated inactive authorizations separately"
assert_contains "$worktrees" 'authorization-candidate and competing-operation collision counts' \
  "validated expired-unconsumed and consumed history is excluded from active collision counting"
assert_contains "$worktrees" 'cannot satisfy review-reopen or authorize a new checkout' \
  "inactive history never grants authority to a later operation"
assert_contains "$worktrees" '**Candidate invalidity:**' \
  "an authorization selected for the current operation is not historical"
assert_contains "$worktrees" 'If that candidate is expired or consumed, it blocks.' \
  "expired or consumed current candidates fail closed"
assert_contains "$worktrees" '**Historical invalidity or conflict:**' \
  "malformed or ambiguous historical evidence remains a distinct blocker"
assert_contains "$worktrees" 'unresolved temporal' \
  "historical overlap with the current operation remains a collision"
assert_contains "$worktrees" 'exactly one active candidate is a current, unexpired, unconsumed' \
  "review-reopen admits exactly one usable authorization after filtering inactive history"

authority="$(printf '%s' "$body" | awk '/^## Linear issue authority/{f=1; next} /^## /{f=0} f' | tr '\n' ' ' | tr -s ' ')"
assert_contains "$authority" "official host-exposed Linear MCP" \
  "sweep uses the official authenticated MCP"
assert_contains "$authority" "exact swept issue" \
  "review and blocker events are issue-scoped"
for event in reviewResult verification precommitReview implementationEvidence failure blocked unblocked restackAuthorized; do
  assert_contains "$authority" "\`$event\`" \
    "sweep records or requires typed $event issue events"
done
assert_contains "$authority" "stable event UUID before each append" \
  "sweep preallocates stable event IDs"
assert_contains "$authority" "independently re-query the exact issue" \
  "every Linear mutation has an independent complete read-back"
assert_contains "$authority" "does not edit an issue description" \
  "sweep cannot mutate the issue contract"
assert_contains "$authority" "current type-aware owner—not a" \
  "only the current type-aware owner authors restack authorization"
assert_contains "$authority" 'readable data contains exactly `operationId`' \
  "restack authorization binds one operation"
assert_contains "$authority" '`controllerPrincipalKind`, `controllerPrincipalId`' \
  "restack authorization binds the exact target controller principal"
assert_contains "$authority" '`registryClaimPath`, `worktreePath`, sorted `affectedRelationIds`, and `expiresAt`' \
  "restack authorization binds canonical paths, affected relations, and expiry"
assert_contains "$authority" 'exactly empty for an issue-local, root, or standalone review/address' \
  "issue-local review can carry an exact empty affected-relation set"
assert_contains "$authority" 'cross-issue rewrite requires the sorted exact nonempty' \
  "cross-issue rewrite authority names every affected relation"
assert_contains "$authority" 'current `assignmentAccepted` native comment' \
  "restack authorization relates the current assignment"
assert_contains "$authority" 'current `implementationEvidence` native comment' \
  "restack authorization relates current implementation evidence"
assert_contains "$authority" 'exact revision that was current at the authorization' \
  "authorization relations resolve historical revisions at authorization time"
assert_contains "$authority" 'expired unconsumed authorization is inactive append-only history' \
  "expired history does not compete or poison later reads"
assert_contains "$authority" 'project `decision`' \
  "cross-issue managed-project restack uses pinned-lead decision authorization"
assert_contains "$authority" 'issue-local/root/standalone operation with exact empty' \
  "empty affected relations require no fake project decision"
assert_contains "$authority" 'bounded delegation without ownership transfer' \
  "restack authorization does not impersonate reassignment"
assert_contains "$authority" 'passing `precommitReview`' \
  "rewritten implementation evidence retains issue-wide review proof"
assert_contains "$authority" 'Post-PR `reviewResult` is not a producer relation' \
  "implementation evidence never points forward to post-PR review"
assert_contains "$authority" 'Only the complete current-B evidence read-back consumes' \
  "authorization consumption occurs only after verified resulting evidence"
assert_contains "$authority" 'authorizationTime < completionTime <= expiresAt' \
  "consumed operations finish within the authorization lifetime"
assert_not_contains "$authority" 'issue-scoped `handoff` to the named sweep' \
  "no-owner-change restack never misuses handoff"
assert_not_contains "$authority" "\`decisionRequest\`" \
  "restack authorization cannot depend on a decision request"

loop="$(printf '%s' "$body" | awk '/^## The per-PR loop/{f=1; next} /^## Termination backstop/{f=0} f' | tr '\n' ' ' | tr -s ' ')"
assert_contains "$loop" "Worker + review + mutation receipts before clean" \
  "clean requires all three receipt families"
assert_contains "$loop" "real \`woostack-review --full\` run on that same HEAD" \
  "clean requires an independent full-review receipt for current HEAD"
assert_contains "$loop" "verified issue-scoped \`reviewResult\` comment" \
  "clean requires the exact Linear review-result mutation receipt"
assert_contains "$loop" "append post-PR \`reviewResult\`" \
  "reviewResult is produced only after the PR exists"
assert_contains "$loop" 'readable data contains exactly `issueId`, `pullRequestNumber`' \
  "reviewResult uses the exact canonical post-PR payload"
assert_contains "$loop" "independently read native GitHub full-review receipt IDs" \
  "reviewResult relates the full-review receipt"
assert_contains "$loop" "issue-wide pre-commit \`precommitReview\` cannot substitute" \
  "precommit review cannot satisfy the post-PR full-review gate"
assert_contains "$loop" "No receipt for HEAD" \
  "missing current-HEAD review proof routes to blocked"
assert_contains "$loop" "clean-looking GitHub verdict without a complete \`reviewResult\`" \
  "GitHub proof alone cannot replace Linear read-back"
assert_contains "$loop" "Missing worker evidence" \
  "missing implementation/verification receipts block acceptance"
assert_contains "$loop" "never self-review" \
  "sweep cannot substitute a coding-worker or self-review"
assert_contains "$loop" "exact descendant set" \
  "pre-restack discovery inventories every branch the command could move"
assert_contains "$loop" "complete issue contract" \
  "every affected descendant contract is independently re-read"
assert_contains "$loop" 'claim="$WOOSTACK_ROOT/.woostack/worktrees/.registry/$issue_id/claim.json"' \
  "sweep uses the canonical exact-native-ID registry claim"
assert_contains "$loop" 'wt="$WOOSTACK_ROOT/.woostack/worktrees/issues/$issue_id"' \
  "sweep uses the deterministic exact-native-ID worktree path"
assert_contains "$loop" 'matching existing exact claim/worktree, or the' \
  "sweep uses an existing exact claim or the only canonical reopen state"
assert_contains "$loop" '**Verified review-reopen**' \
  "a torn-down inReview issue uses the named review-reopen lifecycle"
assert_contains "$loop" 'prior verified §7 teardown' \
  "review-reopen proves teardown rather than guessing from absence"
assert_contains "$loop" 'both canonical claim and path free' \
  "review-reopen proves both canonical resources are free"
assert_contains "$loop" 'branch checked out nowhere' \
  "review-reopen rejects a conflicting checkout"
assert_contains "$loop" 'no other worktree, claim, operation, or collision' \
  "review-reopen proves exclusive operation state"
assert_contains "$loop" "atomically create the authorization-bound canonical claim" \
  "review-reopen claims the exact issue before reattaching"
assert_contains "$loop" 'git worktree add "$wt" "$branch"' \
  "review-reopen reattaches the existing branch without creating one"
assert_contains "$loop" 'missing/wrong/expired/consumed authorization' \
  "an unusable selected authorization blocks worktree mutation"
assert_contains "$loop" "slug-based, ad hoc, or" \
  "sweep cannot create an unregistered fallback worktree"
assert_contains "$loop" 'descendant-owner `restackAuthorized` receipt set' \
  "each descendant owner grants the exact bounded rewrite"
assert_contains "$loop" 'same one operation/controller/expiry' \
  "all descendant authorizations bind one operation and controller"
assert_contains "$loop" "pinned lead's matching project \`decision\`" \
  "cross-issue project rewrite retains pinned-lead authorization"
assert_contains "$loop" '`handoff` without owner transfer cannot satisfy' \
  "handoff cannot substitute for bounded restack authorization"
assert_contains "$loop" "active incompatible" \
  "foreign or incompatible descendant worktrees are explicit collisions"
assert_contains "$loop" "exact-ID claim collision" \
  "an exact issue registry/path collision is explicit"
assert_contains "$loop" 'blocks **without `gt restack` or any ref mutation**' \
  "a collision or authority gap stops before another issue branch moves"
assert_contains "$loop" 'matching existing canonical exact-ID claim/worktree or a newly established' \
  "coordinated restack uses only the exact claim or review-reopen"
assert_contains "$loop" 'Never generic release/reclaim' \
  "generic release/reclaim cannot bypass verified review-reopen"
assert_contains "$loop" 'passing `verification`, passing `precommitReview`' \
  "post-restack implementation evidence retains canonical precommit producer relations"
assert_contains "$loop" 'add exactly the authorization native comment' \
  "post-restack implementation evidence adds only the exact authorization"
assert_contains "$loop" 'historical bound implementation evidence/head A' \
  "restack validates historical authorization input separately from current output"
assert_contains "$loop" 'No assignee/delegate mutation or replacement `assignmentAccepted` occurs' \
  "the current issue owner remains owner throughout restack"
assert_contains "$loop" 'exactly one canonical PR with its retained number/URL/repository/base' \
  "post-restack submission re-proves each PR identity at historical A"
assert_contains "$loop" 'same sole number/URL/repository/explicit branch/base from A now has finalized head B' \
  "post-restack GitHub read-back preserves the PR identity through B"
assert_contains "$loop" 'native Linear PR relation is stable across head revisions' \
  "same-PR head movement does not rewrite the stable Linear relation"
assert_contains "$loop" 'Independently read its retained native ID and the complete issue relation' \
  "post-restack attribution verifies the retained relation at the finalized head"
assert_contains "$loop" 'payload containing only `baseCommitSha`, `headCommitSha`' \
  "post-restack implementation evidence keeps the canonical commit-only payload"
assert_contains "$loop" 'strict `verification` proving the' \
  "address verification is strict and pre-commit"
assert_contains "$loop" 'controller appends and reads back `precommitReview`' \
  "address records issue-wide spec and quality review before commit"
assert_contains "$loop" 'contains no commit/PR/GitHub review identity' \
  "precommit review has no future or post-PR identity"
assert_contains "$loop" 'It never' \
  "address implementation evidence excludes the prior post-PR review result"
assert_contains "$loop" 'authorizationTime < completionTime <= expiresAt' \
  "restack evidence consumes authority only inside its expiry"
assert_contains "$loop" 'before `gt submit --stack`' \
  "moved-head evidence is read back before stack submission"
assert_contains "$loop" "independently" \
  "submission attribution is read separately from implementation evidence"

blockers="$(printf '%s' "$body" | awk '/^## Blocker & terminal state/{f=1; next} /^## Config/{f=0} f' | tr '\n' ' ' | tr -s ' ')"
assert_contains "$blockers" 'exact issue `failure`' \
  "blockers are appended to the affected issue"
assert_contains "$blockers" "independently read every mutation back" \
  "blocker mutations are verified"
assert_contains "$blockers" "No report file is written" \
  "standalone sweep has no local authority record"
assert_contains "$blockers" "caller independently reads it" \
  "delegated callers re-read issue receipts before project progress"
assert_contains "$blockers" "incomplete descendant inventory" \
  "incomplete descendant inventory remains a blocker"
assert_contains "$blockers" 'wrong-controller, wrong-operation' \
  "wrong descendant authorization remains a blocker"
assert_contains "$blockers" "second checkout/worktree" \
  "conflicting checkouts and claims remain blockers"
assert_contains "$blockers" "authorization-consumption read-back" \
  "a moved branch cannot advance without single-use evidence"
assert_contains "$blockers" 'Append `handoff` only if the current owner actually' \
  "handoff is reserved for real ownership transfer"
assert_contains "$blockers" "no-owner-change restack stop leaves the owner" \
  "restack blockers have no reassignment side effects"

hard="$(printf '%s' "$body" | awk '/^## Hard constraints/{f=1} f' | tr '\n' ' ' | tr -s ' ')"
assert_contains "$hard" "Receipt before clean" \
  "the multi-receipt barrier is repeated in Hard constraints"
assert_contains "$hard" "Issue contract and lead authority are read-only" \
  "worker authority restrictions survive condensed execution"
assert_contains "$hard" "Stable issue events with independent read-back" \
  "stable event/read-back protocol survives condensed execution"
assert_contains "$hard" "No local authority" \
  "no local sweep report can be accepted"
assert_contains "$hard" "Coordinate every descendant before restack" \
  "the condensed contract preserves descendant ownership isolation"
assert_contains "$hard" 'unconsumed `restackAuthorized` revision' \
  "the condensed contract requires exact owner-authored authorization"
assert_contains "$hard" "matching project \`decision\`" \
  "the condensed contract retains pinned-lead project authorization"
assert_contains "$hard" "Existing exact claim or verified review-reopen only" \
  "the condensed contract preserves the canonical worktree lifecycle"
assert_contains "$hard" "no other checkout/worktree/operation/collision" \
  "review-reopen stays collision safe"
assert_contains "$hard" "owner/assignment never changes" \
  "bounded delegation creates no reassignment side effects"
assert_contains "$hard" "read-back consumes that authorization before" \
  "rewritten issue evidence consumes the authorization before submission"

finish
