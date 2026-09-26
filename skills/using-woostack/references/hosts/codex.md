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
- **Per-spawn model/effort:** documented as configuration and prompt request, not as a wire field.
  Codex documents `model` and `model_reasoning_effort` as custom-agent and `[agents]` defaults in
  `config.toml`; a spawn can request a model or reasoning effort in the prompt; and an
  unconfigured subagent inherits the parent agent's model and reasoning effort. State the requested
  values in the dispatch prompt, and pass a field only when the active schema exposes that exact
  name. Never derive a per-call argument name from the repository tier table.
- **Per-call cwd:** not documented — fill the dispatch-prompt worktree pin and require the worker to
  verify it before writing.
- **Codex Action job:** one run model per job from the action's `model` and `effort` inputs. Whether
  that run can fan out is a capability of the active run to verify, not a guarantee of the action.

## Tier routing

- **Local (per-spawn routing when available):** resolve the effective tier through the OpenAI
  column in [`../model-tiers.md`](../model-tiers.md) plus its override precedence, then request it
  through the dispatch prompt or the documented agent configuration keys.
- **Codex Action (one run model per job):** resolve one run model up front (a forced fast/deep tier
  if set, otherwise standard); per-tier behavior collapses onto that model for the whole job.
  Split into multiple jobs for per-tier split behavior.

## Host-level fallback

None documented at the subagent layer — usage-limit exhaustion surfaces as provider errors, and
account-level recovery (a second login, plan quota) is outside woostack's scope. The
[shared fallback note](README.md#host-level-fallback-shared-note) applies to `models.<tier>` lists.

## Per-skill notes

- **woostack-orchestrate (parallel dispatch):** for each schedule packet, dispatch one
  delivery-capable subagent with the dispatch-prompt worktree pin. Pass `workspace`, `branch`,
  `parent_branch`, `parent_sha`, child issue URL, and packet `bounded_input`/`acceptance`/`checks`
  as the complete Execute contract; use the tier routing above and clamp `effective_cap` to real
  capability, refilling as workers complete. A Codex Action job cannot be assumed to fan out and
  blocks rather than executing inline.

## Degradation

One run model per job (Codex Action) is not a degradation — it is the documented collapse for that
surface. A local spawn with no configured or requested model inherits the parent agent's model and
reasoning effort: run it and say so once (degraded), per the inline law of the dispatching skill.
A missing required delivery, isolation, identity-correlation, review, or recovery capability
blocks the owning operation per the
[conditional mechanics](README.md#conditional-mechanics-shared); a missing authorized GitHub
interface follows the
[shared GitHub contract](README.md#github-capability-and-authentication-shared).
