---
name: woostack-execute-overnight
description: Execute an approved dependency-aware plan unattended through isolated Graphite worktrees, verification, bounded review sweeps, and a truthful terminal handback. Optional Linear artifacts may mirror the plan and evidence. Never merges.
---

# woostack-execute-overnight

Execute an approved dependency-aware plan the way
[`woostack-execute`](../woostack-execute/SKILL.md) does, but unattended. Reuse its controller,
inline/subagent drivers, Red → Green → Refactor cadence, worktree isolation, dependency/ancestry
checks, verification, review, commit, and recovery boundaries. This skill changes only how a safe
independent track continues when another track blocks. It never merges.

Git, Graphite, and canonical GitHub reads own source, ancestry, PR, review, and delivery truth.
Linear projects/issues are optional artifacts for specifications, plans, fixes, and synchronization
notes. They are not an execution queue, ownership system, approval gate, or completion proof.

## Commands

```text
/woostack-execute-overnight <approved plan> [--inline|--subagent]
/woostack-execute-overnight <approved plan> --project <exact Linear URL|UUID> [--inline|--subagent]
```

Without an exact artifact flag, make no Linear call. `--project` opts into context/synchronization
under the [optional artifact contract](../woostack-init/references/artifact-backends.md); it never
authorizes execution. `--inline` and `--subagent` select the execute driver only.

## Admission

Require:

- one complete explicitly approved implementation plan;
- stable task IDs, complete bounded contracts, acceptance/verification/smoke clauses, and exclusive
  responsibility surfaces;
- an acyclic dependency graph with one declared Git parent per dependent task;
- canonical repository, configured integration base, and frozen start commit;
- explicit unattended handoff (`Run overnight` or intent-equivalent wording); and
- no unresolved decision that requires product, security, data-loss, or scope judgment.

Read repository policy, Git/Graphite ancestry, local worktrees/registry, branches, commits, and fully
paginated GitHub PR/review/check/thread state. Reject duplicate claims, unexplained work, moved
ancestry, overlapping surfaces, stale plans, ambiguous recovery, or a task that cannot be safely
bounded without human judgment.

If exact artifact context was supplied, read it independently and compare its specification/plan
fields with the approved plan. Conflict blocks artifact use and the affected task; it does not
rewrite the plan. Missing provider access blocks only requested synchronization unless persistence
was explicitly part of the deliverable.

## Fixed execution loop

Follow the [execution controller](../woostack-execute/references/controller.md) for each admitted
task:

1. derive the currently dependency-ready task set from the approved DAG and repository evidence;
2. admit one task per controller/coder run and atomically claim its stable worktree registry key;
3. create/verify the isolated Graphite branch at the exact approved base/parent head;
4. run the selected [inline](../woostack-execute/references/inline-driver.md) or
   [subagent](../woostack-execute/references/subagent-driver.md) driver through Red → Green →
   Refactor, focused verification, and smoke observation;
5. run specification review then quality review on one unchanged complete diff identity;
6. invoke [`woostack-commit`](../woostack-commit/SKILL.md) for the controller-owned commit and PR
   boundary;
7. run the bounded bottom-up [`woostack-sweep`](../woostack-sweep/SKILL.md) for the affected stack;
8. independently read back branch/head/base, PR, reviews, checks, threads, and ancestry; and
9. hand back direct evidence and release only a completed task's worktree claim.

Never process two dependent tasks concurrently. Independent roots may run concurrently only when
paths/surfaces, runs, profiles, worktrees, branches, PRs, and provider sessions are disjoint.

## Autonomous decision policy

Unattended execution may make ordinary implementation choices already bounded by an approved task:
code placement following repository convention, naming, local refactoring, and test selection.

It must not invent or change:

- product behavior, acceptance, scope, or non-goals;
- architecture or public API contracts not resolved by the plan;
- security/privacy posture, destructive migration, or data-loss handling;
- dependency edges or Graphite parentage;
- ownership/allocation, approval gates, or merge policy; or
- optional artifact content that conflicts with repository evidence.

A decision outside those bounds blocks only its task and descendants. Preserve the exact question
and continue another dependency-independent track only when the complete graph and responsibility
surfaces prove that continuation cannot be invalidated by the answer.

## Failure isolation and recovery

Classify every stop:

- **task-local failure** — preserve its worktree/registry and block descendants;
- **track-local review or submission failure** — preserve branch/PR evidence and block only tasks
  that depend on that head;
- **shared invariant failure** — stop every affected track;
- **provider/artifact failure** — stop synchronization only, unless persistence is required; and
- **unknown mutation outcome** — re-read the exact Git/Graphite/GitHub or artifact identity before
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

## Optional artifact synchronization

Only when selected, mirror the approved plan and requested task/PR evidence to the exact project or
issue. Perform one minimal mutation at a real boundary, use a stable operation ID, preserve
unrelated content, and independently read back the target. Do not mutate assignee, delegate, native
status, relations, membership, or archival state unless the caller explicitly requested that exact
metadata operation.

Artifact synchronization results are reported separately. Never delay safe repository handback
merely to manufacture an artifact lifecycle.

## Terminal handback

Return one truthful report derived from fresh reads:

- canonical repository and frozen base;
- approved plan identity and task DAG;
- per task: status, worktree/branch/parent, changed paths, verification/smoke results, reviewer
  verdicts, commit SHA, PR URL/head/base, checks/threads, and safe resume boundary;
- completed, blocked, skipped-descendant, and still-independent sets;
- Graphite stack ancestry and sweep outcome;
- optional artifact URL/UUID and synchronization result; and
- every unresolved decision or unknown mutation outcome.

Use task states `completed`, `blocked`, `skipped-dependent`, or `not-started`; do not call submitted
or reviewed work merged. Never claim test, review, PR, artifact, or completion evidence that was not
directly observed.

## Hard constraints

- No Linear issue/project prerequisite.
- No inferred approval, ownership, acceptance, or artifact context.
- No local plan/report as a substitute for the approved input contract.
- No self-review, self-acceptance, force-push, protected-primary edit, or merge.
- No continuation across an unproved dependency or overlapping responsibility surface.
- No retry before independent state discovery after an unknown outcome.
