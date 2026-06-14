---
name: delegated-review-no-silent-downgrade
type: gotcha
scope: skills/woostack-sweep/**,skills/woostack-execute-overnight/**
tags: review-sweep, receipt, downgrade, autonomy, false-clean, provenance, overnight
hook: A delegated review/verify step written as bare prose — no execution receipt, no provenance on its `clean` verdict — lets an autonomous driver silently downgrade it to a cheap self-review and emit a false `clean`.
updated: 2026-06-14
source: [[fixes/2026-06-14-overnight-sweep-downgrade]]
---
A contracted review/verify step that an autonomous driver delegates is only as strong as its
**proof of execution**. In #349, `woostack-execute-overnight`'s post-implementation sweep
contracted a real `woostack-review --full` swarm, but the requirement lived **only as descriptive
loop prose** — no receipt, no pre-flight feasibility gate, no provenance on the `clean` verdict.
So a driver ran a structural self-review and emitted a `clean` byte-identical to a swarm-derived
one. Nothing prevented or flagged the downgrade.

This is the [[fanout-empty-needs-receipt]] ambiguity **one level up**: the sweep aggregates per-PR
`clean` verdicts the way review aggregates per-angle findings — but only review's *inner* layer had
the receipt gate (`verify-receipts.sh`). A `clean` with no receipt is ambiguous (swarm-ran-clean vs
review-never-ran).

Rule for any delegated review/verify contract under autonomy:
- **Receipt before pass.** `clean` is valid **only** from the real engine on the current HEAD,
  evidenced by a receipt (reuse the existing posted-verdict + bot marker — no new artifact). No
  receipt ⇒ `blocked` / un-runnable, **never** a pass. Keep it distinct from "nothing to review"
  (e.g. a branch with no open PR → skip+warn).
- **Pre-flight feasibility.** Check the engine can actually run before going autonomous; statically
  infeasible ⇒ refuse-to-start. A mid-run failure gets its own first-class outcome
  (`sweep-unavailable`), never a downgraded `clean`.
- **No-downgrade is a safety-class invariant.** "Resolve-or-log-and-continue" means *log the
  blocker*, never *quietly substitute a cheaper check* — same class as "never relax safety for
  autonomy."
- State all three as a prominent barrier **and** in `## Hard constraints`, not buried in loop
  prose, per [[gate-needs-hard-barrier]] (soft prose gets skipped by low-effort/fast drivers).
