---
type: fix
status: hardened
branch: fix/tests-regression-blind-fixtures
---

# Fix: Tests angle misses regression-blind assertions (fixtures neutral to the change under test)

## 1. Root Cause

This is a small enhancement to the `woostack-review` `tests` angle rubric, not a defect —
so there is no runtime bad value to trace and `woostack-debug`'s data-flow analysis does not
apply; the "origin" of the gap is the prompt content itself. The evidence:

- `skills/woostack-review/prompts/angles/tests.md:9-17` — the "Find:" list enumerates only
  *syntactic* dead-test patterns. Its "Tests that cannot fail" bullet (`tests.md:13`) lists
  `missing expect`, `only console.log`, `conditional skips`, `expect(true).toBe(true)`, and
  discarded rejections.
- None of these covers the *semantic* case: a test that **has** an `expect`, asserts a real
  value, and would fail on many bugs — but **not on the specific transformation it exists to
  defend**, because its fixture value is invariant under that transformation. The test can
  fail; it just can't fail on the regression it is supposed to guard.

Net: the rubric has no fixture-exercises-the-behavior (mutation-sensitivity) heuristic, so a
regression-blind assertion sails through the `tests` angle.

Real-world miss (dogfooded on `fix/status-board-github-links`): new tests asserted an
anchor's `href` output, but every fixture URL was HTML-escape-neutral (no `&`, `"`, `<`), so a
regression that dropped `html_escape` from the href would leave every assertion green. The one
contract behavior the tests existed to defend was untested — and the current `tests` rubric
gives a worker no basis to flag it.

## 2. Proposed Fix

Add one bullet to the "Find:" list in `prompts/angles/tests.md`, immediately after the
existing "Tests that cannot fail" bullet, describing the fixture-neutral (regression-blind)
case; and add the same case to the `MEDIUM` line of the "Severity rubric" so severity lives
where the file already keeps it (inline "Find" bullets carry no severity — `tests.md:11-17`).

New "Find" bullet (style-matched to its neighbors, no inline severity):

> - Regression-blind assertions: a test whose fixture is neutral to the transformation under
>   test — it asserts a real value and would fail on many bugs, but would stay green if the
>   specific transformation it exists to defend were removed (e.g. asserting an HTML-escaper's
>   output on input with no escapable characters, or a formatter on already-formatted input).
>   Recommend a fixture that actually exercises the transformation.

Severity-rubric addition (`tests.md:29`, the `MEDIUM` line):

> - `MEDIUM` + `blocking: false` — flaky pattern, drifting mock, missing critical edge case,
>   regression-blind assertion (fixture neutral to the change under test).

Prompt-only change; no schema, script, or plumbing touched. Additive — it widens the `tests`
angle's rubric and cannot affect any other angle or the shell test suite.

Non-goals: no mutation-testing tool or new dependency (this is a rubric heuristic, not a
runner); no change to any other angle prompt; no schema/`_worker-header.md` change.

## 3. Implementation Plan

- [ ] **Step 1: Establish the concrete behavioral check (no-runner → concrete verification)**
  - Prompt-content changes have no unit-test runner, so use the woostack-tdd
    no-runner carve-out: construct the minimal escape-neutral-fixture diff (the `html_escape`
    case above) as the fixture, and record the **baseline** — a `tests`-angle worker given the
    *current* `tests.md` rubric plus that diff has no rubric basis to flag the regression-blind
    assertion. This baseline is the "red" state the edit must turn green.
- [ ] **Step 2: Apply the prompt edit**
  - Add the "Regression-blind assertions" bullet after `tests.md:13`, and extend the `MEDIUM`
    severity-rubric line (`tests.md:29`) as shown in §2. No other edits.
- [ ] **Step 3: Verification**
  - Re-run the behavioral check: a `tests`-angle worker given the *updated* rubric plus the
    same neutral-fixture diff now surfaces a `MEDIUM`, non-blocking finding that names the
    regression-blind fixture and recommends an exercising one (e.g. a URL containing `&`/`"`).
  - Confirm the change is additive and breaks nothing mechanical: run
    `bash skills/woostack-review/scripts/tests/run-tests.sh` (it tests scripts, not prompt
    content, so it must stay green) — evidence the edit touched no code path.
