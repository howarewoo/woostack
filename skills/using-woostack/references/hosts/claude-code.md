# Claude Code

## Detection

Claude Code's subagent spawn tool, documented as `Agent` in the
[tools reference](https://code.claude.com/docs/en/tools-reference) and called `Task` in older
builds; project rules load from `CLAUDE.md`. Discover authorized native GitHub capabilities exposed
through Claude Code MCP configuration; the shared capability and authentication contract lives in
the [host index](README.md#github-capability-and-authentication-shared).
Native explicit skill invocation is `/woostack-execute`
([skills](https://code.claude.com/docs/en/skills)); every form is listed in the
[host index](README.md#native-skill-invocation).

## Subagent spawn

Inspect the active spawn tool's schema before dispatch. A call that omits `subagent_type` fails
when the session has no `general-purpose` subagent to fall back on.

- **Primitive:** the subagent spawn tool; independent tasks run concurrently and the host schedules
  them. A session without the spawn tools offers no subagent primitive.
- **Per-call model:** documented — Claude Code can pass a `model` parameter for a specific
  invocation, and resolves the subagent model in this order: that per-invocation parameter, the
  subagent definition's `model` frontmatter (`inherit` selects the session model),
  `CLAUDE_CODE_SUBAGENT_MODEL`, then the session model
  ([subagents](https://code.claude.com/docs/en/sub-agents)). Pass the resolved model when the
  active schema carries the parameter and the caller's policy requires it.
- **Per-call effort:** not documented for a single invocation — `effort` is a subagent-definition
  and session field. Treat a per-call effort argument as absent unless the active schema shows one;
  when it is absent, report once that the selected tier's effort was not applied per invocation.
- **Per-call cwd:** not documented — fill the dispatch-prompt worktree pin and require the worker to
  verify it before writing. A subagent *definition* can request `isolation: worktree`; that is a
  definition choice, not a per-call working directory.
- **Worker profile:** select a discovered subagent whose observed capabilities fit the task;
  `general-purpose` is the plain write-capable worker, and read-only profiles suit exploration and
  review only. Never a skill-scoped profile.

## Tier routing

**Per-call routing when the parameter is available.** Resolve the caller's effective tier through
the active provider's column in [`../model-tiers.md`](../model-tiers.md) plus its override
precedence, and pass everything the resolved tier specifies when the active schema supports the
exact field (the pass-or-inherit law lives in the dispatching skill).

## Host-level fallback

None documented — provider exhaustion surfaces as an error on the spawn, and recovery is
account-level (plan limits), outside woostack's scope. The
[shared fallback note](README.md#host-level-fallback-shared-note) applies to `models.<tier>` lists.

## Per-skill notes

- **woostack-execute:** the no-per-call-cwd case — prompt pin plus self-pin guard — is the normal
  path here.
- **woostack-commit (fast drafting):** route the drafting subagent at the `fast` tier when the
  active schema carries the model parameter.
- **woostack-orchestrate (parallel dispatch):** for each schedule packet, dispatch one
  delivery-capable worker through the spawn tool with the prompt worktree pin. Pass `workspace`,
  `branch`, `parent_branch`, `parent_sha`, child issue URL, and packet
  `bounded_input`/`acceptance`/`checks` as the complete Execute contract. Clamp `effective_cap`
  to host capability, batch and refill as workers complete, and apply the self-pin guard per
  worker. A serialize-only mode runs at concurrency one with a clear notice; without a subagent
  spawn primitive, block rather than executing inline.

## Degradation

A spawn that cannot carry the resolved model runs on the host's next source in its documented
inheritance order — the subagent definition, `CLAUDE_CODE_SUBAGENT_MODEL`, or the session model —
and the run says so once (degraded), per the inline law of the dispatching skill. A session that
disables per-invocation model selection, such as `CLAUDE_CODE_SUBAGENT_MODEL_FORCE`, is that same
documented case. A missing required delivery, isolation, identity-correlation, review, or recovery
capability blocks the owning operation per the
[conditional mechanics](README.md#conditional-mechanics-shared); a missing authorized GitHub
interface follows the
[shared GitHub contract](README.md#github-capability-and-authentication-shared).
