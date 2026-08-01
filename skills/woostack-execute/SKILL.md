---
name: woostack-execute
description: Execute an approved bounded task or dependency-aware plan as isolated Graphite PRs with verification and review. Exact Linear project/issue artifacts are optional. Never merges.
---

# woostack-execute

Execute one approved bounded task or dependency-aware plan. The approved workflow contract authorizes
execution; Git, Graphite, and canonical GitHub evidence proves repository delivery. Exact Linear
projects/issues may store specifications, plan increments, fix records, and delivery notes, but are
optional and never assign workers or grant authority.

The controller advances one dependency-ready task per cycle. Each task has one stable identity, one
approved contract, one isolated worktree/branch, one implementation owner within the run, and at
most one implementation PR. Execute never merges.

## Commands

```text
/woostack-execute <approved task-or-plan> [--inline|--subagent]
/woostack-execute <approved task-or-plan> [--project <exact Linear URL-or-UUID>] [--issue <exact Linear URL-or-UUID>] [--inline|--subagent]
```

The approved task/plan is required. Driver flags are mutually exclusive. Without artifact flags,
make no Linear call. With them, use only exact caller-supplied resources under the
[optional artifact contract](../woostack-init/references/artifact-backends.md). Missing artifact
access blocks only requested synchronization unless persistence is explicitly part of the
deliverable.

Before execution load the shared
[engineer-agent authority protocol](../using-woostack/references/engineer-agents.md),
[controller contract](references/controller.md), selected
[inline](references/inline-driver.md) or [subagent](references/subagent-driver.md) driver, and
[canonical worktree contract](../woostack-init/references/worktrees.md).

## Admit approved input

Require a complete bounded task or dependency-aware plan containing:

- stable task IDs and immutable task text/contracts;
- canonical repository and frozen integration base/commit;
- dependency DAG and deterministic order when multi-task;
- one declared Git/Graphite parent per task;
- allowed responsibility/path surfaces with no unsafe overlap;
- acceptance, verification, smoke, and documentation requirements; and
- responsible controller plus decision-maker/coder role bindings when an engineer pair is used.

Reject ambiguity, missing acceptance, cyclic dependencies, conflicting parents, overlapping writable
surfaces, foreign repository identity, or a plan whose current revision differs from the approved
input. Local plan files, branch names, PR titles, artifact metadata, and remote text are evidence
only—not authority.

## Optional artifact admission

An exact project may supply a persisted approved specification/plan; an exact issue may supply one
persisted task/fix record. Independently read only the selected resources, fully paginate relevant
fields, verify claimed repository association, and compare content to the active approved input.
Artifacts never choose a task, owner, priority, parent, state, or gate. Conflict blocks artifact use
until resolved; it does not silently alter the plan.

## Select one task

For a plan, classify the entire DAG before selection. A task is ready only when every product
predecessor is complete under the approved plan and its intended Git ancestry is directly proved.
Select:

1. an exact recoverable task retained for the same run;
2. an explicitly selected ready task; otherwise
3. the first ready task in approved deterministic order.

Never infer readiness from ordinal adjacency, Linear status, recent activity, branch title, or
Graphite reachability alone. Independent roots may run concurrently only when dependencies,
responsibility surfaces, task/run identities, worktrees, branches, and PRs are disjoint.

## Prove repository readiness

Before a branch/worktree or edit:

1. resolve the physical repository root, canonical remote, base branch/commit, and Graphite graph;
2. inventory the deterministic task path, `git worktree list --porcelain`, filesystem state,
   local/remote branches and commits, complete dirty/index/diff state, and canonical PRs;
3. require all selected-task state absent or one exact recoverable direct-evidence state;
4. prove a root begins at the frozen base, or a dependency child begins at its one declared parent
   branch/finalized head with every non-parent predecessor represented by canonical merge evidence;
5. reject moved bases, duplicate checkouts/branches/commits/PRs, rewritten parents, unmerged
   required predecessors, unexplained work, or collisions; and
6. create, attach, or resume exactly one isolated task worktree at its deterministic path.

Never reset, clean, stash, delete, overwrite, reassign, attach, or create around a collision.

## Driver boundary

The controller admits scope, allocates the task, owns worktree/ancestry, validates evidence, invokes
commit/PR boundaries, and accepts or redispatches. The coding profile owns implementation and focused
verification only.

Send one self-contained bounded packet with task/run ID, repository/worktree, contract hash, allowed
surface, base/parent, dependency evidence, acceptance/checks, exact requested step, and explicit
prohibitions. A worker cannot alter scope/dependencies/gates, inspect another worktree,
self-allocate, self-review, self-accept, commit, push, submit, merge, or access optional artifact
credentials.

Use [subagent-driver.md](references/subagent-driver.md) for an isolated fresh worker when requested
or supported; use [inline-driver.md](references/inline-driver.md) only when explicitly selected or
subagent execution is unavailable and the controller can preserve the same role/surface boundary.
Never claim a subagent ran when it did not.

## Implementation loop

1. **Red/baseline.** Run the smallest contract-relevant reproduction or baseline and observe it.
2. **Green.** Implement the smallest complete production change within the allowed surface.
3. **Refactor.** Simplify without behavior change.
4. **Verify.** Run focused checks, changed-path smoke scenario, and nearest relevant existing checks.
5. **Review.** The independent decision-maker performs task-wide specification and quality review
   of the same complete uncommitted diff. Only explicit `/woostack-review` may delegate advisory
   reviewers. The implementing coder never reviews or accepts its own work.
6. **Iterate.** Redispatch confirmed in-contract gaps to the same coding profile with a fresh packet
   and diff identity; re-run affected checks and reviews.

A contract-changing question returns to the owning workflow. A collision, unsafe instruction,
failed invariant, or unknown mutation returns `BLOCKED`. A timeout is an unknown outcome: inspect the
worktree/process before redispatching and never start a second writer on the same surface.

## Commit and PR boundary

After verification and reviews pass on one unchanged diff, the controller invokes
[`woostack-commit`](../woostack-commit/SKILL.md) with the same bounded task contract. Immediately
before the boundary, re-read the task/run contract, deterministic path,
`git worktree list --porcelain`, branch, Graphite parent, complete dirty/index/diff state, and
ancestry.

The monotonic path is:

```text
finalized commit → Git/Graphite read-back → Graphite submit → canonical PR/head/base read-back
```

On unknown outcome, rediscover before retrying. Never duplicate a commit, branch, submission, or PR.
After verified delivery, tear down only the exact clean task worktree. Preserve it on failure,
collision, blocker, handoff, or unknown outcome.

## Fix/build abandonment

If the user or owning controller explicitly abandons a fix/build at any point after execution
handoff, stop admitting or dispatching work, cancel every active implementation, review, commit, or
submission driver before its next mutation, and preserve its current branch/worktree/PR evidence
without cleanup. Re-read Git, Graphite, and GitHub after cancellation and verify every driver is
quiescent before project closure or handback.

When an exact plan project exists, follow the
[Linear artifact contract](../woostack-init/references/artifact-backends.md) to set only that
project's native status to the configured `projectStatuses.canceled` value and independently read
the closure back. If no exact persisted project exists, report that there is nothing to close and
make no provider write. Do not create a project merely to cancel it or bulk-change issue states.

Handoff, replanning, blockers, pauses, and failed tasks are not abandonment and leave the project
open. An unavailable, failed, or unknown closure returns a truthful artifact blocker with the stable
project identity and safe retry boundary; it never resumes repository work or claims closure.

## Optional artifact synchronization

Only when explicitly selected, append the persisted task's observed branch, commit, PR, changed
paths, verification, review, and blockers. Independently read each write back. Except for the
workflow-owned fix/build project closure above, do not change artifact scope, assignment, ownership,
status, acceptance, dependencies, relations, or project membership. Artifact failure is separate
from repository execution.

## Handback

Return:

- approved input identity/revision and selected stable task ID;
- dependency and Git-parent readiness;
- worktree, branch, base/parent, and changed paths;
- verification commands and observed outcomes;
- reviewer identities/verdicts and complete diff identity;
- commit SHA and canonical PR URL/head/base;
- optional artifact synchronization result;
- teardown or retained recovery state; and
- first blocker/unknown boundary plus safe next action.

For a plan, re-read the approved DAG before another controller cycle. Never call submitted/reviewed
work merged or accepted without direct owning evidence.
