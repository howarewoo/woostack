# Source-control branch and submission boundary

This shared contract applies to Commit, worktrees, delivery, planning, Status, and Sweep.
Git and canonical GitHub reads prove repository state. Graphite is an optional stack tool;
provider artifacts never select or authorize source-control mutations.

## Select one mode before mutation

Use native Git and GitHub CLI by default. Use Graphite when the user explicitly selects it or
fresh repository evidence verifies that the task's branch/stack is already Graphite-managed.
An installed `gt` binary alone does not select Graphite. Inspect available repository-local
Graphite metadata and retained task evidence before choosing; do not initialize Graphite to
perform discovery. If evidence indicates Graphite management but cannot be verified, stop before
staging rather than silently treating the branch as native. Missing `gt` in a native repository
is not a blocker. Explicitly selected Graphite requires a working, initialized CLI and verified
parent graph; missing access blocks that mode.

Carry the selected mode through the task and its recovery evidence. Never switch modes as a
fallback after a failed or ambiguous command. Changing an existing managed stack to native Git
requires an explicit user decision and fresh proof of every affected branch/head/base; it is
not implied by optional Graphite support. A new task with no managed ancestry uses native Git.
`--no-pr-update` requires only local tools for the selected mode, not GitHub authentication;
retain available PR identity evidence without claiming an unperformed remote read.

## Resolve the task branch and parent

The caller supplies the approved bounded task, stable task/run identity, canonical repository,
integration base/start commit, intended parent branch, worktree, and reviewed diff identity.
Before mutation verify:

- exact worktree path, complete `git worktree list --porcelain` inventory, and branch/HEAD;
- canonical remote and integration base;
- parent branch intent, retained start/old parent SHA, and Git ancestry;
- Graphite parent/stack ancestry additionally when that mode is selected;
- staged, unstaged, untracked, conflict, and complete diff state;
- complete changed-path set equals the approved task surface;
- for PR delivery, absence or one exact current-branch canonical PR with matching head repository
  and base; local-only `--no-pr-update` preserves known PR facts without requiring remote discovery; and
- no duplicate branch, checkout, commit, or PR.

Use `parentBranch` for backend-neutral parent identity in delivery checkpoints and task contracts.
A remote-tracking upstream is usually the branch itself, not its dependency parent. A merge-base
proves shared history, not intended parent identity. Neither alone establishes a stack edge.
Native parent identity comes from the approved task contract (including the retained start SHA)
and, for submitted branches, the canonical PR base/head graph, reconciled against Git commits.
Prove a retained admitted parent SHA is an ancestor of the child with
`git merge-base --is-ancestor <admitted-parent-sha> <child-head>`; separately compare current parent
and PR base identity. A moved parent tip need not already be in the child. Apply the shared
[base-change contract](../../woostack-init/references/artifact-backends.md#repository-ancestry-and-base-change-detection)
before fresh work. Missing, conflicting, or rewritten ancestry blocks rather than inventing edges.

Branch display text is not task identity. Preserve unrelated work and stop on collision. Never
reset, clean, stash, delete, overwrite, or create around state.

## Create or modify

Create/adopt worktrees under the [worktree contract](../../woostack-init/references/worktrees.md).
When a collision-free task checkout is at the exact approved start point but has no task branch:

- Native: `git switch -c <task-branch> <exact-start-sha>`, then `git commit -m <subject>`.
- Graphite: `gt create <task-branch> -m <subject>` after verifying its intended parent.

On an existing verified task branch:

- Native: append the staged task change using `git commit -m <subject>`; do not automatically amend.
- Graphite: use `gt modify --commit -m <subject>` only after verifying its automatic descendant
  restack cannot touch an unapproved branch or rewrite a published descendant. Otherwise append
  with `git commit -m <subject>` and re-read Graphite ancestry; leave reconciliation to Sweep.

No staged change means no new commit; reuse the exact verified existing commit for pending
submission or PR metadata recovery. Never amend an unrelated commit or restack an unrelated branch.
After mutation independently read branch, HEAD, parent, message, committed diff, index, and worktree.
The new commit's diff must equal the approved staged diff; the task's complete base-to-head diff
must remain in scope. Staged content must be empty; unrelated unstaged content stays untouched.
An error or timeout is an unknown outcome. Rediscover state before deciding whether anything remains.

## Submit

Before submission re-read exact branch/head/parent, selected-mode ancestry, remote branch, and
fully paginated canonical PR inventory. Use only the verified remote pointing to the canonical
repository, not a guessed `origin`. New PRs are drafts; existing draft/readiness state is preserved.

### Native Git and GitHub CLI

1. Push exactly the task branch: `git push <remote> HEAD:refs/heads/<task-branch>`.
   A non-fast-forward rejection blocks; never force, rebase, reset, or pull implicitly.
2. Independently read the remote ref and verify it equals the intended commit before PR creation.
3. Reuse the one matching open PR. Only after complete discovery proves none exists, run
   `gh pr create --repo <owner/repo> --head <task-branch> --base <parent-branch> --draft --title <title> --body-file <body-file>`.
   Prepare the complete body under the [PR-body contract](pr-body.md) before creation.
   A foreign head repository or conflicting base blocks; do not retarget silently.
4. Update existing PR title/body with `gh pr edit` only after exact identity verification.

### Graphite

Choose submission transport before mutation by inspecting installed CLI help and a read-only
dry run. `gt submit` may include ancestors even without `--stack`, and versions that default to
force-with-lease violate this contract's no-force-push rule. Use `gt submit --draft` only when
the installed version supports a verified non-force, exactly scoped submission without changing
existing PR readiness. Otherwise use the native Git/gh submission sequence above while retaining
Graphite parent tracking and independently reading its graph back. This preselected transport is
not a mode switch or an error fallback. Never silently sync, restack, publish, or submit unrelated
ancestors/descendants.

### Read-back and recovery

For both modes independently read the canonical GitHub PR and verify repository, number/URL,
head branch/SHA, base branch, open state, and uniqueness. A successful command is not proof of
remote state. A push or PR-creation timeout requires fresh remote-ref and PR discovery; resume only
the missing boundary, never create a second PR or recommit. Do not force-push, submit unrelated
branches, merge, mark ready, enable auto-merge, or enqueue a PR.

## Stack reconciliation

[Sweep](../../woostack-sweep/SKILL.md) owns exact affected-set discovery, conflict gates, review
invalidation, and descendant reconciliation. Native mode incorporates each verified parent tip
with a local Git merge in the child's clean isolated worktree, then uses a normal single-branch
push. A local ancestry merge is not a GitHub PR merge and never grants human-only merge authority.
Graphite mode uses its guarded stack restack path. Neither mode may force-push; a rewritten
published head requiring a non-fast-forward push blocks for human resolution.

## Optional artifact context and return

An exact caller-selected provider artifact may be carried as context or receive a delivery note
under [provider-attribution.md](provider-attribution.md). It never selects the branch, worktree,
parent, commit, PR, or submission authority.

Return selected mode, exact worktree, branch, parent/base, commit SHA/message/diff identity,
PR URL/head/base (or `not submitted`), and the first unknown boundary. Never claim a history or
remote mutation without direct read-back.
