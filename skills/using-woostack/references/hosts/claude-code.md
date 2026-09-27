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
- **Per-call model:** Claude Code documents `model` for a specific invocation
  ([choose a model](https://code.claude.com/docs/en/sub-agents#choose-a-model)). Normally it
  precedes the definition's `model`, `CLAUDE_CODE_SUBAGENT_MODEL`, and session model. Pass it only
  for an explicit one-run choice when the active schema and host permit it. Forced-model mode
  prevents that choice; see [Capability limits](#capability-limits).
- **Per-call effort:** not documented for a single invocation; `effort` is a definition/session
  field. Do not infer it from a role preference. An explicit optional request that cannot be
  applied is reported; a required exact effort identity needs independent host evidence.
- **Per-call cwd:** not documented — fill the dispatch-prompt worktree pin and require the worker to
  verify it before writing. A subagent *definition* can request `isolation: worktree`; that is a
  definition choice, not a per-call working directory.
- **Worker profile:** select a discovered subagent whose observed capabilities fit the task;
  `general-purpose` is the plain write-capable worker, and read-only profiles suit exploration and
  review only. Never a skill-scoped profile.

## Model selection

Without an explicit native override, use the host-selected agent/model and effort. The optional
[role preferences](../model-tiers.md) do not choose a concrete model. An explicit override uses
only a field verified in the active spawn schema and authorized by the host.

## Host-level fallback

Recovery belongs to Claude Code. A provider exhaustion error from the spawn is not a signal to
switch a repository model list; see the [shared note](README.md#host-level-fallback-shared-note).

## Per-skill notes

- **woostack-execute:** the no-per-call-cwd case — prompt pin plus self-pin guard — is the normal
  path here.
- **woostack-commit (drafting):** an optional role preference shapes the drafting task, not
  a model selector.
- **woostack-orchestrate (parallel dispatch):** for each schedule packet, dispatch one
  delivery-capable worker through the spawn tool with the prompt worktree pin. Pass `workspace`,
  `branch`, `parent_branch`, `parent_sha`, child issue URL, and packet
  `bounded_input`/`acceptance`/`checks` as the complete Execute contract. Clamp `effective_cap`
  to host capability, batch and refill as workers complete, and apply the self-pin guard per
  worker. A serialize-only mode runs at concurrency one with a clear notice; without a subagent
  spawn primitive, block rather than executing inline.

## Capability limits

With `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1`, Claude Code prevents per-invocation model selection
and ignores the subagent definition's model. It uses `CLAUDE_CODE_SUBAGENT_MODEL` when set,
otherwise the main conversation's model
([forced-model contract](https://code.claude.com/docs/en/sub-agents#run-every-subagent-on-one-model)).
Report an explicit optional override that was not applied; block a required exact identity
comparison without matching host evidence. Ordinary inheritance is not degraded. A missing
required delivery, isolation, identity-correlation, review, or recovery capability blocks per
[conditional mechanics](README.md#conditional-mechanics-shared); GitHub operations follow the
[shared GitHub contract](README.md#github-capability-and-authentication-shared).
