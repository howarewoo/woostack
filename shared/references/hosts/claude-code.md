# Claude Code

Verified against [custom subagents](https://code.claude.com/docs/en/sub-agents) and the
[tools reference](https://code.claude.com/docs/en/tools-reference). Project rules load from
`CLAUDE.md`. Native explicit skill invocation is `/woostack-execute`
([skills](https://code.claude.com/docs/en/skills)); every form is listed in the
[host index](README.md#native-skill-invocation).

Host-specific constraints:

- The subagent spawn tool is documented as `Agent` (`Task` in older builds). A call that omits
  `subagent_type` fails with `subagent_type is required` when the session has no `general-purpose`
  subagent to fall back on. A session that denies the spawn tool has no subagent primitive.
- Subagent model order: the per-invocation `model` parameter, the definition's `model` frontmatter,
  `CLAUDE_CODE_SUBAGENT_MODEL`, then the main conversation's model
  ([choose a model](https://code.claude.com/docs/en/sub-agents#choose-a-model)). `effort` is a
  definition or session field, not a per-invocation one, and a family alias in the first two
  sources can resolve to the main conversation's model instead of that family's version.
- `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` removes the first two sources: subagents run on
  `CLAUDE_CODE_SUBAGENT_MODEL` when both variables are set, otherwise on the main conversation's
  model ([forced-model contract](https://code.claude.com/docs/en/sub-agents#run-every-subagent-on-one-model)).
- A subagent starts in the main conversation's working directory. `isolation: worktree` is a
  definition frontmatter choice, not a per-call working directory.
- `general-purpose` is the write-capable built-in; `Explore` and `Plan` are read-only (Write and
  Edit denied). A user or project subagent named `Explore` overrides the built-in.
