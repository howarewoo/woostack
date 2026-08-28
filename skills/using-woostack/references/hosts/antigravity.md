# Antigravity CLI (`agy`)

## Detection

The `agy` CLI; reads `AGENTS.md` natively; authenticates via system keyring / Google Sign-In
(no documented non-interactive API-key path, so it cannot run headless in ephemeral CI).
Discover official host-exposed Linear or Plane MCP capabilities via `AGENTS.md` / Antigravity MCP runtime;
select provider tool namespace strictly by `artifacts.provider`. Never use custom HTTP/REST/GraphQL transport
or fallback tokens. Artifact operations follow the canonical
[artifact backends contract](../../../woostack-init/references/artifact-backends.md).

## Subagent spawn

- **Primitive:** dynamically orchestrated subagents — the orchestrator instantiates one
  isolated-context subagent per task on demand. Dispatch independent tasks in a single turn
  to run them in parallel; rely on the isolation pattern for token economy.
- **Per-call model/effort knob:** no — single model per session.
- **Per-call cwd:** not exposed — tracked-file-writing workers
  fail closed before worktree reads or writes because Antigravity CLI cannot set session cwd.
  Read-only workers receive the worktree path as descriptive prompt context.

## Tier routing

**Single model per session.** Resolve one run model up front (a forced fast/deep tier if
set, otherwise standard); per-tier behavior collapses onto that one model for the whole job.
Split into multiple jobs for per-tier split behavior. Tier→model values:
[`../model-tiers.md`](../model-tiers.md).

## Host-level fallback

None documented — provider exhaustion surfaces as errors; recovery is account-level, outside
woostack's scope.
`models.<tier>` fallback lists (entries 1..n) are a documented preference order only on this
host — no spawn-time auth probe exists; switch manually by promoting an entry to entry 0.

## Per-skill notes

- **woostack-review (local swarm):** orchestrate isolated-context subagents per angle (see
  `skills/woostack-review/prompts/google.md` for the orchestration narrative). For validators,
  `reviewerSessionId` is the exact opaque isolated-context instance ID returned by each dispatch;
  `reviewerCredentialContextId` is `antigravity:context:<instance-id>`. Feed both into
  [Review's bound-validator sequence](../../../woostack-review/SKILL.md). The CI runner remains
  `run-gemini-cli` (Antigravity cannot run headless there).
- **woostack-execute:** Antigravity CLI cannot establish session cwd for tracked-file-writing
  workers; Execute fails closed before worktree access.
- **woostack-eval (comparative dispatch):** instantiate the two isolated-context workers for
  each candidate/baseline inseparable pair in the same dynamic orchestration turn. There is no
  concrete per-call model pin; choose one concrete run model before the session.
  `session-default` is provable when both workers inherit that same identified session model.
  Parallel dynamic subagents can satisfy comparative concurrency; a host mode that serializes
  the pair cannot.

## Degradation

Single-session collapse is the documented mode, not a degradation. A run that cannot resolve
any model → session default + say so, per the inline law of the dispatching skill.
When the configured provider's official MCP or a required capability is absent on this host, fail
closed for required provider boundaries or report the missing capability for optional operations per
canonical artifact law.
