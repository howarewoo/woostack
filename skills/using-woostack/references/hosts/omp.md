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
`task.enableEffort` is enabled, the active schema adds optional `effort` with exactly `"lo"`,
`"med"`, or `"hi"`; otherwise that field is absent. Inspect the active task schema or tool
description before dispatch. Woostack does not enable host settings or set this optional effort
field. OMP owns effort selection; record verified host effort evidence separately rather than
translating repository model-tier values into the host knob. A selector is not evidence of the
model or effort actually used.

The conditional schema and setting are documented in OMP's [task-agent discovery reference](https://github.com/can1357/oh-my-pi/blob/main/docs/task-agent-discovery.md)
and implemented by [`task/types.ts`](https://github.com/can1357/oh-my-pi/blob/main/packages/coding-agent/src/task/types.ts).
The dispatch-time setting and rejection path are in
[`task/index.ts`](https://github.com/can1357/oh-my-pi/blob/main/packages/coding-agent/src/task/index.ts).
For evidence-bearing workflows, verify returned effort evidence against the resolved configuration;
absent or mismatched evidence blocks a required comparison.
All subagents spawned via `task` run in-process within the same OMP
harness session, sharing in-memory IPC, queues, and tool bridges. External tools (such as Orca)
cannot manage subagent processes because inter-agent coordination depends on this in-process
harness.

Select only an agent actually returned by session discovery. The current OMP inventory exposes:

- `task` — the write-capable general-purpose agent for implementation and delivery work;
- `scout` — a read-only agent for exploration and source analysis; and
- `reviewer` and `security-reviewer` — read-only agents for independent review.

These are host-owned agents, not woostack definitions. Do not create, install, rename, alias, or
persist a replacement catalog. If the active session exposes a different name, use that discovered
name only when its observed capabilities satisfy the task. A read-only agent is never suitable for
a write task.

Inspect the active task tool schema or description before choosing a wire shape. When `task.batch`
is enabled and the schema exposes `{ context, tasks[] }`, send dependency-independent bounded
tasks in that one call. When it is disabled, send one flat `{ agent?, task, ... }` call at a time
where the workflow permits it. Do not send `tasks` or `context` in that mode; OMP rejects those
fields before a worker starts.
Pass the exact resolved task workspace path in the dispatch prompt. The worker must verify that
path, branch, parent/start SHA, and allowed paths before reading or writing; `task` cannot receive
a `cwd` argument.
Pass the complete task contract: repository rules, authority limits, non-goals, acceptance,
required checks and smoke scenario, and result-evidence requirements. Do not duplicate a worker
definition in the prompt.
- A worker must not expand its task, edit another workspace, review or accept itself, merge, or
  infer hidden context.

## Agent selection and tier handling

Use the discovered `task`-equivalent agent for coding or delivery, `scout`-equivalent agents for
read-only exploration, and `reviewer`-equivalent agents for independent review. The caller may use
`fast | standard | deep` to shape task detail and verification depth, but OMP owns model/provider
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
  evidence where available; `null` represents unavailable evidence, not proof of equal effort.
  The selector is not proof of model or effort identity. Require evidence for the same host, runner,
  completion identity, model/session identity, tier, and effort required by the frozen manifest.
  An unprovable identity, host fallback divergence, model/effort divergence, incomplete receipt, or
  missing output/evidence blocks comparative success.

## Safe cleanup of retired generated definitions

`woostack-init` no longer creates `.omp/agents/` files or installs an agent-specific ignore rule.
Existing files are user content and are not inspected or repaired by Init or Doctor. Cleanup is
optional and manual; do not add a migration subsystem for it.

To remove only unchanged files generated by the retired provisioner, resolve the selected consumer
repository to a canonical root and confirm each candidate was created by an older Woostack Init.
An exact byte match is required but is not, by itself, proof of ownership. Obtain the historical
provisioner from a separately verified `howarewoo/woostack` checkout at pre-retirement commit
`cb3bbdc5789677bef2628390361ec9aa42e4827a`; do not assume that commit exists in the consumer
repository. If the trusted source is unavailable, preserve the files for manual review.

Generate expected bytes in a separate temporary directory whose absolute path is canonicalized
before invoking the historical provisioner. Never run it against the consumer repository.
Reject symlinked consumer `.omp` or `agents` directories. Compare each candidate with `cmp` and
remove only a regular, non-symlink `.omp/agents/woostack-{fast,standard,deep}.md` file whose bytes
match exactly and whose generated provenance is confirmed. Skip missing, modified, malformed,
user-authored, or symlinked files. Keep every other agent and configuration entry.

Leave `.omp/agents/.gitignore` and unrelated ignore entries unchanged unless a user has separately
confirmed, by provenance rather than filename, that a standalone `woostack-*.md` line was generated
by Woostack. Any ambiguous, modified, symlinked, or user-owned entry stays in place for manual
review. Repeating the comparison/removal is idempotent and never follows or deletes a symlink
target.

## Degradation

Missing discovered agents or host capabilities are reported precisely. Absence of the retired
Woostack agent files is not a failure. Preserve the effective task tier, exact workspace, and
authority boundaries, and report the actual missing capability or receipt.

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
