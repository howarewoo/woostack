---
type: fix
status: in-review
branch: fix/tests-regression-blind-fixtures
---

# Fix: Add an explicit `tests`-angle rubric item for regression-blind assertions (fixtures neutral to the change under test)

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

Net: the rubric has no *explicit* fixture-exercises-the-behavior (mutation-sensitivity)
heuristic. A worker still surfaces such a fixture — but only incidentally, via the generic
"Missing edge cases on new branches" bullet (`tests.md:16`), and frames it as a *coverage gap*
("add more cases") rather than as a regression-blind assertion. There is no named category for
"the assertion that is present does not defend the behavior," so the finding's title, framing,
and severity drift by model tier.

Real-world origin (dogfooded on `fix/status-board-github-links`): new tests asserted an
anchor's `href` output, but every fixture URL was HTML-escape-neutral (no `&`, `"`, `<`), so a
regression that dropped `html_escape` from the href would leave every assertion green — the one
contract behavior the tests existed to defend was regression-blind, yet surfaced only as a
generic "missing edge cases" note.

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

- [x] **Step 1: Establish the concrete behavioral baseline (no-runner → concrete verification)**
  - Prompt-content changes have no unit-test runner, so use the woostack-tdd no-runner
    carve-out: construct the minimal escape-neutral-fixture diff (the `html_escape` case above)
    and record the **baseline** against the *current* rubric via `completion()`. Measured (fix
    session): a fast-tier (`smol`) `tests` worker flagged the neutral fixture 3/3 but titled it
    "Missing edge cases on new branches" (a coverage gap), never "regression-blind"; the strong
    (`default`) tier surfaced it too. So the "red" baseline is not *silence* but *mis-framing* —
    no named regression-blind category and no pinned severity.
- [x] **Step 2: Apply the prompt edit**
  - Added the "Regression-blind assertions" bullet after `tests.md:13` (now `tests.md:14`), and
    extended the `MEDIUM` severity-rubric line (now `tests.md:30`) as shown in §2. No other edits.
- [x] **Step 3: Verification**
  - Re-ran the behavioral check against the *updated* rubric with the same neutral-fixture diff.
    Measured (fix session): the fast-tier worker now titles the finding "Regression-blind
    assertions (fixture neutral to the transformation under test)" 3/3, states it "would stay
    green if the transformation were removed," and recommends an exercising fixture — the precise
    frame + `MEDIUM` severity the new bullet defines (vs. the "missing edge cases" framing before).
  - Confirmed the change is additive and breaks nothing mechanical: ran the full
    `skills/woostack-review/scripts/tests/test-*.sh` suite (45 scripts) — 45/45 pass. The scripts
    exercise shell code, not prompt content, so a green suite is evidence the edit touched no code path.
