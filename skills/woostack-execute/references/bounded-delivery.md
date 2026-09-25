# Bounded one-PR delivery

Shared implementation and delivery safeguards owned by [Execute](../SKILL.md). Execute admits one
complete bounded enhancement, refactor, test task, or authorized correction with causal evidence.
This reference cannot widen the accepted task or replace its admission gates.

Create no project manifest, specification, or multi-task execution plan. Selected issue input follows
[Execute's exact GitHub issue admission](../SKILL.md#optional-exact-github-issue). Orchestrate may
provide this worker a persisted pre-execution layout and effective prerequisite readiness; Execute
consumes that bounded packet for one task and does not schedule siblings or own the plan. Repository
delivery goes through Commit; Git and canonical GitHub reads supply source-control evidence, not
permission to implement or authority to merge.

Before mutation, apply the shared [source-control contract](../../woostack-commit/references/source-control.md).
Use native Git and an authorized GitHub capability for repository delivery (prefer native GitHub
tools when suitable; host-authenticated `gh` is supported). Discover actual operation capabilities,
read shapes, pagination, and independent readback before any consequential operation.

## Keep one bounded contract

Keep the following resolved contract explicit in the active conversation or completely verified
handoff packet; derive it from a selected exact issue and repository evidence when applicable:

- stable task identity, goal, exact repository/target, bounded paths, non-goals, and acceptance;
- intended change, relevant technical consequences, risks, finite checks, and changed-path smoke;
- integration base commit, approved parent-branch intent, and retained start/old-parent SHA;
- for a correction, evidence-bound diagnosis and the user's authorization for the complete scope; and
- for a selected issue, the independently verified canonical URL, native identity, and accepted
  issue-derived scope.

Do not create hidden workflow state. Repository defaults cannot widen the accepted scope. If
scope expands, retain the workspace and return to the calling skill's planning/admission boundary;
never silently change the contract or split it into additional PRs.

## Create or resume one isolated workspace

Apply the [isolated-workspace guidance](../../woostack-init/references/worktrees.md) for identity,
workspace evidence, base admission, collision discovery, and task-only writes. Independently read the
physical repository root, canonical remote, configured integration base and exact commit, complete
worktree/branch/status/diff inventory, Git ancestry, and canonical GitHub PR state. Require either no
task state or one exact recoverable state. Never reset, clean, stash, overwrite, or create around
unexpected user work.

The repository, host, or caller selects one isolated task workspace and branch. It may reuse a suitable
linked checkout, including an external or host-managed worktree, or create a new linked checkout using
its supported capabilities. Do not require a fixed path, branch recipe, creation command, or
managed-worktree flag.
Resume an exact existing task/workspace/branch/parent/head instead of creating a duplicate. Revalidate
the approved contract and direct repository evidence before each mutation boundary and after
interruptions.

## Implement and verify

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
blocks delivery. A same-PR repair dispatched by Orchestrate from PR-check observation is an
authorized correction of the supplied failing revision: diagnose it (using the surviving Debug
workflow when root-cause proof is missing), apply the smallest in-scope change, and update that PR
through Commit. Execute adds no monitoring loop and schedules no sibling.

Execute does not require an independent pre-commit review receipt. If the caller requests an
independent reviewer, bind its observations to the exact task, repository, parent, and complete
diff identity. The implementer cannot claim independent review of their own work. Correct in-scope
findings and rerun affected checks; material scope changes return to Execute admission.

## Deliver and read back one PR

Only after required verification passes on the complete task diff, use
[Commit](../../woostack-commit/SKILL.md) to submit at most one PR under the source-control contract.
Add a Git commit (never automatically amend), explicitly push only the task branch without force,
and use the selected authorized GitHub submission capability to create a draft only after excluding
an existing matching PR; host-authenticated `gh pr create --draft` and `gh pr edit` are supported
equivalents for draft creation and body updates. Preserve the exact repository/head/base identity and
intended base.
Never merge, mark ready, enable auto-merge, enqueue, or force-push.

For a selected exact issue, re-read it before submission and on resume to verify its
identity, repository, open state, and continued agreement with the accepted contract. Changed scope
returns to the calling skill's admission boundary. An unavailable or invalid issue blocks associated
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

After delivery, retain the selected workspace unless its owner explicitly supplies a safe lifecycle
operation. Never remove a user-owned, host-managed, or external checkout as workflow cleanup.
Publication does not create a workspace obligation. If implementation, verification, review, commit,
submission, read-back, or lifecycle handling fails, is blocked, or has an unknown outcome, retain the
workspace and return exact Git and GitHub resume evidence: repository/base, task/workspace,
branch/parent, head/commit, status/diff, verification/review results, and PR
URL/state when known. On resume, reread those facts and continue at the first unproved boundary
without duplicating a branch, commit, PR, or cleanup.

## Return

Return the stable task identity, accepted scope and correction authorization when applicable, worktree/branch,
base/parent, changed paths, verification/smoke and any independent-review results, commit SHA, canonical
PR URL/head/base/state, and cleanup result. For an exact issue association, include the canonical
issue URL and verified closing-reference outcome. For a reroute or retained failure, name the
destination or blocker and exact safe resume boundary. Never claim evidence not directly observed.
