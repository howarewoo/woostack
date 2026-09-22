# Codex

## Detection

Codex CLI locally (subagent spawns accept a `model` override); Codex Action in CI
(single-session, no subagent model overrides).
Prefer an authorized native GitHub capability when suitable; host-authenticated `gh` remains supported for explicit GitHub operations under the selected
workflow's admission. Never use custom HTTP/REST/GraphQL transport or fallback tokens. GitHub
operations follow the canonical [artifact backends contract](../../../woostack-init/references/artifact-backends.md)
and [GitHub profile](../../../woostack-init/references/artifact-providers/github.md#configuration-and-scope).

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

- **woostack-orchestrate (parallel dispatch):** for each schedule packet, dispatch one
  delivery-capable subagent with the dispatch-prompt worktree pin. Pass `workspace`, `branch`,
  `parent_branch`, `parent_sha`, child issue URL, and packet `bounded_input`/`acceptance`/`checks`
  as the complete Execute contract; use the tier routing above and clamp `effective_cap`
  to real capability, refilling as workers complete. Codex Action's single session cannot fan out
  and blocks rather than executing inline.
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
When no authorized GitHub interface supports a required operation capability, fail closed
for required GitHub boundaries or report the missing capability for optional operations per the
canonical artifact contract.
