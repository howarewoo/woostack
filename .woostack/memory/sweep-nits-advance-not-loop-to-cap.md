---
name: sweep-nits-advance-not-loop-to-cap
type: decision
scope: skills/woostack-sweep/**
tags: sweep, nits, max_rounds, cap, review-loop, done-with-findings, overnight
hook: sweep's max_rounds cap bounds only the BLOCKING loop; a no-blocking (nits-only) verdict is addressed once and advances, never looping to the cap.
updated: 2026-07-14
source: [[fixes/2026-07-14-sweep-continue-on-nits]]
---
`woostack-sweep` originally treated **any** open thread — blocking or nit — as "not clean," so a
nits-only PR was forced back through the bounded `review --full` → address → restack → re-review
loop until it went fully clean or tripped `review_sweep.max_rounds`. The docs said nits "loop to
the cap" and `done-with-findings` was "reachable only at the cap." That burned expensive full
re-reviews chasing non-blocking suggestions.

The decision: **decouple nit handling from the bounded loop.** Branch on the review *verdict*:

- **Blocking findings** → the bounded loop (`max_rounds` + the blocking-only no-progress guard);
  the cap can now only produce `blocked`.
- **No-blocking verdict** (`APPROVED` / `APPROVED WITH SUGGESTIONS`): zero threads ⇒ `clean`
  (receipt-backed) and advance; open nit threads ⇒ **one** `address-comments` pass + restack, then
  **advance** as `done-with-findings` — **no re-review**. Nits get a single pass, never a loop.

Invariant that stays: *receipt-before-clean* still holds — after the nit pass the HEAD SHA has no
fresh receipt, so the PR advances as `done-with-findings`, never a synthesized `clean`.

Reusable rule: in the sweep loop, **`max_rounds` is a blocking-churn backstop, not a nit
throttle.** Do not re-couple nits to "the cap." Callers defer to sweep (the single home of the
loop), so when editing `woostack-execute-overnight` (SKILL + report-template) or the site
`configuration.mdx`, keep the nits path cap-independent — the overnight report reason token is
`nits-addressed`, not `nits-at-cap`. Deliberate tradeoff: skipping the confirming re-review means a
nit fix that regresses outside its diff is not re-caught by the sweep (accepted — nits are
low-risk, and it stops the expensive `--full` churn).
