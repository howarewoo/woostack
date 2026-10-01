# Isolated implementation workspaces

This reference defines outcome-level safeguards for isolated implementation workspaces. It does not
select task scope, dependencies, approval, acceptance, publication, or merge authority. Those
boundaries belong to the active workflow; Git and canonical provider reads own repository state.
Select native Git plus an authorized GitHub capability (prefer native GitHub tools when suitable;
host-authenticated `gh` is supported) under the
[source-control reference](../../woostack-commit/references/source-control.md) for authorized
tool selection. Direct Git/GitHub publication owns artifact scope; no provider-specific artifact
context is selected here.

## Workspace and ownership

The deliverable owns its allocation; a worker temporarily owns exclusive write access. Normally
reuse one approved task workspace and canonical branch across implementation, repair, and integration.
A new attempt, replacement worker, or checkpoint does not itself require another checkout or branch.
Verify the physical repository, branch, HEAD/base where present, index, dirty state, and relevant
diff before writing; inspect existing files/index for an unborn repository. Check relevant worktrees
and path aliases for collisions. Understood dirty changes can be preserved and reused.

Concurrent writers need separate workspaces and non-overlapping responsibility. Sequential writers
can inherit the same allocation only after native host evidence proves the former writer exited or
relinquished access; a timeout, stale report, or waiting new writer proves no release. Unknown
liveness, unexplained changes, or a conflicting checkout blocks affected work, not permission to
allocate around uncertainty. Instructions provide neither locks nor sandboxing. Preserve unrelated
work and primary-checkout recovery edits; never treat them as spare capacity or write on protected trunk.

Before an additional allocation, record in the existing plan/handoff its delivery owner, role,
writer and owned paths/responsibility, verified base, why a released allocation is unsuitable,
integration destination, and retirement condition. Use existing issue/PR identities when available,
not invented artifacts for local work. An unattached allocation is not authorized. Concurrent
contributions can use an inspected common base; sequential repairs stay in the existing allocation.
Disjoint paths do not prove semantic or runtime independence. Account separately for shared mutable
credentials, processes, ports, databases, accounts, and service state. Use authorized separation or
serialize; do not provision sandbox services, alter shared credentials or host-global configuration,
kill unrelated processes, or access additional secrets to enable parallelism.

Checkpoints identify immutable source, normally an existing commit/SHA, not an allocation. Compatible
read-only reviewers can share unchanged source or inspect immutable Git content without new branches.
Identify the actual reviewed source; a directory, branch, or mutable HEAD alone is not provenance,
and a commit does not contain dirty edits. Preserve permitted actual-source evidence for local/dirty
review without creating a forbidden commit or stash. Mutating checks, formatters, generators, or
conflicting runtime operations must be serialized or justifiably isolated. Keeping an old revision
checked out can justify a bounded checkout, not a mandatory named branch or permanent integration tree.

## Base and recovery

Select the intended base from repository policy and task dependencies; verify the required changes
are actually available before working. Git ancestry proves commit-preserving containment, not
intent: an upstream or merge-base alone does not choose the parent. For a squash or rebase landing,
verify the native landing and integrated content instead of demanding ancestry from the former PR
head. Follow [base-change detection](artifact-backends.md#repository-ancestry-and-base-change-detection)
when a previously inspected base changes. An unresolved dependency or conflicting parent blocks
that task; do not silently choose an integration strategy.

Reconcile unknown checkout, handoff, or worker claims against actual workspace/ownership, revisions,
ancestry/diffs, and matching PR facts before retrying or integrating. Preserve recoverable state and
unrelated changes; never reset, clean, stash, rebase, or overwrite them unrequested. An unsuitable
allocation can be replaced for an established reason after preserving recoverable state, not by
discarding it to force reuse. Run task-scoped edits and checks in the selected workspace.

Account for temporary allocations as active, retained for a specific recovery/review/integration
dependency, or safely retired through an authorized host/repository lifecycle. Before retirement,
prove no writer or dependent operation needs them and that contributions, unique commits, required
checkpoints, and recovery material are accounted for. Preserve unknown edits and user-/host-owned
state. Integration, publication, or a "temporary" name grants no deletion authority; without safe
authority retain the allocation with its reason and next safe action. No broad pruning or forced removal.
[Commit](../../woostack-commit/SKILL.md) owns commit, push, PR, native-stack, and requested history
maintenance under its [source-control reference](../../woostack-commit/references/source-control.md).

## Greenfield boundary

A target without a Git repository uses
[Execute's initial scaffold admission](../../woostack-execute/SKILL.md#initial-project-scaffold),
not checkout/HEAD/base checks. Once the relevant Git objects exist, these isolation and evidence
outcomes apply normally. Reading this reference does not authorize scaffolding or invoke Execute.
