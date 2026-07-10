# Cursor / Composer

## Detection

Cursor's Composer agent runtime; project rules load from `.cursorrules`.

## Subagent spawn

- **Primitive:** parallel subagent dispatch — submit independent tasks and let the host
  schedule or queue workers.
- **Per-call model/effort knob:** not exposed to woostack dispatch; workers run on the
  host-selected model.
- **Per-call cwd:** not exposed — fill the dispatch-prompt worktree pin; the subagent
  self-pins.

## Tier routing

No per-call tier mechanism is documented for Cursor dispatch. Treat the session's model as
the run model (single-model collapse); a forced tier applies only by changing the session
model before the run. Tier→model semantics:
[`../model-tiers.md`](../model-tiers.md).

## Host-level fallback

None documented — provider exhaustion surfaces as errors; recovery is account-level, outside
woostack's scope.

## Per-skill notes

- **woostack-review (local swarm):** dispatch angle workers in parallel and let the host
  schedule or queue them.

## Degradation

Tier requested but not routable per call → run at the session model and say so (degraded),
per the inline law of the dispatching skill.
