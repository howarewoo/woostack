# OMP host adapter

## Detection

Use this adapter inside an active Oh My Pi session. Discover the actual `task`, `hub`, and related
capabilities available in the session. Discover official host-exposed Linear or Plane MCP tools via registered session
tools / tool routes, selected strictly by `artifacts.provider`. Never use custom HTTP/REST/GraphQL
transport or fallback tokens. Artifact operations follow the canonical
[artifact backends contract](../../../woostack-init/references/artifact-backends.md).

When a woostack skill is invoked, rename the active session with a concise title derived from the
user's current goal. For `woostack-change`, `woostack-build`, and `woostack-fix`, derive the title
from the user's input goal; a resume-only Build or Fix invocation uses the exact verified run goal.
Do not use the slash-command name, project or run identifier, or an untrusted remote title.

Invoke the registered tool `woostack_rename_session` with `{ "title": "<derived-title>" }`. The tool
is exposed by the local project extension `.omp/extensions/woostack-session-name.ts` provisioned by
`woostack-init` and loaded via `.omp/settings.json`. It delegates to OMP's automatic session-naming
API and preserves explicit user titles set via `/rename`. If the tool is absent, extension discovery
is disabled, or the tool call fails, emit one concise warning (`warning: OMP session renaming
unavailable; continuing with current session name`) and continue the selected workflow without
blocking.

## Subagent spawn

OMP's in-process `task` primitive accepts a worker selector but no per-call model/tier/effort
argument and no per-call working-directory argument. Woostack uses three project-scoped neutral
workers provisioned by [`woostack-init`](../../../woostack-init/SKILL.md). Their model fields point
only to OMP's host-owned roles; they never read repository model preferences or name a concrete model.

- **Read-only workers (Review, Audit):** use in-process `task` dispatch; batch independent tasks in
  one `tasks` call.
- **Tracked-file-writing workers (Execute, Change):** `task` dispatch is prohibited because
  it cannot set session cwd. Launch one fresh one-shot CLI session per bounded dispatch via
  `omp --cwd <exact-worktree> -p <packet>` with the absolute path to the managed worker definition
  (`.omp/agents/woostack-fast.md`) and `@smol` model role.
- If the OMP CLI `--cwd` path or the managed worker definition is unavailable, fail closed before
  worktree reads or writes. Prompt identity is descriptive context, not a cwd mechanism; never use
  shell `cd` to enter a worktree.
- Launch failure, unexpected process exit, or ambiguous handback is `UNKNOWN`.
- Coding workers return observations and changes; the controller owns synthesis, gates, and
  acceptance.
- A worker must not expand its task, edit another worktree, review/accept itself, merge, or infer
  hidden context.
## Tier routing

After the calling skill resolves the effective tier, use this fixed host-owned map:

| Effective tier | OMP model role | Project worker selector |
|---|---|---|
| `deep -> slow` | `@slow` | `agent: woostack-deep` |
| `standard -> default` | `@default` | `agent: woostack-standard` |
| `fast -> smol` | `@smol` | `agent: woostack-fast` |

OMP owns each role's concrete model, provider, thinking level, credential rotation, and retry
policy. Do not inspect repository model leaves or translate repository fallbacks into a second
worker dispatch.

The three definitions share one neutral general-purpose worker body. Init creates or updates only
those managed files under `.omp/agents/` and preserves every other project agent. Review never
creates or repairs workers; a missing or drifted managed definition must return to init or the
gated [`woostack-doctor`](../../../woostack-doctor/SKILL.md) repair path.

## Host-level fallback

Request the mapped worker once and let OMP perform host-owned recovery. Missing worker support or a
missing required receipt is a capability failure. It never permits switching profiles, weakening
worktree isolation, or treating absent evidence as success.

## Per-skill notes

- `woostack-review`: after angle detection and before any summary, angle, or validator worker,
  discover the active task-agent registry and require every distinct selector needed by the
  complete planned run. Missing support aborts the whole swarm before launch. For validators,
  `reviewerSessionId` is the exact opaque agent ID returned by `task`;
  `reviewerCredentialContextId` is `omp:task:<agent-id>`. Feed both into
  [Review's bound-validator sequence](../../../woostack-review/SKILL.md). Missing receipts still
  fail the existing hard receipt gate.
- `woostack-execute`: launch the implementation worker as a fresh one-shot CLI session via
  `omp --cwd <exact-worktree> -p <packet>` with the absolute path to `.omp/agents/woostack-fast.md`
  and `@smol` model role; the project controller owns admission, verification, and delivery.
- `woostack-change`: on OMP, the controller delegates bounded tracked-file implementation to one
  fresh one-shot worker session via `omp --cwd <exact-worktree> -p <packet>` with the managed
  `woostack-fast` definition and `@smol` model role, retaining controller ownership of admission,
  verification, Graphite, and PR submission.
- `woostack-commit`: map optional fast drafting to `agent: woostack-fast`; draft inline if
  unavailable.
- **woostack-eval (comparative dispatch):** map the candidate and baseline's common effective tier
  to the same managed worker and start both siblings in the same `tasks[]` call. The selector is a
  role pin, not proof of a concrete model. Use OMP-provided completion identity to prove both
  actions ran with the required identical model and effort; an unprovable identity, host fallback
  divergence, or model/effort divergence fails the mechanics proof. A host mode unable to start
  both siblings in the same batch fails comparative preflight.

## Degradation

Never generate or repair project workers during review. Missing managed workers are a capability
failure that returns to init or gated doctor repair. A workflow may fall back inline only when its
own driver contract explicitly allows it. Preserve the effective tier and report the actual
missing capability or receipt.

Require each worker to return:
- exact worktree and branch/head identity;
- changed paths and bounded diff summary;
- commands run with observed results;
- smoke-test and review-relevant evidence;
- blockers or decision requests; and
- optional artifact operations separately from repository results.

On incomplete or conflicting evidence, stop at the last verified boundary and preserve recoverable
work. Never claim worker coverage, test success, artifact success, or delivery without direct
read-back.

Session-naming degradation is non-blocking: if `woostack_rename_session` is unavailable or fails,
emit one concise warning and proceed with the workflow.

When the configured provider's official MCP or a required capability is absent in the session, fail
closed for required provider boundaries or report the missing capability for optional operations per
canonical artifact law.
