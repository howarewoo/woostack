# Cursor

Verified against [subagents](https://cursor.com/docs/subagents), [rules](https://cursor.com/docs/rules),
and [Agent Skills](https://cursor.com/docs/skills). Project rules live in `.cursor/rules` as `.mdc`
files; `AGENTS.md` is a supported alternative. Native explicit skill invocation types `/` in Agent
chat and searches for the skill name; every form is listed in the
[host index](README.md#native-skill-invocation).

Host-specific constraints:

- Cursor documents subagent *definitions*, not per-call arguments. A custom subagent is Markdown
  with `name`, `description`, `model`, `readonly`, and `is_background` frontmatter, discovered from
  `.cursor/agents/` or `~/.cursor/agents/`; `.claude/agents/` and `.codex/agents/` are also read for
  compatibility, and `.cursor/` wins on a name conflict.
- `model` defaults to `inherit` and otherwise takes a model ID, with per-model options written as
  brackets, for example `claude-opus-5[effort=high]`. Model, effort, and speed are therefore
  definition choices, not dispatch arguments.
- Cursor falls back to a compatible model when the configured one is blocked by a team admin
  restriction, a legacy request-based Max Mode limit, or plan availability, so a resolved model is
  not proof of the requested one.
- Subagents share the parent agent's checkout by default, where concurrent writers can overwrite
  each other. Request isolation for separate Git worktree branches or cloud environments when
  concurrent edits need independent workspaces.
- Built-in `Explore`, `Bash`, and `Browser` subagents are host-selected; a custom subagent is
  invoked with `/name` in the prompt. A subagent starts with a clean context, so the parent passes
  everything it needs in the prompt.
- Cursor discovers skills from `.agents/skills/` and `.cursor/skills/` plus the user-level and
  Claude/Codex-compatible directories, and walks skill roots recursively.
