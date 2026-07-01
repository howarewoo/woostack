---
name: review-anthropic-effort-is-per-call-not-load-prompt
type: gotcha
scope: skills/woostack-review/**,skills/using-woostack/references/**
tags: woostack-review, anthropic, effort, model-tiers, load-prompt, claude-code-action, blast-radius
hook: Anthropic per-tier reasoning effort in woostack-review is applied PER-CALL in prompts/anthropic.md, never in load-prompt.sh (its effort branch is openai-gated) — the CI single-session claude-code-action step passes only --model, so it cannot carry effort. Changing the Anthropic default tier touches ~8 sites.
updated: 2026-07-01
source: [[fixes/2026-07-01-anthropic-opus-effort-tiers]]
---
`load-prompt.sh` computes/emits `run_effort` **only when `PROVIDER == openai`** (the whole effort
block is `if [ "$PROVIDER" = "openai" ]`), and `default_openai_effort_for` is the only per-tier
effort-default mirror. There is deliberately **no** `default_anthropic_effort_for`: the CI Anthropic
runner (`action.yml`, `anthropics/claude-code-action`) passes only `--model ${run_model}` — unlike the
Codex step's `effort: ${run_effort}` — so an emitted Anthropic `run_effort` would be dead output.

Anthropic effort is therefore a **per-call** concern: the orchestrator in `prompts/anthropic.md`
resolves it (config `models.anthropic.<tier>.effort` → tier default) and passes `effort:` on each
`Task` spawn, **conditionally** ("if the spawn API accepts a reasoning-effort override" — same hedge
as `openai.md`). `config_effort_for` in `load-prompt.sh` is already provider-generic, but nothing
Anthropic-side calls it.

**Blast radius when changing an Anthropic default tier** (e.g. all-Opus + per-tier effort): the
executable slug mirror `scripts/resolve-model.sh::default_model_for` **and** its assertions in
`tests/test-resolve-model.sh`; the canonical table + provider note in
`using-woostack/references/model-tiers.md`; `prompts/anthropic.md` (inline tier mention, routing
rule/example, Step-1 context subagent, Step-2 per-angle mapping, validator); `woostack-review/SKILL.md`
(tier table, provider note, the config-override *example* leaf, the key-reference effort line); and the
authored site tables `configuration.mdx`, `concepts.mdx`, `concepts/context-management.mdx`.

Leave alone: the `_header.md`/`opencode.md` credits-line **examples** (they intentionally show a
non-default route for introspection), the `test-verify-receipts-*` fixtures (fixed model strings, not
default assertions), and the generated `site/content/docs/skills/*.mdx` (regenerate from `SKILL.md`).
When every tier is one model, model routing is a no-op and **effort is the sole tier differentiator** —
if effort does not actually reach the worker, fast/standard/deep collapse to identical runs.
Related: [[review-add-angle-sites]], [[authored-mdx-escapes-jsx-and-table-pipes]].
