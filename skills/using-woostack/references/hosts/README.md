# Host references

These notes are optional. Read a host's page only when that host's own mechanics matter for the
step at hand — a specific primitive name, a documented limitation, or an install note. The active
tool schema and the host's own permissions already define what a call may contain; nothing here
reconstructs them, and this list is not a support matrix or a routing registry. An unlisted host
that exposes the needed capability is usable, and a listed host that does not is not a blocker for
work that does not need it.

- [`claude-code`](claude-code.md)
- [`codex`](codex.md)
- [`cursor`](cursor.md)
- [`antigravity`](antigravity.md)
- [`opencode`](opencode.md)
- [`omp`](omp.md)

## Native skill invocation

Public skill names are stable across hosts: `woostack-init`, `woostack-execute`, and every other
`woostack-*` skill keep one name and one contract. A `/woostack-<name>` example states the logical
command or request; the host's native explicit invocation can differ. Use the form the active host
documents and treat it as the same skill, not a new command. Every example below cites the official
documentation it was verified against.

| Host | Documented explicit invocation | Official source |
| --- | --- | --- |
| Claude Code | `/woostack-execute` — the skill directory name, or the frontmatter `name`, becomes the command | [Extend Claude with skills](https://code.claude.com/docs/en/skills) |
| Codex | `$woostack-execute` — type `$` to mention a skill, or run `/skills`; ChatGPT Work selects a skill with `@` | [Build skills](https://learn.chatgpt.com/docs/build-skills) |
| Cursor | `/woostack-execute` — type `/` in Agent chat and search for the skill name | [Agent Skills](https://cursor.com/docs/skills) |
| OMP | `/skill:woostack-execute` — registered per discovered skill when `skills.enableSkillCommands` is enabled | [Skills](https://github.com/can1357/oh-my-pi/blob/main/docs/skills.md) |
| OpenCode | Ask for the named skill; the native `skill` tool loads `skill({ name: "woostack-execute" })` | [Agent Skills](https://opencode.ai/docs/skills/) |

A version-specific example is documentation evidence, not proof of the active session's schema:
confirm the discovered skill name and the host's own command form in the running host. Native
invocation changes how a skill is requested, never its semantics, its public name, or its
authorization boundaries. Antigravity CLI has no source-verified invocation form recorded here; use
the host's own documented form.
