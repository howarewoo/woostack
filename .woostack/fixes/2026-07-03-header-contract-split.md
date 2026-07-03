---
type: fix
status: in-review
branch: fix/header-contract-split
---

# Fix: split woostack-review shared contract for worker/orchestrator prompts

## 1. Root Cause
`skills/woostack-review/scripts/load-prompt.sh` always prepends `prompts/_header.md` to the loaded body before every prompt, and `prompts/_header.md` currently contains full orchestrator and worker contract (~43KB). In the stage-3 worker briefing, every angle prompt path currently points to that same header, so every angle sub-agent re-reads posting/payload/model-table logic and other orchestrator-only sections that are unrelated to angle execution. This causes the largest avoidable per-angle token spend in review runs.

## 2. Proposed Fix
Split `_header.md` into two purpose-built contracts:

- `prompts/_worker-header.md`: minimal shared contract for workers (output discipline, escape rules, prefetched artifacts needed by workers, finding schema, receipt contract, and receipt proof).
- `prompts/_orchestrator-header.md`: orchestrator-only content (model table/inlining behavior, posting procedure, self-PR downgrade, pending-review preflight, watermark, degraded-mode notes, and other full-review orchestration requirements).
- `prompts/_header.md`: keep a thin compatibility shim that points to the two files and explains split behavior.

Update loading and references to consume split contracts:

- `scripts/load-prompt.sh`: compose orchestrator prompts from `prompts/_orchestrator-header.md + provider prompt`, explicitly inlining the model-tiers marker only in the orchestrator path.
- Stage-3 orchestration docs and angle prompt docs: worker-facing references should point at `prompts/_worker-header.md` (not the monolith) and avoid accidental `-- read _header.md` pullbacks.
- Keep compatibility where pinned forks still read `prompts/_header.md` by preserving a tiny shim.

## 3. Implementation Plan
- [x] **Step 1: Reproduce with a failing test / assertion**
  - Add regression coverage for contract split in prompt loading and references, including a test that the split headers are used by `load-prompt.sh` and worker docs no longer require `_header.md`.

- [x] **Step 2: Apply minimal fix**
  - Create `prompts/_worker-header.md` with worker-only contract text.
  - Create `prompts/_orchestrator-header.md` with orchestrator-only contract text.
  - Replace `prompts/_header.md` with a compatibility shim.
  - Update `scripts/load-prompt.sh` to prepend `_orchestrator-header.md` (explicitly and not via shim-chasing).
  - Update `prompts/openai.md`, `prompts/anthropic.md`, `prompts/google.md`, `prompts/opencode.md`, and all affected angle prompts / stage docs under `SKILL.md` to reference `_worker-header.md` for worker-facing schema/output contract language.

- [x] **Step 3: Verification**
  - Run `bash skills/woostack-review/scripts/tests/test-load-prompt-models.sh` and any relevant review-doc tests.
  - Manually validate a stage-3 worker/validator handoff format still references the new worker header and that the orchestrator path still inlines model-tier table and retains full posting contract text.
