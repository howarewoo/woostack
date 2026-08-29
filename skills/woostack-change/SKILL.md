---
name: woostack-change
description: Use for a small bounded non-bug enhancement or refactor that can ship in one reviewable PR. Invoke via /woostack-change <goal>.
---

# woostack-change

Implement one small, bounded, non-bug enhancement or refactor from the user's request through
one isolated worktree and Graphite branch, ending in at most one complete reviewable PR. Change
makes no provider call and invokes no other woostack workflow; it owns implementation and delivery
directly. The accepted scope is the authority for the run; Git, Graphite, and GitHub are the
delivery evidence.

## Command

```text
/woostack-change <goal>
```

## Admit the request before mutation

Clarify only what is needed to identify the target, outcome, allowed paths, non-goals, acceptance
criteria, and a focused verification plus changed-path smoke scenario. State the interpreted
bounded scope and derive one stable task identity. Do not create a branch, worktree, or file
change while classifying or clarifying.

Reject or reroute before any mutation:

- a bug, regression, incident, production fault, or root-cause investigation goes to
  [`woostack-fix`](../woostack-fix/SKILL.md);
- work that needs multiple PRs, dependency increments, or coordinated phases goes to
  [`woostack-build`](../woostack-build/SKILL.md); and
- genuinely greenfield creation goes to [`woostack-bootstrap`](../woostack-bootstrap/SKILL.md).

Proceed only when the complete safe scope is a non-bug change that fits one PR. If the request
expands later, stop and reroute rather than silently widening it.

## Establish the bounded run

Keep the run contract explicit and current:

- stable task identity, goal, target, allowed paths, non-goals, and acceptance criteria;
- focused verification and changed-path smoke scenario;
- integration base commit and intended Graphite parent; and
- the current worktree, branch, head, and PR facts.

Keep this contract in the active run only. Do not create hidden workflow state; repository policy
may inform safe defaults, but it cannot widen the accepted scope.

## Create or resume one isolated workspace

Before changing a repository, resolve and independently read:

1. the physical repository root, canonical remote, configured integration base, and exact base
   commit;
2. `git worktree list --porcelain`, local and remote branches and commits, complete status and
   diff state, Graphite ancestry, and canonical GitHub PR state; and
3. the deterministic task path, derived branch, parent, head, and any existing PR.

Require either no task state or one exact recoverable task state. Reject protected-primary edits,
detached HEAD, duplicate worktrees or branches, unexplained dirty state, conflicting ancestry,
scope drift, and collisions. Never reset, clean, stash, overwrite, or create around unexpected
user work.

Create and assert one isolated worktree under the [canonical worktree contract](../woostack-init/references/worktrees.md#5-create-and-assert), with one Graphite-tracked branch
whose parent is the verified integration base. When exact task, worktree, branch, parent, and head
facts already exist, attach to that workspace and resume it; never create a duplicate.

## Implement and verify

In the isolated workspace, implement every change needed for the accepted bounded scope and no
other change. Inspect the complete diff and changed paths. Run the focused verification and the
changed-path smoke scenario, noting the commands and observed results. A failed or incomplete
check blocks delivery; it does not authorize a scope expansion or a second workspace.

## Deliver one PR

After verification succeeds, use Graphite to commit the complete diff and submit at most one PR.
Never merge or force-push. Independently read back the exact repository, branch, parent, commit,
changed paths, PR URL, PR head/base, and open state. The success boundary is one complete,
reviewable PR with all requested bounded changes represented by the verified commit.

Remove the isolated worktree only after successful delivery and an independently verified clean
worktree. Do not remove its branch or any user-owned checkout.

If implementation, verification, commit, submission, read-back, or cleanup fails, is blocked, or
has an unknown outcome, retain the worktree. Return exact Git, Graphite, and GitHub resume evidence:
repository and base, worktree path, branch and parent, head/commit, status and diff, verification
results, and PR URL/state when known. On resume, reread those facts and continue at the first
unproved boundary without duplicating a branch, commit, PR, or cleanup.

## Return

Return the stable task identity, accepted scope, worktree and branch, base/parent, changed paths,
verification and smoke results, commit SHA, canonical PR URL/head/base/state, and cleanup result.
For a reroute or retained failure, return the destination or blocker and the exact safe resume
boundary. Never claim evidence that was not directly observed.
