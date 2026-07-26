# omp (Oh My Pi)

## Detection

The `task` tool exposes an `agent:` selector but no per-call `model`, `tier`, or `effort`
argument. omp ships dispatchable workers and resolves their model roles from omp-owned
configuration. woostack detects the `task` primitive and uses those bundled workers; it does not
expect a project agent definition.

## Subagent spawn

- **Primitive:** `task` tool, one subagent per task; dispatch independent tasks in one `tasks[]`
  call to run them in parallel.
- **Worker selector:** choose the bundled `oracle`, `task`, or `quick_task` worker from the
  effective tier mapping below.
- **Per-call model/effort knob:** none. Worker selection routes through omp's model roles.
- **Per-call cwd:** pass it when the spawn accepts one; always fill the dispatch-prompt worktree
  pin as the portable guard.

The worker names and spawn behavior are defined by omp's published
[Subagents & IRC](https://omp.sh/docs/subagents) contract.

## Tier routing

**Host-owned role routing.** After the calling skill resolves the effective woostack tier, use
this fixed map:

| Effective tier | omp model role | Built-in worker selector |
|---|---|---|
| `deep -> slow` | `slow` | `agent: oracle` |
| `standard -> default` | `default` | `agent: task` |
| `fast -> smol` | `smol` | `agent: quick_task` |

These are **role-backed built-in workers** shipped by omp. Selecting them is a full,
non-degraded routing capability even though `task` has no model argument. The generic `tier:`
metadata and any skill-level tier override still determine the effective tier; after that,
woostack applies only the fixed role/worker map above.

Do not resolve a model for an omp dispatch, inspect model leaves in `.woostack/config.json`, or
pass a repository model identity through the worker brief. omp alone resolves `slow`, `default`,
and `smol` through its
[Model roles](https://omp.sh/docs/roles) configuration and owns the concrete model, provider,
thinking level, and role overrides.

**Cross-consumer coexistence.** The shared model schema, provider table, and model resolvers remain
available to non-omp hosts and the CI single-session path. omp dispatch bypasses that repository
model layer; this exception does not change another host's resolution or override precedence.

## Host-level fallback

Fallback is entirely host-owned. omp owns provider and credential selection, credential rotation,
cooldowns, retry policy, and any temporary model fallback behind the selected role. woostack
neither reads nor manages omp model-role, fallback, or credential configuration in user or project
host config, and it never translates repository model settings into an omp retry chain.

Request the mapped built-in worker and let omp perform its own recovery. Do not redispatch an omp
worker by resolving a later repository model entry or by synthesizing another project worker. If
host recovery ends without the receipt required by the calling skill, that skill's existing
receipt or preflight gate fails loudly; review in particular must not turn a missing receipt into
an empty successful angle.

## Per-skill notes

- **woostack-init (scaffold):** no omp-specific scaffold runs. Do not create, regenerate, ignore,
  validate, or edit project `.omp/agents/*`; locally authored agents remain owned by the user.
- **woostack-commit (fast drafting):** map the drafting spawn's effective `fast` tier to
  `agent: quick_task`. If that worker cannot run, draft inline under the normal commit rule.
- **woostack-review (local swarm only):** resolve each angle's effective tier, then select
  `agent: quick_task` for `fast`, `agent: task` for `standard`, and `agent: oracle` for `deep`;
  the deep validator therefore uses `oracle`. Do not run the repository model resolver for these
  dispatches. The CI single-session path is unchanged. omp owns in-worker recovery; if recovery
  leaves any expected worker without a valid receipt, the existing hard receipt gate aborts the
  run with no project-configured fallback redispatch and no silently thinner review.
- **woostack-eval (comparative dispatch):** map the candidate and baseline's common effective tier
  to the same bundled worker and start both siblings in the same `tasks[]` call. The selector is a
  role pin, not proof of a concrete model. Use omp-provided completion identity to prove both
  actions actually ran with the required identical model and effort; an unprovable identity,
  host fallback divergence, or model/effort divergence fails the mechanics proof. Do not consult
  repository model settings to manufacture that proof. A host mode unable to start both siblings
  in the same batch fails comparative preflight.
- **woostack-execute-overnight (preflight advisory):** rely on omp's configured roles,
  authenticated providers, and host-owned recovery. Advise the user to make that host capacity
  resilient before an unattended run, but do not inspect or mutate omp role, fallback, or
  credential config and do not require a repository model list. Exhausted host recovery halts the
  track through the normal blocker path; the advisory remains a recommendation, not a refusal
  condition.

## Degradation

- Missing `task` support or an unavailable mapped built-in worker is a host capability failure,
  not a reason to generate a project worker. Follow the calling skill's existing behavior:
  review stops at preflight or the receipt gate, commit drafts inline, and execution falls back
  inline only where its driver already permits that degradation.
- A concrete model change performed by omp's own retry policy is host recovery, not failed tier
  routing. Keep the effective tier and selected worker truthful, and preserve any actual model
  identity required by the worker receipt.
