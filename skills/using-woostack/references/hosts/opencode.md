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
- **Per-spawn model/effort:** not documented as per-call fields. opencode resolves model and
  reasoning options from agent configuration or the session. Pass an explicit native request
  only when the active schema exposes its exact field and host authorization permits it.
- **Per-call cwd:** not documented — fill the dispatch-prompt worktree pin and require the worker to
  verify it before writing.
- **Worker selection:** select a discovered agent whose observed capabilities fit the task. The
  built-in `Explore` and `Scout` agents cannot modify files, so they never suit a write task.
- **Parallel dispatch shape:** submit independent tasks together when the active build allows it and
  let the runtime schedule workers. There is no documented numeric cap parameter, so clamp
  `effective_cap` to observed behavior and serialize at concurrency one with a clear notice when the
  build cannot run workers in parallel.

## Model selection

The agent's configured or session model is the normal default. Optional
[role preferences](../model-tiers.md) do not select a concrete model; an explicit one-run override
requires a verified native field and host authorization.

## Host-level fallback

The host owns recovery. Provider exhaustion may surface as an error; Woostack does not enact
repository fallback lists. See the [shared note](README.md#host-level-fallback-shared-note).

## Per-skill notes

- **woostack-orchestrate (parallel dispatch):** for each schedule packet, dispatch one
  delivery-capable worker from the discovered agent set with the dispatch-prompt worktree pin.
  Pass `workspace`, `branch`, `parent_branch`, `parent_sha`, child issue URL, and packet
  `bounded_input`/`acceptance`/`checks` as the complete Execute contract; clamp
  `effective_cap` to host capability and refill as workers complete.

## Capability limits

Normal configured/session-model inheritance needs no notice. Report an unsupported optional
explicit override; block an exact-identity requirement without matching host evidence. Missing
required delivery, isolation, identity-correlation, review, or recovery capability blocks per
[conditional mechanics](README.md#conditional-mechanics-shared); GitHub operations follow the
[shared GitHub contract](README.md#github-capability-and-authentication-shared).
