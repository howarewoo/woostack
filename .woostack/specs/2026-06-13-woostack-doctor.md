---
name: woostack-doctor
type: spec
status: approved
date: 2026-06-13
branch: feature/woostack-doctor
links:
---

# /woostack-doctor — workspace health: diagnose + gated repair — Design Spec

> Visualize on demand: render this file with [spec-template.html](../../skills/woostack-build/references/spec-template.html) for a rich view. Markdown is the source of truth; the HTML is a presentation target only.

> `status:` is the build-loop phase enum: `draft → hardened → approved → planning → ready → executing → in-review → done` (plus the terminal `abandoned`). The build loop authors each transition and `/woostack-status` reads it; the enum and join contracts are defined once in [conventions.md](../../skills/woostack-status/references/conventions.md).

> **Plan:** [[plans/2026-06-13-woostack-doctor]]

## 1. Problem

woostack is installed across many consumer repos (`pnpx skills add howarewoo/woostack`). Over
time each repo's `.woostack/` workspace drifts: broken/orphaned wikilinks, stale or missing
`source:` provenance, dead memory notes, orphan worktrees from crashed runs, `.gitignore` drift
vs the shipped template, `config.json` key gaps, and convention lag (e.g. specs authored before a
convention existed). The drift degrades agent navigation and the integrity of the knowledge store,
and there is **no single command to find and fix it**.

The capability *partly* exists but is unreachable. `skills/woostack-init/scripts/doctor.sh` is a
store linter that **only warns** and is **buried** — it runs internally during `woostack-init` and
is not invokable on demand. It covers only the memory store (wikilink resolution, provenance, dead
notes, scope), not workspace-wide health, and it never repairs.

A concrete instance of the gap: specs render as **isolated nodes** in Obsidian. The 1:1 spec↔plan
relationship is expressed only by the plan's plain-text `**Source:**` line (no graph edge), and
specs carry no backlink to their plan. The convention to fix it (a folder-qualified
`[[plans/<basename>]]` backlink on the spec) has no home, no enforcement, and no repair path — it
is exactly the class of drift a doctor should own.

## 2. Goal

Ship `/woostack-doctor`, a run-anytime public command (the 17th) that **diagnoses** a repo's
`.woostack/` workspace health and offers **gated repair** (propose → approve → apply → hand to
`woostack-commit`). Two layers:

1. A **headless diagnose engine** — pure bash, exit-coded (0 = clean, nonzero = findings) — usable
   directly in consumer CI.
2. An **interactive repair layer** — proposes a changeset for the fixable findings, mutates nothing
   before explicit approval, and hands approved file repairs to `woostack-commit`.

Doctor owns the missing quadrant of workspace health: **store integrity + convention lint/repair**.
Its first shipped convention is the spec↔plan Obsidian backlink, demonstrated end-to-end (lint +
repair + backfill of existing specs).

## 3. Non-goals

- **Not scaffolding.** Creating missing structure (dirs, `config.json`, `.gitignore`, the index)
  stays `woostack-init`'s job. Doctor lints and repairs **existing** content/conventions; it does
  not create a `.woostack/` from nothing. If the workspace is absent, doctor says "run
  `woostack-init`" and exits.
- **Not the feature board.** Drift between an authored `status:` and on-disk artifacts is
  `woostack-status`'s job. Doctor does not reconcile or render the board.
- **Not knowledge curation.** Merging/consolidating/judging memory *content* is `woostack-dream`'s
  job. Doctor flags structural problems (broken links, missing provenance) and **reports** (never
  auto-prunes) judgment-only signals like dead notes.
- **Not merging.** Doctor never merges; repairs land as a `woostack-commit` branch + PR.
- **No new convention invented here beyond the spec↔plan backlink.** Other checks lint conventions
  that already exist in the repo.

## 4. Approach

**New bundle `skills/woostack-doctor/`** — `SKILL.md` (command + procedure + hard constraints),
`scripts/` (engine + checks + tests), `references/` (check catalog + repair model).

**Engine move (sharp split).** Relocate `skills/woostack-init/scripts/doctor.sh` →
`skills/woostack-doctor/scripts/doctor.sh` as the diagnose engine, and move its test
`tests/test-doctor.sh` with it. Shared libraries (`lib.sh`, `scope-match.sh`, `build-index.sh`,
`graph.sh`, `resolve-base.sh`) remain `woostack-init`'s foundational infra; the relocated engine
sources them cross-skill by relative path (`../../woostack-init/scripts/<lib>.sh`). `woostack-init`
invokes the engine at its new path for its post-scaffold sanity pass — behavior unchanged. Increment
1 is this move + rewire with **no behavior change** (tests green from the new location).

**Diagnose layer.** A top-level `doctor.sh` orchestrator runs a set of **checks**, each a bash
function/script emitting findings as structured lines: `severity \t code \t fixable \t path \t
message`. Severity ∈ {error, warn}. `fixable` ∈ {auto, report}. The orchestrator aggregates, prints
a grouped report, and sets exit code (nonzero iff any `error`; `--check` forces diagnose-only).

**Checks (v1, broad):**
- *Store/convention (promoted from today's doctor.sh):* memory wikilink resolution; stale/missing
  `source:` provenance; dead notes (report-only); stale/non-glob scope.
- *Convention (new seed):* spec↔plan backlink — for each `.woostack/plans/*.md`, resolve its source
  spec (reuse the `status.sh:92` `**Source:** … specs/<base>` match + legacy same-basename
  fallback) and require the spec to carry a resolvable folder-qualified `[[plans/<plan-basename>]]`
  wikilink. Auto-fixable.
- *Workspace health (new):* orphan worktrees under `.woostack/worktrees/` (auto: prune the prunable
  ones); `.gitignore` drift — each woostack-managed line absent from the consumer `.gitignore`
  (auto: insert the missing line; **per-line presence**, never rewrap the user's file, so re-runs are
  no-ops); `config.json` required-key presence vs the shipped init template's keys (auto: add the
  missing key with its default; or report when the value needs a human).

**Deferred (not v1):** a "version/template lag" check. It is not meaningfully checkable without a
version manifest, which §3 excludes — a consumer uses the installed skill's template directly, so
there is nothing local to compare against unless they forked it. The convention-content angle it was
meant to catch is already covered by the spec↔plan backlink check; broader version drift waits for a
manifest (future). `config.json` key-presence is v1's "is your workspace current" signal.

**Severity → exit code.** Each check tags findings `error` or `warn`. **Structural breakage**
(unresolved wikilink, `**Source:**` pointing at a missing spec, a non-prunable corrupt worktree) =
`error`. **Hygiene/convention** (missing spec↔plan backlink, `.gitignore` drift, missing
`config.json` key, dead note, non-glob scope) = `warn`. The orchestrator exits **nonzero iff any
`error`**; `warn`-only runs exit 0, so a consumer's CI (`--check`) fails on real breakage but not on
hygiene. Both classes are still offered for interactive repair.

**Repair layer (mirrors `woostack-dream`).** After diagnose, doctor collects the `auto`-fixable
findings into a **proposed changeset** (per-item diff/summary), presents it, and **stops at a hard
approval gate**. On approval: apply file repairs to the working tree, then hand to `woostack-commit`
(fresh Graphite branch + PR; respects branch protection; never merges). Filesystem-only repairs
(orphan-worktree prune) apply directly post-approval (not committable). `report`-only findings are
never auto-applied. Nothing mutates before approval.

**Command surface (16 → 17).** Register the new command across the adoption surface: `CLAUDE.md`
(count "sixteen"→"seventeen", file map, Modes B list), `using-woostack` routing table, `site/` nav +
framing pages, and trim `woostack-init`'s SKILL/description so its "repair" claim is scaffold-only and
points to doctor for lint/repair.

## 5. Components & data flow

```
/woostack-doctor [path] [--check]
  └─ scripts/doctor.sh (orchestrator)
       ├─ sources ../../woostack-init/scripts/{lib,scope-match}.sh   (shared infra)
       ├─ checks/*.sh  → findings stream: severity⇥code⇥fixable⇥path⇥message
       ├─ aggregate → grouped report → exit code (nonzero iff any error; --check stops here)
       └─ repair layer (interactive only):
            collect fixable=auto → propose changeset → [APPROVAL GATE]
              ├─ file repairs → working tree → woostack-commit (branch + PR)
              └─ fs-only repairs (worktree prune) → apply directly
```

- **Input:** target repo root (default cwd); discovers `.woostack/`. Absent → "run woostack-init",
  exit nonzero.
- **Finding record:** `severity, code, fixable, path, message`. `code` is a stable identifier
  (e.g. `spec-plan-backlink`, `orphan-worktree`, `gitignore-drift`) for filtering + tests.
- **Changeset:** the set of `fixable=auto` findings + their concrete repair (file edit or fs op).
- **Output:** human report (diagnose) and, post-approval, working-tree edits + a `woostack-commit`
  PR.

## 6. Error handling

- **No `.woostack/`** → clear message pointing to `woostack-init`; exit nonzero; never scaffold.
- **A single check errors** (bad input, missing tool) → that check reports an `error` finding and
  the orchestrator continues other checks; never aborts the whole run on one check.
- **Obsidian/`graph.sh` absent** → backlink + wikilink checks use the grep path (the existing
  always-works default); never hard-depend on the Obsidian app.
- **Dirty working tree at repair time** → doctor relies on `woostack-commit` to branch; it does not
  apply file repairs straight onto a protected branch, and does **not** itself follow the
  woostack-internal worktree contract (that is dev-loop discipline, not imposed on consumer repos) —
  branch isolation comes entirely from the `woostack-commit` handoff. Surface the state; the gate
  still holds.
- **`.gitignore` repair** → insert only the missing woostack-managed lines (per-line presence check),
  preserving the user's file and ordering; never rewrite or reorder. Re-running is a no-op.
- **Repair declined / partial approval** → apply nothing (or only approved items); re-running
  doctor is idempotent (a re-applied backlink/gitignore block is a no-op).
- **Slug-mismatch / spec-less plan** → backlink check only fires when the source spec exists; a
  plan whose `**Source:**` spec is missing is the existing "stale provenance" finding, not a
  backlink error.

## 7. Acceptance criteria

Each AC is a testable behavior → ≥1 plan task.

- **AC1 — Engine move is behavior-preserving**
  - happy: relocated `doctor.sh` + `test-doctor.sh` run green from `skills/woostack-doctor/scripts/`;
    `woostack-init`'s post-scaffold sanity pass invokes the new path and still lints the store.
  - error: a stale reference to the old `woostack-init/scripts/doctor.sh` path fails CI/tests.
  - edge: engine sources shared libs cross-skill (`../../woostack-init/scripts/lib.sh`) and resolves
    them when run from the new dir and from a consumer repo checkout.
- **AC2 — Diagnose engine is headless + exit-coded**
  - happy: a clean workspace → empty/clean report, exit 0; `--check` runs diagnose-only.
  - error: a workspace with ≥1 `error` finding → exit nonzero (CI-gateable).
  - edge: `warn`-only findings → exit 0 by default (warnings don't fail CI) unless escalated.
- **AC3 — spec↔plan backlink check + repair**
  - happy: a spec lacking `[[plans/<basename>]]` for an existing plan → `spec-plan-backlink`
    finding (`fixable=auto`); approved repair inserts the folder-qualified backlink; re-run = clean.
  - error: a spec whose backlink points to a non-existent plan basename → unresolved-link finding.
  - edge: slug-mismatch pair (plan basename ≠ spec basename) resolves via the `Source:` line; a
    spec with no plan is not flagged.
- **AC4 — Workspace-health checks**
  - happy: orphan worktree under `.woostack/worktrees/` → `orphan-worktree` finding; `.gitignore`
    missing a woostack-managed line → `gitignore-drift` finding; missing `config.json` key →
    `config-key` finding.
  - error: a worktree dir that is **not** prunable (has uncommitted work) → reported, never
    auto-pruned.
  - edge: re-running after repair is idempotent (no duplicate gitignore lines, no re-prune).
- **AC5 — Gated repair → woostack-commit**
  - happy: approved file repairs apply to the working tree and hand to `woostack-commit` (branch +
    PR opened, not merged).
  - error: no approval (or ambiguous) → nothing mutates; report-only findings never auto-apply.
  - edge: a run containing both file repairs (commit) and fs-only repairs (worktree prune) routes
    each correctly.
- **AC6 — Born-linked spec template + backfill**
  - happy: `spec-template.md` carries `> **Plan:** [[plans/{{DATE}}-{{SLUG}}]]`; every existing spec
    with a plan gains its backlink; `doctor.sh` on `.woostack/` reports no `spec-plan-backlink`.
  - error: `{{SLUG}}`-only (no date) would produce a broken link — guarded by AC3 resolution test.
  - edge: backfill is idempotent — specs already carrying the backlink are skipped.
- **AC7 — Command surface = 17**
  - happy: `CLAUDE.md` (count, file map, Modes B), `using-woostack` routing table, and `site/` nav
    list `woostack-doctor`; `woostack-init`'s repair claim reads scaffold-only.
  - error: N/A — pure doc/listing consistency; no runtime error path (asserted by a count/listing
    check where one exists).
  - edge: `action.yml` and the internal sub-skills are untouched (doctor is a public command, not a
    review angle or sub-skill).

## 8. Testing

> Strategy only — per-behavior cases live in §7.

bash test scripts under `skills/woostack-doctor/scripts/tests/`, mirroring the existing
`test-doctor.sh` style (fixture `.woostack/` trees built in `mktemp` dirs, `assert.sh` helpers).
Each check gets a `test-check-<code>.sh` asserting it fires on a drifted fixture and stays silent on
a clean one, plus exit-code assertions for the orchestrator. Repair tests build a drifted fixture,
run the apply path, and assert the post-state + idempotent re-run; the `woostack-commit` handoff is
asserted at the boundary (commit invoked with the repaired tree), not by opening a real PR. All
wired into `run-tests.sh`. No app runtime/CI for this repo beyond the bash suite.

## 9. Open questions

All resolved during spec harden:

- **Cross-skill lib path-wiring (resolved).** The moved engine sources shared libs by relative path
  `../../woostack-init/scripts/<lib>.sh`. This is stable: the collection installs all skills as
  siblings under one `skills/` (here and in a consumer's `pnpx skills add` checkout), so
  `woostack-doctor/scripts/` → `../../woostack-init/scripts/` always resolves. Doctor therefore
  **depends on `woostack-init` being installed** (they ship together) — stated as an explicit
  dependency, pinned by AC1's edge case.
- **`--strict` (resolved — YAGNI).** v1 ships errors-only exit gating (above). No `--strict`/warn-fail
  flag; it is a trivial future add if a consumer CI asks for it. Not built now.
- **`config.json` schema source (resolved).** Required keys = the keys present in the shipped
  `woostack-init` `config.json` template. Doctor compares the consumer's `config.json` against that
  set; no separate schema file.
- **Version/template-lag check (resolved — deferred).** Dropped from v1 per §4; needs a version
  manifest (excluded by §3). Future work.
