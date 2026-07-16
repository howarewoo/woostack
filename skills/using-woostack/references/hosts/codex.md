# Codex

## Detection

Codex CLI locally (subagent spawns accept a `model` override); Codex Action in CI
(single-session, no subagent model overrides).

## Subagent spawn

- **Primitive:** local subagent dispatch with a per-call `model` override; dispatch
  independent tasks together and let the runtime schedule.
- **Per-call model/effort knob:** yes locally — `model` plus `reasoning_effort` (GPT-5-family
  reasoning is a parameter on the same slug, not a slug suffix). No, under Codex Action.
- **Per-call cwd:** pass it when the spawn accepts one; fill the dispatch-prompt worktree pin
  regardless.

## Tier routing

- **Local (per-call routing):** resolve the effective tier through the OpenAI column in
  [`../model-tiers.md`](../model-tiers.md) plus its override precedence; pass the resolved
  slug + `reasoning_effort` on every spawn.
- **Codex Action (single model per session):** resolve one run model up front (a forced
  fast/deep tier if set, otherwise standard); per-tier behavior collapses onto that model for
  the whole job. Split into multiple jobs for per-tier split behavior.

## Host-level fallback

None documented at the subagent layer — usage-limit exhaustion surfaces as provider errors.
Account-level recovery (a second login, plan quota) is outside woostack's scope.
`models.<tier>` fallback lists (entries 1..n) are a documented preference order only on this
host — no spawn-time auth probe exists; switch manually by promoting an entry to entry 0.

## Per-skill notes

- **woostack-review (local swarm):** per-call bucket — honor each angle prompt's `tier:` and
  resolve each spawn's model via the review scripts' resolver; (CI) the single-session
  `load-prompt.sh` / `resolve-model.sh` path owns routing and is self-contained.
- **woostack-eval (comparative dispatch):** local Codex can start the two isolated workers in
  each candidate/baseline inseparable pair together and pin the same concrete `model` plus
  `reasoning_effort` on both calls. `session-default` is provable only when both calls omit
  overrides and the host confirms the same session identity. Local concurrent dispatch can
  satisfy comparative mode; single-session Codex Action cannot create the required paired
  workers and fails that mechanics preflight.

## Degradation

Single-session context (Codex Action) is not a degradation — it is the documented
one-run-model collapse. A local spawn that cannot carry `model` → session model + say so
(degraded), per the inline law of the dispatching skill.
