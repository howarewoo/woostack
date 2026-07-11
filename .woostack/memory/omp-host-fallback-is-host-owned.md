---
name: omp-host-fallback-is-host-owned
type: convention
scope: skills/using-woostack/references/model-tiers.md, skills/woostack-execute/references/subagent-driver.md, skills/woostack-execute-overnight/**
tags: omp, fallback, usage-limit, model-tiers, overnight, host-provider
hook: omp runs a temporary usage-limit model fallback beneath woostack's static tier routing — host-owned and self-announcing, never a "silent tier claim"; woostack documents it but never manages omp host config.
updated: 2026-07-10
source: [[fixes/2026-07-10-omp-host-fallback-docs]]
---
woostack's tier system is **static routing** (`models.<tier>` → generated `.omp/agents/`
defs); omp runs a **runtime failover ladder underneath it** on usage-limit errors: sibling
credential rotation first, then `retry.fallbackChains` as a *temporary* model switch
(announced via `retry_fallback_applied` events, reverted on cooldown expiry). Grounded in
omp's `non-compaction-retry-policy.md` / `models.md`.

Two rules this pins:

- **Not a silent tier violation.** The dispatch doctrine's "never pretend a tier ran /
  say so (degraded)" (`subagent-driver.md`) does NOT apply to a host-applied fallback: the
  host announces it and transcripts record the concrete model. The driver has no re-report
  obligation — do not flag this in review as a degraded-silently case.
- **Document, never manage.** woostack writes project `.omp/agents/` defs (generator) but
  never reads or writes omp's user-global host config (`~/.omp/` settings like `retry.*`).
  Fallback guidance is advisory prose only — e.g. execute-overnight's preflight
  "usage-exhaustion resilience" note adds **no refusal condition**.

Layer kinship: [[review-host-distinct-from-model-provider]] (host vs provider surfaces).
Lockstep: the omp bucket in `model-tiers.md` is inlined whole into review's CI orchestrator
prompt and pinned by `test-omp-lockstep.sh` — keep additions terse, never add a table column.
