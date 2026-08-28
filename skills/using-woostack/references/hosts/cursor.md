# Cursor / Composer

## Detection

Cursor's Composer agent runtime; project rules load from `.cursorrules`.
Discover official Linear or Plane MCP tools exposed via Cursor Composer / `.cursorrules` MCP configuration,
selected strictly by `artifacts.provider`. Never use custom
HTTP/REST/GraphQL transport or fallback tokens. Artifact operations follow the canonical
[artifact backends contract](../../../woostack-init/references/artifact-backends.md).

## Subagent spawn

- **Primitive:** parallel subagent dispatch — submit independent tasks and let the host
  schedule or queue workers.
- **Per-call model/effort knob:** not exposed to woostack dispatch; workers run on the
  host-selected model.
- **Per-call cwd:** not exposed — tracked-file-writing workers
  fail closed before worktree reads or writes because Cursor cannot set session cwd.
  Read-only workers receive the worktree path as descriptive prompt context.

## Tier routing

No per-call tier mechanism is documented for Cursor dispatch. Treat the session's model as
the run model (single-model collapse); a forced tier applies only by changing the session
model before the run. Tier→model semantics:
[`../model-tiers.md`](../model-tiers.md).

## Host-level fallback

None documented — provider exhaustion surfaces as errors; recovery is account-level, outside
woostack's scope.
`models.<tier>` fallback lists (entries 1..n) are a documented preference order only on this
host — no spawn-time auth probe exists; switch manually by promoting an entry to entry 0.

## Per-skill notes

- **woostack-review (local swarm):** dispatch angle workers in parallel and let the host schedule
  or queue them. For validators, `reviewerSessionId` is the exact opaque Composer subagent ID
  returned by each dispatch; `reviewerCredentialContextId` is
  `cursor:composer:<subagent-id>`. Feed both into
  [Review's bound-validator sequence](../../../woostack-review/SKILL.md).
- **woostack-execute:** Cursor cannot establish session cwd for tracked-file-writing workers;
  Execute fails closed before worktree access.
- **woostack-eval (comparative dispatch):** submit the two isolated workers for each
  candidate/baseline inseparable pair together through Composer's parallel-subagent primitive.
  Cursor exposes no concrete per-call model pin; `session-default` is provable only when the
  host confirms that both workers inherit the same session model identity. Composer parallel
  subagents support comparative concurrency; a queue-only runtime cannot.

## Degradation

Tier requested but not routable per call → run at the session model and say so (degraded),
per the inline law of the dispatching skill.
When the configured provider's official MCP or a required capability is absent on this host, fail
closed for required provider boundaries or report the missing capability for optional operations per
canonical artifact law.
