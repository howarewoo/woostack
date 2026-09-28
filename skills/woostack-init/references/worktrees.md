# Isolated implementation workspaces

This reference defines outcome-level safeguards for isolated implementation workspaces. It does not
select task scope, dependencies, approval, acceptance, publication, or merge authority. Those
boundaries belong to the active workflow; Git and canonical provider reads own repository state.
Select native Git plus an authorized GitHub capability (prefer native GitHub tools when suitable;
host-authenticated `gh` is supported) under the
[source-control contract](../../woostack-commit/references/source-control.md).
Direct Git/GitHub publication owns artifact scope; no provider-specific artifact context is selected here.

## Workspace and ownership

Use an existing approved workspace and branch when suitable; otherwise select an isolated checkout
through the host or repository. A fresh linked worktree is not required for every invocation. Verify
the physical repository, branch, HEAD, index, dirty state, and task diff before writing. Inspect
relevant worktrees and path aliases for collisions; preserve unrelated work. Never create around a
conflicting checkout or silently take over a workspace.

Every implementation writer needs an independently owned workspace and branch with non-overlapping
responsibility — delegation requires its own workspace, not merely concurrency — and an approved
existing workspace is reused when it is verified suitable. Before reuse, inspect native worker
state and current Git/PR facts. If an earlier writer may still be active, stop the affected work
until its exit or relinquishment is proved. Waiting or serializing a new writer does not establish
that proof. Instructions provide neither locking nor sandboxing.

A session that dispatches writers does not treat the primary checkout's existing edits as spare
capacity: uncommitted work there is recovery evidence, never permission to reset, stash, or keep
writing on the protected trunk.

## Base and recovery

Select the intended base from repository policy and task dependencies; verify the required changes
are actually available before working. Git ancestry proves commit-preserving containment, not
intent: an upstream or merge-base alone does not choose the parent. For a squash or rebase landing,
verify the native landing and integrated content instead of demanding ancestry from the former PR
head. Follow [base-change detection](artifact-backends.md#repository-ancestry-and-base-change-detection)
when a previously inspected base changes. An unresolved dependency or conflicting parent blocks
that task; do not silently choose an integration strategy.

For an unknown checkout, handoff, or worker result, inspect the relevant workspace, writer state,
Git branch/diff, and matching PR before repeating any operation. Retain recoverable state and
unrelated changes; never reset, clean, stash, rebase, overwrite, or assume a timeout means no work
occurred. Run task-scoped edits and checks in the selected workspace. Publication alone does not
authorize its teardown; leave user-owned and host-managed workspaces intact absent an authorized
safe lifecycle operation. [Source control](../../woostack-commit/references/source-control.md)
owns commit, push, PR, and selected native-stack recovery.

## Greenfield boundary

A genuinely greenfield target has no Git repository yet and therefore cannot use this reference
before scaffolding. [`woostack-bootstrap`](../../woostack-bootstrap/SKILL.md) owns collision-safe
creation. Once Git exists, later bounded tasks use these isolation and evidence outcomes normally.
