---
name: review-openai-tier-effort-override
type: gotcha
scope: skills/woostack-review/**
tags: load-prompt, openai, codex, reasoning_effort, inputs.openai_effort, model-tiers
hook: OpenAI reasoning effort defaults (medium for deep, xhigh for standard/fast) must be configured in prompts, action.yml, and default_model_for.
updated: 2026-06-11
source: .woostack/fixes/2026-06-11-codex-model-effort.md
---
OpenAI Codex/GPT-5 family reasoning is controlled via a `reasoning_effort` parameter on the API instead of separate model slugs. When updating OpenAI tier mappings, keep the models and effort levels in sync:

1. **Effort defaults**:
   - `deep`: `gpt-5.5` + `reasoning_effort: medium`
   - `standard`: `gpt-5.4-mini` + `reasoning_effort: xhigh`
   - `fast`: `gpt-5.3-codex-spark` + `reasoning_effort: xhigh`

2. **Configuration points**:
   - **`action.yml`**: Update `openai_effort` input default (e.g. `'medium'`).
   - **`load-prompt.sh`**: Ensure `default_model_for()` maps the `standard` tier to `gpt-5.4-mini`.
   - **Documentation**: Synchronize the `using-woostack/references/model-tiers.md` table and notes, `SKILL.md` default model JSON and best practices, and `prompts/openai.md`.
