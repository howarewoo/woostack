# Isolated implementation workspaces

This reference defines outcome-level safeguards for isolated implementation workspaces. It does not
select task scope, dependencies, approval, acceptance, publication, or merge authority. Those
boundaries belong to the active workflow; Git and canonical provider reads own repository state.
Select native Git plus an authorized GitHub capability (prefer native GitHub tools when suitable;
host-authenticated `gh` is supported), or Graphite only when explicitly selected or verified as
already managing this task/stack, under the
[source-control contract](../../woostack-commit/references/graphite.md).
Direct Git/GitHub publication owns artifact scope; no provider-specific artifact context is selected here.

## Required isolation and identity

Every active implementation task has one approved task identity, one selected branch, and one
selected workspace. The repository, host, or workflow caller may provide an existing linked worktree
or host-managed linked checkout at any supported location. No universal path, directory prefix,
branch-name recipe, creation command, adoption flag, or teardown timing is part of this contract.
Runtime allocation is evidence, not publication identity.

The selected workspace MUST:

- be a real linked Git worktree backed by the admitted repository's common Git directory and present
  in its complete `git worktree list --porcelain` inventory;
- be physically distinct from the primary checkout and from every other active task workspace;
- have the selected branch checked out and expose a directly read HEAD;
- preserve the approved parent branch/SHA and prove required prerequisite ancestry; and
- be owned by one active writer for the task surface.

Resolve physical paths before comparing them. Treat symlink aliases, equal paths, and ancestor/
descendant paths as collisions. Compare the complete `git worktree list --porcelain` inventory and
relevant local/remote branch evidence before dispatch, reuse, handoff, recovery, or delivery. A
suitable existing isolated checkout MAY be reused. A missing or conflicting allocation blocks without
silently choosing the primary checkout, relocating the task, or inventing a replacement branch.

## Repository and ancestry evidence

A caller supplies one complete task-bound ancestry contract with stable approved parent-branch
intent, retained parent/start SHA, Git DAG evidence, and canonical PR base when a PR exists. An
upstream ref or merge-base alone is insufficient. Apply the shared
[repository ancestry contract](artifact-backends.md#repository-ancestry-and-base-change-detection)
to its last independently admitted parent tip. Mutable observed refs, heads, commits, and tips are
repository evidence outside content approval identity.

For roots, the selected parent is the admitted integration branch/SHA. For dependents, the caller
supplies one concrete parent branch/SHA containing every required prerequisite. Prove each required
ancestor with `git merge-base --is-ancestor`, even when hashes are equal. An unresolved join pauses
that task; do not infer order, rewrite heads, rebase, reset, silently switch parents, or require a
merge automatically.

## Discovery, operation, and recovery

Before dispatch or any retained operation, take one coherent direct-evidence snapshot of the
approved task contract, selected workspace/branch, complete Git worktree inventory, canonical
repository identity, filesystem state, dirty/index/conflict/diff state, branch/HEAD facts, parent
ancestry, and applicable canonical PR/review/thread evidence. A material change invalidates the
snapshot; rediscover rather than combining observations from different states.

Orchestrate additionally claims the canonical repository plus each canonical executable issue/task
identity before reservation. Any overlapping task context therefore cannot claim one physical
workspace concurrently; a claim without the current controller owner token is a blocker.

An unknown or partial create, checkout, commit, push, publication, handoff, or recovery boundary
preserves all observed state and blocks. Never delete, overwrite, reset, clean, stash, reassign,
transfer, or recreate around a collision. A timeout or lost worker response leaves ownership unknown;
prove the previous writer stopped or relinquished ownership before any overlapping mutation.
Recovery reuses the exact retained selected workspace, branch, parent, and evidence, or pauses for an
explicit fresh allocation. It never falls back to a prescribed path or branch projection.

All source edits and task-scoped checks run only in the selected workspace. Workers never access
another task workspace, change allocation or scope, mutate artifacts, or exercise merge authority.
Workflow-owned delivery may retain the workspace after publication; publication does not create a
workspace obligation or authorize teardown. Human-owned, host-managed, and external linked workspaces
are left intact unless their owner explicitly supplies a safe lifecycle operation.

## Greenfield boundary

A genuinely greenfield target has no Git repository yet and therefore cannot use this reference
before scaffolding. [`woostack-bootstrap`](../../woostack-bootstrap/SKILL.md) owns collision-safe
creation. Once Git exists, later bounded tasks use these isolation and evidence outcomes normally.
