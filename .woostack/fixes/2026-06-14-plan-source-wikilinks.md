---
type: fix
status: in-review
branch: fix/plan-source-wikilinks
---

# Fix: plan `**Source:**` line should be an Obsidian `[[wikilink]]`, not a bare path

## 1. Root Cause

Not a runtime bug — a convention asymmetry. There is no failing symptom to trace, so
"diagnosis" here = mapping the authored contract and every reader of the plan→spec join.

The spec↔plan join is **asymmetric** today:

- **spec → plan** already uses an Obsidian wikilink. `spec-plan-backlink.sh --fix` inserts
  `> **Plan:** [[plans/<plan-basename>]]` into the spec, and `spec-template.md` ships the same
  callout. This creates a real edge in Obsidian's graph.
- **plan → spec** uses a **bare path**: the plan body opens with
  `**Source:** .woostack/specs/<file>.md` (`plan-template.md:8`). A bare path is **not** a wikilink,
  so it creates **no** Obsidian graph edge back to the spec. The graph is one-directional.

`.woostack/memory/` doctrine (`woostack-init/references/memory.md`) is explicit that **body
`[[wikilinks]]` are the single source of truth for the Obsidian graph**. The plan's `**Source:**`
line is exactly such a body line, yet it is authored as a path — so the plan node has no outbound
link to its spec in the graph.

**Evidence — authored as path:**
- `skills/woostack-plan/references/plan-template.md:8` → `**Source:** .woostack/specs/{{SPEC_BASENAME}}.md`
- `skills/woostack-status/references/conventions.md:14-18, 31` → "exact form `**Source:** .woostack/specs/<file>.md`"

**Evidence — readers hard-code the path shape (the blast radius):**
- `skills/woostack-status/scripts/status.sh:92` — `grep -lE "...specs/${base}([[:space:]]|$)"`
  expects `specs/<slug>.md` followed by **space or EOL**. A wikilink ends in `]]`, not space/EOL,
  and drops the `.md` → **would not match**.
- `skills/woostack-doctor/scripts/checks/spec-plan-backlink.sh:34` — `grep -oE 'specs/[^])[:space:]]+\.md'`
  requires a literal `.md` suffix. A wikilink `[[specs/<slug>]]` has no `.md` → **extraction fails**,
  silently falling back to same-basename resolution (works only when plan basename mirrors spec
  basename; breaks slug-mismatch plans).

So the join cannot simply be reformatted — the two reader regexes must accept the wikilink form
**and** keep accepting the legacy path form, because ~48 existing plans in `.woostack/plans/` are
on disk in path form and must keep resolving (no migration).

## 2. Proposed Fix

Make the plan→spec join a wikilink, symmetric with the existing spec→plan `[[plans/...]]` callout,
while keeping every reader **backward-compatible** with the legacy bare-path form.

**New authored form** (body line only):

```
**Source:** [[specs/<spec-basename>]]
```

Folder-qualified (`specs/…`), no `.md`, mirroring the spec side's `[[plans/<plan-basename>]]`.

**Three design decisions (resolved in harden log §below; override at the gate):**

- **D1 — link shape:** `[[specs/<basename>]]` (folder-qualified), *not* bare `[[<basename>]]`.
  Matches `[[plans/<basename>]]`, and disambiguates from the identically-named plan note.
- **D2 — scope:** change the **body `**Source:**` line only**; leave the frontmatter
  `source: .woostack/specs/<file>.md` property as a path. The body wikilink is what the Obsidian
  graph reads; the frontmatter `source:` stays a machine-readable mirror (and the spec side
  likewise carries no plan path in frontmatter — body callout only). Lower risk, fully symmetric.
- **D3 — readers:** accept **both** forms (wikilink preferred, path legacy). No migration of the
  48 existing plans; honors the "legacy compatibility" language already in `conventions.md`.

## 3. Implementation Plan

> One increment / one PR. In this skills repo a "failing test" step is a concrete verification
> command (extend an existing bash test, then run its runner) per the woostack-tdd carve-out.

### Task 1: Reader — `status.sh` accepts wikilink + path (red→green)

**Files:** Modify `skills/woostack-status/scripts/status.sh:92`; Test
`skills/woostack-status/scripts/tests/test-status.sh`.

- [x] **Step 1: Failing test** — add a case authoring a plan whose body line is
  `**Source:** [[specs/2026-06-01-<slug>]]` (wikilink, no `.md`) and assert the board resolves its
  plan + progress (mirror the existing `romeo` path-form case at test-status.sh:227-228). Keep a
  legacy path-form case so both are covered.
- [x] **Step 2: Run, confirm RED** — `bash skills/woostack-status/scripts/tests/test-status.sh`
  → the new wikilink case fails (plan not found, slug-fallback or `0/…`).
- [x] **Step 3: Minimal fix** — at `status.sh:92`, derive the no-`.md` slug and relax the regex to
  allow an optional `.md` and a `]`/space/EOL right boundary:
  ```sh
  local nomd="${base%.md}"
  found="$(grep -lE "^\*\*Source:\*\*[[:space:]].*specs/${nomd}(\.md)?(\]|[[:space:]]|$)" "$PLAN_DIR"/*.md 2>/dev/null || true)"
  ```
  (The `]`/space/EOL boundary preserves the existing anti-prefix-collision guarantee: `…-foo` will
  not match `…-foo-bar`.)
- [x] **Step 4: Run, confirm GREEN** — both wikilink and legacy path cases pass. (65 passed, 0 failed)

### Task 2: Reader — `spec-plan-backlink.sh` resolves wikilink + path (red→green)

**Files:** Modify `skills/woostack-doctor/scripts/checks/spec-plan-backlink.sh:34-38`; Test
`skills/woostack-doctor/scripts/tests/test-spec-plan-backlink.sh`.

- [x] **Step 1: Failing test** — add a plan whose `**Source:**` line is a wikilink to a spec whose
  basename ≠ plan basename (so the same-basename fallback cannot mask a broken Source parse), and
  assert the backlink check resolves the spec and warns/repairs on it.
- [x] **Step 2: Run, confirm RED** — `bash skills/woostack-doctor/scripts/tests/run-tests.sh`
  (or the backlink test directly) → wikilink case fails (`src` empty, wrong spec resolved).
- [x] **Step 3: Minimal fix** — drop the mandatory `\.md` from the extractor and normalize:
  ```sh
  src="$(grep -m1 -E '^\*\*Source:\*\*' "$plan" 2>/dev/null | grep -oE 'specs/[^])[:space:]]+' | head -1)"
  if [ -n "$src" ]; then
    src="${src%.md}.md"                       # one .md whether wikilink (none) or path
    [ -f "$WOO_ROOT/.woostack/$src" ] && { printf '%s\n' "$WOO_ROOT/.woostack/$src"; return; }
  fi
  ```
  (Char class `[^])[:space:]]` already stops at `]`/`)`/space, so it cleanly extracts
  `specs/<slug>` from `[[specs/<slug>]]`.)
- [x] **Step 4: Run, confirm GREEN** — wikilink + path + same-basename-fallback cases pass; full
  doctor test suite green. (test-spec-plan-backlink 10/10; full suite 82/82, 0 failed)

### Task 3: Authoring convention → wikilink

**Files:** Modify `skills/woostack-plan/references/plan-template.md:8` (+ the closing
explanatory para ~64), `skills/woostack-plan/SKILL.md` (mentions at lines 12, 48, 120, 142-143, 193).

- [x] **Step 1** — template body line → `**Source:** [[specs/{{SPEC_BASENAME}}]]`. Leave the
  frontmatter `source:` property as the path (D2).
- [x] **Step 2** — update `woostack-plan/SKILL.md` prose so the "opening `**Source:**` line"
  description reflects the wikilink form and notes the path form is still accepted (legacy).
- [x] **Step 3 (verify)** — `grep -n 'Source' …plan-template.md` shows the wikilink; the only
  remaining bare-path mentions in the plan skill are explicitly legacy-labeled.

### Task 4: Update the canonical contract + sibling docs

**Files:** `skills/woostack-status/references/conventions.md:14-18, 22-32`; `skills/woostack-commit/SKILL.md:149`;
`skills/woostack-doctor/references/checks.md:41-43` (only if wording implies path-only).

- [x] **Step 1** — `conventions.md`: state the canonical join is `**Source:** [[specs/<basename>]]`
  (wikilink), with the bare path `**Source:** .woostack/specs/<file>.md` accepted as legacy; updated
  the frontmatter-shape example's body line to the wikilink.
- [x] **Step 2** — `commit/SKILL.md:149`: noted the `**Source:**` line may be a wikilink
  `[[specs/<basename>]]` or the legacy path.
- [x] **Step 3** — `checks.md`: only *references* the conventions contract (format-agnostic), so
  cross-link left intact. Also caught + fixed `woostack-build/SKILL.md:75` (authored bare-path
  example → wikilink). `using-woostack:101` is generic ("the `**Source:**` line"), left as-is.
- [x] **Step 4 (verify)** — `grep -rn 'Source'` reviewed: every authored example is the wikilink;
  the only remaining bare-path strings are explicitly legacy-labeled.

### Task 5: Full verification

- [x] **Step 1** — `bash skills/woostack-status/scripts/tests/run-tests.sh` → 65 passed, 0 failed.
- [x] **Step 2** — `bash skills/woostack-doctor/scripts/tests/run-tests.sh` → 82 passed, 0 failed.
      Plus real dogfood: backlink check resolved the 46 on-disk path-form plans (legacy intact).
- [x] **Step 3** — Distilled to `.woostack/memory/source-line-is-multi-reader-contract.md`: *a
  plan↔spec join is a multi-reader contract — changing the `**Source:**` format means touching
  `status.sh`, `spec-plan-backlink.sh`, `conventions.md`, `plan-template.md`, woostack-plan/SKILL,
  woostack-build/SKILL, and woostack-commit/SKILL together, and readers must stay back-compatible
  with on-disk path-form plans.*

## Harden log (resolved questions)

- **Q: wikilink `[[specs/<basename>]]` vs bare `[[<basename>]]`?** → folder-qualified, for symmetry
  with `[[plans/<basename>]]` and to disambiguate the same-named plan note. (D1)
- **Q: also convert frontmatter `source:`?** → No. Body line only; the body wikilink is the graph
  edge, frontmatter stays a path mirror, matching the spec side. (D2)
- **Q: wikilink-only + migrate 48 plans, or accept both?** → Accept both; no migration. (D3)
- **Q: does relaxing `status.sh:92` reintroduce prefix collisions?** → No; the `]`/space/EOL right
  boundary preserves the exact-slug guarantee.
- **Q: out of scope?** → Migrating existing path-form plans; converting frontmatter `source:`;
  touching the PR `Spec:` trailer (a separate plan→PR join, unrelated to Obsidian linking).
