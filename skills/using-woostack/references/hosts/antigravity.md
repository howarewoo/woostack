# Antigravity CLI (`agy`)

## Detection

The `agy` CLI; reads `AGENTS.md` natively; authenticates via system keyring / Google Sign-In
(no documented non-interactive API-key path, so it cannot run headless in ephemeral CI).
Discover official Linear or Plane MCP tools via `AGENTS.md` / Antigravity MCP runtime, or an
authorized GitHub capability exposed by the host (prefer native GitHub tools; host-authenticated
official `gh` remains supported). Discover actual operation capabilities and read/write shapes rather
than assuming tool names or schemas. Never use custom HTTP/REST/GraphQL transport or fallback tokens.
Artifact operations follow the canonical
[artifact backends contract](../../../woostack-init/references/artifact-backends.md).

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
- **woostack-eval (comparative dispatch):** instantiate the two isolated-context workers for
  each candidate/baseline inseparable pair in the same dynamic orchestration turn. There is no
  concrete per-call model pin; choose one concrete run model before the session.
  `session-default` is provable when both workers inherit that same identified session model.
  Parallel dynamic subagents can satisfy comparative concurrency; a host mode that serializes
  the pair cannot.

## Degradation

Single-session collapse is the documented mode, not a degradation. A run that cannot resolve
any model → session default + say so, per the inline law of the dispatching skill.
When the configured provider's authorized interface (official Linear/Plane MCP, or a native GitHub
capability / host-authenticated `gh`) or a required operation capability is absent on this host, fail
closed for required provider boundaries or report the missing capability for optional operations per
canonical artifact law.
