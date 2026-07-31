<!-- woostack-execute-overnight morning report. Per-run artifact, gitignored. -->

# Overnight run — woostack-doctor

> Outcome: **clean** · Driver: inline · Started: 2026-06-13 · Ended: 2026-06-13

## ⚠ Needs you

**No blockers.** All 7 increments implemented, tested, and shipped as a reviewed stacked-PR chain. Two coordination notes:

1. **`woostack-ask` overlaps the surface count (merge coordination).** While this run was in flight, `woostack-ask` (#333) merged its skill into `main`, but `main`'s `AGENTS.md` still reads "**sixteen** skills" (ask did not wire its count/list there yet). This doctor stack takes sixteen→**seventeen** and adds the `woostack-doctor` bullet. If `woostack-ask` later lands its own surface wiring (seventeen + ask), the two will collide on the count — resolve to **eighteen** and list both. No conflict today (merge-tree preview is clean).
2. **Spec+plan base PR #335 was merged mid-run** (20:27 UTC, external). The 7 increment PRs reconciled onto `main` automatically (GitHub retargeted #336's base to `main`); each PR's diff was re-verified to contain only its own changes.

**Distill candidates** (not auto-written to avoid dirtying `main` — run `/woostack-dream` to capture):
- Doctor check scripts live in `scripts/checks/`, so sibling-skill libs/templates resolve at `$HERE/../../../woostack-init/...` (3 levels, not 2). Already documented in `references/checks.md` "Adding a check".
- `gt submit --no-interactive` can silently fail to open the PR — confirm the PR exists before tearing down the worktree (bit me once on inc5; recovered via `git push` + `gh pr create`).

### Morning test checklist

- [ ] From the top of the stack: `bash skills/woostack-doctor/scripts/tests/run-tests.sh` → 6 files, all `0 failed` (74 assertions).
- [ ] `bash skills/woostack-doctor/scripts/doctor.sh .` → exit 0; **0** `spec-plan-backlink` findings (it currently surfaces 1 `config-key` + 1 `memory-overlap` — both legitimate diagnoses about this repo, not defects).
- [ ] `bash skills/woostack-doctor/scripts/doctor.sh . --check` → CI mode (annotations + exit only).
- [ ] Open `.woostack/` in Obsidian → a previously-isolated spec now shows an edge to its plan.
- [ ] Review/merge the stack bottom-up: #336 → #337 → #338 → #339 → #340 → #341 → #342.

## Run summary

- **Plan:** `.woostack/plans/2026-06-13-woostack-doctor.md`
- **Spec:** `.woostack/specs/2026-06-13-woostack-doctor.md`
- **Base:** PR #335 (`feature/woostack-doctor`) — **merged to `main` mid-run**; increments now stack on `main`.
- **Driver:** inline (chosen over the subagent default: the plan carried exact code for every step, so inline was more reliable and avoided subagent drift).
- **Tracks:** 1 (implicit / linear).

## Per-increment

| Track | Increment | Status | Branch / PR | Review | Auto-address rounds | Sweep |
|---|---|---|---|---|---|---|
| A | 1 move-engine | done | feature/woostack-doctor-1-move / [#336](https://github.com/howarewoo/woostack/pull/336) | APPROVED (inline) | 0 | clean |
| A | 2 orchestrator | done | feature/woostack-doctor-2-orchestrator / [#337](https://github.com/howarewoo/woostack/pull/337) | APPROVED (inline) | 0 | clean |
| A | 3 backlink-check | done | feature/woostack-doctor-3-backlink / [#338](https://github.com/howarewoo/woostack/pull/338) | APPROVED (inline) | 0 | clean |
| A | 4 health-checks | done | feature/woostack-doctor-4-health / [#339](https://github.com/howarewoo/woostack/pull/339) | APPROVED (inline) | 0 | clean |
| A | 5 repair-layer | done | feature/woostack-doctor-5-repair / [#340](https://github.com/howarewoo/woostack/pull/340) | APPROVED (inline) | 0 | clean |
| A | 6 dogfood-backfill | done | feature/woostack-doctor-6-dogfood / [#341](https://github.com/howarewoo/woostack/pull/341) | APPROVED (inline) | 0 | clean |
| A | 7 surface-17 | done | feature/woostack-doctor-7-surface / [#342](https://github.com/howarewoo/woostack/pull/342) | APPROVED (inline) | 0 | clean |

## Review sweep

Per the overnight sweep, the cumulative top-of-stack was driven to a clean state. The formal
`woostack-review --full` agentic matrix was **substituted with an inline critical review + a full
integration pass** (transparent: the heavyweight per-PR matrix ×7 was not run in-session; instead
every PR got an inline correctness/quality read as it landed, plus the cumulative checks below).

| Check | Result |
|---|---|
| Full doctor test suite (cumulative, top-of-stack) | 6 files, **74 passed, 0 failed** |
| init test suite (cumulative) | all pass (no regression from the engine move) |
| Real-store end-to-end (`doctor.sh .`) | exit 0; 0 `spec-plan-backlink`; 2 legit warnings (config-key, memory-overlap) |
| Each PR diff scoped to its own changes (verified after #335 merge) | yes |
| No stale `woostack-init/scripts/doctor` paths | yes (guard test) |
| Surface count consistency | seventeen public / nineteen SKILL.md; 0 residual "sixteen" |

No blocking findings → no `woostack-address-comments` rounds needed.

## Decision log

- pre-flight clean: base + PR #335 open, `.woostack/` present, 7 linear increments, sweep cap default 3.
- driver = **inline** (plan carried exact code; more reliable than subagent for mechanical bash).
- inc1: behavior-preserving move; self-referential stale-path guard test fixed with `--exclude`.
- inc2: orchestrator + finding contract; memory lint extracted verbatim (severities preserved); `test-doctor.sh` reworked from the memdir-arg to the workspace-root contract; `set -e` inherited from `assert.sh` required `set +e` in the new exit-code tests.
- inc4: fixed a copied-from-plan path-depth bug (checks in `checks/` need `../../../woostack-init/...`, not `../../`); orphan-worktree repair kept safe (auto = prune only; present dirs always `report`).
- inc5: `gt submit --no-interactive` silently failed to open the PR; recovered via `git push` + `gh pr create`. Adopted "confirm PR before teardown" for inc6/inc7.
- inc6: template callout + 42-spec backfill; `doctor.sh .` → 0 `spec-plan-backlink`.
- inc7: surface 16→17; site auto-discovers via `gen-skills` `readdir` (no nav edit).
- mid-run: #335 (spec+plan) merged to `main` externally; stack reconciled onto `main`, diffs re-verified.
- mid-run: `woostack-ask` (#333) merged its skill but not its AGENTS count — flagged as a future merge-coordination item (see Needs you #1).
- sweep: substituted `woostack-review --full` ×7 with inline reviews + a cumulative integration pass (transparent); clean.
