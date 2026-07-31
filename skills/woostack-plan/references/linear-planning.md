# Linear planning capability contract

This optional persistence contract applies only when the caller selected an exact Linear project.
The canonical
[artifact contract](../../woostack-init/references/artifact-backends.md) owns selection, trust,
provider, mutation, and read-back rules. The
[retained artifact context](../../woostack-build/references/linear-context.md) owns repository and
resource identity for this synchronization path.

## Required input

Planning receives one verified feature-project UUID or exact Linear URL and a retained context. A
standalone invocation establishes the same context before reading the project. Require:

- one ownership-valid `feature` project in the configured workspace/team and repository;
- one complete, valid chain of current unsuperseded phase updates whose head is `specApproved` or
  `planning`, except for an explicit evidence-backed `ready → planning` replan;
- the current complete `specHardened` body and its following `specApproved` event;
- a complete paginated issue/relation snapshot; and
- no conflicting native status, ownership, branch, pull-request, or event evidence.

The specification is project-update content; the managed issue graph is the plan.

## Desired increment graph

Build the whole desired graph before mutating Linear. Each independently shippable increment maps
to exactly one managed `increment` issue and at most one implementation PR. Every desired issue
contains:

- a stable client UUID allocated before its first mutation, a unique positive integer ordinal, and
  the current native project ID;
- objective, exact files and responsibilities, complete Red→Green→Refactor tasks, acceptance
  coverage, automated verification, and manual verification;
- sorted dependency client IDs that resolve to native issues in the same project; and
- exactly one Git parent declaration, deferred during planning: a root records
  `{"kind":"projectBase","freezeOwner":"woostack-build"}`, while a stacked increment names one
  dependency issue. Planning never records a branch or SHA. At build-ready,
  `woostack-build` replaces each root declaration with the concrete frozen base branch and SHA.

Ordinals are presentation order, never implicit dependency edges. Native Linear dependency/blocker
relations are authoritative and must agree with the native IDs recorded in managed metadata. Reject
cycles, duplicate UUIDs or ordinals, unknown or cross-project dependencies, relation drift,
uncovered acceptance criteria, and Graphite ancestry that cannot represent the declared parent.
Independent tracks are explicit dependency roots; never infer or auto-partition them.

## Phase entry

For initial planning, append one `planning` project event with a new stable event UUID,
`revision: 1`, the current `specApproved` native update ID as `predecessorId`, and the relevant
specification/update IDs in sorted `relatedIds`. The readable body records the planning scope and
acceptance-coverage basis. Independently read back the exact envelope and the project. The native
project category remains `backlog`; do not append another phase event merely because the native
status already has the required category.

When the current phase is already `planning`, resume that exact phase after validating the chain;
never append a same-phase retry. Correct a malformed current planning event only through the
append-only revision procedure below.

A `ready → planning` entry is allowed only for an explicit replan supplied with independently
verified evidence that every managed increment has no implementation branch or pull request. Its
new `planning` event uses a new stable UUID, points to the current `ready` native update, relates
every current increment issue ID, and records in its readable body the complete issue snapshot,
repository evidence query, and explicitly empty branch/PR result. Update native project status to
the configured `backlog` mapping and independently read both mutations back. Missing, partial,
stale, or conflicting replan evidence blocks without issue mutation.

## Reconcile by stable identity

1. Discover the complete project issue and native relation sets and match only the managed identity
   tuple. Titles never match an issue. An incomplete or unknown relation read blocks before mutation.
2. Allocate client UUIDs once for desired increments that do not yet exist. On an unknown create
   outcome, rediscover that exact UUID before any retry.
3. Create missing issues and update retained issues without changing their client UUIDs, project,
   repository, or role. Preserve execution evidence verbatim.
4. Compute relation creates as `desired - existing` and deletes as `existing - desired`; never
   replay a satisfied delta. After mutation, independently read every relation in the complete
   desired set and prove every deleted relation is absent. An unknown create or delete outcome
   blocks until complete rediscovery proves the exact relation's presence or absence; never retry
   from the mutation response.
5. Independently read every issue plus the complete project, current phase chain, comments, work
   owners, native states, and branch/PR attribution. Compare that snapshot with the whole
   desired graph, not only changed issues.

A replan may add, reorder, update, or rewire unstarted increments while preserving stable
identities. This workflow never deletes or silently detaches a managed increment. An issue with
branch, PR, assignment-acceptance, implementation, review, verification, acceptance, or failure
evidence cannot be rewritten as unstarted. A scope removal or evidence conflict returns to the
build owner for an explicit project decision or abandonment.

## Corrections and event evidence

Managed project updates and issue comments are append-only.

A phase event correction may target only the current phase head. Append the same stable event
`clientId` at exactly the next revision, preserve its event kind, project identity, and predecessor,
and set `supersedesId` to that current phase update's exact native ID. Before any further action,
independently read the corrected event and complete one-head phase chain back. A historical or
non-head phase correction stops before mutation and requires explicit human-directed recovery; it
never cascades descendant revisions or implies a multi-write transaction.

A non-phase project event correction may target only that event's current revision without being
the phase head. Append the same stable event `clientId` at exactly the next revision, preserve its
event kind, project identity, and contextual phase predecessor, and set `supersedesId` to that
current event revision's exact native update ID. Independently read the corrected record back before
action. It does not advance, replace, or rewrite the phase chain and never cascades descendant
revisions.

A managed issue comment/event correction may target only that issue event's current revision.
Append the same stable event `clientId` at exactly the next revision, preserve its event kind and
exact project-plus-issue identity, and set `supersedesId` to that current comment/event revision's
exact native ID. Independently read the corrected record back before further action. It has no phase-head
requirement and never rewrites descendants.

For every correction class, a missing or stale superseded record, wrong identity, event kind, or
context, skipped or duplicate revision, competing current revisions, missing receipt, or ambiguity
fails closed before further mutation. Append `decision`/`progress` project events or canonical issue
events for durable planning evidence; those events point at the current phase head but do not
advance it.

## Output and boundary

Return only after an independent read proves one current `planning` chain head, one managed issue
per increment, exact native project membership and dependencies, stable ordinals and identities,
complete contract/acceptance coverage, expected `backlog` project category, expected `planned`
issue states, and no unexplained implementation evidence.

Planning owns no approval gate, never appends `ready`, never freezes the repository base, never
creates a branch or PR, and never executes, commits, merges, or writes a development artifact to
the repository. The caller hardens the issue graph, verifies it again, and owns the later `ready`
phase and execution handoff.
