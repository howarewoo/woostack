# Canonical worktree contract

Worktrees isolate tracked implementation writes and make collisions/recovery explicit. They do not
own scope, allocation, dependencies, approval, acceptance, or merge authority. The approved
workflow contract owns those decisions; Git, Graphite, and canonical GitHub reads own repository
state. Linear is optional artifact context only.

`<wi>` below means the installed `woostack-init` skill directory. Its worktree helper is:

- `<wi>/scripts/resolve-base.sh` — resolve the configured integration base.

## 1. Identity and placement

Every active implementation task has one stable task ID, one controller/engineer run, one branch,
and one worktree. The approved task/run contract supplies identity; the deterministic path plus
direct Git, Graphite, and canonical GitHub evidence supplies repository state. For filesystem
placement, require the ID to be one non-empty path component matching
`^[A-Za-z0-9][A-Za-z0-9._-]*$`; reject separators, whitespace, and any other encoding. Never derive
identity from a title, ordinal, recent activity, issue key, shortened hash, or disposable directory
name.

The physical primary root is the common Git directory's repository root, not whichever worktree the
caller currently occupies. Resolve it inline from any checkout:

```sh
git_common_dir="$(git rev-parse --git-common-dir)"
WOOSTACK_ROOT="$(cd "$git_common_dir/.." && pwd -P)"
```

Place each task worktree at
`$WOOSTACK_ROOT/.woostack/worktrees/tasks/<stable-task-id>`; never nest it inside another task
worktree or a tracked source directory.

Optional exact Linear project/issue IDs may be recorded as descriptive context, but cannot replace
the stable task ID or any repository identity.

## 2. Verified start point

A caller supplies one complete task-bound ancestry contract whose stable canonical parent-branch
Apply the shared
[repository ancestry contract](artifact-backends.md#repository-ancestry-and-base-change-detection)
to its last independently admitted parent tip. Mutable observed refs, heads, commits, and tips
remain repository evidence outside content approval identity. Never substitute the current
checkout, current branch tip, ordinal adjacency, a PR title, or inferred local ownership.

### Standalone bounded task

Resolve the integration branch with `<wi>/scripts/resolve-base.sh`; never hard-code `main` or
`staging`. Retain the exact canonical branch/ref and admitted tip from independent Git/GitHub
reads. Apply the shared repository advancement contract before using any newly observed tip for
fresh work.

### Plan dependency root

A root starts from its stable approved parent branch intent and last admitted tip. Fresh work may
start only at the latest tip after parent-tip admission. Multiple roots may
start there in parallel only when the complete approved DAG proves no dependency path and task IDs,
responsibility surfaces, runs, worktrees, branches, and PRs are disjoint.

### Plan dependency child

A child declares exactly one predecessor as its Git parent. Require that predecessor's canonical
branch identity, complete delivery checkpoint, commit, canonical PR identity/head/base, fully
paginated current-head reviews, merge state, and Graphite parent to agree; read available checks for
observation only (incomplete or unavailable check reads never block). Apply the shared repository
advancement contract before using a newly observed descendant head for fresh child work. Start
retained work from its recorded state and revalidate ancestry, diff, and PR base; never silently
rebase, reset, recreate, or attach it to a different branch. Every non-parent
predecessor must have canonical GitHub merge evidence represented in the child's permitted ancestry.
Reject inferred order, rewritten heads, open non-parent dependencies, duplicate ancestry, conflicts,
or partial proof.

## 3. Direct identity and collision evidence

Before create, resume, review-reopen, handoff, commit, or teardown, take one complete snapshot of:

- the approved stable task/run contract and deterministic worktree path;
- `git worktree list --porcelain`, including every checkout and its branch/HEAD;
- filesystem existence at the deterministic path;
- local and remote branches/commits;
- staged, unstaged, untracked, conflict, and diff state in the relevant checkout;
- Graphite parent/stack ancestry;
- fully paginated canonical GitHub PR head/base/state/reviews/threads; and
- available GitHub checks for observation only (incomplete or unavailable check reads never block).
The task/run identity comes from the active approved controller contract or one completely verified
handoff packet. Repository reads cannot invent, replace, or transfer that identity. Branch display
text, a directory name, chat, recent activity, and artifact fields are never allocation evidence.

Require the deterministic path to agree with both the filesystem and
`git worktree list --porcelain`, the branch to have at most one checkout, and every retained
branch/commit/PR fact to form one consistent ancestry. A material change while the snapshot is
assembled invalidates it; repeat discovery rather than combining observations from different
states.

## 4. Discovery and recovery

Classify the complete direct-evidence snapshot:

1. **All absent:** the deterministic path is absent from the filesystem and worktree inventory, and
   no local/remote branch, commit, or canonical PR already represents the task.
2. **One exact retained state:** resume only when the deterministic path, worktree listing, branch,
   recorded start SHA/head, parent branch, ancestry, dirty/index/diff state, commits, and PR facts
   agree with the same approved task/run contract or completely verified handoff successor. A
   compatible descendant tip on the same canonical parent branch does not invalidate content
   receipts: preserve the retained start/head and freshly revalidate ancestry, diff, and PR base.
3. **Verified review-reopen:** the prior implementation worktree is absent, the same canonical
   branch and PR/head remain, the approved review-fix contract names the same stable task, the
   deterministic path is free, and the branch is not checked out anywhere.
4. **Partial or competing state:** stop. Preserve everything and report the exact conflicting
   paths, checkouts, branches, heads, ancestry, dirty state, or PRs.

Never delete, overwrite, reset, clean, stash, reassign, invent a new task ID, attach an unexplained
branch, or create around a collision.

## 5. Create and assert

After the complete snapshot proves the intended operation collision-free:

1. verify the deterministic path is absent from both the filesystem and
   `git worktree list --porcelain`;
2. for fresh work, use `git worktree add -b <branch> <path> <latest-admitted-parent-tip>` after
   compatible parent-tip re-admission so Git exclusively rejects an existing branch, path, or
   checkout; for verified review-reopen, attach only the already verified canonical branch with
   `git worktree add <path> <branch>`;
3. use `gt track --parent <branch>` for the approved Graphite parent;
4. verify physical path, common Git root, branch, HEAD/start, Graphite parent, and absence of another
   checkout; and
5. re-read dirty/index/diff state plus canonical remote branch/PR evidence at the new boundary.

A failed or partial post-create assertion is an unknown mutation boundary. Rediscover direct
repository state, preserve any observed branch/worktree, and stop; do not recreate or clean it
automatically.

## 6. Operate only in the task worktree

Every source edit, implementation test, formatter, and task-scoped verification command runs from
the exact task worktree. Before the first tracked edit and every worker redispatch, recheck the
approved stable task/run contract, deterministic path, `git worktree list --porcelain`, branch,
parent, allowed surface, and complete dirty/index/diff identity.

The coding worker never:

- reads or writes another task worktree;
- changes allocation, scope, plan dependencies, or acceptance;
- commits, pushes, submits, opens/updates a PR, restacks, or merges when the controller owns those
  boundaries;
- accesses optional artifact credentials or mutates artifacts; or
- moves, removes, or repairs a task worktree.

An unexpected file, branch, checkout, worktree, dirty-state, or ancestry change blocks. Recovery is
decided only from the approved task/run contract and fresh direct repository evidence.

## 7. Commit, review reopen, and restack

The controller invokes [`woostack-commit`](../../woostack-commit/SKILL.md) only after verification
and independent review bind to the same complete diff identity. Immediately before
commit/submission, re-read the task/run contract, deterministic worktree path, complete worktree
inventory, branch, parent, index/diff, and canonical PR evidence.

A review-reopen operation permits only the exact approved review fix on the same branch/PR. It may
reattach that branch only when the deterministic path is free and no checkout already holds it.
After the fix passes focused verification and review, Graphite may restack the affected
branch/descendants under [`woostack-sweep`](../../woostack-sweep/SKILL.md). Re-read every resulting
head/base/ancestry and PR. Review reopen grants no unrelated ref rewrite, merge, or second fix.

Unknown commit/push/submit/restack outcome requires direct rediscovery before retry. Never duplicate
a branch, commit, PR, or operation merely because a command returned unclearly.

## 8. Teardown

Remove a worktree only after direct reads prove the task's controller-owned boundary is complete:
finalized commit, clean task worktree, canonical PR/head/base when submission was requested, and no
unresolved local mutation. Re-resolve and verify the exact deterministic path immediately before
`git worktree remove <path>`.

Keep branch, commits, PR, and optional artifacts. On failure, blocker, collision, handoff, or unknown
outcome, preserve the worktree and report:

- stable task/run ID and approved contract identity;
- deterministic worktree path and current `git worktree list --porcelain` entry;
- branch, start SHA, and Graphite parent;
- dirty/index/diff, commit, and PR state;
- first unverified boundary; and
- exact safe next action.

Never use teardown as cleanup for unexplained state.

## 9. Greenfield bootstrap boundary

A genuinely greenfield target has no Git repository yet, so it cannot use this worktree contract
before scaffolding. [`woostack-bootstrap`](../../woostack-bootstrap/SKILL.md) owns collision-safe
creation. Once Git exists, later bounded tasks use this contract normally.
