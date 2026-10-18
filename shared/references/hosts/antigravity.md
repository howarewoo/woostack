# Antigravity CLI (`agy`)

Verified against [custom subagents](https://antigravity.google/docs/subagents/) and
[CLI features](https://antigravity.google/docs/cli/features/). Project instructions come from
`AGENTS.md`. No source-verified explicit skill invocation form is recorded in the
[host index](README.md#native-skill-invocation); use the host's own documented form.

Host-specific constraints:

- The parent agent spawns a background session through `invoke_subagent` and a transient one through
  `define_subagent`. Subagents run concurrently, start with a clean context, and do not inherit the
  parent's conversation history.
- Workspace mode is an explicit per-subagent choice: `inherit` the parent workspace, `branch` for an
  isolated Git worktree, or `share` for shared directory storage. Worktrees generated for a
  subagent are cleaned up when it is killed.
- A custom subagent is Markdown with YAML frontmatter, discovered from `.agents/agents/<name>.md` or
  `~/.gemini/config/agents/<name>.md`. `tools` is an allowlist, and a documented known issue is that
  an unmapped or misspelled tool name can hang the subagent process.
- `model` is a tier on the definition (`inherit`, `flash`, `pro`), not a dispatch argument, and
  `commandExecutionPolicy` (`off`, `auto`, `eager`, `sandbox`) sets the subagent's shell auto-execution.
- Built-in subagents are `research`, `self`, and `browser`; `browser` is invoked only through the
  `/browser` slash command.
- Subagents inherit the parent's allowed terminal command prefixes, file read/write directory
  scopes, and sandbox settings, and a permission request bubbles up to the subagent panel. `/agents`
  opens that panel, `Alt+J` in the CLI, and `/tasks` monitors background tasks.
