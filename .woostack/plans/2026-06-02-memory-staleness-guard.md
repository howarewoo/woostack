---
type: plan
source: .woostack/specs/2026-06-02-memory-staleness-guard.md
status: done
branch: memory-staleness-guard
---

**Source:** [[specs/2026-06-02-memory-staleness-guard]]


# Memory Staleness Guard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Warn when scoped memory notes point `source:` at missing `.woostack/specs/` or `.woostack/plans/` provenance files.

**Architecture:** Extend `doctor.sh` with one warning-only source check inside the existing per-note lint loop. Keep source validation constrained to authored woostack spec/plan paths so symbolic provenance such as `pr-165` remains valid.

**Tech Stack:** Bash, existing woostack-init shell test harness, Markdown memory contract.

---

### Task 1: Add Failing Stale-Provenance Tests

**Files:**
- Modify: `skills/woostack-init/scripts/tests/test-doctor.sh`

- [x] **Step 1: Add provenance fixtures to the clean repo setup**

In `skills/woostack-init/scripts/tests/test-doctor.sh`, after the stale scope test and before the unresolved wikilink test, add:

```bash
# missing .woostack source → warn, exit 0
mk_note "$md" stale-source-spec.md $'name: stale-source-spec\ntype: pattern\nscope: packages/api/**\nsource: .woostack/specs/missing.md' 'body'
pushd "$repo" >/dev/null; run_doctor ".woostack/memory"; popd >/dev/null
assert_contains "$OUT" "source '.woostack/specs/missing.md' is missing" "missing spec source warned"
assert_exit 0 "$CODE" "missing spec source is a warning"

mk_note "$md" stale-source-plan.md $'name: stale-source-plan\ntype: pattern\nscope: packages/api/**\nsource: .woostack/plans/missing.md' 'body'
pushd "$repo" >/dev/null; run_doctor ".woostack/memory"; popd >/dev/null
assert_contains "$OUT" "source '.woostack/plans/missing.md' is missing" "missing plan source warned"
assert_exit 0 "$CODE" "missing plan source is a warning"

mkdir -p "$repo/.woostack/specs" "$repo/.woostack/plans"
touch "$repo/.woostack/specs/existing.md" "$repo/.woostack/plans/existing.md"
mk_note "$md" live-source-spec.md $'name: live-source-spec\ntype: pattern\nscope: packages/api/**\nsource: .woostack/specs/existing.md' 'body'
mk_note "$md" live-source-plan.md $'name: live-source-plan\ntype: pattern\nscope: packages/api/**\nsource: .woostack/plans/existing.md' 'body'
mk_note "$md" pr-source.md $'name: pr-source\ntype: convention\nscope: packages/api/**\nsource: pr-165' 'body'
pushd "$repo" >/dev/null; run_doctor ".woostack/memory"; popd >/dev/null
assert_not_contains "$OUT" "live-source-spec" "existing spec source is not warned"
assert_not_contains "$OUT" "live-source-plan" "existing plan source is not warned"
assert_not_contains "$OUT" "pr-source" "PR source is not treated as a filesystem path"
```

- [x] **Step 2: Run the doctor tests and verify the new expectations fail**

Run:

```bash
bash skills/woostack-init/scripts/tests/test-doctor.sh
```

Expected: the test exits non-zero because the output does not contain the missing-source warnings yet.

### Task 2: Implement Source Provenance Warning

**Files:**
- Modify: `skills/woostack-init/scripts/doctor.sh`
- Test: `skills/woostack-init/scripts/tests/test-doctor.sh`

- [x] **Step 1: Add the source check to `doctor.sh`**

In `skills/woostack-init/scripts/doctor.sh`, after the existing stale-scope check and before wikilink validation, add:

```bash
  source_path="$(field "$f" source)"
  case "$source_path" in
    .woostack/specs/*|.woostack/plans/*)
      [ -f "$source_path" ] || warn "$base: source '$source_path' is missing (stale provenance)"
      ;;
  esac
```

- [x] **Step 2: Run the doctor tests and verify they pass**

Run:

```bash
bash skills/woostack-init/scripts/tests/test-doctor.sh
```

Expected: all assertions pass, including stale provenance warnings.

- [x] **Step 3: Run the full woostack-init script test suite**

Run:

```bash
bash skills/woostack-init/scripts/tests/run-tests.sh
```

Expected: every woostack-init script test passes.

### Task 3: Document Doctor Staleness Checks

**Files:**
- Modify: `skills/woostack-init/references/memory.md`

- [x] **Step 1: Update the doctor script summary**

In `skills/woostack-init/references/memory.md` §8, change the `doctor.sh` row from:

```markdown
| `doctor.sh` | `bash doctor.sh [<memdir>]` — lints the memory directory; warnings exit 0, errors exit 1. Also emits the dead-note warning described below. |
```

to:

```markdown
| `doctor.sh` | `bash doctor.sh [<memdir>]` — lints the memory directory; warnings exit 0, errors exit 1. Also emits the staleness warnings described below. |
```

- [x] **Step 2: Replace the prose heading with complete warning coverage**

Replace the paragraph headed `**Recall telemetry & the dead-note check.**` with:

```markdown
**Staleness warnings.** `doctor.sh` emits warning-only findings for cheap structural staleness signals:

- **Orphaned scope:** a note with a non-global `scope:` whose globs match no tracked files in `git ls-files` is flagged as stale. This catches notes scoped to paths that were deleted or moved.
- **Stale provenance:** a note whose `source:` starts with `.woostack/specs/` or `.woostack/plans/` is expected to point at an authored spec or plan in the current repo. If that file is missing, the note is flagged for review. Other provenance forms, such as `source: pr-165`, are not treated as filesystem paths.
- **Dead note:** `recall.sh` stamps `recall_count`/`last_recalled` (§3) on every selected note — matched + one-hop linked + global — as a best-effort side effect: a write failure (e.g. a read-only checkout) logs `recall: stamp failed <note>` to stderr but never changes recall's output or exit status. Ephemeral CI clones therefore simply do not accrue telemetry; persistent checkouts do. `doctor.sh` turns that signal into a warning when a note's `updated:` date is older than `WOOSTACK_DEAD_DAYS` (default 90) days and its `recall_count` is absent or 0. Notes without an `updated:` field have no age basis and are skipped. `WOOSTACK_NOW` (default `date +%F`) overrides "today" for deterministic runs and tests.

`doctor.sh` also warns on unresolved body `[[wikilinks]]`; those are graph integrity warnings rather than staleness signals.
```

- [x] **Step 3: Check docs wording and cross-references**

Run:

```bash
rg -n "doctor.sh|stale provenance|orphaned scope|dead note|unresolved" skills/woostack-init/references/memory.md
```

Expected: §8 documents orphaned scope, stale provenance, dead notes, and unresolved wikilinks without duplicating details elsewhere.

### Task 4: Final Verification

**Files:**
- Verify: `skills/woostack-init/scripts/doctor.sh`
- Verify: `skills/woostack-init/scripts/tests/test-doctor.sh`
- Verify: `skills/woostack-init/references/memory.md`

- [x] **Step 1: Run full tests**

Run:

```bash
bash skills/woostack-init/scripts/tests/run-tests.sh
```

Expected: all tests pass.

- [x] **Step 2: Inspect the diff**

Run:

```bash
git diff -- skills/woostack-init/scripts/doctor.sh skills/woostack-init/scripts/tests/test-doctor.sh skills/woostack-init/references/memory.md .woostack/specs/2026-06-02-memory-staleness-guard.md .woostack/plans/2026-06-02-memory-staleness-guard.md
```

Expected: the diff is limited to the stale-provenance check, its tests, the memory contract update, and the woostack spec/plan artifacts.

- [x] **Step 3: Commit the increment**

Run:

```bash
gt modify -a -m "Add memory stale provenance guard"
```

Expected: Graphite records the branch changes without touching `main`.
