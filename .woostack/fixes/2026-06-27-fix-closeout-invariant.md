---
type: fix
status: executing
branch: fix/fix-closeout-invariant
---

# Fix: Make woostack-fix closeout mandatory

## 1. Root Cause

`woostack-fix` already says a successful fix should update the single PR, set the
fix lifecycle to `in-review`, and tear down the worktree. However, those duties are
buried in step 6 as lifecycle tracking after step 5 delegates execution to
`woostack-execute`. The skill does not state a clear completion invariant that
forbids final handback immediately after implementation/tests.

Evidence:

- Step 5 emphasizes that `woostack-execute` commits the code and opens or updates
  the one PR, which can make the flow appear finished once tests pass.
- Step 6 contains the required lifecycle and teardown behavior, but its heading is
  “Track the PR and lifecycle,” not a mandatory closeout gate.
- The hard constraints say to delegate execution and never merge, but they do not
  explicitly define “done” as PR submitted, fix status committed as `in-review`,
  and the worktree removed.

## 2. Proposed Fix

Update `skills/woostack-fix/SKILL.md` so a successful run has an explicit closeout
invariant: after approved execution succeeds, the agent must not final-answer until
the PR is submitted or updated, the fix file is marked `in-review`, that lifecycle
update is committed/submitted, and the fix worktree is torn down. Keep failure
behavior unchanged: leave the worktree in place and report its path when commit,
submit, review, or teardown cannot complete.

If the authored docs page mirrors this wording, update
`site/content/docs/skills/woostack-fix.mdx` in the same change.

## 3. Implementation Plan

- [x] **Step 1: Reproduce with a failing documentation check**
  - Add a lightweight shell test that asserts `skills/woostack-fix/SKILL.md`
    contains a “Completion invariant” section and the mandatory closeout terms:
    submit/update PR, `in-review`, commit/submit lifecycle update, and remove the
    worktree.
- [x] **Step 2: Apply the minimal fix**
  - Add the completion invariant near the top of `skills/woostack-fix/SKILL.md`
    so it is visible before the detailed procedure.
  - Rename or strengthen step 6 so closeout cannot be read as optional tracking.
  - State the failure exception explicitly: if closeout cannot commit, submit, or
    tear down, leave the worktree and report the blocker/path.
  - Mirror the authored docs page only where it is manually maintained and affected.
- [x] **Step 3: Verification**
  - Run the new documentation check.
  - Run `pnpm -C site build` if the authored docs page changes.
