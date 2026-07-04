---
type: fix
status: in-review
branch: fix/sweep-memory-commit
---

# Fix: Commit sweep-generated memory on the swept PR

## 1. Root Cause

`woostack-sweep` runs `woostack-address-comments --auto` inside a per-PR worktree, but the memory write path routes tracked memory notes back to the primary checkout instead of the swept branch.

Evidence:

- `skills/woostack-sweep/SKILL.md` lines 48-50 currently tells sweep to export `WOOSTACK_ROOT` to the primary checkout before the address step "so any address-comments memory write lands in the primary store." That contradicts the worktree contract in `skills/woostack-init/references/worktrees.md` lines 75-79 and 105-120: only metrics/telemetry/watermark are primary-root local state; tracked memory notes and `MEMORY.md` must be written in the worktree and committed with the increment.
- `skills/woostack-address-comments/scripts/memory-record.sh` line 12 defaults `MEMORY_DIR` to `$WOOSTACK_COMMON_ROOT/.woostack/memory`. In a secondary worktree, `resolve-root.sh` sets `WOOSTACK_ROOT` to the active worktree and `WOOSTACK_COMMON_ROOT` to the primary checkout, so final `ACCEPT` memory writes bypass the PR branch.
- `skills/woostack-review/scripts/memory-record.sh` has the same default and can strand locally recorded review memory outside a PR when review helpers are run from a worktree.
- Recent Claude Code session evidence: `~/.claude/projects/-Users-adamwoo-Documents-GitHub-woostack/044750df-4e7b-4a7c-a468-9854fce46aa1.jsonl` lines 161-167 show 10 `.woostack/memory/*.md` changes appearing in the primary checkout before `woostack-address-comments`; line 178 identifies them as review recall side effects and a blocker. That session then committed those memory files separately instead of letting them ride the PR that generated them. A July 4 sweep session (`8656c23d-df54-4b6f-aa52-27b8eec926f3.jsonl` lines 9-32, 160-172 from grep evidence) shows sweep running from `feature/model-tier-routing-docs` and declaring the stack clean, reinforcing that sweep's current flow can finish without auditing primary-tree memory residue.

The bad value originates in the root split: `WOOSTACK_COMMON_ROOT` is correct for local sidecars, but tracked memory notes are shared artifacts and must use the active worktree root (`WOOSTACK_ROOT`).

## 2. Proposed Fix

Make tracked memory writes use the active worktree by default, while leaving metrics and telemetry primary-root behavior unchanged.

- Change both memory recorders (`skills/woostack-address-comments/scripts/memory-record.sh` and `skills/woostack-review/scripts/memory-record.sh`) so `MEMORY_DIR` defaults to `$WOOSTACK_ROOT/.woostack/memory`.
- Update the worktree-root regression tests for address-comments and review so they fail before the code change: memory notes should be created under the secondary worktree's `.woostack/memory`, not the primary checkout. Keep the review metrics assertions proving `.woostack/metrics.json` still writes to the primary checkout.
- Update `skills/woostack-sweep/SKILL.md` to stop saying that `address-comments` memory should land in the primary store. It should say sweep may export the primary root for metrics/telemetry sidecars, but tracked memory notes must remain in the per-PR worktree and ride the `woostack-commit --no-pr-update` commit on the swept branch.
- Update `skills/woostack-address-comments/SKILL.md` and its prompt where needed so final `ACCEPT` memory writes happen before the commit/push step or are otherwise included in the same `woostack-commit --no-pr-update` commit. The current docs say memory is written after push, which cannot commit it on the PR.

## 3. Implementation Plan

- [x] **Step 1: Reproduce with failing tests**
  - In `skills/woostack-address-comments/scripts/tests/test-worktree-common-root.sh`, change the assertions to expect `memory-record.sh` to write one scoped note under `$wt/.woostack/memory` and leave the primary checkout's memory note count unchanged.
  - In `skills/woostack-review/scripts/tests/test-worktree-common-root.sh`, change the memory assertions the same way while keeping the metrics assertions anchored to the primary checkout.
  - Run both tests and confirm they fail because the current scripts write memory under `$WOOSTACK_COMMON_ROOT`.

- [x] **Step 2: Apply the minimal fix**
  - Change `MEMORY_DIR` defaults in both `skills/woostack-address-comments/scripts/memory-record.sh` and `skills/woostack-review/scripts/memory-record.sh` from `$WOOSTACK_COMMON_ROOT/.woostack/memory` to `$WOOSTACK_ROOT/.woostack/memory`.
  - Adjust the comments in each `resolve-root.sh` only if needed to clarify that `WOOSTACK_COMMON_ROOT` remains for primary-only sidecars, not tracked memory.
  - Update `skills/woostack-sweep/SKILL.md` lines 48-50 so sweep documents primary-root export for metrics/telemetry only and explicitly keeps tracked memory writes in the per-PR worktree.
  - Update `skills/woostack-address-comments/SKILL.md` and `skills/woostack-address-comments/prompts/address.md` so ACCEPT memory writes are staged before invoking `woostack-commit --no-pr-update`, with replies/resolution after the successful commit SHA is captured.

- [x] **Step 3: Verification**
  - Run `bash skills/woostack-address-comments/scripts/tests/test-worktree-common-root.sh`.
  - Run `bash skills/woostack-review/scripts/tests/test-worktree-common-root.sh`.
  - Run `grep`/file inspection only as needed to verify sweep/address docs no longer instruct primary-checkout tracked-memory writes.
