---
type: fix
status: executing
branch: fix/review-host-managed-swarm
---

# Fix: Let review hosts manage subagent fan-out

## 1. Root Cause

`woostack-review` currently documents and implements a hard default swarm cap of `6`.
The shell helper initializes `max_concurrency` from `WOO_REVIEW_MAX_CONCURRENCY:-6`,
and the review skill tells native host integrations to implement the same bounded
queue. That makes the conservative shell fallback become the universal review
contract, even when the host can safely manage a larger subagent queue on its own.

Evidence:

- `skills/woostack-review/scripts/run-bounded-swarm.sh` advertises
  `--max-concurrency, WOO_REVIEW_MAX_CONCURRENCY, 6` as the precedence order and
  uses `6` when no override is present.
- `skills/woostack-review/SKILL.md` describes native host dispatch in terms of the
  same bounded queue, so hosts with their own queueing semantics inherit the cap.
- The local no-PR handback asks the orchestrator to mention bounded mode and
  `max_concurrency`, reinforcing the cap as normal review behavior.

## 2. Proposed Fix

Make host-managed fan-out the default review contract. Native host integrations
should dispatch all active review work and let the host queue or parallelize
according to its own limits. Keep `run-bounded-swarm.sh` as a shell fallback and
explicit opt-in limiter: when `--max-concurrency` or `WOO_REVIEW_MAX_CONCURRENCY`
is set, it runs bounded; otherwise it starts every angle/chunk worker and waits for
the host shell/runtime to manage execution pressure.

Update swarm metrics and handback wording so an unbounded/host-managed run is
represented as `max_concurrency: null`, while explicit bounded runs still record the
numeric cap.

## 3. Implementation Plan

- [x] **Step 1: Reproduce with a failing test**
  - Update `skills/woostack-review/scripts/tests/test-bounded-swarm.sh` to cover the
    no-cap default and assert the observed active worker count reaches all queued
    work items, not `6`.
  - Assert `swarm-metrics.json` records `max_concurrency: null` for the default
    host-managed run.
- [x] **Step 2: Apply the minimal fix**
  - Change `run-bounded-swarm.sh` so `max_concurrency` is empty by default and only
    bounded when `--max-concurrency` or `WOO_REVIEW_MAX_CONCURRENCY` provides a
    positive integer.
  - Preserve the existing explicit bounded path, retry behavior, receipt gate, and
    per-worker environment/model propagation.
  - Keep invalid explicit values as hard errors; only the absent-value path becomes
    host-managed.
  - Update `skills/woostack-review/SKILL.md` so native host dispatch is described as
    host-managed fan-out, with bounded scheduling limited to the shell helper or
    explicit host opt-in.
  - Update local handback wording from always reporting bounded mode to reporting
    host-managed mode when no cap is configured.
- [x] **Step 3: Verification**
  - Run `bash skills/woostack-review/scripts/tests/test-bounded-swarm.sh`.
  - Run `bash skills/woostack-review/scripts/tests/test-bounded-swarm-receipts.sh`.
