**Source:** .woostack/specs/2026-06-11-woostack-dream-design-trends.md

# Shared Curated Memory + Design-Trend Consolidation Implementation Plan

**Goal:** Make consolidated learnings both token-efficient to recall and committed/shared, and have `woostack-dream` consolidate design trends from the `specs/plans/fixes` decision corpus into that shared store.

**Architecture:** Four PR-sized, Graphite-stacked increments on top of the spec+plan PR: **(A)** remove the flat `memory.md` shard so the scoped `.woostack/memory/` store is the single surface; **(B)** move recall telemetry off note frontmatter into a gitignored `.telemetry.tsv` sidecar; **(C)** flip `.gitignore` to track the store and re-route in-worktree distill commits; **(D)** teach `woostack-dream` to mine the corpus, consolidate cross-artifact design trends into tracked notes, commit via `woostack-commit`, and read incrementally. The memory contract [`skills/woostack-init/references/memory.md`](../../skills/woostack-init/references/memory.md) is the single schema home; consuming skills cross-link it.

**Tech Stack:** Bash (POSIX-ish, bash 3.2 compatible) for the `woostack-init` scripts + their `tests/assert.sh` harness; Markdown skills/prompts/references; git/Graphite.

> No app runner/CI in this repo. Script changes are red/green against `skills/*/scripts/tests/*.sh`; prose/markdown changes are verified by concrete `grep`/`bash -n` commands with exact expected output (the `woostack-tdd` no-runner carve-out). Run a test file with `bash <path>`; a suite ends in `finish` (non-zero on any failure).

---

## Increment A: Remove the flat `memory.md` shard (single scoped store)

> One PR. Cohesive, atomic "remove flat memory" change — touches many files but a partial removal would leave a half-wired shard, so it ships as one slice. Low logic, mostly deletions + prose. **Breaking contract change**, called out in the commit body.

### Task A1: Drop flat-file handling from `recall.sh` (+ test)

**Files:**
- Modify: `skills/woostack-init/scripts/recall.sh:14,84-85` and the header comment `:4-6`
- Modify (comment cleanup): `skills/woostack-init/scripts/build-index.sh:3`, `skills/woostack-init/scripts/doctor.sh:3`
- Test: `skills/woostack-init/scripts/tests/test-recall.sh:10,35` (+ flat-only case)

- [ ] **Step 1: Update the test red-first — remove flat-shard expectations**

In `test-recall.sh`, the "Global memory" section currently includes flat `memory.md` content. Change the global-memory fixture to assert global-*scoped notes* only, and delete the flat-only sub-case. Replace the block around line 10:

```bash
# OLD (line ~10): seeds a flat memory.md and expects it in Global memory
printf -- '- accepted: do not flag X\n' > "$woo/memory.md"
```

with a global-scoped note fixture:

```bash
# Global memory now = global-scoped notes only (no flat memory.md).
mk_note "$woo/memory" gx.md $'name: gx\ntype: convention\nscope: *\nupdated: 2026-06-02' '- accepted: do not flag X'
bash "$DIR/../build-index.sh" "$woo/memory" >/dev/null
```

Delete the `woo2` flat-only case (lines ~35): `woo2="$(mktemp -d)"; printf -- '- only flat here\n' > "$woo2/memory.md"` and its assertions.

- [ ] **Step 2: Run the test, confirm it fails**

Run: `bash skills/woostack-init/scripts/tests/test-recall.sh`
Expected: FAIL — recall still emits the (now-absent) flat path; assertion on "do not flag X" coming from a global note fails because recall reads `$FLAT`.

- [ ] **Step 3: Remove flat handling from `recall.sh`**

Delete the flat var and its read. Change line 14 from:

```bash
MEM_DIR="$WOO/memory"; FLAT="$WOO/memory.md"
```

to:

```bash
MEM_DIR="$WOO/memory"
```

Replace lines 84-85:

```bash
global_out=""
[ -f "$FLAT" ] && global_out="$(cat "$FLAT")"
```

with:

```bash
global_out=""
```

Update the header comment (lines 4-6) to drop "flat memory.md +": the global shard is now "no-scope/`*` notes", always included, never dropped by `RECALL_CAP`. Also clean the now-inaccurate flat-file mentions in `build-index.sh:3` ("never reads/writes the flat memory.md" → "Indexes the dir only. Idempotent.") and `doctor.sh:3` ("the flat memory.md is free-form and never read" → drop the sentence).

- [ ] **Step 4: Run the test + lint the comment-only edits**

Run: `bash skills/woostack-init/scripts/tests/test-recall.sh && bash -n skills/woostack-init/scripts/build-index.sh && bash -n skills/woostack-init/scripts/doctor.sh`
Expected: PASS — `finish` reports 0 failed; both `bash -n` exit 0.

- [ ] **Step 5: Commit**

```bash
gt create -m "refactor(memory): recall.sh drops flat memory.md; global shard = global-scoped notes"
```

### Task A2: Collapse `memory-record.sh` to scoped-only; delete `memory-append.sh` (address-comments + review)

**Files:**
- Modify: `skills/woostack-address-comments/scripts/memory-record.sh:4,14,28-31`, `skills/woostack-review/scripts/memory-record.sh:4,14,28-31`
- Delete: `skills/woostack-address-comments/scripts/memory-append.sh`, `skills/woostack-review/scripts/memory-append.sh`
- Test: `skills/woostack-address-comments/scripts/tests/test-address-helper-scripts.sh`, `skills/woostack-review/scripts/tests/test-memory-record.sh`, `skills/woostack-address-comments/scripts/tests/test-address-worker-contract.sh`

- [ ] **Step 1: Update tests red-first — flat fallback becomes skip-with-notice**

In `test-memory-record.sh` and `test-address-helper-scripts.sh`, replace any "store absent ⇒ appends to flat memory.md" case with a skip-with-notice expectation:

```bash
# store absent: record skips with a notice, writes no flat file
woo="$(mktemp -d)"
out="$(MEMORY_DIR="$woo/memory" LEARNING="x" bash "$SCRIPTS/memory-record.sh" 2>&1 || true)"
assert_contains "$out" "no scoped store" "memory-record skips when .woostack/memory/ absent"
assert_exit 1 "$([ -e "$woo/memory.md" ]; echo $?)" "memory-record writes no flat memory.md"
```

Remove any `source ... memory-append.sh` references and the worker-contract assertion that `memory-append.sh` exists.

- [ ] **Step 2: Run the tests, confirm they fail**

Run: `bash skills/woostack-review/scripts/tests/test-memory-record.sh`
Expected: FAIL — current script falls back to `memory-append.sh` (writes a flat file) instead of skipping.

- [ ] **Step 3: Rewrite the fallback branch in both `memory-record.sh` copies**

Replace lines 28-31:

```bash
if [ ! -d "$MEMORY_DIR" ]; then
  MEMORY_FILE="$MEMORY_FILE" LEARNING="$NEW_NORM" bash "$HERE/memory-append.sh"
  exit 0
fi
```

with:

```bash
if [ ! -d "$MEMORY_DIR" ]; then
  echo "memory-record: no scoped store at $MEMORY_DIR; skipping (run /woostack-init)" >&2
  exit 0
fi
```

Delete the `MEMORY_FILE=` line (14) and the header line (4) mentioning the flat fallback. Then delete both `memory-append.sh` files:

```bash
git rm skills/woostack-address-comments/scripts/memory-append.sh skills/woostack-review/scripts/memory-append.sh
```

- [ ] **Step 4: Run the tests, confirm they pass**

Run: `bash skills/woostack-review/scripts/tests/test-memory-record.sh && bash skills/woostack-address-comments/scripts/tests/test-address-helper-scripts.sh && bash skills/woostack-address-comments/scripts/tests/test-address-worker-contract.sh`
Expected: PASS — all three `finish` clean.

- [ ] **Step 5: Commit**

```bash
gt modify -c -m "refactor(memory): record helpers scoped-only; remove flat memory-append.sh"
```

### Task A3: Remove `memory.md` from the gitignore template, scaffold, and its test

**Files:**
- Modify: `skills/woostack-init/templates/gitignore:7`, `skills/woostack-init/scripts/tests/test-gitignore-template.sh:13`, `skills/woostack-init/SKILL.md` (flat-seed step)

- [ ] **Step 1: Update the template test red-first**

In `test-gitignore-template.sh`, delete line 13 (`assert_contains "$body" "memory.md" ...`) and add:

```bash
assert_not_contains "$body" "$(printf 'memory.md')" "gitignore template no longer ignores a flat shard"
```

Use a literal, line-anchored check (the `.` in `memory.md` is a regex metachar, so `-F`):

```bash
assert_exit 1 "$(grep -qxF 'memory.md' "$template"; echo $?)" "no bare 'memory.md' line in gitignore template"
```

- [ ] **Step 2: Run, confirm fail**

Run: `bash skills/woostack-init/scripts/tests/test-gitignore-template.sh`
Expected: FAIL — template still has the `memory.md` line.

- [ ] **Step 3: Remove the line from the template + scaffold prose**

Delete line 7 (`memory.md`) from `skills/woostack-init/templates/gitignore`. In `skills/woostack-init/SKILL.md`, remove the step that seeds an empty flat `.woostack/memory.md` (the scoped store is the only memory surface).

- [ ] **Step 4: Run, confirm pass**

Run: `bash skills/woostack-init/scripts/tests/test-gitignore-template.sh`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
gt modify -c -m "refactor(init): drop flat memory.md from gitignore template + scaffold"
```

### Task A4: Purge the flat shard from the memory contract

**Files:**
- Modify: `skills/woostack-init/references/memory.md` §1, §2, §6, §7, §10

- [ ] **Step 1: Edit the contract sections**

- §1: delete the "additive layer on top of the flat `.woostack/memory.md` global shard … The flat file remains valid …" framing; state the scoped `.woostack/memory/` store is the single memory surface.
- §2 layout: remove the `memory.md  flat global shard …` line and its `.gitignore` mention.
- §6 step 1: change "Always load `memory/MEMORY.md` … and the flat `memory.md` global shard. Both are always present." → "Always load `memory/MEMORY.md`."
- §7: remove the address-comments "falls back to the flat `memory.md` bullet append path" sentence; state that when `.woostack/memory/` is absent the record is skipped (defer to `/woostack-init`).
- §10 degradation: drop "load … the flat `memory.md`"; with no scoped store, recall yields an empty set and record skips.

- [ ] **Step 2: Verify no flat-shard claims remain in the contract**

Target the flat *shard* (path + phrases), NOT the bare token `memory.md` — the contract is itself named `memory.md` and is cross-linked by that filename elsewhere.

Run: `grep -nE 'flat memory|global shard|\.woostack/memory\.md|flat \.woostack' skills/woostack-init/references/memory.md`
Expected: zero matches — no line presents a flat shard as a loaded/fallback surface.

- [ ] **Step 3: Commit**

```bash
gt modify -c -m "docs(memory): contract drops the flat memory.md shard (§1/2/6/7/10)"
```

### Task A5: Purge flat-shard fallback prose from consuming skills

**Files (modify):** `skills/woostack-dream/SKILL.md`, `skills/woostack-execute/SKILL.md`, `skills/woostack-execute-overnight/SKILL.md`, `skills/woostack-debug/SKILL.md`, `skills/woostack-tdd/SKILL.md`, `skills/woostack-commit/SKILL.md`, `skills/woostack-address-comments/SKILL.md` + `prompts/address.md` + `scripts/prefetch.sh`, `skills/woostack-review/SKILL.md` + `prompts/_header.md` + `prompts/validator.md` + `prompts/validator-prosecutor.md` + `scripts/prefetch.sh`, `skills/woostack-init/SKILL.md`, `skills/woostack-bootstrap/references/development.md`

- [ ] **Step 1: Find every flat-shard mention**

Target the flat shard specifically — `\.woostack/memory\.md` (the flat path) and the phrases — never the bare token `memory.md`, which also matches every `references/memory.md` cross-link.

Run: `grep -rnE 'flat memory|global shard|\.woostack/memory\.md' skills | grep -v '/specs/\|/plans/\|/fixes/'`
Expected: the list of sites to edit (the files above).

- [ ] **Step 2: Edit each site**

Remove "falls back to the flat `memory.md`" / "always-loaded flat shard" / "flat global shard" language. Where a skill described recall or memory-record degradation via the flat file, replace with: the scoped store is the only surface; absent store ⇒ recall empty / record skipped. Keep each skill's cross-link to the memory contract intact (link, don't restate).

- [ ] **Step 3: Verify the purge**

Run: `grep -rnE 'flat memory|global shard|\.woostack/memory\.md' skills | grep -v '/specs/\|/plans/\|/fixes/'`
Expected: zero matches (every flat-shard reference removed). Cross-links to the contract file `references/memory.md` are untouched and excluded by this pattern.

- [ ] **Step 4: Lint the touched scripts**

Run: `for s in skills/woostack-address-comments/scripts/prefetch.sh skills/woostack-review/scripts/prefetch.sh; do bash -n "$s" && echo "ok $s"; done`
Expected: `ok …` for each (no syntax breakage from prose/comment edits).

- [ ] **Step 5: Commit**

```bash
gt modify -c -m "docs(skills): remove flat memory.md fallback prose across the collection"
```

---

## Increment B: Recall telemetry → gitignored sidecar

> One PR, stacked on A. Moves `recall_count`/`last_recalled` off note frontmatter into `.woostack/memory/.telemetry.tsv` so notes can be tracked (Inc C) without churn.

### Task B1: Sidecar + `del_field` helpers in `lib.sh`

**Files:**
- Modify: `skills/woostack-init/scripts/lib.sh` (append helpers)
- Test: `skills/woostack-init/scripts/tests/test-lib.sh`

- [ ] **Step 1: Write failing tests for the new helpers**

Append to `test-lib.sh` before `finish`:

```bash
# --- telemetry sidecar ---
tmd="$(mktemp -d)"
tel_bump "$tmd" "alpha" "2026-06-11"
assert_eq "$(tel_get "$tmd" alpha recall_count)"  "1"          "tel_bump creates row count=1"
assert_eq "$(tel_get "$tmd" alpha last_recalled)" "2026-06-11" "tel_bump sets date"
tel_bump "$tmd" "alpha" "2026-06-12"
assert_eq "$(tel_get "$tmd" alpha recall_count)"  "2"          "tel_bump increments existing row"
assert_eq "$(tel_get "$tmd" alpha last_recalled)" "2026-06-12" "tel_bump refreshes date"
assert_eq "$(tel_get "$tmd" missing recall_count)" ""          "tel_get of unknown note is empty"

# --- del_field ---
dfd="$(mktemp -d)"; mk_note "$dfd" n.md $'name: x\ntype: pattern\nrecall_count: 3\nlast_recalled: 2026-01-01' 'body'
del_field "$dfd/n.md" recall_count
del_field "$dfd/n.md" last_recalled
assert_eq "$(field "$dfd/n.md" recall_count)"  "" "del_field removes recall_count"
assert_eq "$(field "$dfd/n.md" last_recalled)" "" "del_field removes last_recalled"
assert_eq "$(field "$dfd/n.md" name)" "x" "del_field preserves other fields"
assert_contains "$(note_body "$dfd/n.md")" "body" "del_field preserves body"
```

- [ ] **Step 2: Run, confirm fail**

Run: `bash skills/woostack-init/scripts/tests/test-lib.sh`
Expected: FAIL — `tel_bump: command not found` / `del_field: command not found`.

- [ ] **Step 3: Implement the helpers in `lib.sh`**

Append:

```bash
# --- telemetry sidecar: per-clone, gitignored, line-based TSV ---
# <memdir>/.telemetry.tsv rows: name<TAB>recall_count<TAB>last_recalled
_tel_file() { printf '%s\n' "$1/.telemetry.tsv"; }

# tel_get <memdir> <name> <recall_count|last_recalled> → value, empty if absent.
tel_get() {
  local f col; f="$(_tel_file "$1")"; [ -f "$f" ] || return 0
  case "$3" in recall_count) col=2 ;; last_recalled) col=3 ;; *) return 0 ;; esac
  awk -F'\t' -v n="$2" -v c="$col" '$1==n{print $c; exit}' "$f"
}

# tel_bump <memdir> <name> <iso-date> — upsert: increment count, set date.
# Atomic (temp + mv). Returns non-zero without changing the file on write failure.
tel_bump() {
  local memdir="$1" name="$2" date="$3" f tmp cur=0
  f="$(_tel_file "$memdir")"
  [ -d "$memdir" ] || return 1
  if [ -f "$f" ]; then
    cur="$(awk -F'\t' -v n="$name" '$1==n{print $2; exit}' "$f")"; cur="${cur:-0}"
    case "$cur" in (*[!0-9]*) cur=0 ;; esac
  fi
  tmp="$(mktemp "$memdir/.tel.XXXXXX")" || return 1
  { [ -f "$f" ] && awk -F'\t' -v n="$name" '$1!=n' "$f"
    printf '%s\t%s\t%s\n' "$name" "$(( cur + 1 ))" "$date"; } > "$tmp" || { rm -f "$tmp"; return 1; }
  mv "$tmp" "$f" || { rm -f "$tmp"; return 1; }
}

# del_field <file> <key> — remove a frontmatter key (atomic). No-op if absent.
del_field() {
  local file="$1" key="$2" tmp dir
  dir="$(dirname "$file")"; tmp="$(mktemp "$dir/.woomem.XXXXXX")" || return 1
  awk -v key="$key" '
    /^---$/{fence++; if(fence<=2){print; next}}
    { if(fence==1 && index($0, key ":")==1) next; print }
  ' "$file" > "$tmp" || { rm -f "$tmp"; return 1; }
  mv "$tmp" "$file" || { rm -f "$tmp"; return 1; }
}
```

- [ ] **Step 4: Run, confirm pass**

Run: `bash skills/woostack-init/scripts/tests/test-lib.sh`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
gt create -m "feat(memory): lib.sh telemetry-sidecar (tel_get/tel_bump) + del_field helpers"
```

### Task B2: `recall.sh` stamps the sidecar, not the note

**Files:**
- Modify: `skills/woostack-init/scripts/recall.sh:67-82`
- Test: `skills/woostack-init/scripts/tests/test-recall.sh:69-97`

- [ ] **Step 1: Rewrite the telemetry assertions (red)**

Replace the stamping assertions (lines 77-85) to read the sidecar via `tel_get` instead of `field … recall_count`:

```bash
assert_eq "$(tel_get "$md5" a recall_count)"  "1"          "matched note stamped count=1"
assert_eq "$(tel_get "$md5" a last_recalled)" "2026-06-02" "matched note last_recalled stamped"
assert_eq "$(tel_get "$md5" b recall_count)"  "1"          "one-hop linked note stamped"
assert_eq "$(tel_get "$md5" g recall_count)"  "1"          "global note stamped"
# note frontmatter is NOT mutated:
assert_eq "$(field "$md5/a.md" recall_count)" "" "recall does not write telemetry into note frontmatter"
```

And the second-run bumps (84-85):

```bash
assert_eq "$(tel_get "$md5" a recall_count)"  "2"          "second run bumps count to 2"
assert_eq "$(tel_get "$md5" a last_recalled)" "2026-06-03" "second run refreshes last_recalled"
```

- [ ] **Step 2: Run, confirm fail**

Run: `bash skills/woostack-init/scripts/tests/test-recall.sh`
Expected: FAIL — recall still writes `recall_count` into the note via `set_field`; `tel_get` finds no sidecar.

- [ ] **Step 3: Rewrite `stamp_note` to use `tel_bump`**

Replace lines 67-82 (the `stamp_note` block and its three loops). New `stamp_note`:

```bash
# --- Stamp recall telemetry into the gitignored sidecar (best-effort). ---
# Cumulative recall_count + last_recalled per note name. Failures never break
# recall: they log to stderr and recall still exits 0.
_now="$(_woo_now)"
stamp_note() {
  tel_bump "$MEM_DIR" "$(field "$1" name || basename "$1" .md)" "$_now" \
    || echo "recall: stamp failed $(basename "$1")" >&2
}
for f in "${matched_files[@]:-}"; do [ -n "${f:-}" ] && stamp_note "$f"; done
for f in "${linked_files[@]:-}"; do [ -n "${f:-}" ] && stamp_note "$f"; done
while IFS= read -r f; do [ -n "$f" ] && stamp_note "$f"; done < "$globals"
```

(The read-only-dir best-effort case still holds: `tel_bump` returns non-zero when it can't write the temp file, so the existing "stamp failed" stderr + exit-0 test at lines 87-97 passes unchanged — verify the fixture makes `$MEM_DIR` read-only, not just the note.)

- [ ] **Step 4: Run, confirm pass**

Run: `bash skills/woostack-init/scripts/tests/test-recall.sh`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
gt modify -c -m "feat(memory): recall.sh stamps telemetry to the sidecar, not note frontmatter"
```

### Task B3: `doctor.sh` dead-note check reads the sidecar

**Files:**
- Modify: `skills/woostack-init/scripts/doctor.sh:85`
- Test: `skills/woostack-init/scripts/tests/test-doctor.sh:147`

- [ ] **Step 1: Update the "recalled note never dead" fixture (red)**

In `test-doctor.sh`, the case at line 147 encodes recall via frontmatter (`recall_count: 3`). Move that signal to the sidecar:

```bash
mk_note "$dd2" old.md $'name: old\ntype: pattern\nscope: *\nupdated: 2026-01-01' 'body'
printf 'old\t3\t2026-05-01\n' > "$dd2/.telemetry.tsv"
OUT="$(WOOSTACK_NOW=2026-06-01 bash "$DIR/../doctor.sh" "$dd2" 2>&1 || true)"
assert_not_contains "$OUT" "dead note" "a note recalled per the sidecar is never flagged dead"
```

- [ ] **Step 2: Run, confirm fail**

Run: `bash skills/woostack-init/scripts/tests/test-doctor.sh`
Expected: FAIL — doctor reads `recall_count` from frontmatter (now absent) → treats the note as never-recalled → emits "dead note".

- [ ] **Step 3: Read the count from the sidecar in `doctor.sh`**

Replace line 85:

```bash
rc="$(field "$f" recall_count)"; rc="${rc:-0}"
```

with:

```bash
rc="$(tel_get "$MEM_DIR" "$name" recall_count)"; rc="${rc:-0}"
```

- [ ] **Step 4: Run, confirm pass**

Run: `bash skills/woostack-init/scripts/tests/test-doctor.sh`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
gt modify -c -m "feat(memory): doctor.sh dead-note check joins recall_count from the sidecar"
```

### Task B4: Contract §3/§8 doc update + one-time strip of existing notes

**Files:**
- Modify: `skills/woostack-init/references/memory.md` §3 (field table), §8 (dead-note source)
- One-time data fix: this repo's `.woostack/memory/*.md`

- [ ] **Step 1: Edit the contract**

§3: remove the `recall_count` and `last_recalled` rows from the note-frontmatter field table; add a short paragraph: telemetry lives in a tool-managed, gitignored `.woostack/memory/.telemetry.tsv` sidecar (`name⇥recall_count⇥last_recalled`), written by `recall.sh`, read by `doctor.sh`; stray copies in note frontmatter are inert. §8: change "reads `recall_count`/`last_recalled` (§3) … stamps … on every selected note" to "stamps the sidecar"; the dead-note check joins the sidecar by name.

- [ ] **Step 2: One-time strip of telemetry frontmatter from this repo's notes**

Run (in the primary tree, before Inc C tracks them):

```bash
( source skills/woostack-init/scripts/lib.sh
  for f in .woostack/memory/*.md; do
    [ "$(basename "$f")" = MEMORY.md ] && continue
    del_field "$f" recall_count; del_field "$f" last_recalled
  done )
```

- [ ] **Step 3: Verify the strip + contract**

Run: `grep -lE '^recall_count:|^last_recalled:' .woostack/memory/*.md; grep -nE 'recall_count|last_recalled' skills/woostack-init/references/memory.md`
Expected: no note files listed (telemetry stripped); the contract mentions the fields only as "sidecar / inert", not as live frontmatter rows.

- [ ] **Step 4: Commit**

```bash
gt modify -c -m "docs(memory): contract §3/§8 telemetry → sidecar; strip stale frontmatter"
```

> Note: this repo's `.woostack/memory/` is still gitignored until Inc C, so the strip is a working-tree cleanup that Inc C then commits.

---

## Increment C: Track the scoped memory store

> One PR, stacked on B. Flips `.gitignore`, mirrors the scaffold, and re-routes distill so memory rides the increment commit in-worktree. Tracking this repo's ~26 existing (now telemetry-clean) notes lands as one commit.

### Task C1: Flip `.gitignore` + template + test to track memory

**Files:**
- Modify: `.woostack/.gitignore`, `skills/woostack-init/templates/gitignore`, `skills/woostack-init/scripts/tests/test-gitignore-template.sh`

- [ ] **Step 1: Update the template test (red)**

In `test-gitignore-template.sh`, replace the `memory/` assertion (line 14) with sidecar/watermark-only ignores:

```bash
assert_exit 1 "$(grep -qx 'memory/' "$template"; echo $?)" "template no longer ignores the whole scoped store"
assert_contains "$body" "memory/.telemetry.tsv"  "template ignores the telemetry sidecar"
assert_contains "$body" "memory/.dream-watermark" "template ignores the dream watermark"
```

- [ ] **Step 2: Run, confirm fail**

Run: `bash skills/woostack-init/scripts/tests/test-gitignore-template.sh`
Expected: FAIL — template still has the bare `memory/` line, lacks the sidecar/watermark lines.

- [ ] **Step 3: Edit both gitignores**

In `skills/woostack-init/templates/gitignore`, replace the `memory/` line with:

```
memory/.telemetry.tsv
memory/.dream-watermark
```

Apply the identical change to `.woostack/.gitignore` (remove `memory/`, add the two ignore lines; `memory.md` already gone in Inc A). `metrics.json`, `*.local.*`, `visuals/`, `overnight/`, `worktrees/`, and `.obsidian/workspace*`/`cache` stay.

- [ ] **Step 4: Run, confirm pass; confirm notes are now tracked**

Run: `bash skills/woostack-init/scripts/tests/test-gitignore-template.sh && git check-ignore -v .woostack/memory/MEMORY.md; echo "exit=$?"`
Expected: test PASS; `git check-ignore` prints nothing and `exit=1` (MEMORY.md is no longer ignored). `git check-ignore .woostack/memory/.telemetry.tsv` still matches.

- [ ] **Step 5: Stage the now-tracked store + commit**

```bash
git add .woostack/memory/ .woostack/.gitignore skills/woostack-init/templates/gitignore skills/woostack-init/scripts/tests/test-gitignore-template.sh
gt create -m "feat(memory): track the scoped store; ignore only telemetry/watermark sidecars"
```

### Task C2: Worktree contract + `execute`/`-overnight` distill ride the in-worktree commit

**Files:**
- Modify: `skills/woostack-init/references/worktrees.md` §3, §5
- Modify: `skills/woostack-execute/SKILL.md:121-136,169,190`, `skills/woostack-execute-overnight/SKILL.md` (the `WOOSTACK_ROOT`-anchored-distill line ~39)

- [ ] **Step 1: Edit `worktrees.md`**

§3 local-only exception: remove `.woostack/memory/` from the list — keep only `.woostack/metrics.json`, the telemetry sidecar, and the dream watermark as gitignored/primary-only. Add a sentence: tracked memory notes are written **in the worktree** and ride the increment's commit. §5: scope the `WOOSTACK_ROOT` redirect to metrics/telemetry/watermark only; memory notes + `MEMORY.md` are committed on the increment branch, so they need no primary redirect.

- [ ] **Step 2: Edit `woostack-execute` step 7 (distill)**

Replace the redirect instruction (lines 130-133) — drop the `export WOOSTACK_ROOT=…` for memory and the "local-only to the primary tree" rationale. New text: distill into `.woostack/memory/` **in the worktree**, rebuild `MEMORY.md` there with `build-index.sh`, and let the note + index ride the increment's `woostack-commit` (step alongside the code). Update the "Distilled memory notes … are local-only and gitignored" lines (169, 190): memory is now tracked and ships with the increment PR; only metrics/telemetry stay local. Keep the §7 reject-by-default gate wording intact.

- [ ] **Step 3: Edit `woostack-execute-overnight`**

Update the per-increment cadence line (~39) `WOOSTACK_ROOT-anchored distill` → distill in-worktree, committed with the increment; metrics/telemetry remain `WOOSTACK_ROOT`-anchored.

- [ ] **Step 4: Verify**

Run: `grep -nE 'local-only|WOOSTACK_ROOT' skills/woostack-execute/SKILL.md skills/woostack-execute-overnight/SKILL.md skills/woostack-init/references/worktrees.md | grep -i memory`
Expected: no line claims memory is local-only/primary-redirected; remaining `WOOSTACK_ROOT` references are scoped to metrics/telemetry/watermark.

- [ ] **Step 5: Commit**

```bash
gt modify -c -m "docs(worktrees): tracked memory rides in-worktree distill commit (execute/-overnight)"
```

### Task C3: Contract §2 + ripple prose (execute/address/review note shared memory)

**Files:**
- Modify: `skills/woostack-init/references/memory.md` §2; `skills/woostack-execute/SKILL.md`, `skills/woostack-address-comments/SKILL.md`, `skills/woostack-review/SKILL.md` (one line each)

- [ ] **Step 1: Edit §2 layout**

Update the `.gitignore` description: tracks `specs/`, `plans/`, `fixes/`, `config.json`, **and now `memory/` notes + `MEMORY.md`**; ignores `metrics.json`, `*.local.*`, the telemetry sidecar, and the dream watermark. Note that memory is now shared team knowledge.

- [ ] **Step 2: One-line ripple notes**

In each of `execute`/`address-comments`/`review` SKILL.md, where they describe distilled/recorded memory, add that the note is now **tracked/shared** and rides the existing commit (no new commit logic).

- [ ] **Step 3: Verify**

Run: `grep -nE 'tracked|shared' skills/woostack-init/references/memory.md | grep -i 'memory/'; grep -rn 'shared' skills/woostack-execute/SKILL.md skills/woostack-address-comments/SKILL.md skills/woostack-review/SKILL.md | grep -i memory`
Expected: §2 states notes/index are tracked; each skill notes shared memory.

- [ ] **Step 4: Commit**

```bash
gt modify -c -m "docs(memory): §2 notes/index tracked + shared; ripple note in execute/address/review"
```

---

## Increment D: `woostack-dream` — design-trend mining + commit + incremental

> One PR, stacked on C. The original ask, now writing tracked notes. All edits in `skills/woostack-dream/SKILL.md` (+ frontmatter). Prose-only skill; verified by structural grep + a live dry-run.

### Task D1: Description + Phase 1 corpus read

**Files:**
- Modify: `skills/woostack-dream/SKILL.md` frontmatter `description`, Phase 1 (§"Gather")

- [ ] **Step 1: Widen the `description`**

Change "Reflects over the static memory store + docs (no session mining)" → "Reflects over the static memory store, the specs/plans/fixes decision corpus, and docs (no session mining)". Keep the rest.

- [ ] **Step 2: Add the corpus-as-input step to Phase 1**

After the existing follow-`source:`-for-staleness sentence, add: *enumerate and read the full `.woostack/{specs,plans,fixes}/*.md` corpus as design-trend input to the `surface` op (incrementally — see Phase 2)*. Explicitly distinguish this from the staleness read, and **keep** the existing sentence excluding `.woostack/{specs,plans,fixes}/*.md` from the doc-promotion **target** set (inputs, not promotion targets).

- [ ] **Step 3: Verify**

Run: `grep -nE 'decision corpus|specs,plans,fixes|design-trend|promotion-target' skills/woostack-dream/SKILL.md`
Expected: description names the corpus; Phase 1 has the corpus-as-input line AND retains the promotion-target exclusion.

- [ ] **Step 4: Commit**

```bash
gt create -m "feat(dream): read the specs/plans/fixes corpus as design-trend input"
```

### Task D2: `surface` op consolidates cross-artifact design trends

**Files:**
- Modify: `skills/woostack-dream/SKILL.md` Phase 2 `surface` bullet

- [ ] **Step 1: Extend the `surface` definition**

Add to the `surface` bullet: a recurring pattern may be a **design decision recurring across the specs/plans/fixes corpus**, consolidated into one tracked note. `source:` = the most-specific contributing artifact path (never fabricated). The note passes the §7 reject-by-default gate (cross-feature glob scope, provenance, dedupe, `updated:` stamp) and uses a recall-eligible type (`decision`/`pattern`/`convention`), never `spec`/`plan`. Dedupe is **store-wide** (against `MEMORY.md` + fuzzy hooks): a corroborated trend **strengthens/rescopes the existing note** rather than re-adding — the token-efficiency mechanism. Superseded raw scratch is pruned via the existing `drop` op (full-body gate).

- [ ] **Step 2: Verify**

Run: `grep -nE 'across the specs/plans/fixes|store-wide|strengthen|recall-eligible|never .*spec.*plan' skills/woostack-dream/SKILL.md`
Expected: the surface bullet carries the cross-artifact + store-wide-dedupe + recall-eligible-type language.

- [ ] **Step 3: Commit**

```bash
gt modify -c -m "feat(dream): surface consolidates cross-artifact design trends (store-wide dedupe)"
```

### Task D3: Incremental watermark, commit handoff, idempotence restate

**Files:**
- Modify: `skills/woostack-dream/SKILL.md` Phase 1 (watermark), Phase 4/5 (commit), Hard constraints (drop local-only)

- [ ] **Step 1: Document the incremental read**

In Phase 1/2, add: the corpus trigger set is artifacts new/changed since the gitignored `.woostack/memory/.dream-watermark` (which stores a **git ref**): `git log <ref>..HEAD --name-only -- .woostack/specs .woostack/plans .woostack/fixes`. Matching is against the always-read note index as the **history proxy** (a new artifact corroborating a decision already captured as a note strengthens it; new-vs-new is a fresh trend). **First run (no/absent/corrupt watermark, or non-git checkout) = full-corpus baseline.** `instructions: "full corpus"` forces a re-baseline. The watermark advances to `HEAD` **only after a successful, approved run**.

- [ ] **Step 2: Flip the commit stance**

Phase 4/5 + Hard constraints: remove "Local-only memory … never staged or committed". New stance: memory notes are tracked, so on approval `woostack-dream` hands **both** curated memory changes and doc edits to `woostack-commit`; it still **never self-commits and never merges**. Restate idempotence as **"a re-run with no new artifacts since the watermark is a no-op"** (replace the pure-static wording).

- [ ] **Step 3: Verify**

Run: `grep -nE 'dream-watermark|git log .*--name-only|full-corpus baseline|woostack-commit|no-op' skills/woostack-dream/SKILL.md; grep -nE 'local-only|never .*commit' skills/woostack-dream/SKILL.md`
Expected: watermark/baseline/commit-handoff/no-op language present; no remaining "local-only memory / never commit" hard constraint (only "never self-commit / never merge").

- [ ] **Step 4: Commit**

```bash
gt modify -c -m "feat(dream): incremental watermark + first-run baseline; commit via woostack-commit"
```

### Task D4: Degradation + error handling for the corpus path

**Files:**
- Modify: `skills/woostack-dream/SKILL.md` Degradation, Hard constraints

- [ ] **Step 1: Edit degradation/errors**

Add: an absent/empty `{specs,plans,fixes}/` corpus makes trend mining a no-op (the rest of the pass proceeds); a missing/corrupt watermark falls back to a full-corpus baseline (never errors); a detected trend that duplicates an existing note routes to an update, not a duplicate add.

- [ ] **Step 2: Live dry-run (acceptance smoke)**

Run, against this repo's populated store/corpus:

```bash
( source skills/woostack-init/scripts/lib.sh
  printf 'recall sidecar: '; tel_get .woostack/memory some-note recall_count; echo )
bash skills/woostack-init/scripts/doctor.sh .woostack/memory; echo "doctor exit=$?"
```

Then invoke `/woostack-dream` and confirm by observation: Phase 1 reads the corpus, `surface` proposes ≥1 cross-artifact trend note (or correctly reports none / all-already-distilled) each with a real contributing-artifact `source:`, the HARD gate halts before any write, and (on a test approval) the watermark advances and a second run with no new artifacts is a no-op.
Expected: `doctor exit=0` (warnings ok); dream halts at the gate with a labeled changeset; no write before approval.

- [ ] **Step 3: Cross-link integrity sweep (whole change)**

Relative `*.md` links in every changed markdown file resolve:

```bash
for f in $(git diff --name-only main -- '*.md'); do
  d="$(dirname "$f")"
  grep -oE '\]\([^)]+\.md[^)]*\)' "$f" | sed -E 's/^\]\(//; s/[)#].*$//' | while read -r rel; do
    case "$rel" in /*|http*) continue ;; esac
    [ -f "$d/$rel" ] || echo "BROKEN: $f -> $rel"
  done
done; echo "link sweep done"
```

Expected: no `BROKEN:` lines; `link sweep done`.

And the flat-shard claims are gone collection-wide:

```bash
grep -rnE 'flat memory|global shard|\.woostack/memory\.md' skills | grep -v '/specs/\|/plans/\|/fixes/' || echo "clean: no flat-shard claims remain"
```

Expected: `clean: no flat-shard claims remain`.

- [ ] **Step 4: Commit**

```bash
gt modify -c -m "docs(dream): corpus/watermark degradation + error handling; dry-run verified"
```

---

## Self-review (run before handing back)

- [ ] **Spec coverage** — AC-A1/A2/A3 → Inc A tasks A1-A5; AC-B1 → B1-B4; AC-C1 → C1, AC-C2 → C2, C3; AC-D1 → D1-D2, AC-D2 → D3, AC-D3 → D1; AC-X (cross-link/count) → A4/A5 grep gates + D4 sweep. Every AC maps to a task/verification.
- [ ] **AC coverage** — each filled happy/error/edge case has a bash test (scripts) or a grep/dry-run check (prose): sidecar upsert+join (B1-B3), no-flat assertions (A1-A3), gitignore tracks-store/ignores-sidecar (C1), record skip-with-notice (A2), watermark baseline + no-op idempotence (D3-D4).
- [ ] **No placeholders** — every step has real code, exact commands, expected output. No TBD/TODO.
- [ ] **Type consistency** — helper names match across tasks: `tel_get`/`tel_bump`/`_tel_file`/`del_field` (lib.sh, used identically in recall.sh B2 and doctor.sh B3); sidecar path `.woostack/memory/.telemetry.tsv` and watermark `.woostack/memory/.dream-watermark` consistent in B, C, D.
