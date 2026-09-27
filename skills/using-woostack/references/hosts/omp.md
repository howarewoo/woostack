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

## Session naming

When a woostack skill is invoked, call the registered tool `woostack_rename_session` with
`{ "title": "<derived-title>" }` and a concise title derived from the user's input goal. For
issue-backed Execute with no explicit goal, the exact user-supplied issue reference may be the
title — not remote issue content or title, a slash-command name, a run identifier, or an untrusted
remote title.

The tool comes from the local extension `.omp/extensions/woostack-session-name.ts` provisioned by
`woostack-init`, which delegates to OMP's automatic session-naming API and preserves a title set
explicitly with `/rename`. OMP loads project extensions and settings at startup, so restart it after
installing or repairing. If the tool is absent, extension discovery is disabled, or the call fails,
emit one concise warning (`warning: OMP session renaming unavailable; continuing with current session
name`) and continue the selected workflow without blocking.

## Previously generated agent definitions

`woostack-init` no longer creates `.omp/agents/` files or an agent-specific ignore rule, and Doctor
neither inspects nor repairs them; their absence is normal and never a failure. OMP itself still
discovers project agents from `.omp/agents/*.md`, so existing files are live user content.

A repository may still hold `.omp/agents/woostack-{fast,standard,deep}.md` from the retired
provisioner. Cleanup is optional, manual, and user-initiated; woostack never runs it and there is no
migration subsystem. The exact-byte plus provenance recipe that guards removal is in the
[OMP harness guide](https://github.com/howarewoo/woostack/blob/main/site/content/docs/harnesses/omp.mdx#previously-generated-agent-definitions).
