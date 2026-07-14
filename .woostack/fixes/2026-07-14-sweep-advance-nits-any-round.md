---
type: fix
status: in-review
branch: fix/sweep-advance-nits-any-round
---

# Fix: Sweep advances approved-with-nits verdicts on every round

## 1. Root Cause

`woostack-sweep` is a prose-executed state machine whose verdict and termination ordering is
underspecified when a review returns on the final allowed round.

The normal transition in `skills/woostack-sweep/SKILL.md` classifies a fresh, receipt-backed
`STATUS_LINE`: `APPROVED` / `APPROVED WITH SUGGESTIONS` advances as `clean` when no threads remain,
or takes one address/restack pass and advances as `done-with-findings` when only non-blocking
threads remain. Separately, `## Termination backstop` says the round cap and no-progress guard stop
the loop "whichever trips first" without stating that the newly returned verdict is classified
before either backstop.

That ambiguity appears only when conditions coincide. On round 1 or a later pre-cap round, only the
verdict transition is eligible, so a no-blocking verdict advances. On the final allowed round, both
the fresh no-blocking verdict and `max_rounds` become eligible. The current text therefore permits a
cap-first interpretation even though the section later asserts that a no-blocking verdict never
reaches a terminus. The no-progress guard has the same ordering dependency: it may stop only after
the latest receipt-backed verdict has first been classified and found still blocking.

This is a real contract gap, not a review-engine defect:

- `woostack-review` produces `STATUS_LINE` from the current review's finding counts and has no
  sweep-round or cap state.
- `woostack-address-comments` handles threads but returns no sweep-round verdict.
- The sweep's existing contract test covers receipt/self-review behavior only. The baseline command
  `bash skills/woostack-sweep/scripts/tests/run-tests.sh` passes `4 passed, 0 failed`, while a search
  finds no rule for "final allowed round," classifying the fresh verdict before cap/no-progress, or
  equivalent ordering. The passing suite therefore does not protect the requested all-round
  transition.

The root cause is one missing precedence rule at the sweep's shared verdict/termination boundary,
not separate bugs in individual rounds.

## 2. Proposed Fix

Define verdict-first ordering once in `skills/woostack-sweep/SKILL.md`:

- After every `woostack-review --full`, including the final allowed round, first validate the review
  receipt for the current HEAD and classify the fresh `STATUS_LINE`.
- Any no-blocking verdict follows the existing round-independent transition: zero threads advances
  as `clean`; open non-blocking threads take one address/restack pass and advance as
  `done-with-findings` without re-review.
- Only when the latest receipt-backed verdict still has blocking findings may the no-progress guard
  or `max_rounds` stop the PR as `blocked`.

Anchor the rule at the shared per-PR transition and make the termination backstop and hard constraint
refer to the same ordering. Do not special-case round one, middle rounds, or the final round; do not
change review verdict generation, addressing, configuration, outcomes, callers, or authored site
pages. This preserves receipt-before-clean, the blocking-only cap/guard, bottom-up traversal, and
the existing one-pass tradeoff for non-blocking findings.

## 3. Implementation Plan

- [x] **Step 1: Reproduce with a failing contract test**
  - Add `skills/woostack-sweep/scripts/tests/test-round-verdict-contract.sh` using the existing
    fixed-string assertion helpers.
  - Pin the observable state-machine contract: every fresh receipt-backed verdict, including one
    returned on the final allowed round, is classified before cap/no-progress; a no-blocking verdict
    advances through the existing `clean` or `done-with-findings` branch; termination is legal only
    while the latest verdict remains blocking.
  - Cover first-round, later pre-cap, and final-round no-blocking outcomes plus final-round blocking
    and blocking no-progress. Keep the existing missing-receipt contract unchanged.
  - Run `bash skills/woostack-sweep/scripts/tests/run-tests.sh` and confirm the new assertions fail
    against the current skill text.

- [x] **Step 2: Apply the minimal ordering fix**
  - Update `skills/woostack-sweep/SKILL.md` at the shared verdict boundary to require receipt
    validation and fresh-verdict classification before any cap/no-progress evaluation on every
    round, explicitly including the final allowed round.
  - Clarify `## Termination backstop` so cap/no-progress can terminate only after the latest verdict
    remains blocking.
  - Restate the precedence tersely in `## Hard constraints` so future edits cannot reintroduce
    round-dependent behavior.

- [x] **Step 3: Verification**
  - Re-run `bash skills/woostack-sweep/scripts/tests/run-tests.sh`; all receipt and round-ordering
    contract assertions must pass.
  - Search `skills/woostack-sweep/SKILL.md` for the ordered transition and confirm no clause permits
    cap/no-progress evaluation before classification of the latest verdict.
  - Review the final diff for scope: only the sweep skill, its contract test, the fix lifecycle file,
    and execution-owned memory/checklist updates may change; no caller or site-doc wording should be
    duplicated because the external outcome vocabulary and configuration are unchanged.
