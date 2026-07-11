---
type: fix
status: hardened
branch: fix/review-model-fallback-arrays
---

# Fix: Accept OMP model fallback arrays during review

## 1. Root Cause

The fallback-array rollout updated OMP generation and the downstream model/prompt resolvers, but omitted the shared upstream configuration parser used by review and audit. `skills/woostack-review/scripts/prefetch.sh` loads configuration before angle detection or swarm execution, and `skills/woostack-review/scripts/model_config.py::_parse_model_leaf` accepts only a string or one `{model, effort?}` object. A valid non-empty `models.<tier>` array therefore fails before the already-correct primary-entry resolution can run.

The intended contract already exists elsewhere: `skills/woostack-init/scripts/gen-omp-agents.sh` preserves ordered entries for OMP fallback selection, while `skills/woostack-review/scripts/resolve-model.sh` and `load-prompt.sh` select entry 0 when one concrete model and effort are required. The shared parser must preserve arrays so host-specific routing remains available.

Receipt verification has the same contract gap. `skills/woostack-review/scripts/verify-receipts.sh::config_model_for_tier` returns an entire array instead of its primary model, so fixing only the loader would expose a later receipt mismatch. Existing tests cover string and single-object leaves but not fallback arrays, allowing both omissions to remain green.

Evidence:

- Calling `model_config.normalize_models` with the issue's `models.deep` value reproduces `ValueError: models.deep must be a string or an object with a `model` key`.
- Focused existing suites pass for array-aware downstream paths: resolver 19/0, prompt model/effort 35/0, and OMP generator 62/0.
- A focused probe of the receipt lookup expression returns the whole JSON array rather than entry 0's model.
- `skills/woostack-audit/scripts/load-audit-config.sh` imports the same shared parser, so it is affected by the same rejection.

## 2. Proposed Fix

Extend `model_config.py` to accept a non-empty ordered array at flat and provider-scoped tier leaves. Normalize every entry with the existing scalar string/object rules, preserve order and array shape, reject empty arrays, and report malformed entries with the indexed configuration path such as `models.deep[1]`. Nested arrays remain invalid.

Update `verify-receipts.sh` so provider-scoped and flat array leaves select entry 0 before extracting the concrete model. Entry 0 is the configured primary outside OMP agent-definition generation; a fallback entry must not satisfy receipt validation.

Bring review-facing schema text, prompt examples, and authored configuration documentation into lockstep with the established OMP contract: a tier leaf is a string, one `{model, effort?}` object, or a non-empty ordered array of those forms; entry 0 is primary. Do not change the already-correct resolver, prompt loader, generator, or doctor behavior.

## 3. Implementation Plan

- [ ] **Step 1: Reproduce parser and receipt failures with focused tests**
  - Extend `skills/woostack-review/scripts/tests/test-load-config-models-root.sh` with flat arrays for `fast`, `standard`, and `deep`; a provider-scoped array; canonical normalization and order preservation; empty arrays; invalid scalar, null, nested-array, and malformed-object entries; and exact indexed error paths.
  - Extend `skills/woostack-audit/scripts/tests/test-load-audit-config.sh` to prove the shared loader accepts a valid fallback array and rejects a malformed one before audit execution.
  - Extend `skills/woostack-review/scripts/tests/test-verify-receipts-openai-models.sh` to prove provider-scoped and flat arrays validate against entry 0, while a receipt naming entry 1 is rejected.
  - Run the three focused scripts and confirm the new valid-array and primary-selection cases fail for the diagnosed reasons before changing production code.
- [ ] **Step 2: Accept and normalize ordered fallback arrays**
  - Refactor `skills/woostack-review/scripts/model_config.py` so scalar leaf parsing remains the single source for string/object validation and an outer tier parser handles non-empty arrays without permitting nested arrays.
  - Preserve array order and canonical entry shape; retain existing effort normalization and string/single-object compatibility.
  - Emit precise tier paths for empty arrays and indexed paths for invalid entries.
  - Run the review and audit loader tests until all new and existing cases pass.
- [ ] **Step 3: Resolve receipt models to the configured primary**
  - Update `skills/woostack-review/scripts/verify-receipts.sh::config_model_for_tier` to normalize both provider-scoped and flat array leaves to entry 0 before existing object/string extraction.
  - Keep fallback entries invalid as receipt-model substitutes.
  - Run `test-verify-receipts-openai-models.sh` until the new and existing cases pass.
- [ ] **Step 4: Synchronize review schema and documentation**
  - Update the root-model schema descriptions in `skills/woostack-review/scripts/load-config.sh`, `skills/woostack-review/SKILL.md`, and `skills/woostack-review/prompts/_orchestrator-header.md`.
  - Make array-unsafe model lookup examples in `skills/woostack-review/prompts/anthropic.md`, `openai.md`, and `opencode.md` explicitly select entry 0 before extracting the model.
  - Clarify `site/content/docs/configuration.mdx` so its host-routing guidance does not contradict its documented `.woostack/config.json` fallback arrays.
  - Extend the existing host/reference documentation-sync test to guard the review schema and entry-0 semantics.
- [ ] **Step 5: Verify compatibility and the complete affected surface**
  - Run `bash skills/woostack-review/scripts/tests/test-load-config-models-root.sh`.
  - Run `bash skills/woostack-audit/scripts/tests/test-load-audit-config.sh`.
  - Run `bash skills/woostack-review/scripts/tests/test-resolve-model.sh`.
  - Run `bash skills/woostack-review/scripts/tests/test-load-prompt-models.sh`.
  - Run `bash skills/woostack-review/scripts/tests/test-verify-receipts-openai-models.sh`.
  - Run `bash skills/woostack-init/scripts/tests/test-gen-omp-agents.sh`.
  - Run `bash skills/woostack-doctor/scripts/tests/test-models-leaf-shape.sh`.
  - Run the focused documentation-sync test and `pnpm -C site build` because an authored docs page changes.
