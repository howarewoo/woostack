# opencode

## Detection

The OpenCode runtime. A primary agent delegates to a subagent through the `task` tool; `@mention`
is how a user manually invokes a subagent in chat, not a transport an agent can call. Built-in
subagents are `General` (full tool access), `Explore` and `Scout` (both read-only), and a project or
user can add configured agents under `.opencode/agents/`
([agents](https://opencode.ai/docs/agents/)). Discover authorized native GitHub capabilities
exposed through OpenCode runtime MCP configuration; the shared capability and authentication
contract lives in the [host index](README.md#github-capability-and-authentication-shared).
Native explicit skill invocation asks for the named skill: the native `skill` tool loads
`skill({ name: "woostack-execute" })` from the discovered skill list
([Agent Skills](https://opencode.ai/docs/skills/)); every form is listed in the
[host index](README.md#native-skill-invocation).

## Subagent spawn

Inspect the active `task` tool schema before dispatch.

- **Primitive:** the `task` tool, gated by the host's `task` permission. A runtime that denies that
  permission or omits the tool has no delivery primitive.
- **Per-spawn model/effort:** not documented as a per-call field. opencode documents `model` and
  provider reasoning options as *agent configuration* resolved per agent, so a per-call value stays
  unproven until the active schema shows one. Pass it when the schema carries the exact name;
  otherwise the subagent runs on its configured or session model.
- **Per-call cwd:** not documented — fill the dispatch-prompt worktree pin and require the worker to
  verify it before writing.
- **Worker selection:** select a discovered agent whose observed capabilities fit the task. The
  built-in `Explore` and `Scout` agents cannot modify files, so they never suit a write task.
- **Parallel dispatch shape:** submit independent tasks together when the active build allows it and
  let the runtime schedule workers. There is no documented numeric cap parameter, so clamp
  `effective_cap` to observed behavior and serialize at concurrency one with a clear notice when the
  build cannot run workers in parallel.

## Tier routing

**Per-call routing when the active schema supports it.** Resolve the caller's effective tier through
the active provider's column in [`../model-tiers.md`](../model-tiers.md) plus its override
precedence, and pass everything the resolved tier specifies only when the active schema exposes
that exact field (the pass-or-inherit law lives in the dispatching skill).

## Host-level fallback

None documented — provider exhaustion surfaces as errors, and recovery is account-level, outside
woostack's scope. The [shared fallback note](README.md#host-level-fallback-shared-note) applies to
`models.<tier>` lists.

## Per-skill notes

- **woostack-orchestrate (parallel dispatch):** for each schedule packet, dispatch one
  delivery-capable worker from the discovered agent set with the dispatch-prompt worktree pin.
  Pass `workspace`, `branch`, `parent_branch`, `parent_sha`, child issue URL, and packet
  `bounded_input`/`acceptance`/`checks` as the complete Execute contract; request the resolved model
  only where the active schema supports it, clamp `effective_cap` to host capability, and refill as
  workers complete. Without delivery-capable subagents, block rather than executing inline.

## Degradation

A spawn with no per-call model field runs on the agent's configured or session model: run it and say
so once (degraded), per the inline law of the dispatching skill. A requested tier that cannot be
routed per call is reported the same way, never silently applied. A missing required delivery,
isolation, identity-correlation, review, or recovery capability blocks the owning operation per the
[conditional mechanics](README.md#conditional-mechanics-shared); a missing authorized GitHub
interface follows the
[shared GitHub contract](README.md#github-capability-and-authentication-shared).
