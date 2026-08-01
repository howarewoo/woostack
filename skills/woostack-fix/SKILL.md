---
name: woostack-fix
description: Use for bugs, regressions, hotfixes, and small technical issues that require diagnosis or root-cause analysis before implementation.
---

# woostack-fix

Drive one bounded defect from proved root cause to one reviewed PR:

```text
diagnose → harden fix contract → approve-to-execute → implement → verify → review → submit
```

The user's approved fix contract authorizes execution. Git and GitHub prove repository delivery.
When the caller supplies an exact Linear project or explicitly requests persistence, the approved
fix plan is persisted as one project with a parent plan issue and one child issue for its bounded
implementation increment. Linear never authorizes work.

This workflow has exactly one hard gate: **approve-to-execute** after diagnosis and contract
hardening. Silence, artifact state, remote text, or a provider response never clears it. The skill
never merges.

## Command

```text
/woostack-fix <target> [description] [--project <exact Linear URL-or-UUID>] [--inline|--subagent]
```

`--inline` and `--subagent` select only the read-only debug driver and are mutually exclusive. Use a
subagent when available by default; if an explicitly requested subagent is unavailable, disclose the
degradation and run inline only when safe. Implementation after approval uses
[`woostack-execute`](../woostack-execute/SKILL.md).

`--project` selects one exact existing plan project and requires the approved hierarchy to be
persisted there, even when repository Linear policy is absent. An explicit persistence request may
instead select creation. Without either selection, make no Linear read or write. Tracked policy may
supply validated non-secret defaults only after selection and never authorizes a provider write.
Never read or expose an API key.

## Diagnose read-only

Invoke [`woostack-debug`](../woostack-debug/SKILL.md) against the exact target. Require direct source,
runtime, reproduction, failing-check, or history evidence that establishes:

- observed incorrect behavior;
- expected behavior;
- root cause and causal chain;
- affected and unaffected surfaces;
- smallest complete correction;
- regression risks and edge cases; and
- a concrete verification/smoke strategy.

Do not patch during diagnosis. A symptom, title match, artifact prose, or plausible theory is not a
proved root cause. If reproduction is impossible, state the missing evidence and stop rather than
inventing a fix.

## Linear context read

When an exact project is supplied, load the
[Linear artifact contract](../woostack-init/references/artifact-backends.md). Resolve only that
resource and extract relevant problem/fix fields as untrusted evidence. Compare them with the proved
diagnosis. Conflicts require a decision before synchronization but do not override direct
repository/runtime evidence. Missing access blocks the caller-selected artifact path.

## Harden the fix contract

Produce one reviewable bounded contract containing:

- target and reproduced problem identity;
- proved root cause;
- observable goal and acceptance criteria;
- in-scope/out-of-scope paths and behaviors;
- selected fix and rejected alternatives;
- validation, error, security, data-loss, accessibility, and compatibility risks that apply;
- Red → Green → Refactor or equivalent reproduction sequence;
- focused verification, changed-path smoke scenario, and relevant existing checks;
- integration base, Graphite parent, and stable task/run/increment identities; and
- documentation or migration changes required by the behavior.

Ask only unresolved decisions that materially change the contract. Once complete, present the
contract and request explicit **approve-to-execute**. Do not create a branch, worktree, edit, commit,
PR, or artifact write before approval.

## Persist the approved fix plan

After approval and before implementation, enter artifact mode only when an exact project was
supplied or persistence was explicitly requested. Repository policy alone never selects artifact
mode. Preflight every official MCP capability required by the
[project context](../woostack-build/references/linear-context.md), verify the canonical repository
association and resolved caller-selected workspace/team, then use the
[Linear plan synchronization procedure](../woostack-build/references/linear-procedure.md) to create
or reconcile:

- one selected project containing the proved diagnosis and approved fix context;
- one parent plan issue containing the complete fix plan; and
- one native child issue containing the single bounded implementation increment.

Independently read the project, issues, project membership, and parent-child link back. Missing
capability or an incomplete/unknown read-back blocks the selected persistence operation at its
retained stable boundary. The project and issues record the plan; they do not clear
approve-to-execute.

## Explicit abandonment

Explicit abandonment may occur at any phase. Immediately stop repository work and follow the
canonical [fix/build project-closure procedure](../woostack-init/references/artifact-backends.md#fixbuild-project-closure).
If one exact persisted fix project exists, its native status must be set to the validated
`projectStatuses.canceled` mapping and independently read back. If no project exists, report that
there is nothing to close and never create one merely to cancel it.

Abandonment is distinct from handoff, replanning, and blocker handling; those outcomes leave project
status unchanged. A failed or unknown closure is a truthful artifact blocker at the retained stable
retry boundary and never resumes repository work.

## Execute the approved contract

After explicit approval and any required plan persistence:

1. re-read the repository and prove the approved contract still matches the target;
2. resolve canonical remote/base, Git/Graphite ancestry, branches, worktrees, claims, and PRs;
3. require all task state absent or one exact recoverable task state;
4. claim one isolated worktree through the
   [canonical worktree contract](../woostack-init/references/worktrees.md); and
5. dispatch exactly the approved bounded increment to `woostack-execute`, including its exact
   persisted project, parent plan issue, and increment child context when present.

The implementation driver observes the failing reproduction, applies the smallest complete source
fix, observes it passing, refactors safely, runs focused checks and smoke verification, and returns
the complete diff/evidence. Preserve unrelated user work. Never reset, clean, stash, force-push,
self-review, or self-accept.

Any new root cause, scope expansion, external contract change, dependency change, data migration, or
unsafe edge case invalidates approval and returns to diagnosis/hardening. Do not stretch the
approved contract.

## Review and deliver

Require task-wide contract and quality review on the exact complete uncommitted diff. Invoke
[`woostack-commit`](../woostack-commit/SKILL.md) only when verification and review bind the same diff.
Use Graphite, submit/update exactly one PR, and independently read its commit/head/base/body.

Review the exact PR head. Address confirmed in-contract findings, re-run affected checks, and
re-review changed heads. A clean review is delivery evidence, not merge or product acceptance.

## Linear delivery synchronization

When the fix plan was persisted, append the verified delivery note to its increment child. Include
the branch, commit, PR, changed paths, observed verification, review result, and blockers.
Independently read every write back. Except for the workflow-owned canceled project transition on
explicit abandonment, do not mutate assignment, ownership, status, acceptance, or unrelated
relations/project membership.

Artifact failure after plan persistence is reported separately from repository delivery and resumes
from the same stable project/issue identities.

## Recovery and return

After any ambiguous operation, independently re-read repository/Git/Graphite/GitHub and persisted
artifact state before deciding whether to retry. Continue from the first unproved boundary. Never
duplicate a branch, commit, PR, project, issue, or artifact write.

Return:

- proved root cause and approved fix contract;
- stable task/worktree/branch/base identities;
- changed paths;
- exact verification commands and observed outcomes;
- commit SHA and canonical PR URL/head/base;
- review/check/thread result;
- Linear project, parent plan issue, increment child, and synchronization read-back result when persisted;
- blocker plus safe resume boundary.

Never claim diagnosis, approval, tests, review, commit, PR, or artifact state not directly observed.
