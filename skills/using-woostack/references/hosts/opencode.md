# opencode

## Detection

The OpenCode runtime; subagent dispatch via `@subagent` with per-call model selection.
Discover official Linear or Plane MCP tools exposed via OpenCode runtime MCP configuration, selected strictly by
`artifacts.provider`. Never use custom HTTP/REST/GraphQL transport or
fallback tokens. Artifact operations follow the canonical
[artifact backends contract](../../../woostack-init/references/artifact-backends.md).

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
  `skills/woostack-review/prompts/opencode.md`); cap concurrency (`N=1`) only when the build lacks
  parallelism. For validators, `reviewerSessionId` is the exact opaque worker ID returned by each
  `@subagent` dispatch; `reviewerCredentialContextId` is
  `opencode:subagent:<worker-id>`. Feed both into
  [Review's bound-validator sequence](../../../woostack-review/SKILL.md).
- **woostack-execute:** route implementation workers at the `fast` tier per call;
  preserve the controller's project admission and delivery boundaries.
- **woostack-eval (comparative dispatch):** submit the candidate and baseline as two isolated
  `@subagent` workers in the same parallel dispatch, keeping every inseparable pair intact.
  Pin the same concrete model on both calls. `session-default` is provable only when the runtime
  identifies both workers as inheriting the same session model. Builds with true parallel
  subagents support comparative concurrency; an `N=1` or queue-only build cannot.

## Degradation

A spawn that cannot carry the resolved model → session model + say so (degraded), per the
inline law of the dispatching skill.
When the configured provider's official MCP or a required capability is absent on this host, fail
closed for required provider boundaries or report the missing capability for optional operations per
canonical artifact law.
