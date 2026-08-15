---
name: woostack-execute-overnight
description: Execute an approved Linear project or local run manifest unattended through isolated Graphite worktrees, verification, bounded review sweeps, and truthful handback. Requires an exact project or run ID and matching approval records; never merges.
---

# woostack-execute-overnight

Execute an approved Linear project or local run manifest through the
[`woostack-execute`](../woostack-execute/SKILL.md) controller, but unattended. Reuse its canonical
admission, fast implementation-worker, worktree, dependency/ancestry, verification, commit, and
recovery boundaries, while retaining this skill's bounded review-sweep and independent-track recovery
safety. This command requires an exact `--project` or `--run`; it never creates or revises a project,
and never merges.

Git, Graphite, and canonical GitHub reads own source, ancestry, PR, review, and delivery truth. The
shared [repository advancement contract](../woostack-init/references/artifact-backends.md#repository-ancestry-is-separate-from-approval-identity)
keeps branch/ref/head movement outside content receipt identity while requiring fresh ancestry
re-admission and all collision, rewrite, and PR-base safeguards. Input requires the exact project or
exact local run manifest, direct increment tasks/issues, native or local dependency graph, and the
matching content-bound approval records required by normal Execute admission.

## Commands

```text
/woostack-execute-overnight <approved project> --project <exact Linear URL|UUID>
/woostack-execute-overnight --run <exact-run-id> [--recheck]
```

`--project` and `--run` are mutually exclusive; exactly one is required. The command accepts only an
already-approved project or approved local run manifest and has no issue or alternate-driver mode.

## Admission

Require:

- in provider mode: one exact approved project identity supplied by URL or UUID, the complete approved
  project specification, all current direct issues, native dependency graph, and exactly matching
  `projectSpecApprovalRecord` and `executionPlanApprovalRecord` required by
  [`woostack-execute` admission](../woostack-execute/SKILL.md#provider-admission-one-exact-resource-and-two-matching-records);
- in local run mode: one exact approved run ID at the repository-local ignored
  `.woostack/tmp/runs/<run-id>/` path; ordered no-follow ancestor checks; owner-only `0700`
  directory; owner-only `0600` regular `manifest.json`, gate, and lock files; exact manifest
  revision, `repoRoot`, `status`, `taskExecutions`, stable-task DAG, and matching local
  `projectSpecApprovalRecord` and `executionPlanApprovalRecord` required by
  [`woostack-execute` local run admission](../woostack-execute/SKILL.md#local-run-admission-exact-manifest-and-gate-file-receipts);
- when `--recheck` is provided with `--run`: bounded [`woostack-harden`](../woostack-harden/SKILL.md)
  recheck against current trunk; byte-identical files preserve both records, changed project-spec
  bytes return to gate 1, and changed execution-plan bytes return to gate 2. Without `--recheck`,
  compatible parent advance keeps existing approvals;
- stable task IDs, complete bounded contracts, acceptance/verification/smoke clauses, and exclusive
  responsibility surfaces;
- an acyclic dependency graph with one declared stable canonical parent branch per dependent task;
- canonical repository, configured integration parent branch, and last independently admitted tip;
- explicit unattended handoff (`Run overnight` or intent-equivalent wording); and
- no unresolved decision that requires product, security, data-loss, or scope judgment.

Read repository policy, deterministic task paths, `git worktree list --porcelain`, filesystem state,
local/remote branches and commits, complete dirty/index/diff state, Git/Graphite ancestry, and fully
paginated GitHub PR/review/check/thread state. Apply the shared repository advancement contract to
the approved parent-branch intent, last admitted tip, and current evidence, then carry its admitted
tip and retained-work state into the normal controller. Independently reject duplicate checkouts,
branches, commits, or PRs; unexplained work; overlapping surfaces; stale plans; ambiguous recovery;
or a task that cannot be safely bounded without human judgment.

Independently re-read the complete project specification / manifest, all current direct tasks/issues,
dependencies, and approval records/receipts and require exact equality. Repeat at every boundary
required by the execution controller. Drift, incomplete pagination, provider unavailability, or
conflict blocks execution with no local or alternate-provider fallback. The controller never amends
the approved project specification or graph.

## Fixed execution loop

Follow the [execution controller](../woostack-execute/references/controller.md) for each admitted
task or issue:

1. in local run mode select only the lowest-ordinal unfinished task; in provider mode derive the
   currently dependency-ready issue set from the approved DAG and repository evidence;
2. admit each selected task or issue only when its deterministic path is collision-free;
3. create/verify its isolated worktree and Graphite branch from the latest compatible admitted
   parent-branch tip; retained work preserves its recorded start/head and is never silently rebased,
   reset, recreated, or reassigned;
4. dispatch the configured fast implementation worker under the
   [normal Execute worker boundary](../woostack-execute/SKILL.md#worker-and-verification-boundary)
   through Red → Green → Refactor, focused verification, and smoke observation;
5. run specification review then quality review on one unchanged complete diff identity;
6. invoke [`woostack-commit`](../woostack-commit/SKILL.md) for the controller-owned commit and PR
   boundary (with `--issue` in provider mode; without `--issue` in local run mode);
7. run the bounded bottom-up [`woostack-sweep`](../woostack-sweep/SKILL.md) for the affected stack;
8. persist and independently read back the delivery checkpoint (to Linear in provider mode; via
   manifest CAS with no-follow reopen in local run mode);
9. independently read back worktree, dirty state, branch/head/base, PR, reviews, checks, threads,
   and ancestry; and
10. hand back direct evidence and remove only a completed task's exact clean worktree.

Local run mode is strictly sequential: never admit a second task from the same run until the first
task's complete delivery checkpoint is independently read back. Distinct local run IDs may execute
concurrently only when paths, responsibility surfaces, profiles, worktrees, branches, and PRs are
disjoint. Provider mode retains its existing rule: dependent issues never run concurrently, while
independent roots may run concurrently only across fully disjoint tracks and provider sessions.

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

A decision outside those bounds preserves the exact question and blocks local run mode before the
next task. In provider mode, it blocks the affected issue and descendants; another
dependency-independent track may continue only when the complete graph and responsibility surfaces
prove that continuation cannot be invalidated by the answer.

## Failure isolation and recovery

Classify every stop:

- **task-local failure** — preserve its worktree and direct repository evidence and block
  descendants;
- **track-local review or submission failure** — preserve branch/PR evidence and block only tasks
  that depend on that head;
- **shared invariant failure** — stop every affected track;
- **required provider failure** — stop affected execution at the last verified boundary; and
- **unknown mutation outcome** — re-read the exact Git/Graphite/GitHub or project/manifest identity
  before retrying anything.

In local run mode, every stop retains the current task's worktree and recovery evidence, CAS-records
`status: "blocked"` in `taskExecutions`, and stops that run before the next ordinal. Provider mode
retains the track-local isolation above.

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

An explicit user or owning-controller decision to abandon the project or local run stops every new
dispatch and cancels every active implementation, verification, review, commit, or submission driver
before its next mutation. Preserve current worktrees, branches, commits, and PRs without cleanup,
re-read Git/Graphite/GitHub after cancellation, and verify every driver is quiescent before closure
or terminal handback.

In provider mode, follow the [Linear artifact contract](../woostack-init/references/artifact-backends.md)
to set only the exact project's native status to the configured `projectStatuses.canceled` value and
independently read the closure back. In local run mode, mark the run manifest as abandoned (`abandoned: true`).
Never create a project merely to cancel it or bulk-change issue states.

A task failure, blocker, pause, ordinary handoff, or replan is not abandonment and leaves the
project/run open. A failed or unknown closure becomes a truthful terminal blocker with the stable
identity and safe retry boundary; unattended execution does not resume.

## Artifact synchronization

For an exact approved Linear project, mirror only directly observed task/PR evidence to its exact project
or direct issue. Perform one minimal mutation at a real boundary, use a stable operation ID, preserve
unrelated content, and independently read back the target. Delivery notes do not change approved
project/issue content or dependencies. Except for project closure, do not mutate assignee, delegate,
native status, relations, membership, or archival state.

In local run mode, mirror writes are best effort only: any mirror failure emits a warning and never
invalidates or erases verified repository delivery evidence.

## Terminal handback
Return one truthful report derived from fresh reads:

- canonical repository, stable parent branch, and last admitted parent tip;
- exact approved project identity or run ID, project specification, direct task/issue DAG, and both
  approval records/receipts/rechecks;
- per task/issue: status, worktree/branch/parent, changed paths, verification/smoke results, reviewer
  verdicts, commit SHA, PR URL/head/base, checks/threads, and safe resume boundary;
- completed, blocked, skipped-dependent, and still-independent sets;
- Graphite stack ancestry and sweep outcome; and
- every unresolved decision or unknown mutation outcome.
Use task states `completed`, `blocked`, `skipped-dependent`, or `not-started`; do not call
submitted or reviewed work merged. Never claim test, review, PR, artifact, or completion evidence
that was not directly observed.

Overnight's terminal repository boundary is a verified, review-clean, open PR or PR stack. It never
marks a PR ready, enables auto-merge, enters a merge queue, retargets a PR for merge, or merges.
`Completed`, `delivered`, and a clean sweep describe evidence at that open-PR boundary only. No task
wording, completion state, inferred request, or explicit user request can widen this unattended
workflow into merge authority; report the conflict and stop without that mutation.

## Hard constraints

- Exactly one of `--project` or `--run` is required; no issue or alternate-driver mode.
- Both approval records or receipts must exactly match the independently read project graph or
  gate-file bytes.
- No inferred approval, ownership, acceptance, or artifact context.
- No fuzzy discovery as a substitute for the approved input contract.
- No self-review, self-acceptance, force-push, protected-primary edit, or merge.
- No continuation across an unproved dependency or overlapping responsibility surface.
- No retry before independent state discovery after an unknown outcome.
