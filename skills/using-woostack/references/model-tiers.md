# Model Tiers (shared, host-agnostic)

Canonical tier→model mapping for the woostack collection. Consumers resolve tiers through this file.
Each consumer keeps only its own **runtime bindings** (env vars, config paths, dispatch calls)
and points at the precedence rules below — there is no second copy of this table.

Tiers are `fast | standard | deep`. The caller selects an effective tier or uses a prompt's `tier:`
frontmatter; the runtime resolves it to a concrete model or host-owned role according to the
current host's capability class. The context/summary helper subagent is implicitly `fast`.

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
> - **Anthropic** routes every tier to `claude-opus-4-8`; model selection is a no-op, so the tier is expressed entirely through reasoning `effort` (`low` for fast, `medium` for standard, `xhigh` for deep). `effort` is a real config field (`models.anthropic.<tier>.effort`); callers apply it per invocation.
> - **Google** currently ships only `gemini-3-5-flash` in the 3.5 line; no Pro/Ultra/Thinking variant exists yet, so all tiers collapse onto flash (tier routing is effectively a no-op until Google releases a larger model).
> - **OpenAI** GPT-5-family reasoning is a parameter on the same slug, not a slug suffix. Use `gpt-5.5` for every tier, with `reasoning_effort: low` for fast, `medium` for standard, and `high` for deep. There is no `gpt-5-pro`.
> - **OpenRouter** DeepSeek exposes exactly two slugs — `deepseek/deepseek-v4-flash` and `deepseek/deepseek-v4-pro`. Reasoning is a `reasoning_effort` parameter (`high` / `xhigh`, where `xhigh` maps to max). Use plain `v4-pro` for standard and `v4-pro` with `reasoning_effort: xhigh` for deep. Do not route to `deepseek-r1` — V4 supersedes it.

## Routing by host capability (generic)

Three capability classes: **per-call model routing** (the spawn accepts an explicit model/effort;
resolve the effective tier and pass everything it specifies), **single model per session**
(resolve one run model up front; per-tier behavior collapses onto it), and **host-owned role
routing** (the spawn selects a role-backed worker; the host owns the concrete model).
Host-owned role routing is non-degraded and bypasses repository model resolution. The canonical
[supported coding-host allowlist](hosts/README.md) gates routing before capability classification:
only an exact allowlisted slug may load its linked host mechanics. File presence alone never makes
a host routable. For an allowlisted host, its capability class, spawn mechanics, fixed role
mapping where applicable, per-skill notes, and host-level fallback behavior live in that linked
host file. The provider table remains the source of truth for hosts that consume repository model
configuration.

## Override precedence (generic)

When a host supports per-repo / per-run overrides, resolve highest-precedence first:

1. **Forced tier** — a one-run tier override.
2. **Explicit model** — an explicit model-id input.
3. **Per-provider per-tier** override key.
4. **Flat per-tier** override key.
5. **Table default** (above).

A forced tier still determines the effective tier on every host. A host-owned role-routing host
then stops at its fixed tier-to-role map: it does not resolve model-specific items 2–5, read
repository model leaves, or invoke a model resolver. The host owns role configuration, concrete
model identity, credentials, and fallback. Per-call and single-session hosts continue through the
full precedence above.

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
what that host does. Host-owned role-routing hosts bypass these leaves; hosts with repository model
routing preserve their documented resolution and fallback behavior. An empty array is a hard config
error.
