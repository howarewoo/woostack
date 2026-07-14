---
type: fix
status: executing
branch: fix/sweep-continue-on-nits
---

# Fix: Sweep advances on a nits-only verdict instead of looping to the cap

## 1. Root Cause

`woostack-sweep`'s per-PR loop treats **any open thread** — blocking or nit — as
"not clean," so a PR whose only remaining findings are nits is forced back through the
bounded `woostack-review --full` → `address-comments` → restack → **re-review** loop until it
either becomes fully clean (zero unresolved threads, receipt-backed) or trips the
`review_sweep.max_rounds` cap. The skill states this explicitly:

- `skills/woostack-sweep/SKILL.md` L86-88: "a PR is driven to clean — **or, at the
  `max_rounds` cap, to approved-with-only-nits** — before the sweep moves up."
- L98-99 (no-progress guard): "**Nits never trip this guard — while only non-blocking nits
  remain, keep reviewing/addressing them until the `max_rounds` cap.**"
- L105-107 (termination): "Only nits remain … **reachable only at the `max_rounds` cap**,
  since the guard never stops on nits → not a blocker: mark the PR `done-with-findings`,
  record the open nits, and move to the next PR up."
- L173 (hard constraint): "**nits loop to the cap**; only blocking findings at the cap are a
  blocker."

Consequence: a nits-only PR keeps burning expensive full re-reviews (each round is
`woostack-review --full`, L65-66) purely to chase non-blocking suggestions, and only advances
to the next PR once the cap is reached. The user wants the sweep to address the nits **once**
and then continue to the next PR — not loop them to the cap.

The root cause is that nit handling is coupled to the same bounded loop as blocking findings.
`max_rounds` exists to bound *blocking* churn (a request-changes fix that may not converge);
nits, being non-blocking suggestions, do not need iterative re-review to converge — one address
pass is enough before moving on.

## 2. Proposed Fix

Decouple nit handling from the `max_rounds` loop. Read the `woostack-review --full` verdict; the
verdict drives two paths:

- **Blocking findings present** (`REQUEST CHANGES` / request-changes `STATUS_LINE`): unchanged —
  loop `review --full` → address → restack → re-review, bounded by `max_rounds` + the
  blocking-only no-progress guard. At the cap with blocking findings still present → `blocked`.
- **No blocking findings** (`APPROVED` / `APPROVED WITH SUGGESTIONS`):
  - **Zero unresolved threads** → `clean` (receipt-backed for this HEAD) → advance. Unchanged.
  - **Open nit threads** → run **one** `woostack-address-comments` pass (fix / push back / reply
    / resolve / push via `woostack-commit`), **restack this stack only** so the PRs above rebase
    onto the new tip, then **advance to the next PR up** as `done-with-findings` (record the nits
    addressed and any deliberately left open). **No further nit re-review.**

Net effect: the bounded review→address→re-review loop now iterates **only while blocking
findings remain**; the `max_rounds` cap can therefore only ever produce `blocked`. A nits-only
verdict resolves in a single address pass and the sweep continues. The `clean` /
`done-with-findings` / `blocked` per-PR vocabulary is unchanged — `done-with-findings` simply
becomes reachable as soon as a no-blocking verdict appears (after one address pass), not only at
the cap.

**Invariants preserved.**

- *Receipt before clean* (L53-63, L166-169) is untouched: a PR is `clean` **only** with a real
  `woostack-review --full` receipt for its HEAD. After the nit address pass the HEAD SHA changes
  and has no fresh receipt, so the PR advances as `done-with-findings`, never a synthesized
  `clean`.
- The no-progress guard stays **blocking-only** (it already is); only its "nits loop to the cap"
  clause is replaced by "nits get one address pass, then advance."
- Bottom-up, each PR reviewed once on the way up; a fix restacks only the PRs above it; never
  merge, never force-push a protected base, never edit the primary tree.

**Tradeoff (deliberate, matches the request).** Advancing after a single nit address pass skips
a confirming re-review of that PR, so a nit fix that regressed something outside its own diff
would not be re-caught by the sweep. This is the explicit intent — stop spending expensive
`--full` rounds on non-blocking suggestions — and is bounded by the fact that nit fixes are
low-risk by definition. **Hardening decision (settled): no confirming re-review** — advance
directly after the single address pass, per the request.

**Callers / docs to reconcile** (they currently restate the "nits at the cap" coupling):

- `skills/woostack-execute-overnight/SKILL.md` L166-167, L191-193, L207-209 — replace the
  "reaching the `max_rounds` cap with only nits" phrasing with cap-independent
  `done-with-findings` wording, deferring loop mechanics to `woostack-sweep` per its own L154-156
  "do not restate them here."
- `skills/woostack-execute-overnight/references/report-template.md` L37, L43 — the `nits-at-cap`
  sweep-reason token becomes `nits-addressed` (nits no longer tie to the cap).
- `site/content/docs/configuration.mdx` L281 — `max_rounds` now bounds the loop before the sweep
  declares a PR `blocked` (the cap no longer produces the nits outcome).

## 3. Implementation Plan

- [x] **Step 1: Define the concrete verification (no test runner for Markdown)**
  - This is a documentation-behavior change in a skills collection; per the woostack-tdd kernel's
    "no-runner → concrete verification," pin the intended behavior as grep assertions that fail
    against the current text and pass after the edit:
    - `skills/woostack-sweep/SKILL.md` no longer contains "nits loop to the cap" or "reachable
      only at the `max_rounds` cap"; the no-progress guard's nits clause states nits get a single
      address pass then advance; the termination/loop text states a no-blocking verdict advances
      after one address pass.
    - Collection-wide grep finds no remaining "nits-at-cap" token and no "cap … only nits"
      coupling in `woostack-execute-overnight` or the site config page.
  - Run the grep assertions and confirm they currently fail (the phrases still present).

- [x] **Step 2: Apply the fix to `skills/woostack-sweep/SKILL.md`**
  - Per-PR loop / "Clean?" step: make explicit that a no-blocking verdict with open nit threads
    takes a single `address-comments` pass + restack, then advances (no re-review).
  - "Strictly bottom-up" paragraph (L86-88): drop "at the `max_rounds` cap" from the nits path.
  - No-progress guard (L98-99): replace the "keep reviewing/addressing them until the
    `max_rounds` cap" clause with the single-pass-then-advance rule.
  - Termination "Only nits remain" branch (L105-107): reachable as soon as a no-blocking verdict
    appears (after one address pass), not "only at the `max_rounds` cap."
  - Per-PR outcome vocabulary (L111) and hard constraints (L162-163, L172-173): update the
    parentheticals so `done-with-findings` / nits are no longer defined as "at the cap"; state the
    cap bounds only the blocking loop.

- [x] **Step 3: Reconcile the callers and docs**
  - `skills/woostack-execute-overnight/SKILL.md` L166-167, L191-193, L207-209 — cap-independent
    `done-with-findings` wording.
  - `skills/woostack-execute-overnight/references/report-template.md` L37, L43 — `nits-at-cap` →
    `nits-addressed`.
  - `site/content/docs/configuration.mdx` L281 — `max_rounds` bounds the loop before a PR is
    declared `blocked`.

- [x] **Step 4: Verification**
  - Re-run the Step 1 grep assertions; confirm they now pass.
  - `grep` the collection for any surviving "nits-at-cap" / "loop to the cap" / "only nits" cap
    coupling and confirm none remain (outside legitimate blocking-at-cap references).
  - `pnpm -C site build` to confirm the docs site still builds after the `configuration.mdx` edit.
