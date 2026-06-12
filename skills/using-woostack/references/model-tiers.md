# Model Tiers (shared, host-agnostic)

Canonical tier→model mapping for the woostack collection. Both `woostack-review` (angle workers +
validator) and `woostack-execute` (subagent driver) resolve tiers through this file. Each consumer
keeps only its own **runtime bindings** (env vars, config paths, dispatch calls) and points at the
precedence rules below — there is no second copy of this table.

Tiers are `fast | standard | deep`. A prompt or template declares a `tier:` in frontmatter; the
host resolves it to a concrete model via the table. The context/summary helper subagent is
implicitly `fast`.

| Tier | Use for | Anthropic | OpenAI (Codex) | Google (Gemini) | OpenRouter |
|---|---|---|---|---|---|
| `fast` | rubric checklists, mechanical fully-specified 1–2-file tasks, context summaries | `claude-haiku-4-5` | `gpt-5.3-codex-spark` + `reasoning_effort: xhigh` | `gemini-3-5-flash` | `openrouter/deepseek/deepseek-v4-flash` |
| `standard` | reasoning workers, multi-file integration | `claude-sonnet-4-6` | `gpt-5.4-mini` + `reasoning_effort: xhigh` | `gemini-3-5-flash` | `openrouter/deepseek/deepseek-v4-pro` |
| `deep` | skeptical validation, design/architecture judgment, code-quality review | `claude-opus-4-8` | `gpt-5.5` + `reasoning_effort: medium` | `gemini-3-5-flash` | `openrouter/deepseek/deepseek-v4-pro` + `reasoning_effort: xhigh` |

> **Provider notes:**
> - **Google** currently ships only `gemini-3-5-flash` in the 3.5 line; no Pro/Ultra/Thinking variant exists yet, so all tiers collapse onto flash (tier routing is effectively a no-op until Google releases a larger model).
> - **OpenAI** GPT-5-family reasoning is a parameter on the same slug, not a slug suffix. Use `gpt-5.5` with `reasoning_effort: medium` for complex review and the skeptical validator, `gpt-5.4-mini` with `reasoning_effort: xhigh` for everyday coding review, and `gpt-5.3-codex-spark` with `reasoning_effort: xhigh` for simple/cost-sensitive rubric workers and latency-first real-time coding checks. There is no `gpt-5-pro`.
> - **OpenRouter** DeepSeek exposes exactly two slugs — `deepseek/deepseek-v4-flash` and `deepseek/deepseek-v4-pro`. Reasoning is a `reasoning_effort` parameter (`high` / `xhigh`, where `xhigh` maps to max). Use plain `v4-pro` for standard and `v4-pro` with `reasoning_effort: xhigh` for deep. Do not route to `deepseek-r1` — V4 supersedes it.

## Routing by host capability (generic)

- **Per-call routing** (Claude Code `Task`, Codex local subagents with a `model` override,
  opencode `@subagent`): resolve the effective tier = a forced tier if the host sets one, else
  the prompt's own `tier:` frontmatter; map it to the column for the active provider; **pass that
  model on every spawn.** Never rely on inherited parent-session model selection when a spawn API
  accepts an explicit model.
- **Single model per session** (Codex Action without subagent model overrides, Antigravity CLI): resolve
  one run model up front; per-tier behavior collapses onto that one model for the whole job.

## Override precedence (generic)

When a host supports per-repo / per-run overrides, resolve highest-precedence first:

1. **Forced tier** — a one-run tier override.
2. **Explicit model** — an explicit model-id input.
3. **Per-provider per-tier** override key.
4. **Flat per-tier** override key.
5. **Table default** (above).

Each consumer binds these to its own surface. For example `woostack-review` binds them to
`FORCE_TIER` (Review Context) › `inputs.model` (action.yml) › `models.<provider>.<tier>` /
`models.<tier>` in `/tmp/pr-review/config.json`, resolved by `scripts/load-prompt.sh`
(`default_model_for()` is the Bash mirror of the Anthropic/OpenAI/Google/OpenRouter columns —
keep it in sync with this table).
