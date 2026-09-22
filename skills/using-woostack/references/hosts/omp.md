# OMP host adapter

## Detection

Use this adapter inside an active Oh My Pi session. Discover the actual `task`, `hub`, and related
capabilities available in the session. Prefer authorized native GitHub capabilities when suitable; host-authenticated `gh` remains supported for explicit
GitHub operations under the selected workflow's artifact admission. Never use custom HTTP/REST/GraphQL
transport or fallback tokens. GitHub operations follow the canonical
[artifact backends contract](../../../woostack-init/references/artifact-backends.md) and
[GitHub profile](../../../woostack-init/references/artifact-providers/github.md#configuration-and-scope).

When a woostack skill is invoked, rename the active session with a concise title derived from the
user's current goal. For `woostack-change`, `woostack-prepare`, and `woostack-execute`, derive the
title from the user's input goal; a preparation resume uses the exact verified packet goal. Do not
use the slash-command name, project or run identifier, or an untrusted remote title.

Invoke the registered tool `woostack_rename_session` with `{ "title": "<derived-title>" }`. The tool
is exposed by the local project extension `.omp/extensions/woostack-session-name.ts` provisioned by
`woostack-init` and loaded via `.omp/settings.json`. It delegates to OMP's automatic session-naming
API and preserves explicit user titles set via `/rename`. If the tool is absent, extension discovery
is disabled, or the tool call fails, emit one concise warning (`warning: OMP session renaming
unavailable; continuing with current session name`) and continue the selected workflow without
blocking.

## Subagent spawn

OMP's `task` primitive accepts an existing worker selector. It does not expose a per-call model,
tier, or working-directory argument to Woostack. Effort is conditional: when the host setting
`task.enableEffort` is enabled, inspect the active schema and use only its optional `effort` values
`"lo"`, `"med"`, or `"hi"`; otherwise omit effort. Woostack does not enable host settings or set
this optional field. OMP owns effort selection; never translate repository model-tier values into the
host knob.

When `task.batch` is enabled and the schema exposes `{ context, tasks[] }`, send dependency-independent
bounded tasks in that one call. When it is disabled, send one supported flat task shape at a time;
do not send `tasks` or `context` in that mode. Inspect the active task schema or tool description
before dispatch. A selector is not evidence of the concrete model, effort, or completion identity.

All subagents spawned via `task` run in-process within the same OMP harness session, sharing
in-memory IPC, queues, and tool bridges. External tools such as Orca cannot manage subagent processes
because inter-agent coordination depends on this in-process harness.

Select only an agent returned by session discovery. The current inventory commonly exposes a
write-capable general-purpose `task` agent plus read-only exploration and review agents, but the
active session is authoritative. Host-exposed agents are not woostack definitions: never create,
install, rename, alias, or persist a replacement catalog. A read-only agent is never suitable for a
write task.

Pass the exact resolved task workspace path in the dispatch prompt. The worker must verify that path,
branch, parent/start SHA, and allowed paths before reading or writing; `task` cannot receive a `cwd`
argument. Pass the complete task contract: repository rules, authority limits, non-goals, acceptance,
required checks and smoke scenario, and result-evidence requirements. Do not duplicate a worker
definition in the prompt. A worker must not expand its task, edit another workspace, review or accept
itself, merge, or infer hidden context.

## Agent selection and tier handling

Use a discovered `task`-equivalent agent for coding or delivery, scout-equivalent agents for read-only
exploration, and reviewer-equivalent agents for independent review. The caller may use `fast |
standard | deep` to shape task detail and verification depth, but OMP owns model/provider
configuration and recovery; never translate a tier into a worker name or model parameter.

A selector proves only that the host accepted that agent. It does not prove a concrete model,
provider, effort, or completion identity. Preserve those facts as separate host evidence whenever a
workflow requires them.

## Host-level fallback

Request the selected existing worker once and let OMP perform host-owned recovery. Do not switch
profiles, weaken worktree isolation, or treat absent evidence as success. Missing write capability
for a required coding task, missing independent review capability, or missing required result
evidence is an explicit capability failure. Inline fallback is allowed only when the calling
workflow's contract explicitly permits it; Orchestrate must block without a delivery-capable
subagent and Execute must not gain orchestration responsibilities.

## Per-skill notes

- `woostack-execute`: works inline by default; an optional discovered write-capable worker may
  implement the one supplied bounded task. Execute still owns admission, verification, Commit, and
  delivery; it does not discover or schedule additional tasks.
- **woostack-orchestrate (parallel dispatch):** preflight whether the active schema exposes the
  batch shape and whether host capacity supports the required concurrency. If batch is exposed,
  dispatch up to the effective cap in one `tasks[]` call and refill as workers complete. If it is
  not exposed, use the supported single-call shape only where Orchestrate's own contract permits it;
  never describe sequential calls as same-wave or parallel. A host mode that serializes runs at
  concurrency one gets a clear notice; without a delivery-capable subagent, block rather than
  executing inline.
- `woostack-commit`: optional fast drafting may use the discovered write-capable worker; draft inline
  when that optional capability is unavailable. Commit remains responsible for its own source-control
  and PR evidence.
- **woostack-eval (comparative dispatch):** preflight the active batch schema before dispatch. When
  it exposes `{ context, tasks[] }`, dispatch candidate and baseline siblings through the same
  discovered worker in one intact `tasks[]` wave. If `task.batch` is unavailable, stop comparative
  preflight before either sibling starts; only Eval's explicitly accepted candidate-only qualitative
  smoke branch may degrade. Leave the optional effort knob unset and freeze verified host effort
evidence where available; `null` represents unavailable evidence, not proof of equal effort. Require
evidence for the same host, runner, completion identity, model/session identity, tier, and effort
required by the frozen manifest. An unprovable identity, host fallback divergence, model/effort
divergence, incomplete receipt, or missing output/evidence blocks comparative success.

## Degradation

Missing discovered agents or host capabilities are reported precisely. The absence of retired
Woostack agent files is not a failure because Init and Doctor do not create or repair them. Preserve
the effective task tier, exact workspace, and authority boundaries, and report the actual missing
capability or receipt. Inline fallback remains subject to the calling workflow's contract.

Require each worker to return:
- exact worktree and branch/head identity;
- changed paths and bounded diff summary;
- commands run with observed results;
- smoke-test and review-relevant evidence;
- blockers or decision requests; and
- optional direct GitHub operations separately from repository results.

On incomplete or conflicting evidence, stop at the last verified boundary and preserve recoverable
work. Never claim worker coverage, test success, GitHub success, or delivery without direct read-back.

Session-naming degradation is non-blocking: if `woostack_rename_session` is unavailable or fails,
emit one concise warning and proceed with the workflow.

When no authorized GitHub interface supports a required operation capability, fail closed
for required GitHub boundaries or report the missing capability for optional operations per the
canonical artifact contract.
