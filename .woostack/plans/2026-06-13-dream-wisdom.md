**Source:** .woostack/specs/2026-06-13-dream-wisdom.md

# woostack-dream → wisdom consolidation Implementation Plan

**Goal:** Reshape `woostack-dream` around a two-tier knowledge model — a new tracked `.woostack/wisdom/` store of generalized findings consolidated from memory + overnight + the decision corpus, with a gated default-keep prune of fully-absorbed scratch, wired wholesale into review/build/plan.

**Architecture:** Pure Markdown skills + bash tooling (no app runtime). Increment 1 lays the store foundation (contract doc, init scaffold row, gitignore regression test). Increment 2 rewrites the `woostack-dream` procedure (scan overnight, `consolidate`→wisdom, gated `prune`, corrected recoverability claim). Increments 3–4 wire consumers: build/ideate/plan read `wisdom/*.md` wholesale; review composes a `$OUTDIR/wisdom.md` artifact via a new `compose-wisdom.sh` helper mirroring the existing `recall.sh`/`memory.md` pattern. Linear `gt` stack on the spec+plan PR base.

**Tech Stack:** Markdown (`SKILL.md`, reference docs), bash + coreutils (init/review scripts, `assert.sh` test harness), Graphite (`gt`) for stacked PRs.

---

## Increment 1: Wisdom store foundation

> One independently shippable PR — the contract doc, init scaffold row, `.gitkeep` template, and gitignore regression test. No behavior change to any skill yet. Stacks on the spec+plan PR.

### Task 1: Wisdom-store contract (`wisdom.md`)

**Files:**
- Create: `skills/woostack-init/references/wisdom.md`

- [x] **Step 1: Verify the file is absent (red)**

Run: `test ! -e skills/woostack-init/references/wisdom.md && echo MISSING`
Expected: `MISSING`

- [x] **Step 2: Write the contract**

Create `skills/woostack-init/references/wisdom.md` with exactly:

```markdown
# Wisdom Store Contract

This document is the canonical reference for the `.woostack/wisdom/` store. Every woostack skill
that reads or writes wisdom files should point here rather than restating the schema. It is the
sibling of [`memory.md`](memory.md) — `memory.md` governs the scope-routed `.woostack/memory/`
store; this file governs the wholesale-loaded `.woostack/wisdom/` store.

---

## 1. Purpose — the two-tier model

woostack keeps knowledge in two tiers:

- **`.woostack/memory/`** — scoped per-fact notes, loaded by scope-matched recall (see
  [`memory.md`](memory.md)). Raw, per-feature scratch distilled by `woostack-execute`.
- **`.woostack/wisdom/`** — a deliberately small set of **generalized, cross-cutting findings**,
  loaded **wholesale** (always, regardless of file scope) to guide future development and reviews.

`woostack-dream` is the only writer of `wisdom/`. It mines the decision corpus
(`.woostack/{fixes,specs,plans}/`) plus the scratch tiers (`.woostack/memory/`,
`.woostack/overnight/`) for recurring trends and consolidates them here. Once a finding is fully
captured in a wisdom file, the contributing **scratch** inputs (memory notes + overnight reports)
are pruned (see §5). The decision corpus is never deleted.

---

## 2. Layout

```
.woostack/
├── memory/    scope-routed per-fact notes (see memory.md)
├── wisdom/    generalized findings — THIS contract
│   ├── <slug>.md
│   └── .gitkeep
├── specs/     plans/   fixes/   authored decision corpus (mined, never pruned)
└── overnight/ run reports (gitignored scratch, mined + prunable)
```

`wisdom/` is **tracked shared knowledge** — it is NOT gitignored (contrast `overnight/`, which is).
`/woostack-init` scaffolds the directory with a `.gitkeep`.

---

## 3. File format

A wisdom file is a Markdown file under `.woostack/wisdom/` with line-oriented frontmatter,
identical in parsing rules to a memory note (one `key: value` per line; comma lists, not YAML block
sequences):

```
---
name: <unique-slug>
type: wisdom
category: review | planning | testing | process
source: <comma-list of contributing inputs — see §5>
updated: YYYY-MM-DD
---
Generalized finding stated as durable guidance, plus how to apply it. [[wikilinks]] to related
memory notes, specs, or plans are encouraged (Obsidian-native, grep-resolvable).
```

| Field | Required | Description |
|---|---|---|
| `name` | yes | Unique slug; the wikilink anchor and filename basename. |
| `type` | yes | Always `wisdom`. Reserved + recall-excluded (see §4). |
| `category` | no | One of `review`/`planning`/`testing`/`process`. A hook for future selective loading; consumers currently load **all** categories. |
| `source` | yes | The contributor ledger (§5). Provenance is required, as for memory notes. |
| `updated` | yes | ISO date the finding was last written. |
| body | yes | Non-empty generalized guidance after the closing `---`. |

Keep the set **small**: a wisdom file must clear a bar higher than a memory note — it is
generalized, cross-cutting, and re-read on every review/build/plan. Fewer, denser findings beat
many thin ones.

---

## 4. Recall exclusion (structural)

Wisdom is **never** part of scope-matched memory recall. This is structural, not a code filter:
`build-index.sh` and `recall.sh` scan only `.woostack/memory/`, so a file under `.woostack/wisdom/`
is never indexed into `MEMORY.md` and never loaded by `recall.sh`. The `type: wisdom` value is
**reserved** (alongside `spec`/`plan`) and documented as recall-excluded in `memory.md` §3 so the
recall docs stay self-consistent. Wisdom reaches consumers only via the wholesale-load path (§6).

---

## 5. The `source:` ledger and prune semantics

`source:` is a comma-list of **all** inputs that contributed to the finding. Each token is one of:

- a memory note `name` (resolves to `.woostack/memory/<name>.md`);
- a repo-relative path under `.woostack/overnight/`, `.woostack/specs/`, `.woostack/plans/`, or
  `.woostack/fixes/`.

The ledger is **permanent provenance**: it still names a contributor after that contributor has been
pruned (a tombstone). It records *why* the finding exists.

**Prune** is the deletion of fully-absorbed scratch. It is computed and gated by `woostack-dream`:

1. An input is **eligible** for prune only if it appears in some wisdom file's `source:`.
2. Of the eligible inputs, the **prune list** is the subset whose value is *fully* captured by the
   wisdom finding — judged per-input by the agent at synthesis time.
3. Inputs that retain independent value (e.g. a **scope-specific** memory note whose precision would
   be lost if generalized) are **partial** → kept (or rescoped), never in the prune list.
4. **Any doubt → keep.**
5. **Only scratch is prunable:** `.woostack/memory/` notes and `.woostack/overnight/` reports.
   `specs`/`plans`/`fixes` tokens are provenance-only and are **never** deleted, even when fully
   absorbed.

Safety: `overnight/` is gitignored → a deleted report is **unrecoverable**. `woostack-dream`'s
review gate therefore shows the **full body** of every overnight report on the prune list before
any deletion, and requires explicit approval (silence is not approval). Memory notes are
git-tracked (recoverable) but are still shown with their absorbing wisdom file. Pruning a memory
note triggers `build-index.sh` regeneration; deleting an overnight report touches no index.

---

## 6. Consumption (wholesale-load)

Wisdom guides future work by being loaded **in full** (every `wisdom/*.md` body) wherever design,
planning, or review context is gathered:

- **`woostack-review`** — `prefetch.sh` composes a `$OUTDIR/wisdom.md` artifact via
  [`compose-wisdom.sh`](../../woostack-review/scripts/compose-wisdom.sh) (the wisdom analogue of
  `recall.sh`/`memory.md`); reviewers treat it as an additional rubric of learned house-rules.
  <!-- woostack-defer(increment 4): compose-wisdom.sh and the $OUTDIR/wisdom.md prefetch wiring land in increment 4; this contract reference is intentionally ahead of its implementation in the stack -->

- **`woostack-build` / `woostack-ideate`** — the design phase reads all `wisdom/*.md` before
  proposing a design.
- **`woostack-plan`** — reads all `wisdom/*.md` before writing the plan.

An empty or absent `wisdom/` makes every load a no-op (no consumer error).

---

## 7. Lifecycle

```
woostack-execute distills ──► memory/ note (scoped scratch)
woostack-execute-overnight ──► overnight/ report (gitignored scratch)
woostack-dream consolidates recurring trends across memory + overnight + fixes/specs/plans
        └──► wisdom/<slug>.md   (durable, generalized)   + gated prune of fully-absorbed scratch
review / build / plan ──► wholesale-load wisdom/ as guidance
```

`woostack-dream` no longer **creates** memory notes (its old `surface` op is now `consolidate`,
retargeted to `wisdom/`); memory notes are created only by `woostack-execute` distillation.

---

## 8. Degradation

- No `.woostack/wisdom/` directory → consumers load nothing (no-op); `woostack-dream` creates it on
  first approved `consolidate` (or `/woostack-init` scaffolds it).
- No `.woostack/overnight/` directory → the overnight scan is a no-op; the rest of the dream pass
  proceeds.
- Missing scripts (individual manual install) → announce the manual fallback, never fail silently
  (mirrors `memory.md` §10).
```

- [x] **Step 3: Verify the contract exists with the required sections (green)**

Run:
```bash
test -f skills/woostack-init/references/wisdom.md \
  && grep -q 'type: wisdom' skills/woostack-init/references/wisdom.md \
  && grep -q 'two-tier' skills/woostack-init/references/wisdom.md \
  && grep -q 'prune' skills/woostack-init/references/wisdom.md \
  && grep -q 'wholesale' skills/woostack-init/references/wisdom.md \
  && echo OK
```
Expected: `OK`

- [x] **Step 4: Commit**

```bash
gt create -m "feat(wisdom): add wisdom-store contract reference"
```

### Task 2: Note the wisdom tier in `memory.md` (§2 layout + §3 reserved type)

**Files:**
- Modify: `skills/woostack-init/references/memory.md` (§2 Layout block; §3 `type` enum)

- [x] **Step 1: Confirm memory.md does not yet mention wisdom (red)**

Run: `grep -c 'wisdom' skills/woostack-init/references/memory.md || true`
Expected: `0`

- [x] **Step 2: Add a sibling-store line to the §2 layout tree**

In `skills/woostack-init/references/memory.md`, inside the §2 Layout fenced tree, add a `wisdom/`
sibling line after the `plans/` line. The tree currently contains lines like:

```
├── specs/           woostack-build markdown specs (type: spec)
├── plans/           woostack-build markdown plans
```

Insert after the `plans/` line:

```
├── wisdom/          generalized findings, wholesale-loaded — see wisdom.md (sibling store)
```

- [x] **Step 3: Add the reserved `type: wisdom` entry to the §3 `type` enum**

In §3, the `type` enum paragraph currently reads:

```
`spec` and `plan` are reserved for specs and plans authored under `.woostack/specs/` and `.woostack/plans/` respectively. They are **excluded from recall routing** — the recall procedure never loads note bodies whose type is `spec` or `plan`.
```

Append after it (new paragraph):

```
`wisdom` is likewise **reserved and recall-excluded**: wisdom files live in the sibling
`.woostack/wisdom/` store (not `.woostack/memory/`), so they are never indexed or scope-recalled.
The wisdom store has its own contract — see [`wisdom.md`](wisdom.md).
```

- [x] **Step 4: Verify both edits landed and the cross-link resolves (green)**

Run:
```bash
grep -q 'wisdom/' skills/woostack-init/references/memory.md \
  && grep -q '`wisdom` is likewise' skills/woostack-init/references/memory.md \
  && test -f skills/woostack-init/references/wisdom.md \
  && echo OK
```
Expected: `OK`

- [x] **Step 5: Commit**

```bash
gt modify -c -m "docs(memory): note wisdom sibling store + reserved type"
```

### Task 3: Scaffold `wisdom/` in `woostack-init` (table row + `.gitkeep` template)

**Files:**
- Create: `skills/woostack-init/templates/wisdom/.gitkeep`
- Modify: `skills/woostack-init/SKILL.md` (step 2 scaffold table; Reference section)

- [x] **Step 1: Confirm the template is absent (red)**

Run: `test ! -e skills/woostack-init/templates/wisdom/.gitkeep && echo MISSING`
Expected: `MISSING`

- [x] **Step 2: Create the `.gitkeep` template**

```bash
mkdir -p skills/woostack-init/templates/wisdom
: > skills/woostack-init/templates/wisdom/.gitkeep
```

- [x] **Step 3: Add `wisdom/` rows to the init scaffold table**

In `skills/woostack-init/SKILL.md`, step 2's scaffold table currently has these rows:

```
   | `.woostack/fixes/` directory | (create empty) |
   | `.woostack/fixes/.gitkeep` | `templates/fixes/.gitkeep` |
```

Insert after the `fixes/.gitkeep` row:

```
   | `.woostack/wisdom/` directory | (create empty) |
   | `.woostack/wisdom/.gitkeep` | `templates/wisdom/.gitkeep` |
```

- [x] **Step 4: Cross-link the wisdom contract from the Reference section**

In `skills/woostack-init/SKILL.md`, the final `## Reference` section currently points only to
`references/memory.md`. Append a sentence:

```
The sibling `.woostack/wisdom/` store (generalized findings, wholesale-loaded) has its own
contract in [references/wisdom.md](references/wisdom.md).
```

- [x] **Step 5: Verify the scaffold row + template + cross-link (green)**

Run:
```bash
test -f skills/woostack-init/templates/wisdom/.gitkeep \
  && grep -q '.woostack/wisdom/.gitkeep' skills/woostack-init/SKILL.md \
  && grep -q 'references/wisdom.md' skills/woostack-init/SKILL.md \
  && echo OK
```
Expected: `OK`

- [x] **Step 6: Commit**

```bash
gt modify -c -m "feat(init): scaffold .woostack/wisdom/ (tracked store)"
```

### Task 4: Gitignore regression test — wisdom tracked, overnight ignored

**Files:**
- Modify: `skills/woostack-init/scripts/tests/test-gitignore-template.sh`

- [x] **Step 1: Add the wisdom/overnight assertions (write the failing check)**

In `skills/woostack-init/scripts/tests/test-gitignore-template.sh`, before the `finish` line, add:

```bash
# Wisdom is a TRACKED store — the template must NOT ignore it (contrast overnight/).
assert_exit 1 "$(grep -qx 'wisdom/' "$template"; echo $?)" "template does not ignore the wisdom store"
assert_not_contains "$body" "$(printf 'wisdom/')" "gitignore template keeps wisdom/ tracked"
# Regression guard: overnight/ stays ignored even as wisdom/ is added as a sibling.
assert_contains "$body" "overnight/" "gitignore template still ignores overnight reports"
```

- [x] **Step 2: Run the test, confirm it passes against the unchanged template (green)**

The `templates/gitignore` already omits any `wisdom/` line and contains `overnight/`, so the new
assertions pass without touching the template — that is the intended invariant (wisdom tracked by
default).

Run: `bash skills/woostack-init/scripts/tests/test-gitignore-template.sh`
Expected: PASS — all assertions pass, ending with the `finish` summary (exit 0).

- [x] **Step 3: Prove the guard bites (confirm the assertion is real)**

Run (temporary, do not commit the edit):
```bash
cp skills/woostack-init/templates/gitignore /tmp/gi.bak
printf 'wisdom/\n' >> skills/woostack-init/templates/gitignore
bash skills/woostack-init/scripts/tests/test-gitignore-template.sh; echo "exit=$?"
cp /tmp/gi.bak skills/woostack-init/templates/gitignore
```
Expected: a FAIL line for "template does not ignore the wisdom store" and `exit=1`, then the
template is restored.

- [x] **Step 4: Commit**

```bash
gt modify -c -m "test(init): assert wisdom tracked + overnight ignored in gitignore template"
```

### Task 5: build-index regression test — a sibling `wisdom/` never leaks into `MEMORY.md` (AC3 edge)

**Files:**
- Modify: `skills/woostack-init/scripts/tests/test-build-index.sh`

- [x] **Step 1: Add the no-leak case (write the failing-by-construction check)**

In `skills/woostack-init/scripts/tests/test-build-index.sh`, before the `finish` line, add:

```bash
# AC3 (dream-wisdom): a sibling .woostack/wisdom/ store is structurally invisible to
# build-index (it globs only its own memdir), so a type: wisdom file must never leak
# into MEMORY.md.
wd="$(mk_memdir)"
mk_note "$wd" real.md $'name: real\ntype: decision' 'real memory note'
mkdir -p "$wd/../wisdom"
printf -- '---\nname: wis-leak\ntype: wisdom\n---\nGeneralized finding.\n' > "$wd/../wisdom/wis-leak.md"
bash "$BI" "$wd"
assert_contains "$(cat "$wd/MEMORY.md")" "real" "memory note is indexed"
assert_not_contains "$(cat "$wd/MEMORY.md")" "wis-leak" "sibling wisdom/ never leaks into MEMORY.md"
rm -rf "$wd" "$wd/../wisdom"
```

- [x] **Step 2: Run the test, confirm it passes (green)**

build-index globs only `$MEM_DIR/*.md`, so `wis-leak` cannot appear in the index — the assertion
passes by construction (that IS the structural guarantee AC3 asserts).

Run: `bash skills/woostack-init/scripts/tests/test-build-index.sh`
Expected: PASS — ends with the `finish` summary, exit 0.

- [x] **Step 3: Commit**

```bash
gt modify -c -m "test(init): assert sibling wisdom store never leaks into MEMORY.md"
```

---

## Increment 2: Reshape `woostack-dream`

> One independently shippable PR — rewrites the `woostack-dream` procedure to scan overnight, consolidate into `wisdom/`, prune fully-absorbed scratch under the existing gate, and correct the recoverability claim. Depends on Increment 1 (`wisdom.md` exists, `wisdom/` scaffolded). Stacks on Increment 1.

### Task 1: Add `overnight/` to the Phase 1 scan + correct the recoverability claim

**Files:**
- Modify: `skills/woostack-dream/SKILL.md` (Phase 1 Gather; Phase 3 drop-visibility rationale)

- [x] **Step 1: Confirm dream does not scan overnight today (red)**

Run: `grep -c 'overnight' skills/woostack-dream/SKILL.md || true`
Expected: `0`

- [x] **Step 2: Broaden the Phase 1 corpus read to include `overnight/`**

In `skills/woostack-dream/SKILL.md`, Phase 1 currently enumerates the design-trend corpus as
`.woostack/{specs,plans,fixes}/*.md`. Change that enumeration to
`.woostack/{specs,plans,fixes,overnight}/*.md` and add this sentence to the same paragraph:

```
`.woostack/overnight/*.md` (gitignored morning reports from woostack-execute-overnight) are also
read as scratch trend-input. Because overnight reports are gitignored, the git-log watermark cannot
track them — they are full-scanned every run; the prune step (Phase 2/4) bounds the set by deleting
fully-absorbed reports so the scan does not grow unbounded.
```

- [x] **Step 3: Correct the "gitignored memory is unrecoverable" claim**

Search the file for the recoverability claim and rewrite it to name overnight as the unrecoverable
surface. The two occurrences (Phase 2 `drop` op and Phase 3 full-body rule) currently assert memory
is gitignored/unrecoverable. Replace each "gitignored memory is unrecoverable" phrasing with:

```
memory notes are git-tracked (recoverable), but `.woostack/overnight/` reports are gitignored and
**unrecoverable once deleted** — so the gate shows their full body before any prune
```

- [x] **Step 4: Verify the scan + correction (green)**

Run:
```bash
grep -q 'overnight' skills/woostack-dream/SKILL.md \
  && ! grep -qi 'gitignored memory is unrecoverable' skills/woostack-dream/SKILL.md \
  && grep -qi 'overnight.*unrecoverable' skills/woostack-dream/SKILL.md \
  && echo OK
```
Expected: `OK`

- [x] **Step 5: Commit**

```bash
gt create -m "feat(dream): scan overnight reports; fix recoverability claim"
```

### Task 2: Retarget `surface`→`consolidate` (memory → wisdom)

**Files:**
- Modify: `skills/woostack-dream/SKILL.md` (Phase 2 operations list; Phase 4 apply)

- [x] **Step 1: Confirm the surface op still targets memory (red)**

Run: `grep -n 'surface' skills/woostack-dream/SKILL.md`
Expected: matches showing the `surface` op consolidating into the memory store (≥1 line).

- [x] **Step 2: Rewrite the `surface` bullet as `consolidate`**

In Phase 2, replace the entire `- **surface**: …` bullet with:

```
- **consolidate**: Roll a recurring pattern (a trend across the memory + overnight +
  specs/plans/fixes corpora) into a single tracked **wisdom file** at `.woostack/wisdom/<slug>.md`,
  per the wisdom contract [`../woostack-init/references/wisdom.md`](../woostack-init/references/wisdom.md).
  This is the former `surface` op, retargeted from `memory/` to `wisdom/` and broadened to include
  overnight + fixes. The wisdom file's `source:` records **all** contributing inputs (note names +
  artifact paths) as permanent provenance. New wisdom must clear the wisdom contract's bar
  (generalized, cross-cutting, high-value); dedupe store-wide against existing wisdom — a
  corroborated trend strengthens or rescopes the existing wisdom file rather than adding a duplicate.
  `woostack-dream` therefore no longer creates memory notes (those are written by woostack-execute
  distillation); it consolidates, hygienes, and prunes them.
```

- [x] **Step 3: Verify the retarget (green)**

Run:
```bash
grep -q '\*\*consolidate\*\*' skills/woostack-dream/SKILL.md \
  && grep -q '.woostack/wisdom/<slug>.md' skills/woostack-dream/SKILL.md \
  && grep -q 'references/wisdom.md' skills/woostack-dream/SKILL.md \
  && echo OK
```
Expected: `OK`

- [x] **Step 4: Commit**

```bash
gt modify -c -m "feat(dream): retarget surface→consolidate into wisdom store"
```

### Task 3: Add the gated `prune` operation + Phase 3/4 wiring

**Files:**
- Modify: `skills/woostack-dream/SKILL.md` (Phase 2 ops; Phase 3 gate; Phase 4 apply)

- [x] **Step 1: Confirm there is no prune op today (red)**

Run: `grep -c 'prune' skills/woostack-dream/SKILL.md || true`
Expected: `0`

- [x] **Step 2: Add the `prune` bullet to Phase 2 (after `consolidate`)**

```
- **prune**: Delete the **fully-absorbed** scratch inputs of a wisdom file — only memory notes and
  overnight reports, never `fixes/specs/plans`. Compute a **prune list** = the subset of a wisdom
  file's `source:` ledger whose value is *fully* captured by the finding (per-input agent judgment).
  Inputs retaining independent value (e.g. a scope-specific memory note) are **partial** → kept or
  rescoped, never pruned. **Any doubt → keep.** See the wisdom contract §5
  [`../woostack-init/references/wisdom.md`](../woostack-init/references/wisdom.md).
```

- [x] **Step 3: Extend the Phase 3 review gate for the prune list**

In Phase 3, add a bullet to the gate's presentation rules:

```
- Show the **prune list**: each fully-absorbed input, its absorbing wisdom file, and a one-line
  "why absorbed". Show the **full body** of every `.woostack/overnight/` report on the prune list
  (gitignored → unrecoverable). `fixes/specs/plans` never appear on a prune list.
```

- [x] **Step 4: Extend the Phase 4 apply step for prune execution**

In Phase 4, add to the **Memory** apply step (after the rewrite/delete + build-index sentence):

```
Execute the approved **prune list**: delete each fully-absorbed memory note (`.woostack/memory/<name>.md`)
and overnight report (`.woostack/overnight/<file>.md`). Pruning memory notes is a memory mutation →
re-run `build-index.sh` then `doctor.sh`; deleting overnight reports touches no index.
```

- [x] **Step 5: Verify prune is wired across phases (green)**

Run:
```bash
grep -q '\*\*prune\*\*' skills/woostack-dream/SKILL.md \
  && grep -q 'prune list' skills/woostack-dream/SKILL.md \
  && grep -q 'full body' skills/woostack-dream/SKILL.md \
  && echo OK
```
Expected: `OK`

- [x] **Step 6: Commit**

```bash
gt modify -c -m "feat(dream): add gated default-keep prune of absorbed scratch"
```

### Task 4: Update `woostack-dream` description, degradation, and hard constraints

**Files:**
- Modify: `skills/woostack-dream/SKILL.md` (frontmatter `description`; Degradation; Hard constraints)

- [x] **Step 1: Update the frontmatter `description`**

The `description:` currently says dream surfaces insights into memory. Update it to mention the
wisdom store, overnight scan, and gated prune — keep it one concise sentence (discovery-driving).
Replace the surface/consolidate clause so it reads (approximately):

```
…then proposes a gated changeset that merges/replaces/drops/resolves memory notes, consolidates
recurring trends from memory + overnight + the specs/plans/fixes corpus into the .woostack/wisdom/
store, and prunes the fully-absorbed scratch (memory notes + overnight reports) it merged…
```

- [x] **Step 2: Add degradation rules for wisdom + overnight**

In `## Degradation`, add:

```
- If `.woostack/wisdom/` is absent, create it on the first approved `consolidate` (or defer to
  `/woostack-init`); never error solely because it is missing.
- If `.woostack/overnight/` is absent or empty, the overnight scan is a no-op; the rest of the pass
  proceeds.
```

- [x] **Step 3: Update the legacy "no new scripts / don't modify the memory contract" constraint**

The `## Hard constraints` section has a `**Reuse existing scripts**` bullet forbidding new scripts
and contract edits. Reword it so it bounds dream's **runtime** behavior (a dream *run* adds no
scripts and mutates no contract), not feature work, and add `wisdom/` as a write target:

```
- **Reuse existing scripts at runtime**: a `woostack-dream` *run* reuses the scripts under
  `skills/woostack-init/scripts/`, adds no new scripts, and does not edit the memory/wisdom contracts.
  (Evolving those contracts or tooling is feature work, not a dream run.)
- **Two stores, one writer**: dream is the only writer of `.woostack/wisdom/`. It consolidates into
  wisdom and prunes absorbed scratch, but never deletes `fixes/specs/plans`.
```

- [x] **Step 4: Verify description + degradation + constraints (green)**

Run:
```bash
grep -q 'wisdom' skills/woostack-dream/SKILL.md \
  && grep -q 'overnight scan is a no-op' skills/woostack-dream/SKILL.md \
  && grep -q 'only writer of' skills/woostack-dream/SKILL.md \
  && echo OK
```
Expected: `OK`

- [x] **Step 5: Commit**

```bash
gt modify -c -m "docs(dream): update description, degradation, constraints for wisdom"
```

---

## Increment 3: Wire build / ideate / plan consumers

> One independently shippable PR — small doc edits so the design and planning phases load `wisdom/*.md` wholesale. Depends on Increment 1 (`wisdom.md` contract). Stacks on Increment 2.

### Task 1: Load wisdom in the design phase (`woostack-ideate` + `woostack-build` note)

**Files:**
- Modify: `skills/woostack-ideate/SKILL.md` (Process step 1 "Explore project context")
- Modify: `skills/woostack-build/SKILL.md` (step 1 Ideate)

- [ ] **Step 1: Confirm neither loads wisdom today (red)**

Run: `grep -c 'wisdom' skills/woostack-ideate/SKILL.md skills/woostack-build/SKILL.md || true`
Expected: `0` for both files.

- [ ] **Step 2: Add a wisdom-load instruction to ideate's context exploration**

In `skills/woostack-ideate/SKILL.md`, Process step 1 ("Explore project context"), append:

```
   Also read every `.woostack/wisdom/*.md` file (wholesale — they are generalized, cross-cutting
   guidance, not scope-routed) and treat them as house-rules the design should respect. See the
   wisdom contract [`../woostack-init/references/wisdom.md`](../woostack-init/references/wisdom.md).
   An empty or absent `wisdom/` is a no-op.
```

- [ ] **Step 3: Note the wisdom load in `woostack-build` step 1**

In `skills/woostack-build/SKILL.md`, step 1 (Ideate), append a sentence:

```
The design phase loads `.woostack/wisdom/*.md` wholesale as guidance (via `woostack-ideate`'s
context exploration); see the wisdom contract
[`../woostack-init/references/wisdom.md`](../woostack-init/references/wisdom.md).
```

- [ ] **Step 4: Verify (green)**

Run:
```bash
grep -q 'wisdom' skills/woostack-ideate/SKILL.md \
  && grep -q 'wisdom' skills/woostack-build/SKILL.md \
  && echo OK
```
Expected: `OK`

- [ ] **Step 5: Commit**

```bash
gt create -m "feat(build): load wisdom wholesale in the design phase"
```

### Task 2: Load wisdom in `woostack-plan`

**Files:**
- Modify: `skills/woostack-plan/SKILL.md` ("Read and check the spec" section)

- [ ] **Step 1: Confirm plan does not load wisdom today (red)**

Run: `grep -c 'wisdom' skills/woostack-plan/SKILL.md || true`
Expected: `0`

- [ ] **Step 2: Add a wisdom-load step**

In `skills/woostack-plan/SKILL.md`, in the "Read and check the spec" section, add as a new first
sub-step:

```
0. **Load wisdom.** Read every `.woostack/wisdom/*.md` file (wholesale) before planning, and respect
   those generalized findings when shaping increments and tasks. See the wisdom contract
   [`../woostack-init/references/wisdom.md`](../woostack-init/references/wisdom.md). Empty/absent
   `wisdom/` is a no-op.
```

- [ ] **Step 3: Verify (green)**

Run: `grep -q 'Load wisdom' skills/woostack-plan/SKILL.md && grep -q 'references/wisdom.md' skills/woostack-plan/SKILL.md && echo OK`
Expected: `OK`

- [ ] **Step 4: Commit**

```bash
gt modify -c -m "feat(plan): load wisdom wholesale before planning"
```

---

## Increment 4: Wire the `woostack-review` consumer

> One independently shippable PR — a `compose-wisdom.sh` helper (mirroring `recall.sh`), a `$OUTDIR/wisdom.md` prefetch artifact, and the `_header.md` contract bullet so reviewers consult wisdom. Depends on Increment 1. Stacks on Increment 3.

### Task 1: `compose-wisdom.sh` helper

**Files:**
- Create: `skills/woostack-review/scripts/compose-wisdom.sh`
- Create: `skills/woostack-review/scripts/tests/test-compose-wisdom.sh`

- [ ] **Step 1: Write the failing test**

Create `skills/woostack-review/scripts/tests/test-compose-wisdom.sh`:

```bash
#!/usr/bin/env bash
# Self-contained (no external assert harness): verifies compose-wisdom.sh cats
# all wisdom bodies wholesale and is a no-op when the store is absent/empty.
set -uo pipefail
SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/compose-wisdom.sh"
fail=0
check() { if [ "$2" = "$3" ]; then echo "ok - $1"; else echo "FAIL - $1 (got '$2', want '$3')"; fail=1; fi; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Case 1: absent store → empty output, exit 0.
out="$(bash "$SCRIPT" "$tmp" 2>/dev/null)"; rc=$?
check "absent store is empty" "$out" ""
check "absent store exits 0" "$rc" "0"

# Case 2: two wisdom files → both bodies present, with SOURCE headers.
mkdir -p "$tmp/.woostack/wisdom"
printf -- '---\nname: a\ntype: wisdom\n---\nAlpha finding.\n' > "$tmp/.woostack/wisdom/a.md"
printf -- '---\nname: b\ntype: wisdom\n---\nBeta finding.\n'  > "$tmp/.woostack/wisdom/b.md"
out="$(bash "$SCRIPT" "$tmp")"
case "$out" in *"Alpha finding."*) echo "ok - emits a.md body";; *) echo "FAIL - missing a.md body"; fail=1;; esac
case "$out" in *"Beta finding."*)  echo "ok - emits b.md body";; *) echo "FAIL - missing b.md body"; fail=1;; esac
case "$out" in *"SOURCE: a.md"*)   echo "ok - labels source a.md";; *) echo "FAIL - missing SOURCE a.md"; fail=1;; esac

# Case 3: empty store dir (only .gitkeep) → empty output.
rm -f "$tmp/.woostack/wisdom/"*.md; : > "$tmp/.woostack/wisdom/.gitkeep"
out="$(bash "$SCRIPT" "$tmp")"
check "empty store (.gitkeep only) is empty" "$out" ""

[ "$fail" = 0 ] && echo "PASS" || { echo "FAILED"; exit 1; }
```

- [ ] **Step 2: Run it, confirm it fails (helper missing)**

Run: `bash skills/woostack-review/scripts/tests/test-compose-wisdom.sh; echo "exit=$?"`
Expected: FAIL — errors that `compose-wisdom.sh` cannot be found / non-empty output assertions fail; `exit=1`.

- [ ] **Step 3: Write `compose-wisdom.sh`**

Create `skills/woostack-review/scripts/compose-wisdom.sh`:

```bash
#!/usr/bin/env bash
# Compose the wholesale wisdom guidance for a review.
# Usage: compose-wisdom.sh <woostack_root>
# Cats every .woostack/wisdom/*.md body to stdout, each prefixed with a
# `## SOURCE: <basename>` header (mirrors prefetch.sh's rules.md format). A no-op
# (empty output, exit 0) when the store is absent or holds no .md files. Wisdom is
# loaded WHOLESALE — there is no scope routing (that is memory's job; see recall.sh).
set -uo pipefail
ROOT="${1:-.}"
WDIR="$ROOT/.woostack/wisdom"
[ -d "$WDIR" ] || exit 0
shopt -s nullglob
files=("$WDIR"/*.md)
for f in "${files[@]}"; do
  printf '## SOURCE: %s\n' "$(basename "$f")"
  cat "$f"
  printf '\n\n'
done
exit 0
```

- [ ] **Step 4: Run the test, confirm it passes (green)**

Run: `bash skills/woostack-review/scripts/tests/test-compose-wisdom.sh`
Expected: PASS (every `ok -` line, final `PASS`, exit 0).

- [ ] **Step 5: Remove the deferral marker (the forward reference now resolves)**

`compose-wisdom.sh` now exists, so the Increment-1 `woostack-defer(increment 4)` marker in
`wisdom.md` §6 has done its job. Delete that single comment line:

```bash
sed -i.bak '/woostack-defer(increment 4)/d' skills/woostack-init/references/wisdom.md
rm -f skills/woostack-init/references/wisdom.md.bak
grep -q 'woostack-defer' skills/woostack-init/references/wisdom.md && echo "STILL PRESENT (unexpected)" || echo "MARKER REMOVED"
```
Expected: `MARKER REMOVED`

- [ ] **Step 6: Commit**

```bash
gt create -m "feat(review): add compose-wisdom.sh wholesale wisdom loader"
```

### Task 2: Compose `$OUTDIR/wisdom.md` in `prefetch.sh`

**Files:**
- Modify: `skills/woostack-review/scripts/prefetch.sh` (after the cross-PR memory composition block)

- [ ] **Step 1: Confirm prefetch does not compose wisdom today (red)**

Run: `grep -c 'wisdom' skills/woostack-review/scripts/prefetch.sh || true`
Expected: `0`

- [ ] **Step 2: Add the wisdom composition after the memory block**

In `skills/woostack-review/scripts/prefetch.sh`, immediately after the cross-PR memory `if [ -d "$WOOSTACK_DIR/memory" ]; then … fi` block (the block that writes `$OUTDIR/memory.md` via `recall.sh`), insert:

```bash
# Wholesale wisdom guidance — every .woostack/wisdom/*.md body (generalized,
# cross-cutting house-rules), composed via compose-wisdom.sh (the wisdom analogue
# of recall.sh/memory.md). Always-load, no scope routing. No-op when the store is
# absent/empty, so $OUTDIR/wisdom.md is present only when there is wisdom to read.
WISDOM_OUT="$OUTDIR/wisdom.md"
COMPOSE_WISDOM="$SCRIPT_DIR/compose-wisdom.sh"
if [ -f "$COMPOSE_WISDOM" ]; then
  if bash "$COMPOSE_WISDOM" "$WOOSTACK_ROOT" > "$WISDOM_OUT" 2>/dev/null; then
    [ -s "$WISDOM_OUT" ] || rm -f "$WISDOM_OUT"
    [ -f "$WISDOM_OUT" ] && echo "Composed wisdom guidance ($(wc -c < "$WISDOM_OUT")B)"
  else
    rm -f "$WISDOM_OUT"
  fi
fi
```

- [ ] **Step 3: Syntax-check prefetch.sh + confirm the artifact is produced (green)**

Run:
```bash
bash -n skills/woostack-review/scripts/prefetch.sh && echo SYNTAX_OK
# Behavioral check of the inserted block, isolated from the full prefetch:
tmp="$(mktemp -d)"; mkdir -p "$tmp/.woostack/wisdom" "$tmp/out"
printf -- '---\nname: x\ntype: wisdom\n---\nReview house-rule.\n' > "$tmp/.woostack/wisdom/x.md"
OUTDIR="$tmp/out" WOOSTACK_ROOT="$tmp" SCRIPT_DIR="$(pwd)/skills/woostack-review/scripts" bash -c '
  WISDOM_OUT="$OUTDIR/wisdom.md"; COMPOSE_WISDOM="$SCRIPT_DIR/compose-wisdom.sh"
  bash "$COMPOSE_WISDOM" "$WOOSTACK_ROOT" > "$WISDOM_OUT"; [ -s "$WISDOM_OUT" ] || rm -f "$WISDOM_OUT"'
grep -q 'Review house-rule.' "$tmp/out/wisdom.md" && echo ARTIFACT_OK
rm -rf "$tmp"
```
Expected: `SYNTAX_OK` then `ARTIFACT_OK`.

- [ ] **Step 4: Commit**

```bash
gt modify -c -m "feat(review): compose \$OUTDIR/wisdom.md guidance in prefetch"
```

### Task 3: Document the wisdom artifact in the review contract (`_header.md`)

**Files:**
- Modify: `skills/woostack-review/prompts/_header.md` (Prefetched Artifacts list; a Wisdom guidance paragraph)

- [ ] **Step 1: Confirm the contract does not mention wisdom today (red)**

Run: `grep -c 'wisdom' skills/woostack-review/prompts/_header.md || true`
Expected: `0`

- [ ] **Step 2: Add a Prefetched-Artifacts bullet (after the Cross-PR memory bullet)**

In `skills/woostack-review/prompts/_header.md`, in the "Prefetched Artifacts (do NOT re-fetch)"
list, after the `**Cross-PR memory**` bullet, add:

```
- **Wisdom guidance** (optional, present when the consumer repo has a non-empty `.woostack/wisdom/`): `/tmp/pr-review/wisdom.md` — every wisdom file body, loaded **wholesale** (generalized, cross-cutting house-rules the team distilled via `woostack-dream`). Each section is prefixed `## SOURCE: <file>.md`. Treat it as an additional rubric: do NOT re-flag an issue wisdom already records as a known/accepted convention. Advisory context, not a `rule_quote` source.
```

- [ ] **Step 3: Add a short "Wisdom guidance" usage paragraph (after the Cross-PR memory paragraph)**

After the existing `If /tmp/pr-review/memory.md exists, read it before reporting. …` paragraph, add:

```
If `/tmp/pr-review/wisdom.md` exists, read it before reporting. It is the team's generalized,
cross-cutting wisdom (loaded wholesale, not scope-routed). If a finding you would report is already
described there as a known/accepted convention, DROP it. Like memory, wisdom is advisory context —
do not cite it in `rule_quote`.
```

- [ ] **Step 4: Verify (green)**

Run:
```bash
grep -q 'Wisdom guidance' skills/woostack-review/prompts/_header.md \
  && grep -q '/tmp/pr-review/wisdom.md' skills/woostack-review/prompts/_header.md \
  && echo OK
```
Expected: `OK`

- [ ] **Step 5: Commit**

```bash
gt modify -c -m "docs(review): document wisdom.md guidance artifact in shared contract"
```

---

## Self-review (run before handing back)

- [ ] **Spec coverage** — every spec requirement maps to a task:
  - AC1 (scaffold `wisdom/`) → Inc 1 Task 3.
  - AC2 (wisdom tracked, overnight ignored) → Inc 1 Task 4.
  - AC3 (structural recall exclusion) → Inc 1 Task 1 §4 + Task 2 §3 (doc) + **Task 5 build-index regression test** (concrete no-leak proof; no recall.sh change, per §9 Q1).
  - AC4 (wisdom contract + memory.md note) → Inc 1 Tasks 1–2.
  - AC5 (dream procedure reshape + correction) → Inc 2 Tasks 1–4.
  - AC6 (consumers load wisdom wholesale) → Inc 3 Tasks 1–2 (build/ideate/plan) + Inc 4 Tasks 1–3 (review).
  - AC7 (gated default-keep prune; overnight full-body) → Inc 2 Task 3.
- [ ] **AC coverage** — each happy/error/edge case maps to a verification step (greps, the gitignore guard's bite-test, the compose-wisdom absent/empty/populated cases, the prefetch artifact check).
- [ ] **No placeholders** — every step has the actual file path, exact content/edit, exact command, and expected output; no TBD/TODO.
- [ ] **Type consistency** — names match across tasks: `compose-wisdom.sh`, `$OUTDIR/wisdom.md`, `type: wisdom`, `.woostack/wisdom/<slug>.md`, `source:` ledger / prune list — used identically in the spec, `wisdom.md`, dream, and review wiring.

> woostack plan conventions (kept): frontmatter-free; opens with the `**Source:**` line; basename mirrors the spec (`2026-06-13-dream-wisdom`); no required-sub-skill banner; in this runner-less skill repo, each "failing test" is a concrete grep / `bash -n` / self-contained bash test with exact expected output.
