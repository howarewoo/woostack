---
type: fix
status: in-review
branch: fix/plan-status-done-on-final-increment
---

# Fix: Plan frontmatter `status:` never advances to `done`, so it rots after the last increment ships

## 1. Root Cause

In the build loop the plan lifecycle is
`planning → ready → executing → in-review → done` (+ terminal `abandoned`)
(`skills/woostack-status/references/conventions.md:8-11`). Authorship of those
transitions is split across skills:

- `woostack-plan` authors `status: planning`.
- `woostack-build` step 6 authors `status: ready`.
- `woostack-execute` then runs every increment but **ticks checkboxes only and
  explicitly never touches the plan frontmatter** (`skills/woostack-execute/SKILL.md`
  "Tick checkboxes in place"; the skill description says "tick the plan's checkboxes
  in place"). It never merges either.

No skill authors the terminal `executing → in-review → done` transitions on a **plan**.
Those bands are left to be *derived* by the `/woostack-status` board from artifacts
(`skills/woostack-build/SKILL.md:172`, "the board also computes from artifacts").

**Consequence (the drift):** when a plan's last increment is committed and its PR opened
(and later merged), nothing advances the plan **file's** `status:`. It stays frozen at
`ready`/`executing` forever. The board can *derive* the true band when `gh` + the `Spec:`
trailer are available (`resolve_phase`, `status.sh:177-178`), but the **authored field on
disk rots** — it disagrees with reality. That stale authored value is the "status drift."

**Contrast — fixes do not have this gap.** `woostack-fix` (the *outer* orchestrator) owns
its fix-file lifecycle and explicitly advances it: `status: in-review` when the PR opens,
`status: done` once merged (`skills/woostack-fix/SKILL.md:140-142`). Execute ticks the fix
file's checkboxes but does not touch its frontmatter — the transition stays with the fix
skill. Plans have no equivalent owner for the terminal transition, which is the gap.

**Evidence — `resolve_phase` (`status.sh:175-200`):**
- `:177` `if open>0 → in-review` (first check; wins over everything).
- `:178` `frac=100 AND merged>0 AND merged==prcount → done` (derived done = all PRs merged).
- `:184` trusts an authored `done` only when `frac=100 AND prcount==0 AND hasCommits==0`
  (legacy / untrailered, branch already gone).
- `:192` while a plan has commits/branch/PR, authored `done` still renders `executing`.

So the board deliberately treats `done` as *merged-and-landed*. An authored `done` ahead of
merge is silently reconciled to `in-review`/`executing` (no false drift flag), and converges
to `done` once the stack merges and the branches are gone.

## 2. Proposed Fix

**Decision (user, 2026-06-16): `woostack-execute` authors the terminal `status: done` at
the final increment.** When execute ticks the **last** plan checkbox (plan now 100%), it
also writes `status: done` to the **plan** frontmatter and commits that one-line bump via
`woostack-commit --no-pr-update`, so the terminal authored value persists to the branch tip.
This is the plan lifecycle's terminal authored transition — symmetric with `planning`
(`woostack-plan`) and `ready` (`woostack-build`).

This is a deliberate, **narrow carve-out** of execute's "never touches frontmatter" rule:
execute authors **exactly one** frontmatter value — the terminal `status: done` on a **plan
file only** — and nothing else. It must **not** touch **fix-file** frontmatter (that lifecycle
stays owned by `woostack-fix`), so the carve-out is plan-scoped and `woostack-fix:143-145`
stays true.

`status.sh` / the board are **not** changed: `done` is already a valid plan status everywhere
(`conventions.md`, `status.sh:35`, `status-enum.sh`, `status-band.sh`), and the board correctly
shows `in-review` while the final PR is open, then `done` at merge. The fix removes the
**file rot**; the board's reality-derivation is correct and stays. (See Open Question Q1.)

Timing note: execute never merges and never watches merge, so it cannot author `done` at the
*merge* event. The reachable terminal point is "final increment committed, PR opened" — the
user accepted authoring `done` there (file leads, board reconciles to `in-review` until merge).

## 3. Implementation Plan

- [x] **Step 1: Reproduce / pin current behavior (TDD)**
  - No code runner covers SKILL.md prose, so this is the no-runner carve-out
    ([woostack-tdd](../../skills/woostack-tdd/SKILL.md)): the verification is a grep-assertion
    that the terminal-done step is **absent** today, then present after the edit.
  - Confirm `status.sh` tests stay green as a regression guard (this fix makes **no** board
    change, per Q1): `bash skills/woostack-status/scripts/tests/run-tests.sh`.

- [x] **Step 2: Author the terminal-done step in `woostack-execute`**
  - `skills/woostack-execute/SKILL.md`: in **Terminal state** (`:161-167`) add the step —
    "after the final increment is committed and every plan checkbox is `[x]`, author
    `status: done` on the **plan** frontmatter and commit the bump via
    `woostack-commit --no-pr-update`." Scope it explicitly to **plan files**, not fix files.
  - Add a **Hard constraint** (`:203-219`) carving out the boundary: "Author exactly one
    frontmatter transition — the terminal plan `status: done` at 100% — and nothing else;
    never author fix-file frontmatter (owned by `woostack-fix`)."
  - Reconcile the existing "Tick checkboxes in place / does not touch frontmatter" wording so
    the carve-out is not self-contradictory.

- [x] **Step 3: Propagate the carve-out to every site asserting "execute never touches frontmatter"**
  - Audit + update the cross-cutting claims (the ~multi-site wiring pattern). Candidate sites:
    `woostack-execute` description front-matter line, `woostack-build` step 8/9 prose
    (`:132-134`, `:169-172`), `woostack-fix:143-145` (verify it stays true — fix-file scoped),
    `conventions.md`, and the `using-woostack` routing notes if they restate the boundary.
  - `grep -rn "does not touch.*frontmatter\|ticks.*checkboxes\|never touch" skills/` to find all.

- [x] **Step 4: Update `woostack-build` prose**
  - `skills/woostack-build/SKILL.md:132-134,169-172`: the plan reaches `done` because execute
    **authors** it at the final increment; keep the "board also derives/reconciles from
    artifacts (shows in-review while the final PR is open)" note.

- [x] **Step 5: Update `woostack-execute-overnight`**
  - `skills/woostack-execute-overnight/SKILL.md`: same terminal obligation — when a track's
    final increment completes and all plan checkboxes are `[x]`, author `status: done` and
    commit the bump before the morning report. (See Q2 for multi-track semantics.)

- [x] **Step 6: Refine the `done` definition in conventions**
  - `skills/woostack-status/references/conventions.md` (the `done` line): "authored by
    `woostack-execute` after the final increment (all checkboxes `[x]`); the board still
    derives/confirms via merged PRs and shows `in-review` while the final PR is open."

- [x] **Step 7: Docs-site sync (AGENTS.md hard constraint)**
  - `grep -rn "frontmatter\|in-review\|lifecycle\|status:" site/content/docs/` for any
    **authored** page restating the plan lifecycle / the execute boundary; update if found.
    Per-skill reference pages regenerate from `SKILL.md` — no manual edit.
  - Verify: `pnpm -C site build`.

- [x] **Step 8: Verification**
  - `bash skills/woostack-status/scripts/tests/run-tests.sh` green.
  - Grep-assert the terminal-done step + Hard constraint are present in `woostack-execute`.
  - `woostack-doctor --check` clean (no new convention violations).
  - `pnpm -C site build` succeeds.

## Open Questions — RESOLVED (harden, 2026-06-16)

- **Q1 — touch `status.sh`? → NO.** Prose + conventions only. The board's `done = merged`
  invariant is deliberate; an authored `done` ahead of merge is correctly reconciled to
  `in-review` until the stack lands, then shown as `done`. Authoring the terminal value
  removes the **file rot**, which is the actual complaint. `status.sh` is unchanged; its test
  suite stays green as a regression guard.
- **Q2 — overnight multi-track done? → author once, at whole-plan 100%.** `done` is authored
  only after **all** tracks' increments are complete (every checkbox `[x]`), never per-track.
- **Q3 — bump commit shape? → separate `--no-pr-update` commit** after the final increment's
  PR commit, mirroring `woostack-fix`'s `approved` bump. Not folded into the increment commit.
- **Q4 — standalone `/woostack-execute <plan>`? → yes, included.** The carve-out lives in
  execute itself, so standalone runs get the terminal-done authoring too — it is where the
  behavior belongs.
