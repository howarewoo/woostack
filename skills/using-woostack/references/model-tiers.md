# Model Tiers (shared, host-agnostic)

Canonical tier guidance for the woostack collection. Consumers resolve tiers through this file.
Each consumer keeps only its own **runtime bindings** (env vars, config paths, dispatch calls)
and points at the precedence rules below — there is no second copy of this table.

Tiers are `fast | standard | deep`. The caller selects an effective tier or uses a prompt's `tier:`
frontmatter; the runtime resolves it to a concrete model or host-owned agent capability according
to the current host's capability class. The context/summary helper subagent is implicitly `fast`.

For simple, fully specified tasks, delegating to `fast` is often much faster and cheaper than
implementing in the main session. Consider that benefit alongside dispatch, context preparation,
and verification overhead under the calling workflow's delegation rules. Delegation remains
optional; keep work inline when the total cost or risk favors it.

| Tier | Use for | Anthropic | OpenAI (Codex) | Google (Gemini) | OpenRouter |
|---|---|---|---|---|---|
| `fast` | rubric checklists, mechanical fully-specified 1–2-file tasks, context summaries | `claude-opus-4-8` + `effort: low` | `gpt-5.5` + `reasoning_effort: low` | `gemini-3-5-flash` | `openrouter/deepseek/deepseek-v4-flash` |
| `standard` | reasoning workers, multi-file integration | `claude-opus-4-8` + `effort: medium` | `gpt-5.5` + `reasoning_effort: medium` | `gemini-3-5-flash` | `openrouter/deepseek/deepseek-v4-pro` |
| `deep` | skeptical validation, design/architecture judgment, code-quality review | `claude-opus-4-8` + `effort: xhigh` | `gpt-5.5` + `reasoning_effort: high` | `gemini-3-5-flash` | `openrouter/deepseek/deepseek-v4-pro` + `reasoning_effort: xhigh` |

> **Provider notes:**
> - **Anthropic** routes every tier to `claude-opus-4-8`; model selection is a no-op, so the tier is expressed entirely through reasoning `effort` (`low` for fast, `medium` for standard, `xhigh` for deep). `effort` is a real config field (`models.anthropic.<tier>.effort`); pass it per invocation only when the active schema supports it. Otherwise use the host's documented effort inheritance and report once that the requested tier effort could not be applied.
> - **Google** currently ships only `gemini-3-5-flash` in the 3.5 line; no Pro/Ultra/Thinking variant exists yet, so all tiers collapse onto flash (tier routing is effectively a no-op until Google releases a larger model).
> - **OpenAI** GPT-5-family reasoning is a parameter on the same slug, not a slug suffix. Use `gpt-5.5` for every tier, with `reasoning_effort: low` for fast, `medium` for standard, and `high` for deep. There is no `gpt-5-pro`.
> - **OpenRouter** DeepSeek exposes exactly two slugs — `deepseek/deepseek-v4-flash` and `deepseek/deepseek-v4-pro`. Reasoning is a `reasoning_effort` parameter (`high` / `xhigh`, where `xhigh` maps to max). Use plain `v4-pro` for standard and `v4-pro` with `reasoning_effort: xhigh` for deep. Do not route to `deepseek-r1` — V4 supersedes it.

## Routing by host capability (generic)

Three capability classes: **per-call model routing** (the spawn accepts an explicit model and may
accept effort; resolve the effective tier and pass only fields the active schema supports),
**single model per session** (resolve one run model up front; per-tier behavior collapses onto it),
and **host-owned agent routing** (the spawn selects an agent exposed by the host; the host owns the
concrete model).
Host-owned routing is non-degraded only when the host proves the selected agent's capabilities;
the host adapter owns agent discovery, selection, and fallback. It never creates a repository
catalog or aliases. The [known host references](hosts/README.md) are optional mechanics recipes.
Capability evidence from the active host determines routing; host identity and file presence are not proof. For a
compatible host, its capability class, spawn mechanics, per-skill notes, and host-level fallback
behavior may live in a known host file.
The provider table remains the source of truth for hosts that consume repository model
configuration.

## Override precedence (generic)

When a host supports per-repo / per-run overrides, resolve highest-precedence first:

1. **Forced tier** — a one-run tier override.
2. **Explicit model** — an explicit model-id input.
3. **Per-provider per-tier** override key.
4. **Flat per-tier** override key.
5. **Table default** (above).

A forced tier still determines the effective tier on every host. A host-owned agent-routing host
does not resolve model-specific items 2–5 or construct a tier-to-agent map unless its host adapter
explicitly documents that capability. The caller passes the effective tier as task context and
verification depth; the host owns agent selection, concrete model identity, credentials, and
fallback. Per-call and single-session hosts continue through the full precedence above.

On repository-model hosts, each consumer binds these precedence levels to its own runtime surface.
Consumers must keep any canonicalized effective configuration and resolver defaults in sync with
the provider table above.

For hosts that consume repository model configuration, each tier leaf is a model-slug string, an
object `{ model, effort }`, **or an ordered array** of those forms (a fallback list). `effort`
(`minimal | low | medium | high | xhigh`) is a real config field: the `reasoning_effort:`
annotations in the table above are illustrative defaults, and a config-set `effort` overrides them
config-first.

**Array leaves (fallback lists):** entry 0 is the primary and carries the exact semantics of the
bare value — each repository-model consumer reads entry 0; a one-element array equals the bare
form. Entries 1..n declare a static preference order owned by woostack; runtime enactment is
per-host. Each host file's "Host-level fallback" section under [`hosts/`](hosts/README.md) states
what that host does. Host-owned agent-routing hosts bypass these leaves when their adapter says
model configuration is host-owned; hosts with repository model routing preserve their documented
resolution and fallback behavior. An empty array is a hard config error.
