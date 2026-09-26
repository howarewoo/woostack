# Antigravity CLI (`agy`)

## Detection

The `agy` CLI; reads `AGENTS.md` natively; authenticates via system keyring / Google Sign-In
(no documented non-interactive API-key path, so it cannot run headless in ephemeral CI).
No official Antigravity parameter surface is verified in this collection, so treat its dispatch
knobs as unknown until the active runtime exposes them. Discover authorized native GitHub
capabilities through the Antigravity MCP runtime; the shared capability and authentication contract
lives in the [host index](README.md#github-capability-and-authentication-shared).
Native explicit skill invocation uses the host's own documented form; a `/woostack-*` example
states the logical command only, and no Antigravity-specific form is recorded in the
[host index](README.md#native-skill-invocation).

## Subagent spawn

Inspect the active runtime before dispatch. Dynamically orchestrated subagents — one
isolated-context subagent per task, instantiated on demand — are the documented shape; no per-call
`model`, effort, or `cwd` argument is verified for it.

- **Primitive:** dynamically orchestrated subagents — submit independent tasks in a single turn and
  let the host instantiate isolated-context subagents; rely on the isolation pattern for token
  economy.
- **Per-call model/effort knob:** unverified. Pass it only when the active schema exposes that exact
  field; otherwise workers run on the session model and the run says so once.
- **Per-call cwd:** not exposed — fill the dispatch-prompt worktree pin; the subagent self-pins.

## Tier routing

No per-call tier mechanism is verified for Antigravity dispatch, so resolve one run model up front
(a forced fast/deep tier if set, otherwise standard) and let per-tier behavior collapse onto it for
the whole job. Split into multiple jobs for per-tier split behavior. Tier→model values:
[`../model-tiers.md`](../model-tiers.md). Revisit only if the active runtime exposes per-call
routing.

## Host-level fallback

None documented — provider exhaustion surfaces as errors, and recovery is account-level, outside
woostack's scope. The [shared fallback note](README.md#host-level-fallback-shared-note) applies to
`models.<tier>` lists.

## Per-skill notes

- **woostack-orchestrate (parallel dispatch):** for each schedule packet, instantiate one
  delivery-capable isolated-context subagent with the dispatch-prompt worktree pin. Pass `workspace`,
  `branch`, `parent_branch`, `parent_sha`, child issue URL, and packet
  `bounded_input`/`acceptance`/`checks` as the complete Execute contract. Clamp `effective_cap` to
  host capability, refill as workers complete, and keep one concrete run model for all workers
  unless the active schema exposes per-call routing. A serializing mode runs at concurrency one with
  a clear notice; without delivery-capable subagents, block rather than executing inline.

## Degradation

One run model per session is the mode to plan around, not a degradation. A run that cannot resolve
any model uses the session default and says so once, per the inline law of the dispatching skill. A
missing required delivery, isolation, identity-correlation, review, or recovery capability blocks
the owning operation per the
[conditional mechanics](README.md#conditional-mechanics-shared); a missing authorized GitHub
interface follows the
[shared GitHub contract](README.md#github-capability-and-authentication-shared).
