---
type: fix
status: in-review
branch: fix/overnight-sweep-downgrade
---

# Fix: woostack-execute-overnight driver can silently downgrade the review sweep (self-review instead of woostack-review --full)

Source issue: [#349](https://github.com/howarewoo/woostack/issues/349)

## 1. Root Cause

The post-implementation review sweep contracts a real `woostack-review --full` swarm, but that
requirement lives **only as descriptive prose** — there is no execution receipt, no pre-flight
feasibility gate, and no provenance on the emitted `clean` verdict. An autonomous overnight driver
can therefore run a structural/manual self-review and emit a `clean` that is **byte-identical** to a
swarm-derived clean, and nothing in either skill prevents or flags it.

This is the [[fanout-empty-needs-receipt]] ambiguity **one level up**: `woostack-sweep` aggregates
per-PR `clean` verdicts the way `woostack-review` aggregates per-angle findings — but only
`woostack-review`'s *inner* layer has a receipt gate (`verify-receipts.sh` + `receipt.<angle>.json`,
which hard-fail an angle that never ran). The *sweep* layer above it has **no equivalent receipt**,
so a "clean" PR is ambiguous: swarm-ran-clean vs review-never-ran/downgraded. Reinforced by
[[gate-needs-hard-barrier]]: a load-bearing requirement written only as soft loop prose gets skipped
by low-effort/fast drivers.

**Evidence / affected sites:**

- `skills/woostack-sweep/SKILL.md`
  - Per-PR loop steps 1–2 (the per-PR drive-to-clean loop): `clean` is computed from
    `woostack-review`'s `STATUS_LINE` with **no requirement that the verdict be proven
    woostack-review-derived** (no receipt). A driver can short-circuit the engine and still set the
    verdict.
  - Per-PR outcome vocabulary (`clean` / `done-with-findings` / `blocked`): carries **no
    provenance** — a downgraded clean and a real clean are the same token.
- `skills/woostack-execute-overnight/SKILL.md`
  - Pre-flight (the only human touchpoint): validates plan critical-gaps + safety + opens the
    report, but **never checks that the review swarm can actually run** (host can spawn the review
    sub-agents + a provider/model resolves). So infeasibility is discovered mid-run, when the
    autonomous driver is most tempted to improvise.
  - Autonomy overrides #1–3 (verification-fails / blocking-review / unsafe-step): **none covers
    "downgrade the review depth."** The resolve-or-log-and-continue policy has no rule forbidding a
    cheaper-review substitution.
  - Morning-report outcome enum (`clean` / `done-with-findings` / `partial+blockers` /
    `refused-to-start`) and per-increment sweep-verdict cell: **cannot express a downgraded /
    unverified clean**, so a human reading the report cannot tell a real clean from a downgraded one.

`woostack-review` already solved exactly this problem internally (receipt gate); the sweep is the
un-receipted layer directly above it.

## 2. Proposed Fix

Minimal, prose-contract edits to the two `SKILL.md` files (no script logic change required — these
are pure-prose skills), each pinned by a committed grep-prose test. Four coordinated parts that map
1:1 to the issue's asks:

- **A. `woostack-sweep` — require a review receipt before `clean`.**
  A PR may be marked `clean` **only** when the verdict is derived from an actual
  `woostack-review --full` run on that PR's current HEAD — and **never** from a structural / self /
  manual review. The **receipt** is the existing artifact the loop already reads: the
  woostack-review-posted verdict bearing its bot marker on the PR at the reviewed HEAD SHA (the
  same `STATUS_LINE` + marker step 2 consumes). No new artifact file — reuse the marker as
  proof-of-execution. A PR whose review engine did **not** produce such a verdict (engine
  error/hang/skipped) folds into sweep's **existing `blocked`** outcome — the blocker definition is
  amended to name "review did not run / no woostack-review receipt for HEAD" explicitly. This stays
  **distinct** from the existing no-open-PR case (which remains skip + warn, un-reviewable). State
  the receipt rule as a prominent barrier in the per-PR loop **and** restate it in Hard constraints
  (per [[gate-needs-hard-barrier]]), not buried in step 2. Per [[fanout-empty-needs-receipt]],
  absent receipt ⇒ not clean.
  *No new per-PR outcome value* — `clean` / `done-with-findings` / `blocked` is unchanged; this
  edit makes `clean` provably swarm-derived and routes review-didn't-run into `blocked`.

- **B. `woostack-execute-overnight` — pre-flight review feasibility.**
  Add a pre-flight check: confirm the review swarm can run (host can spawn the review sub-agents +
  a provider/model resolves — the same capability signal overnight already probes for the smart
  driver default). If it is **statically** infeasible at pre-flight, **refuse-to-start** with a
  report (existing `refused-to-start` outcome) — never go autonomous into a run whose contracted
  sweep cannot run. (A swarm that passes pre-flight but **fails when invoked mid-run** is the
  `sweep-unavailable` run-level outcome from part C, which halts that track — the two moments are
  distinct.)

- **C. `woostack-execute-overnight` — first-class `sweep-unavailable` outcome.**
  Add `sweep-unavailable` to the morning-report **Run summary** outcome enum (a run-level outcome
  alongside `clean` / `done-with-findings` / `partial+blockers` / `refused-to-start`) for the case
  where the contracted sweep could not run mid-run. Forbid the downgrade so `clean` in the report
  **always** means swarm-derived — a human can no longer mistake a downgraded/unverified clean for
  a real one. The per-increment sweep-verdict cell keeps `woostack-sweep`'s vocabulary unchanged
  (part A); `sweep-unavailable` is a **run-level** outcome, not a new per-PR sweep verdict.

- **D. `woostack-execute-overnight` — driver rule (no silent downgrade).**
  Codify in Autonomy overrides **and** Hard constraints: *resolve-or-log-and-continue never means
  downgrade a contracted review.* A driver may not substitute a cheaper/self review on an
  unverified cost assumption; if the contracted `woostack-review --full` cannot run, **log the
  blocker and halt the track** (mid-run → `sweep-unavailable`) or **refuse at pre-flight** (static
  → `refused-to-start`, part B). Same class of invariant as "never relax safety for autonomy."

Parts **A + D** are the core invariant (receipt + no-downgrade rule); **B + C** are the pre-flight
gate + reporting that make a downgrade observable instead of silent.

### Resolved questions (hardening)

1. **Forbid the downgrade, not just label it.** `clean` stays swarm-only; there is no
   "downgraded-clean" token. The honest alternatives are `blocked` (per-PR, sweep) and
   `sweep-unavailable` (run-level, overnight) — never a disguised clean.
2. **Two distinct infeasibility moments.** Static (pre-flight) → `refused-to-start`. Mid-run swarm
   failure → `sweep-unavailable` + halt that track.
3. **No new per-PR sweep outcome.** "Review didn't run / no receipt" folds into sweep's existing
   `blocked`; only overnight gains the run-level `sweep-unavailable`. Keeps the sweep change minimal
   and the loop the single home.
4. **The receipt is the existing marker.** Reuse the woostack-review-posted verdict + bot marker on
   the PR at the reviewed HEAD SHA — no new artifact, no new script.
5. **No-PR skip stays distinct from review-didn't-run.** No open PR = skip + warn (existing,
   un-reviewable); PR present but engine didn't run = `blocked`.

## 3. Implementation Plan

- [x] **Step 1: Reproduce with failing grep-prose tests (Red).**
  - Add `skills/woostack-sweep/scripts/tests/test-review-receipt-contract.sh` + a
    `run-tests.sh` harness, sourcing `woostack-init/scripts/tests/assert.sh` (mirror existing
    skill prose tests; assert ASCII tokens per [[skill-test-assert-ascii-token]]). Assert
    `skills/woostack-sweep/SKILL.md` contains the per-PR **receipt** requirement and the
    "never mark clean from a self/structural review" clause (in the loop **and** Hard constraints).
  - Add `skills/woostack-execute-overnight/scripts/tests/test-sweep-integrity-contract.sh` +
    `run-tests.sh`. Assert `skills/woostack-execute-overnight/SKILL.md` contains: the pre-flight
    review-feasibility clause, the `sweep-unavailable` outcome, and the no-downgrade driver rule
    (e.g. an ASCII token like `sweep-unavailable` and a "log the blocker"/"never ... downgrade"
    phrase).
  - Confirm both fail today (tokens absent).

- [x] **Step 2: Apply the minimal contract edits (Green).**
  - `skills/woostack-sweep/SKILL.md`: add part **A** — receipt requirement as a prominent barrier
    in the per-PR loop + a Hard-constraints restatement; extend the blocker definition so an absent
    review receipt is a blocker; note provenance on the per-PR outcome vocabulary.
  - `skills/woostack-execute-overnight/SKILL.md`: add part **B** (pre-flight feasibility check),
    part **C** (`sweep-unavailable` outcome in the morning-report enum + per-increment verdict),
    and part **D** (no-downgrade driver rule in Autonomy overrides + Hard constraints).
  - Keep both skills' cross-links intact; `woostack-sweep` stays the single home of the loop and
    `woostack-execute-overnight` keeps delegating to it (do not restate the loop in overnight).

- [x] **Step 3: Verification.**
  - Run `bash skills/woostack-sweep/scripts/tests/run-tests.sh` and
    `bash skills/woostack-execute-overnight/scripts/tests/run-tests.sh` — both green.
  - Run any repo-wide skill test sweep if present; ensure no stale-path / surface-count test
    regressions from the new test dirs.
  - Re-read both edited `SKILL.md` files end-to-end for internal consistency (the four parts agree
    on the `sweep-unavailable` term and the receipt vocabulary).

- [x] **Step 4: Distill the gotcha.**
  - Record the root-cause gotcha (delegated review/verify step encoded as bare prose + no receipt +
    no `clean` provenance ⇒ autonomous driver silently downgrades it; the `fanout-empty-needs-receipt`
    pattern one level up). Link [[fanout-empty-needs-receipt]] and [[gate-needs-hard-barrier]].
