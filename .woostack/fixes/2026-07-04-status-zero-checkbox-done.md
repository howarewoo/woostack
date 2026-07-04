---
type: fix
status: in-review
branch: fix/status-zero-checkbox-done
---

# Fix: woostack-status mislabels done zero-checkbox plans as executing

Fixes [#456](https://github.com/howarewoo/woostack/issues/456).

## 1. Root Cause

`/woostack-status` shows a feature as `executing` when its plan is authored `status: done`,
all discovered increment PRs are merged, but the plan has zero markdown task checkboxes.

Traced in `skills/woostack-status/scripts/status.sh`:

- Line 374: `frac=0; [ "$total" -gt 0 ] && frac=$(( done * 100 / total ))` — with
  `total=0`, `frac` stays `"0"` and can never reach `"100"`.
- `resolve_phase()` (lines 177–202), called with `frac="0"`, `authored="done"`,
  `hasPlan=1`, `merged=3`, `prcount=3`, `open=0`:
  - L180 discovered-PR done path requires `frac = 100` → never fires for a 0/0 plan.
  - L186 authored-done fallback requires `frac = 100` **and** `prcount -eq 0` → fails
    both (PRs were discovered).
  - Falls through to the `case "$authored"` branch (L192–199): authored `done` with
    `hasPlan=1` echoes **`executing`**.
- `next_action()` (L226) then renders `finish plan (0/0); 3/3 increments shipped`,
  matching the reported output exactly.

`frac` is local to `status.sh` (not exported, not sourced elsewhere), so the defect is
fully contained to this script.

## 2. Proposed Fix

Trust an explicit authored `done` for zero-checkbox plans, mirroring the existing
narrow-trust precedent at L181–187. **Rejected alternative:** defaulting `frac=100`
when `total=0` (vacuous truth) — too broad, because L180 ignores `authored`, so a
zero-checkbox plan authored `executing` with one merged PR would silently flip to
`done`; conventions.md says the board derives truth and flags drift, and a 0-box plan
carries no progress signal to derive from.

Concrete change in `skills/woostack-status/scripts/status.sh`:

1. Pass `total` into `resolve_phase` as a 9th parameter (single call site, L381).
2. Add two authored-done zero-checkbox rules after the existing L186 fallback:

```bash
# A zero-checkbox plan carries no progress signal; trust an explicit authored
# done when every discovered increment PR is merged (closed-unmerged keeps the
# feature visible), or — mirroring the legacy rule above — when nothing was
# discovered at all.
if [ "$authored" = "done" ] && [ "$total" -eq 0 ]; then
  if [ "$merged" -gt 0 ] && [ "$merged" -eq "$prcount" ]; then echo "done"; return; fi
  if [ "$prcount" -eq 0 ] && [ "$hasCommits" -eq 0 ]; then echo "done"; return; fi
fi
```

Effects:

- Authored `done` + 0 checkboxes + all discovered PRs merged → `done` (the bug).
- Authored `done` + 0 checkboxes + no PRs + no branch commits → `done` (legacy
  no-trailer case, symmetric with L186).
- Closed-but-unmerged PRs stay visible: `merged < prcount` fails the first rule and
  `prcount > 0` fails the second.
- The `open > 0 → in-review` gate (L179) still runs first — unaffected.
- Authored `executing`/`in-review` zero-checkbox plans are untouched (guard requires
  `authored = done`).
- Plans with real checkboxes are untouched (`total > 0`).
- `frac` derivation (L374) and the HTML progress bar are untouched.

No change to `plan_progress()` (correctly returns `0 0`) and no change to when
`status: done` gets authored — per memory `execute-authors-terminal-plan-done`, the
board-derivation logic in `resolve_phase` is the right place for this fix.

Doc touch: `skills/woostack-status/references/conventions.md` `done` bullet gains a
one-line note that a zero-checkbox plan relies on its authored `done` plus merged PRs.

## 3. Implementation Plan

- [x] **Step 1: Reproduce with failing tests**
  - In `skills/woostack-status/scripts/tests/test-status.sh`, following the existing
    `oscar`/`oscardone` fixture pattern (mkspec + mkplan + `FAKE_GH_JSON` + `run_status`,
    ~L265–297), add:
    - Zero-checkbox authored-done + all PRs MERGED → phase `done` (the bug; must fail
      before the fix).
    - Zero-checkbox authored-done + one PR CLOSED (unmerged) → phase **not** `done`.
    - Zero-checkbox authored-done + no PRs + no branch commits → phase `done` (legacy
      rule; must fail before the fix).
    - Zero-checkbox authored-**executing** + all PRs MERGED → stays `executing`
      (guards against the rejected broad fix).
    - Zero-checkbox authored-done + one PR OPEN → phase `in-review` (L179 gate sanity).
  - Run `bash skills/woostack-status/scripts/tests/run-tests.sh`; confirm the two
    marked tests fail with the current code.
- [x] **Step 2: Apply the minimal fix**
  - In `status.sh`: pass `total` into `resolve_phase` (9th param, call site L381) and
    add the authored-done zero-checkbox rules from §2 after the L186 fallback.
  - Add the one-line zero-checkbox note to the `done` bullet in
    `skills/woostack-status/references/conventions.md`.
- [x] **Step 3: Verification**
  - Run `bash skills/woostack-status/scripts/tests/run-tests.sh` — all tests pass,
    including the pre-existing 100%-checkbox `oscar`/`oscardone` regression guards and
    the HTML board tests (`test-html-board.sh`).
  - Bash 3.2 / `set -u` compatible: plain `[` arithmetic tests, no arrays.
