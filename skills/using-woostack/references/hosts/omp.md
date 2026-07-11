# omp (Oh My Pi)

## Detection

The `task` tool exposes an `agent:` selector but **no per-call `model`/`tier`/`effort`
argument**; generated agent definitions live under `.omp/agents/`; host config lives in
`~/.omp/` (user-global) and `.omp/` (project).

## Subagent spawn

- **Primitive:** `task` tool, one subagent per task; dispatch independent tasks in a single
  turn to run them in parallel.
- **Per-call model/effort knob:** none — model routing rides the agent definition.
- **Per-call cwd:** pass it when the spawn accepts one; the dispatch-prompt worktree pin is
  filled regardless (the guard double-checks).

## Tier routing

**Agent-by-tier.** omp resolves a subagent's model from the **agent definition** (`model` +
`thinkingLevel`). woostack ships three generated defs
`.omp/agents/woostack-{fast,standard,deep}.md` — baked from `.woostack/config.json` flat
`models.<tier>` by `skills/woostack-init/scripts/gen-omp-agents.sh` — and the dispatching
skill selects `agent: woostack-<effective-tier>` per spawn. **Ensure-then-select:** before
dispatch, run the generator (idempotent) so the defs exist and are current, then select the
per-task effective tier's agent — **agent-by-tier** routing. This is a routing pattern
over the existing flat `models.<tier>` config — **not a fifth provider column** and **not
a new config key**. An unset tier resolves to a `thinkingLevel`-only def (fast→low,
standard→medium, deep→xhigh) inheriting the session model. woostack effort
(`minimal|low|medium|high|xhigh`) maps 1:1 to omp `thinkingLevel` (which also allows
`off`). This is the "host cannot route per call" branch done right — it is **not**
degraded: the tier's model/effort apply via the def, so never "run at session model + say
so" under omp. Tier→model values and override precedence:
[`../model-tiers.md`](../model-tiers.md).

**Cross-consumer coexistence.** On CI/single-session hosts the flat provider table and
`resolve-model.sh` are untouched; this bucket is informational there. A consumer can still
set provider-specific columnar models for those hosts.

## Host-level fallback

Tier routing above is **static**; usage-limit failover is **host-owned**. The tier def picks
the subagent session's *starting* model; on provider exhaustion omp walks its ladder —
rotate sibling credentials (same provider), then apply its own `retry.fallbackChains` as a
**temporary, self-announcing** model switch (`retry_fallback_applied` events) that reverts on
cooldown expiry, then informed waiting against the provider's retry-after, then loud failure —
beneath, not instead of, the tier's configured model. Credential-cooldown state is
store-level, so a sibling spawn of the same tier agent falls over at spawn time rather than
mid-task; the temporary model switch itself is per-session. woostack documents this layer but
never reads or writes omp host config (`~/.omp/`).

## Per-skill notes

- **woostack-init (scaffold):** after writing `.woostack/config.json` (or when it already
  exists), run `skills/woostack-init/scripts/gen-omp-agents.sh` to generate the three tier
  defs; the generator writes an adjacent `.omp/agents/.gitignore` so defs stay untracked.
- **woostack-commit (fast drafting):** select `agent: woostack-fast` for the drafting spawn
  (ensure defs first via the generator).
- **woostack-review (local swarm only):** dispatch each angle worker as
  `agent: woostack-<tier>` (tier-pinned general-purpose worker) and the deep validator as
  `agent: woostack-deep`; ensure defs first. The CI single-session
  `load-prompt.sh` / `resolve-model.sh` path is unchanged. If a worker hits a usage limit,
  omp recovers inside the worker (rotation/fallback) and the worker finishes on the fallback
  model — receipt `model` stays the configured slug while the transcript records the concrete
  model. An unrecovered worker writes no execution receipt, so review's receipt gate
  hard-fails the run — no silently thinner review.
- **woostack-execute-overnight (preflight advisory):** check usage-exhaustion resilience — a
  second provider login or `retry.fallbackChains` covering the tier models — before an
  unattended run; without it, mid-run exhaustion halts the track through the normal blocker
  path (recommendation, not a refusal condition).

## Degradation

- Defs missing or stale → run the generator (idempotent) and re-select; that is the fix, not
  a degradation.
- Generator cannot run (no shell) → treat as no-per-call-routing: run at the session model
  and say so (degraded), per the inline law of the dispatching skill.
