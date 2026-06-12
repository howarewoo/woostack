---
type: fix
status: in-review
branch: fix/overnight-sweep-cap-nits
---

# Fix: Overnight review-sweep cap halts on approved-with-nits

## 1. Root Cause

The post-implementation **review sweep** in
[`skills/woostack-execute-overnight/SKILL.md`](../../skills/woostack-execute-overnight/SKILL.md)
treats **any not-clean PR at the cap as a blocker**, regardless of *why* it is not clean.

- **"Clean?" (per-PR loop step 2)** = woostack-review verdict has **no blocking findings**
  (`APPROVED` / `APPROVED WITH SUGGESTIONS`) **AND zero unresolved threads**.
- **Termination backstop** ends the per-PR loop at `max_rounds` **or** the no-progress guard, then:
  *"Either, without a clean PR, is a blocker → halt."*
- **Halt** lists `cap-without-clean` as a sweep blocker → **ends that track's remaining sweep**
  (blocked PR recorded `blocked`, every PR above → `not-attempted-review`) and advances to the next
  track. For the default single-track plan, that halts the rest of the stack.

This conflates two end-states at the cap:

1. **Blocking findings still present** (verdict is request-changes) — genuinely unsafe to stack more
   work on → halt is correct.
2. **No blocking findings, only unresolved *nit* threads** (verdict `APPROVED` /
   `APPROVED WITH SUGGESTIONS` + open non-blocking suggestion threads) — safe; the PR is approved.
   Because "clean" also requires *zero* unresolved threads, a few leftover nits at the cap fail the
   clean check and trip the **same** halt as a request-changes blocker.

**Evidence:** SKILL.md §"Termination backstop" (`Either, without a clean PR, is a blocker → halt`)
and §"Halt" (`A sweep blocker — cap-without-clean, …`). Neither branches on the verdict's blocking
status — only on the binary clean/not-clean. The vocabulary to distinguish them already exists:
"no blocking findings" (`APPROVED` / `APPROVED WITH SUGGESTIONS`) vs blocking (request-changes), and
a `done-with-findings` per-increment status is already defined in §"Morning report".

The per-increment early check (**Autonomy override #2**) is **already correct** — it halts only when
*"Still blocking after the cap"* (keyed to blocking, not to nits) — so this fix is scoped to the
**sweep**, which is what "continue to the next PR" refers to.

## 2. Proposed Fix

Classify by the **verdict's blocking status**, and treat **below-cap** and **at-cap** differently —
nits keep the loop running until the cap, and only at the cap do nits let the sweep move on.

**Below the cap (rounds remain):**
- **Blocking findings** with no progress (a re-review returns the **same blocking findings** as the
  prior round, or `address-comments` makes no headway on a **blocking** thread) → **blocker → halt**
  (churning a stuck blocker is futile — unchanged in spirit, but now scoped to *blocking*).
- **Only nits left** (`APPROVED` / `APPROVED WITH SUGGESTIONS`, open non-blocking threads) → **keep
  reviewing/addressing** — do **not** let the no-progress guard early-terminate on nits. Spend the
  remaining rounds trying to clear them, bounded by `max_rounds`.

**At the cap (`max_rounds` reached) without a clean PR:**
- **Blocking findings remain** (request-changes) → **blocker → halt** that track (unchanged).
- **Only nits remain** → **not a blocker**: mark the PR `done-with-findings`, record the open nits in
  the morning report (test checklist / "Needs you" as *address-in-morning*, distinct from a blocker),
  and **move on to the next PR** (sweep continues upward; track proceeds normally).

Net: the **no-progress guard is re-scoped to blocking findings only** (no early stop on nits), and
the **`max_rounds` cap** is where nits-only converts to `done-with-findings` + continue rather than a
halt.

Prose-only edits to `skills/woostack-execute-overnight/SKILL.md` (no code/scripts; this repo has no
app test runner). Sites:

1. **§"The per-PR loop" — "Strictly bottom-up" closing line** (~L165): a PR moves up when it reaches
   **clean *or* approved-with-nits-at-cap**, not only clean.
2. **§"Termination backstop"** (~L170–178): (a) re-scope the **no-progress guard** to **blocking
   findings** — "resolves no thread" / "same findings" / "`CLARIFY` leaves a thread open" trip an
   early stop only when the unresolved item is **blocking**; when only nits remain, keep looping to
   the cap. (b) Replace *"Either, without a clean PR, is a blocker → halt"* with the at-cap split:
   blocking remains → halt; nits-only → `done-with-findings` + move on.
3. **§"Halt"** (~L182): scope the `cap-without-clean` / no-progress blocker triggers to **blocking
   findings still present**; state explicitly that approved-with-nits at the cap is **not** a sweep
   blocker.
4. **§"Morning report"** (~L207–211): note that cap-reached-with-only-nits PRs are
   `done-with-findings`, surfaced in the test checklist as *address nits in the morning*, separate
   from blockers.
5. **Hard constraint "Drive the stack to clean review"** (~L244): clarify that hitting the cap with
   only nits is not a blocker — only blocking findings at the cap halt the track.
6. **§"Terminal state"** (~L217): a track now **completes** when every PR is clean **or**
   approved-with-nits-at-cap (no blocking findings remain anywhere); it **halts** only on a blocking
   blocker. Update the "swept to a clean review **or** halted" dichotomy to admit the
   `done-with-findings` terminus.

## 3. Implementation Plan

- [x] **Step 1: Pin current behavior with a failing concrete check (no-runner verification)**
  - Add a grep-based assertion (run in the fix's verification step, not a committed test file — this
    repo ships no test runner) capturing that **after** the fix the SKILL.md:
    - **no longer** contains the unconditional `without a clean PR, is a blocker` phrasing,
    - **does** distinguish blocking-vs-nits at the cap (e.g. matches both `done-with-findings`
      *within the sweep terminus prose* and a "blocking findings" condition on the halt), and
    - **does** scope the no-progress guard to blocking (below-cap nits keep looping, not an early
      halt).
  - Before editing, confirm the assertion **fails** against the current file (the distinguishing
    prose is absent) — this is the Red step.

- [x] **Step 2: Apply the minimal prose fix**
  - Edit the **six** sites in `skills/woostack-execute-overnight/SKILL.md` per §2 so the sweep
    terminus branches on the verdict's blocking status at the **unified** terminus (cap *or*
    no-progress): request-changes → halt; approved-with-nits → record nits + `done-with-findings` +
    continue upward.
  - Keep edits surgical; do not touch Autonomy override #2 (already correct) or the `Config` /
    `max_rounds` mechanics.

- [x] **Step 3: Verification**
  - Re-run the Step-1 grep assertion — now **passes** (Green).
  - Re-read the edited sections end-to-end for internal consistency: §"Terminal state" still holds
    ("clean or halted"), but the per-track halt no longer fires on nits-at-cap; the
    `done-with-findings` status is consistent between the sweep prose and the morning-report table.
  - Confirm no other skill cross-links assume "cap-without-clean ⇒ always blocker"
    (`grep -rn "cap-without-clean\|without a clean PR" skills/`).
