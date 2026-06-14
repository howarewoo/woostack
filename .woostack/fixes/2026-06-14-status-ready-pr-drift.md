---
type: fix
status: in-review
branch: fix/status-ready-pr-drift
---

# Fix: `ready` + spec+plan PR false-flagged as "status lags" drift

## 1. Root Cause

`/woostack-status` flags a "status lags" drift whenever the displayed phase is a *head
state* and a PR already exists. The head-state list lives in one place:

`skills/woostack-status/scripts/status.sh:315-318`
```bash
case "$phase" in
  draft|hardened|approved|planning|ready)
    [ "$prcount" -gt 0 ] && flag "$name: status lags - phase '$phase' but a PR already exists" ;;
esac
```

`ready` is in that list. But the design says the spec+plan PR is opened **at** `ready`:

- `conventions.md:38` — *"`ready` — plan hardened, 0 boxes done, spec+plan PR should be
  opened before execution"*
- `next_action` `ready` (`status.sh:199`) — *"open spec+plan PR, then execute"*

So when the build/handoff loop opens the spec+plan PR while the plan is still at
`status: ready` (the documented, expected state between plan-harden and execution), the PR
is discovered (`prs_for_spec`, or `prs_for_branch` fallback at `status.sh:290`), `prcount`
becomes ≥1, and the lag flag fires. The flag contradicts the convention that *blesses* a PR
at `ready`. This contradiction was introduced by the same fix that added the `ready` phase
(`2026-06-12-build-loop-ready-phase.md`): it defined ready-opens-the-PR **and** added
`ready` to the lag list **and** added a test asserting the flag — all at once.

**Evidence the relevant `ready` is the *plan* phase, not the spec phase:** spec frontmatter
owns only `draft → hardened → approved` (`conventions.md:8`); `ready` is a *plan* phase
(`conventions.md:11`). Once a plan resolves to the spec, the board reads the plan's
`status:` (`status.sh:260`). So "spec is ready" in practice means **plan `status: ready`**.

**Latent test bug compounding it:** the existing guard
`test-status.sh:96-102` is named *"ready with open PR flagged"* but calls
`mkplan ... 0 5` with **no status arg**, so the plan defaults to `planning`
(`mkplan` default, `test-status.sh:27`). The test actually exercises `planning`+PR and has
**never covered the real `ready`+PR path** — which is why the false positive shipped
untested.

## 2. Proposed Fix

Align the lag-flag with the conventions: **remove `ready` from the head-state lag list**, so
a PR existing at `ready` is treated as expected, not drift. Keep the flag for the genuinely
pre-PR phases (`draft`/`hardened`/`approved`/`planning`).

Three edits:

1. **`skills/woostack-status/scripts/status.sh:316`** — drop `|ready` from the `case`
   pattern: `draft|hardened|approved|planning)`.
2. **`skills/woostack-status/scripts/tests/test-status.sh`** — replace the mislabeled
   `ready_pr` guard with a real `ready`+spec+plan-PR test (plan `status: ready`) asserting
   **no** "status lags", and add an explicit `planning`+PR guard so the genuine-lag path
   that the old test silently covered is not lost.
3. **`skills/woostack-status/references/conventions.md:49`** — reword the drift bullet so
   `ready` is named as exempt (its spec+plan PR is expected).

**Non-goals (kept out to stay minimal):**
- `resolve_phase` still derives `eff=in-review` when any PR is OPEN
  (`status.sh:153`), so the row *displays* in-review once the spec+plan PR opens. That is
  pre-existing behavior and not the reported symptom (the symptom is the **drift flag**).
  Left unchanged.
- Accepted tradeoff: a plan left at `ready` after *increment* execution starts no longer
  earns a lag nudge — but `resolve_phase` already promotes such a row to `executing`/
  `in-review`/`done` from branch commits + checkbox progress, so the board still shows the
  true state. Conventions explicitly bless a PR at `ready`, so this is correct.

## 3. Implementation Plan

- [x] **Step 1: Reproduce with a failing test (Red)**
  - In `skills/woostack-status/scripts/tests/test-status.sh`, replace the `ready_pr` block
    (lines ~96-102) with a test that creates the plan at `status: ready`
    (`mkplan "$ready_pr" oscar 2026-06-01-oscar.md 0 5 ready feature/oscar`) and an OPEN
    spec+plan PR via `FAKE_GH_JSON`, then asserts `assert_not_contains "$OUT" "status lags"
    "ready with spec+plan PR not flagged (PR expected at ready)"`.
  - Add a `planning_pr` block (plan `status: planning` + OPEN PR) asserting
    `assert_contains "$OUT" "status lags" "planning with open PR still flagged"` to preserve
    the genuine-lag coverage the old mislabeled test provided.
  - Run `bash skills/woostack-status/scripts/tests/run-tests.sh` and confirm the new
    `ready` assertion **fails** (flag currently fires) — Red.

- [x] **Step 2: Apply the minimal fix (Green)**
  - In `skills/woostack-status/scripts/status.sh:316`, change the pattern
    `draft|hardened|approved|planning|ready)` → `draft|hardened|approved|planning)`.
  - Re-run the test suite; the `ready` assertion passes, the new `planning` assertion
    passes, and the existing `approved`+PR lag test (`test-status.sh:180`) still passes —
    Green.

- [x] **Step 3: Update the convention doc**
  - In `skills/woostack-status/references/conventions.md:49`, reword the drift bullet from
    `head-state phases while PRs already exist;` to name the exempt phase, e.g.
    `pre-PR head-state phases (draft / hardened / approved / planning) while PRs already
    exist (ready is exempt — its spec+plan PR is expected before execution);`.

- [x] **Step 4: Verification**
  - `bash skills/woostack-status/scripts/tests/run-tests.sh` → all green.
  - `grep -n 'ready' skills/woostack-status/scripts/status.sh` → confirm `ready` no longer
    appears in the lag `case`, but is still present in `VALID_PHASES`, `resolve_phase`, and
    `next_action`.
