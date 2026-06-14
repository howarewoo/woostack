---
name: fanout-empty-needs-receipt
type: pattern
scope: skills/woostack-review/**
tags: receipt, false-pass, empty-findings, swarm, fan-out, gate, verify-receipts
hook: An empty aggregate from a fan-out of workers is ambiguous (clean vs never-ran) — require a per-worker execution receipt to disambiguate.
updated: 2026-06-06
source: [[plans/2026-06-06-review-fail-fast-receipts]]
---

When a flow fans work out to N workers and then aggregates their outputs, an
**empty aggregate is ambiguous**: it can mean "every worker ran and found nothing"
(a true clean result) or "no worker actually ran" (runner/auth/bridge absent). If
the aggregator pre-initializes each worker's output to a benign empty value (woostack-review
pre-writes `findings.<angle>.json = []` for non-destructive failure) and swallows worker
exit codes, the second case silently masquerades as the first — a **false PASS** (issue #237:
review reported APPROVED with zero findings when no angle analysis ran).

Fix pattern: each worker writes a **separate execution receipt** as its LAST action —
proof-of-execution distinct from its result. woostack-review uses
`receipt.<angle>[.<chunk>].json` = `{angle, chunk, runner, model, tier, ts}`, valid iff it is a
JSON object with matching `angle`/`chunk` and **non-empty `runner`+`model`** (identity, not just
file presence). Key rules learned:

- **Do NOT pre-initialize the receipt** (unlike the result file). The receipt's *presence* is the
  signal; pre-creating it defeats the mechanism.
- A worker that dies *after* its pre-initialized empty result but *before* the receipt leaves a
  *valid empty result + no receipt* — so the retry trigger must include "receipt missing", not
  just "result invalid", or the one retry never fires.
- One **single-authority** gate script owns the valid-receipt contract and the hard-fail
  (`verify-receipts.sh`), exposing a non-failing `--list-missing` mode the swarm reuses for its
  retry set so the contract never drifts between swarm and gate.
- Ship the receipt-WRITE contract and the gate in **lockstep** — never the gate before workers
  write receipts, or every run self-fails.

This keeps the empty-result invariant honest: `findings.json == []` ⟺ every expected worker
executed and found nothing. See [[review-angle-trigger-precision]] for the related
detect-then-act wiring discipline in the same skill.
