# Source-control branch and submission boundary

This contract applies to Commit, worktrees, delivery, planning, and reconciliation. Git and
canonical GitHub reads prove repository state; provider artifacts never authorize source mutations.

Use native Git with an available, authorized GitHub integration for PR delivery. Prefer suitable
host-native tools; host-authenticated `gh` is supported. Discover operation capabilities, complete
read shapes, and read-back support before mutation. Keep credentials in the host. Unsupported or
unknown capability blocks that operation, never licenses a different transport after failure.
`--no-pr-update` requires only local Git, not GitHub authentication or remote discovery; retain
known PR identity without claiming an unperformed read.

## Resolve the task branch and parent

The caller supplies an approved bounded task, stable identity, canonical repository, integration
base/start commit, intended parent branch, selected worktree, and verified diff identity. Before
mutation verify:

- the physical worktree path, complete `git worktree list --porcelain` inventory, branch, and HEAD;
- canonical remote, integration base, parent branch intent, retained start/old-parent SHA, and
  ancestry;
- index, unstaged, untracked, conflict, and complete diff state; every changed path belongs to
  the approved task;
- for PR delivery, complete canonical PR inventory: absence or one open current-branch PR with
  matching head repository and base; local-only commits preserve known conflicting PR facts; and
- no competing branch, checkout, commit, or PR.

Use `parentBranch` for parent identity in task contracts and delivery checkpoints. An upstream
usually tracks the task branch; a merge-base proves shared history, not intended parent identity.
Parent intent comes from the approved task and retained start SHA, reconciled with the canonical
PR base/head graph for submitted branches. Prove the admitted parent SHA is an ancestor of the
child with `git merge-base --is-ancestor <admitted-parent-sha> <child-head>` and compare current
parent and PR base separately. A moved parent tip need not already be in the child. Apply the
[base-change contract](../../woostack-init/references/artifact-backends.md#repository-ancestry-and-base-change-detection)
before fresh work. Missing, conflicting, or rewritten ancestry blocks. Branch names alone do not
prove task identity. Preserve unrelated work; never reset, clean, stash, delete, or overwrite it.

## Create or modify

Use the caller/host-selected isolated worktree and branch under the
[workspace guidance](../../woostack-init/references/worktrees.md). Verify checkout, canonical
repository, branch, HEAD, parent ancestry, and collision-free physical path before mutation. Do
not prescribe a path, branch recipe, or cleanup. Stage only verified task hunks, and append a
`git commit -m <subject>` when the index contains a new task change; never automatically amend.
With no new staged change, reuse the verified commit for pending submission or PR metadata recovery.

After committing, independently read branch, HEAD, parent, message, committed diff, index, and
worktree. The new commit's diff must equal the approved staged diff, the complete base-to-head diff
must remain in scope, and the index must be empty. Leave unrelated unstaged content untouched.
An error or timeout has an unknown outcome: rediscover state before deciding whether to retry.

## Submit

Re-read branch, HEAD, parent, remote branch, and fully paginated canonical PR inventory. Use only
the verified remote for the canonical repository. Publish exactly the task branch without force;
independently verify its remote ref equals the intended commit. A non-fast-forward rejection blocks:
do not implicitly pull, rebase, reset, or force-push. New PRs are drafts; preserve existing PR
readiness.

### GitHub submission

Reuse the one matching open PR. Only complete absence proof permits a new draft with the exact
repository, head, and intended parent/base. Foreign head repository, conflicting base, duplicate,
or closed PR state blocks; never retarget or create around it. After identity verification, update
title/body while preserving human-authored content under the [PR-body contract](pr-body.md).
Host-authenticated `gh` equivalents include `git push <remote> HEAD:refs/heads/<task-branch>`,
`gh pr create --repo <owner/repo> --head <task-branch> --base <parent-branch> --draft --title <title> --body-file <body-file>`,
and `gh pr edit` for a verified existing PR.

### Read-back and recovery

Independently read the canonical GitHub PR and verify repository, URL/number, head branch/SHA,
base, open state, and uniqueness. Successful command output alone is not proof. After unknown push
or PR mutation, rediscover remote ref and complete PR inventory; resume only the missing boundary,
never recommit or create a second PR. Never submit unrelated branches, merge, mark ready, enable
auto-merge, enqueue, or force-push.

## Stack reconciliation

The calling workflow owns affected-set discovery, conflict gates, review invalidation, and
descendant reconciliation. Incorporate each verified parent tip with a local Git merge in the
child's clean isolated worktree, then push only that branch normally. A local ancestry merge is not
a GitHub PR merge and does not grant merge authority. A rewritten published head requiring a
non-fast-forward push blocks for human resolution.

## Optional GitHub issue context and return

A caller-selected exact GitHub issue may supply context or a delivery note under
[provider-attribution.md](provider-attribution.md). It never selects branch, worktree, parent,
commit, PR, or submission authority. Return exact worktree, branch, parent/base, commit SHA/message
and diff identity, PR URL/head/base (or `not submitted`), and first unknown boundary. Claim no
history or remote mutation without independent read-back.
