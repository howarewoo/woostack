# Cursor / Composer

## Detection

Cursor's Composer agent runtime; project rules load from `.cursorrules`. No official Cursor
parameter surface is verified in this collection, so treat its dispatch knobs as unknown until the
active runtime exposes them. Discover authorized native GitHub capabilities exposed through Cursor
Composer / `.cursorrules` MCP configuration; the shared capability and authentication contract lives
in the [host index](README.md#github-capability-and-authentication-shared).
Native explicit skill invocation uses the host's own documented form; a `/woostack-*` example
states the logical command only, and no Cursor-specific form is recorded in the
[host index](README.md#native-skill-invocation).

## Subagent spawn

Inspect the active runtime before dispatch. A Composer parallel-subagent dispatch is the documented
shape; no per-call `model`, effort, or `cwd` argument is verified for it.

- **Primitive:** parallel subagent dispatch — submit independent tasks and let the host schedule or
  queue workers.
- **Per-call model/effort knob:** unverified. Pass it only when the active schema exposes that exact
  field; otherwise workers run on the host-selected model and the run says so once.
- **Per-call cwd:** not exposed — fill the dispatch-prompt worktree pin; the subagent self-pins.

## Tier routing

No per-call tier mechanism is verified for Cursor dispatch. Treat the session's model as the run
model until the active schema exposes a per-call field; a forced tier then applies by changing the
session model before the run. Tier→model semantics: [`../model-tiers.md`](../model-tiers.md).

## Host-level fallback

None documented — provider exhaustion surfaces as errors, and recovery is account-level, outside
woostack's scope. The [shared fallback note](README.md#host-level-fallback-shared-note) applies to
`models.<tier>` lists.

## Per-skill notes

- **woostack-orchestrate (parallel dispatch):** for each schedule packet, submit one
  delivery-capable parallel-subagent worker with the dispatch-prompt worktree pin. Pass `workspace`,
  `branch`, `parent_branch`, `parent_sha`, child issue URL, and packet
  `bounded_input`/`acceptance`/`checks` as the complete Execute contract; clamp `effective_cap` to
  host capability and refill as workers complete. Workers run on the host-selected model unless the
  active schema exposes a per-call field. A queue-only runtime runs at concurrency one with a clear
  notice; without delivery-capable subagents, block rather than executing inline.

## Degradation

A tier requested but not routable per call runs at the session model and says so once (degraded),
per the inline law of the dispatching skill. A missing required delivery, isolation,
identity-correlation, review, or recovery capability blocks the owning operation per the
[conditional mechanics](README.md#conditional-mechanics-shared); a missing authorized GitHub
interface follows the
[shared GitHub contract](README.md#github-capability-and-authentication-shared).
