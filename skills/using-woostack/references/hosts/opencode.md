# opencode

## Detection

The OpenCode runtime; subagent dispatch via `@subagent` with per-call model selection.
Discover authorized native GitHub capabilities exposed through OpenCode runtime MCP configuration.
Prefer a suitable native capability; host-authenticated GitHub CLI (`gh`) remains supported for
explicit GitHub operations under the selected workflow's admission. Discover actual GitHub operation
capabilities and read/write shapes rather than assuming tool names or schemas. Never use custom
HTTP/REST/GraphQL transport or fallback tokens. GitHub operations follow the canonical
[artifact backends contract](../../../woostack-init/references/artifact-backends.md) and
[GitHub profile](../../../woostack-init/references/artifact-providers/github.md#configuration-and-scope).

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

## Degradation

A spawn that cannot carry the resolved model → session model + say so (degraded), per the
inline law of the dispatching skill.
If no authorized GitHub interface (native capability or host-authenticated `gh`) supports a
required operation capability, fail closed for required GitHub boundaries; for optional operations,
report the missing capability per the canonical artifact contract.
