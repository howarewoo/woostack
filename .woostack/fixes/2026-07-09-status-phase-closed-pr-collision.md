---
type: fix
status: hardened
branch: fix/status-phase-closed-pr-collision
---

# Fix: /woostack-status stuck on executing/in-review from closed-unmerged PRs, plus false branch collisions on done/abandoned rows

Fixes [#463](https://github.com/howarewoo/woostack/issues/463).

## 1. Root Cause

Two independent defects in `skills/woostack-status/scripts/status.sh`, both confirmed by
tracing `resolve_phase` and the main render loop (woostack-debug, inline).

### RC1 — `prcount` counts CLOSED PRs, so a completed feature never resolves `done`

- The PR tally loop increments `prcount` for **every** discovered PR unconditionally (L362),
  while `open`/`merged` increment only for their own states (L363). A `CLOSED` (unmerged) PR
  therefore inflates `prcount` past `open + merged`.
- `resolve_phase` gates `done` on `merged -eq prcount` at two sites:
  - **L180** — `frac=100 && merged>0 && merged -eq prcount` (checkbox plans)
  - **L186** — zero-checkbox authored-done (`merged>0 && merged -eq prcount`)
- With a closed-unmerged PR present, `merged < prcount`, both `done` rules fail, and control
  falls through to the `case "$authored"` block (L200-209), which — for authored
  `executing`/`in-review`/`done` with a plan — echoes `executing`. Result: a feature whose
  work is complete (frac=100, or authored-done for a zero-checkbox plan) and whose only stray
  artifact is a `CLOSED` PR is pinned to `executing`/`in-review` indefinitely. (An `open` PR
  is handled earlier at L179 and is not the concern here.)
- **Evidence:** reproduced by fixtures `oc` (test-status.sh L281-288), `ocd` (L290-297), and
  `zc` (L309-317) — all currently assert `executing` for merged+closed inputs.

**Deliberate-behavior interaction — surface at the approval gate.** The "a closed-unmerged PR
keeps the feature visible" rule is **not accidental**: it was intentionally introduced by issue
[#456](https://github.com/howarewoo/woostack/issues/456)
(`.woostack/fixes/2026-07-04-status-zero-checkbox-done.md`, §2 "Effects"), is pinned by the
three tests above, and is documented in `conventions.md` L46-47 and the `resolve_phase`
comments L181-195. **Issue #463 reverses that guard for _completed_ plans.** This is a coherent
refinement, not a contradiction: genuine incompleteness is already carried by `frac < 100`
(checkbox plans) or an authored status other than `done` (zero-checkbox plans), so once a plan
is *complete* a closed-unmerged PR is workflow noise — in this Graphite stacked-PR repo,
superseded/restacked increments routinely leave `CLOSED` PRs. #456's primary goal
(zero-checkbox authored-done + all-merged ⇒ `done`) is preserved; only its conservative
closed-PR block is relaxed, and only for completed plans.

**Invariant preserved (memory `execute-authors-terminal-plan-done`).** The board's
`done = merged-and-landed` rule and the `open>0 → in-review` gate (L179, which runs *before*
every `done` rule) are deliberate and must not be relaxed. This fix does **not** touch L179: an
open PR still renders `in-review`. It only changes the `open=0` case where a `CLOSED` PR
coexists with merged PRs — there the real work has landed and nothing is in-flight, so `done` is
consistent with the invariant. The recalled note's "not a board-logic change" guidance targeted
a different symptom (status-file rot); the closed-PR mis-derivation genuinely lives in
`resolve_phase` and is fixed there.

### RC2 — branch-collision flag runs on terminal (`done`/`abandoned`) rows

- The collision check (L404-409) records into `SEEN_BRANCHES` and compares for **every** row,
  with no `eff`-phase guard. Two terminal features — or a terminal + an active feature — that
  share a `branch:` value get a false `branch '...' also claimed by another spec (collision)`
  flag.
- `conventions.md` L58 already scopes this flag to "two **in-flight** rows on the same branch";
  the code simply never honored "in-flight". RC2 makes the code match the documented convention.
- **Evidence:** no test references `collision`/`SEEN_BRANCHES`, so current behavior is
  unspecified — the fix is additive and safe.

## 2. Proposed Fix

Minimal, targeted edits to `skills/woostack-status/scripts/status.sh`, plus the tests and docs
that pin the changed behavior. Bash 3.2 / `set -u` safe (plain `[` arithmetic, no new arrays).

### RC1 — exclude CLOSED PRs from the "all active PRs merged" determination

Introduce `active_prcount = open + merged` in `resolve_phase` and use it in place of `prcount`
at the two `done` sites (L180, L186). Leave the two `prcount -eq 0` legacy/no-PR checks (L187,
L194) unchanged — they intentionally require that *no* PR was discovered.

```bash
resolve_phase() {
  local authored="$1" hasPlan="$2" frac="$3" open="$4" merged="$5" prcount="$6" branchExists="$7" hasCommits="$8" total="${9:-0}"
  local active_prcount=$(( open + merged ))   # CLOSED (unmerged) PRs are workflow noise; exclude
  if [ "$open" -gt 0 ]; then echo "in-review"; return; fi
  if [ "$frac" = "100" ] && [ "$merged" -gt 0 ] && [ "$merged" -eq "$active_prcount" ]; then echo "done"; return; fi
  # ...
    if [ "$merged" -gt 0 ] && [ "$merged" -eq "$active_prcount" ]; then echo "done"; return; fi   # zero-checkbox
```

Apply to **both** L180 and L186 so checkbox and zero-checkbox completed plans treat closed PRs
identically (avoids a new inconsistency). Because L179 already returns when `open>0`, at both
sites `open=0` ⇒ `active_prcount == merged`, so each check reduces to "every discovered
non-closed PR is merged and at least one merged". Update the `resolve_phase` comments
(L181-195) to state that a closed-unmerged PR no longer blocks a *completed* plan from `done`
(only an open PR via L179, or an incomplete plan, does).

### RC2 — scope the collision flag to in-flight rows

Guard the collision block (L404) so terminal rows neither record nor compare their branch:

```bash
if [ -n "$br" ] && [ "$br" != unknown ] && [ "$eff" != done ] && [ "$eff" != abandoned ]; then
```

`eff` is already computed at L389 (before L404). Terminal rows are excluded from both the check
and `SEEN_BRANCHES`, so only two *in-flight* rows sharing a branch flag — matching
`conventions.md` L58.

### Tests (TDD)

- **Rewrite** the three fixtures that pin #456's closed-PR block to assert the new behavior
  (RED against current code, GREEN after the fix):
  - `oc` (L281-288): merged+closed, frac=100 ⇒ **`done`**, hidden by default, counted `done`.
  - `ocd` (L290-297): authored-done spec+plan, merged+closed, frac=100 ⇒ **`done`**.
  - `zc` (L309-317): zero-checkbox authored-done, merged+closed ⇒ **`done`**.
- **Preserve** the guardrails that must still hold (no behavior change expected): `open`-PR ⇒
  `in-review` (`zo`), zero-checkbox authored-**executing** + merged stays `executing` (`ze`),
  all-merged/no-closed ⇒ `done` (`hotel`/`zd`).
- **Add** RC2 collision fixtures:
  - two authored-done, 100%-plan, no-PR specs sharing one `branch:` ⇒ **no** `collision` flag
    (RED before fix).
  - two authored-executing specs (with plans) sharing one `branch:` ⇒ collision **still**
    flagged (guards against over-suppression).

### Docs

- `conventions.md` L46-47: change "every discovered increment PR is merged" ⇒ "every
  **active (open/merged)** increment PR is merged; a closed-unmerged PR no longer blocks `done`
  once the plan is complete".
- `conventions.md` L58 already reads "two in-flight rows" — no change needed (code now matches).

## 3. Implementation Plan

- [ ] **Step 1: Reproduce with failing tests**
  - In `skills/woostack-status/scripts/tests/test-status.sh`, rewrite the `oc`/`ocd`/`zc`
    assertions to the new `done` behavior (merged+closed ⇒ done / hidden-by-default / counted
    done), keeping each fixture's setup otherwise intact.
  - Add two RC2 collision fixtures: a done-pair sharing a branch ⇒ **no** `collision` flag; an
    executing-pair sharing a branch ⇒ collision **still** flagged.
  - Run `bash skills/woostack-status/scripts/tests/run-tests.sh`; confirm the rewritten
    `oc`/`ocd`/`zc` and the done-pair collision test FAIL against current code.
- [ ] **Step 2: Apply the minimal fix**
  - `status.sh`: add `active_prcount=$(( open + merged ))` in `resolve_phase`; use it at the
    L180 and L186 `done` checks; update the L181-195 comments.
  - `status.sh`: add `&& [ "$eff" != done ] && [ "$eff" != abandoned ]` to the collision guard
    (L404).
  - `skills/woostack-status/references/conventions.md`: update the `done` bullet (L46-47) for
    the active-PR wording.
- [ ] **Step 3: Verification**
  - Run `bash skills/woostack-status/scripts/tests/run-tests.sh` — all `test-status.sh` and
    `test-html-board.sh` tests pass, including the untouched all-merged / open-PR / executing
    guards.
  - Spot-check the new `done` rendering hides completed rows and the collision flag no longer
    fires on the done-pair fixture.
