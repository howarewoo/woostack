# OMP

Verified against [task-agent discovery](https://github.com/can1357/oh-my-pi/blob/main/docs/task-agent-discovery.md)
and [skills](https://github.com/can1357/oh-my-pi/blob/main/docs/skills.md). Native explicit skill
invocation is `/skill:woostack-execute`; interactive mode registers one command per discovered skill
when `skills.enableSkillCommands` is enabled. Every form is listed in the
[host index](README.md#native-skill-invocation).

## Delegation

`task` takes an existing worker selector and exposes no model or working-directory argument. Model
precedence is `task.agentModelOverrides` for that agent, then the agent frontmatter `model` list,
then the parent's active model. A selector proves the host accepted that agent, not which model,
provider, or effort ran; keep those as separate evidence when a workflow needs them.

Effort is conditional on a host setting: with `task.enableEffort` enabled (default `false`) the task
schema adds an optional `effort` of exactly `lo`, `med`, or `hi`, and it is absent otherwise. Woostack
does not enable host settings or set that field. Verify returned effort evidence against the resolved
configuration; absent or mismatched evidence blocks a required comparison.

`task.batch` changes the wire shape. Inspect the active schema: when batch is enabled, send
dependency-independent tasks in one call; otherwise send one flat call at a time. OMP rejects
`tasks` and `context` in the flat form before a worker starts.

`task` has no `cwd`, so pass the selected workspace in the task and require the worker to verify its
checkout, branch and base, and affected paths before writing. Subagents run in-process in the same
OMP harness session, sharing in-memory IPC, queues, and tool bridges, so an external tool cannot
manage their processes.

Use only agents the session actually exposes. OMP's bundled set includes `task` (write-capable
general work), `scout` (read-only exploration), and `reviewer` and `security-reviewer` (read-only
review). They are host-owned: never create, install, rename, alias, or persist a replacement agent
catalog, and a read-only agent never suits a write task.

## Retired session naming

Automatic session naming is retired. Woostack no longer ships a naming extension, Init and Doctor
no longer create, repair, or check `.omp/` naming assets, and no skill calls a naming tool. The
host and user own session titles.

Already-installed `.omp/extensions/woostack-session-name.ts`, its `.omp/settings.json` entry, and
its `.omp/.gitignore` lines are user data: nothing rewrites, strips, or removes them, and a
retained extension may stay active under OMP until the user removes it.

## Previously generated agent definitions

`woostack-init` no longer creates `.omp/agents/` files or an agent-specific ignore rule, and Doctor
neither inspects nor repairs them; their absence is normal and never a failure. OMP itself still
discovers project agents from `.omp/agents/*.md`, so existing files are live user content.

A repository may still hold `.omp/agents/woostack-{fast,standard,deep}.md` from the retired
provisioner. Cleanup is optional, manual, and user-initiated; woostack never runs it and there is no
migration subsystem. The exact-byte plus provenance recipe that guards removal is in the
[OMP harness guide](https://github.com/howarewoo/woostack/blob/main/site/content/docs/harnesses/omp.mdx#previously-generated-agent-definitions).
