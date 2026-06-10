---
type: fix
status: in-review
branch: fix/fix-delegate-to-execute
---

# Fix: woostack-fix inlines execution instead of delegating to woostack-execute

## 1. Root Cause

`woostack-fix` re-implements plan execution inline instead of delegating to the canonical
execution engine, `woostack-execute`. The duplication originates in three places in
`skills/woostack-fix/SKILL.md`:

- **Step 5 ("Execute")** spells out its own TDD loop (`failing test → minimal fix → verify →
  tick checkboxes`) and its own branch creation. This is a weaker copy of
  `woostack-execute`'s per-increment cadence.
- **Step 6 ("Commit and PR")** invokes `woostack-commit` directly — but `woostack-execute`
  already owns per-increment commit via `woostack-commit`.
- **Step 7 ("Distill Memory gotchas")** runs its own distill pass — but `woostack-execute`
  already owns per-increment distill into `.woostack/memory/`.

Evidence: `grep "woostack-execute" skills/woostack-fix/SKILL.md` returns **no matches** — the
fix loop never references the execute engine at all, even though `woostack-execute` is the
documented owner of "implement each increment with TDD, tick checkboxes in place, commit via
woostack-commit, review each task, distill, never merge."

Consequences of the inline copy:
- **No task-scoped review.** Fix's inline step 5 has no spec-compliance / code-quality check;
  `woostack-execute` adds that review loop to every increment. Fixes ship unreviewed.
- **Drift risk.** Two copies of the execution cadence (branch-before-edit, TDD kernel, tick,
  commit, distill, never-merge) diverge over time. The recent
  `2026-06-09-inline-execute-quality-checks` fix already had to patch execute's cadence; fix's
  inline copy was not updated in lockstep.

This mirrors the dependency-internalization pattern: `woostack-build` step 9 delegates execution
to `woostack-execute` and "absorbs what used to be separate distill memory and offer the PR
steps." `woostack-fix` should do the same.

This is a skill-documentation/design change (Mode A), not a runtime bug, so the "test" is a
text/grep assertion over the skill Markdown rather than a unit test.

## 2. Proposed Fix

Rewrite `skills/woostack-fix/SKILL.md` so the execute phase **delegates** to
`woostack-execute`, passing the fix file as the plan. Fold the now-redundant commit and distill
steps into that delegation (exactly as `woostack-build` step 9 folds them).

Resulting procedure (7 steps → 6 steps):

1. Diagnose (unchanged)
2. Write fix plan (unchanged)
3. Harden (unchanged)
4. Approve — GATE (unchanged; fix's one gate stays upstream of delegation)
5. **Execute via `woostack-execute`** — set `status: executing`, invoke
   `/woostack-execute .woostack/fixes/<file>.md --inline`. The fix file's
   `## 3. Implementation Plan` is the single increment. `woostack-execute` owns the cadence:
   branch-before-edit, TDD per task (failing test → minimal fix → verify), tick the fix file's
   checkboxes in place, commit via `woostack-commit`, run the task-scoped spec-compliance +
   code-quality review, and distill durable learnings. Default `--inline` for this lightweight
   loop (a fix is one increment / one PR); `--subagent` available for a larger fix.
6. **Track PR & lifecycle** — no separate commit step (execute committed in step 5). Once the
   PR is open, set `status: in-review` (`done` once merged). The fix file's frontmatter
   `status:` stays the lifecycle source of truth; `woostack-commit` writes the
   `Spec: .woostack/fixes/<file>.md` trailer.

Cross-doc accuracy:
- Update the frontmatter `description` (drop "execute via TDD, and commit via woostack-commit" →
  "execute via woostack-execute").
- Update the Overview flow diagram.
- Update the Hard constraints: replace nothing essential; add a **Delegate execution**
  constraint and keep TDD-kernel / wait-for-approval / one-file / no-guess-and-check /
  never-merge.
- Update `.claude/CLAUDE.md` quick-file-map line 99
  (`diagnose → fix plan → approve → TDD → commit`) to reflect delegation.

### Design decisions resolved during hardening

- **Default driver = `--inline`.** A fix is small / single-increment; inline is the lightweight
  fit. `--subagent` stays available for larger fixes. (Rather than letting execute take its
  smart default, fix names `--inline` so the lightweight loop is the documented default.)
- **Fold steps 6 & 7 into delegation.** Execute owns commit + review + distill, so fix must not
  re-inline them — same as build step 9. The only post-execute work fix retains is the
  frontmatter lifecycle transition (`executing` → `in-review` → `done`), which execute does not
  touch (execute ticks checkboxes, not fix frontmatter).
- **Preserve the root-cause gotcha distill intent.** Execute's distill is reject-by-default and
  generic; a fix's distinctive value is the debugging gotcha from step 1. Step 5 notes that the
  fix's distill should capture the root-cause gotcha learned in diagnosis.
- **Fix file IS the plan for execute's purposes.** `woostack-execute` reads the named Markdown
  file and ticks its checkboxes; it does not hard-require the `.woostack/plans/` directory or a
  `**Source:**` line. Passing `.woostack/fixes/<file>.md` works; its `## 3. Implementation
  Plan` is the single increment.
- **Status ownership stays with fix.** Fix sets `executing` before delegating and
  `in-review`/`done` after; execute owns no frontmatter and no approval gate, so no conflict.

## 3. Implementation Plan

- [x] **Step 1: Reproduce with a failing text check**
  - Run `grep -n "woostack-execute" skills/woostack-fix/SKILL.md` and confirm it returns no
    matches (the fix loop never references the execute engine — RED).
  - Confirm the inline-execution markers are present: step 5 "Work through the implementation
    plan tasks in order using TDD", the standalone `/woostack-commit` step 6, and the
    standalone distill step 7.

- [x] **Step 2: Apply the minimal documentation fix**
  - Edit `skills/woostack-fix/SKILL.md`:
    - Frontmatter `description`: replace "execute via TDD, and commit via woostack-commit" with
      "execute via woostack-execute (which commits via woostack-commit and reviews each task)".
    - Overview flow diagram: change the execute leg to delegate to `woostack-execute`.
    - Step 5: replace the inline TDD/branch block with a delegation to
      [`woostack-execute`](../woostack-execute/SKILL.md) (`--inline` default), describing that
      execute owns branch / TDD / tick / commit / review / distill, and noting the root-cause
      gotcha distill intent.
    - Step 6: restate as PR/lifecycle tracking only (no separate commit); fold old step 7
      (distill) into the step-5 delegation note.
    - Hard constraints: add **Delegate execution** (step 5 hands the fix file to
      `woostack-execute`; do not re-inline a TDD/commit/distill loop); keep TDD-kernel,
      wait-for-approval, one-file, no-guess-and-check, never-merge.
  - Edit `.claude/CLAUDE.md` quick-file-map line 99 to reflect delegation
    (`diagnose → fix plan → approve → execute (woostack-execute) → PR`).

- [x] **Step 3: Verification**
  - `grep -n "woostack-execute" skills/woostack-fix/SKILL.md` now returns matches incl. the
    `../woostack-execute/SKILL.md` cross-link (GREEN).
  - `grep -n "Work through the implementation plan tasks in order using TDD" skills/woostack-fix/SKILL.md`
    returns no matches (inline loop removed).
  - The `../woostack-execute/SKILL.md` cross-link target exists.
  - Step numbering is consistent (6 steps) and the Overview flow / description match the body.
  - `.claude/CLAUDE.md` line for the fix loop no longer says the inline `TDD → commit` shape.
