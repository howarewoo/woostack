# Worktree lifecycle + base-branch contract

The single source of truth for **how woostack skills isolate every write in a per-PR git
worktree** and **how the base/trunk branch is resolved**. `woostack-build`, `woostack-execute`,
`woostack-execute-overnight`, `woostack-fix`, and `woostack-commit` link this file; none restate it.
The point: let multiple bootstrap/build/fix runs proceed **in parallel on one machine** without
collision.

`<wi>` below = the installed `woostack-init` scripts directory (the same place `build-index.sh`
lives; the agent resolves it when the skill is available).

## 1. Base-branch resolution

Resolve the integration/trunk branch with `<wi>/resolve-base.sh` — never a hardcoded `staging`. It
exports `WOOSTACK_BASE_BRANCH` (and prints it when executed) with precedence:

1. explicit `WOOSTACK_BASE_BRANCH` override (host pins, tests),
2. `.woostack/config.json` → `base_branch` (when set and non-empty),
3. `git symbolic-ref refs/remotes/origin/HEAD` (the remote default branch),
4. `main` (fresh repo / no remote).

```bash
base="$(bash <wi>/resolve-base.sh)"     # capture in a fresh shell
```

This value is what a **stack base** branch is cut from and what a **base PR targets** (`--base`).

## 2. Worktree lifecycle

### Create (on the first write)

```bash
base="$(bash <wi>/resolve-base.sh)"            # or the parent branch tip for a stacked increment
slug="${branch//\//-}"                          # branch feature/foo -> dir feature-foo
wt="$WOOSTACK_ROOT/.woostack/worktrees/$slug"   # anchored to the PRIMARY repo root
git worktree add -b "$branch" "$wt" "$base_ref"
( cd "$wt" && gt track --parent "$base_parent_branch" )   # Graphite: register the stack parent
```

`-b` creates a **fresh** branch at `$base_ref`, so `$base_ref` is only a start-point and is never
checked out — no "branch already checked out in another worktree" clash, and parallel runs (disjoint
branch sets) never collide.

### Operate (cwd = the worktree)

From the first write onward the run operates with **cwd = `$wt`**. **All** writes happen there — the
`.woostack/` spec/plan/fix markdown *and* the implementation code — and any sub-skill the run calls
(`woostack-plan`, `woostack-harden`, `woostack-commit`) inherits that cwd so it authors into the
worktree, not the primary tree. In subagent mode the controller dispatches implementers with cwd =
`$wt`.

### Teardown (after a SUCCESSFUL commit + push + PR)

```bash
git worktree remove "$wt"
```

Only the working dir is deleted; the **branch, commits, and PR persist**. **On failure** (commit /
push errored, or an unresolved review blocker) → **leave the worktree** and report its path. **On
abandon** (the run is dropped before a PR exists) → `git worktree remove --force "$wt"` and delete
the dangling branch. Never lose committed work.

## 3. Hard invariant: the primary tree is never edited

A run does all its writes in its own worktree; the primary checkout stays on the base branch, clean,
as the stable point all runs branch from. This is what makes parallel safe — two runs never touch
the primary tree.

- **Local-only exception:** `.woostack/memory/` and `.woostack/metrics.json` are gitignored and
  primary-tree-only; they are written via the `WOOSTACK_ROOT` export of §5 so they survive teardown.
- **Workflow exception:** `woostack-bootstrap`'s one-time initial repo creation + first commit (no
  base branch exists yet, pre any parallelism).

**Status visibility is by design.** In-flight artifacts live on a feature branch inside a worktree,
never in the primary working tree, so `/woostack-status` (which scans the primary tree) surfaces
**only merged / base-branch state**, not worktree WIP. A spec/plan/fix is not "on the board" until
its PR merges.

## 4. `base_ref` for stacked PRs

`woostack-execute` produces a Graphite stack. `base_ref` is **parent-aware**:

- **stack base** (the spec+plan branch, or a standalone fix/bootstrap branch) → the resolved
  `WOOSTACK_BASE_BRANCH`.
- **stacked increment k** → the **increment k-1 branch tip** (increment 1 → the spec+plan branch).

Removal-after-commit is safe because `git worktree remove` deletes only the working dir — the branch
outlives it, so the next increment's `base_ref` still exists to cut from. The plan file was committed
on the spec+plan branch, so every increment worktree (branching off it) **has the plan**, and the
increment's checkbox ticks are made there and ride that increment's PR.

`gt track --parent <parent>` + `gt submit` open/update each PR with **base = parent branch** so
GitHub renders the stack. **`gt submit` scope:** submit only the current branch's own (disjoint)
stack — never `gt sync` / restack-all while a parallel run is in flight. Raw-git fallback (no `gt`):
identical branch ancestry; `gh pr create --base <parent-branch>`.

## 5. Memory / metrics resolve to the primary tree

`.woostack/memory/` and `.woostack/metrics.json` are gitignored and local-only — they exist **only
in the primary checkout**. Because the cadence runs inside a worktree, export the primary root before
any distill/metrics write so it lands in the primary store, not the ephemeral worktree:

```bash
export WOOSTACK_ROOT="$(cd "$(git rev-parse --git-common-dir)/.." && pwd)"   # primary root, from anywhere
```

`git rev-parse --git-common-dir` resolves to the **primary** `.git` from inside any worktree, so its
parent is the primary root. `resolve-root.sh` honors that `WOOSTACK_ROOT` override as its
highest-precedence source, so distill and metrics anchor to the primary `.woostack/`. No script
change needed.

## 6. Parallel-safety caveats (best-effort, documented)

- **Shared `.git` / Graphite metadata** serializes via git's index/ref locks (brief contention, no
  corruption). Each run submits only its own stack; never run a repo-wide `gt sync`/restack while a
  parallel run is in flight.
- **`.woostack/memory/` index rebuild + `.woostack/metrics.json`** are last-writer-wins. Different
  runs write different note files; only the index/`MEMORY.md` rebuild and the metrics file are racy,
  and both are local/rebuildable. No locking (YAGNI).

## 7. Orphan worktrees

Leave-on-failure can leave worktrees behind. They are inert (gitignored). Reclaim with:

```bash
git worktree list
git worktree prune            # drops admin records for deleted dirs
git worktree remove <path>    # or remove a specific stale worktree
```

A pre-existing dir at a slug usually means a stale worktree from a crashed run — remove/prune it
before retrying; never silently reuse or overwrite it.
