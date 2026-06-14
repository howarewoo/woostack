---
name: woostack-status
type: spec
status: approved
date: 2026-06-04
branch: feature/woostack-status
links:
---

# woostack-status: a derived feature board — Design Spec

> **Plan:** [[plans/2026-06-04-woostack-status]]

> Visualize on demand: render this file with [spec-template.html](../../skills/woostack-build/references/spec-template.html) for a rich view, or hand it to `woostack-visualize` (audience `engineer`). Markdown is the source of truth; the HTML is a presentation target only.

## 1. Problem

In a multi-person woostack repo, several features sit half-built at once — some specs
drafted, some plans mid-execution, some PRs open, some quietly abandoned. The state of each
feature is **implicit**, scattered across four places you must cross-reference by hand:

- `.woostack/specs/*.md` frontmatter — does a spec exist, and what phase is it in?
- `.woostack/plans/*.md` — does a plan exist, and how many checkboxes are done?
- git / GitHub — does the feature's branch exist, who owns it, how stale is it?
- PRs — which increment PRs are open or merged?

There is no at-a-glance answer to "what state is every feature in, and what should be done
next." The `status:` frontmatter field already exists on specs but has **no defined
vocabulary** — four ad-hoc words are in use (`draft` ×7, `hardened`, `approved`, `ready`)
with no ordering or meaning, and nothing reconciles the field against reality, so it can
silently lie. This repo is itself the dogfood case: 13 spec files (12 `.md` + one stray
`.html`), 12 plans, one branch reading `unknown`.

## 2. Goal

Ship `/woostack-status`: an **on-demand, read-only, derived** feature board that, for every
spec in `.woostack/`, shows its phase, plan progress, increment-PR state, owner, age, and the
single concrete **next action** — and flags any drift between the authored phase and the
artifacts on disk. Optimize equally for three jobs: state-at-a-glance, what-to-do-next, and
multi-person coordination (ownership + stalled/abandoned/collision signals).

Establish and enforce the supporting invariant that makes the board reliable:
**every spec has exactly one plan; a plan owns N increment PRs.**

## 3. Non-goals

- **No committed status file.** The board is computed fresh each run and printed to the
  terminal; never written to a tracked file (would churn and merge-conflict every time anyone
  advances a feature). No `STATUS.md`, no snapshot.
- **No web/HTML view.** Defer to `woostack-visualize` if ever wanted.
- **No authored ownership, lock, or increment-list field.** Ownership/staleness/increments
  are all derived (GitHub + git), never hand-maintained.
- **No auto-fetch and no mutation.** The board never fetches, commits, or pushes. `--fetch`
  is an explicit opt-in.
- **No blocking gate.** Enforcement is advisory (flags + a non-blocking commit-time notice),
  never a hard stop. Honors woostack's never-block ethos.
- **No new memory-store linting.** `doctor.sh` stays memory-only; reconcile lives in
  `status.sh`.
- **Not in v1:** `woostack-commit` *auto-advancing* `status:`. The loop authors it; commit
  only *checks* it (§4 enforcement). Full auto-advance deferred.
- **No cross-repo aggregation, no live watch/daemon.**

## 4. Approach

A small shell deriver (`status.sh`, modeled on `doctor.sh`) reads the real artifacts and
prints a table plus a flags block. Phase is **authored + reconciled**: a defined enum lives
in the spec's `status:` field, advanced by the build loop at every step, and the deriver
cross-checks it against artifacts — surfacing mismatches as visible warnings rather than
trusting it blindly (same honesty principle as `doctor.sh`).

### 4.1 Phase enum

Eight defined, ordered values. The build loop authors **all** of them; reconcile validates.

| phase | meaning | authored when |
|---|---|---|
| `draft` | spec written, not hardened | build step 2 |
| `hardened` | grilled, awaiting spec-approval gate | step 3 (post-grill) |
| `approved` | spec-approval gate cleared, no plan yet | step 3 (gate cleared) |
| `planning` | plan exists, execution not started (0 boxes) | step 4 |
| `executing` | branch + commits, plan partial | step 6 |
| `in-review` | an increment PR is open | step 8 |
| `done` | plan 100% + all increment PRs merged | post-merge |
| `abandoned` | shelved; terminal, hidden by default | manual |

One-time migration of the existing `.md` specs: `ready` → `approved`; keep the rest.

### 4.2 Authored vs. computed (truth table)

The loop writes `status:` at every step, but for the **execute → review → done band** the
artifacts are authoritative — reconcile computes the true phase and flags a mismatch rather
than emitting spurious "between-increment" drift:

- any increment PR **open** → `in-review`
- plan partial, no open PR, branch has commits → `executing`
- plan **100% AND all increment PRs merged AND ≥1 merged** → `done`

For the head states (`draft`/`hardened`/`approved`/`planning`) and `abandoned` — none of
which are fully visible on disk — the **authored** value is displayed; reconcile only checks
boundary sanity (e.g. `approved` but a PR already exists → flag).

### 4.3 spec ↔ plan ↔ PR hierarchy (the reliability invariant)

- **spec → plan is 1:1.** Exactly one plan per spec. Joined by a **standardized** prose line
  the plan carries in its first ~5 lines: `**Source:** .woostack/specs/<file>.md`
  (build step 4 writes it; the format is pinned in `conventions.md`). Slug-match is the
  legacy fallback. Plans stay **frontmatter-free** (they are working checklists). 0 or ≥2
  resolved plans for a spec → FLAG.
- **plan → increment PRs is 1:N.** Discovered via a machine-readable trailer
  `Spec: .woostack/specs/<file>.md` that **woostack-commit writes into every PR body**;
  `status.sh` runs `gh pr list --search "Spec: <path>"` to enumerate a spec's increment PRs.
  Old PRs without the trailer: fall back to the active-branch PR from `spec.branch` and mark
  the rollup "partial."
- **`spec.branch:` = the active increment's branch** — the live join to git/PR. Merged
  increments come from the trailer search, not an authored list.

### 4.4 What to do next (phase → action lookup)

draft→*run grill-me* · hardened→*get spec approval* · approved→*writing-plans* ·
planning→*decompose, then execute* · executing→*finish plan (N/M); start next increment
(M/N shipped)* · in-review→*address comments / merge when green* · done→*—* · abandoned→*—*

### 4.5 Multi-person (GitHub is the cross-person source of truth)

Local clones can't see teammates' branches without fetching, so the board leans on `gh`:

- **PR-bearing phases** (`executing`/`in-review`/`done`): owner = PR author, age = PR
  `updatedAt`, state from `gh` — visible regardless of local fetch.
- **Pre-PR phases** (`draft`/`hardened`/`approved`/`planning`): owner/age from the **spec
  file's** git log (committed and pulled), not the not-yet-existing branch.
- **No auto-fetch.** `--fetch` is opt-in for branch-level freshness on PR-less branches; the
  board notes when PR-less data may be stale.
- **stale** if age > `staleDays` (config, default 14). **collision** = two in-flight specs
  claiming the same `branch:`.

### 4.6 Display

- Default view: **in-flight only** (`draft`…`in-review`). `done`/`abandoned` hidden,
  surfaced as a footer count (`✓ 12 done · 3 abandoned`); `--all` expands them.
- Deriver reads `specs/*.md` only — the stray `.html` is skipped, no special-casing.

### 4.7 Config

`.woostack/config.json` gains a `status` namespace (namespace-per-tool pattern):
`{ "status": { "staleDays": 14 } }`.

### 4.8 Enforcement across actions

So the user can't silently break the board:

1. **Canonical home** — new `skills/woostack-status/references/conventions.md`: the phase
   enum, spec↔plan 1:1, the `**Source:**` plan line, the PR `Spec:` trailer, the `branch:`
   convention, and the reconcile rules. `woostack-build`, `woostack-commit`,
   `using-woostack`, and `spec-template.md` **link** it (per CLAUDE.md "cross-link, do not
   duplicate").
2. **`status.sh` reconcile** — flags violations on every board run (read-only surface).
3. **`woostack-commit` advisory check** — when a commit touches `.woostack/specs/*` or
   `plans/*`, run the cheap invariant checks (1:1 plan resolves, `branch:` present/valid,
   `status:` is a known enum value) on the touched files and print any violation as **one
   non-blocking advisory line** in the commit report. Catches breakage at ship time.
4. **`using-woostack`** — routing row, one-line invariant pointer (links `conventions.md`),
   and red-flag guard rows (second plan, hand-set/blank `status:`/`branch:`, rename/move).

## 5. Components & data flow

```
/woostack-status (skill)  [flags: --all, --fetch]
  └─ runs status.sh against ./.woostack
       ├─ read specs/*.md frontmatter → {name, status(phase), branch, date}
       ├─ per spec: resolve its plan via "**Source:**" line (slug fallback)
       │     └─ count - [x] / - [ ] → N/M  (0 or ≥2 plans → FLAG)
       ├─ gh pr list --search "Spec: <path>" → increment PRs (open/merged)  [trailer]
       ├─ owner/age: gh PR author+updatedAt (PR phases) | spec git log (pre-PR)
       ├─ reconcile (truth table + boundary checks) → FLAGS
       ├─ next-action: phase → action lookup
       └─ render: in-flight table (SPEC｜PHASE｜PLAN｜INCREMENTS｜OWNER｜AGE｜NEXT)
                  + ⚠ FLAGS + footer (✓ N done · M abandoned)
```

**New files**

- `skills/woostack-status/SKILL.md` — thin command skill: runs `status.sh`, narrates board +
  next actions. Routed from `using-woostack`.
- `skills/woostack-status/scripts/status.sh` — the deriver (ships with the skill, runs
  against the local `.woostack`; same model as `doctor.sh`).
- `skills/woostack-status/references/conventions.md` — canonical invariant doc (§4.8).
- `skills/woostack-status/tests/test-status.sh` (+ fixtures) — shell tests over a synthetic
  `.woostack`.

**Edited files**

- `skills/using-woostack/SKILL.md` — routing row, invariant pointer, red-flag rows.
- `skills/woostack-build/SKILL.md` — make spec↔plan 1:1 explicit; author `status:` at each
  step per the enum; require the `**Source:**` line when writing plans; link `conventions.md`.
- `skills/woostack-commit/SKILL.md` — write the `Spec:` PR-body trailer; run the advisory
  invariant check on touched spec/plan files; link `conventions.md`.
- `skills/woostack-build/references/spec-template.md` — document the `status:` enum; link
  `conventions.md`.
- `.woostack/specs/*.md` — one-time `status:` migration (`ready` → `approved`); fix the
  `unknown` branch and any 1:1 join gaps surfaced on first run.
- `.woostack/config.json` template (`skills/woostack-init/templates/config.json`) + the init
  reference — add the `status` namespace default.
- Root `AGENTS.md` / `.claude/CLAUDE.md` (symlinked) — 8 → 9 public command count, add the
  `woostack-status` bullet + file-map entry. README/adoption surface as needed.

## 6. Error handling

- **No `.woostack/` or no specs:** friendly empty-state, exit 0.
- **`gh`/`gt` absent or unauthenticated:** degrade — render without PR/increment/owner columns
  for PR-phase rows, print one notice; never hard-fail the board.
- **PR trailer missing (legacy PRs):** fall back to active-branch PR; mark rollup "partial".
- **Branch missing while phase ≥ `executing`:** reconcile FLAG, not a crash.
- **Plan not found / ≥2 plans:** the 1:1 FLAG, not an error.
- **Malformed/missing `status:`/`branch:`:** treat phase as `unknown`, FLAG, keep rendering
  other rows.
- **Exit code:** `0` on success even with drift flags (advisory); non-zero only on the
  script's own operational failure → safe to run in CI.

## 7. Testing

Shell tests (`test-status.sh`) over synthetic `.woostack/` fixtures, mirroring
`test-doctor.sh`. Cover:

- **Phase + next-action** — each of the 8 enum values renders the right row and next string;
  `done`/`abandoned` hidden by default, shown under `--all`, counted in the footer.
- **Truth table** — open PR → `in-review`; partial plan + commits, no open PR → `executing`;
  plan 100% + all PRs merged → `done`; authored value disagreeing with the band → FLAG, no
  spurious between-increment drift.
- **Plan join** — `**Source:**` resolution; slug fallback; `N/M` from checkboxes; 0-plan and
  ≥2-plan both FLAG.
- **Increment discovery** — `Spec:` trailer search enumerates open+merged PRs; missing
  trailer → active-branch fallback + "partial".
- **Multi-person** — owner/age from gh for PR phases vs spec git log for pre-PR phases;
  `--fetch` opt-in; stale > `staleDays`; same-branch collision FLAG.
- **Reconcile boundary** — `approved`/`≤hardened` but a PR exists → FLAG; blank/`unknown`
  branch → FLAG.
- **Degradation + empty state + config** — `gh` absent still renders; no specs → exit 0;
  `staleDays` honored, default 14.
- **woostack-commit advisory** — touching a spec that violates 1:1/branch/enum prints the
  non-blocking advisory line; a clean change prints nothing.

## 8. Open questions

- **Increment `gh` search precision.** Confirm `gh pr list --search "Spec: <path>"` reliably
  matches the trailer across open + merged; decide exact query/JSON fields at plan time.
- **Migration packaging.** Do the `ready → approved` + `unknown`-branch + 1:1 cleanup as part
  of increment 1 (engine) so the board is honest on first run, vs. a separate housekeeping
  commit. (Leaning: bundle with engine.)
- **Increment decomposition** (build step 5, ≤500 LOC each), to confirm at plan time:
  1. **Engine** — `status.sh` (parse/join/reconcile/truth-table/render) + `conventions.md` +
     config namespace + tests + the existing-spec migration.
  2. **Command + producers** — `woostack-status` SKILL; woostack-commit trailer + advisory
     check; woostack-build status-advancement + `**Source:**` line + 1:1 wording;
     spec-template enum; `using-woostack` routing/pointer/red-flags; CLAUDE.md/README surface.
