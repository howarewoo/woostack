---
type: plan
source: .woostack/specs/2026-06-02-memory-recall-telemetry.md
status: done
branch: feat/memory-recall-telemetry
---

# Memory Recall Telemetry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist recall usage (`recall_count` + `last_recalled`) onto each memory note when `recall.sh` loads it, and add a `doctor.sh` dead-note warning, converting the store from write-only to self-correcting.

**Architecture:** Add three shared helpers to `lib.sh` (`set_field` for atomic frontmatter mutation, `_woo_now` + `_woo_epoch` for deterministic dates). `recall.sh` stamps every selected note (matched + one-hop linked + global) best-effort. `doctor.sh` derives a dead-note warning from `updated:` age vs `recall_count`. Document the new fields + knobs in the memory contract. No app code — these are skill assets.

**Tech Stack:** POSIX-ish bash (3.2 / macOS BSD compatible), awk, the existing `tests/assert.sh` harness. No new dependencies.

**Source:** [[specs/2026-06-02-memory-recall-telemetry]] · Issue #159.

**Conventions to respect:**
- All scripts live in `skills/woostack-init/scripts/`. `lib.sh` is sourced by `recall.sh`, `doctor.sh`, `build-index.sh`.
- bash 3.2: no `mapfile`, no GNU-only flags. macOS `date` is BSD (no `-d`); macOS `mktemp` needs an `XXXXXX` template.
- Tests: each `test-*.sh` sources `tests/assert.sh` (which provides `assert_eq`, `assert_contains`, `assert_not_contains`, `assert_exit`, `mk_note`, `finish`). Run all via `tests/run-tests.sh`.
- Frontmatter is line-oriented between two `---` fences. `field()` reads the first match; `note_body()` is everything after the second fence.

---

## File Structure

| File | Responsibility | Change |
|---|---|---|
| `skills/woostack-init/scripts/lib.sh` | Shared frontmatter + date helpers | Add `set_field`, `_woo_now`, `_woo_epoch` |
| `skills/woostack-init/scripts/recall.sh` | Compose per-PR memory; now also stamps telemetry | Add stamping block |
| `skills/woostack-init/scripts/doctor.sh` | Lint memory dir; now warns on dead notes | Add dead-note check |
| `skills/woostack-init/references/memory.md` | Memory contract | Document new fields + doctor behavior + knobs |
| `skills/woostack-init/scripts/tests/test-lib.sh` | Unit tests for lib helpers | Add `set_field` + date-helper tests |
| `skills/woostack-init/scripts/tests/test-recall.sh` | recall behavior tests | Add stamping tests |
| `skills/woostack-init/scripts/tests/test-doctor.sh` | doctor behavior tests | Add dead-note tests |

---

## Task 1: Date helpers in lib.sh (`_woo_now`, `_woo_epoch`)

**Files:**
- Modify: `skills/woostack-init/scripts/lib.sh`
- Test: `skills/woostack-init/scripts/tests/test-lib.sh`

- [ ] **Step 1: Read the current test file to find the source line + append point**

Run: `cat skills/woostack-init/scripts/tests/test-lib.sh`
Confirm it sources `lib.sh` (via `$DIR/lib.sh` or similar) and ends with `finish`. You will append new assertions *before* the final `finish` call.

- [ ] **Step 2: Write the failing tests** (append before `finish` in `test-lib.sh`)

```bash
# --- _woo_now / _woo_epoch ---
assert_eq "$(WOOSTACK_NOW=2026-01-02 _woo_now)" "2026-01-02" "_woo_now honors WOOSTACK_NOW"
e1="$(_woo_epoch 2026-01-01)"; e2="$(_woo_epoch 2026-01-02)"
assert_eq "$(( e2 - e1 ))" "86400" "_woo_epoch: one day apart = 86400s (time-of-day zeroed)"
set +e; _woo_epoch "not-a-date" >/dev/null 2>&1; rc=$?; set -e
assert_exit 1 "$rc" "_woo_epoch returns non-zero on unparseable input"
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `bash skills/woostack-init/scripts/tests/test-lib.sh`
Expected: FAIL — `_woo_now`/`_woo_epoch` not defined (`command not found`) or assertion failures.

- [ ] **Step 4: Implement the helpers** (append to `skills/woostack-init/scripts/lib.sh`)

```bash
# _woo_now → today's ISO date (YYYY-MM-DD). Override with WOOSTACK_NOW for tests.
_woo_now() { printf '%s\n' "${WOOSTACK_NOW:-$(date +%F)}"; }

# _woo_epoch <YYYY-MM-DD> → Unix epoch seconds at 00:00:00 of that date.
# Time-of-day is zeroed so age math and tests are deterministic. Tries GNU
# `date -d` first, falls back to BSD `date -j -f`. Non-zero on unparseable input.
_woo_epoch() {
  local d="$1" e
  e="$(date -d "$d 00:00:00" +%s 2>/dev/null)" \
    || e="$(date -j -f '%Y-%m-%d %H:%M:%S' "$d 00:00:00" +%s 2>/dev/null)" \
    || return 1
  printf '%s\n' "$e"
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bash skills/woostack-init/scripts/tests/test-lib.sh`
Expected: PASS (the three new assertions; existing ones still pass).

- [ ] **Step 6: Commit**

```bash
git add skills/woostack-init/scripts/lib.sh skills/woostack-init/scripts/tests/test-lib.sh
git commit -m "feat(memory): add _woo_now/_woo_epoch date helpers to lib.sh"
```

---

## Task 2: `set_field` frontmatter mutator in lib.sh

**Files:**
- Modify: `skills/woostack-init/scripts/lib.sh`
- Test: `skills/woostack-init/scripts/tests/test-lib.sh`

- [ ] **Step 1: Write the failing tests** (append before `finish` in `test-lib.sh`)

```bash
# --- set_field ---
sfd="$(mktemp -d)"
mk_note "$sfd" n.md $'name: x\ntype: pattern\nscope: a/**' 'body [[link]] here'
# update existing key
set_field "$sfd/n.md" type "gotcha"
assert_eq "$(field "$sfd/n.md" type)" "gotcha" "set_field updates an existing key"
assert_eq "$(field "$sfd/n.md" name)" "x" "set_field: other fields preserved on update"
assert_contains "$(note_body "$sfd/n.md")" "body [[link]] here" "set_field: body preserved on update"
# insert absent key
set_field "$sfd/n.md" recall_count "1"
assert_eq "$(field "$sfd/n.md" recall_count)" "1" "set_field inserts an absent key"
assert_eq "$(field "$sfd/n.md" name)" "x" "set_field: fields intact after insert"
assert_contains "$(note_body "$sfd/n.md")" "body [[link]] here" "set_field: body intact after insert"
# date value round-trips
set_field "$sfd/n.md" last_recalled "2026-06-02"
assert_eq "$(field "$sfd/n.md" last_recalled)" "2026-06-02" "set_field: date value round-trips"
# malformed note (no frontmatter) → non-zero, file unchanged
printf 'no frontmatter\n' > "$sfd/bad.md"
set +e; set_field "$sfd/bad.md" recall_count 1; rc=$?; set -e
assert_exit 1 "$rc" "set_field fails on a note without frontmatter"
assert_eq "$(cat "$sfd/bad.md")" "no frontmatter" "set_field leaves a malformed note unchanged"
rm -rf "$sfd"
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash skills/woostack-init/scripts/tests/test-lib.sh`
Expected: FAIL — `set_field: command not found`.

- [ ] **Step 3: Implement `set_field`** (append to `skills/woostack-init/scripts/lib.sh`)

```bash
# set_field <file> <key> <value> — set a frontmatter key (update if present, else
# insert before the closing fence). Rewrites ONLY the first frontmatter block;
# body and all other fields are preserved verbatim. Atomic: writes a temp file in
# the note's own directory, then mv's it over the original. Returns non-zero
# WITHOUT modifying the file if it lacks two '---' fences or the write fails.
set_field() {
  local file="$1" key="$2" val="$3" tmp dir
  [ "$(grep -c '^---$' "$file" 2>/dev/null)" -ge 2 ] || return 1
  dir="$(dirname "$file")"
  tmp="$(mktemp "$dir/.woomem.XXXXXX")" || return 1
  awk -v key="$key" -v val="$val" '
    { 
      if ($0 == "---") {
        fence++
        if (fence == 1) { infm=1; print; next }
        if (fence == 2) { if (infm && !seen) print key ": " val; infm=0; print; next }
      }
      if (infm && !seen && index($0, key ":") == 1) { print key ": " val; seen=1; next }
      print
    }
  ' "$file" > "$tmp" || { rm -f "$tmp"; return 1; }
  mv "$tmp" "$file" || { rm -f "$tmp"; return 1; }
}
```

Note: `index($0, key ":") == 1` matches a line that *starts with* `key:` without treating `key` as a regex (robust + matches how `field()` greps `^key:`).

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash skills/woostack-init/scripts/tests/test-lib.sh`
Expected: PASS (all new assertions).

- [ ] **Step 5: Commit**

```bash
git add skills/woostack-init/scripts/lib.sh skills/woostack-init/scripts/tests/test-lib.sh
git commit -m "feat(memory): add atomic set_field frontmatter mutator to lib.sh"
```

---

## Task 3: Stamp telemetry in recall.sh

**Files:**
- Modify: `skills/woostack-init/scripts/recall.sh` (insert after `linked_files` array is built, ~line 62, before the `global_out` block)
- Test: `skills/woostack-init/scripts/tests/test-recall.sh`

- [ ] **Step 1: Write the failing tests** (append before `finish` in `test-recall.sh`)

```bash
# --- telemetry stamping ---
woo5="$(mktemp -d)"; md5="$woo5/memory"; mkdir -p "$md5"
mk_note "$md5" a.md $'name: a\ntype: pattern\nscope: pkg/**'      'A body [[b]]'
mk_note "$md5" b.md $'name: b\ntype: pattern\nscope: zzz/**'      'B linked body'
mk_note "$md5" g.md $'name: g\ntype: convention\nscope: *'        'G global body'
p5="$(mktemp)"; printf 'pkg/x.ts\n' > "$p5"

WOOSTACK_NOW=2026-06-02 bash "$RECALL" "$woo5" "$p5" >/dev/null
assert_eq "$(field "$md5/a.md" recall_count)"  "1"          "matched note stamped count=1"
assert_eq "$(field "$md5/a.md" last_recalled)" "2026-06-02" "matched note last_recalled stamped"
assert_eq "$(field "$md5/b.md" recall_count)"  "1"          "one-hop linked note stamped"
assert_eq "$(field "$md5/g.md" recall_count)"  "1"          "global (scope:*) note stamped"

# second run bumps the cumulative count and refreshes the date
WOOSTACK_NOW=2026-06-03 bash "$RECALL" "$woo5" "$p5" >/dev/null
assert_eq "$(field "$md5/a.md" recall_count)"  "2"          "second run bumps count to 2"
assert_eq "$(field "$md5/a.md" last_recalled)" "2026-06-03" "second run refreshes last_recalled"

# best-effort: a read-only memory dir makes stamping fail, but recall still
# produces output and exits 0, logging the failure to stderr.
chmod -R a-w "$md5" 2>/dev/null || true
set +e
out="$(WOOSTACK_NOW=2026-06-04 bash "$RECALL" "$woo5" "$p5" 2>/dev/null)"; code=$?
err="$(WOOSTACK_NOW=2026-06-04 bash "$RECALL" "$woo5" "$p5" 2>&1 >/dev/null)"
set -e
chmod -R u+w "$md5" 2>/dev/null || true
assert_exit 0 "$code"            "recall exits 0 even when stamping fails"
assert_contains "$out" "A body"  "recall output intact when stamping fails"
assert_contains "$err" "stamp failed" "stamp failure logged to stderr"
rm -rf "$woo5" "$p5"
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash skills/woostack-init/scripts/tests/test-recall.sh`
Expected: FAIL — `recall_count` is empty (no stamping yet), so the count assertions fail.

- [ ] **Step 3: Implement stamping** — insert this block in `recall.sh` immediately after the `linked_files=()` building loop (the `done < "$linked"` around line 62) and before `global_out=""`:

```bash
# --- Stamp recall telemetry on every selected note (best-effort). ---
# Cumulative recall_count + last_recalled. Failures never break recall: they
# log to stderr and recall still exits 0. Stamps matched + one-hop linked +
# global notes (each appears in exactly one set, so no double-counting).
_now="$(_woo_now)"
stamp_note() {
  local f="$1" cur next
  cur="$(field "$f" recall_count)"; cur="${cur:-0}"
  case "$cur" in (*[!0-9]*) cur=0 ;; esac
  next=$(( cur + 1 ))
  { set_field "$f" recall_count "$next" && set_field "$f" last_recalled "$_now"; } \
    || echo "recall: stamp failed $(basename "$f")" >&2
}
for f in "${matched_files[@]:-}"; do [ -n "${f:-}" ] && stamp_note "$f"; done
for f in "${linked_files[@]:-}"; do [ -n "${f:-}" ] && stamp_note "$f"; done
while IFS= read -r f; do [ -n "$f" ] && stamp_note "$f"; done < "$globals"
```

(`$globals` is the tmpfile of global note paths written during the initial scan; it still exists — the EXIT trap removes it.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash skills/woostack-init/scripts/tests/test-recall.sh`
Expected: PASS — new stamping assertions AND all pre-existing recall assertions (stdout is unchanged by stamping).

- [ ] **Step 5: Commit**

```bash
git add skills/woostack-init/scripts/recall.sh skills/woostack-init/scripts/tests/test-recall.sh
git commit -m "feat(memory): stamp recall_count/last_recalled on recalled notes"
```

---

## Task 4: Dead-note warning in doctor.sh

**Files:**
- Modify: `skills/woostack-init/scripts/doctor.sh` (insert at the end of the per-note `for` loop body, after the wikilink check, before the `done` ~line 54)
- Test: `skills/woostack-init/scripts/tests/test-doctor.sh`

- [ ] **Step 1: Write the failing tests** (append before `finish` in `test-doctor.sh`)

```bash
# --- dead-note check ---
# old + never recalled → dead warning, exit 0
dd1="$(mktemp -d)/m"; mkdir -p "$dd1"
mk_note "$dd1" old.md $'name: old\ntype: pattern\nscope: *\nupdated: 2026-01-01' 'stale body'
OUT="$(WOOSTACK_NOW=2026-06-02 bash "$DOC" "$dd1" 2>&1)"; CODE=$?
assert_contains "$OUT" "dead note" "old + zero recalls flagged as dead"
assert_exit 0 "$CODE" "dead note is a warning (exit 0)"

# old but recalled → not flagged
dd2="$(mktemp -d)/m"; mkdir -p "$dd2"
mk_note "$dd2" old.md $'name: old\ntype: pattern\nscope: *\nupdated: 2026-01-01\nrecall_count: 3' 'body'
OUT="$(WOOSTACK_NOW=2026-06-02 bash "$DOC" "$dd2" 2>&1)"
assert_not_contains "$OUT" "dead note" "a recalled note is never flagged dead"

# fresh updated → not flagged
dd3="$(mktemp -d)/m"; mkdir -p "$dd3"
mk_note "$dd3" fresh.md $'name: fresh\ntype: pattern\nscope: *\nupdated: 2026-05-30' 'body'
OUT="$(WOOSTACK_NOW=2026-06-02 bash "$DOC" "$dd3" 2>&1)"
assert_not_contains "$OUT" "dead note" "a fresh note is not flagged"

# no updated: → not aged, not flagged
dd4="$(mktemp -d)/m"; mkdir -p "$dd4"
mk_note "$dd4" noupd.md $'name: noupd\ntype: pattern\nscope: *' 'body'
OUT="$(WOOSTACK_NOW=2026-06-02 bash "$DOC" "$dd4" 2>&1)"
assert_not_contains "$OUT" "dead note" "a note without updated: is not flagged"

# WOOSTACK_DEAD_DAYS tightens the window
dd5="$(mktemp -d)/m"; mkdir -p "$dd5"
mk_note "$dd5" recent.md $'name: recent\ntype: pattern\nscope: *\nupdated: 2026-05-30' 'body'
OUT="$(WOOSTACK_NOW=2026-06-02 WOOSTACK_DEAD_DAYS=1 bash "$DOC" "$dd5" 2>&1)"
assert_contains "$OUT" "dead note" "DEAD_DAYS=1 flags a 3-day-old never-recalled note"
rm -rf "$dd1" "$dd2" "$dd3" "$dd4" "$dd5"
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash skills/woostack-init/scripts/tests/test-doctor.sh`
Expected: FAIL — no "dead note" warning emitted (and the DEAD_DAYS case fails).

- [ ] **Step 3: Implement the check** — insert at the end of the `for f in "$MEM_DIR"/*.md` loop body in `doctor.sh`, after the wikilink `while` loop and before `done`:

```bash
  # Dead-note signal: old (by updated:) AND never recalled → prune candidate.
  # Requires updated: (no age basis otherwise). Warning only.
  upd="$(field "$f" updated)"
  if [ -n "$upd" ]; then
    upd_e="$(_woo_epoch "$upd" || true)"
    if [ -n "$upd_e" ]; then
      now_e="$(_woo_epoch "$(_woo_now)")"
      rc="$(field "$f" recall_count)"; rc="${rc:-0}"
      case "$rc" in (*[!0-9]*) rc=0 ;; esac
      age=$(( ( now_e - upd_e ) / 86400 ))
      if [ "$age" -gt "${WOOSTACK_DEAD_DAYS:-90}" ] && [ "$rc" -eq 0 ]; then
        warn "$base: dead note — written ${age}d ago, never recalled (prune candidate)"
      fi
    fi
  fi
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash skills/woostack-init/scripts/tests/test-doctor.sh`
Expected: PASS (new dead-note assertions + all pre-existing doctor assertions).

- [ ] **Step 5: Commit**

```bash
git add skills/woostack-init/scripts/doctor.sh skills/woostack-init/scripts/tests/test-doctor.sh
git commit -m "feat(memory): doctor warns on dead notes (old + never recalled)"
```

---

## Task 5: Document the contract in memory.md

**Files:**
- Modify: `skills/woostack-init/references/memory.md`

- [ ] **Step 1: Add the new fields to the §3 fields table**

In the fields table (after the `source` row), add:

```markdown
| `recall_count` | no | **Tool-managed.** Cumulative count of recall runs that loaded this note, written by `recall.sh`. Never hand-edit. Absent ⇒ never recalled. |
| `last_recalled` | no | **Tool-managed.** ISO date of the most recent recall load, written by `recall.sh`. Never hand-edit. |
```

Then add a sentence under the table:

```markdown
`recall_count` and `last_recalled` are **written by tooling, not by hand** — `recall.sh` stamps them (best-effort) on every note it loads. They are the recall-telemetry signal feeding `doctor.sh`'s dead-note check (see §8).
```

- [ ] **Step 2: Document the dead-note warning + knobs in §8 (Scripts)**

Update the `doctor.sh` row in the §8 scripts table to mention the dead-note check, and add a paragraph after the table:

```markdown
`doctor.sh` also emits a **dead-note warning** (exit 0): a note whose `updated:` date is older than `WOOSTACK_DEAD_DAYS` (default 90) days **and** whose `recall_count` is absent or 0 is flagged as a prune candidate. Notes without an `updated:` field have no age basis and are skipped. `WOOSTACK_NOW` (default `date +%F`) overrides "today" for deterministic runs and tests.

`recall.sh` stamps `recall_count`/`last_recalled` on every selected note (matched + one-hop linked + global) as a best-effort side effect: a write failure (e.g. read-only checkout) logs `recall: stamp failed <note>` to stderr but never changes recall's output or exit status. Ephemeral CI clones therefore simply do not accrue telemetry; persistent checkouts do.
```

- [ ] **Step 3: Update the §8 lib.sh helper list**

Find the sentence listing lib.sh helpers (`field()`, `note_body()`, `first_body_line()`) and extend it to include `set_field()` (atomic frontmatter mutation) and the date helpers `_woo_now()`/`_woo_epoch()`.

- [ ] **Step 4: Verify cross-links + render**

Run: `grep -n "recall_count\|last_recalled\|WOOSTACK_DEAD_DAYS\|set_field" skills/woostack-init/references/memory.md`
Expected: matches in §3 and §8. Confirm no broken section references were introduced.

- [ ] **Step 5: Commit**

```bash
git add skills/woostack-init/references/memory.md
git commit -m "docs(memory): document recall telemetry fields + doctor dead-note check"
```

---

## Task 6: Full-suite verification

**Files:** none (verification only)

- [ ] **Step 1: Run the whole test suite**

Run: `bash skills/woostack-init/scripts/tests/run-tests.sh`
Expected: every `test-*.sh` reports `N passed, 0 failed`; overall exit 0.

- [ ] **Step 2: Smoke-test doctor on the repo's own example notes (if any) and a hand-built fixture**

Run:
```bash
tmp="$(mktemp -d)/m"; mkdir -p "$tmp"
printf -- '---\nname: z\ntype: pattern\nscope: *\nupdated: 2025-01-01\n---\nbody\n' > "$tmp/z.md"
WOOSTACK_NOW=2026-06-02 bash skills/woostack-init/scripts/doctor.sh "$tmp"
```
Expected: stderr shows `::warning:: z.md: dead note — written ...d ago, never recalled (prune candidate)` and exit 0.

- [ ] **Step 3: Confirm clean tree + branch state**

Run: `git status --short && git log --oneline -6`
Expected: clean tree; commits for tasks 1–5 present on `feat/memory-recall-telemetry`.

---

## Self-Review (completed during planning)

- **Spec coverage:** §4 decisions → Tasks 1–4; `_woo_epoch` determinism → Task 1; `set_field` malformed-note safety → Task 2; stamp-all-selected + best-effort → Task 3; dead-note rule + 90d knob + updated-only → Task 4; §3/§5/§8 docs → Task 5. All covered.
- **Placeholder scan:** no TBD/TODO; every code step shows complete code.
- **Type/name consistency:** `set_field`, `_woo_now`, `_woo_epoch`, `stamp_note`, `WOOSTACK_NOW`, `WOOSTACK_DEAD_DAYS` used identically across tasks. recall stamps via the same helpers doctor reads.
- **Deferred (follow-up issues at PR time, per spec §8):** churn-guard for unrelated-branch reviews; distillation stamping `updated:`; the recalled-but-never-acted-on signal.
