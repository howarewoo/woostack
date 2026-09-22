# Bounded one-PR delivery

Shared implementation and delivery mechanics for [`woostack-change`](../SKILL.md). Change owns
admission and user authority for one non-bug PR; planning-only Prepare and Plan never call this
reference. This contract cannot widen Change's bounded scope or replace its gates.

The calling skill owns delivery directly, without invoking another woostack workflow. Create no
project manifest, specification, or execution plan. GitHub operations are limited to the exact issue
reads explicitly admitted by [Change's GitHub issue input](../SKILL.md#admit-an-exact-github-issue);
goal-only Change makes none. Git and canonical GitHub repository/PR operations supply source-control
evidence, not development-artifact authority.

Before mutation, apply the shared [source-control selection and ancestry contract](../../woostack-commit/references/graphite.md).
Use native Git and an authorized GitHub capability for repository delivery (prefer native GitHub
tools when suitable; host-authenticated `gh` is supported). Discover actual operation capabilities,
read shapes, pagination, and independent readback before any consequential operation. Optional
Graphite selection follows the shared contract; unknown selection blocks, and `gt` failure never
authorizes backend switching.

## Keep one bounded contract

Keep the following explicit in the active conversation or completely verified handoff packet:

- stable task identity, goal, exact repository/target, allowed paths, non-goals, and acceptance;
- intended change, relevant technical consequences, risks, focused verification, and changed-path
  smoke scenario;
- integration base commit, approved parent-branch intent, and retained start/old parent SHA;
- current worktree, branch, head, complete diff identity, and PR facts; and
- for issue-backed Change, the independently verified canonical issue URL, native identity, and
  accepted issue-derived scope.

Do not create hidden workflow state. Repository defaults cannot widen the accepted scope. If
scope expands, retain the workspace and return to the calling skill's planning/admission boundary;
never silently change the contract or split it into additional PRs.

## Create or resume one isolated workspace

Apply the [canonical worktree contract](../../woostack-init/references/worktrees.md#1-identity-workspace-resolution-and-placement)
for identity, workspace resolution, base admission, collision discovery, creation/adoption, and
task-only writes. Independently read the physical repository root, canonical remote, configured
integration base and exact commit, complete worktree/branch/status/diff inventory, Git ancestry,
and canonical GitHub PR state. Require either no task state or one exact recoverable state. Never
reset, clean, stash, overwrite, or create around unexpected user work.

Create, assert, or adopt one isolated task workspace under the
[canonical creation contract](../../woostack-init/references/worktrees.md#5-create-assert-or-adopt):
adopt an existing linked/external worktree in-place (`managed_worktree = false`) or create a managed
task worktree (`managed_worktree = true`) when starting in the primary checkout, with one
task branch whose parent is the verified integration base. Track it with Graphite only in selected Graphite mode. Resume an exact existing
task/worktree/branch/parent/head instead of creating a duplicate. Revalidate the approved contract and
direct repository evidence before each mutation boundary and after interruptions.
## Implement, verify, and independently review

Implement every change needed for the accepted bounded scope and no other change. Before choosing
an implementation, load and apply the canonical
[least-code standard](../../woostack-bootstrap/references/patterns.md#7-least-code--comments):
trace the affected flow, then take the first safe rung that satisfies the complete contract.
Carry that standard into any delegated implementation packet. Simplification cannot reduce accepted
scope, compatibility, safety protections, or required verification. Follow the canonical
[application-boundary adapters rule](../../woostack-bootstrap/references/patterns.md#3-application-boundary-adapters)
for new or materially changed boundaries; do not migrate untouched legacy boundaries or add no-op
wrappers for shared identity contracts.

When considering optional implementation delegation, use the shared
[model-tier guidance](../../using-woostack/references/model-tiers.md), including its speed and
cost considerations for simple tasks. The calling skill retains delivery ownership.

Inspect the complete diff and changed paths. Run focused verification and the changed-path smoke
scenario, retaining exact commands and observed results. A failed or incomplete required check
blocks delivery.

An independent read-only reviewer, distinct from the implementer, must check the full accepted
contract against the complete diff, relevant safety/edge cases, and observed verification. Bind
review evidence to reviewer identity, task, repository, parent, and the same complete diff identity
as verification. The implementer cannot approve their own work; unavailable independent review
blocks delivery rather than becoming self-review. Correct in-scope findings, rerun affected checks,
and obtain fresh independent review for the changed diff. Material scope changes return to Change
admission before more implementation.

## Deliver and read back one PR

Only after verification and independent review pass on the same complete diff, commit and submit
at most one PR using the selected backend under the shared source-control contract. In native mode,
add a Git commit (never automatically amend), explicitly push only the task branch without force,
and use the selected authorized GitHub submission capability to create a draft only after excluding
an existing matching PR; host-authenticated `gh pr create --draft` and `gh pr edit` are supported
equivalents for draft creation and body updates. Preserve the exact repository/head/base identity and
intended base.
Never merge, mark ready, enable auto-merge, enqueue, or force-push.

For issue-backed Change, re-read the exact issue before submission and on resume to verify its
identity, repository, open state, and continued agreement with the accepted contract. Changed scope
returns to Change admission before more mutation. An unavailable or invalid issue blocks associated
delivery; retain any verified repository progress rather than dropping the association.
Apply the canonical
[PR association rules](../../woostack-commit/references/provider-attribution.md#pr-association):
preserve human-authored PR text, add exactly one `Resolves <canonical GitHub issue URL>` line, and
verify the full PR body and intended reference on read-back alongside head/base/SHA. This uses only
the selected issue's reads and GitHub PR operations, not Project writes or issue writes. Do not claim
the issue is closed or close it directly. An unknown submission or association outcome requires
discovery before retry; report repository delivery and association separately.

Independently read back the exact repository, branch, parent, commit, changed paths, PR URL,
PR head/base, and open state. The success boundary is one complete reviewable PR whose verified
commit contains every requested bounded change.

Remove only a managed task worktree created by Woostack (`managed_worktree = true`) after successful
delivery and independently verified cleanliness, following
[canonical teardown](../../woostack-init/references/worktrees.md#8-teardown). Preserve pre-isolated or
external worktrees (`managed_worktree = false`), and keep its branch, commits, and PR; never remove a
user-owned or external checkout.
If implementation, verification, review, commit, submission, read-back, or cleanup fails, is blocked,
or has an unknown outcome, retain the worktree. Return exact Git, GitHub, and selected-backend resume
evidence: repository/base, task/worktree, branch/parent, head/commit, status/diff, verification/review
results, and PR URL/state when known. On resume, reread those facts and continue at the first
unproved boundary without duplicating a branch, commit, PR, or cleanup.

## Return

Return the stable task identity, accepted scope, worktree/branch, base/parent, changed paths,
verification/smoke and independent-review results, commit SHA, canonical PR URL/head/base/state,
and cleanup result. For issue-backed Change, include the canonical issue URL and verified closing-
reference outcome. For a reroute or retained failure, name the destination or blocker and exact safe
resume boundary. Never claim evidence not directly observed.
