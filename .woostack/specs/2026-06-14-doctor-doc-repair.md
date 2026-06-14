---
name: doctor-doc-repair
type: spec
status: approved
date: 2026-06-14
branch: feature/doctor-doc-repair
links:
---

# Doctor repairs docs to templates/rules + corrects static status drift — Design Spec

> Visualize on demand: render this file with [spec-template.html](spec-template.html) for a rich view. Markdown is the source of truth; the HTML is a presentation target only.

> `status:` is the build-loop phase enum: `draft → hardened → approved → planning → ready → executing → in-review → done` (plus the terminal `abandoned`). The build loop authors each transition and `/woostack-status` reads it; the enum and join contracts are defined once in [conventions.md](../../woostack-status/references/conventions.md).

> **Plan:** [[plans/2026-06-14-doctor-doc-repair]]

## 1. Problem

`woostack-doctor` lints and repairs `.woostack/` store integrity and conventions, but its
**doc-shape** coverage is one check deep: `spec-plan-backlink` is the only check that touches
spec/plan/fix template conformance. The rest of the template-and-rules contract goes unenforced:

- A spec/plan/fix can carry a missing or wrong `type:` — which silently breaks Obsidian typing
  and the memory-recall routing that excludes specs by `type`.
- A plan can be missing the canonical `**Source:** .woostack/specs/<file>.md` join line, or carry
  a `source:` frontmatter value that disagrees with that line. The board falls back to a fuzzy
  slug match, and the Obsidian backlink degrades.
- A `status:` value can be a typo or alias (`aproved`, `in_review`, `complete`), or sit in the
  wrong artifact's band (a spec authored with a plan-lifecycle value like `executing`).

`woostack-status` *flags* status drift but, by doctrine, never rewrites it — and it computes the
live `executing → in-review → done` band from git/PR state, which is correct truth to leave
computed, not bake into a file. But the **authoring-time** slice of that drift — enum typos,
wrong-band values — has no repairer anywhere. Today the only fix is a human hand-editing
frontmatter.

## 2. Goal

Extend `woostack-doctor` with a family of **doc-template + static-status-drift** checks that
diagnose and (gated) repair specs, plans, and fixes against their templates and the
`conventions.md` enum, reading **only file content** — no git, no PR, no network. Deliver real
"status correction" through a curated **exact-match** alias normalization, while keeping the
`doctor ↔ status` boundary crisp: doctor owns static authoring drift; `woostack-status` remains the
sole, read-only owner of the git/PR-derived live band.

## 3. Non-goals

- **No git/PR state in doctor.** Never compute or write the live `executing | in-review | done`
  band — that stays `woostack-status`'s read-only computed truth. Doctor reads file content only.
- **No section-body checks.** Section prose (`## 1. Problem` … `## 9. Open questions`, plan
  Increment/Task structure) is authored content doctor cannot generate; out of scope.
- **No fuzzy status matching.** Only exact hits against the curated alias table auto-fix; anything
  else is `report`.
- **No memory-content curation** (that is `woostack-dream`) and **no board reconciliation** (that
  is `woostack-status`).
- **Never merges**, never scaffolds (absent `.woostack/` → point at `woostack-init`).

## 4. Approach

A pure extension of doctor's established check architecture — no new layer, no new dependency:

- New per-check scripts under `skills/woostack-doctor/scripts/checks/`, each emitting findings in
  the existing `severity⇥code⇥fixable⇥path⇥message` line format and honoring the uniform calling
  convention (`<check> <WOO_ROOT>` to diagnose, `<check> --fix <WOO_ROOT> <extra-args...>` to
  repair).
- **Registration is automatic.** `doctor.sh` discovers checks with `for chk in "$HERE"/checks/*.sh`
  — dropping a new `checks/*.sh` wires it into both diagnose and `--check`. **No `doctor.sh` edit.**
  Wiring work is: catalog in `references/checks.md`, tests in `scripts/tests/`, and the SKILL.md
  boundary amendment.
- Checks reuse `woostack-init/scripts/lib.sh` (`source "$HERE/../../../woostack-init/scripts/lib.sh"`,
  as `memory.sh` already does) for `field "$f" <key>` frontmatter reads, and the
  `VALID=" a b c "` / `[ "${VALID/ $x /}" = "$VALID" ]` membership idiom (same shape as `status.sh`'s
  `VALID_PHASES`). A doc whose `head -1` is not `---` (no frontmatter fence) is `report`, never
  auto-edited — mirrors `memory-malformed`.
- The status-value alias table is **curated and exact-match**, owned by the `status-enum` check.
  `conventions.md` stays the canonical home of the enum; doctor links it and does not restate it.
  (The valid-phase set is hardcoded in the check the way `status.sh`'s `VALID_PHASES` already is —
  an accepted third copy, all three pointing at `conventions.md` as canonical.) The alias
  normalization is mentioned in `checks.md`.

The new checks (codes are the contract; severities settled below):

| code | rule (across `specs/`, `plans/`, `fixes/`) | severity | fixable |
|---|---|---|---|
| `doc-type` | `type:` missing, or not matching the dir (`specs/`→`spec`, `plans/`→`plan`, `fixes/`→`fix`) | **warn** | **auto** — dir implies the type (no fence ⇒ report) |
| `status-enum` | `status:` value not in the `conventions.md` enum | **error** | **auto** on an exact alias-table hit; **report** otherwise (no enum/alias hit ⇒ can't guess intent) |
| `status-band` | status value belongs to the *other* artifact's band: a spec carrying a plan-lifecycle value (`planning`/`ready`/`executing`/`in-review`/`done`), or a plan carrying a spec value (`draft`/`hardened`/`approved`). **Skips `fixes/`** (a fix is its own spec+plan — no opposite band). | warn | **report** — can't mechanically pick the right value |
| `plan-source` | plan missing the `**Source:** .woostack/specs/<file>.md` line | warn | **auto** when `source:` frontmatter resolves to an existing spec (derive + insert the line); **report** when neither `source:` nor a same-basename spec exists |
| `plan-source-sync` | plan's `source:` frontmatter path ≠ the canonical `**Source:**` line path | warn | **auto** — set `source:` ← the canonical line (the line is the canonical join per `conventions.md`) |
| `spec-plan-backlink` | *(existing — unchanged)* | warn | auto |

`status-enum` and `status-band` are **orthogonal**: `status-enum` normalizes a misspelling against
the alias table regardless of band (`wip` on a spec → auto-fix to `executing`), and `status-band`
*independently* reports that `executing` is a plan-band value on a spec. One repairs spelling; the
other surfaces a band judgment for a human.

**Boundary amendment.** `woostack-doctor`'s hard constraint *"Never reconcile the board (that is
`woostack-status`)"* is refined, not dropped: doctor repairs **static, authoring-time** doc drift
(enum/alias normalization, frontmatter shape, join lines; reports wrong-band) but **never computes
or writes the git/PR-derived band**. SKILL.md's description and hard-constraints list, plus the
cross-link to `conventions.md`, are updated to draw this line explicitly.

## 5. Components & data flow

- **`scripts/checks/doc-type.sh`** — walks `specs/ plans/ fixes/`; for each `.md`, reads `type:`;
  emits `doc-type` when missing/mismatched. `--fix <root> <file> <expected-type>` rewrites/inserts
  the `type:` key.
- **`scripts/checks/status-enum.sh`** — reads `status:`; if not in the valid enum, looks it up in
  the curated alias table. Hit → `auto` (emit + `--fix` rewrites to canonical). Miss → `report`
  with a "unknown status; did you mean …?" message only when an alias is *close* (still
  exact-keyed, never applied). Owns the alias table.
- **`scripts/checks/status-band.sh`** — `report`-only; classifies the dir's expected band and emits
  when the authored value is in the opposite band.
- **`scripts/checks/plan-source.sh`** — handles both `plan-source` (line presence; derive from
  `source:`) and `plan-source-sync` (line ↔ frontmatter agreement). One script, two codes (the
  way `memory.sh` emits a family). `--fix` takes a subcommand to disambiguate which repair to apply
  (e.g. `plan-source.sh --fix <root> <plan> source-line|source-sync`), documented in `checks.md`.
- **`doctor.sh`** — **no edit**: its `checks/*.sh` glob auto-discovers the new scripts for both
  diagnose and `--check`.
- **`references/checks.md`** — adds the catalog rows (code, severity, fixable, `--fix` args) +
  documents the alias table and the static-vs-computed-drift boundary.
- **`SKILL.md`** — amends the description + hard constraints for the refined boundary (doctor owns
  static authoring drift; never the git/PR-derived band).
- **`woostack-add-phase-enum-value` memory note** — this feature adds a new enum-consuming site
  (`status-enum`/`status-band`'s hardcoded valid set); the note's site list is updated during the
  wire-up increment.

Data flow is unchanged: orchestrator → checks emit findings → skill groups `auto` into a proposed
changeset → **hard gate** → apply approved `--fix` paths → `woostack-commit` → re-run to confirm.

Alias table (initial curated set, exact-match; extensible):

```
aproved      -> approved
approve      -> approved
hardend      -> hardened
in_review    -> in-review
inreview     -> in-review
reviewing    -> in-review
complete     -> done
completed    -> done
merged       -> done
wip          -> executing
planned      -> planning
abandon      -> abandoned
abandonded   -> abandoned
```

## 6. Error handling

- **No `.woostack/`** → existing engine behavior is unchanged (point at `woostack-init`); the new
  checks add nothing here.
- **`report` findings are never auto-applied** — surfaced in the "manual / judgment" list only.
- **Ambiguous repair** → `report`, never `auto`: a `status:` with no enum/alias hit, a wrong-band
  value, or a `plan-source` with no derivable source.
- **Idempotent `--fix`** — re-applying an already-good repair is a no-op (grep-guard before mutate,
  as `gitignore-drift` and `spec-plan-backlink` already do).
- **Phantom-repair guard** — after a `--fix`, confirm the change actually landed; if not, escalate
  to a `manual` `error` finding and exit nonzero (mirrors `spec-plan-backlink`'s no-H1 guard) so the
  orchestrator never reports a phantom-successful repair.
- **Consumer-CI migration** — new `error`-severity codes can newly fail `--check` on pre-existing
  consumer docs. Severities are chosen to minimize surprise: prefer `warn` wherever a fallback keeps
  the board working (slug-match for a missing `**Source:**` line), reserve `error` for genuine
  structural breakage (see §9).

## 7. Acceptance criteria

Each AC is a testable behavior → ≥1 plan task.

- **AC1 — `doc-type` detect + repair**
  - happy: a spec/plan/fix with the correct `type:` → no finding.
  - error: a plan with `type: spec` (or no `type:`) → emits `doc-type` `auto`; `--fix` sets
    `type: plan`; re-run is clean.
  - edge: `--fix` on an already-correct file is a no-op (idempotent).
- **AC2 — `status-enum` alias hit**
  - happy: `status: approved` → no finding.
  - error: `status: aproved` → emits `status-enum` `auto`; `--fix` rewrites to `approved`.
  - edge: re-apply is a no-op; a value already canonical is untouched.
- **AC3 — `status-enum` miss (report-only)**
  - error: `status: frobnicate` (no enum or alias hit) → emits `status-enum` `report`; **never**
    auto-applied even when "fix all" is approved.
- **AC4 — `status-band` (report-only)**
  - error: a spec with `status: executing` → emits `status-band` `report` (plan-band value on a
    spec); a plan with `status: hardened` → emits `status-band` `report`.
  - happy: a spec with `status: approved` and a plan with `status: executing` → no finding.
- **AC5 — `plan-source` line presence**
  - error: a plan missing the `**Source:**` line but with `source: .woostack/specs/x.md` (existing
    spec) → emits `plan-source` `auto`; `--fix` inserts the canonical line; re-run clean.
  - edge: a plan with neither a `source:` frontmatter nor a same-basename spec → emits `plan-source`
    `report` (nothing derivable).
- **AC6 — `plan-source-sync`**
  - error: a plan whose `source:` path ≠ the `**Source:**` line path → emits `plan-source-sync`
    `auto`; `--fix` sets `source:` to the line's path.
  - edge: line and frontmatter already agree → no finding.
- **AC7 — gate + no-git**
  - Nothing mutates before approval (the existing hard gate covers the new `auto` findings).
  - None of the new checks invoke `git`, `gh`, or the network (assertable: run with `PATH` stripped
    of `git`/`gh`, or assert no such calls — diagnose + `--fix` still succeed).
- **AC8 — orchestrator + catalog wiring**
  - `doctor.sh`'s `checks/*.sh` glob runs the new checks with **no edit to `doctor.sh`** (their
    codes appear in diagnose output on a seeded-bad workspace); `--check` exits nonzero iff a new
    `error` (i.e. an unknown `status:`) is present — `doc-type`/`status-band`/`plan-source*` being
    `warn` keep exit 0.
  - `references/checks.md` lists every new code (with severity, fixable, `--fix` args);
    `test-no-stale-paths.sh` stays green.

## 8. Testing

> Strategy only — harness, test levels, fixtures, CI. Per-behavior cases live in §7.

Doctor's existing pure-bash harness: `scripts/tests/run-tests.sh` driving `test-*.sh`, with seeded
fixture workspaces. Add per-check test files (or extend `test-health-checks.sh` /
`test-repair-apply.sh`) covering, for each new check: diagnose-detects, `--fix`-repairs,
reapply-idempotent, `report`-never-auto-applied, and the no-git assertion (AC7). Extend
`test-orchestrator.sh` for registration (AC8) and keep `test-no-stale-paths.sh` green for the new
cross-links. TDD red-first per increment (woostack-tdd kernel): each check's failing diagnose test
before the check script, each `--fix` test before the repair path.

## 9. Resolved decisions

- **Severity (settled).** `status-enum` = **error** (an unknown `status:` already breaks
  `status.sh`'s phase derivation → the right signal; fails `--check` until fixed). `doc-type` =
  **warn** (hurts Obsidian + memory-recall routing but breaks no board join → surfaces + auto-fixes
  without newly failing a consumer's `--check`). `status-band`, `plan-source`, `plan-source-sync` =
  **warn**. The one new way `--check` can newly fail a consumer is an unknown `status:` value;
  document this migration in `checks.md`.
- **Alias table (settled).** Curated, exact-match, owned by the `status-enum` check (initial set in
  §5, extensible). `conventions.md` stays the enum home and is linked, not restated; `checks.md`
  mentions the alias normalization.
- **`fixes/` band semantics (settled).** `status-band` **skips `fixes/`** (a fix is its own
  spec+plan — no opposite band). `status-enum` and `doc-type` still apply to `fixes/`.
- **Registration (settled by exploration).** No `doctor.sh` edit — the `checks/*.sh` glob
  auto-discovers new checks.
- **Enum/alias orthogonality (settled).** `status-enum` normalizes spelling regardless of band;
  `status-band` independently reports band. A `wip` on a spec auto-fixes to `executing` **and** is
  reported as a plan-band value on a spec.

_No open questions remain._
