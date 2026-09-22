# opencode

## Detection

The OpenCode runtime; subagent dispatch via `@subagent` with per-call model selection.
Discover official Linear or Plane MCP tools exposed via OpenCode runtime MCP configuration or
host-authenticated GitHub CLI (`gh`) under the selected workflow's artifact admission. Never use custom HTTP/REST/GraphQL transport or
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

**Per-call routing.** Resolve the caller's effective tier through the active provider's column in
[`../model-tiers.md`](../model-tiers.md) plus its override precedence, and pass everything
the resolved tier specifies on every spawn (the pass-or-inherit law lives in the dispatching
skill).

## Host-level fallback

None documented — provider exhaustion surfaces as errors; recovery is account-level, outside
woostack's scope.
`models.<tier>` fallback lists (entries 1..n) are a documented preference order only on this
host — no spawn-time auth probe exists; switch manually by promoting an entry to entry 0.

## Per-skill notes

- **woostack-orchestrate (parallel dispatch):** for each schedule packet, dispatch one
  delivery-capable `@subagent` worker with the dispatch-prompt worktree pin (plus per-call cwd when
  accepted). Pass `workspace`, `branch`, `parent_branch`, `parent_sha`, child issue URL, and packet
  `bounded_input`/`acceptance`/`checks` as the complete Execute contract; pin the resolved model,
  clamp `effective_cap` to host capability, and refill as workers complete. An `N=1` or queue-only
  build runs at concurrency one with a clear notice; without delivery-capable subagents, block rather
  than executing inline.
- **woostack-eval (comparative dispatch):** submit the candidate and baseline as two isolated
  `@subagent` workers in the same parallel dispatch, keeping every inseparable pair intact.
  Pin the same concrete model on both calls. `session-default` is provable only when the runtime
  identifies both workers as inheriting the same session model. Builds with true parallel
  subagents support comparative concurrency; an `N=1` or queue-only build cannot.

## Degradation

A spawn that cannot carry the resolved model → session model + say so (degraded), per the
inline law of the dispatching skill.
When the configured provider's official interface (Linear/Plane MCP, or host-authenticated gh for GitHub) or a required capability is absent on this host, fail
closed for required provider boundaries or report the missing capability for optional operations per
canonical artifact law.
