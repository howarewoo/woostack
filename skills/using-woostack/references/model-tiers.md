# Model Tiers (shared, host-agnostic)

Canonical tier→model mapping for the woostack collection. `woostack-review` (angle workers +
validator), `woostack-audit` (audit workers), and `woostack-execute` (subagent driver) resolve
tiers through this file. Each consumer
keeps only its own **runtime bindings** (env vars, config paths, dispatch calls) and points at the
precedence rules below — there is no second copy of this table.

Tiers are `fast | standard | deep`. A prompt or template declares a `tier:` in frontmatter; the
runtime either resolves that tier to a concrete model or maps it to a host-owned role, according
to the current host's capability class. The context/summary helper subagent is implicitly `fast`.

| Tier | Use for | Anthropic | OpenAI (Codex) | Google (Gemini) | OpenRouter |
|---|---|---|---|---|---|
| `fast` | rubric checklists, mechanical fully-specified 1–2-file tasks, context summaries | `claude-opus-4-8` + `effort: low` | `gpt-5.5` + `reasoning_effort: low` | `gemini-3-5-flash` | `openrouter/deepseek/deepseek-v4-flash` |
| `standard` | reasoning workers, multi-file integration | `claude-opus-4-8` + `effort: medium` | `gpt-5.5` + `reasoning_effort: medium` | `gemini-3-5-flash` | `openrouter/deepseek/deepseek-v4-pro` |
| `deep` | skeptical validation, design/architecture judgment, code-quality review | `claude-opus-4-8` + `effort: xhigh` | `gpt-5.5` + `reasoning_effort: high` | `gemini-3-5-flash` | `openrouter/deepseek/deepseek-v4-pro` + `reasoning_effort: xhigh` |

> **Provider notes:**
> - **Anthropic** routes every tier to `claude-opus-4-8`; model selection is a no-op, so the tier is expressed entirely through reasoning `effort` (`low` for fast, `medium` for standard, `xhigh` for deep). `effort` is a real config field (`models.anthropic.<tier>.effort`); the annotations above are its illustrative defaults, applied per-call in `woostack-review`'s `prompts/anthropic.md` (the CI single-session `claude-code-action` step passes only `--model`, so it cannot carry effort).
> - **Google** currently ships only `gemini-3-5-flash` in the 3.5 line; no Pro/Ultra/Thinking variant exists yet, so all tiers collapse onto flash (tier routing is effectively a no-op until Google releases a larger model).
> - **OpenAI** GPT-5-family reasoning is a parameter on the same slug, not a slug suffix. Use `gpt-5.5` for every tier, with `reasoning_effort: low` for fast, `medium` for standard, and `high` for deep. There is no `gpt-5-pro`.
> - **OpenRouter** DeepSeek exposes exactly two slugs — `deepseek/deepseek-v4-flash` and `deepseek/deepseek-v4-pro`. Reasoning is a `reasoning_effort` parameter (`high` / `xhigh`, where `xhigh` maps to max). Use plain `v4-pro` for standard and `v4-pro` with `reasoning_effort: xhigh` for deep. Do not route to `deepseek-r1` — V4 supersedes it.

## Routing by host capability (generic)

Three capability classes: **per-call model routing** (the spawn accepts an explicit model/effort;
resolve the effective tier and pass everything it specifies), **single model per session**
(resolve one run model up front; per-tier behavior collapses onto it), and **host-owned role
routing** (the spawn selects a role-backed worker; the host owns the concrete model).
Host-owned role routing is non-degraded and bypasses repository model resolution. Which class a
host falls in, its spawn mechanics, its fixed role mapping where applicable, its per-skill notes,
and its host-level fallback behavior live in one file per host under
[`hosts/`](hosts/README.md). The provider table and `resolve-model.sh` remain unchanged for CI and
other hosts that consume repository model configuration.

**Host mechanics:** before any host-dependent step (subagent dispatch, scaffold, draft), load `skills/using-woostack/references/hosts/<current-host>.md`; no matching file -> treat the host as having no per-call routing and say so (degraded).

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

On repository-model hosts, each consumer binds these to its own surface. For example
`woostack-review` binds them to
`FORCE_TIER` (Review Context) › `inputs.model` (action.yml) › **root** `models.<provider>.<tier>` /
`models.<tier>` in the consumer `.woostack/config.json` (canonicalized into
`/tmp/pr-review/config.json`), resolved by `scripts/load-prompt.sh` (`default_model_for()` is the
Bash mirror of the Anthropic/OpenAI/Google/OpenRouter columns — keep it in sync with this table).

For hosts that consume repository model configuration, each tier leaf is a model-slug string, an
object `{ model, effort }`, **or an ordered array** of those forms (a fallback list). `effort`
(`minimal | low | medium | high | xhigh`) is a real config field: the `reasoning_effort:`
annotations in the table above are illustrative defaults, and a config-set `effort` overrides them
config-first in `load-prompt.sh` (precedence: action input → config `effort` → tier default).

**Array leaves (fallback lists):** entry 0 is the primary and carries the exact semantics of the
bare value — every repository-model resolver (`load-prompt.sh` and `resolve-model.sh`) reads entry
0; a one-element array equals the bare form. Entries 1..n declare a static preference order owned
by woostack; runtime enactment is per-host. Each host file's "Host-level fallback" section under
[`hosts/`](hosts/README.md) states what that host does. Host-owned role-routing hosts bypass these
leaves entirely; hosts with repository model routing preserve their documented resolution and
fallback behavior. An empty array is a hard config error.
