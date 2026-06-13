---
name: 2026-06-10-parallel-worktrees
type: spec
status: approved
date: 2026-06-10
branch: feature/parallel-worktrees
links:
---

# Parallel worktree isolation + configurable base branch — Design Spec

> **Plan:** [[plans/2026-06-10-parallel-worktrees]]

> Visualize on demand: render this file with [spec-template.html](spec-template.html) for a rich view. Markdown is the source of truth; the HTML is a presentation target only.

> `status:` is the build-loop phase enum: `draft → hardened → approved → planning → executing → in-review → done` (plus the terminal `abandoned`). The build loop authors each transition and `/woostack-status` reads it; the enum and join contracts are defined once in [conventions.md](../../woostack-status/references/conventions.md).

## 1. Problem

woostack's write-producing skills (`woostack-bootstrap`, `woostack-build` → `woostack-execute`,
`woostack-fix`) all mutate the **single primary working tree** of a repo. That makes it unsafe
to run more than one of them at a time on the same machine against the same repo: two concurrent
runs stomp each other's checkout, branch, and in-progress edits. The user wants to run multiple
bootstraps/builds/fixes **in parallel** without collision.

Two coupled gaps:

1. **No isolation.** All write work happens in the one working tree, so concurrent runs collide.
2. **Hardcoded base branch.** The integration/trunk branch is hardcoded `staging` across the docs
   (`woostack-bootstrap/references/development.md`, `woostack-commit` step 7 `gh pr create --base
   staging`, the `gt create --base staging` guidance). Different repos use different trunks
   (`staging` in one, `dev`/`main` in another), and there is no per-repo override.

## 2. Goal

Let multiple `woostack-bootstrap` / `woostack-build` / `woostack-fix` runs proceed in parallel on
one machine against one repo, by giving **each PR its own git worktree** for all write changes and
**removing that worktree after the commit lands**. Make the **base/trunk branch per-repo
configurable**. Preserve the Graphite **stacked-PR** model that `woostack-execute` produces.

## 3. Non-goals

- **`woostack-address-comments` worktrees.** Recreating a worktree for a branch already under
  review is a reasonable future extension but is **out of scope** here (follow-up note only).
- **A worktree on/off toggle.** Worktree-per-PR is the behavior; no `worktree.enabled` config knob
  (YAGNI). May be revisited if a host genuinely cannot support worktrees.
- **Locking / mutexes for shared local state.** Parallel-write safety for `.woostack/memory/` index
  rebuilds and `.woostack/metrics.json` is **best-effort / last-writer-wins**, documented, not
  enforced with locks.
- **Changing the merge policy.** No skill merges; unchanged.
- **Changing the gate structure** of build/fix. Worktrees are a mechanical change to *where* edits
  happen, not *when* approvals occur.

## 4. Approach

### 4.1 One canonical contract, linked everywhere

Add a new reference, **`skills/woostack-init/references/worktrees.md`** — the canonical
worktree-lifecycle + base-branch-resolution contract, homed beside the existing
[`memory.md`](../../woostack-init/references/memory.md) contract (`woostack-init` owns the
`.woostack/` workspace, the `.gitignore`, and the config template). Every other skill **links** it;
none restates it (per the repo "cross-link, do not duplicate" rule).

### 4.2 Worktree lifecycle

- **Create (before any edits):**
  ```bash
  git worktree add -b <branch> .woostack/worktrees/<branch-slug> <base-ref>
  ```
  A *fresh* branch is created directly in the worktree (`-b`), so `<base-ref>` is only a start-point
  and is never checked out — no "branch already checked out in another worktree" clash, and parallel
  runs (disjoint branch sets) never collide. With Graphite, register the stack parent from inside
  the worktree: `gt track --parent <base-branch>`.
- **Operate:** all edits, TDD, verification, and the `woostack-commit` call run **inside** the
  worktree.
- **Teardown (after a successful commit + push + PR):**
  ```bash
  git worktree remove .woostack/worktrees/<branch-slug>
  ```
  The working dir is deleted; the **branch, commits, and PR persist**. **On failure** (commit/push
  errored, or an unresolved review blocker) → **leave the worktree** and report its path. Never lose
  work.

### 4.3 Hard invariant: the primary tree is never edited

A run does **all** its writes — the `.woostack/` spec/plan/fix markdown *and* the implementation
code — inside its own per-PR worktree. The first file write triggers worktree creation; from then on
the run operates with **cwd = the worktree** (sub-skills it calls, e.g. `woostack-plan` /
`woostack-harden`, inherit that cwd so they author into the worktree, not the primary tree). The
primary checkout stays on the base branch, clean, as the stable point all runs branch from. This is
what makes parallel safe — two builds never touch the primary tree, so they cannot stomp each
other's checkout/branch/edits.

**The one local-only exception is memory/metrics** (`.woostack/memory/`, `.woostack/metrics.json`) —
gitignored, primary-tree-only, written via the `WOOSTACK_ROOT` export of §4.7 so they survive
teardown. **The one workflow exception is** `woostack-bootstrap`'s initial repo creation + first
commit (no base branch exists yet, pre any parallelism).

**Status visibility is intentional:** because in-flight artifacts live on a feature branch inside a
worktree (never in the primary working tree), `/woostack-status` — which scans the primary tree —
**surfaces only merged / base-branch state**, not worktree WIP. This is a deliberate product
choice: a spec/plan is not "on the board" until its PR merges. No status change is in scope.

### 4.4 Worktree location

`.woostack/worktrees/<branch-slug>`, anchored to the **primary** repo root (resolved via
`resolve-root.sh` / `git rev-parse --show-toplevel` from the primary tree — see §4.7), added to the
gitignore template. Because that path is gitignored, branch checkouts never re-materialize it inside
themselves (no recursion). **`<branch-slug>` = the branch name with `/` → `-`** (e.g. branch
`feature/parallel-worktrees` → dir `feature-parallel-worktrees`), so the dir ↔ branch mapping is 1:1
and unique per feature/fix → parallel runs never collide on the same dir. (Harden decision: reuse
the spec/fix `branch:` slug verbatim, sanitized.)

### 4.5 Configurable base branch — shared resolver

New optional **`base_branch`** key in `.woostack/config.json` (sibling of `review` / `status`).
Resolution is implemented **once** as a sourced shell helper — new
**`skills/woostack-init/scripts/resolve-base.sh`**, mirroring the existing
[`resolve-root.sh`](../../woostack-review/scripts/resolve-root.sh) pattern — that every skill sources
rather than re-deriving inline (harden decision). It exports the resolved base with this
**precedence**:

1. `.woostack/config.json` → `base_branch` if set and non-empty (read with `jq`, `.woostack/`
   anchored to `$WOOSTACK_ROOT`).
2. Else auto-detect the remote default: `git symbolic-ref refs/remotes/origin/HEAD` → strip to the
   branch name (e.g. `main`, `master`).
3. Else (no remote / fresh repo) fall back to `main`.

The resolved value feeds **all three** uses that are currently hardcoded `staging`: where a stack's
**base branch is cut from**, what a base PR **targets** (`--base`), and the **worktree `base-ref`
for a stack base**. Every hardcoded `staging` PR-base reference is replaced by sourcing this helper.
The helper ships with a focused script test under `skills/woostack-init/scripts/tests/` (AC3).

### 4.6 Stacked-PR support (the load-bearing case)

`woostack-build` → `woostack-execute` produces a Graphite stack:

```
base_branch (primary tree, never edited)
  └─ spec+plan PR        ← build step 7: worktree off base_branch, removed after commit
       └─ increment 1 PR ← execute: worktree off spec+plan branch, removed after commit
            └─ increment 2 PR ← worktree off increment-1 branch, removed after commit
                 └─ … increment N
```

- **`base-ref` is parent-aware:** only the **stack base** (the spec+plan branch, or a standalone
  fix/bootstrap branch) uses the resolved `base_branch`. **Each stacked increment uses its parent
  branch tip** (increment 1 → spec+plan branch; increment k → increment k-1 branch).
- **Removal-after-commit is safe** because `git worktree remove` deletes only the working dir — the
  branch/commits/PR persist, so the next increment's `<base-ref>` still exists to cut from.
- **Stack registration:** `gt track --parent <parent-branch>` inside each worktree, then `gt submit`
  opens/updates the PR with **base = parent branch** (not `base_branch`) so GitHub shows the stack.
  Raw-git fallback (no `gt`): identical branch ancestry; `gh pr create --base <parent-branch>`.
- **`gt submit` scope** (harden decision): submit only the **current branch's own stack** — never
  `gt sync` / restack-all mid-run. Each run's stack is disjoint from other runs' stacks, so a
  stack-scoped `gt submit` touches only that run's branches; cross-run safety comes from never
  running a repo-wide sync/restack while a parallel run is in flight.
- **Checkbox ticks** (`woostack-execute` step 3) happen **in the increment's worktree** so they ride
  that increment's PR — the plan file is tracked and was committed on the spec+plan branch, so it is
  present in every increment worktree (which branches off it).
- **Subagent mode** (harden decision): the controller (in the primary tree) creates the increment's
  worktree and dispatches implementer subagents with **cwd = that worktree** — it is their "one
  shared working tree" for the increment. Tasks stay sequential within an increment (concurrent edits
  to one tree corrupt it), unchanged from today; the parallelism this spec enables is across separate
  *runs*, each with its own stack and worktrees, not across subagents within a run.

### 4.7 Memory / metrics resolve to the primary tree

`.woostack/memory/` and `.woostack/metrics.json` are gitignored and local-only — they exist **only
in the primary checkout**. Distill (`woostack-execute` step 7) and review-metrics writes must resolve
their `.woostack/` against the **primary** worktree, never the ephemeral one (deleted on teardown).

**Mechanism (harden decision — no shared-script edit):** the existing `resolve-root.sh` already
honors a `WOOSTACK_ROOT` override as its highest-precedence source. The driving skill computes the
primary root **once at run start, while still in the primary tree** (`git rev-parse --show-toplevel`,
or `git rev-parse --git-common-dir` → parent, which yields the primary root from anywhere) and
**exports `WOOSTACK_ROOT`** for all memory/metrics operations. Because the override wins regardless
of cwd, distill and metrics anchor to the primary `.woostack/` even when run from inside a worktree —
so `resolve-root.sh` and the review/address-comments scripts need **no change** (no scope expansion).

### 4.8 Parallel-safety caveats (documented, best-effort)

- **Shared `.git` / Graphite metadata.** Concurrent `gt` operations serialize via git's index/ref
  locks (brief contention, no corruption). Each run **submits only its own stack** and never runs
  `gt sync` / restack-all mid-parallel-run. Disjoint stacks per run → a stack-submit touches only
  that run's branches.
- **`.woostack/memory/` index rebuild + `.woostack/metrics.json`.** Last-writer-wins; documented.
  Different runs write different note files; only the index/`MEMORY.md` rebuild and the metrics file
  are racy, and both are local/rebuildable.

## 5. Components & data flow

| Component | Change |
|---|---|
| **NEW** `skills/woostack-init/references/worktrees.md` | Canonical contract: lifecycle (create/operate/teardown), location + slug rule, never-edit-primary invariant, base-branch resolution, stacked-PR `base-ref` rule, memory/metrics→primary (`WOOSTACK_ROOT` export), `gt submit` scope, parallel caveats, orphan-worktree cleanup, `gt`-less fallback. |
| **NEW** `skills/woostack-init/scripts/resolve-base.sh` | Sourced helper exporting the resolved base branch (config → `origin/HEAD` → `main`), mirroring `resolve-root.sh`. Sourced by commit/build/execute/fix. |
| **NEW** `skills/woostack-init/scripts/tests/test-resolve-base.sh` | RED-first test of the resolver precedence (config set / unset+remote / unset+no-remote). Wired into `run-tests.sh`. |
| `skills/woostack-init/templates/gitignore` | Add `worktrees/`. |
| `skills/woostack-init/scripts/tests/test-gitignore-template.sh` | Assert template ignores `worktrees/`. |
| `skills/woostack-init/templates/config.json` | Leave keys as-is; `base_branch` is documented-optional (default = auto-detect). Document the key + resolution in the contract / `woostack-init` SKILL. |
| `skills/woostack-init/SKILL.md` | Reference the new contract; scaffold note for `.woostack/worktrees/` + `base_branch`. |
| `skills/woostack-bootstrap/SKILL.md` + `references/development.md` | Branching model: replace hardcoded `staging` with the resolved base branch. **Bootstrap itself adds no worktree create/teardown step** — it exempts the initial scaffold (primary tree) and states that all subsequent feature/fix work goes through build/fix (which carry the worktree lifecycle). Link the contract for that hand-off. |
| `skills/woostack-build/SKILL.md` | Create the spec+plan worktree off the resolved base branch when authoring begins (step 2); run steps 2–7 with **cwd = worktree** (so `woostack-plan`/`woostack-harden` author into it); teardown after the step-7 commit (leave on failure; teardown + branch-delete on abandon). Link contract. |
| `skills/woostack-execute/SKILL.md` | Per-increment cadence: create worktree off parent-branch tip before editing (step 1), teardown after commit+distill; `base-ref` = parent; ticks in worktree; memory→primary via `WOOSTACK_ROOT` (link contract). |
| `skills/woostack-execute-overnight/SKILL.md` | Mirror execute's per-increment worktree cadence (shares the cadence; left inconsistent it would be a bug). |
| `skills/woostack-fix/SKILL.md` | Create the fix worktree off the resolved base when the fix markdown is first written (step 2); run diagnosis-capture/plan/harden/approve/TDD with **cwd = worktree**; teardown after the step-6 commit (leave on failure; teardown + branch-delete on abandon). Link contract. |
| `skills/woostack-commit/SKILL.md` | Resolve `base_branch` for branch creation + PR `--base` (replace `staging`); note it may run inside a worktree and stays worktree-agnostic. |
| Repo-wide sweep | grep all hardcoded `staging` / `--base staging` PR-base references and replace with the resolved base branch. |

**Data flow:** driving skill (in primary tree) resolves base branch → resolves `<base-ref>` (base
branch for a stack base, parent tip for an increment) → `git worktree add -b … <base-ref>` →
`gt track --parent` → edits + TDD + tick + `woostack-commit` (inside worktree) → `gt submit` (PR base
= parent) → distill/metrics target primary `.woostack/` → `git worktree remove` (on success) /
leave + report (on failure).

## 6. Error handling

- **`git worktree add` fails** (path exists, base-ref missing, dirty state) → stop, report; do not
  fall back to editing the primary tree. A pre-existing dir at the slug usually means a **stale
  worktree from a crashed run** — instruct `git worktree remove <path>` (or `git worktree prune`)
  before retrying; never silently reuse or overwrite it.
- **Orphan accumulation** (leave-on-failure leaves worktrees behind) → the contract documents
  reclaiming them with `git worktree list` + `git worktree prune` / `git worktree remove`; orphans
  are inert (gitignored) and never block a run.
- **Commit / push / submit fails** → leave the worktree intact, report its path so work is
  recoverable; do not teardown.
- **`git worktree remove` fails** (residual changes) → report; do not force-remove silently (the
  user may have uncommitted work). Suggest `git worktree remove --force` explicitly.
- **`base_branch` resolves empty** (no config, no remote) → fall back to `main`; never error out of
  the run.
- **Host cannot create worktrees** → out of scope to auto-degrade; document the limitation in the
  contract.
- **Graphite unavailable** → raw-git fallback path (`gh pr create --base <parent>`); never block.

## 7. Acceptance criteria

Each AC is a testable behavior → ≥1 plan task. Several ACs are doc-shaped (this is a skills repo);
those are verified by grep/presence assertions and the existing init script-test harness.

- **AC1 — Canonical contract exists and is linked, not duplicated**
  - happy: `skills/woostack-init/references/worktrees.md` exists and defines lifecycle, location,
    invariant, base-branch resolution, stacked-PR `base-ref` rule, memory/metrics→primary, caveats.
  - error: bootstrap/build/execute/fix/commit each **link** the contract; none restates the
    `git worktree` command sequence inline (grep: at most the contract file contains the canonical
    command block).
  - edge: `gt`-less raw-git fallback is documented in the contract.
- **AC2 — gitignore template ignores worktrees**
  - happy: `skills/woostack-init/templates/gitignore` contains `worktrees/`.
  - error: `test-gitignore-template.sh` asserts it (test added) and passes via `run-tests.sh`.
  - edge: a worktree checkout does not re-track `.woostack/worktrees/` (covered by it being ignored).
- **AC3 — Base branch is configurable with the defined resolution order (shared resolver)**
  - happy: `resolve-base.sh` with `config.base_branch` set → emits that value; used as cut-from / PR
    `--base` / stack-base `base-ref`.
  - error: unset → emits `git symbolic-ref refs/remotes/origin/HEAD` branch name.
  - edge: unset + no remote → emits `main`. Verified by `test-resolve-base.sh` (RED-first) under
    `run-tests.sh`.
- **AC4 — No remaining hardcoded `staging` PR-base references**
  - happy: a repo-wide grep for `--base staging` / "from `staging`"-style PR-base wording in the
    skill docs returns only the resolution machinery, not literals.
  - error: `N/A — covered by AC3` (same change).
  - edge: legitimate non-PR-base mentions of `staging` (e.g. the branching-model *example* table)
    are allowed if they reference the configurable value.
- **AC5 — Worktree lifecycle is wired into build (step 7), execute (per-increment), fix (steps 5–6)**
  - happy: build/execute/fix instruct create-before-edit + teardown-after-commit, linking the
    contract.
  - error: **bootstrap is delegate-only** — it adds no create/teardown step; it exempts the initial
    scaffold (primary tree) and routes subsequent work to build/fix (which carry the lifecycle).
  - edge: `woostack-execute-overnight` mirrors the execute cadence.
- **AC6 — Stacked PRs survive worktree removal-after-commit**
  - happy: execute's `base-ref` for increment k is the increment k-1 branch (stack base uses
    resolved base branch); contract states branches persist past `git worktree remove`.
  - error: `gt track --parent` / `gh pr create --base <parent>` documented so PRs stack, not orphan.
  - edge: parallel disjoint stacks each submit only their own branches (no restack-all mid-run).
- **AC7 — Memory/metrics resolve to the primary tree**
  - happy: execute distill + metrics writes target the primary `.woostack/` (via
    `git rev-parse --git-common-dir`), documented in the contract and execute SKILL.
  - error: teardown after a mid-run distill does not strand memory (memory was written to primary).
  - edge: `N/A — local-only, no commit involved`.

## 8. Testing

> Strategy only — harness, test levels, fixtures, CI. Per-behavior cases live in §7.

This is a skills/docs collection, not an application; there is no app build/CI. Verification is:

- **Script tests** (`skills/woostack-init/scripts/tests/`, run via `run-tests.sh`): extend
  `test-gitignore-template.sh` for the `worktrees/` entry (AC2). Add a small focused test for the
  base-branch **resolution** if a shared shell helper is introduced (otherwise resolution is
  inline-jq documented in the contract and verified by grep/review).
- **Grep/presence assertions** for doc-shaped ACs (AC1, AC4, AC5): contract file present; skills
  link it; no remaining `--base staging` literals.
- **Manual walkthrough** (PR test plan, Before-merge): on a scratch repo, run a `woostack-fix` and a
  second `woostack-fix`/`woostack-build` concurrently; confirm two worktrees under
  `.woostack/worktrees/`, the primary tree stays clean on the base branch, each PR opens, and the
  worktrees are removed after commit. Confirm a `woostack-build` produces a Graphite stack
  (spec+plan ← increments) with correct PR bases after each increment's worktree is removed.

## 9. Open questions

All resolved during harden (2026-06-10); recorded here as settled decisions:

- **`base_branch` resolution mechanism** → **shared sourced helper** `resolve-base.sh` +
  `test-resolve-base.sh`, mirroring `resolve-root.sh`. DRY, testable, gives AC3 an executable test.
  (§4.5)
- **`gt submit` scope** → submit only the **current branch's own (disjoint) stack**; never
  `gt sync` / restack-all mid-run. Cross-run safety from not running repo-wide sync/restack while a
  parallel run is in flight. (§4.6)
- **Worktree dir slug** → reuse the `branch:` name verbatim with `/` → `-` (1:1 dir ↔ branch). (§4.4)
- **Memory/metrics → primary tree** → driving skill **exports `WOOSTACK_ROOT`** (primary root,
  computed at run start) so the existing `resolve-root.sh` override anchors distill/metrics to the
  primary `.woostack/` from any cwd — **no shared-script change**. (§4.7)
- **Subagent-mode cwd** → controller creates the worktree and dispatches implementers with cwd = that
  worktree; tasks stay sequential within an increment. (§4.6)
- **Bootstrap depth** → **delegate-only**: base-branch config + initial-scaffold exemption + route
  subsequent work to build/fix; no create/teardown step in bootstrap. (§5)

Resolved during **plan** harden (2026-06-10):

- **Where `.woostack/` artifacts live** → **in the worktree** (not the primary tree). A run creates
  its worktree on the first file write and runs with **cwd = worktree** so spec/plan/fix markdown +
  code are all authored there; the primary tree stays pristine (only local-only memory/metrics go to
  it, via `WOOSTACK_ROOT`). **Consequence (by design):** `/woostack-status` shows only merged /
  base-branch state, never worktree WIP — no status change in scope. (§4.3)

No new questions remain — the artifact is hardened.
