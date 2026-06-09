---
type: fix
status: in-review
branch: fix/inline-execute-quality-checks
---

# Fix: Inline execute uses PR-level review instead of task quality checks

## 1. Root Cause

`woostack-execute` has two execution drivers, but only the subagent driver owns the task-scoped
review loop:

- `skills/woostack-execute/SKILL.md` says inline mode's automated review is
  `woostack-review --fast`.
- `skills/woostack-execute/references/inline-driver.md` repeats that inline mode has no
  per-task reviewer loop and hands back to a PR-level `woostack-review --fast` gate.
- `skills/woostack-execute/references/subagent-driver.md` already defines the desired
  spec-compliance then code-quality loop using `prompts/spec-reviewer.md` and
  `prompts/quality-reviewer.md`.

The bad behavior originates in the inline driver documentation and the parent execute cadence,
not in the reviewer prompt files. A relevant local memory note also records that
`woostack-review --fast` can skip markdown-only skill-doc PRs, so it is the wrong quality gate
for inline execute in this skill collection.

## 2. Proposed Fix

Update the execute skill docs so inline mode uses the same review criteria as the subagent path,
adapted to the controller working inline:

- Replace inline references to `woostack-review --fast` with an inline task review loop.
- Define that loop in `references/inline-driver.md`: after each task, the controller checks the
  task diff against the spec-compliance criteria, fixes gaps, then checks the same diff against
  the code-quality criteria and fixes Important issues before ticking the task complete.
- Keep the subagent path unchanged except for any wording needed to clarify that both drivers now
  share the same spec and quality checks, while subagent mode still delegates them to fresh
  reviewer subagents with tier routing.
- Preserve the existing commit, distill, branch, and never-merge cadence.

## 3. Implementation Plan

- [x] **Step 1: Reproduce with a failing text check**
  - Run an `rg` check that fails while inline execute still names `woostack-review --fast` as
    its review path in `skills/woostack-execute/SKILL.md` or
    `skills/woostack-execute/references/inline-driver.md`.
  - Confirm the same search identifies all stale inline review references before editing.
- [x] **Step 2: Apply the minimal documentation fix**
  - Edit `skills/woostack-execute/SKILL.md` to describe inline review as the same
    spec-compliance plus code-quality task checks used by subagent mode, performed inline by the
    controller instead of dispatched to subagents.
  - Edit `skills/woostack-execute/references/inline-driver.md` to spell out the inline review
    loop and handback behavior.
  - Keep `skills/woostack-execute/references/subagent-driver.md` behavior intact unless a narrow
    cross-reference update is needed.
- [x] **Step 3: Verification**
  - Run `rg -n "woostack-review --fast|full review|PR-level automated review|per-task spec \\+ quality|spec\\+quality" skills/woostack-execute`.
  - Verify no inline-mode wording routes through `woostack-review --fast`.
  - Verify `skills/woostack-execute/SKILL.md` and `references/inline-driver.md` both state that
    inline mode uses spec-compliance and code-quality checks before ticking a task complete.
