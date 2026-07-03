---
type: fix
status: hardened
branch: fix/review-worker-skill-scope
---

# Fix: Stop review angle workers from loading the orchestrator skill

## 1. Root Cause

The leak is not coming from `load-prompt.sh` explicitly inlining the review orchestrator. In review mode, `skills/woostack-review/scripts/load-prompt.sh` selects `prompts/_worker-header.md` for the role header and composes only the review context, the selected header, and the provider body. The existing `test-load-prompt-models.sh` split-contract assertions already cover that worker prompts omit the orchestrator header and model table.

The root cause is the Stage 3 worker-dispatch contract. The generic Stage 3 instructions and several provider templates say to spawn review sub-agents, but they do not require a plain/general/default worker with no `woostack-review` skill scope and do not explicitly prohibit attaching or resolving `skill://woostack-review` / `SKILL.md` in the worker context. On hosts that auto-carry the invoking skill into spawned workers, that omission lets every angle worker load the full `woostack-review` orchestrator document even though the worker brief already points at the only required inputs: `_worker-header.md`, one angle prompt, and `$OUTDIR` artifacts.

Evidence from the diagnosis:

- `skills/woostack-review/SKILL.md` Stage 3 lists host dispatch primitives, but does not define the worker as plain/general-purpose/default or skill-scope-free.
- The Stage 3 worker brief tells workers to read `_worker-header.md`, `prompts/angles/<angle>.md`, `diff.txt`, and `meta.json`, but lacks a guard against loading `skill://woostack-review` or `SKILL.md`.
- `prompts/anthropic.md` already shows the right `subagent_type: "general-purpose"` shape, but the generic Stage 3 contract and the Google/OpenCode/OpenAI provider prompts do not propagate that no-skill-scope boundary.
- `_worker-header.md` contains the worker contract and output rules; the full orchestrator `SKILL.md` is not a worker dependency.

## 2. Proposed Fix

Make the skill-scope boundary explicit anywhere Stage 3 worker dispatch is specified:

- Update `skills/woostack-review/SKILL.md` Stage 3 to require plain/general-purpose/default workers for angle dispatch, and prohibit using a `woostack-review` skill-scoped worker or attaching/resolving `skill://woostack-review` / `SKILL.md` into worker context.
- Add the same constraint to the worker brief itself: it is self-contained, workers read only `_worker-header.md`, their angle prompt, and the prefetched artifacts. If the host has already injected the orchestrator skill, workers must ignore it and follow the worker contract and angle prompt.
- Propagate the dispatch rule into subagent-capable provider prompts: Anthropic keeps `subagent_type: "general-purpose"` and names the no-skill-scope invariant; Google, OpenCode, and OpenAI instruct their runtimes to use plain/default/general subagents and never `@woostack-review` / `skill://woostack-review` skill-scoped workers.
- Update authored context-management docs if they describe review subagent isolation, so the public explanation matches the new plain-worker/no-skill-scope invariant.
- Keep `load-prompt.sh` unchanged unless tests expose a loader regression; the evidence points to dispatch instructions/templates, not loader composition.

## 3. Implementation Plan

- [ ] **Step 1: Reproduce with a failing test**
  - Add a narrow regression test under `skills/woostack-review/scripts/tests/` using the existing `assert.sh` helpers.
  - Assert `SKILL.md` Stage 3 and each subagent-capable provider prompt (`anthropic.md`, `google.md`, `opencode.md`, `openai.md`) contain both a plain/general/default worker instruction and the `skill://woostack-review` no-skill-scope guard.
  - Assert the Anthropic prompt still contains `subagent_type: "general-purpose"`.
  - Keep or extend the existing review-mode prompt split assertions so `MODE=review` output does not contain orchestrator-only markers.

- [ ] **Step 2: Apply the minimal fix**
  - Edit `skills/woostack-review/SKILL.md` Stage 3 worker-dispatch guidance and worker brief text to require plain/general-purpose/default workers and forbid `skill://woostack-review` / `SKILL.md` worker context.
  - Edit `skills/woostack-review/prompts/anthropic.md`, `google.md`, `opencode.md`, and `openai.md` to mirror the same no-skill-scope dispatch rule in provider-specific language.
  - Update `site/content/docs/concepts/context-management.mdx` and its duplicate section in `site/content/docs/concepts.mdx` only if their current review-subagent context-economy text needs the no-skill-scope clarification.
  - Avoid changing loader code or angle rubrics unless the failing test identifies a real prompt-generation regression.

- [ ] **Step 3: Verification**
  - Run the new worker skill-scope regression test.
  - Run `bash skills/woostack-review/scripts/tests/test-load-prompt-models.sh` to preserve the existing worker/orchestrator split contract.
  - If authored docs are updated, run `pnpm -C site build`.
