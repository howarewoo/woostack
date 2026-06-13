---
type: fix
status: in-review
branch: fix/subagent-cwd-pin
---

# Fix: Subagent driver can't honor the worktree contract on cwd-less spawn hosts

## 1. Root Cause

The worktree contract defines subagent-mode isolation **purely in terms of a controller-set
cwd**. `woostack-init/references/worktrees.md` §2 (Operate):

> In subagent mode the controller dispatches implementers with cwd = `$wt`.

The subagent driver (`woostack-execute/references/subagent-driver.md` → Per-task loop step 1)
and the implementer prompt (`woostack-execute/prompts/implementer.md`) inherit that assumption:
neither passes `$wt` into the dispatch nor makes the implementer **self-assert** its location.
They assume the host's spawn primitive exposes a per-call `cwd`.

On a cwd-less spawn host this is unsatisfiable. Concrete host: Claude Code's `Agent` tool — its
spawn schema is `subagent_type | model | prompt | isolation | run_in_background`, **no `cwd`**.
The two reachable behaviors both violate the contract:

1. **Inherit parent cwd** → the implementer runs in the **primary checkout** (on the protected
   base branch). Any write there violates §3 ("the primary tree is never edited") and dirties the
   tree every parallel run branches from.
2. **`isolation: "worktree"`** → the host makes a *fresh throwaway* worktree, **not** the
   controller's tracked per-PR branch worktree (`$wt`, created + `gt track --parent <base>`).
   Commits land on a detached/unintended worktree, not the PR branch.

Nothing in the dispatch path asserts "I am in `$wt`," so the failure is **silent**: a dispatched
implementer can edit the protected primary `staging`/`main` checkout with no abort. The smart
default resolves to subagent (the host *can* spawn agents), but the driver then can't faithfully
place those agents — forcing an inline fallback that loses the subagent driver's
isolation/parallelism.

**Root cause:** isolation depends on a controller-set cwd that cwd-less spawn hosts cannot
provide, and no host-independent self-pin guard exists as a substitute.

## 2. Proposed Fix

Adopt the issue's Fix #1 (portable — removes the blocker without the host gaining a `cwd` param),
plus the Fix #2 capability/fallback documentation and the Fix #3 host-guidance note.

Make the implementer **self-pin** to `$wt` as its first action, and have the controller **always**
fill that pin (and additionally set a per-call cwd when the host supports one — belt-and-suspenders):

- **`prompts/implementer.md`** — add a "Worktree pin (do this first)" block, placed **before
  `## Task`** (must precede any write), with a `<worktree absolute path — $wt>` placeholder. The
  implementer's first action: `cd` into it, then a hard `git rev-parse --show-toplevel` assertion
  that **aborts before any write** if the toplevel isn't `$wt`. So a cwd-less host can run subagent
  mode safely — the implementer can never write to the primary tree. **Normalize the compare**
  (`pwd -P` vs `git rev-parse --show-toplevel`, both resolved) so a symlinked path (e.g. macOS
  `/var`→`/private/var`) doesn't spuriously abort a correct run; the dangerous direction
  (pass while in the wrong tree) stays impossible either way:

  ```bash
  cd "<worktree path — $wt>" || exit 1
  want="$(pwd -P)"                         # resolved cwd (the worktree root we just entered)
  have="$(git rev-parse --show-toplevel)"  # resolved git toplevel
  [ "$have" = "$want" ] || { echo "ABORT: git toplevel $have != worktree $want"; exit 1; }
  ```
- **`references/subagent-driver.md`** — Per-task loop step 1: instruct the controller to resolve
  `$wt`, fill the prompt's pin placeholder with it, and set the spawn call's `cwd = $wt` **when the
  host's API exposes a per-call cwd**. Add a "Worktree placement" capability note: per-call-cwd
  host → set it (guard double-checks; belt-and-suspenders); cwd-less host → the prompt guard
  self-pins (the portable path); `isolation:"worktree"` is **not** a substitute (fresh throwaway
  worktree, not the tracked PR branch). A host that can neither set cwd nor run the self-pin shell
  guard cannot run the plan's TDD/verification either, so it's the same class as "no test harness"
  → fall back to inline (say so, degraded — never pretend).
- **`woostack-init/references/worktrees.md`** §2 — amend the "controller dispatches implementers
  with cwd = `$wt`" sentence to describe the per-call-cwd path **and** the always-on dispatch-prompt
  self-pin guard, and the `isolation:"worktree"`-is-not-a-substitute host guidance.
- **`woostack-execute/SKILL.md`** (Per-increment cadence step 1) — amend "(dispatched with **cwd =
  the worktree**)" to reflect cwd-where-supported, else self-pinned by the dispatch-prompt guard.

`woostack-execute-overnight` reuses the same driver + contract files, so the central edit covers
both its `--subagent` and smart-default paths — no overnight-specific change needed.

## 3. Implementation Plan

- [x] **Step 1: Reproduce with a failing structural check**
  - Add a grep-based verification (the no-runner concrete check) asserting the guard exists, e.g.
    `git rev-parse --show-toplevel` appears in `prompts/implementer.md` and the
    `isolation`-not-a-substitute guidance appears in `subagent-driver.md`. Watch it fail
    (pre-edit) so the fix is test-anchored.
- [x] **Step 2: Apply the dispatch-prompt pin + guard to `prompts/implementer.md`**
  - Insert a "Worktree pin (do this first)" block **before `## Task`** with the `<worktree path —
    $wt>` placeholder and the normalized `pwd -P` vs `git rev-parse --show-toplevel` assertion,
    abort-before-any-write semantics.
- [x] **Step 3: Document placement + capability fallback in `references/subagent-driver.md`**
  - Per-task loop step 1: controller resolves `$wt`, fills the pin, sets per-call cwd where
    supported. Add the "Worktree placement" capability note (per-call-cwd / cwd-less self-pin /
    `isolation` not-a-substitute / inline last resort).
- [x] **Step 4: Amend the contract + cadence cross-references**
  - `worktrees.md` §2 Operate sentence and `woostack-execute/SKILL.md` cadence step 1 parenthetical.
- [x] **Step 5: Verification**
  - Re-run the Step 1 grep checks (now passing). Run `woostack-init`'s `doctor.sh` to confirm the
    store still lints clean. Confirm no other file restates the amended contract sentence
    (`grep -rn "dispatches implementers with cwd"`).
