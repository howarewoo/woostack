---
name: review-swarm-orchestrator-fallback-redispatch
type: gotcha
scope: skills/woostack-review/**, skills/woostack-sweep/**, skills/using-woostack/references/hosts/omp.md
tags: review, sweep, fallback, usage-limit, resolve-model, receipt, omp, concurrent-burst
hook: a host's native models.<tier> fallback is not enough for the review swarm — under a concurrent-spawn burst it collapses, so review Stage 3 must re-dispatch usage/rate-limited workers onto the next configured entry (resolve-model.sh --index) before the receipt gate can hard-block.
updated: 2026-07-11
source: [[fixes/2026-07-11-review-swarm-fallback-redispatch]]
---
Native `models.<tier>` failover is **host-owned but not guaranteed**. Under a
concurrent-spawn burst (every angle worker hits the primary's usage limit at once), a
store-level credential cooldown can collapse the whole native chain, so all siblings exit
`usage_limit_reached` with no receipt even though a usable fallback is configured. Stage 3's
receipt gate then hard-blocks and `woostack-sweep` marks the PR `blocked` — the configured
fallback never ran.

Recovery is **orchestrator-side and host-agnostic**: on a usage/rate-limited worker with no
receipt, review Stage 3 re-dispatches it pinned to the next configured `models.<tier>` entry —
resolved with `resolve-model.sh --provider <p> --tier <t> --index N` (N incrementing from 1) —
walking the chain until a receipt appears or `--index` exits 3 ("chain exhausted"). Only an
exhausted chain hard-fails; a usage-limit hit on the primary tier alone is not a blocker when a
fallback is configured. `woostack-audit` inherits this for free (it repoints the same swarm).

`resolve-model.sh --index` selects the *winning* leaf (provider-scoped-then-flat — the same
leaf `provider_tier_model` resolves entry 0 from), then indexes into **that** leaf so fallback
entries never mix across leaves; a non-array or out-of-range leaf exits 3 with empty stdout
(distinct from the exit-1 usage error). Index 0 still routes through `provider_tier_model`
unchanged, so `load-prompt.sh`'s sourced 2-arg use is untouched.

Complements [[omp-host-fallback-is-host-owned]] (native failover is host-owned, self-announcing)
and [[review-model-resolution-two-paths]] (the resolver's CI vs local paths); the missing-receipt
proof-of-execution rule is [[fanout-empty-needs-receipt]].
