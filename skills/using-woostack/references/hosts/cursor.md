# Cursor / Composer

## Detection

Cursor's Composer agent runtime; project rules load from `.cursorrules`.
Use the host-authenticated GitHub CLI (`gh`) for explicit GitHub operations under the selected
workflow's admission. Never use custom HTTP/REST/GraphQL transport or fallback tokens. GitHub
operations follow the canonical [artifact backends contract](../../../woostack-init/references/artifact-backends.md)
and [GitHub profile](../../../woostack-init/references/artifact-providers/github.md#configuration-and-scope).

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
- **woostack-eval (comparative dispatch):** submit the two isolated workers for each
  candidate/baseline inseparable pair together through Composer's parallel-subagent primitive.
  Cursor exposes no concrete per-call model pin; `session-default` is provable only when the
  host confirms that both workers inherit the same session model identity. Composer parallel
  subagents support comparative concurrency; a queue-only runtime cannot.

## Degradation

Tier requested but not routable per call → run at the session model and say so (degraded),
per the inline law of the dispatching skill.
When the host-authenticated GitHub interface (`gh`) or a required capability is absent, fail closed
for required GitHub boundaries or report the missing capability for optional operations per the
canonical artifact contract.
