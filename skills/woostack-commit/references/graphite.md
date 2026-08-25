# Graphite branch and submission boundary

Use this reference for repository history mutation in `woostack-commit`. It is task/branch based;
Linear is not required.

## Resolve the task branch

The caller supplies the approved bounded task, stable task/run identity, canonical repository,
integration base/start commit, intended Graphite parent, worktree, and reviewed diff identity.
Before mutation verify:

- exact deterministic worktree path, complete `git worktree list --porcelain` inventory, and current
  branch/HEAD;
- canonical remote and integration base;
- Graphite parent/stack ancestry;
- staged, unstaged, untracked, conflict, and complete diff state;
- complete changed-path set equals the approved task surface;
- absence or one exact current-branch canonical PR; and
- no duplicate branch, checkout, commit, or PR.

Branch display text is not task identity. Preserve unexpected or unrelated work and stop on
collision. Never reset, clean, stash, delete, overwrite, or create around state.

## Create or modify

When the approved task has no branch and the current collision-safe checkout is at its exact start
point, create one concise repository-conventional task branch/commit:

```bash
gt create -m "<type>: <concise subject>"
```

When already on the one verified task branch, update only its staged task diff:

```bash
gt modify -m "<type>: <concise subject>"
```

Do not amend an unrelated commit or branch. After the command, independently read branch, HEAD,
parent, commit message, committed diff, index, and worktree. Staged content must be empty and the
committed paths/diff must equal the approved staged identity. Unrelated unstaged changes may remain
untouched.

An error or timeout is an unknown outcome. Re-read repository and Graphite state before deciding
whether anything remains; never replay blindly.

## Submit

Before submission re-read the exact task branch/head/parent, Graphite stack, remote branch, and
canonical PR inventory. Submit only the current task branch or explicitly approved affected stack:

```bash
gt submit
```

Do not use raw Git push or `gh pr create` as a substitute for Graphite. Do not force-push, sync the
repository, submit unrelated descendants, or create a duplicate PR.

Afterward independently fetch the canonical GitHub PR and verify repository, number/URL, head
branch/SHA, base, open state, and uniqueness. If the submission result is unclear, rediscover remote
branch and PR state. Retry only when complete evidence proves the intended boundary is absent.

`gh pr edit` is allowed only after exact current PR identity verification and only for the title/body
fields owned by `woostack-commit`.

## Optional artifact context

An exact caller-selected Linear or Plane artifact may be carried as descriptive context or receive a delivery
note under [provider-attribution.md](provider-attribution.md). It never selects the branch, worktree,
parent, commit, PR, or submission authority.

## Return

Return the exact worktree, branch, parent/base, commit SHA/message/diff identity, PR URL/head/base,
and first unknown boundary. Never claim a history or remote mutation without direct read-back.
