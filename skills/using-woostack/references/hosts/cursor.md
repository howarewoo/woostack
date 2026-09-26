# Cursor / Composer

## Detection

Cursor's Composer agent runtime; project rules load from `.cursorrules`.
Discover authorized native GitHub capabilities exposed through Cursor Composer / `.cursorrules` MCP
configuration. Prefer a suitable native capability; host-authenticated GitHub CLI (`gh`) remains
supported for explicit GitHub operations under the selected workflow's admission. Discover actual
GitHub operation capabilities and read/write shapes rather than assuming tool names or schemas.
Never use custom HTTP/REST/GraphQL transport or fallback tokens.

## Subagent spawn

- **Primitive:** parallel subagent dispatch — submit independent tasks and let the host
  schedule or queue workers.
- **Per-call model/effort knob:** not exposed to woostack dispatch; workers run on the
  host-selected model.
- **Per-call cwd:** not exposed — fill the dispatch-prompt worktree pin; the subagent
  self-pins.

## Tier routing

No per-call tier mechanism is documented for Cursor dispatch. Treat the session's model as
the run model (single-model collapse); a forced tier applies only by changing the session
model before the run. Tier→model semantics:
[`../model-tiers.md`](../model-tiers.md).

## Host-level fallback

None documented — provider exhaustion surfaces as errors; recovery is account-level, outside
woostack's scope.
`models.<tier>` fallback lists (entries 1..n) are a documented preference order only on this
host — no spawn-time auth probe exists; switch manually by promoting an entry to entry 0.

## Per-skill notes

- **woostack-orchestrate (parallel dispatch):** for each schedule packet, submit one delivery-capable
  parallel-subagent worker with the dispatch-prompt worktree pin. Pass `workspace`, `branch`,
  `parent_branch`, `parent_sha`, child issue URL, and packet `bounded_input`/`acceptance`/`checks`
  as the complete Execute contract; clamp `effective_cap` to host capability and refill as workers
  complete. Workers run on the host-selected model. A queue-only runtime runs at concurrency one
  with a clear notice; without delivery-capable subagents, block rather than executing inline.

## Degradation

Tier requested but not routable per call → run at the session model and say so (degraded),
per the inline law of the dispatching skill.
If no authorized GitHub interface (native capability or host-authenticated `gh`) supports a
required operation capability, fail closed for required GitHub boundaries; for optional operations,
report the missing capability without an unauthorized fallback.
