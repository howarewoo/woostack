# Canonical worktree contract

Worktrees isolate tracked implementation writes and make collisions/recovery explicit. They do not
own scope, allocation, dependencies, approval, acceptance, or merge authority. The approved
workflow contract owns those decisions; Git, Graphite, and canonical GitHub reads own repository
state. Linear is optional artifact context only.

`<wi>` below means the installed `woostack-init` skill directory. The helpers are:

- `<wi>/scripts/resolve-base.sh` — resolve the configured integration base;
- `<wi>/scripts/worktree-common-root.sh` — resolve the common primary root; and
- `<wi>/scripts/worktree-id.sh` — collision-safe stable-task-ID encoding.

## 1. Identity and placement

Every active implementation task has one stable task ID, one controller/engineer run, one branch,
one worktree, and one registry claim. Never derive identity from a title, ordinal, recent activity,
issue key, shortened hash, or disposable directory name.

The physical primary root is the common Git directory's repository root, not whichever worktree the
caller currently occupies. Place task worktrees under a sibling administration root resolved by the
helper; never nest them inside another worktree or a tracked source directory.

Optional exact Linear project/issue IDs may be recorded as descriptive context, but cannot replace
the stable task ID or any repository identity.

## 2. Verified start point

A caller supplies one complete task-bound ancestry contract. Never substitute the current checkout,
current branch tip, ordinal adjacency, a PR title, or a registry entry.

### Standalone bounded task

Resolve the integration branch with `<wi>/scripts/resolve-base.sh`; never hard-code `main` or
`staging`. Retain the exact branch and commit SHA from independent Git/GitHub reads. The branch
starts at that commit and Graphite tracks the integration branch. A moved base on resume is drift,
not permission to rebase silently.

### Plan dependency root

A root starts at the immutable commit SHA frozen by the approved plan and tracks the exact approved
base branch. Multiple roots may start there in parallel only when the complete approved DAG proves
no dependency path and task IDs, responsibility surfaces, runs, registry claims, worktrees,
branches, and PRs are disjoint.

### Plan dependency child

A child declares exactly one predecessor as its Git parent. Require that predecessor's exact branch,
finalized head, canonical PR, and review/merge state to agree. Start the child at that exact head and
pass the same parent branch to `gt track --parent`. Every non-parent predecessor must have canonical
GitHub merge evidence represented in the child's permitted ancestry. Reject inferred order,
rewritten heads, open non-parent dependencies, or partial proof.

## 3. Disposable registry

Before `git worktree add`, atomically create:

```text
$WOOSTACK_ROOT/.woostack/worktrees/.registry/<stable-task-id>/claim.json
```

`claim.json` records only recovery facts:

- stable task ID and approved contract identity/hash;
- canonical repository URL and controller/engineer run ID;
- optional exact Linear IDs when artifact mode was selected;
- branch and absolute worktree path;
- exact start commit SHA and Graphite parent/base branch;
- mode (`implementation` or `review-reopen`);
- creation timestamp; and
- latest observed local Git boundary.

Create the claim with exclusive filesystem semantics; a pre-existing path is a collision until its
contents and all repository evidence prove one exact recoverable state. The registry is gitignored,
disposable administration. It never authorizes edits or proves assignment, dependencies, review,
acceptance, branch ancestry, or PR state.

On handoff, preserve the claim/worktree and update run identity only after the responsible
controller verifies the complete handoff packet and repository state. Chat or artifact assignment
fields do not permit replacement.

## 4. Discovery and recovery

Before create, resume, review-reopen, or teardown, inventory:

- registry claims;
- `git worktree list --porcelain` state;
- local and remote branches/commits;
- Graphite parent/stack ancestry;
- canonical GitHub PR head/base/state/reviews/checks/threads; and
- current worktree/index/diff identity.

Classify:

1. **All absent:** create one claim, branch, and worktree.
2. **One exact retained state:** resume only when task/run or verified handoff successor, claim,
   path, branch, start SHA, parent, ancestry, diff, commit, and PR facts agree.
3. **Verified review-reopen:** the prior implementation worktree/claim is absent, the same canonical
   branch and PR/head remain, the approved review-fix contract names the same stable task, and no
   competing checkout/claim exists. Create a new claim with `mode: review-reopen`.
4. **Partial or competing state:** stop. Preserve everything and report exact conflicts.

Never delete, overwrite, reset, clean, stash, reassign, create a second claim, invent a new task ID,
or create around a collision.

## 5. Create and assert

After the atomic claim:

1. create the branch at the exact approved start commit when absent;
2. add the worktree at the exact collision-checked path;
3. use `gt track --parent <branch>` for the approved Graphite parent;
4. verify physical path, common Git root, branch, HEAD/start, Graphite parent, registry identity, and
   absence of another checkout; and
5. record the verified boundary in the claim.

A failed or partial post-create assertion is an unknown mutation boundary. Preserve claim/worktree
and stop; do not recreate or clean it automatically.

## 6. Operate only in the task worktree

Every source edit, implementation test, formatter, and task-scoped verification command runs from
the exact task worktree. Before the first tracked edit and every worker redispatch, recheck the
stable task/run, claim, path, branch, parent, allowed surface, and diff identity.

The coding worker never:

- reads or writes another task worktree;
- changes allocation, scope, plan dependencies, or acceptance;
- commits, pushes, submits, opens/updates a PR, restacks, or merges when the controller owns those
  boundaries;
- accesses optional artifact credentials or mutates artifacts; or
- deletes/repairs the registry.

An unexpected file, branch, claim, worktree, or ancestry change blocks. Repository evidence—not a
registry field or artifact status—decides whether recovery is safe.

## 7. Commit, review reopen, and restack

The controller invokes [`woostack-commit`](../../woostack-commit/SKILL.md) only after verification
and independent review bind to the same complete diff identity. Re-read claim, branch, parent,
index/diff, and canonical PR evidence immediately before commit/submission.

A review-reopen claim permits only the exact approved review fix on the same branch/PR. After the
fix passes focused verification and review, Graphite may restack the affected branch/descendants
under [`woostack-sweep`](../../woostack-sweep/SKILL.md). Re-read every resulting head/base/ancestry
and PR. It grants no unrelated ref rewrite, merge, or second fix.

Unknown commit/push/submit/restack outcome requires direct rediscovery before retry. Never duplicate
a branch, commit, PR, or operation merely because a command returned unclearly.

## 8. Teardown

Remove a worktree and claim only after direct reads prove the task's controller-owned boundary is
complete: finalized commit, clean task worktree, canonical PR/head/base when submission was
requested, and no unresolved local mutation. Use `git worktree remove <path>` and delete only the
matching registry directory after verifying both exact paths.

Keep branch, commits, PR, and optional artifacts. On failure, blocker, collision, handoff, or unknown
outcome, preserve worktree/claim and report:

- stable task/run ID;
- registry and worktree paths;
- branch, start SHA, and Graphite parent;
- diff/commit/PR state;
- first unverified boundary; and
- exact safe next action.

Never use teardown as cleanup for unexplained state.

## 9. Greenfield bootstrap boundary

A genuinely greenfield target has no Git repository yet, so it cannot use this worktree contract
before scaffolding. [`woostack-bootstrap`](../../woostack-bootstrap/SKILL.md) owns collision-safe
creation. Once Git exists, later bounded tasks use this contract normally.
