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
`models.<tier>` fallback lists (entries 1..n) are a documented preference order only on this
host — no spawn-time auth probe exists, so the consumer switches manually (promote an entry
to entry 0, or re-run after editing config).

## Per-skill notes

- **woostack-execute (dispatch):** the no-per-call-cwd case — prompt pin + self-pin guard —
  is the normal path here.
- **woostack-execute:** route the implementation worker at the `fast` tier per
  call; the controller retains project admission, verification, and delivery boundaries.
- **woostack-commit (fast drafting):** route the drafting subagent at the `fast` tier
  per-call.
- **woostack-review (local swarm):** dispatch every active angle task via `Task`, letting the host
  schedule; workers are `general-purpose`. For validators, `reviewerSessionId` is the exact opaque
  agent ID returned by `Task`; `reviewerCredentialContextId` is
  `claude-code:task:<agent-id>`. Feed both into
  [Review's bound-validator sequence](../../../woostack-review/SKILL.md).
- **woostack-eval (comparative dispatch):** place both isolated `general-purpose` workers for
  each candidate/baseline inseparable pair in the same `Task` dispatch turn, alongside other
  intact pairs within capacity. Pin the same concrete `model` (and exposed effort) on both
  calls. `session-default` is provable only when both calls omit `model` and the host confirms
  inheritance from the same session identity. One-turn sibling `Task` dispatch supports
  comparative concurrency; a Task mode that serializes the pair cannot.

## Degradation

A spawn that cannot carry `model` → the subagent inherits the session model: run it, and say
so (degraded), per the inline law of the dispatching skill.
