---
type: fix
status: in-review
branch: fix/multi-line-review-anchors
---

# Fix: Preserve multi-line review finding anchors

## 1. Root Cause

`woostack-review` implements an end-to-end single-line anchor contract even though GitHub's review API accepts ranges. The limitation is distributed across every live handoff: `prompts/_worker-header.md` and the duplicated schema in `prompts/_orchestrator-header.md` define only `line`; `scripts/resolve-diff-line.sh` accepts and resolves only one RIGHT-side line; `merge-findings.sh` and `intersect-findings.sh` validate only that field; neither validator prompt requires an endpoint to survive validation; and the orchestrator payload builder emits only `path`, `line`, `side`, and `body`.

The deficiency is reproduced on the current code with a two-hunk diff:

- `resolve-diff-line.sh --line 10` and a separate `--line 31` each succeed, but `--line 10 --end 11` exits with `unknown arg: --end`. Independent endpoint checks therefore cannot prove same-hunk membership.
- A defender finding with `{ "line": 10, "end_line": 31 }` passes the current final intersection filter unchanged with zero dropped anchors, even though the endpoints are in different hunks.
- The focused single-anchor baselines remain green (`test-intersect-final-anchors.sh`: 4/4; `test-intersect-final-anchors-adversarial.sh`: 5/5), confirming that existing coverage never exercises an endpoint.

GitHub's REST contract maps a range to `start_line` plus terminal `line`, with both sides set to `RIGHT`. The finding schema requested by issue #510 uses `line` as the start and optional `end_line` as the end, so a valid finding range must become `start_line: line`, `start_side: "RIGHT"`, `line: end_line`, and `side: "RIGHT"`. No GitHub or provider limitation blocks the change.

## 2. Proposed Fix

Add optional `end_line` to both live finding-schema copies and require both defender and prosecutor validators to preserve it. Absence retains today's single-line behavior.

Make `scripts/resolve-diff-line.sh` the one range authority. Add optional `--end <N>`, parse the unified diff once, and assign each RIGHT-side anchor a hunk identity. Preserve the existing no-`--end` stdout contract exactly. In range mode, emit `<start>:<end>` only when both positive, ordered endpoints resolve on the RIGHT side of the same file and hunk; otherwise emit the canonical start alone when the start is valid, or `null` when the start is invalid. Equal, reversed, malformed, deletion-only, out-of-hunk, and different-hunk endpoints therefore degrade safely to one line. Include `end_line` in range cache keys so concurrent workers cannot reuse a result for a different endpoint.

Route both anchor safety nets through that contract. `merge-findings.sh` and `intersect-findings.sh::filter_final_anchors` must canonicalize a valid range, remove only an invalid `end_line`, and continue dropping a finding only when its start is invalid. Each stage must report how many endpoints degraded so malformed model output is visible without turning the safe fallback into a failure. Keep deduplication keyed on the start `line`; findings at the same location remain one logical issue regardless of highlighted extent. The final filter remains authoritative in defender-only and adversarial modes.

In the existing orchestrator payload builder, leave the current location object byte-for-byte unchanged when no validated `end_line` remains. For a valid range, emit `start_line`/`start_side` and use `end_line` as GitHub's terminal `line`. Provider prompts need no separate posting path because they already delegate to this builder. No dependency, application code, generated reference page, or authored docs-site statement changes.

## 3. Implementation Plan

- [x] **Step 1: Reproduce resolver and safety-net range failures**
  - Add `skills/woostack-review/scripts/tests/test-resolve-diff-line.sh` covering unchanged single-line output; valid same-hunk RIGHT-side ranges; malformed, equal, reversed, deletion-only, out-of-hunk, and different-hunk endpoints degrading to the valid start; invalid starts returning `null`; and endpoint-aware cache keys.
  - Extend `test-intersect-final-anchors.sh` and `test-intersect-final-anchors-adversarial.sh` with valid-range preservation, invalid-range degradation without finding loss, and no-`end_line` compatibility in both validator modes.
  - Add `skills/woostack-review/scripts/tests/test-merge-finding-anchors.sh` proving a valid range survives pre-validation, an invalid endpoint is stripped without dropping a valid-start finding, and a finding without `end_line` is unchanged.
  - Run the focused tests before implementation and confirm the new range assertions fail against the single-line contract.

- [x] **Step 2: Implement one range-aware diff resolver**
  - Add optional `--end` parsing, range-aware cache keys, per-hunk RIGHT-side anchor tracking, and the `<start>:<end>` / `<start>` / `null` output contract to `resolve-diff-line.sh`.
  - Preserve the current invocation, exit status, default diff/cache resolution, atomic cache writes, and missing-diff behavior when `--end` is absent.
  - Run `test-resolve-diff-line.sh` and confirm all single-line and range cases pass.

- [x] **Step 3: Preserve and validate ranges through the finding pipeline**
  - Add optional `end_line` and its same-file, same-hunk, RIGHT-side semantics to `_worker-header.md` and `_orchestrator-header.md`; require `validator.md` and `validator-prosecutor.md` to preserve the winning finding's endpoint.
  - Update `merge-findings.sh` and `intersect-findings.sh::filter_final_anchors` to parse the shared resolver result, retain canonical valid ranges, strip invalid endpoints, drop only invalid starts, and report endpoint degradation counts on stderr.
  - Run `test-merge-finding-anchors.sh` and both intersection tests; confirm valid ranges survive, invalid ranges degrade, findings without `end_line` remain unchanged, and both validator paths preserve the field.

- [x] **Step 4: Emit GitHub multi-line review payloads**
  - Add `skills/woostack-review/scripts/tests/test-review-payload-ranges.sh` around the existing orchestrator payload builder: no endpoint must produce exactly the current location fields; `line: 10, end_line: 12` must produce `start_line: 10`, `start_side: "RIGHT"`, `line: 12`, and `side: "RIGHT"`; degraded findings must contain no range fields.
  - Update the sole payload builder in `_orchestrator-header.md` and run the new payload test to green.

- [x] **Step 5: Verification**
  - Run `bash -n` on `resolve-diff-line.sh`, `merge-findings.sh`, and `intersect-findings.sh`.
  - Run `test-resolve-diff-line.sh`, `test-merge-finding-anchors.sh`, `test-intersect-final-anchors.sh`, `test-intersect-final-anchors-adversarial.sh`, and `test-review-payload-ranges.sh`.
  - Smoke-test a synthetic two-hunk diff through resolver → merge → intersection → payload construction: a same-hunk range must post range fields, a cross-hunk endpoint must post the original single-line location, and an invalid start must still be dropped.
