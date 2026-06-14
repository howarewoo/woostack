---
type: plan
source: .woostack/specs/2026-06-02-memory-recall.md
status: done
branch: feat/woostack-memory-recall
---

**Source:** .woostack/specs/2026-06-02-memory-recall.md


# Memory recall + review scope-routing (Increment B) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Ship `recall.sh` (the recall orchestration deferred from A) and wire it into the review pipeline so workers receive scope-matched memory for the PR's changed files instead of the whole flat dump.

**Architecture:** New `skills/woostack-init/scripts/recall.sh` reuses `scope-match.sh` + `lib.sh`. `prefetch.sh`'s memory block calls it; output replaces the raw flat copy but always includes the flat file as the cap-protected global shard. Read-path only.

**Tech Stack:** Bash + coreutils. Tests extend the woostack-init harness.

**Source of truth:** `.woostack/specs/2026-06-02-memory-recall.md`. Stacks on `feat/woostack-init`.

---

## File Structure

| File | Responsibility |
|---|---|
| `skills/woostack-init/scripts/recall.sh` | Compose per-PR memory: scoped + one-hop + cap-protected global. |
| `skills/woostack-init/scripts/tests/test-recall.sh` | recall.sh unit tests. |
| `skills/woostack-review/scripts/prefetch.sh` | Memory block (~679-697) calls recall.sh; fallback when absent. |
| `skills/woostack-review/prompts/_header.md` | Note: memory is now scope-routed context. |
| `skills/woostack-review/SKILL.md` | Cross-PR Memory section: mention recall.sh composition. |

---

## Task 1: `recall.sh`

**Files:**
- Create: `skills/woostack-init/scripts/recall.sh`
- Test: `skills/woostack-init/scripts/tests/test-recall.sh`

- [x] **Step 1: Write the failing test**

Create `skills/woostack-init/scripts/tests/test-recall.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DIR/tests/assert.sh"
RECALL="$DIR/recall.sh"

# Build a fixture .woostack with flat file + scoped notes.
woo="$(mktemp -d)"; md="$woo/memory"; mkdir -p "$md"
printf -- '- accepted: do not flag X\n' > "$woo/memory.md"
mk_note "$md" api.md      $'name: api\ntype: pattern\nscope: packages/api/**' 'API note body'
mk_note "$md" web.md      $'name: web\ntype: pattern\nscope: apps/web/**' 'WEB note [[api]] body'
mk_note "$md" glob.md     $'name: glob\ntype: convention\nscope: *' 'GLOBAL note body'
paths="$(mktemp)"; printf 'packages/api/x.ts\n' > "$paths"

out="$(bash "$RECALL" "$woo" "$paths")"
assert_contains "$out" "API note body" "matched scoped note included"
assert_not_contains "$out" "WEB note" "unmatched note excluded"
assert_contains "$out" "GLOBAL note body" "global (scope:*) note always included"
assert_contains "$out" "do not flag X" "flat global shard always included"

# one-hop: changing apps/web pulls web.md, which links [[api]] -> api.md too
printf 'apps/web/y.tsx\n' > "$paths"
out="$(bash "$RECALL" "$woo" "$paths")"
assert_contains "$out" "WEB note" "web matched"
assert_contains "$out" "API note body" "one-hop [[api]] pulled in"

# two hops do NOT chain: make api link [[deep]]; deep must NOT appear via web->api->deep
mk_note "$md" deep.md $'name: deep\ntype: pattern\nscope: zzz/**' 'DEEP note body'
mk_note "$md" api.md  $'name: api\ntype: pattern\nscope: packages/api/**' 'API note [[deep]] body'
out="$(bash "$RECALL" "$woo" "$paths")"
assert_not_contains "$out" "DEEP note body" "two-hop not chained"

# only-flat-file repo degrades to flat content
woo2="$(mktemp -d)"; printf -- '- only flat here\n' > "$woo2/memory.md"
out="$(bash "$RECALL" "$woo2" "$paths")"
assert_contains "$out" "only flat here" "only-flat repo: flat content emitted"

# neither source -> empty, exit 0
woo3="$(mktemp -d)"
set +e; out="$(bash "$RECALL" "$woo3" "$paths")"; code=$?; set -e
assert_eq "$out" "" "no memory -> empty output"
assert_exit 0 "$code" "no memory -> exit 0"

# cap protects global: tiny cap still keeps flat shard, drops scoped
printf 'packages/api/x.ts\n' > "$paths"
out="$(RECALL_CAP=40 bash "$RECALL" "$woo" "$paths" 2>/dev/null)"
assert_contains "$out" "do not flag X" "global protected under tiny cap"

rm -rf "$woo" "$woo2" "$woo3"
finish
```

- [x] **Step 2: Run, confirm FAIL** (recall.sh missing).

Run: `bash skills/woostack-init/scripts/tests/test-recall.sh; echo exit=$?` → FAIL.

- [x] **Step 3: Write `recall.sh`**

Create `skills/woostack-init/scripts/recall.sh`:

```bash
#!/usr/bin/env bash
# recall.sh <woostack_dir> <paths_file> — compose per-PR memory context.
# stdout: ## Scoped memory + ## Linked notes + ## Global memory.
# The global shard (flat memory.md + no-scope/`*` notes) is ALWAYS included and
# never dropped by RECALL_CAP (bytes, default 102400). Scoped/linked notes fill
# the remaining budget; lowest match-count dropped first (logged to stderr).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib.sh"
SCOPE_MATCH="$HERE/scope-match.sh"

WOO="${1:?woostack_dir required}"; PATHS_FILE="${2:?paths_file required}"
CAP="${RECALL_CAP:-102400}"
MEM_DIR="$WOO/memory"; FLAT="$WOO/memory.md"
paths="$(cat "$PATHS_FILE" 2>/dev/null || true)"

is_global() { local s; s="$(printf '%s' "$1" | tr -d '[:space:]')"; [ -z "$s" ] || [ "$s" = '*' ]; }
render() { local nm; nm="$(field "$1" name)"; printf '### %s\n%s\n' "${nm:-$(basename "$1" .md)}" "$(note_body "$1")"; }

declare -A inc
matched="$(mktemp)"; linked="$(mktemp)"; globals="$(mktemp)"
trap 'rm -f "$matched" "$linked" "$globals"' EXIT

if [ -d "$MEM_DIR" ]; then
  shopt -s nullglob
  for f in "$MEM_DIR"/*.md; do
    b="$(basename "$f")"; [ "$b" = "MEMORY.md" ] && continue
    scope="$(field "$f" scope || true)"
    if is_global "$scope"; then printf '%s\n' "$f" >> "$globals"; inc[$b]=1; continue; fi
    [ -z "$paths" ] && continue
    cnt="$(printf '%s\n' "$paths" | bash "$SCOPE_MATCH" "$scope" 2>/dev/null | grep -c . || true)"
    [ "${cnt:-0}" -gt 0 ] && printf '%s\t%s\n' "$cnt" "$f" >> "$matched"
  done
fi

mapfile -t matched_files < <(sort -t"$(printf '\t')" -k1,1nr "$matched" | cut -f2-)
for f in "${matched_files[@]:-}"; do [ -n "${f:-}" ] && inc[$(basename "$f")]=1; done
for f in "${matched_files[@]:-}"; do
  [ -n "${f:-}" ] || continue
  while IFS= read -r lk; do
    [ -z "$lk" ] && continue
    lf="$MEM_DIR/$lk.md"
    if [ -f "$lf" ] && [ -z "${inc[$lk.md]:-}" ]; then inc[$lk.md]=1; printf '%s\n' "$lf" >> "$linked"; fi
  done < <(grep -oE '\[\[[^]]+\]\]' "$f" 2>/dev/null | sed 's/\[\[//;s/\]\]//' | sort -u)
done
mapfile -t linked_files < <(cat "$linked")

global_out=""
[ -f "$FLAT" ] && global_out="$(cat "$FLAT")"
while IFS= read -r f; do
  [ -n "$f" ] || continue
  if [ -n "$global_out" ]; then global_out+=$'\n\n'; fi
  global_out+="$(render "$f")"
done < "$globals"

scoped_out=""; linked_out=""
gbytes=${#global_out}
budget=$(( CAP - gbytes ))
if [ "$budget" -le 0 ] && [ -n "$global_out" ]; then
  global_out="$(printf '%s' "$global_out" | tail -c "$CAP")"
  echo "recall: global shard exceeds cap; tail-capped, scoped notes dropped" >&2
else
  for f in "${matched_files[@]:-}"; do
    [ -n "${f:-}" ] || continue
    chunk="$(render "$f")"$'\n\n'
    if [ $(( ${#scoped_out} + ${#chunk} )) -le "$budget" ]; then scoped_out+="$chunk"
    else echo "recall: dropped $(basename "$f") (cap)" >&2; fi
  done
  rem=$(( budget - ${#scoped_out} ))
  for f in "${linked_files[@]:-}"; do
    [ -n "${f:-}" ] || continue
    chunk="$(render "$f")"$'\n\n'
    if [ $(( ${#linked_out} + ${#chunk} )) -le "$rem" ]; then linked_out+="$chunk"
    else echo "recall: dropped linked $(basename "$f") (cap)" >&2; fi
  done
fi

[ -n "$scoped_out" ] && printf '## Scoped memory (matched this PR)\n\n%s' "$scoped_out"
[ -n "$linked_out" ] && printf '## Linked notes\n\n%s' "$linked_out"
[ -n "$global_out" ] && printf '## Global memory\n\n%s\n' "$global_out"
exit 0
```

- [x] **Step 4: Run, confirm all pass, full suite green.**

Run: `bash skills/woostack-init/scripts/tests/test-recall.sh; echo exit=$?` then `bash skills/woostack-init/scripts/tests/run-tests.sh`.
Expected: recall test all pass; whole suite exit 0. Run shellcheck; info-level OK.

- [x] **Step 5: Commit** — `feat(woostack-init): recall.sh — scope-routed memory composition + tests`

---

## Task 2: Wire recall.sh into prefetch.sh

**Files:**
- Modify: `skills/woostack-review/scripts/prefetch.sh` (memory block ~679-697)

- [x] **Step 1: Read the current block.** Read `skills/woostack-review/scripts/prefetch.sh` lines 679-700 (the `MEMORY_SRC`/`MEMORY_OUT` block). Note `SCRIPT_DIR` is defined at line 251 as `$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)`.

- [x] **Step 2: Replace the block** with recall-first, flat-copy fallback. New block:

```bash
# Cross-PR memory — composed per-PR via recall.sh when a scope-routed store
# (.woostack/memory/) exists: scope-matched notes + one-hop links + the
# cap-protected global shard (flat memory.md). Falls back to a raw flat copy
# when recall.sh is unavailable (e.g. single-skill install). Missing both => no
# memory context (normal for fresh repos).
WOOSTACK_DIR="${GITHUB_WORKSPACE:-$(pwd)}/.woostack"
MEMORY_SRC="$WOOSTACK_DIR/memory.md"
MEMORY_OUT="$OUTDIR/memory.md"
RECALL="$SCRIPT_DIR/../../woostack-init/scripts/recall.sh"
# Working-set paths: prefer the ignore-filtered list, else derive from meta.json.
PATHS_FILE="$OUTDIR/changed-paths.filtered.txt"
if [ ! -f "$PATHS_FILE" ]; then
  jq -r '.files[].path' "$OUTDIR/meta.json" 2>/dev/null > "$OUTDIR/changed-paths.txt" || true
  PATHS_FILE="$OUTDIR/changed-paths.txt"
fi

copy_flat_memory() {  # the pre-recall fallback
  if [ -f "$MEMORY_SRC" ]; then
    local sz; sz=$(wc -c < "$MEMORY_SRC" 2>/dev/null || echo 0)
    if [ "$sz" -gt 102400 ]; then tail -c 102400 "$MEMORY_SRC" > "$MEMORY_OUT";
      echo "Memory file large (${sz}B); truncated to last 100KB.";
    else cp "$MEMORY_SRC" "$MEMORY_OUT"; fi
    echo "Loaded cross-PR memory: $MEMORY_SRC (${sz}B)"
  else rm -f "$MEMORY_OUT"; fi
}

if [ -d "$WOOSTACK_DIR/memory" ] || [ -f "$MEMORY_SRC" ]; then
  if [ -f "$RECALL" ]; then
    if bash "$RECALL" "$WOOSTACK_DIR" "$PATHS_FILE" > "$MEMORY_OUT" 2> "$OUTDIR/recall.log"; then
      [ -s "$MEMORY_OUT" ] || rm -f "$MEMORY_OUT"
      echo "Composed cross-PR memory via recall.sh ($(wc -c < "$MEMORY_OUT" 2>/dev/null || echo 0)B; see recall.log)"
    else
      echo "::warning::recall.sh failed; falling back to flat memory copy"; copy_flat_memory
    fi
  else
    echo "::warning::recall.sh not found at $RECALL; using flat memory copy"; copy_flat_memory
  fi
else
  rm -f "$MEMORY_OUT"
fi
```

- [x] **Step 3: Syntax check + targeted integration test.**

Run:
```bash
bash -n skills/woostack-review/scripts/prefetch.sh && echo "syntax ok"
# Integration: fake a minimal OUTDIR + .woostack with a scoped note, run just the block logic.
tmp="$(mktemp -d)"; export OUTDIR="$tmp/out"; mkdir -p "$OUTDIR"
woo="$tmp/.woostack/memory"; mkdir -p "$woo"
printf 'packages/api/x.ts\n' > "$OUTDIR/changed-paths.filtered.txt"
printf -- '---\nname: api\ntype: pattern\nscope: packages/api/**\n---\nAPI RULE\n' > "$woo/api.md"
printf -- '---\nname: web\ntype: pattern\nscope: apps/web/**\n---\nWEB RULE\n' > "$woo/web.md"
( cd "$tmp" && GITHUB_WORKSPACE="$tmp" SCRIPT_DIR="$(cd skills/woostack-review/scripts 2>/dev/null && pwd || echo "$PWD/skills/woostack-review/scripts")" \
  RECALL="$PWD/skills/woostack-init/scripts/recall.sh" bash -c '
    set -e; MEMORY_OUT="$OUTDIR/memory.md"; PATHS_FILE="$OUTDIR/changed-paths.filtered.txt"
    bash "'"$PWD"'/skills/woostack-init/scripts/recall.sh" "$GITHUB_WORKSPACE/.woostack" "$PATHS_FILE" > "$MEMORY_OUT"
    grep -q "API RULE" "$MEMORY_OUT" && ! grep -q "WEB RULE" "$MEMORY_OUT" && echo "INTEGRATION OK"' )
rm -rf "$tmp"
```
Expected: `syntax ok` and `INTEGRATION OK` (the API note is recalled, the WEB note is not, for an api-only change).

- [x] **Step 4: Confirm scope guard.** `git diff origin/main -- skills/woostack-review/scripts/prefetch.sh` shows ONLY the memory block changed (plus the added `changed-paths.txt` derivation). No other prefetch logic touched.

- [x] **Step 5: Commit** — `feat(woostack-review): prefetch composes memory via recall.sh (scope-routed)`

---

## Task 3: Docs + final verify

**Files:**
- Modify: `skills/woostack-review/prompts/_header.md`
- Modify: `skills/woostack-review/SKILL.md`

- [x] **Step 1: Update `_header.md`.** In the *Cross-PR memory* bullet (the one describing `/tmp/pr-review/memory.md`), add a sentence: when the repo has a `.woostack/memory/` store, this file is **scope-routed** — it contains the notes whose `scope` matches the PR's changed files, any one-hop linked notes, plus the always-included global shard. Still: do NOT re-flag an issue the memory records as known/accepted. Keep it brief; do not restate the contract.

- [x] **Step 2: Update review `SKILL.md`.** In the *Cross-PR Memory* section, add a short paragraph: when a scope-routed store exists, `prefetch.sh` composes the per-PR memory via `recall.sh` (link `../woostack-init/references/memory.md`) instead of dumping the whole file; the flat `memory.md` remains the always-loaded global shard. One or two sentences.

- [x] **Step 3: Verify cross-links + full suite.**

Run:
```bash
bash skills/woostack-init/scripts/tests/run-tests.sh; echo "suite exit=$?"
grep -oE '\]\(([^)]+)\)' skills/woostack-review/SKILL.md | sed -E 's/\]\(//; s/\)//' | while read -r l; do
  case "$l" in http*|\#*) continue;; esac; p="${l%%#*}"
  base=skills/woostack-review; [ -e "$base/$p" ] || [ -e "$p" ] || echo "BROKEN: $l"; done; echo "links checked"
```
Expected: suite exit 0; no BROKEN lines (the `../woostack-init/...` relative link resolves from `skills/woostack-review/`).

- [x] **Step 4: Commit** — `docs(woostack-review): document scope-routed memory recall`

---

## Self-Review (completed during planning)

**Spec coverage:** §5.1 recall.sh → Task 1; §5.2 prefetch wiring → Task 2; §5.3 docs → Task 3; §6 error handling (fallback, cap log, read-only) → Tasks 1-2; §7 testing → Tasks 1-2. No gaps.

**Placeholder scan:** Task 1 ships complete recall.sh + tests. Task 2 ships the complete replacement block. Task 3 specifies exact doc edits + verification (prose enumerated, acceptable for markdown).

**Type consistency:** recall.sh consumes `field`/`note_body` (lib.sh) and `scope-match.sh` exactly as defined in increment A. prefetch's `SCRIPT_DIR` and `$OUTDIR`/`changed-paths.filtered.txt` match existing prefetch/detect-angles usage.
