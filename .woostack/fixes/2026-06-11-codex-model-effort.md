---
type: fix
status: in-review
branch: fix/codex-model-effort
---

# Fix: Configure OpenAI Codex Model Tiers and Effort Levels

## 1. Root Cause
The OpenAI Codex provider in `woostack-review` resolves models and effort levels per tier (fast, standard, deep). The user requested updating these mappings to reduce costs and adjust reasoning quality:
- `deep`: `gpt-5.5` with `reasoning_effort: medium` (changed from `xhigh`)
- `standard`: `gpt-5.4-mini` with `reasoning_effort: xhigh` (changed from `gpt-5.4` default effort)
- `fast`: `gpt-5.3-codex-spark` with `reasoning_effort: xhigh` (added explicit effort `xhigh`)

Currently:
1. `skills/using-woostack/references/model-tiers.md` documents `gpt-5.4` as standard, and `gpt-5.5` + `reasoning_effort: xhigh` as deep.
2. `skills/woostack-review/SKILL.md` hardcodes standard as `openai/gpt-5.4` / `gpt-5.4` and deep as `anthropic/claude-opus-4-8` / `gpt-5.5` with `reasoning_effort: xhigh`.
3. `skills/woostack-review/prompts/openai.md` documents standard defaulting to `gpt-5.4`.
4. `skills/woostack-review/scripts/load-prompt.sh` returns `gpt-5.4` for standard.

## 2. Proposed Fix
1. Update `skills/using-woostack/references/model-tiers.md` model tiers table and provider notes to:
   - fast: `gpt-5.3-codex-spark` + `reasoning_effort: xhigh`
   - standard: `gpt-5.4-mini` + `reasoning_effort: xhigh`
   - deep: `gpt-5.5` + `reasoning_effort: medium`
2. Update `skills/woostack-review/SKILL.md`:
   - Change `"standard": "openai/gpt-5.4"` to `"standard": "openai/gpt-5.4-mini"` (line 173).
   - Change `"standard": "gpt-5.4"` to `"standard": "gpt-5.4-mini"` (line 177).
   - Update model tiers table at line 388-389.
3. Update `skills/woostack-review/prompts/openai.md`:
   - Change `standard` tier defaults from `gpt-5.4` to `gpt-5.4-mini` with `reasoning_effort: xhigh`.
   - Update references to `reasoning_effort` defaults.
4. Update `skills/woostack-review/scripts/load-prompt.sh`'s `default_model_for` to return `gpt-5.4-mini` for the `standard` tier under `openai` (line 71).
5. Update `action.yml` to set the default value of the `openai_effort` input to `medium`.

## 3. Implementation Plan
- [x] **Step 1: Reproduce with a failing test**
  - Add test script `skills/woostack-review/scripts/tests/test-load-prompt-models.sh` checking standard tier maps to `gpt-5.4-mini`. Verified it fails.
- [x] **Step 2: Apply the minimal fix**
  - Update `skills/woostack-review/scripts/load-prompt.sh` to route standard to `gpt-5.4-mini`.
  - Update `action.yml` to set default `openai_effort` to `medium`.
  - Update documentation and prompts:
    - `skills/using-woostack/references/model-tiers.md`
    - `skills/woostack-review/SKILL.md`
    - `skills/woostack-review/prompts/openai.md`
- [x] **Step 3: Verification**
  - Run the test script and verify it passes.
