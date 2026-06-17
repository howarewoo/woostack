---
type: fix
status: in-review
branch: fix/375-final-finding-anchors
---

# Fix: Final review findings can keep stale anchors after validator passes

Source issue: [#375](https://github.com/howarewoo/woostack/issues/375)

## 1. Root Cause

Final review posting consumes `$OUTDIR/findings.json` directly, but the final validator/intersection stage does not re-filter that file against the postable PR diff after it writes it.

Evidence:

- `merge-findings.sh` already has the right guard for raw angle output: after merging per-angle findings into `raw_findings.json`, it calls `resolve-diff-line.sh` and drops raw findings whose `(file, line)` cannot anchor on the right side of the diff.
- `intersect-findings.sh` then builds the final postable `findings.json` from validator outputs. In defender-only mode it copies/classifies defender output; in adversarial mode it writes merged defender/prosecutor findings. Neither path runs a second PR-file-set or line-anchor validation pass after the final set is produced.
- The adversarial merge intentionally preserves the defender object for matched findings and only merges severity/blocking from prosecutor matches. A fuzzy or title-only match can therefore prove that validators agreed on the issue while still leaving the final object with the defender's stale `file`/`line`.
- The posting contract and provider prompts treat `findings.json` as the single source of truth for the batched GitHub Review API POST. A stale `line` can therefore reach GitHub and produce HTTP 422 "Line could not be resolved"; a stale `file` can also post outside the current PR file set. Sibling issue #374 is the same root cause at the path/file-set boundary.

## 2. Proposed Fix

Add a final post-intersection normalization step in `skills/woostack-review/scripts/intersect-findings.sh`, after `classify_floor` has produced `findings.json` and before metrics/counts/posting observe it.

The normalization should:

- Load the current PR file set from `$OUTDIR/meta.json` (`.files[].path`), falling back to `$OUTDIR/changed-paths.txt` or `$OUTDIR/changed-paths.filtered.txt` only if metadata is unavailable.
- For each final finding with `file` and `line`, drop it when the file is not in the current PR file set.
- For remaining findings, call `resolve-diff-line.sh --file <file> --line <line>` using the current `$OUTDIR` diff context. Drop findings whose resolver output is `null`.
- When the resolver returns a numeric line, write that canonical value back to `.line` so the final posted payload uses the postable anchor, not a stale pre-validation value.
- Preserve findings without `file`/`line` only if the existing posting contract permits them. The current inline-comment contract expects both fields for postable findings, so the implementation should avoid broadening behavior.

This is intentionally final-stage validation rather than another prompt instruction: model and validator outputs are untrusted, and the last machine-written artifact before posting must be independently postable.

## 3. Implementation Plan

- [x] **Step 1: Reproduce with failing tests**
  - Add a shell regression near `skills/woostack-review/scripts/tests/test-intersect-*.sh`.
  - Fixture A: defender-only mode, `meta.json` containing only `src/app.ts`, a diff with right-side lines 1-2, and `findings.defender.json` containing one stale `src/app.ts:99` finding plus one valid `src/app.ts:2` finding.
  - Expected: `intersect-findings.sh` writes `findings.json` with only the valid finding.
  - Fixture B: include a finding for `other.ts` with an otherwise plausible line.
  - Expected: `intersect-findings.sh` drops it because `other.ts` is not in the current PR file set.
  - Add an assertion that a finding whose line resolves to a numeric canonical value has `.line` rewritten to that numeric value.

- [x] **Step 2: Apply the minimal fix**
  - Add a small final-filter helper inside `intersect-findings.sh` after `classify_floor`.
  - Reuse `resolve-diff-line.sh` instead of reimplementing diff parsing.
  - Keep diagnostics concise: report how many findings were dropped for non-PR files and unresolvable anchors.
  - Keep the change scoped to final postable review findings; do not change angle prompts or validator matching semantics.

- [x] **Step 3: Verification**
  - Run the new regression test.
  - Run the existing intersect/merge review script tests:
    - `skills/woostack-review/scripts/tests/test-intersect-farapart.sh`
    - `skills/woostack-review/scripts/tests/test-intersect-nits.sh`
    - `skills/woostack-review/scripts/tests/test-intersect-overlap.sh`
    - `skills/woostack-review/scripts/tests/test-merge-findings-recovery.sh`
  - Run the full `skills/woostack-review/scripts/tests/test-*.sh` sweep if the targeted tests pass quickly.

- [x] **Step 4: Distill the gotcha**
  - Record the durable debugging lesson: review model/validator agreement does not imply GitHub-postable anchors; final machine-generated review payloads need a post-intersection PR-file-set and diff-anchor guard.
