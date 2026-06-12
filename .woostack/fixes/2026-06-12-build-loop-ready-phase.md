---
type: fix
status: in-review
branch: fix/build-loop-ready-phase
---

# Fix: Build loop has no "plan hardened, ready for execution" status

## 1. Root Cause

The spec frontmatter phase enum is
`draft → hardened → approved → planning → executing → in-review → done` (+ `abandoned`),
defined once in
[`conventions.md`](../../skills/woostack-status/references/conventions.md).

`woostack-build` authors a `status:` transition at each step **except after the plan
harden**:

| build step | action | status authored |
|---|---|---|
| 2 | write spec | `draft` |
| 3 | harden spec → spec-approval gate | `hardened` → `approved` |
| 4 | write plan (`woostack-plan`) | `planning` |
| **6** | **harden the plan** | **— none —** |
| 7 | commit spec+plan PR | — none — |
| 8 | execution-handoff gate | — none — |
| 9 | execute | `executing` → `in-review` |

So from step 4 through step 8 the spec sits at `planning`, whose conventions meaning is
"plan exists, **0 boxes done**" and whose board next-action is
`harden plan, then open spec+plan PR` (`status.sh:198`). That single value conflates two
distinct states:

- **plan just written, not yet hardened** (step 4 output), and
- **plan hardened, spec+plan PR ready, awaiting execution** (step 6 output).

This is asymmetric with the spec, which earns its own `hardened` value after *its* harden
(step 3). There is no phase that means "ready for execution," so the board cannot show that
a plan is done and ready to hand to `woostack-execute`, and `/woostack-status`'s next-action
keeps telling the user to "harden plan" after it is already hardened.

**Evidence:** `woostack-build/SKILL.md:82-88` (step 6 amends the plan in place, authors no
status) and `:164-169` (the "Author `status:` through the loop" constraint lists
`draft`/`hardened`/`approved`/`planning`/`executing`/`in-review` — nothing at step 6).

## 2. Proposed Fix

Insert a new head-state phase **`ready`** between `planning` and `executing`, authored by
`woostack-build` at the end of **step 6** once the plan harden stops producing questions:

```
draft → hardened → approved → planning → ready → executing → in-review → done   (+ abandoned)
```

- `planning` keeps its meaning: plan written, **not yet hardened** (authored at step 4 by
  `woostack-plan`).
- `ready` (new): plan **hardened**, 0 boxes done, spec+plan PR may be open, **ready for
  execution** (authored at step 6 by `woostack-build`).
- `ready` is a **head state** (pre-`executing`), not part of the execute→review→done band, so
  it needs **no truth-table row** — the board displays the authored value via
  `resolve_phase`'s `*) echo "$authored"` fall-through, which already returns any authored
  head value once it is in `VALID_PHASES`.
- `ready` **requires a plan** (like `planning`): it is intentionally absent from the
  `draft|hardened|approved|abandoned` "no plan is OK" exemption at `status.sh:249`, so a
  `ready` spec with no plan correctly flags.

Scope is the build loop + the status board that reads the enum. `woostack-plan` still authors
`planning` at write time (correct for standalone `/woostack-plan`); the `planning → ready`
advance belongs to `woostack-build` step 6. `woostack-fix` does **not** use this enum (fixes
track via their own fix-file frontmatter), so it is untouched.

### Edit sites (8 across 6 files)

1. `conventions.md:36` — enum string: insert `-> ready` after `planning`.
2. `conventions.md` phase-enum table (≈41-50) — new row:
   `| ready | plan hardened, 0 boxes done, ready for execution | 6 |`.
3. `status.sh:35` — `VALID_PHASES`: add `ready`.
4. `status.sh:194-205` `next_action` (spec branch) — retarget `planning)` to
   `harden the plan (woostack-harden)` and add `ready)` →
   `open spec+plan PR, then execute (woostack-execute)`.
5. `status.sh:305` — reconcile "status lags" flag group: add `ready` to
   `draft|hardened|approved|planning`.
6. `test-status.sh` — update the `planning next-action` assertion (line ~70) to the new
   planning text, and add a `ready` case (mkspec `ready` + mkplan 0-done) asserting the new
   `ready` next-action.
7. `spec-template.md:14` — enum string in the `status:` callout: insert `→ ready`.
8. `woostack-build/SKILL.md` — step 6 body (set `status: ready` when the plan harden stops)
   and the "Author `status:` through the loop" constraint (`:165`), and
   `woostack-commit/SKILL.md:154` enum pipe-list: add `ready`.

`woostack-tdd/SKILL.md:88` ("when `status:` is ≥ `planning`") and `woostack-plan/SKILL.md`
already subsume `ready` conceptually (`ready` > `planning`, plan exists) — **verify only, no
edit** unless a cross-link reads more clearly.

## 3. Implementation Plan

- [x] **Step 1: Reproduce with a failing test**
  - In `skills/woostack-status/scripts/tests/test-status.sh`, add a `ready`-phase case:
    `mkspec` a spec with `status: ready` + `mkplan` a 0-done plan (no branch commits), run
    status, and `assert_contains "$OUT" "open spec+plan PR, then execute" "ready next-action"`.
  - Also flip the existing `planning next-action` assertion (≈line 70) to the new planning
    text `harden the plan`.
  - Run the suite; confirm both new assertions **fail** first (Red): `ready` is currently an
    unknown phase (flagged + next-action `set status:`), and `planning` still emits the old
    text.

- [x] **Step 2: Wire `ready` into the board (`status.sh`)**
  - `VALID_PHASES` (`:35`): add ` ready ` so it is no longer flagged unknown and
    `resolve_phase` returns it.
  - `next_action` (`:194-205`): set `planning)` → `harden the plan (woostack-harden)`; add
    `ready)` → `open spec+plan PR, then execute (woostack-execute)`.
  - Reconcile flag (`:305`): add `ready` to `draft|hardened|approved|planning`.
  - Re-run the suite → Green. Confirm no pre-existing assertion regressed (the
    `commit-backed planning → executing` derivation at lines 103-111 must still pass —
    `ready` only changes the authored head value, `resolve_phase`'s commit/PR rules are
    unchanged).

- [x] **Step 3: Update the enum's documentation sources**
  - `conventions.md`: enum string (`:36`) + new table row for `ready` (authored at step 6).
  - `spec-template.md:14`: enum string in the `status:` callout.
  - `woostack-commit/SKILL.md:154`: enum pipe-list.

- [x] **Step 4: Author the transition in `woostack-build`**
  - Step 6 body (`:82-88`): after "hardening stops producing new questions", add "set the
    spec's `status: ready`" (mirroring step 3's `status: hardened`).
  - "Author `status:` through the loop" constraint (`:165`): add `ready` (step 6) to the
    listed transitions.
  - Sanity-check steps 8/9 prose still reads correctly with `ready` preceding `executing`.

- [x] **Step 5: Verification**
  - `bash skills/woostack-status/scripts/tests/test-status.sh` → all pass.
  - `grep -rn "planning -> executing\|planning → executing"` across `skills/` returns no
    stale enum missing `ready`.
  - `grep -rn '\bready\b' skills/woostack-status skills/woostack-build skills/woostack-commit`
    confirms every enum source lists `ready`.
  - Confirm `woostack-tdd:88` / `woostack-plan` need no edit (verify-only).

## 4. Hardening notes (resolved)

- **Board visibility of `ready`.** A `ready` row renders only when no `Spec:`-trailered PR is
  discovered (`open=0`, `prcount=0`); an open spec+plan PR flips `resolve_phase` to
  `in-review` and a merged one is counted, so the clean `ready` next-action
  `open spec+plan PR, then execute (woostack-execute)` is the correct single move. `planning)`
  trims to `harden the plan (woostack-harden)`.
- **No `resolve_phase` logic change.** `ready` is returned by the existing
  `case "$authored" in ... *) echo "$authored"` fall-through; it is deliberately **not** in the
  `executing|in-review|done` coercion branch, and `ready` + branch commits + 0 boxes stays
  `ready` (identical to `planning`'s behavior). Adding `ready` to `VALID_PHASES` is the only
  enablement needed.
- **`ready` requires a plan.** Kept out of the `draft|hardened|approved|abandoned` no-plan
  exemption (`status.sh:249`) so a planless `ready` spec still flags `no plan resolves`.
- **Out of scope (pre-existing):** the spec+plan docs PR carries a `Spec:` trailer, so once
  discovered the `:305` "status lags — PR already exists" flag fires on `ready` exactly as it
  already does on `planning` today. This fix preserves that existing behavior rather than
  changing the docs-PR-counted-as-increment interaction.
- **Untouched by design:** `woostack-fix`'s own next-action map (fix lifecycle, not this enum),
  `woostack-harden` / `woostack-plan` (author no `status:` themselves — the caller does),
  `woostack-tdd:88` (`ready` > `planning`, already subsumed), and README/`action.yml` (do not
  restate the enum).
