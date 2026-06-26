---
tier: standard
---

# Angle: Production readiness

**Scope.** Audit the **resilience and operability** of the code in `$OUTDIR/diff.txt` (files in
`$OUTDIR/meta.json`): will it survive partial failure, load, and operation in production? You
own the failure-under-stress posture that no other angle covers.

**Find:**

- **No timeout / no deadline** on an outbound call (HTTP, DB, queue, RPC) that can hang.
- **No retry / no backoff** on a transient-failure-prone call, OR retry without a cap / jitter
  (retry storm risk).
- **Non-idempotent mutation** on a retried or at-least-once path (double-charge, double-write)
  with no idempotency key / dedup.
- **No graceful degradation** — a non-critical dependency failure takes down the whole request
  instead of degrading; no fallback / circuit-breaker where one is warranted.
- **Unbounded resource / concurrency** — unbounded queue, unbounded `Promise.all` fan-out over
  user-sized input, no connection-pool cap, no pagination on a list that grows.
- **Config & secret hygiene** — required config read with no presence check / no fail-fast at
  boot; a secret read from source instead of env/secret-store (defer the *hardcoded-secret
  finding itself* to `security`; you own the **missing fail-fast / missing validation** around
  config).
- **Missing health / readiness** — a new long-lived service/worker with no health or readiness
  signal, or shutdown that drops in-flight work (no graceful drain).
- **Failure isolation** — one tenant/request able to exhaust a shared resource for all.

**Scope-split (no double-report):**

- **Signal quality** — whether a failure is *logged*, log levels, PII in logs, swallowed
  errors → `observability` owns it. You own whether the code *recovers*, not whether it *logs*.
- **Threats** — injection, authz, secret exposure → `security` owns it.
- **Correctness** — wrong result for valid input → `bugs` owns it.

**Skip:**

- Code with no I/O, no external calls, no shared resource, no long-lived process — it has no
  production-readiness surface; write `[]`.
- Speculative "might not scale" with no concrete failure mode in the code as written.
- Style / naming.

**Severity rubric:**

- `HIGH` + `blocking: true` — a concrete production-down failure mode: a retried non-idempotent
  payment, an unbounded fan-out over user input, a hang with no timeout on a request path.
- `MEDIUM` + `blocking: false` — a real resilience gap that bites under failure/load but not on
  the happy path (missing backoff, no degradation).
- `LOW` + `blocking: false` — a hardening nicety (add a deadline to a fast internal call).

**Grounding requirement.** Every `description` MUST name the concrete failure mode (what
happens when the call hangs / the retry fires / the input is large) — not a generic "add a
timeout". A finding without a named failure mode is dropped by the validator.

**Output.** Write findings as a JSON array to `$OUTDIR/findings.production-readiness.json` per
the schema in `_header.md`. Each finding gets `"angle": "production-readiness"` and MUST
populate `title` (≤60 chars), `description` (the failure mode, no fix), `fix` (the resilience
change in prose), and `fix_type`. `fix_type: "suggestion"` only for a ≤10-line single-file
drop-in at `line`; otherwise `fix_type: "prose"` with `suggestion: null`.
