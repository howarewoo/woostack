# Antigravity CLI (`agy`)

## Detection

The `agy` CLI; reads `AGENTS.md` natively; authenticates via system keyring / Google Sign-In
(no documented non-interactive API-key path, so it cannot run headless in ephemeral CI).
Discover authorized native GitHub capabilities through the Antigravity MCP runtime. Prefer a
suitable native capability; host-authenticated GitHub CLI (`gh`) remains supported for explicit
GitHub operations under the selected workflow's admission. Discover actual GitHub operation
capabilities and read/write shapes rather than assuming tool names or schemas. Never use custom
HTTP/REST/GraphQL transport or fallback tokens.

## Subagent spawn

- **Primitive:** dynamically orchestrated subagents — the orchestrator instantiates one
  isolated-context subagent per task on demand. Dispatch independent tasks in a single turn
  to run them in parallel; rely on the isolation pattern for token economy.
- **Per-call model/effort knob:** no — single model per session.
- **Per-call cwd:** not exposed — fill the dispatch-prompt worktree pin; the subagent
  self-pins.

## Tier routing

**Single model per session.** Resolve one run model up front (a forced fast/deep tier if
set, otherwise standard); per-tier behavior collapses onto that one model for the whole job.
Split into multiple jobs for per-tier split behavior. Tier→model values:
[`../model-tiers.md`](../model-tiers.md).

## Host-level fallback

None documented — provider exhaustion surfaces as errors; recovery is account-level, outside
woostack's scope.
`models.<tier>` fallback lists (entries 1..n) are a documented preference order only on this
host — no spawn-time auth probe exists; switch manually by promoting an entry to entry 0.

## Per-skill notes

- **woostack-orchestrate (parallel dispatch):** for each schedule packet, instantiate one
  delivery-capable isolated-context subagent with the dispatch-prompt worktree pin. Pass `workspace`,
  `branch`, `parent_branch`, `parent_sha`, child issue URL, and packet
  `bounded_input`/`acceptance`/`checks` as the complete Execute contract. Clamp `effective_cap` to
  host capability, refill as workers complete, and keep one concrete run model for all workers.
  A serializing mode runs at concurrency one with a clear notice; without delivery-capable subagents,
  block rather than executing inline.

## Degradation

Single-session collapse is the documented mode, not a degradation. A run that cannot resolve
any model → session default + say so, per the inline law of the dispatching skill.
If no authorized GitHub interface (native capability or host-authenticated `gh`) supports a
required operation capability, fail closed for required GitHub boundaries; for optional operations,
report the missing capability without an unauthorized fallback.
