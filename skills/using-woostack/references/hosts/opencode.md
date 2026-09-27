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
  let the runtime schedule workers. There is no documented numeric cap parameter, so the caller
  derives its own concurrency from observed behavior and serializes with a clear notice when the
  build cannot run workers in parallel.

## Model selection

The agent's configured or session model is the normal default. Optional
[role preferences](../model-tiers.md) do not select a concrete model; an explicit one-run override
requires a verified native field and host authorization.

## Host-level fallback

The host owns recovery. Provider exhaustion may surface as an error; Woostack does not enact
repository fallback lists. See the [shared note](README.md#host-level-fallback-shared-note).

## Per-skill notes

- **woostack-orchestrate (multi-task coordination):** deliver each ready task through one
  delivery-capable worker from the discovered agent set with the dispatch-prompt worktree pin, and
  pass the complete bounded task contract, acceptance, and required checks. Derive concurrency from
  observed host behavior and start the next task as a worker completes. A host without a `task`
  primitive runs the tasks sequentially in the calling session and reports that; never describe
  one-at-a-time dispatch as parallel, and never present sequential work as independent review.

## Capability limits

Normal configured/session-model inheritance needs no notice. Report an unsupported optional
explicit override; block an exact-identity requirement without matching host evidence. Missing
required delivery, isolation, review, or recovery capability blocks per
[conditional mechanics](README.md#conditional-mechanics-shared); GitHub operations follow the
[shared GitHub contract](README.md#github-capability-and-authentication-shared).
