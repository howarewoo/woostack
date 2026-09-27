# Codex

Verified against [subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents),
[build skills](https://learn.chatgpt.com/docs/build-skills), and the
[Codex GitHub Action](https://learn.chatgpt.com/docs/github-action). Local clients are the CLI, IDE
extension, and ChatGPT desktop app; current releases enable subagent workflows by default. Project
rules load from `AGENTS.md`. Native explicit skill invocation is `$woostack-execute` — type `$` to
mention a skill or run `/skills`; ChatGPT Work selects a skill with `@`. Every form is listed in the
[host index](README.md#native-skill-invocation).

Host-specific constraints:

- Codex owns the whole subagent lifecycle — spawning, follow-up routing, waiting, and closing agent
  threads — so a subagent prompt states how to divide the work, whether to wait, and what summary to
  return.
- A subagent inherits the parent agent's model and reasoning effort unless a spawn request, an
  `[agents]` default in `config.toml`, or the custom agent file's `model` and `model_reasoning_effort`
  selects one. A model chosen without an explicit or configured effort uses that model's default
  reasoning effort. A request written in the prompt is not proof the choice took effect.
- Subagents inherit the current sandbox policy, and on local clients the permission mode selected
  for the parent turn. ChatGPT Work instead runs subagents in a hosted environment with no local
  sandbox or approval-mode control.
- Local Codex reads skills from `.agents/skills`, `$REPO_ROOT/.agents/skills`, and
  `$HOME/.agents/skills`, and follows symlinked skill folders.
- The Codex GitHub Action runs one non-interactive `codex exec` step configured by its `model` and
  `effort` inputs, which Codex documents as the last step in a job. Whether that one run can fan out
  is a property of the run to verify, not a guarantee of the action.
