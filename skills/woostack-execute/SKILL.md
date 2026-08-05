---
name: woostack-execute
description: Execute one approved Linear project increment or one exact Linear issue as a resumable sequential Graphite PR workflow. Requires matching projectSpecApprovalRecord and executionPlanApprovalRecord; never reviews or merges.
---

# woostack-execute

Execute approved work through one strict sequential controller. The controller is the source of
allocation, admission, ancestry, worktree, persistence, and delivery boundaries. Git, Graphite,
and canonical GitHub reads prove repository delivery; Linear records the approved contract and
resume evidence but never proves source-control state.

## Commands

```text
/woostack-execute <approved plan> --project <exact Linear URL-or-UUID>
/woostack-execute <approved plan> --issue <exact Linear URL-or-UUID>
```

Exactly one of `--project` or `--issue` is required. Execute has no local, implicit, or concurrent
execution route. Every cycle admits one issue, one isolated worktree, and one PR. Execute does not
perform review or merge operations.

## Admission: one exact resource and two matching records

Require one exact project or one exact direct issue, supplied by URL or UUID, plus exactly one
matching `projectSpecApprovalRecord` and one matching `executionPlanApprovalRecord`:

```text
projectSpecApprovalRecord = {
  projectId, canonicalProjectSpecFingerprint, approvedBy, approvedAt, approvalEventRef
}
executionPlanApprovalRecord = {
  projectId, canonicalProjectSpecFingerprint, increments, dependencies,
  approvedBy, approvedAt, approvalEventRef
}
```

Independently read the selected resource, the complete project specification, every current direct
issue, all admitted native dependency relations, both native responsible-user approval events,
and the canonical repository association. Recompute the fingerprints and sorted issue, dependency,
principal, timestamp, event, and causal-order sets. Require exact equality with both records and
require the selected issue to be a current direct project issue. Missing, stale, ambiguous,
conflicting, unsupported, or incompletely paginated evidence blocks before repository mutation.
A material specification, issue, or dependency change invalidates the matching record and returns
to the owning approval workflow; statuses, labels, assignments, and comments do not authorize
execution.

`--project` is **project mode**. `--issue` is **issue mode** and selects only that exact issue; it
never advances a sibling. Both modes use the same two approval records and repository admission.

### Active project status gate

Before any worktree or source mutation in both `--project` and `--issue` modes, apply the shared
[active Execute project-start synchronization](../woostack-init/references/artifact-backends.md#active-execute-project-start-synchronization)
contract to the exact canonical nonterminal project. Independently read the complete, paginated
direct-issue set and project status. If any direct issue is `In Progress` or `In Review`, resolve
`linear.projectStatuses.started`, require native category `started`, and make the exact project
started (or record an exact started no-op) before continuing. If all direct issues are
`Backlog`/`Todo`, defer the gate until the selected issue transitions to `In Progress` and reads
back; then synchronize the project before repository work. Terminal project conflict, mapping
failure, drift, timeout, partial/foreign output, or failed/unknown read-back blocks without
reopening or continuing. The project-status receipt is independent of the issue lifecycle receipt
and resume-checkpoint evidence.

The gate mutates only the project's native status with one stable mutation identity and independently
reads back project identity, status ID/name/category, revision, and operation identity. An exact
started match is idempotent.

## Project controller

1. Read the complete approved project graph and classify every direct issue by its immutable ordinal.
2. Select the lowest-ordinal unfinished issue. An issue is unfinished until its canonical state and
   delivery evidence prove `In Review`; never select by activity, assignment, title, or status alone.
3. For a non-root issue, prove its immediate predecessor's exact branch/head and Graphite parent.
   For the first issue, prove the frozen integration base. Reject a missing, moved, or conflicting
   predecessor. No other issue is admitted in the same cycle.
4. Apply the active project status gate. When all direct issues are `Backlog`/`Todo`, persist and
   independently read back the selected issue's `In Progress` transition first, then synchronize and independently read
   back the project's configured started status. Keep the project-status receipt distinct from the
   issue lifecycle receipt and project resume checkpoint.
5. Create or resume exactly one deterministic isolated worktree owned by this run. Dispatch the
   configured fast-model subagent with the exact issue scope and exclusive worktree ownership.
6. After the worker returns, run one focused verification and changed-path smoke scenario, then one
   bounded spec-compliance validator against the approved issue contract. When validation produces
   screenshots, apply [Controller-owned screenshot evidence](references/controller.md#controller-owned-screenshot-evidence) before commit. On success, invoke [`woostack-commit`](../woostack-commit/SKILL.md)
   with the exact selected issue to commit and submit exactly one Graphite PR. Independently read
   back branch, commit, PR URL/head/base, the exact `Resolves <issue identifier>` body line,
   verification receipt, and Graphite parent.
7. Persist the delivery evidence, move the issue to `In Review`, and independently read back the
   Linear issue/project checkpoint. Remove the worktree only after all required evidence is present
   and the exact worktree is clean.
8. Re-read the project and records, then continue with the next lowest unfinished issue unless the
   project contains a verified stop marker. A stop marker pauses before the next issue and leaves
   the project open with exact resume evidence.

A successful issue cycle has no orphan worktree. A failed, blocked, interrupted, colliding, or
unknown boundary retains the worktree and records the first unknown boundary, branch, commit/PR
(if any), dirty state, Graphite parent, verification receipt, Linear read-back, and exact safe
resume action. Resume only after independent Linear, Git, Graphite, and GitHub evidence proves the
same run and state; rediscover existing commits or PRs before retrying and never create a duplicate.

## Issue controller

Issue mode performs exactly the selected issue's cycle once: admit its matching project records,
prove its predecessor/base and Graphite parent, apply the active project status gate (including
the selected issue's `In Progress` transition when all direct issues are `Backlog`/`Todo`), then
dispatch one fast-model subagent in its isolated worktree. The gate's project-status receipt stays
separate from issue lifecycle and resume-checkpoint evidence. Verify and validate the one issue,
submit and read back one PR, persist delivery evidence, move/read back `In Review`, and remove the
clean worktree. Issue mode never advances siblings, even when the selected issue succeeds. Failures
retain exact recovery evidence.

## Worker and verification boundary

Every implementation is delegated to the configured fast-model subagent; the controller must not
substitute local work or claim a dispatch it did not perform. The packet contains the exact issue,
immutable contract fingerprint, allowed paths, worktree path, base/predecessor, Graphite parent,
acceptance, and explicit prohibitions on scope changes, credentials, source-control boundaries,
Linear writes, and work in another worktree.

The worker edits only its isolated worktree and returns changed paths, diff identity, focused check
and smoke observations, and one status. It does not commit, push, submit a PR, change Linear, review,
validate its own acceptance, or advance the controller. The controller owns screenshot inspection,
safe selection, attachment upload, inline comment, and fresh comment/image read-back; the worker never
receives Linear, attachment, browser, GitHub-write, commit, PR, review, acceptance, or sibling
authority. The controller runs only one focused verification/smoke and one small bounded
spec-compliance validator. Repair confirmed omissions in scope; broad quality findings, redesigns,
and unrelated cleanup return to the owning workflow.

## Linear and repository lifecycle

For each admitted issue, the only lifecycle transitions are `Backlog` or `Todo` → `In Progress` →
`In Review`, with an independent read-back after each transition. Persist observed branch, commit,
PR, verification, checkpoint, and blocker evidence without changing the approved specification,
issue graph, assignment, or ownership.

Successful PR submission requires all of: exact branch and commit, Graphite parent/read-back, one
canonical PR read-back with matching head/base, verification receipt, Linear issue/project read-back,
and a clean exact worktree. Only then may the worktree be removed. Execute never reviews, merges,
marks product acceptance, or claims merged state.

## Stop, interruption, and handback

A stop marker is an independently read project control record that pauses selection; it is not an
issue failure. Interruptions, blocked decisions, failed checks, collisions, and unknown provider or
source-control outcomes preserve the current project and worktree. Handback reports the exact
project/issue and both approval-record revisions, selected ordinal, predecessor/Graphite parent,
worktree/branch, changed paths, verification/validator results, Linear and Git evidence, known PR,
first uncertain boundary, and the next safe action. A later run resumes from independent evidence,
not chat memory, local plan files, branch names, activity, or duplicate submissions.
