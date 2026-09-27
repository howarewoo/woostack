# Codex

## Detection

Local Codex clients — CLI, IDE extension, and desktop app — enable subagent workflows by default
([subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents)). The Codex GitHub
Action instead runs one non-interactive `codex exec` step per CI job, configured by its `model` and
`effort` inputs ([Codex GitHub Action](https://learn.chatgpt.com/docs/github-action)). Discover
authorized native GitHub capabilities exposed through Codex MCP configuration; the shared
capability and authentication contract lives in the
[host index](README.md#github-capability-and-authentication-shared).
Native explicit skill invocation is `$woostack-execute` — type `$` to mention a skill, or run
`/skills` ([build skills](https://learn.chatgpt.com/docs/build-skills)); ChatGPT Work selects a
skill with `@` instead. Every form is listed in the
[host index](README.md#native-skill-invocation).

## Subagent spawn

- **Primitive:** subagent delegation on local clients. Spawning, follow-up routing, waiting, and
  closing agent threads are host-owned; the caller states how to divide the work, whether to wait,
  and what summary to return. A session that exposes no delivery-capable subagent has no delivery
  primitive.
- **Per-spawn model/effort:** Codex documents `model` and `model_reasoning_effort` as
  custom-agent and `[agents]` defaults in `config.toml`; unconfigured subagents inherit the
  parent's model and effort. For an explicit one-run choice, request the native values in the
  dispatch prompt and pass a wire field only when the active schema exposes its exact name and
  host authorization permits it. A prompt request alone is not proof the override took effect.
- **Per-call cwd:** not documented — fill the dispatch-prompt worktree pin and require the worker to
  verify it before writing.
- **Codex Action job:** one run model per job from the action's `model` and `effort` inputs. Whether
  that run can fan out is a capability of the active run to verify, not a guarantee of the action.

## Model selection

Local subagents inherit their configured or parent agent model and reasoning effort. A Codex Action
job uses its host-configured `model` and `effort` inputs for the run. Optional
[role preferences](../model-tiers.md) shape work, not provider/model selection.

## Host-level fallback

Provider errors reach the subagent if the host has no documented spawn-time recovery. Woostack
does not manually select entries from repository fallback lists; see the
[shared note](README.md#host-level-fallback-shared-note).

## Per-skill notes

- **woostack-orchestrate (parallel dispatch):** for each schedule packet, dispatch one
  delivery-capable subagent with the dispatch-prompt worktree pin. Pass `workspace`, `branch`,
  `parent_branch`, `parent_sha`, child issue URL, and packet `bounded_input`/`acceptance`/`checks`
  as the complete Execute contract; clamp `effective_cap` to real capability, refilling as
  workers complete. A Codex Action job cannot be assumed to fan out and blocks rather than
  executing inline.

## Capability limits

One model per Codex Action job is the normal host behavior. A local spawn without an explicit
model inherits its configured or parent agent model without a degradation notice. Report an
unsupported optional explicit request; block an exact-identity requirement without matching
host evidence. Missing required delivery, isolation, identity-correlation, review, or recovery
capability blocks per [conditional mechanics](README.md#conditional-mechanics-shared); GitHub
operations follow the [shared GitHub contract](README.md#github-capability-and-authentication-shared).
