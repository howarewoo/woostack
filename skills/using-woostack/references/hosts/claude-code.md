# Claude Code

## Detection

The `Task` tool with named subagent profiles (`general-purpose` is the plain worker) and a
per-call `model` parameter; project rules load from `CLAUDE.md`.

## Subagent spawn

- **Primitive:** `Task` tool; dispatch every independent task in one turn and let the host
  handle concurrency.
- **Per-call model/effort knob:** yes — pass the resolved model (and effort form where the
  model family carries one) explicitly on every spawn.
- **Per-call cwd:** no (the `Agent`/`Task` spawn takes no cwd) — fill the dispatch-prompt
  worktree pin; the subagent self-pins and aborts if not in `$wt`.
- **Worker profile:** plain `general-purpose` for fan-out workers; never a skill-scoped
  profile.

## Tier routing

**Per-call routing.** Resolve the effective tier — a forced tier if set, else the prompt's
own `tier:` frontmatter — through the active provider's column in
[`../model-tiers.md`](../model-tiers.md) plus its override precedence, and **pass everything
the resolved tier specifies on every spawn** (the pass-or-inherit law lives in the
dispatching skill).

## Host-level fallback

None documented — Claude Code applies no host-owned usage-limit failover to spawned
subagents; provider exhaustion surfaces as errors on the spawn. Recovery is account-level
(plan limits), outside woostack's scope.

## Per-skill notes

- **woostack-execute (dispatch):** the no-per-call-cwd case — prompt pin + self-pin guard —
  is the normal path here.
- **woostack-commit (fast drafting):** route the drafting subagent at the `fast` tier
  per-call.
- **woostack-review (local swarm):** dispatch every active angle task via `Task`, letting the
  host schedule; workers are `general-purpose`.

## Degradation

A spawn that cannot carry `model` → the subagent inherits the session model: run it, and say
so (degraded), per the inline law of the dispatching skill.
