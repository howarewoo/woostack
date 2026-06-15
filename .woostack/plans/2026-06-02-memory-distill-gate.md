---
name: memory-distill-gate-plan
type: plan
date: 2026-06-02
branch: feature/memory-distill-gate
spec: .woostack/specs/2026-06-02-memory-distill-gate.md
source: .woostack/specs/2026-06-02-memory-distill-gate.md
status: done
---

**Source:** [[specs/2026-06-02-memory-distill-gate]]


# Memory Distillation Gate + updated: Coverage — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a reject-by-default distillation gate (prose) backed by three warning-only `doctor.sh` checks, and guarantee distilled notes carry `updated:` so dead-note detection has full coverage. Closes #167 + #161.

**Architecture:** Two layers. (1) Prose gate in `memory.md` §7 the distill step applies at write time. (2) `doctor.sh` backstop — three new per-note warnings (missing `source:`, non-glob `scope:` with review-provenance exemption, missing `updated:`) that catch escapes. All warnings exit 0; nothing hard-blocks. SKILL.md step 7 gets a terse pointer to §7, not a restatement.

**Tech Stack:** Bash (`doctor.sh` + the `tests/` fixture harness using `assert.sh`/`mk_note`), Markdown contract docs.

---

## File structure

| File | Responsibility | Change |
|---|---|---|
| `skills/woostack-init/scripts/doctor.sh` | Memory-store linter | Add 3 warning checks in the per-note loop |
| `skills/woostack-init/scripts/tests/test-doctor.sh` | doctor fixture tests | Add tests for the 3 checks; add `updated:` to 3 existing fixtures that the missing-`updated:` check would otherwise flag |
| `skills/woostack-init/references/memory.md` | Memory contract (canonical) | §7 reject-by-default gate; §8 document the 3 new warnings |
| `skills/woostack-build/SKILL.md` | Build-loop skill | Step 7 — terse pointer to §7 gate + `updated:` stamp |

**Regression note (verified against current `test-doctor.sh`):** only the missing-`updated:` check breaks existing assertions — fixtures `live-source-spec.md`, `live-source-plan.md`, `pr-source.md` have `source:` but no `updated:`, so the new warning text contains their names and trips `assert_not_contains` (lines ~42-44). The missing-`source:` and non-glob checks break no existing assertion. Task 3 fixes those three fixtures.

Run the suite anytime with: `bash skills/woostack-init/scripts/tests/test-doctor.sh`

---

## Task 1: doctor.sh — missing `source:` warning

**Files:**
- Modify: `skills/woostack-init/scripts/doctor.sh` (per-note loop, after the existing `source_path` / stale-provenance block)
- Test: `skills/woostack-init/scripts/tests/test-doctor.sh`

- [x] **Step 1: Write the failing test**

Add after the existing stale-provenance assertions (after the `pr-source` block, ~line 44), still inside the `$md`/`$repo` setup:

```bash
# missing source: → warn, exit 0
mk_note "$md" no-source.md $'name: no-source\ntype: pattern\nscope: packages/api/**\nupdated: 2026-06-02' 'body'
pushd "$repo" >/dev/null; run_doctor ".woostack/memory"; popd >/dev/null
assert_contains "$OUT" "no-source: missing source:" "note without source: is warned"
assert_exit 0 "$CODE" "missing source: is a warning"
```

- [x] **Step 2: Run test to verify it fails**

Run: `bash skills/woostack-init/scripts/tests/test-doctor.sh`
Expected: FAIL — `[...] does not contain [no-source: missing source:]` (check not implemented yet).

- [x] **Step 3: Write minimal implementation**

In `doctor.sh`, the `source_path` variable is already computed for the stale-provenance check. Immediately after that `case` block (the one matching `.woostack/specs/*|.woostack/plans/*`), add:

```bash
  [ -z "$source_path" ] && warn "$base: missing source: (provenance required)"
```

- [x] **Step 4: Run test to verify it passes**

Run: `bash skills/woostack-init/scripts/tests/test-doctor.sh`
Expected: PASS — new assertions green. Existing assertions still green (source-less notes `ok`/`stale`/`link` are only checked via exit code or unrelated substrings).

- [x] **Step 5: Commit**

```bash
git add skills/woostack-init/scripts/doctor.sh skills/woostack-init/scripts/tests/test-doctor.sh
git commit -m "feat(doctor): warn on memory notes missing source: (#161)"
```

---

## Task 2: doctor.sh — non-glob `scope:` warning (review-provenance exempt)

**Files:**
- Modify: `skills/woostack-init/scripts/doctor.sh` (per-note loop)
- Test: `skills/woostack-init/scripts/tests/test-doctor.sh`

- [x] **Step 1: Write the failing tests**

Add after the Task 1 block (inside the `$md`/`$repo` setup so notes have `source:`+`updated:` to isolate the non-glob signal):

```bash
# non-glob scope (single literal path), distill-origin → warn
mk_note "$md" nonglob.md $'name: nonglob\ntype: pattern\nscope: packages/api/handler.ts\nupdated: 2026-06-02\nsource: .woostack/specs/existing.md' 'body'
pushd "$repo" >/dev/null; run_doctor ".woostack/memory"; popd >/dev/null
assert_contains "$OUT" "nonglob: non-glob scope" "single literal scope warned as possible trivia"
assert_exit 0 "$CODE" "non-glob scope is a warning"

# all-literal multi-scope (no * anywhere) → warn
mk_note "$md" multilit.md $'name: multilit\ntype: pattern\nscope: a/b.ts, c/d.ts\nupdated: 2026-06-02\nsource: .woostack/specs/existing.md' 'body'
pushd "$repo" >/dev/null; run_doctor ".woostack/memory"; popd >/dev/null
assert_contains "$OUT" "multilit: non-glob scope" "all-literal multi-scope warned"

# globbed scope → no warning
mk_note "$md" globbed.md $'name: globbed\ntype: pattern\nscope: packages/api/**\nupdated: 2026-06-02\nsource: .woostack/specs/existing.md' 'body'
pushd "$repo" >/dev/null; run_doctor ".woostack/memory"; popd >/dev/null
assert_not_contains "$OUT" "globbed: non-glob scope" "a globbed scope is not flagged"

# global scope (*) → no warning
mk_note "$md" globalscope.md $'name: globalscope\ntype: pattern\nscope: *\nupdated: 2026-06-02\nsource: .woostack/specs/existing.md' 'body'
pushd "$repo" >/dev/null; run_doctor ".woostack/memory"; popd >/dev/null
assert_not_contains "$OUT" "globalscope: non-glob scope" "global scope is exempt"

# review-provenance (pr-*) with literal scope → exempt
mk_note "$md" review-pr.md $'name: review-pr\ntype: convention\nscope: packages/api/handler.ts\nupdated: 2026-06-02\nsource: pr-42' 'body'
pushd "$repo" >/dev/null; run_doctor ".woostack/memory"; popd >/dev/null
assert_not_contains "$OUT" "review-pr: non-glob scope" "review-provenance note is exempt from non-glob warning"

# review-provenance (address-comments) with literal scope → exempt
mk_note "$md" review-ac.md $'name: review-ac\ntype: convention\nscope: packages/api/handler.ts\nupdated: 2026-06-02\nsource: address-comments' 'body'
pushd "$repo" >/dev/null; run_doctor ".woostack/memory"; popd >/dev/null
assert_not_contains "$OUT" "review-ac: non-glob scope" "address-comments note is exempt"
```

Note: `nonglob.md`/`multilit.md` use `scope` values that won't match tracked files, so the existing stale-scope warning also fires — that's fine and independent; we assert only on the `non-glob scope` substring.

- [x] **Step 2: Run tests to verify they fail**

Run: `bash skills/woostack-init/scripts/tests/test-doctor.sh`
Expected: FAIL on the two `assert_contains "... non-glob scope"` (check not implemented).

- [x] **Step 3: Write minimal implementation**

In `doctor.sh`, after the missing-`source:` line from Task 1 (so `source_path` and `scope` are both in scope), add:

```bash
  # Non-glob scope = trivia signal. Exempt global (*) and review-provenance notes
  # (review records deliberately scope narrowly to suppress an accepted finding).
  case "$source_path" in pr-*|address-comments) is_review=1 ;; *) is_review= ;; esac
  if [ -n "$scope" ] && [ "$scope" != "*" ] && [ -z "$is_review" ] && [ "${scope#*\*}" = "$scope" ]; then
    warn "$base: non-glob scope '$scope' (possible trivia — prefer a glob)"
  fi
```

`${scope#*\*}` strips the shortest prefix ending in a literal `*`; it equals `$scope` only when `scope` contains no `*` at all.

- [x] **Step 4: Run tests to verify they pass**

Run: `bash skills/woostack-init/scripts/tests/test-doctor.sh`
Expected: PASS — all Task 2 assertions green; existing assertions still green (no existing fixture has a non-glob, non-review scope).

- [x] **Step 5: Commit**

```bash
git add skills/woostack-init/scripts/doctor.sh skills/woostack-init/scripts/tests/test-doctor.sh
git commit -m "feat(doctor): warn on non-glob memory scope, exempt review notes (#161)"
```

---

## Task 3: doctor.sh — missing `updated:` warning (+ fix existing fixtures)

**Files:**
- Modify: `skills/woostack-init/scripts/doctor.sh` (dead-note block)
- Modify: `skills/woostack-init/scripts/tests/test-doctor.sh` (3 existing fixtures + new tests)

- [x] **Step 1: Fix the 3 existing fixtures that the new check would flag**

In `test-doctor.sh`, add `\nupdated: 2026-06-02` to the frontmatter of these three `mk_note` calls so the missing-`updated:` warning does not trip their `assert_not_contains`:

```bash
mk_note "$md" live-source-spec.md $'name: live-source-spec\ntype: pattern\nscope: packages/api/**\nsource: .woostack/specs/existing.md\nupdated: 2026-06-02' 'body'
mk_note "$md" live-source-plan.md $'name: live-source-plan\ntype: pattern\nscope: packages/api/**\nsource: .woostack/plans/existing.md\nupdated: 2026-06-02' 'body'
mk_note "$md" pr-source.md $'name: pr-source\ntype: convention\nscope: packages/api/**\nsource: pr-165\nupdated: 2026-06-02' 'body'
```

- [x] **Step 2: Write the failing test**

Add a dedicated missing-`updated:` test (use its own temp dir to isolate, mirroring the dead-note block style):

```bash
# missing updated: → warn (cannot be aged), exit 0
mu="$(mktemp -d)/m"; mkdir -p "$mu"
mk_note "$mu" noupd2.md $'name: noupd2\ntype: pattern\nscope: *\nsource: pr-1' 'body'
OUT="$(bash "$DOC" "$mu" 2>&1)"; CODE=$?
assert_contains "$OUT" "noupd2: missing updated:" "note without updated: is warned"
assert_exit 0 "$CODE" "missing updated: is a warning"
assert_not_contains "$OUT" "dead note" "missing updated: does not also emit a dead-note signal"
rm -rf "$mu"
```

- [x] **Step 3: Run test to verify it fails**

Run: `bash skills/woostack-init/scripts/tests/test-doctor.sh`
Expected: FAIL — `[...] does not contain [noupd2: missing updated:]`.

- [x] **Step 4: Write minimal implementation**

In `doctor.sh`, the dead-note block is `upd="$(field "$f" updated)"; if [ -n "$upd" ]; then ... fi`. Add an `else` branch so a note with no `updated:` is warned instead of silently skipped:

```bash
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
  else
    warn "$base: missing updated: (cannot be aged — add updated:)"
  fi
```

- [x] **Step 5: Run the full suite to verify pass + no regressions**

Run: `bash skills/woostack-init/scripts/tests/test-doctor.sh`
Expected: PASS — new assertion green; the previously-fixed fixtures (Step 1) keep lines ~42-44 green; the existing `dd4 noupd` dead-note assertion still holds (it checks `assert_not_contains "dead note"`, and our new warning text differs).

- [x] **Step 6: Run the whole init test runner as a final guard**

Run: `bash skills/woostack-init/scripts/tests/run-tests.sh`
Expected: every `test-*.sh` reports `0 failed`, runner exits 0.

- [x] **Step 7: Commit**

```bash
git add skills/woostack-init/scripts/doctor.sh skills/woostack-init/scripts/tests/test-doctor.sh
git commit -m "feat(doctor): warn on memory notes missing updated: (#167)"
```

---

## Task 4: memory.md — reject-by-default gate (§7) + new warnings doc (§8)

**Files:**
- Modify: `skills/woostack-init/references/memory.md` (§7 Distillation, §8 Scripts staleness warnings)

- [x] **Step 1: Add the reject-by-default gate to §7**

In `## 7. Distillation (write path)`, after the existing bullet list (`type` / `scope` / `source` / body) and before the "Distillation **dedupes against `MEMORY.md` first**" paragraph, insert:

```markdown
**Reject-by-default gate.** Before writing any note, it must pass every check — fewer, denser notes beat many thin ones:

1. **Cross-feature test** — if `scope:` is a single literal file/path (no glob), reject as trivia. Scope must be a glob that could plausibly fire on a *different* feature's files.
2. **Provenance required** — no `source:`, no note. Every durable learning traces back to a spec or plan.
3. **Dedupe (strengthened)** — exact-name match against `MEMORY.md` **plus** a fuzzy compare of the candidate `hook:` against existing hooks to catch near-duplicates phrased differently; update the existing note rather than adding. (This compare is agent judgment; store-level collision surfacing is tracked separately in conflict detection.)
4. **Stamp `updated:`** — every created or updated note gets today's ISO date, so the dead-note check (§8) can age it.

`doctor.sh` backstops items 1, 2, and 4 with warning-only checks (§8) — they catch escapes but never hard-block.
```

- [x] **Step 2: Document the 3 new warnings in §8**

In `## 8. Scripts`, in the **Staleness warnings** list (after the **Dead note** bullet), add:

```markdown
- **Missing provenance:** a note with no `source:` is flagged — the distillation gate (§7) requires provenance on every note.
- **Non-glob scope:** a note whose `scope:` is non-global and contains no `*` glob (a single literal path, or an all-literal comma list) is flagged as possible trivia. Notes with global scope (`*` or absent) and review-recorded notes (`source:` of `pr-<n>` or `address-comments`, which deliberately scope narrowly) are exempt.
- **Missing age basis:** a note with no `updated:` field is flagged — it cannot be aged by the dead-note check above. (Both write paths stamp `updated:`; a note without it is anomalous.)
```

- [x] **Step 3: Verify cross-links + render**

Run: `grep -n "Reject-by-default\|Non-glob scope\|Missing provenance\|Missing age basis" skills/woostack-init/references/memory.md`
Expected: all four anchors present. Eyeball that §7 and §8 read cleanly and the §8 additions sit under the existing staleness list.

- [x] **Step 4: Commit**

```bash
git add skills/woostack-init/references/memory.md
git commit -m "docs(memory): document distillation gate + doctor backstop warnings (#161, #167)"
```

---

## Task 5: woostack-build SKILL.md — step 7 pointer

**Files:**
- Modify: `skills/woostack-build/SKILL.md` (Procedure step 7, "Distill memory")

- [x] **Step 1: Add the gate pointer to step 7**

In step 7, after the existing sentence describing dedupe-first and before "Then run `woostack-init`'s `build-index.sh` and `doctor.sh`", insert a terse pointer (do NOT restate the four criteria — `memory.md` §7 is canonical, per the cross-link-don't-duplicate rule):

```markdown
   Apply the **reject-by-default distillation gate** (see the [memory contract](../woostack-init/references/memory.md) §7): single-file scope, missing `source:`, or a near-duplicate `hook:` ⇒ do not write the note; and **stamp `updated:`** (today's ISO date) on every note you create or update.
```

- [x] **Step 2: Verify the cross-link resolves**

Run: `ls skills/woostack-init/references/memory.md && grep -n "reject-by-default distillation gate" skills/woostack-build/SKILL.md`
Expected: file exists; the new pointer line is present. Confirm the relative path `../woostack-init/references/memory.md` is correct from `skills/woostack-build/SKILL.md` (sibling `skills/` subdir).

- [x] **Step 3: Commit**

```bash
git add skills/woostack-build/SKILL.md
git commit -m "docs(build): point distill step at the reject-by-default gate (#161, #167)"
```

---

## Self-review (done while writing)

- **Spec coverage:** §7 stamp (#167) → Task 3 + Task 4/5 prose. §161 cross-feature/provenance/dedupe → Task 4 §7 gate + doctor Tasks 1-2. §8 doc → Task 4. SKILL.md pointer → Task 5. doctor backstop (3 warnings) → Tasks 1-3. Review-provenance exemption → Task 2. updated: coverage warning → Task 3. All covered.
- **Non-goals respected:** no fuzzy-dedupe script; no error-severity gates (all `warn`); no `recall.sh`/`build-index.sh`/`memory-record.sh` changes; #166/#168 untouched.
- **Type/string consistency:** warning substrings asserted in tests match the `warn` strings in the implementation exactly (`missing source:`, `non-glob scope`, `missing updated:`).
- **No placeholders:** every code + command step is concrete.
```
