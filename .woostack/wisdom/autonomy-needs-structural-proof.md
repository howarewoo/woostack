---
name: autonomy-needs-structural-proof
type: wisdom
category: process
source: gate-needs-hard-barrier, delegated-review-no-silent-downgrade, fanout-empty-needs-receipt, fixes/2026-06-11-address-comments-verdict-gate, fixes/2026-06-14-overnight-sweep-downgrade, plans/2026-06-06-review-fail-fast-receipts
updated: 2026-06-15
---

A load-bearing gate, verdict, or quality step survives an **autonomous or low-effort/fast
driver** only if it is **structurally enforced and backed by proof-of-execution**. Soft body
prose gets collapsed, skipped, or downgraded by a model optimizing for completion. Three
layers of the same law:

- **Gates** — a load-bearing approval gate needs a prominent STOP barrier **and** a
  restatement in `## Hard constraints` ("Silence is not a yes"). A gate that exists only as a
  mid-procedure sentence is skippable. ([[gate-needs-hard-barrier]])
- **Verdicts** — a delegated review/verify `clean` is valid **only** with an execution receipt
  from the real engine on the current HEAD. No receipt ⇒ `blocked`, never a pass. Decide
  feasibility at pre-flight; a mid-run failure is its own outcome, never a downgraded `clean`.
  ([[delegated-review-no-silent-downgrade]])
- **Fan-out** — an empty aggregate is ambiguous: *clean* vs *never ran* look identical. Each
  worker writes a **separate execution receipt as its last action**; do not pre-initialize the
  receipt to a benign value, or a swallowed worker masquerades as a PASS.
  ([[fanout-empty-needs-receipt]])

How to apply: state every load-bearing rule as a barrier **and** as a Hard constraint; make
"no silent downgrade" a safety-class invariant the driver cannot relax; let one
single-authority gate/aggregator script own the receipt contract so the autonomous path and
the test path cannot drift. The same instinct catches side-effect failures — e.g. confirm a
`gt submit` actually opened the PR before tearing down its worktree.
