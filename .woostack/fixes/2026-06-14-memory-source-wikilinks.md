---
type: fix
status: in-review
branch: fix/memory-source-wikilinks
---

# Fix: memory-note `source:` provenance should be an Obsidian `[[wikilink]]`

## 1. Root Cause

This is a convention change, not a defect — but it reverses a documented design decision, so
the "root cause" is **where the current contract pins provenance to a raw path and which
readers parse it**.

Today a scoped memory note's frontmatter `source:` holds a **raw path** —
`source: .woostack/specs/<file>.md` / `.woostack/plans/<file>.md` — or a review marker
`pr-<n>` / `address-comments`. The memory contract (§3) states *"Links live in the body only…
there is no `links:` frontmatter field."* So the spec/plan a note descends from is **not** an
Obsidian graph edge, even though PR #351 just made the symmetric **plan→spec** join a
`**Source:** [[specs/<basename>]]` wikilink for exactly this reason (graph symmetry, readers
stay back-compat).

Obsidian **does** index `[[wikilinks]]` inside frontmatter property values, so authoring
`source: [[specs/<basename>]]` gives the memory note a graph edge to its origin spec/plan —
closing the same asymmetry #351 closed for plans, one level down.

**Surface that parses memory `source:` (traced, evidence in `skills/`):**

- `skills/woostack-doctor/scripts/checks/memory.sh` **L48–53** — provenance check: `case`
  on `source:`; if it starts with `.woostack/specs/` or `.woostack/plans/`, file-exists check
  against `$WOO_ROOT`; empty → "missing provenance"; `pr-*`/`address-comments` → review class.
  *A `[[specs/foo]]` value would not match the path `case` → its missing-file staleness goes
  undetected.* **Pre-existing gap:** the `case` omits `.woostack/fixes/`, yet **14** notes use
  `source: .woostack/fixes/…` — fix-sourced provenance is **never** staleness-checked today.
  This fix closes that gap (the migration to `[[fixes/…]]` forces it: an unhandled
  `[[fixes/…]]` would otherwise become a false `unresolved` warning).
- `skills/woostack-doctor/scripts/checks/memory.sh` **L58–61** — unresolved-link check: greps
  the **whole file** for `[[…]]` and tests each against `$MEM_DIR/<link>.md`. *A
  `source: [[specs/foo]]` resolves to `$MEM_DIR/specs/foo.md`, which never exists → a **false**
  `unresolved [[specs/foo]]` warning.* This is the one real bug the change introduces and must
  be fixed in the same change.
- `skills/woostack-init/scripts/recall.sh` **L52–58** — one-hop link expand: greps whole file
  for `[[…]]` but only expands links that resolve to `$MEM_DIR/<link>.md` (`[ -f "$lf" ]`
  guard). A `[[specs/foo]]` source never resolves there → silently skipped. Recall renders
  `note_body` only, so frontmatter never enters PR context. **No change needed.**
- `skills/woostack-init/scripts/graph.sh` — link/backlink *lister*, not a validator. It would
  now list `specs/foo` as an outbound link, which is the desired Obsidian-style edge. **No
  change needed.**

**Migration set (this repo's `.woostack/memory/*.md`):** 29 notes carry a path-form
`source:` — 15 `.woostack/plans/…`, 14 `.woostack/fixes/…`, 0 specs. All targets exist on
`main` **except** `.woostack/fixes/2026-06-11-enable-repo-review-action.md` (sourced by
`review-action-trigger-gates.md`), which is already stale. `source: pr-<n>` /
`address-comments` markers are **not** migrated (not vault files). Readers still accept the
legacy path form (back-compat for any future hand-authored path-form note), but the sweep
converts every existing path-form note in this repo to the wikilink form.

## 2. Proposed Fix

Make the memory `source:` provenance field a **folder-qualified Obsidian wikilink** —
`source: [[specs/<basename>]]`, `[[plans/<basename>]]`, or `[[fixes/<basename>]]` — as the
authored form, while readers accept **both** the wikilink and the legacy
`.woostack/{specs,plans,fixes}/<file>.md` path (and review markers `pr-<n>` /
`address-comments` stay raw — they are not vault files). The prefix set is the three authored
artifact dirs: `specs`, `plans`, `fixes`.

Two minimal reader edits in `doctor/scripts/checks/memory.sh`, both back-compat:

1. **Provenance check (L48–53):** before the existing path `case`, normalize a `[[…]]`
   value: strip the brackets, strip an optional trailing `.md` on the inner value (robustness,
   mirroring #351's "normalize to one `.md`"), and for an inner prefixed `specs/`, `plans/`, or
   `fixes/`, rewrite to `.woostack/<inner>.md`. A raw path passes through unchanged; a **bare**
   `[[foo]]` (no recognized prefix) is out of convention — it falls through unmatched (no
   provenance warning, no review class) and is left to the link check below. **Add `fixes/` to
   the file-exists `case`** (`.woostack/specs/*|.woostack/plans/*|.woostack/fixes/*`) so
   fix-sourced provenance is finally staleness-checked — for both the wikilink and legacy path
   forms. The empty→"missing provenance" check and the `pr-*`/`address-comments` review
   classification key off the **raw** value so they work for both forms. Warning text reports
   the resolved path.

2. **Unresolved-link check (L58–61):** resolve a link prefixed `specs/`, `plans/`, or
   `fixes/` against `$WOO_ROOT/.woostack/<link>.md` instead of `$MEM_DIR/<link>.md`. This kills
   the false positive and validates artifact wikilinks wherever they appear; plain
   note-to-note links still resolve against `$MEM_DIR`. (When an artifact is genuinely missing,
   both this check and the provenance check warn — different finding codes, acceptable and
   informative.)

`recall.sh` and `graph.sh` are unchanged (already correct, per §1).

Docs updated together (multi-reader contract):
- `skills/woostack-init/references/memory.md` — §3 body-only statement gets a `source:`
  carve-out; the frontmatter `source` table row; the example frontmatter block; §154
  "provenance required"; §189 stale-provenance description (accept the `specs`/`plans`/`fixes`
  wikilink forms + the legacy paths; note `fixes/` is now validated).
- `skills/woostack-doctor/references/checks.md` — the `memory-provenance` row.
- `skills/woostack-dream/SKILL.md` — the line that follows a note's `source:` to its spec/plan
  (note it may now be a `[[wikilink]]`).

**Migration sweep:** convert all 29 path-form notes in `.woostack/memory/*.md` to the
wikilink form (`.woostack/<dir>/<basename>.md` → `[[<dir>/<basename>]]` for
`dir ∈ {specs,plans,fixes}`), via `set_field` (atomic, body-preserving) over the
`grep -rl '^source: \.woostack/'` set. `pr-<n>`/`address-comments` notes are skipped. The one
already-stale note (`review-action-trigger-gates.md` → a missing fix file) is converted
faithfully; its now-surfaced (correct) `memory-provenance` warning is a **woostack-dream
follow-up**, not repaired here — the sweep converts form, it does not fix content.

## 3. Implementation Plan

- [x] **Step 1: Reproduce with failing tests** (`skills/woostack-doctor/scripts/tests/test-doctor.sh`)
  - Add cases alongside the existing provenance block (around L30–57), one per prefix:
    - `source: [[specs/existing]]` where `.woostack/specs/existing.md` exists → **no**
      `memory-provenance` warning **and no** `unresolved [[specs/existing]]` warning.
    - `source: [[specs/missing]]` → `memory-provenance` warning reporting the resolved path
      `.woostack/specs/missing.md` is missing.
    - `source: [[plans/existing]]` (exists) → clean; `source: [[plans/missing]]` → warning.
    - `source: [[fixes/existing]]` (exists) → clean; `source: [[fixes/missing]]` → warning
      (proves the newly-added `fixes/` prefix is validated and emits no false `unresolved`).
    - Optional robustness: `source: [[plans/existing.md]]` (trailing `.md`) resolves the same.
  - Run `bash skills/woostack-doctor/scripts/tests/test-doctor.sh` → the wikilink cases fail
    (current code emits the false `unresolved` warning and misses the missing-artifact staleness).
    ✅ RED confirmed: 6 failures (false unresolved-link ×4, missing spec/fix provenance ×2).

- [x] **Step 2: Apply the minimal fix** (`skills/woostack-doctor/scripts/checks/memory.sh`)
  - Normalize the `source:` wikilink → path before the provenance `case` (L48–53): strip
    `[[ ]]`, strip an optional trailing `.md`, rewrite a `specs/`|`plans/`|`fixes/` inner to
    `.woostack/<inner>.md`. Keep empty/`pr-*`/`address-comments` behavior keyed off the **raw**
    value. **Add `fixes/` to the file-exists `case`.**
  - In the unresolved-link loop (L58–61), resolve `specs/`|`plans/`|`fixes/`-prefixed links
    against `$WOO_ROOT/.woostack/<link>.md`; plain links stay `$MEM_DIR/<link>.md`.
  - Run the test → green. ✅ doctor 58/0, orchestrator 9/0.

- [x] **Step 3: Update the contract + reader docs**
  - `memory.md`: §3 carve-out, `source` table row, example frontmatter (show the wikilink
    form), §154, §189 (three prefixes + legacy paths; `fixes/` now validated).
  - `checks.md`: `memory-provenance` row mentions the wikilink form + `fixes/` coverage.
  - `woostack-dream/SKILL.md`: `source:`-following line accepts the wikilink form.

- [x] **Step 4: Migration sweep** (`.woostack/memory/*.md`, in the worktree → rides the PR)
  - For each note matched by `grep -rl '^source: \.woostack/' .woostack/memory/*.md`, read its
    `source:` path, map `.woostack/<dir>/<basename>.md` → `[[<dir>/<basename>]]`
    (`dir ∈ {specs,plans,fixes}`), and rewrite via `set_field "$f" source "[[<dir>/<basename>]]"`.
    Skip `pr-<n>`/`address-comments`. Expect 29 notes changed (15 plans, 14 fixes).
  - Re-run `build-index.sh` is **not** needed (`MEMORY.md` hooks derive from body, not `source:`).

- [x] **Step 5: Verification**
  - `bash -n` clean. Suites: `test-doctor.sh` 58/0, `test-orchestrator.sh` 9/0; full
    `doctor.sh` exit 0.
  - Dogfood: all **28** healthy migrated sources validate clean. Two pre-existing **content**
    staleness items remain (neither a form-conversion regression — both woostack-dream
    follow-ups): `review-action-trigger-gates.md` → missing fix target
    `.woostack/fixes/2026-06-11-enable-repo-review-action.md` (now correctly surfaced, since
    `fixes/` is validated); `status-ready-phase-pr-not-drift.md` → dangling **body** link
    `[[woostack-add-phase-enum-value]]` (absent note, unchanged `$MEM_DIR` code path; main
    emits it too). Proof the fix works: the **old** checker emits a 2nd, false
    `[[fixes/…]]` *source* warning on `status-ready…` against the migrated store; the new
    checker suppresses it.

- [x] **Step 6: Distill** the gotcha — *memory `source:` is a multi-reader contract; the
  provenance check and the unresolved-link check both parse it, `fixes/` is a first-class
  provenance prefix, and Obsidian indexes frontmatter wikilinks* — mirroring #351's
  `source-line-is-multi-reader-contract` note.
