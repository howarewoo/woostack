#!/usr/bin/env bash
# Structural contract: unattended execution records progress, blockers, review, and handoff in
# exact Linear issues/project updates, then renders (but never writes) the terminal handback.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../woostack-init/scripts/tests/assert.sh"
set +e

SKILL="$HERE/../../SKILL.md"
body="$(cat "$SKILL")"

authority="$(printf '%s' "$body" | awk '/^## Authority and MCP boundary/{f=1; next} /^## /{f=0} f' | tr '\n' ' ')"
assert_contains "$authority" "official Linear MCP" \
  "overnight uses only official host-exposed Linear MCP authority"
assert_contains "$authority" "stable client UUIDs" \
  "overnight binds exact managed Linear identities"
assert_contains "$authority" "The complete verified project, issue graph, typed events" \
  "overnight derives development state from verified remote records"
assert_contains "$authority" "disposable worktree registry keyed by exact Linear IDs" \
  "overnight keeps recovery administration identity-bound"

drivers="$(printf '%s' "$body" | awk '/^## What it reuses from woostack-execute/{f=1; next} /^## Verified event protocol/{f=0} f' | tr '\n' ' ')"
assert_contains "$drivers" "A coding worker may only analyze and edit" \
  "coding workers stay inside one issue implementation surface"
assert_contains "$drivers" "run its focused tests and changed-path smoke checks" \
  "coding workers may run only bounded verification and smoke checks"
assert_contains "$drivers" "report exact changed paths, diff identity, commands/results, observations, and status" \
  "coding workers return observations rather than progress mutations"
assert_contains "$drivers" "It leaves all changes uncommitted" \
  "coding workers do not cross the commit boundary"
assert_contains "$drivers" "It cannot commit, push, submit, create, or update a PR" \
  "coding workers cannot perform source-control or PR boundaries"
assert_contains "$drivers" "perform any Git/Graphite/GitHub/Linear source-control or mutation boundary" \
  "coding workers cannot escalate through another provider"
assert_contains "$drivers" 'append `verification`, `precommitReview`, `implementationEvidence`, `reviewResult`' \
  "coding workers cannot append precommit, implementation, or post-PR issue evidence"
assert_contains "$drivers" 'request `inReview`; decide acceptance; or mark work `done`' \
  "coding workers cannot cross lifecycle or acceptance boundaries"
assert_contains "$drivers" "the overnight controller independently re-reads the exact owner, frozen contract, relations, current evidence" \
  "controller refreshes authority after every worker handback"
assert_contains "$drivers" "The controller performs every Git/Graphite/GitHub/Linear and lifecycle" \
  "controller retains all source-control, provider, and lifecycle boundaries"
assert_contains "$drivers" 'appends and reads back `verification` and `precommitReview`' \
  "controller owns canonical pre-commit issue evidence"
assert_contains "$drivers" 'canonical `implementationEvidence` append/read-back' \
  "controller-owned woostack-commit retains finalized implementation evidence"
assert_contains "$drivers" 'later full review/sweep appends post-PR' \
  "reviewResult remains a separate post-PR boundary"
assert_contains "$drivers" "Complete receipts let the controller continue those eligible actions unattended" \
  "controller authority preserves unattended orchestration"
assert_not_contains "$drivers" "A coding worker may analyze, edit, verify, commit" \
  "overnight never delegates controller boundaries to a coding worker"

events="$(printf '%s' "$body" | awk '/^## Verified event protocol/{f=1; next} /^## Pre-flight/{f=0} f' | tr '\n' ' ')"
assert_contains "$events" "append-only remote evidence" \
  "unattended progress is append-only Linear evidence"
assert_contains "$events" "stable client UUID before" \
  "every event mutation preallocates a stable UUID"
assert_contains "$events" "exact issue UUID" \
  "issue events retain exact native issue attribution"
assert_contains "$events" "workflow timestamp" \
  "managed events retain timestamps"
assert_contains "$events" "positive revision" \
  "managed events retain append-only revisions"
assert_contains "$events" "new independent read" \
  "every Linear mutation requires an independent read-back"
for event in assignmentAccepted verification precommitReview implementationEvidence decisionRequest decisionResponse failure reviewResult blocked unblocked handoff progress blockerOpened blockerResolved; do
  assert_contains "$events" "\`$event\`" \
    "overnight records typed $event events"
done
assert_contains "$events" "Missing driver observations, controller-owned issue evidence, review, or" \
  "missing driver observations or controller-owned receipts prohibit acceptance"
assert_contains "$events" 'payload contains only `baseCommitSha`, `headCommitSha`' \
  "implementation evidence uses the canonical commit-only producer payload"
assert_contains "$events" "Canonical PR attribution is separate later evidence" \
  "PR attribution is discovered independently after implementation evidence"
assert_contains "$events" "appended and independently read back by the controller's" \
  "controller-owned woostack-commit produces implementation evidence"
assert_contains "$events" '`precommitReview` follows passing verification' \
  "controller records issue-wide review before commit"
assert_contains "$events" 'no commit/head/PR/GitHub review field' \
  "precommit review has no future or post-PR identity"
assert_contains "$events" '`reviewResult` is exclusively post-PR evidence' \
  "full review remains separate from issue-wide precommit review"
assert_not_contains "$events" "records exact changed paths, commits, branch, PR" \
  "implementation evidence does not absorb later branch or PR attribution"
assert_contains "$events" "Project progress is derived only from the complete issue set" \
  "project progress derives only from verified issue records"
assert_contains "$events" "likewise cannot alter project scope" \
  "workers cannot change project contracts or lead-owned decisions"
assert_contains "$events" 'Immediately before every project `progress`, `blockerOpened`, `blockerResolved`, or `handoff`' \
  "every project progress/blocker/handoff mutation starts with a fresh lead read"
assert_contains "$events" "every phase event, and every native project status mutation" \
  "phase and native project status mutations use the same lead barrier"
assert_contains "$events" "principal kind and native principal ID must exactly match the freshly read pinned lead" \
  "project mutations require exact type-aware pinned-lead identity"
assert_contains "$events" "A non-lead controller may append and read back only typed issue evidence" \
  "a non-lead remains limited to owner-authorized issue evidence"
assert_contains "$events" "must not allocate a project-event UUID" \
  "a non-lead cannot begin or replay a project mutation"

tracks="$(printf '%s' "$body" | awk '/^## Relation-derived tracks/{f=1; next} /^## /{f=0} f' | tr '\n' ' ')"
assert_contains "$tracks" "native Linear relations and stable IDs" \
  "tracks derive from Linear relations and stable issue IDs"
assert_contains "$tracks" '`baseCommitSha` on its frozen `baseBranch`' \
  "independent roots use the frozen base SHA"
assert_contains "$tracks" "exact declared parent issue's verified branch/PR head" \
  "dependency children use exact parent issue/PR ancestry"
assert_contains "$tracks" "non-parent" \
  "joins require merged non-parent dependencies"
assert_contains "$tracks" "exact open parent PR/head" \
  "an in-review parent may provide exact stacked ancestry"
assert_contains "$tracks" "parent claimed \`done\` requires independently verified merge evidence" \
  "done-parent ancestry requires merge truth"
assert_contains "$tracks" "Run one issue and one track at a time" \
  "overnight preserves deterministic sequential execution"

preflight="$(printf '%s' "$body" | awk '/^## Pre-flight/{f=1; next} /^## /{f=0} f' | tr '\n' ' ')"
assert_contains "$preflight" 'spawn the contracted `woostack-review`' \
  "pre-flight checks review-swarm feasibility"
assert_contains "$preflight" "Never replace the full swarm" \
  "unattended execution cannot downgrade the contracted review"
assert_contains "$preflight" '`executionApproved` admits only a fresh run' \
  "executionApproved is fresh-run admission only"
assert_contains "$preflight" '`executing` or `inReview` admits only an exact retained-run resume' \
  "executing and inReview are receipt-backed resume states"
assert_contains "$preflight" '`assignmentAccepted` for every begun issue' \
  "resume binds the retained run to assignment acceptance"
assert_contains "$preflight" "every typed receipt through the observed" \
  "resume requires a complete monotonic typed receipt chain"
assert_contains "$preflight" "registry/worktree/branch/commit/Graphite/PR state" \
  "resume reconciles exact retained Git and PR state"
assert_contains "$preflight" "issue owner and project membership, and pinned" \
  "resume re-verifies issue and project ownership"
assert_contains "$preflight" "Skip every exact verified boundary" \
  "resume continues at the first proven-missing boundary without replay"
assert_contains "$preflight" "Foreign or stale run identity" \
  "foreign and stale runs fail closed"
assert_contains "$preflight" "Do not allocate a new run or event UUID" \
  "partial or unknown resume state cannot mint replacement UUIDs"
assert_contains "$preflight" "without a local fallback or replay" \
  "unknown resume outcomes block without replay"
assert_contains "$preflight" "only through the exact pinned lead" \
  "pre-flight project blockers remain lead-owned"

sweep="$(printf '%s' "$body" | awk '/^## Post-implementation review sweep/{f=1; next} /^## /{f=0} f' | tr '\n' ' ')"
assert_contains "$sweep" 'review_sweep.max_rounds' \
  "overnight preserves the bounded sweep cap"
assert_contains "$sweep" "blocking-only no-progress guard" \
  "overnight preserves the no-progress guard"
assert_contains "$sweep" "issue-scoped \`reviewResult\`" \
  "sweep results bind the exact issue"
assert_contains "$sweep" "Any missing driver observation, controller-owned issue evidence" \
  "sweep cannot accept missing driver observations or controller receipts"
assert_contains "$sweep" '`done-with-findings` requires the exact full-review GitHub receipt' \
  "done-with-findings retains the reviewed-head A receipt"
assert_contains "$sweep" 'sweep deliberately does not re-review this' \
  "done-with-findings does not fabricate a head-B re-review"

handback="$(printf '%s' "$body" | awk '/^## Terminal handback/{f=1; next} /^## /{f=0} f' | tr '\n' ' ')"
assert_contains "$handback" "Do not write a local report" \
  "terminal output is rendered, not authored locally"
assert_contains "$handback" 'do not append issue or project `handoff` events merely to record' \
  "ordinary open actions do not misuse ownership handoff events"
assert_contains "$handback" "deliberate assignee/delegate change with read-back" \
  "real handoffs require verified ownership transfer"
assert_contains "$handback" "Paginate and independently re-read" \
  "terminal output is reconstructed from fresh remote records"
assert_contains "$handback" "render the handback directly in the terminal" \
  "terminal handback has no filesystem delivery target"
assert_contains "$handback" "Project progress" \
  "terminal progress is a verified issue-set derivation"

hard="$(printf '%s' "$body" | awk '/^## Hard constraints/{f=1} f' | tr '\n' ' ')"
assert_contains "$hard" "No local report" \
  "the terminal handback is not a filesystem artifact"
assert_contains "$hard" "never author, read, accept, or prune" \
  "no report producer, reader, acceptance, or prune path may return"
assert_contains "$hard" "One issue, observation-only worker" \
  "coding delegation stays one-issue, uncommitted, and observation-only"
assert_contains "$hard" "Controller-owned evidence and source control" \
  "controller retains evidence, source-control, PR, and lifecycle authority"
assert_contains "$hard" "Never downgrade to self-review" \
  "the bounded sweep cannot silently downgrade review"
assert_contains "$hard" "only all-done permits" \
  "project completion remains all-issues-done only"
assert_contains "$hard" "Receipt-backed admission" \
  "hard constraints retain exact fresh-vs-resume admission"
assert_contains "$hard" "Fresh lead for every project mutation" \
  "hard constraints retain project lead authority"
assert_contains "$hard" 'canonical `implementationEvidence` contains only' \
  "hard constraints retain the canonical implementation payload"

finish
