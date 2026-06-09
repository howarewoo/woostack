**Source:** .woostack/specs/2026-06-09-woostack-dream.md

# woostack-dream Skill Implementation Plan

**Goal:** Create the `woostack-dream` skill — an agent-agnostic memory & docs curation pass over the `.woostack/` store — and wire it in as the sixteenth public command.

**Architecture:** Two stacked Graphite increments. (1) Author `skills/woostack-dream/SKILL.md`: the self-contained five-phase skill (gather → synthesize → hard gate → apply → summarize/iterate) reusing the existing `woostack-init/scripts/` primitives; independently shippable and correct on its own. (2) Surface wiring: register the command in `using-woostack`, `AGENTS.md` (= `.claude/CLAUDE.md` symlink), and `README.md`, updating every fifteen→sixteen count for consistency. No new scripts, no memory-contract change.

**Tech Stack:** Markdown, Bash (grep/test verification), Git, Graphite.

> No test runner ships in this repo (skill markdown only). Per the [woostack-tdd](../../skills/woostack-tdd/SKILL.md) no-runner carve-out, each "failing test" step is a concrete `grep`/`test` verification with exact expected output: assert-it-fails (red) before authoring, assert-it-passes (green) after.

---

## Increment 1: Author the woostack-dream skill

> One independently shippable PR — its own Graphite branch. The skill is complete and correct before any wiring; wiring is Increment 2.

### Task 1: Create `skills/woostack-dream/SKILL.md`

**Files:**
- Create: `skills/woostack-dream/SKILL.md`

- [x] **Step 1: Red — assert the skill file is absent**

Run: `test -f skills/woostack-dream/SKILL.md && echo EXISTS || echo MISSING`
Expected: `MISSING`

- [x] **Step 2: Write `skills/woostack-dream/SKILL.md`**

Author the file with this exact frontmatter:

```markdown
---
name: woostack-dream
description: Use to curate the .woostack/ knowledge store — an agent-agnostic version of managed "dreams". Reflects over the static memory store + docs (no session mining), then proposes a gated changeset that merges duplicate notes, replaces stale/contradicted ones, drops dead/orphaned notes, resolves conflicts, surfaces consolidated insights, and recommends evidence-guarded documentation edits. Nothing mutates before explicit approval; ends on a summary + iterate loop. Local-only memory (no commit); doc edits land in the working tree. Never commits or merges. Invoke via /woostack-dream [instructions].
---
```

Then the body — write each section with complete prose (no placeholders):

1. **Title + framing** — `# woostack-dream`, then: agent-agnostic, lo-fi analog of Anthropic's managed Dreams; reflects over the *static* store + docs (deterministic, repeatable), never session transcripts or the live conversation. Standalone maintenance command, **not** a `woostack-build` phase. It is the agentic synthesis + apply layer on top of `doctor.sh`'s mechanical lint.

2. **`## Command`** — `/woostack-dream [instructions]`. The optional free-text `instructions` argument steers synthesis focus (e.g. `"focus on API conventions; ignore one-off gotchas"`), applied throughout — mirroring Dreams' `instructions`. No argument = curate the whole store.

3. **`## Procedure`** — five `### Phase N — <name>` subsections:
   - **Phase 1 — Gather (read-only).** If `.woostack/memory/` exists, run [`doctor.sh`](../woostack-init/scripts/doctor.sh) and capture its warnings (overlap clusters, stale provenance, orphaned scope, dead notes, missing provenance, non-glob trivia), then read `memory/MEMORY.md` + every note body. Always read the flat `.woostack/memory.md`. Enumerate the doc surface with `git ls-files '*.md'` (tracked-only — gitignored memory and `node_modules` excluded); exclude `.woostack/specs|plans|fixes/*.md` from the promotion-**target** set (provenance inputs, not promotion targets). Read recent `git log` and the spec/plan/fix a note's `source:` points at to ground stale-vs-current judgments. Honor the optional `instructions` steer. Cross-link the memory contract [`../woostack-init/references/memory.md`](../woostack-init/references/memory.md).
   - **Phase 2 — Synthesize the "dream" (read-only).** Produce a changeset of discrete, labeled ops — enumerate **merge** (collapse duplicate/fuzzy-near-dupe notes; survivor keeps union of scopes + most specific provenance; rewrite inbound `[[wikilinks]]` via [`graph.sh`](../woostack-init/scripts/graph.sh) `--backlinks` to the survivor), **replace** (rewrite contradicted/stale note to latest value; preserve `source:`), **drop** (dead + orphaned-scope notes; rewrite/remove inbound links; **gitignored ⇒ unrecoverable**), **resolve** (adjudicate each `doctor.sh` overlap cluster; when you cannot confidently decide, **flag for the user — never guess**), **surface** (consolidate a recurring pattern into one new note; `source:` derived from contributing notes, never fabricated; must pass the memory-contract §7 distillation reject-by-default gate), and **doc recommendation** (promote a convention or fix a contradicted claim; **evidence guard:** cite the backing memory note — no note → no doc edit). State that the pass is **idempotent**.
   - **Phase 3 — Review gate (HARD).** Present the complete changeset in conversation as before/after; each **drop shows the full note body** (unrecoverable once applied); each un-adjudicable conflict is **flagged for the user**; each doc edit shows a diff with its backing note cited. **Nothing has mutated.** Require explicit approval — silence/ambiguity is not approval (honor the project's approval-gate discipline). For a large changeset offer a [`woostack-visualize`](../woostack-visualize/SKILL.md) render (audience `engineer`) as a reading aid; the changeset still lives in conversation, not a separate artifact.
   - **Phase 4 — Apply (on approval).** Memory: rewrite/delete the affected note files in place → run [`build-index.sh`](../woostack-init/scripts/build-index.sh) to regenerate `MEMORY.md` → re-run `doctor.sh` and confirm clean (report residual warnings, especially unresolved `[[wikilinks]]`). Docs: write the approved edits to the working tree (uncommitted).
   - **Phase 5 — Summarize & iterate.** Report what changed (notes merged/replaced/dropped/added, conflicts resolved, doc edits applied). Invite change requests; on a request, return to Phase 3/4 and re-summarize. When done: memory changes are already local-only (no commit); for the working-tree doc edits, offer to hand off to [`woostack-commit`](../woostack-commit/SKILL.md). Never commit or merge here.

4. **`## Degradation`** — scoped store → use the scripts; flat `memory.md` only → state the fallback and curate the flat file with bullet-level dedupe/replace/drop (no scope/index/doctor machinery); no `.woostack/` → stop, nothing to curate, do not scaffold (defer to `/woostack-init`); scripts missing (individual install) → announce manual fallback per memory-contract §10, do recall/lint by hand, never fail silently.

5. **`## Hard constraints`** — bullets: non-destructive before the gate; explicit approval required (silence ≠ yes); memory local-only (no commit), doc edits working-tree only; never commits, pushes, or merges; doc edits evidence-guarded; dropped notes shown full-body at the gate; inbound-link integrity on merge/drop; idempotent; reuse existing scripts — add no new script, do not change the memory contract; not part of the gated build chain.

Keep cross-links relative and correct: `../woostack-init/scripts/{doctor,build-index,graph,recall,scope-match}.sh`, `../woostack-init/references/memory.md`, `../woostack-visualize/SKILL.md`, `../woostack-commit/SKILL.md`.

- [x] **Step 3: Green — assert the file exists with valid frontmatter**

Run: `test -f skills/woostack-dream/SKILL.md && head -3 skills/woostack-dream/SKILL.md | grep -c '^name: woostack-dream$'`
Expected: `1`

- [x] **Step 4: Commit**

```bash
gt create -m "feat: add woostack-dream skill"
```

### Task 2: Structural verification of the skill

**Files:**
- Verify: `skills/woostack-dream/SKILL.md`

- [x] **Step 1: Assert the five phases are present** (covers AC1)

Run: `grep -cE '^### Phase [1-5] ' skills/woostack-dream/SKILL.md`
Expected: `5`

- [x] **Step 2: Assert gate / non-destructive / no-commit / degradation / instructions language** (covers AC2, AC5, AC6, AC1-edge)

Run:
```bash
for p in 'instructions' 'approval' 'evidence guard' 'doctor.sh' 'build-index.sh' 'never commit' 'local-only' 'Degradation' 'idempotent' 'unrecoverable'; do
  grep -qi "$p" skills/woostack-dream/SKILL.md && echo "OK: $p" || echo "MISSING: $p"
done
```
Expected: every line prints `OK: …` (no `MISSING:`).

- [x] **Step 3: Assert all relative cross-links resolve** (covers AC9 link-integrity intent — no dangling links)

Run:
```bash
d=skills/woostack-dream
grep -oE '\]\(\.\./[^)]+\)' "$d/SKILL.md" | sed -E 's/^\]\(//; s/\)$//' | while read -r rel; do
  tgt="$d/${rel%%#*}"
  [ -e "$tgt" ] && echo "OK: $rel" || echo "BROKEN: $rel"
done
```
Expected: every referenced path prints `OK:` (no `BROKEN:`).

- [x] **Step 4: Commit any fixes**

```bash
# only if Steps 1-3 surfaced a fix; otherwise skip
gt modify -c -m "test: verify woostack-dream skill structure"
```

---

## Increment 2: Wire woostack-dream as the sixteenth public command

> One independently shippable PR, stacked on Increment 1. Pure documentation/routing edits; updates every fifteen→sixteen count (covers AC7).

### Task 1: Add the routing row in `using-woostack`

**Files:**
- Modify: `skills/using-woostack/SKILL.md` (Command Routing table)

- [x] **Step 1: Red — assert no dream row yet**

Run: `grep -c 'woostack-dream' skills/using-woostack/SKILL.md`
Expected: `0`

- [x] **Step 2: Add the routing row** after the `/woostack-tdd` row in the Command Routing table:

```markdown
| `/woostack-dream [instructions]`, curate the memory store and recommend doc updates (gated) | `woostack-dream` |
```

- [x] **Step 3: Green — assert the row exists**

Run: ``grep -c '| `/woostack-dream' skills/using-woostack/SKILL.md``
Expected: `1`

- [x] **Step 4: Commit**

```bash
gt create -m "docs: route woostack-dream in using-woostack"
```

### Task 2: Update `AGENTS.md` (public list, counts, Mode B, file map)

**Files:**
- Modify: `AGENTS.md` (root; `.claude/CLAUDE.md` is a symlink to it — one edit updates both)

> Line numbers below are hints from the pre-edit file; match by the quoted content (inserts shift later lines). Edit `AGENTS.md` directly — the symlink follows.

- [x] **Step 1: Add the public-command bullet** after the `woostack-tdd` bullet (currently line 32):

```markdown
- [`woostack-dream`](skills/woostack-dream/SKILL.md)
```

- [x] **Step 2: Bump the surface count** — line 16, `has fifteen skills:` → `has sixteen skills:`.

- [x] **Step 3: Bump the in-prose surface count** — line 38, `absent from the fifteen-skill command surface above` → `absent from the sixteen-skill command surface above`.

- [x] **Step 4: Bump the SKILL.md-file count** — line 82, `any of the seventeen `SKILL.md` files (the fifteen public command/adoption` → `any of the eighteen `SKILL.md` files (the sixteen public command/adoption`.

- [x] **Step 5: Add to the Mode B enumeration** — in the Mode B paragraph (lines 57-60), insert `` `/woostack-dream`, `` into the command list (after `/woostack-debug`).

- [x] **Step 6: Add a Quick file map entry** — after the visualize entry (lines 116-117):

```markdown
- Memory & docs curation engine (public command; agent-agnostic "dreams"):
  [`skills/woostack-dream/SKILL.md`](skills/woostack-dream/SKILL.md)
```

- [x] **Step 7: Green — counts consistent, no stale count remains**

Run:
```bash
echo "dream refs: $(grep -c 'woostack-dream' AGENTS.md)"
echo "stale fifteen: $(grep -ciE 'fifteen' AGENTS.md)"
echo "stale seventeen: $(grep -ciE 'seventeen' AGENTS.md)"
```
Expected: `dream refs:` ≥ `3`; `stale fifteen: 0`; `stale seventeen: 0`.

- [x] **Step 8: Commit**

```bash
gt modify -c -m "docs: register woostack-dream in AGENTS.md"
```

### Task 3: Update `README.md` (surface sentence + command section)

**Files:**
- Modify: `README.md`

- [x] **Step 1: Update the surface sentence (line 28)** — `surface is fifteen skills:` → `surface is sixteen skills:`, and append `woostack-dream` to the comma list after `woostack-tdd` (e.g. `…woostack-debug, woostack-tdd, and woostack-dream.`).

- [x] **Step 2: Add a command section** after the `/woostack-tdd` section (around line 111):

```markdown
### `/woostack-dream [instructions]`: curate memory & recommend doc updates

The agent-agnostic version of managed "dreams": a reflection pass over your `.woostack/` knowledge store. It reads the memory store and docs (static — no session mining), then proposes a single gated changeset that merges duplicate notes, replaces stale or contradicted ones, drops dead/orphaned notes, resolves conflicts `doctor.sh` only flags, surfaces consolidated insights, and recommends **evidence-guarded** edits to your docs (promoting recurring conventions, fixing claims memory now contradicts). Nothing changes before you approve; it ends on a summary and lets you request changes. Memory edits are local-only; doc edits land in the working tree (offer to `woostack-commit`). Never commits or merges. → [SKILL.md](skills/woostack-dream/SKILL.md)
```

- [x] **Step 3: Green — README lists and documents the command**

Run:
```bash
echo "sentence: $(grep -c 'sixteen skills' README.md)"
echo "section: $(grep -c '### `/woostack-dream' README.md)"
echo "stale: $(grep -c 'fifteen skills' README.md)"
```
Expected: `sentence: 1`; `section: 1`; `stale: 0`.

- [x] **Step 4: Commit**

```bash
gt modify -c -m "docs: document woostack-dream in README"
```

### Task 4: Cross-file consistency check

**Files:**
- Verify: `skills/using-woostack/SKILL.md`, `AGENTS.md`, `README.md`, `skills/woostack-dream/SKILL.md`

- [x] **Step 1: Assert the command is registered in every surface** (covers AC7)

Run:
```bash
for f in skills/woostack-dream/SKILL.md skills/using-woostack/SKILL.md AGENTS.md README.md; do
  grep -q 'woostack-dream' "$f" && echo "OK: $f" || echo "MISSING: $f"
done
```
Expected: four `OK:` lines, no `MISSING:`.

- [x] **Step 2: Assert no stale fifteen/seventeen count survives the wired surface**

Run: `grep -rilE 'fifteen|seventeen' AGENTS.md README.md skills/using-woostack/SKILL.md | wc -l | tr -d ' '`
Expected: `0`

- [x] **Step 3: Commit any fixes**

```bash
# only if Steps 1-2 surfaced a fix; otherwise skip
gt modify -c -m "docs: reconcile woostack-dream surface counts"
```

---

## Self-review (run before handing back)

- [ ] **Spec coverage** — AC1 (Inc1 T1 + T2 S1), AC2 (Inc1 T1 Phase 3 + T2 S2), AC3 (Inc1 T1 Phase 2/4 + T2 S2), AC4 (Phase 2 doc-recommendation + T2 S2 `evidence guard`), AC5 (Degradation + T2 S2), AC6 (Hard constraints + T2 S2), AC7 (Inc2 all tasks), AC8 (Phase 5), AC9 (Phase 2 merge/drop link rewrite + idempotent language + Inc1 T2 S3). All mapped.
- [ ] **AC coverage** — each AC's happy/edge/error case maps to a grep/test assertion or an authored-section requirement above.
- [ ] **No placeholders** — exact paths, exact commands, expected output in every step; SKILL.md content specified section-by-section.
- [ ] **Type consistency** — phase names (Gather/Synthesize/Review gate/Apply/Summarize), op names (merge/replace/drop/resolve/surface/doc), and script names (`doctor.sh`/`build-index.sh`/`graph.sh`) are used identically across plan and skill.

> woostack plan conventions (kept):
> - Frontmatter-free; opens with the `**Source:**` line.
> - Filename mirrors the spec basename: `.woostack/plans/2026-06-09-woostack-dream.md`.
> - No required sub-skill banner — execution is `woostack-execute`'s.
> - No test runner here → "failing test" steps are concrete `grep`/`test` verifications with exact expected output.
