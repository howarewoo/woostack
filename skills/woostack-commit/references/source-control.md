# Source-control branch and submission boundary

This file is the canonical owner of Commit delivery, PR submission, and their recovery. Git and
canonical GitHub reads prove repository state; provider artifacts never authorize a source
mutation.

Use native Git with an available, authorized GitHub integration, preferring the host's native
GitHub tools; host-authenticated `gh` is supported. Discover read shape, pagination, and read-back
support before a consequential write. An unknown or unsupported capability blocks that operation; a
backend error is not permission to switch transport or credentials.

Read only what the current step needs: this working tree's branch, base, and diff, plus a targeted
query for the PR or stack it acts on. A complete repository inventory is warranted only when that
targeted query is ambiguous.

`--no-pr-update` is local-only: no push, PR, or stack write, and no GitHub authentication or
remote read. Retain known PR identity without claiming a read that did not happen.

## Resolve the working tree and base

The caller's authorized outcome plus current Git evidence — not a branch name, commit message, PR,
artifact, or prior session — decide what belongs in this commit. Before mutation, read the physical
worktree, branch, HEAD, intended base, index, tracked and untracked changes, and complete diff;
classify every changed path. Resolve the canonical remote for publication, not local-only Commit.

Parent identity is the approved parent branch, reconciled with the PR base for a submitted branch;
an upstream or a merge-base proves shared history, not intended parent. The branch's own current
evidence is the proof: where a dependency, a base change, or a submitted PR must be established,
read that branch rather than a caller packet. Prove ordinary linear history with
`git merge-base --is-ancestor <parent-sha> <child-head>`, and prove a squash-merged parent by content
present in the parent branch, since it leaves no source-head ancestry.
A moved parent tip need not already be in the child, and no admitted parent or start SHA is
required once branch and PR evidence already establish the relationship. Apply the
[base-change contract](../../woostack-init/references/artifact-backends.md#repository-ancestry-and-base-change-detection)
to fresh work. Missing, conflicting, or rewritten ancestry blocks.

Block protected-primary work, detached HEAD, unresolved conflicts, unexplained staged paths, a
competing checkout or writer on the same tree, an existing PR whose repository, head, base, or
ancestry conflicts, and any path outside the outcome. A mixed worktree is usable only when every
in-scope hunk can be staged without touching or hiding unrelated changes; ambiguous mixed hunks
block. Preserve unrelated work: never switch branches, reset, clean, stash, delete, or overwrite it
to make the state convenient. Inspect the wider worktree inventory only when reuse, collision, or
ownership is actually in question.

## Create or modify

Stage verified in-scope paths or hunks and append `git commit -m <subject>`; never amend or rewrite
another branch automatically. With no new staged change, reuse the verified commit for pending
submission or PR metadata recovery.

After committing, independently read branch, HEAD, parent, message, committed diff, index, and
worktree: the commit's diff equals the approved staged diff, the base-to-head diff stays in scope,
and the index is empty. If a hook or staging operation changed content unexpectedly, unstage only
the paths this invocation staged, preserve the worktree, and stop with the exact mismatch.

## Submit

Publish the task branch with a non-force push to the verified remote, then independently read the
remote ref and confirm it equals the intended commit. A non-fast-forward rejection blocks: never
pull, rebase, reset, or force-push around it. Updating one PR, including a lower layer of a chain,
does not resubmit its descendants.

Query PRs across all states for this exact head repository and branch, paginating until the
matching set is exhausted. Reuse its one matching open PR. Only proved absence across states
permits a new draft with the exact repository, head, and intended base. A closed or merged match,
duplicate, foreign head repository, conflicting base, or unreadable result blocks — never retarget
or create around it. New PRs are always drafts; an existing PR keeps its readiness. Update the
title and body under the [PR-body contract](pr-body.md) after identity verification.

Host-authenticated `gh` equivalents include
`git push <remote> HEAD:refs/heads/<task-branch>`,
`gh pr create --repo <owner/repo> --head <task-branch> --base <parent-branch> --draft --title <title> --body-file <body-file>`,
and `gh pr edit` for a verified existing PR.

## Native GitHub stack membership for a dependent PR

Register a dependent PR in a native GitHub stack only when the caller explicitly requests it or
repository workflow requires it. A chained base delivers without registration; unavailable optional
stack metadata does not invalidate an otherwise verified commit and PR, and registration is never
claimed without a verified read. When registration was explicitly required and cannot be
completed, report that boundary precisely.

When it is required, the caller supplies the intended parent and chain; Commit infers no
dependency, parent, or order. Read the child and each chain PR, then query the repository's stacks
for those PR numbers and read the matching stack records. Prove unique open PRs, same-repository
heads, unchanged head SHA/base/readiness, that the child base equals its approved parent's head
branch, that each earlier base equals its predecessor's head, that the bottom base is the
configured trunk, and that admitted Git ancestry still holds. A chained PR base alone is not
membership.

Reuse precise membership without mutation. If the parent tops a matching stack and the child is
unstacked, append only the child. Create one stack from the verified bottom-to-top PR numbers only
when none of its members is registered. A child in another stack, a registered non-top parent, or
any conflicting or uncertain membership blocks registration without altering the verified PR.
Use a narrowly scoped authorized stack operation, such as
[the REST stack create/add endpoints](https://docs.github.com/en/rest/pulls/stacks):
`POST /repos/{owner}/{repo}/stacks` with `pull_requests` for creation, or
`POST /repos/{owner}/{repo}/stacks/{stack_number}/add` for a top-only append; host-authenticated
`gh api` supports both. Never run a stack-wide submit/push/sync or require `gh stack` tracking.

## Read-back and recovery

Read the canonical PR back and verify repository, URL/number, head branch/SHA, base, open state, and
uniqueness; for a registered stack also verify stack number, trunk, and complete ordered
membership. Successful command output alone is not proof.

After an unknown commit, push, PR, or stack outcome, rediscover the remote ref, the targeted PR
query, and affected stack membership, then resume only the missing boundary. A lost create response
is not proof of absence: never recommit, create a second PR or stack, or repeat a write merely
because a response was missing. Never submit unrelated branches, merge, mark ready, enable
auto-merge, enqueue, close issues, or force-push.

## Stack reconciliation

The calling workflow owns affected-set discovery, conflict gates, review invalidation, and
descendant reconciliation. [GitHub's stack
requirements](https://docs.github.com/en/pull-requests/reference/stacked-pull-requests) evaluate
protections against the native stack's trunk, not each child's PR base, and require linear
inter-branch history for merging, so a changed lower-layer head or trunk can break that linearity.
Do not automatically merge each moved parent into its child, cascade restacks, rewrite published
heads, force-push, or request a server-side rebase. Preserve the affected branches and PRs, report
the human-maintenance boundary when reconciliation needs a rewrite, and re-read Git and stack
evidence afterward. This is not a merge-readiness gate on an ordinary task commit or same-PR
update.

## Optional GitHub issue context

A caller-selected exact GitHub issue supplies context, PR association, and an explicitly requested
note under [provider-attribution.md](provider-attribution.md). It never selects the branch,
worktree, parent, commit, PR, or submission authority, and its note stays optional and separate
from repository delivery. Commit reports the branch/base, commit, changed paths, PR identity, any
required stack read-back, and the first incomplete boundary, claiming no history or remote
mutation without independent read-back.
