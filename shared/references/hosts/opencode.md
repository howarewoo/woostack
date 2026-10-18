# opencode

Verified against [agents](https://opencode.ai/docs/agents/) and
[Agent Skills](https://opencode.ai/docs/skills/). A primary agent delegates through the `task` tool;
`@mention` is how a *user* invokes a subagent in chat, not a transport an agent can call. Native
explicit skill invocation asks for the named skill, which the native `skill` tool loads as
`skill({ name: "woostack-execute" })`; every form is listed in the
[host index](README.md#native-skill-invocation).

Host-specific constraints:

- The `task` tool is gated by the host's `task` permission; `deny` on that permission leaves the
  agent no delivery primitive. `permission.task: deny` on an agent removes its subagents from the
  Task tool description, and a `hidden: true` agent is hidden from `@` autocomplete but still
  callable by the model.
- Built-in subagents are `General` (full tool access except todo), `Explore`, and `Scout`; the last
  two are read-only and cannot modify files, so they never suit a write task.
- Project and user agents are Markdown in `.opencode/agents/` and `~/.config/opencode/agents/`.
  `model` overrides the model for that agent, and unrecognized options pass straight through to the
  provider, so a provider-specific effort value belongs in the agent's own configuration.
- The `skill` tool is gated separately by the `skill` permission, so a discovered skill can still be
  unreachable; `deny` hides it from the agent entirely.
- There is no documented numeric concurrency cap, so derive concurrency from observed behavior and
  serialize with a clear notice when the build cannot run workers in parallel.
