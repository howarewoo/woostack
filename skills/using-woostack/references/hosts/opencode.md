# opencode

## Detection

The OpenCode runtime; subagent dispatch via `@subagent` with per-call model selection.

## Subagent spawn

- **Primitive:** `@subagent` dispatch via the runtime's primitive, letting the runtime
  schedule workers; use an explicit cap such as `N=1` only when the build does not support
  parallelism.
- **Per-call model/effort knob:** yes — pass the resolved model explicitly per spawn.
- **Per-call cwd:** pass it when the spawn accepts one; fill the dispatch-prompt worktree pin
  regardless.

## Tier routing

**Per-call routing.** Resolve the effective tier — forced tier if set, else the prompt's
`tier:` frontmatter — through the active provider's column in
[`../model-tiers.md`](../model-tiers.md) plus its override precedence, and pass everything
the resolved tier specifies on every spawn (the pass-or-inherit law lives in the dispatching
skill).

## Host-level fallback

None documented — provider exhaustion surfaces as errors; recovery is account-level, outside
woostack's scope.
`models.<tier>` fallback lists (entries 1..n) are a documented preference order only on this
host — no spawn-time auth probe exists; switch manually by promoting an entry to entry 0.

## Per-skill notes

- **woostack-review (local swarm):** dispatch angle workers via the runtime primitive (see
  `skills/woostack-review/prompts/opencode.md`); cap concurrency (`N=1`) only when the build
  lacks parallelism.

## Degradation

A spawn that cannot carry the resolved model → session model + say so (degraded), per the
inline law of the dispatching skill.
