---
name: woostack-execute
description: Execute an approved bounded task or dependency-aware plan as isolated Graphite PRs with verification and review. Fix/build origins require their exact approved Linear records; standalone execution remains artifact-optional. Never merges.
---

# woostack-execute

Execute one approved bounded task or dependency-aware plan. Fix-origin and build-origin execution
carry exact content-bound Linear approval records; standalone execution remains artifact-optional.
Git, Graphite, and canonical GitHub evidence proves repository delivery. Linear never assigns
workers or proves source-control state.

The controller advances one dependency-ready task per cycle. Each task has one stable identity, one
approved contract, one isolated worktree/branch, one implementation owner within the run, and at
most one implementation PR. Execute never merges.

## Commands

```text
/woostack-execute <approved task-or-plan> [--inline|--subagent]
/woostack-execute <approved task-or-plan> [--project <exact Linear URL-or-UUID>] [--issue <exact Linear URL-or-UUID>] [--inline|--subagent]
```

The approved task/plan is required. Driver flags are mutually exclusive. Standalone execution
without artifact flags makes no Linear call. Fix-origin input must carry one complete
`fixApprovalRecord` and exact matching `--issue`. Build-origin input must carry one complete
`buildProjectSpecApprovalRecord`, one complete `buildExecutionPlanApprovalRecord`, and exact
matching `--project`. Missing required identity, canonical content, complete relation pagination,
responsible-user approval evidence, or independent read-back is an admission failure, never an
artifact-free route. Use selected resources only under the
[artifact contract](../woostack-init/references/artifact-backends.md).

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

## Artifact admission

An exact artifact for standalone execution may supply persisted context but never clears an
execution gate. Independently read only selected resources, fully paginate relevant fields, verify
the canonical repository association, and compare content to the active approved input. Conflict
blocks artifact use rather than silently changing the contract.

Fix/build origin is different: its exact Linear identity and approval record are required
repository admission inputs.

For fix-origin execution, the approved input must carry exactly one:

```text
fixApprovalRecord = {
  issueId,
  canonicalContentFingerprint,
  approvedBy,
  approvedAt,
  approvalEventRef
}
```

Invocation MUST carry `--issue` whose exact URL/UUID resolves to `issueId`. Artifact-free,
degraded, project-backed, and omitted-artifact routes MUST NOT accept fix-origin input.
Independently read the exact issue, completely paginate relevant issue relations and approval
events, and recompute the fingerprint using the shared
[fix identity algorithm](../woostack-init/references/artifact-backends.md#fix-issue-identity-and-approval-record).
Require exact issue ID, fingerprint, responsible-user native principal ID, approval timestamp,
stable approval-event reference, and causal order to match the record. Provider status, labels,
assignment, issue content alone, workflow inference, an agent-authored event, or read-back alone
does not approve execution.

Perform this check before implementation, after every worker handback, before every redispatch,
and immediately before commit. A material title, description/plan, or admitted native dependency
change invalidates approval; unrelated comments and metadata do not. Any missing, drifted,
ambiguous, conflicting, unsupported, incompletely paginated, or unavailable issue/relation/approval
evidence blocks with no local, conversational, historical-project, or alternate-provider fallback.

For build-origin execution, the approved input must carry exactly one
`buildProjectSpecApprovalRecord` and one `buildExecutionPlanApprovalRecord` in the shared
[build record shapes](../woostack-init/references/artifact-backends.md#build-project-graph-and-approval-records).
Invocation MUST carry `--project` resolving to both records' `projectId`.

Independently read the complete project specification, every current direct increment issue, every
admitted native dependency relation, and both responsible-user approval events. Recompute the
canonical project fingerprint, sorted `{ issueId, canonicalIncrementFingerprint }` set, and sorted
dependency tuple set. Require exact project/issue identities, fingerprints, edges, approval
principal IDs, timestamps, event references, causal order, project membership, and parent absence
to match. The selected task must be one exact approved direct issue. Historical parent/container
issues are excluded and never supply current input.

Perform this complete check before implementation, after every worker handback, before every
redispatch, immediately before commit, and before selecting another increment. Project-spec drift
invalidates both records and returns to build specification hardening. Issue/edge drift invalidates
the execution-plan record and returns to graph hardening. Missing, ambiguous, conflicting,
unsupported, incompletely paginated, or unavailable evidence blocks with no local, conversational,
cached, or alternate-provider fallback.

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

For fix/build-origin work, every worker result is a required artifact handback boundary. Before
accepting it, asking a reviewer to assess it, or dispatching another implementation packet, repeat
the origin's complete issue/project, content-fingerprint, relation, and responsible-user approval
check. Drift returns control to `woostack-fix` or `woostack-build`; worker output never silently
updates the canonical contract.

## Commit and PR boundary

After verification and reviews pass on one unchanged diff, perform the final required fix/build
content, relation, and approval-record check. Only then may the controller invoke
[`woostack-commit`](../woostack-commit/SKILL.md) with the same bounded task
contract. Immediately before that boundary, also re-read the task/run contract, deterministic path,
`git worktree list --porcelain`, branch, Graphite parent, complete dirty/index/diff state, and
ancestry.

The monotonic path is:

```text
finalized commit → Git/Graphite read-back → Graphite submit → canonical PR/head/base read-back
```

On unknown outcome, rediscover before retrying. Never duplicate a commit, branch, submission, or PR.
After verified delivery, tear down only the exact clean task worktree. Preserve it on failure,
collision, blocker, handoff, or unknown outcome.

## Abandonment

When the user explicitly abandons a fix/build after handoff, stop admitting or dispatching work,
cancel every active implementation, review, commit, or submission driver before its next mutation,
preserve current branch/worktree/PR evidence, re-read Git/Graphite/GitHub, and verify every driver is
quiescent before closure or handback.

For a project-backed build/plan task, when an exact plan project exists, follow the canonical
[project-backed workflow closure](../woostack-init/references/artifact-backends.md#project-backed-workflow-closure):
set only its native status to configured `projectStatuses.canceled` and independently read it back.
A fix's exact issue is not a project: preserve it and append only a verified minimal note. If no
exact persisted project exists, report that there is nothing to close and make no provider write.
Do not create a project merely to cancel it or bulk-change issue states.

Handoff, replanning, blockers, pauses, and failed tasks are not abandonment and leave the project
open. Unknown closure/note outcomes are truthful artifact blockers with the stable issue/project
identity and safe retry boundary; they never resume repository work or claim closure.

## Artifact synchronization

For a required fix/build origin or explicitly selected standalone artifact, append only observed
branch, commit, PR, changed paths, verification, review, and blockers to the matching issue/project.
Independently read each write back. Delivery notes never change the approved canonical content or
dependency graph. Except for project-backed closure, do not change assignment, ownership, status,
acceptance, dependencies, relations, or project membership. Report a delivery-note failure
separately from directly verified repository delivery.

## Handback

Return:

- approved input identity/revision and selected stable task ID;
- dependency and Git-parent readiness;
- worktree, branch, base/parent, and changed paths;
- verification commands and observed outcomes;
- reviewer identities/verdicts and complete diff identity;
- commit SHA and canonical PR URL/head/base;
- required or selected artifact identity, approval recheck, and synchronization result;
- teardown or retained recovery state; and
- first blocker/unknown boundary plus safe next action.

For a plan, re-read the approved DAG before another controller cycle. Never call submitted/reviewed
work merged or accepted without direct owning evidence.
