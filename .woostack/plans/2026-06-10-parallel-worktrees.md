**Source:** .woostack/specs/2026-06-10-parallel-worktrees.md

# Parallel worktree isolation + configurable base branch Implementation Plan

**Goal:** Let multiple `woostack-bootstrap`/`build`/`fix` runs proceed in parallel on one machine by giving each PR its own git worktree (all writes — `.woostack/` markdown *and* code — happen inside it, removed after commit), and make the integration/trunk branch per-repo configurable — while preserving the Graphite stacked-PR model `woostack-execute` produces.

**Architecture:** One canonical contract (`woostack-init/references/worktrees.md`) defines the worktree lifecycle, the never-edit-primary invariant (a run runs with **cwd = its worktree** from the first write; only local-only memory/metrics go to the primary tree), the parent-aware `base-ref` rule for stacks, and the intentional `/woostack-status` consequence (worktree WIP is invisible until merge). A sourced+executable `resolve-base.sh` helper centralizes base-branch resolution (`config.base_branch` → `origin/HEAD` → `main`), replacing every hardcoded `staging`. The work stacks: foundation (resolver + gitignore + contract) → commit consumer + staging sweep → build/fix/bootstrap wiring → execute/overnight per-increment cadence.

**Tech Stack:** Bash (coreutils + `jq` + `git` + `git worktree`), Markdown skill docs, the existing `woostack-init/scripts/tests` bash harness (`assert.sh`, auto-discovering `run-tests.sh`).

> Path convention used below: `<wi>` = the installed `woostack-init` scripts directory (the same place `build-index.sh` lives; the agent resolves it when the skill is available). Helpers are referenced by that path, mirroring how the skills already reference `build-index.sh`/`doctor.sh`.

---

## Increment 1: Foundation — base resolver, gitignore, worktree contract, init wiring

> One independently shippable PR (≤500 LOC soft target) — its own Graphite-stacked branch. Adds new files + docs only; no behavior change to existing flows yet. The base of the stack.

### Task 1: `resolve-base.sh` shared helper + RED-first test

**Files:**
- Create: `skills/woostack-init/scripts/resolve-base.sh`
- Test: `skills/woostack-init/scripts/tests/test-resolve-base.sh`

- [ ] **Step 1: Write the failing test**

Create `skills/woostack-init/scripts/tests/test-resolve-base.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DIR/tests/assert.sh"
resolver="$DIR/resolve-base.sh"

# Run the resolver SOURCED in a clean env (config/remote path), echo the result.
resolved() { # repo
  ( cd "$1" && env -u WOOSTACK_BASE_BRANCH WOOSTACK_ROOT="$1" \
      bash -c 'set -e; . "$1"; printf "%s" "$WOOSTACK_BASE_BRANCH"' _ "$resolver" )
}

# 1. config.base_branch set -> wins
repo1="$(mktemp -d)"; ( cd "$repo1" && git init -q && git commit -q --allow-empty -m init )
mkdir -p "$repo1/.woostack"; printf '{"base_branch":"trunk"}\n' > "$repo1/.woostack/config.json"
assert_eq "$(resolved "$repo1")" "trunk" "config base_branch wins"

# 2. unset config -> remote default branch (origin/HEAD)
origin="$(mktemp -d)"; ( cd "$origin" && git init -q --bare )
repo2="$(mktemp -d)"
( cd "$repo2" && git init -q && git checkout -q -b dev && git commit -q --allow-empty -m init \
  && git remote add origin "$origin" && git push -q origin dev && git remote set-head origin dev )
assert_eq "$(resolved "$repo2")" "dev" "remote default branch used when no config"

# 3. unset config + no remote -> main
repo3="$(mktemp -d)"; ( cd "$repo3" && git init -q && git commit -q --allow-empty -m init )
assert_eq "$(resolved "$repo3")" "main" "no remote falls back to main"

# 4. explicit WOOSTACK_BASE_BRANCH override honored as-is (config present, but pinned wins)
out4="$( cd "$repo1" && WOOSTACK_ROOT="$repo1" WOOSTACK_BASE_BRANCH="pinned" \
  bash -c '. "$1"; printf "%s" "$WOOSTACK_BASE_BRANCH"' _ "$resolver" )"
assert_eq "$out4" "pinned" "explicit override wins over config"

# 5. EXECUTED (not sourced) prints the resolved branch for $( ) capture
out5="$( cd "$repo1" && env -u WOOSTACK_BASE_BRANCH WOOSTACK_ROOT="$repo1" bash "$resolver" )"
assert_eq "$out5" "trunk" "executed mode prints resolved branch"

finish
```

- [ ] **Step 2: Run the test, confirm it fails**

Run: `bash skills/woostack-init/scripts/tests/test-resolve-base.sh`
Expected: FAIL — the resolver does not exist yet, so `. "$resolver"` errors (`No such file or directory`) and the run exits non-zero.

- [ ] **Step 3: Minimal implementation**

Create `skills/woostack-init/scripts/resolve-base.sh`:

```bash
#!/usr/bin/env bash
# Single source of truth for the woostack base / integration branch.
#
# Sourced (or executed) by every woostack skill that cuts a stack-base branch,
# targets a PR base (`--base`), or resolves a worktree base-ref. Resolving ONE
# base here keeps the trunk branch per-repo configurable instead of hardcoded
# `staging`.
#
# Precedence:
#   1. explicit WOOSTACK_BASE_BRANCH override (host pins, tests) — honored as-is
#   2. .woostack/config.json -> base_branch, if set and non-empty
#   3. git symbolic-ref refs/remotes/origin/HEAD -> the remote default branch
#   4. main — fallback when there is no remote / fresh repo
#
# Root resolution mirrors resolve-root.sh (WOOSTACK_ROOT override ->
# GITHUB_WORKSPACE -> git rev-parse --show-toplevel -> pwd) so `.woostack/`
# anchors to the repo root. (woostack-init/scripts has no resolve-root.sh to
# source, so the precedence is inlined here; keep it in sync with
# skills/woostack-review/scripts/resolve-root.sh.)
if [ -z "${WOOSTACK_ROOT:-}" ]; then
  if [ -n "${GITHUB_WORKSPACE:-}" ]; then
    WOOSTACK_ROOT="$GITHUB_WORKSPACE"
  else
    WOOSTACK_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  fi
fi
export WOOSTACK_ROOT

if [ -z "${WOOSTACK_BASE_BRANCH:-}" ]; then
  _wb_cfg="$WOOSTACK_ROOT/.woostack/config.json"
  _wb_base=""
  if [ -f "$_wb_cfg" ] && command -v jq >/dev/null 2>&1; then
    _wb_base="$(jq -r '.base_branch // empty' "$_wb_cfg" 2>/dev/null || true)"
  fi
  if [ -z "$_wb_base" ]; then
    _wb_base="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || true)"
    _wb_base="${_wb_base#origin/}"
  fi
  [ -z "$_wb_base" ] && _wb_base="main"
  WOOSTACK_BASE_BRANCH="$_wb_base"
fi
export WOOSTACK_BASE_BRANCH

# When executed (not sourced), print the resolved branch so callers can capture it:
#   base="$(bash <wi>/resolve-base.sh)"
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  printf '%s\n' "$WOOSTACK_BASE_BRANCH"
fi
```

- [ ] **Step 4: Run the test, confirm it passes**

Run: `bash skills/woostack-init/scripts/tests/test-resolve-base.sh`
Expected: PASS — `5 passed, 0 failed`.

- [ ] **Step 5: Shellcheck the new script**

Run: `shellcheck -x skills/woostack-init/scripts/resolve-base.sh`
Expected: clean (exit 0, no output).

- [ ] **Step 6: Commit**

```bash
gt create -m "feat(init): add resolve-base.sh base-branch resolver + test"
```

### Task 2: Ignore `worktrees/` in the gitignore template

**Files:**
- Modify: `skills/woostack-init/templates/gitignore`
- Test: `skills/woostack-init/scripts/tests/test-gitignore-template.sh`

- [ ] **Step 1: Write the failing test (extend the existing one)**

In `skills/woostack-init/scripts/tests/test-gitignore-template.sh`, add this line immediately after the `memory/` assertion (before `finish`):

```bash
assert_contains "$body" "worktrees/" "gitignore template ignores per-PR worktrees"
```

- [ ] **Step 2: Run the test, confirm it fails**

Run: `bash skills/woostack-init/scripts/tests/test-gitignore-template.sh`
Expected: FAIL — `gitignore template ignores per-PR worktrees` (`worktrees/` not yet in the template).

- [ ] **Step 3: Minimal implementation**

In `skills/woostack-init/templates/gitignore`, add `worktrees/` to the transient block so it reads:

```gitignore
# Transient, per-clone — not shared knowledge.
metrics.json
*.local.*
visuals/
overnight/
worktrees/
memory.md
memory/
```

- [ ] **Step 4: Run the test, confirm it passes**

Run: `bash skills/woostack-init/scripts/tests/test-gitignore-template.sh`
Expected: PASS — all assertions green including the new one.

- [ ] **Step 5: Commit**

```bash
gt modify -c -m "feat(init): gitignore per-PR worktrees/ dir"
```

### Task 3: The canonical worktree-lifecycle contract

**Files:**
- Create: `skills/woostack-init/references/worktrees.md`

- [ ] **Step 1: Confirm it is absent (RED)**

Run: `test ! -f skills/woostack-init/references/worktrees.md && echo MISSING`
Expected: prints `MISSING`.

- [ ] **Step 2: Create the contract**

Create `skills/woostack-init/references/worktrees.md` with this exact content:

```markdown
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
```

- [ ] **Step 3: Verify the contract exists with its key anchors**

Run: `grep -c "git worktree add -b\|WOOSTACK_BASE_BRANCH\|base_ref\|git-common-dir" skills/woostack-init/references/worktrees.md`
Expected: a count ≥ 4.

- [ ] **Step 4: Commit**

```bash
gt modify -c -m "docs(init): add canonical worktree-lifecycle + base-branch contract"
```

### Task 4: Wire the contract + `base_branch` into the woostack-init SKILL

**Files:**
- Modify: `skills/woostack-init/SKILL.md`

- [ ] **Step 1: Write the failing verification**

Run: `grep -c "worktrees.md\|base_branch" skills/woostack-init/SKILL.md`
Expected: FAIL — prints `0`.

- [ ] **Step 2: Edit the SKILL**

In `skills/woostack-init/SKILL.md`, in the step-2 templates table, add a row after the `.woostack/.gitignore` row:

```markdown
   | `.woostack/worktrees/` directory | (create empty — per-PR git worktrees, gitignored) |
```

Then, in the `config.json` namespace paragraph (after the `status` namespace sentence), append:

```markdown
The optional top-level `base_branch` key sets the integration/trunk branch that base branches are
cut from and PRs target; unset, it auto-detects the remote default (`origin/HEAD`, else `main`).
Resolution lives in [`scripts/resolve-base.sh`](scripts/resolve-base.sh); the per-PR worktree
lifecycle that consumes it is the [worktree contract](references/worktrees.md).
```

- [ ] **Step 3: Confirm the verification passes**

Run: `grep -c "worktrees.md\|base_branch" skills/woostack-init/SKILL.md`
Expected: PASS — prints `≥ 2`.

- [ ] **Step 4: Commit**

```bash
gt modify -c -m "docs(init): document base_branch + worktrees scaffold and link the contract"
```

---

## Increment 2: woostack-commit consumes the resolver; remove every hardcoded `staging`

> Independently shippable. The first consumer of `resolve-base.sh`; closes the Increment-1 deferral. Replaces hardcoded `staging` PR-base wording across the docs.

### Task 1: woostack-commit resolves the base branch + worktree-agnostic note

**Files:**
- Modify: `skills/woostack-commit/SKILL.md`

> `resolve-base.sh` ships clean in Increment 1 (no deferral marker); this increment is its first consumer. No `woostack-defer` marker is used in this plan — the slices are doc/script additions where an isolated diff draws no "missing call site" finding.

- [ ] **Step 1: Write the failing verification**

Run: `grep -c "resolve-base.sh\|WOOSTACK_BASE_BRANCH" skills/woostack-commit/SKILL.md`
Expected: FAIL — prints `0`.

- [ ] **Step 2: Edit step 2 (branch shape) to use the resolved base + worktree-agnostic note**

In `skills/woostack-commit/SKILL.md` §"2. Enforce branch shape before committing", after the `gt create feature/<short-slug>` block, add:

```markdown
Resolve the integration/trunk branch with the shared helper rather than assuming `staging` (`<wi>` =
the installed woostack-init scripts dir):

```bash
base="$(bash <wi>/resolve-base.sh)"
gt create feature/<short-slug> --base "$base"
```

**Running inside a worktree:** when a driving skill (build / execute / fix) has already created a
per-PR worktree on a `feature/*` or `fix/*` branch (see the [worktree
contract](../woostack-init/references/worktrees.md)), this step finds a non-protected branch and
continues — `woostack-commit` commits whatever tree it is invoked in and creates no second branch.
```

- [ ] **Step 3: Edit step 7 (PR create) to target the resolved base**

In §"7. Update PR fields", replace the `gh pr create --base staging …` block with:

```markdown
```bash
base="$(bash <wi>/resolve-base.sh)"
gh pr create --base "$base" --head "$(git branch --show-current)" --title "<concise title>" --body-file <tmp-body-file>
```

For a **stacked** increment PR the base is the **parent branch**, not `$base` (see the [worktree
contract](../woostack-init/references/worktrees.md) §4); Graphite sets it automatically via
`gt submit` when the branch was `gt track --parent`ed.
```

- [ ] **Step 4: Confirm the verification passes**

Run: `grep -c "resolve-base.sh\|worktree" skills/woostack-commit/SKILL.md`
Expected: PASS — prints `≥ 2`.

- [ ] **Step 5: Commit**

```bash
gt create -m "feat(commit): resolve base branch via resolve-base.sh; worktree-agnostic note"
```

### Task 2: Sweep remaining hardcoded `staging` PR-base references

**Files:**
- Modify: `skills/woostack-bootstrap/references/development.md`

- [ ] **Step 1: Find the offending references**

Run: `grep -rn "\-\-base staging" skills/`
Expected: a hit in `skills/woostack-bootstrap/references/development.md` (the `gt create --base staging` line).

- [ ] **Step 2: Rewrite the branching model to reference the configurable base**

In `skills/woostack-bootstrap/references/development.md` §"Branching model", replace the final line:

```markdown
Use Graphite (`gt create`, `gt modify`, `gt submit`) to manage stacks. `gt create --base staging` for the initial branch.
```

with:

```markdown
Use Graphite (`gt create`, `gt modify`, `gt submit`) to manage stacks. The integration/trunk branch
is **per-repo configurable** — resolve it with
[`resolve-base.sh`](../../woostack-init/scripts/resolve-base.sh) (`.woostack/config.json` →
`base_branch`, else the remote default, else `main`) and pass it as the base of the stack:
`gt create --base "$(bash <wi>/resolve-base.sh)"`. The example table above uses `staging` to
illustrate the integration role, not as a hardcoded requirement.
```

- [ ] **Step 3: Confirm no hardcoded PR-base `staging` command remains**

Run: `grep -rn "\-\-base staging" skills/`
Expected: no output.

- [ ] **Step 4: Commit**

```bash
gt modify -c -m "docs(bootstrap): make branching-model base branch configurable, drop hardcoded staging"
```

---

## Increment 3: Worktree lifecycle in build, fix; bootstrap delegate-only

> Independently shippable. Wires create-on-first-write + cwd=worktree + teardown-after-commit into the entry skills. Links the contract; restates nothing.

### Task 1: build — spec+plan worktree from step 2, teardown after step 7

**Files:**
- Modify: `skills/woostack-build/SKILL.md`

- [ ] **Step 1: Write the failing verification**

Run: `grep -c "worktree" skills/woostack-build/SKILL.md`
Expected: FAIL — prints `0`.

- [ ] **Step 2: Edit step 2 (Write the spec) to create + enter the worktree**

In `skills/woostack-build/SKILL.md` procedure step 2, before "author a markdown spec to `.woostack/specs/…`", insert:

```markdown
   **First, create the spec+plan worktree** (the first write of this run, per the [worktree
   contract](../woostack-init/references/worktrees.md)): pick the branch `feature/<slug>`, then
   `git worktree add -b feature/<slug> "$WOOSTACK_ROOT/.woostack/worktrees/feature-<slug>"
   "$(bash <wi>/resolve-base.sh)"` and run **steps 2–7 with cwd = that worktree** — the spec, the
   `woostack-plan` plan, and both hardens author into it, never the primary tree. (On abandon at the
   spec gate, `git worktree remove --force` it and delete the branch.)
```

- [ ] **Step 3: Edit step 7 (Commit the spec+plan PR) to teardown after**

In step 7, after "open a PR", append:

```markdown
   The commit happens inside the spec+plan worktree via `woostack-commit`; after the PR is open,
   **teardown** the worktree (`git worktree remove "$WOOSTACK_ROOT/.woostack/worktrees/feature-<slug>"`).
   The branch/commits/PR persist as the **stack base** the execution increments stack on. Leave the
   worktree on failure and report its path.
```

- [ ] **Step 4: Confirm the verification passes**

Run: `grep -c "worktree" skills/woostack-build/SKILL.md`
Expected: PASS — prints `≥ 2` and references the contract.

- [ ] **Step 5: Commit**

```bash
gt create -m "feat(build): author the spec+plan in a per-PR worktree (step 2), teardown after step 7"
```

### Task 2: fix — fix worktree from step 2, teardown after step 6

**Files:**
- Modify: `skills/woostack-fix/SKILL.md`

- [ ] **Step 1: Write the failing verification**

Run: `grep -c "worktree" skills/woostack-fix/SKILL.md`
Expected: FAIL — prints `0`.

- [ ] **Step 2: Edit step 2 (Write the fix plan) to create + enter the worktree**

In `skills/woostack-fix/SKILL.md` procedure step 2, before "Create a markdown file under `.woostack/fixes/…`", insert:

```markdown
   **First, create the fix worktree** (the first write of this run, per the [worktree
   contract](../woostack-init/references/worktrees.md)): with the chosen `fix/<slug>` branch,
   `git worktree add -b fix/<slug> "$WOOSTACK_ROOT/.woostack/worktrees/fix-<slug>"
   "$(bash <wi>/resolve-base.sh)"` and run **steps 2–6 with cwd = that worktree** — the fix markdown,
   the harden edits, and the TDD code all author into it, never the primary tree. (On abandon at the
   approval gate, `git worktree remove --force` it and delete the branch.)
```

- [ ] **Step 3: Edit step 6 (Commit and PR) to teardown after commit**

In step 6, after the `/woostack-commit` invocation + PR-open sentence, append:

```markdown
   After the PR is open, **teardown** the worktree
   (`git worktree remove "$WOOSTACK_ROOT/.woostack/worktrees/fix-<slug>"`); the branch/commits/PR
   persist. **Leave it on failure** and report its path. The step-7 memory distill targets the
   primary tree — `export WOOSTACK_ROOT="$(cd "$(git rev-parse --git-common-dir)/.." && pwd)"` before
   writing — per the [worktree contract](../woostack-init/references/worktrees.md) §5.
```

- [ ] **Step 4: Confirm the verification passes**

Run: `grep -c "worktree" skills/woostack-fix/SKILL.md`
Expected: PASS — prints `≥ 2`.

- [ ] **Step 5: Commit**

```bash
gt modify -c -m "feat(fix): author the fix + TDD in a per-PR worktree, teardown after commit"
```

### Task 3: bootstrap — delegate-only (base config + exemption + hand-off)

**Files:**
- Modify: `skills/woostack-bootstrap/SKILL.md`

- [ ] **Step 1: Write the failing verification**

Run: `grep -c "worktree" skills/woostack-bootstrap/SKILL.md`
Expected: FAIL — prints `0`.

- [ ] **Step 2: Add a delegate-only note to the hard constraints**

In `skills/woostack-bootstrap/SKILL.md` §"Hard constraints", add a bullet:

```markdown
- **Initial scaffold is the one worktree exemption.** A fresh repo has no base branch to
  `git worktree` from, so the initial scaffold + first commit land in the primary tree. All
  *subsequent* feature/fix work goes through `woostack-build` / `woostack-fix`, which author each PR
  inside its own worktree per the [worktree contract](../woostack-init/references/worktrees.md).
  Bootstrap itself adds no worktree create/teardown step.
```

- [ ] **Step 3: Confirm the verification passes**

Run: `grep -c "worktree" skills/woostack-bootstrap/SKILL.md`
Expected: PASS — prints `≥ 1`.

- [ ] **Step 4: Commit**

```bash
gt modify -c -m "docs(bootstrap): note the initial-scaffold worktree exemption + delegate to build/fix"
```

---

## Increment 4: execute + execute-overnight per-increment worktree cadence

> Independently shippable. Wires the parent-aware worktree create/teardown into the per-increment cadence — the case that produces the Graphite stack. Links the contract.

### Task 1: execute — per-increment worktree, parent base-ref, ticks-in-worktree, memory→primary

**Files:**
- Modify: `skills/woostack-execute/SKILL.md`

- [ ] **Step 1: Write the failing verification**

Run: `grep -c "worktree" skills/woostack-execute/SKILL.md`
Expected: FAIL — prints `0`.

- [ ] **Step 2: Edit per-increment cadence step 1 (Start its branch before editing)**

In `skills/woostack-execute/SKILL.md` §"Per-increment cadence" step 1, replace its body with:

```markdown
1. **Start its branch before editing — in a per-PR worktree.** Verify the current branch is not
   protected, then create the increment's fresh Graphite-stacked branch **in its own worktree** off
   the **parent branch tip**, per the [worktree contract](../woostack-init/references/worktrees.md):

   ```bash
   git worktree add -b <inc-branch> "$WOOSTACK_ROOT/.woostack/worktrees/<inc-slug>" "$parent_branch"
   ( cd "$WOOSTACK_ROOT/.woostack/worktrees/<inc-slug>" && gt track --parent "$parent_branch" )
   ```

   `$parent_branch` is the spec+plan branch for increment 1, else the previous increment's branch
   (the stack base uses the resolved base branch; stacked increments use their parent). All work —
   the TDD code, the plan checkbox ticks (step 3), and, in subagent mode, the implementer subagents
   (dispatched with **cwd = the worktree**) — happens inside it.
```

- [ ] **Step 3: Edit the distill step (step 7) to anchor memory to the primary tree**

In step 7 of the cadence, after "distill the increment's durable, reusable learnings into `.woostack/memory/`", insert:

```markdown
   The cadence runs inside the per-PR worktree, but `.woostack/memory/` is local-only to the
   **primary** tree, so export the primary root before distilling (per the [worktree
   contract](../woostack-init/references/worktrees.md) §5):

   ```bash
   export WOOSTACK_ROOT="$(cd "$(git rev-parse --git-common-dir)/.." && pwd)"
   ```
```

- [ ] **Step 4: Add the teardown after the cycle (after distill)**

At the end of the cadence (after step 7, before "Then advance to the next increment."), insert:

```markdown
8. **Teardown the worktree.** After the increment is committed, reviewed, and distilled, remove its
   worktree (`git worktree remove "$WOOSTACK_ROOT/.woostack/worktrees/<inc-slug>"`); the
   branch/commits/PR persist as the stack base for the next increment. **Leave it on a
   blocker/failure** and report its path. The next increment's worktree is cut off this increment's
   branch tip.
```

- [ ] **Step 5: Confirm the verification passes**

Run: `grep -c "worktree" skills/woostack-execute/SKILL.md`
Expected: PASS — prints `≥ 3` and references the contract.

- [ ] **Step 6: Commit**

```bash
gt create -m "feat(execute): per-increment worktree cadence (parent base-ref, memory->primary, teardown)"
```

### Task 2: execute-overnight mirrors the cadence

**Files:**
- Modify: `skills/woostack-execute-overnight/SKILL.md`

- [ ] **Step 1: Write the failing verification**

Run: `grep -c "worktree" skills/woostack-execute-overnight/SKILL.md`
Expected: FAIL — prints `0`.

- [ ] **Step 2: Edit the per-increment cadence bullet to inherit worktrees**

In `skills/woostack-execute-overnight/SKILL.md`, change the "Per-increment cadence" bullet (currently `branch → implement (driver) → tick … → woostack-commit → review → distill`) to:

```markdown
- **Per-increment cadence**: create per-PR worktree → implement (driver) → tick the plan's
  checkboxes in place → [`woostack-commit`](../woostack-commit/SKILL.md) → review → distill →
  teardown worktree. Identical to [`woostack-execute`](../woostack-execute/SKILL.md)'s cadence,
  including the per-PR [worktree contract](../woostack-init/references/worktrees.md) (parent-aware
  `base_ref`, `WOOSTACK_ROOT`-anchored distill, leave-on-failure). On a track blocker the blocked
  track's last worktree is **left in place** for morning inspection, not torn down.
```

- [ ] **Step 3: Confirm the verification passes**

Run: `grep -c "worktree" skills/woostack-execute-overnight/SKILL.md`
Expected: PASS — prints `≥ 2`.

- [ ] **Step 4: Commit**

```bash
gt modify -c -m "docs(overnight): inherit the per-PR worktree cadence; leave blocked-track worktree for AM"
```

---

## Self-review (run before handing back)

- [x] **Spec coverage** — every spec section maps to a task:
  - §4.1 contract → Inc 1 Task 3; §4.2 lifecycle → contract §2 + Inc 3/4 wiring; §4.3 invariant (primary never edited, cwd=worktree, status-by-design, memory exception) → contract §3 + build/fix step-2 edits (Inc 3 T1/T2) + bootstrap exemption (Inc 3 T3); §4.4 location/slug → contract §2 + gitignore (Inc 1 T2); §4.5 resolver → Inc 1 T1 + Inc 2; §4.6 stacked-PR/`gt submit`/ticks-in-worktree/subagent → contract §4 + Inc 4 T1; §4.7 memory→primary → contract §5 + Inc 4 T1 S3 + Inc 3 T2; §4.8 caveats → contract §6; §6 error handling → contract §2 (leave-on-failure / abandon) + §7 (orphans).
- [x] **AC coverage** — AC1 (contract present + linked, not duplicated) → Inc 1 T3 + every wiring task links it; AC2 (gitignore) → Inc 1 T2 (executable test); AC3 (resolver precedence) → Inc 1 T1 (`test-resolve-base.sh`, RED-first, 5 cases: config/remote/main/override/executed); AC4 (no hardcoded staging) → Inc 2 T2 (grep empty); AC5 (build/execute/fix wired, bootstrap delegate-only) → Inc 3 + Inc 4; AC6 (stacked PRs survive removal) → contract §4 + Inc 4 T1; AC7 (memory→primary) → contract §5 + Inc 4 T1 S3.
- [x] **No placeholders** — new files (`resolve-base.sh`, `test-resolve-base.sh`, `worktrees.md`) carry full content; doc edits give exact anchor text, exact replacement, and a grep/`test` verification with expected output. `<wi>` is a declared path placeholder (the woostack-init scripts dir), not a TODO.
- [x] **Type consistency** — `WOOSTACK_BASE_BRANCH`, `WOOSTACK_ROOT`, `base_ref`/`$parent_branch`, `$WOOSTACK_ROOT/.woostack/worktrees/<slug>`, and the `git rev-parse --git-common-dir` primary-root idiom are used identically across tasks and the contract.

> woostack plan conventions (kept):
> - Frontmatter-free; opens with the `**Source:**` line.
> - Filename mirrors the spec basename `2026-06-10-parallel-worktrees.md` (spec's date).
> - No required-sub-skill banner — execution is `woostack-execute`'s.
> - This is a skills/docs repo: "failing test" steps for doc edits are concrete `grep`/`test` verifications with exact expected output; the two executable suites (`test-resolve-base.sh`, `test-gitignore-template.sh`) are genuine RED-first bash tests run via `run-tests.sh`.
