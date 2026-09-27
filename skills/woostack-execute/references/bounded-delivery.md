# Bounded delivery

Delivery safeguards for one admitted [`woostack-execute`](../SKILL.md) outcome. They narrow
execution; they cannot widen the accepted scope or replace admission. Git and canonical GitHub reads
supply source-control evidence, not permission to implement or authority to merge, and repository
delivery runs through [`woostack-commit`](../../woostack-commit/SKILL.md) under the shared
[source-control contract](../../woostack-commit/references/source-control.md). Implementation,
verification, and workspace selection stay in [Execute](../SKILL.md); only the delivery-time
specifics follow.

## One outcome, no hidden state

Create no project manifest, specification, multi-task plan, or persisted workflow state. A
coordinating workflow may hand over its bounded outcome, non-goals, acceptance, and selected
workspace and base; Execute consumes that for one outcome, schedules no sibling, and owns no shared
plan. Repository defaults cannot widen the accepted scope. If the outcome grows, retain the
workspace and return to the caller's admission boundary. A reviewability split stays within
authorized scope; ask before changing an explicit PR mapping.

Resume an exact existing workspace, branch, base, and head instead of creating a duplicate, and
revalidate the admitted outcome plus direct repository evidence before each mutation boundary and
after interruptions. Require either no task state or one exact recoverable state; never reset,
clean, stash, or overwrite unexpected user work.

## Correct and review in place

A repair dispatched from PR-check observation on this PR is an authorized correction of that
failing revision: establish cause from reproduction or adequate evidence, apply the smallest
in-scope change, rerun affected checks, and update the same PR through Commit. A separate
read-only Debug invocation is optional, not a prerequisite. Execute adds no monitoring loop.

Independent review applies only when requested, required by repository workflow, or warranted by
risk. Bind its observations to the exact outcome, repository, base, and complete diff, correct
in-scope findings, and rerun affected checks; a material scope change returns to admission.

## Submit and read back

After required checks pass on the complete in-scope diff, let Commit submit the reviewable
PR(s) appropriate to the authorized mapping and read back the exact relevant repository, branch,
and matching PR facts. Re-read selected exact issues before submission and on resume; changed
scope returns to admission. Apply the
[PR association rules](../../woostack-commit/references/provider-attribution.md#pr-association):
preserve human-authored PR text and close only fully addressed work, without claiming or performing
issue closure. Report repository delivery and association separately.

Register [native stack membership](../../woostack-commit/references/source-control.md#native-github-stack-membership-for-a-dependent-pr)
only when explicitly requested or required by repository workflow, and verify its identity,
trunk, order, and affected PR heads/bases; chained bases and mutation responses alone prove
nothing. Read back the repository, branch, base, commit, changed paths, PR URL, head, and open
state for each delivered PR.

## Recover and return

On any failed, blocked, or unknown step, retain the workspace and return exact resume evidence:
repository and base, workspace and branch, head and commit, status and diff, check and review
results, PR URL and state, and required stack identity and order when known. On resume, reread
those facts and continue at the first unproved boundary without duplicating a branch, commit, PR,
stack, or cleanup. Retain the selected workspace unless its owner supplies a safe lifecycle
operation, and never remove a user-owned, host-managed, or external checkout as cleanup; publication
creates no workspace obligation.

Return the admitted outcome and scope, worktree/branch/base, changed paths, check and review
results, commit SHA, canonical PR URL/head/base/state, and any issue-association outcome. For a
reroute or retained failure, name the destination or blocker and the exact safe resume boundary.
Never claim evidence not directly observed.
