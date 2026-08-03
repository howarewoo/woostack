---
name: woostack-execute-overnight
description: Execute an approved Linear project unattended through isolated Graphite worktrees, verification, bounded review sweeps, and truthful handback. Requires an exact project and matching approval records; never merges.
---

# woostack-execute-overnight

Execute an approved Linear project through the
[`woostack-execute`](../woostack-execute/SKILL.md) project controller, but unattended. Reuse its
canonical admission, fast implementation-worker, worktree, dependency/ancestry, verification,
commit, and recovery boundaries, while retaining this skill's bounded review-sweep and
independent-track recovery safety. This command is explicit project-only; it never becomes a Build
choice, creates or revises a project, and never merges.

Git, Graphite, and canonical GitHub reads own source, ancestry, PR, review, and delivery truth.
Project input requires the exact project, direct increment issues, native dependency graph, and the
two content-bound approval records required by the normal Execute admission. Linear never assigns
workers or proves repository delivery.

## Commands

```text
/woostack-execute-overnight <approved project> --project <exact Linear URL|UUID>
```

The exact `--project` is required. The command accepts only an already-approved project and has no
issue or alternate-driver mode.

## Admission

Require:

- one exact approved project identity supplied by URL or UUID;
- the complete approved project specification, all current direct issues, native dependency graph,
  and exactly matching `projectSpecApprovalRecord` and `executionPlanApprovalRecord` required by
  [`woostack-execute` admission](../woostack-execute/SKILL.md#admission-one-exact-resource-and-two-matching-records);
- stable task IDs, complete bounded contracts, acceptance/verification/smoke clauses, and exclusive
  responsibility surfaces;
- an acyclic dependency graph with one declared Git parent per dependent task;
- canonical repository, configured integration base, and frozen start commit;
- explicit unattended handoff (`Run overnight` or intent-equivalent wording); and
- no unresolved decision that requires product, security, data-loss, or scope judgment.

Read repository policy, deterministic task paths, `git worktree list --porcelain`, filesystem state,
local/remote branches and commits, complete dirty/index/diff state, Git/Graphite ancestry, and fully
paginated GitHub PR/review/check/thread state. Reject duplicate checkouts, branches, commits, or
PRs; unexplained work; moved ancestry; overlapping surfaces; stale plans; ambiguous recovery; or a
task that cannot be safely bounded without human judgment.

Independently re-read the complete project specification, all current direct issues, native
dependencies, and responsible-user approval events and require exact equality with both approval
records. Repeat at every boundary required by the execution controller. Drift, incomplete
pagination, provider unavailability, or conflict blocks execution with no local or alternate-
provider fallback. The controller never amends the approved project specification or graph.

## Fixed execution loop

Follow the [execution controller](../woostack-execute/references/controller.md) for each admitted
issue:

1. derive the currently dependency-ready issue set from the approved DAG and repository evidence;
2. admit each selected issue only when its deterministic path is collision-free;
3. create/verify its isolated worktree and Graphite branch at the exact approved base/parent head;
4. dispatch the configured fast implementation worker under the
   [normal Execute worker boundary](../woostack-execute/SKILL.md#worker-and-verification-boundary)
   through Red → Green → Refactor, focused verification, and smoke observation;
5. run specification review then quality review on one unchanged complete diff identity;
6. invoke [`woostack-commit`](../woostack-commit/SKILL.md) for the controller-owned commit and PR
   boundary;
7. run the bounded bottom-up [`woostack-sweep`](../woostack-sweep/SKILL.md) for the affected stack;
8. independently read back worktree, dirty state, branch/head/base, PR, reviews, checks, threads,
   and ancestry; and
9. hand back direct evidence and remove only a completed issue's exact clean worktree.

The controller repeats the exact project/issue/dependency/approval-record check after every worker
handback, before every redispatch, immediately before commit, and before selecting another
increment. Never process two dependent issues concurrently. Independent roots may run concurrently
only when paths/surfaces, runs, profiles, worktrees, branches, PRs, and provider sessions are
disjoint.

## Autonomous decision policy

Unattended execution may make ordinary implementation choices already bounded by an approved task:
code placement following repository convention, naming, local refactoring, and test selection.

It must not invent or change:

- product behavior, acceptance, scope, or non-goals;
- architecture or public API contracts not resolved by the plan;
- security/privacy posture, destructive migration, or data-loss handling;
- dependency edges or Graphite parentage;
- ownership/allocation, approval gates, or merge policy; or
- canonical or selected artifact content that conflicts with repository evidence.

A decision outside those bounds blocks only its task and descendants. Preserve the exact question
and continue another dependency-independent track only when the complete graph and responsibility
surfaces prove that continuation cannot be invalidated by the answer.

## Failure isolation and recovery

Classify every stop:

- **task-local failure** — preserve its worktree and direct repository evidence and block
  descendants;
- **track-local review or submission failure** — preserve branch/PR evidence and block only tasks
  that depend on that head;
- **shared invariant failure** — stop every affected track;
- **required project provider failure** — stop affected execution at the last verified boundary; and
- **unknown mutation outcome** — re-read the exact Git/Graphite/GitHub or project identity before
  retrying anything.

Never retry with a new task ID, operation ID, branch, commit, or PR. Never reset, clean, stash,
delete, overwrite, reassign, force-push, protected-primary edit, or create around a collision.

A failed check is not automatically task-local: inspect whether it proves a shared regression. A
missing worker response is unknown outcome; verify process/worktree state before redispatch so two
workers never write the same surface.

## Bounded review sweep

For each submitted stack, run full review, address confirmed findings through the same task's coding
profile, restack only through Graphite, and re-review the resulting head. Obey sweep's round/no-
progress bounds. A clean result requires direct evidence for the current head: reviews/checks pass,
blocking threads resolve, ancestry is correct, and no uncommitted worker changes remain.

The implementing coder never acts as its own reviewer. Review workers remain read-only and have no
repository-write, GitHub-posting, artifact, acceptance, or merge authority.

## Project abandonment

An explicit user or owning-controller decision to abandon the project stops every new dispatch and
cancels every active implementation, verification, review, commit, or submission driver before its
next mutation. Preserve current worktrees, branches, commits, and PRs without cleanup, re-read
Git/Graphite/GitHub after cancellation, and verify every driver is quiescent before project closure
or terminal handback.

Follow the [Linear artifact contract](../woostack-init/references/artifact-backends.md) to set only
the exact project's native status to the configured `projectStatuses.canceled` value and
independently read the closure back. Never create a project merely to cancel it or bulk-change issue
states.

A task failure, blocker, pause, ordinary handoff, or replan is not abandonment and leaves the
project open. A failed or unknown closure becomes a truthful terminal artifact blocker with the
stable project identity and safe retry boundary; unattended execution does not resume.

## Artifact synchronization

For the exact approved project, mirror only directly observed task/PR evidence to its exact project
or direct issue. Perform one minimal mutation at a real boundary, use a stable operation ID, preserve
unrelated content, and independently read back the target. Delivery notes do not change approved
project/issue content or dependencies. Except for project closure, do not mutate assignee, delegate,
native status, relations, membership, or archival state.

An approval-record failure blocks before repository mutation; a delivery-note failure after verified
repository delivery does not erase that repository evidence.

## Terminal handback
Return one truthful report derived from fresh reads:

- canonical repository and frozen base;
- exact approved project identity, project specification, direct issue DAG, and both approval
  records/rechecks;
- per issue: status, worktree/branch/parent, changed paths, verification/smoke results, reviewer
  verdicts, commit SHA, PR URL/head/base, checks/threads, and safe resume boundary;
- completed, blocked, skipped-dependent, and still-independent sets;
- Graphite stack ancestry and sweep outcome; and
- every unresolved decision or unknown mutation outcome.
Use issue states `completed`, `blocked`, `skipped-dependent`, or `not-started`; do not call
submitted or reviewed work merged. Never claim test, review, PR, artifact, or completion evidence
that was not directly observed.

## Hard constraints

- Exact `--project` is required; no issue or alternate-driver mode.
- Both `projectSpecApprovalRecord` and `executionPlanApprovalRecord` must exactly match the
  independently read project graph and responsible-user approval events.
- No inferred approval, ownership, acceptance, or artifact context.
- No local plan/report as a substitute for the approved input contract.
- No self-review, self-acceptance, force-push, protected-primary edit, or merge.
- No continuation across an unproved dependency or overlapping responsibility surface.
- No retry before independent state discovery after an unknown outcome.
