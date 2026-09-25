# Source-control branch and submission boundary

This contract applies to Commit, worktrees, delivery, planning, and reconciliation. Git and
canonical GitHub reads prove repository state; provider artifacts never authorize source mutations.

Use native Git with an available, authorized GitHub integration for PR delivery. Prefer suitable
host-native tools; host-authenticated `gh` is supported. Discover operation capabilities, complete
read shapes, and read-back support before mutation. Keep credentials in the host. Unsupported or
unknown capability blocks that operation, never licenses a different transport after failure.
`--no-pr-update` requires only local Git: no push, PR, or stack operation and no GitHub authentication
or remote discovery. Retain known PR identity without claiming an unperformed read.

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
readiness. Updating an existing PR, including a lower stack layer, does not resubmit descendants.

### GitHub submission

Reuse the one matching open PR. Only complete absence proof permits a new draft with the exact
repository, head, and intended parent/base. Foreign head repository, conflicting base, duplicate,
or closed PR state blocks; never retarget or create around it. After identity verification, update
title/body while preserving human-authored content under the [PR-body contract](pr-body.md).
Host-authenticated `gh` equivalents include `git push <remote> HEAD:refs/heads/<task-branch>`,
`gh pr create --repo <owner/repo> --head <task-branch> --base <parent-branch> --draft --title <title> --body-file <body-file>`,
and `gh pr edit` for a verified existing PR.

### Native GitHub stack membership for a dependent PR

Only a caller-approved dependent PR needs this step, after its exact PR is submitted. The caller
supplies the intended parent and chain; Commit does not infer dependencies, choose a parent, or
schedule siblings. Read each chain PR (including the child) and fully paginate the repository's
native stack inventory; resolve candidate stacks by PR number and read their exact stack records.
Prove unique open PRs, same-repository heads, unchanged head SHA/base/readiness, the child base
equals its approved parent's head branch, each earlier base equals its predecessor's head, the
bottom base is the configured integration/trunk branch, and admitted Git ancestry still holds.
A chained PR base alone is not native stack membership.

If the child already belongs to precisely the intended stack at the intended position, reuse it
without mutation. If the parent is the top of an existing matching stack and the child is unstacked,
append only the child. Otherwise, with no member already registered, create one stack from the
verified bottom-to-top PR numbers. Use a narrowly scoped authorized GitHub stack operation, such as
the [REST stack create/add endpoints](https://docs.github.com/en/rest/pulls/stacks):
`POST /repos/{owner}/{repo}/stacks` with `pull_requests` for creation or
`POST /repos/{owner}/{repo}/stacks/{stack_number}/add` for a top-only append. Host-authenticated
`gh api` supports these REST operations. Never use stack-wide submit/push/sync or require the
`gh stack` extension or local tracking. Its
[`link` command](https://docs.github.com/en/pull-requests/reference/stacked-prs-cli-commands#gh-stack-link)
is optional only when the exact PR-URL invocation is proven not to push, create/retarget PRs, or
change readiness; branch inputs and `--open` are unsafe substitutes.

Conflicting or uncertain membership, a registered non-top parent, foreign repository, moved parent,
or unavailable stack capability blocks stack delivery without altering the existing commit/PR.
After mutation or an unknown outcome, re-read native membership (including trunk, stack number,
and complete ordered PR numbers) and each affected PR's head SHA, base, content, and readiness.
Verify the child follows its approved parent and all earlier members are unchanged. Recover only
the missing operation from this fresh evidence; never create a replacement stack or claim a
registered stack from chained bases or a mutation response alone. Independent PRs and local-only
commits skip this step entirely.

### Read-back and recovery

Independently read the canonical GitHub PR and verify repository, URL/number, head branch/SHA,
base, open state, and uniqueness; for a dependent PR also verify the native stack as above.
Successful command output alone is not proof. After unknown push, PR, or stack mutation,
rediscover remote ref, complete PR inventory, and affected stack membership; resume only the
missing boundary, never recommit or create a second PR or stack. Never submit unrelated branches,
merge, mark ready, enable auto-merge, enqueue, or force-push.

## Stack reconciliation

The calling workflow owns affected-set discovery, conflict gates, review invalidation, and
descendant reconciliation. [GitHub's stack requirements](https://docs.github.com/en/pull-requests/reference/stacked-pull-requests)
evaluate protections against the native stack's trunk, not each child's PR base, and require
linear inter-branch history for merging. A changed lower-layer head or trunk can break that
linearity. Do not automatically merge each moved parent into its child, cascade restacks,
rewrite published heads, force-push, or request a server-side rebase. Preserve the affected
branches/PRs and report a human-maintenance boundary when reconciliation requires a rewrite;
re-read Git and native stack evidence after that change. This is not a merge-readiness gate on
ordinary task commits or same-PR updates.

## Optional GitHub issue context and return

A caller-selected exact GitHub issue may supply context or a delivery note under
[provider-attribution.md](provider-attribution.md). It never selects branch, worktree, parent,
commit, PR, or submission authority. Return exact worktree, branch, parent/base, commit SHA/message
and diff identity, PR URL/head/base (or `not submitted`), and for a dependent PR the verified
stack number/trunk/order or first incomplete boundary. Claim no history or remote mutation
without independent read-back.
