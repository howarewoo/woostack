# Host references

These known host files are mechanics recipes for hosts that expose the needed capabilities:

- [`claude-code`](claude-code.md)
- [`codex`](codex.md)
- [`cursor`](cursor.md)
- [`antigravity`](antigravity.md)
- [`opencode`](opencode.md)
- [`omp`](omp.md)

File presence and host identity do not prove support or add a routing registry. Before a
host-dependent step, verify from the active host that an authorized mechanism actually provides the
capability and operation shape the consuming skill requires. A known host without those capabilities
still fails; a compatible unlisted host may be used. Do not guess an adapter, construct a path from
host text, or read an arbitrary file. Record capability evidence separately from real execution.

Consuming skills keep their generic capability and evidence gates inline. Host files hold
mechanics (primitive names, native knob forms, agent selectors); a mechanics sentence lives in
one host file rather than being duplicated in a skill.

## Conditional mechanics (shared)

Every adapter follows these rules; an adapter states a host's own documented facts and the checks
that confirm them, and never restates this list.

1. The active authorized tool schema and discovered agent capabilities decide valid wire
   arguments. A host name, adapter file, or example is not proof of `model`, effort, `cwd`,
   batching, parallelism, permissions, or recovery support. An adapter never mandates an argument
   the active schema may not carry.
2. Select an agent the host actually exposes, and only when its observed capabilities fit the
   work: read-only for exploration and review, write-capable for implementation and delivery.
   Never invent an agent name and never turn a `fast | standard | deep` tier into an agent
   selector.
3. Pass optional native model and effort fields only for an explicit one-run choice, when the
   active schema exposes their exact names and the host authorizes them. A role preference is
   never an override. Omit every unsupported optional field.
4. Missing `cwd` is not missing isolation when the required safe path is otherwise supported:
   keep the task-level workspace pin, require the worker to verify repository, branch, parent, and
   start before it writes, and treat a mismatch as a blocker.
5. Normal host model/effort inheritance needs no notice. Report an optional explicit override
   that could not be applied; if exact identity is required and unsupported or unproven, block
   that operation. Missing required delivery, isolation, identity-correlation, review, or recovery
   capability also blocks. Never execute Orchestrate inline or describe sequential dispatch as
   one parallel wave.

## GitHub capability and authentication (shared)

Adapters keep only their own host's GitHub discovery surface and link here. Prefer an authorized
native capability; host-authenticated GitHub CLI (`gh`) remains supported for explicit GitHub
operations under the selected workflow's admission. Discover actual GitHub operation capabilities
and read/write shapes rather than assuming tool names or schemas. Never use custom
HTTP/REST/GraphQL transport or fallback tokens. The selected operation loads its owning references.
If no authorized interface (native capability or host-authenticated `gh`) supports a required
operation, fail closed for that GitHub boundary; for an optional operation, report the missing
capability under the owning workflow. No transport fallback, credential probing, or permission
change belongs here.

## Host-level fallback (shared note)

Model recovery belongs to the host. If the host documents no spawn-time recovery, a provider
error reaches the spawn; Woostack does not enact a repository fallback list, probe accounts,
or switch models on behalf of the host.

## Native skill invocation

Public skill names are stable across hosts: `woostack-init`, `woostack-execute`, and every other
`woostack-*` skill keep one name and one contract. A `/woostack-<name>` example states the logical
command or request; the host's native explicit invocation can differ. Use the form the active host
documents and treat it as the same skill, not a new command. Every example below cites the
official documentation it was verified against.

| Host | Documented explicit invocation | Official source |
| --- | --- | --- |
| Codex | `$woostack-execute` — type `$` to mention a skill, or run `/skills` | [Build skills](https://learn.chatgpt.com/docs/build-skills) |
| Claude Code | `/woostack-execute` — the skill directory name, or the frontmatter `name`, becomes the command | [Extend Claude with skills](https://code.claude.com/docs/en/skills) |
| OMP | `/skill:woostack-execute` — registered per discovered skill when `skills.enableSkillCommands` is enabled | [Skills](https://github.com/can1357/oh-my-pi/blob/main/docs/skills.md) |
| OpenCode | Ask for the named skill; the native `skill` tool loads `skill({ name: "woostack-execute" })` | [Agent Skills](https://opencode.ai/docs/skills/) |

A version-specific example is documentation evidence, not proof of the active session's schema:
confirm the discovered skill name and the host's own command form in the running host. Native
invocation changes how a skill is requested, never its semantics, its public name, or its
authorization boundaries. Cursor and Antigravity CLI have no source-verified invocation form
recorded here; use each host's own documented form and keep the capability-conditional wording.

## Section contract

Every known host file carries these six sections, in order:

1. **Detection** — capability signals that identify the host, plus its native invocation form.
2. **Subagent spawn** — primitive name; documented native model/effort and `cwd` fields (verified
   against the active schema); parallel dispatch shape.
3. **Model selection** — the host's ordinary inheritance and supported explicit one-run fields,
   following [role preferences](../model-tiers.md).
4. **Host-level fallback** — host-owned recovery and its documented boundary.
5. **Per-skill notes** — host-specific steps consumed by named skills.
6. **Capability limits** — host-specific unavailable capabilities, without treating ordinary model
   inheritance as degradation.

The conditional mechanics, GitHub capability and authentication, and native-invocation rules live
in this index only. An adapter links to them instead of copying them.
