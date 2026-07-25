---
type: fix
status: in-review
branch: fix/artifact-trailer-attribution
---

# Fix: Prevent Markdown formatting in Spec trailers

## 1. Root Cause

`skills/woostack-review/scripts/parse-artifact-trailers.py` removes the literal `Spec: ` prefix and validates the remaining value as one raw `.woostack/specs/*.md` or `.woostack/fixes/*.md` path. A trailer such as ``Spec: `.woostack/fixes/example.md` `` therefore fails before review because the backticks remain part of the value. The same wrapped value is also rejected by `resolve-intent.sh` and ignored by `status.sh`; the readers consistently implement the raw-path contract.

The bad value originates in `skills/woostack-commit/SKILL.md`. It documents the raw final trailer, but its Markdown PR flow leaves the full body—including the load-bearing trailer—to model-authored prose and does not validate the proposed body or read the submitted body back. The Linear flow already performs both checks. This producer/consumer gap permits conventional Markdown code formatting to reach every strict reader.

Baseline evidence from the read-only diagnosis:

- `Spec: .woostack/fixes/example.md` returns `{"kind":"markdown-fix","path":".woostack/fixes/example.md"}` from `parse-artifact-trailers.py` with exit 0.
- ``Spec: `.woostack/fixes/example.md` `` returns `artifact context: Spec trailer must name one Markdown spec or fix file` with exit 1.
- `test-resolve-artifact-context.sh` passes its existing 75 raw-trailer cases but has no wrapped-trailer regression case.
- The exact `status.sh` predicate accepts the raw value and rejects the wrapped value.

## 2. Proposed Fix

Fix the sole shared PR-body producer in `skills/woostack-commit/SKILL.md`; keep all three readers strict and consistent.

For Markdown-backed non-change PRs:

1. Resolve and validate one raw artifact path from the active spec/fix invariant before PR-body composition. The value must match `.woostack/specs/<basename>.md` or `.woostack/fixes/<basename>.md`.
2. Keep attribution controller-owned. Fast-subagent or inline drafting supplies only the title, Goal, Summary, and Test plan fields; the controller appends exactly one final nonblank `Spec: <validated-artifact-path>` line without Markdown delimiters.
3. Before `gh pr create` or `gh pr edit`, require the proposed body to contain exactly that raw final trailer, no other `Spec:` line, and no `Linear-Project:` or `Linear-Issue:` line. Missing, malformed, wrapped, duplicate, mixed-backend, or mismatched attribution blocks the operation with the expected raw trailer named in the error.
4. After submission or edit, re-fetch the PR body with `gh pr view` and require the same exact raw final trailer before reporting success. A normal PR update may replace malformed current attribution with the validated active artifact; `--no-pr-update` must instead validate the untouched existing body and block if it is absent or invalid.
5. Preserve the existing no-trailer behavior for verified `change/*` invocations and Markdown changes that trace to no spec/fix, plus the existing strict Linear pair validation.

This mirrors the established Linear proposed-body/read-back pattern and closes the producer gap once. Accepting backticks in only the review parser would leave intent resolution and status discovery inconsistent, so no reader normalization is included. The change adds no dependency, API, storage, or runtime surface.

## 3. Implementation Plan

- [x] **Step 1: Reproduce with failing contract tests**
  - Add `skills/woostack-commit/tests/test-markdown-attribution.sh` as a contract test for the Markdown branch: raw spec and fix trailers are the sole final nonblank attribution line; wrapped, duplicate, mixed-Linear, and mismatched attribution blocks; artifact-neutral bodies omit attribution; and `--no-pr-update` requires valid existing attribution.
  - Add a malformed wrapped-fix case to `skills/woostack-review/scripts/tests/test-resolve-artifact-context.sh` to pin the existing strict consumer contract and prove no Markdown artifact reader is invoked.
  - Run `bash skills/woostack-commit/tests/test-markdown-attribution.sh` and confirm the new producer contract fails before the skill change. The resolver case is expected to pass before the producer fix because it protects the already-correct reader.
- [x] **Step 2: Apply the minimal producer fix**
  - Update the Markdown invariant, drafting, PR resolution, body composition, and report steps in `skills/woostack-commit/SKILL.md` so the controller validates one active artifact path, appends exactly one raw final trailer, validates the proposed body before create/edit, verifies the submitted body by read-back, and reports the verified Markdown path.
  - Keep fast-subagent and inline prose drafting limited to the existing title, Goal, Summary, and Test plan fields. Discard any draft that introduces attribution instead of copying or normalizing its trailer text.
  - Define current-body recovery explicitly: normal updates may replace malformed attribution with the validated active artifact, while `--no-pr-update` preserves the body and therefore blocks unless its existing trailer is already exact.
  - Leave `parse-artifact-trailers.py`, `resolve-intent.sh`, `status.sh`, and the canonical raw-trailer convention unchanged.
- [x] **Step 3: Verification**
  - Run `bash skills/woostack-commit/tests/test-markdown-attribution.sh`.
  - Run `bash skills/woostack-review/scripts/tests/test-resolve-artifact-context.sh`.
  - Run `bash skills/woostack-review/scripts/tests/test-resolve-intent.sh`.
  - Run `bash skills/woostack-status/scripts/tests/test-status.sh`.
  - Update only the stale section-start token in `skills/woostack-commit/tests/test-linear-attribution.sh` so it locates the current non-change Linear paragraph, then run `bash skills/woostack-commit/tests/test-linear-attribution.sh` to verify the unchanged Linear attribution contract.
