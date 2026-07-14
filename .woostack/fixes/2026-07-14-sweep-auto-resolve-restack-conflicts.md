---
type: fix
status: executing
branch: fix/sweep-auto-resolve-restack-conflicts
---

# Fix: Sweep stops on expected restack conflicts

## 1. Root Cause

`woostack-sweep` classifies every restack/rebase conflict as a blocker by event type instead of checking whether the conflict can be resolved safely. `skills/woostack-sweep/SKILL.md` jumps from `gt restack` to a blanket blocker and contains no inspect, resolve, verify, stage, or `gt continue` transition.

This is reproducible in the preserved `feature-linear-artifacts-04-increments-sweep` worktree: `git status --short --branch` reported one `UU` path during the bottom-up restack, while `git diff --cc` showed a semantic combined result already present in the worktree. Graphite's installed help confirms that `gt restack` pauses in an interactive Git rebase and `gt continue` resumes the halted Graphite command. The current sweep contract therefore stops even when the only remaining operations are verifying, path-scoped staging, and continuing an expected descendant rebase.

The behavior originated in the overnight sweep design, which assumed every conflict required human judgment, and was preserved when the loop moved into `woostack-sweep`. `woostack-execute-overnight` only delegates and reports the sweep outcome; it is not the source of the behavior. Existing sweep contract tests cover review receipts and verdict ordering but do not cover conflict recovery.

## 2. Proposed Fix

Update the single sweep-loop contract in `skills/woostack-sweep/SKILL.md` so a paused stack-scoped restack enters a semantic conflict-resolution loop:

- enumerate every unmerged path and index stage with `git status --short`, `git ls-files -u`, and `git diff --cc`, and read the replayed change with `git rebase --show-current-patch`;
- preserve both the already-reviewed lower-PR fix and the descendant PR's intent rather than choosing `ours` or `theirs` wholesale, including rename/delete and non-text conflicts;
- run the smallest existing focused verification that covers every affected behavior before staging;
- stage only the verified conflict paths with `git add -- <paths>` and run `gt continue`, repeating the inspect/resolve/verify/continue cycle if later descendant commits conflict;
- run `gt submit --stack` only after the restack finishes, then continue the sweep.

The occurrence of a conflict is no longer a blocker. Block only when the conflict remains ambiguous or unsafe, no existing focused verification can establish the combined behavior, focused verification fails, `gt continue` fails, or the restack fails for another reason. Report the unresolved paths and failed command, and leave the paused worktree and rebase state intact. Never use blanket `ours`/`theirs`, `git add -A`, or `gt continue -a`, because they can discard one side's intent or stage unrelated worktree changes. Keep stack scoping, protected-base, no-merge, and primary-tree isolation invariants unchanged. The overnight report template retains `restack-conflict` for this narrowed unresolved-conflict outcome and needs no behavioral duplication.

## 3. Implementation Plan

- [x] **Step 1: Reproduce with a failing contract test**
  - Add `skills/woostack-sweep/scripts/tests/test-restack-conflict-contract.sh`.
  - Assert that restack conflicts enumerate unmerged paths and stages, inspect the replayed commit, resolve semantically, run focused verification, stage by explicit path, and resume with `gt continue` before `gt submit --stack`.
  - Assert that repeated descendant conflicts re-enter the same recovery loop, while only ambiguous, unsafe, unverifiable, verification-failing, continuation-failing, or otherwise unresolved conflicts block and preserve the worktree.
  - Assert that blanket side selection and blanket staging are forbidden, the old unconditional blocker sentence is absent, and the autonomous-resolution and stop-on-uncertainty boundaries survive in `## Hard constraints`.
  - Run `bash skills/woostack-sweep/scripts/tests/test-restack-conflict-contract.sh` and confirm it fails against the current contract.
- [x] **Step 2: Apply the minimal fix**
  - Replace the blanket restack-conflict blocker in `skills/woostack-sweep/SKILL.md` with the enumerate stages → inspect replayed intent → reconcile both sides → focused verification → path-scoped stage → `gt continue` loop.
  - Require repeated continuation until the stack-scoped restack completes, then submit the stack and continue the normal sweep; forbid blanket side selection and blanket staging.
  - Narrow the blocker definition and terminal behavior to conflicts the autonomous loop cannot resolve or verify safely, with exact failed-command reporting and preserved worktree/rebase state.
  - Restate the autonomous conflict-recovery boundary in `## Hard constraints` without duplicating the sweep loop in `woostack-execute-overnight`.
- [x] **Step 3: Verification**
  - Run `bash skills/woostack-sweep/scripts/tests/test-restack-conflict-contract.sh` and confirm it passes.
  - Run `bash skills/woostack-sweep/scripts/tests/run-tests.sh` and confirm all sweep contract tests pass.
  - Read the final restack step in sequence and confirm `gt submit --stack` occurs only after successful conflict continuation, while unresolved failures preserve the worktree.
