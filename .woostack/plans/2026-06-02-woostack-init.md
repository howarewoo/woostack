# woostack-init (Increment A) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the `woostack-init` skill — scaffolds/repairs the `.woostack/` workspace and owns the canonical scope-routed memory contract plus its bash tooling.

**Architecture:** A new first-party skill under `skills/woostack-init/`. Three pure-bash scripts (`scope-match.sh` primitive, `build-index.sh`, `doctor.sh`) sharing a tiny frontmatter `lib.sh`. The scaffold verb itself is SKILL.md prose (agent-driven, like the other woostack skills) that creates the tree from `templates/` then runs the scripts. Additive superset: the flat `memory.md` and every other skill are untouched (those are increments B/C/D).

**Tech Stack:** Bash + coreutils (grep -E, sed, awk, sort, cut) — no node/python/YAML lib. Tests are plain-bash asserts with a tiny runner.

**Source of truth:** spec at `.woostack/specs/2026-06-02-woostack-init.md`.

---

## File Structure

| File | Responsibility |
|---|---|
| `skills/woostack-init/scripts/lib.sh` | Shared frontmatter helpers: `field()`, `first_body_line()`, `note_body()`. Sourced by the other scripts. |
| `skills/woostack-init/scripts/scope-match.sh` | Glob→ERE→`grep -E` matching primitive. Stdin paths, `$1` glob spec. |
| `skills/woostack-init/scripts/build-index.sh` | Regenerate `MEMORY.md` from note frontmatter, sorted by type then name. |
| `skills/woostack-init/scripts/doctor.sh` | Lint the `memory/` dir (consumes `scope-match.sh` + `lib.sh`). |
| `skills/woostack-init/scripts/tests/assert.sh` | Assert helpers + `tmprepo` fixture builder. |
| `skills/woostack-init/scripts/tests/run-tests.sh` | Runs every `test-*.sh`. |
| `skills/woostack-init/scripts/tests/test-*.sh` | One per script under test. |
| `skills/woostack-init/templates/config.json` | `{ "review": {} }` skeleton. |
| `skills/woostack-init/templates/gitignore` | `.woostack/` ignore rules. |
| `skills/woostack-init/templates/example-note.md` | One worked scoped note. |
| `skills/woostack-init/references/memory.md` | The canonical contract: schema, glob semantics, recall procedure. |
| `skills/woostack-init/SKILL.md` | The `/woostack-init` verb (scaffold flow, flags, report). |
| `AGENTS.md` | Five-skill collection: layout, command table, quick-ref. |

**Build order is dependency-driven:** test harness → `lib.sh` → `scope-match` → `build-index` → `doctor` (needs scope-match+lib) → templates → contract doc → SKILL.md → AGENTS.md.

---

## Task 1: Test harness + skill skeleton

**Files:**
- Create: `skills/woostack-init/scripts/tests/assert.sh`
- Create: `skills/woostack-init/scripts/tests/run-tests.sh`

- [x] **Step 1: Write the assert helpers**

Create `skills/woostack-init/scripts/tests/assert.sh`:

```bash
#!/usr/bin/env bash
# Minimal bash test helpers for the woostack-init scripts.
set -euo pipefail

PASS=0; FAIL=0

assert_eq() { # actual expected msg
  if [ "$1" = "$2" ]; then PASS=$((PASS+1)); else
    FAIL=$((FAIL+1)); echo "  FAIL: $3"; echo "    expected: [$2]"; echo "    actual:   [$1]"; fi
}
assert_contains() { # haystack needle msg
  if printf '%s' "$1" | grep -qF -- "$2"; then PASS=$((PASS+1)); else
    FAIL=$((FAIL+1)); echo "  FAIL: $3"; echo "    [$1] does not contain [$2]"; fi
}
assert_not_contains() { # haystack needle msg
  if printf '%s' "$1" | grep -qF -- "$2"; then
    FAIL=$((FAIL+1)); echo "  FAIL: $3"; echo "    [$1] unexpectedly contains [$2]"; else PASS=$((PASS+1)); fi
}
assert_exit() { # expected_code actual_code msg
  if [ "$1" = "$2" ]; then PASS=$((PASS+1)); else
    FAIL=$((FAIL+1)); echo "  FAIL: $3 (expected exit $1, got $2)"; fi
}
finish() { echo "  $PASS passed, $FAIL failed"; [ "$FAIL" -eq 0 ]; }

# Build a throwaway memory dir; echoes its path.
mk_memdir() { mktemp -d; }
# Write a note: mk_note <dir> <filename> <frontmatter-block> <body>
mk_note() { printf -- '---\n%s\n---\n%s\n' "$3" "$4" > "$1/$2"; }
```

- [x] **Step 2: Write the runner**

Create `skills/woostack-init/scripts/tests/run-tests.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
rc=0
for t in test-*.sh; do
  [ -e "$t" ] || continue
  echo "== $t =="
  if bash "$t"; then :; else rc=1; fi
done
exit "$rc"
```

- [x] **Step 3: Make executable and verify the runner runs with no tests**

Run:
```bash
chmod +x skills/woostack-init/scripts/tests/*.sh
bash skills/woostack-init/scripts/tests/run-tests.sh; echo "exit=$?"
```
Expected: no `test-*.sh` yet → prints nothing under a loop, `exit=0`.

- [x] **Step 4: Commit**

```bash
git add skills/woostack-init/scripts/tests/assert.sh skills/woostack-init/scripts/tests/run-tests.sh
git commit -m "test(woostack-init): bash assert harness + runner"
```

---

## Task 2: `lib.sh` frontmatter helpers

**Files:**
- Create: `skills/woostack-init/scripts/lib.sh`
- Test: `skills/woostack-init/scripts/tests/test-lib.sh`

- [x] **Step 1: Write the failing test**

Create `skills/woostack-init/scripts/tests/test-lib.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DIR/tests/assert.sh"
source "$DIR/lib.sh"

d="$(mk_memdir)"
mk_note "$d" a.md $'name: alpha\ntype: pattern\nscope: packages/api/**\nhook: short hook' $'First body line.\nSecond [[beta]] line.'

assert_eq "$(field "$d/a.md" name)" "alpha" "field name"
assert_eq "$(field "$d/a.md" type)" "pattern" "field type"
assert_eq "$(field "$d/a.md" scope)" "packages/api/**" "field scope"
assert_eq "$(field "$d/a.md" hook)" "short hook" "field hook"
assert_eq "$(first_body_line "$d/a.md")" "First body line." "first body line"
assert_contains "$(note_body "$d/a.md")" "[[beta]]" "body contains wikilink"
rm -rf "$d"
finish
```

- [x] **Step 2: Run test to verify it fails**

Run: `bash skills/woostack-init/scripts/tests/test-lib.sh; echo "exit=$?"`
Expected: FAIL — `lib.sh` does not exist (source error), `exit` non-zero.

- [x] **Step 3: Write `lib.sh`**

Create `skills/woostack-init/scripts/lib.sh`:

```bash
#!/usr/bin/env bash
# Shared frontmatter helpers for the woostack-init scripts.
# Frontmatter is line-oriented: between two `---` fences, one `key: value` per line.

# field <file> <key> → first matching value (trimmed), empty if absent.
field() {
  sed -n '/^---$/,/^---$/p' "$1" \
    | grep -m1 "^$2:" \
    | sed "s/^$2:[[:space:]]*//; s/[[:space:]]*$//"
}

# note_body <file> → everything after the closing frontmatter fence.
note_body() {
  awk 'done2{print} /^---$/{c++; if(c==2){done2=1}}' "$1"
}

# first_body_line <file> → first non-empty body line, trimmed.
first_body_line() {
  note_body "$1" | sed '/^[[:space:]]*$/d' | head -1 | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}
```

- [x] **Step 4: Run test to verify it passes**

Run: `bash skills/woostack-init/scripts/tests/test-lib.sh; echo "exit=$?"`
Expected: `6 passed, 0 failed`, `exit=0`.

- [x] **Step 5: Commit**

```bash
git add skills/woostack-init/scripts/lib.sh skills/woostack-init/scripts/tests/test-lib.sh
git commit -m "feat(woostack-init): frontmatter helper lib + tests"
```

---

## Task 3: `scope-match.sh` primitive

**Files:**
- Create: `skills/woostack-init/scripts/scope-match.sh`
- Test: `skills/woostack-init/scripts/tests/test-scope-match.sh`

- [x] **Step 1: Write the failing test**

Create `skills/woostack-init/scripts/tests/test-scope-match.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DIR/tests/assert.sh"
SM="$DIR/scope-match.sh"

paths=$'packages/api/orpc/x.ts\npackages/web/y.tsx\napps/admin/z.ts\nREADME.md'

# ** crosses slashes
out="$(printf '%s\n' "$paths" | bash "$SM" 'packages/api/**')"
assert_contains "$out" "packages/api/orpc/x.ts" "** matches subtree"
assert_not_contains "$out" "packages/web/y.tsx" "** excludes sibling"

# * does not cross a slash
out="$(printf '%s\n' "$paths" | bash "$SM" 'apps/*/z.ts')"
assert_contains "$out" "apps/admin/z.ts" "* matches one segment"

out="$(printf '%s\n' "$paths" | bash "$SM" 'apps/*.ts' || true)"
assert_not_contains "$out" "apps/admin/z.ts" "* does not cross slash"

# exact + dot escaping
out="$(printf '%s\n' "$paths" | bash "$SM" 'README.md')"
assert_contains "$out" "README.md" "exact literal match"
out="$(printf '%s\n' "$paths" | bash "$SM" 'READMEXmd' || true)"
assert_not_contains "$out" "README.md" "dot is escaped, not any-char"

# comma list = OR
out="$(printf '%s\n' "$paths" | bash "$SM" 'packages/web/**, apps/*/z.ts')"
assert_contains "$out" "packages/web/y.tsx" "comma list alt 1"
assert_contains "$out" "apps/admin/z.ts" "comma list alt 2"

# global: empty or *
out="$(printf '%s\n' "$paths" | bash "$SM" '*')"
assert_contains "$out" "README.md" "star is global"
out="$(printf '%s\n' "$paths" | bash "$SM" '')"
assert_contains "$out" "packages/api/orpc/x.ts" "empty is global"

# exit status: no match → 1
set +e
printf '%s\n' "$paths" | bash "$SM" 'nope/**' >/dev/null; code=$?
set -e
assert_exit 1 "$code" "no match exits 1"

finish
```

- [x] **Step 2: Run test to verify it fails**

Run: `bash skills/woostack-init/scripts/tests/test-scope-match.sh; echo "exit=$?"`
Expected: FAIL — `scope-match.sh` missing.

- [x] **Step 3: Write `scope-match.sh`**

Create `skills/woostack-init/scripts/scope-match.sh`:

```bash
#!/usr/bin/env bash
# scope-match.sh — print stdin paths matching a comma-separated glob spec.
# Glob semantics: *→[^/]*  **→.*  exact→literal(dots escaped)  ""|*→global.
# Exit 0 if >=1 path matched, 1 otherwise.
set -euo pipefail

SPEC="${1:-}"

glob_to_ere() {
  local g="$1" out="" i=0 n=${#1} c
  while [ "$i" -lt "$n" ]; do
    c=${g:$i:1}
    case "$c" in
      '*')
        if [ "${g:$((i+1)):1}" = '*' ]; then out+='.*'; i=$((i+2));
        else out+='[^/]*'; i=$((i+1)); fi ;;
      '.'|'+'|'?'|'('|')'|'['|']'|'{'|'}'|'|'|'^'|'$'|'\') out+="\\$c"; i=$((i+1)) ;;
      *) out+="$c"; i=$((i+1)) ;;
    esac
  done
  printf '^%s$' "$out"
}

trimmed="$(printf '%s' "$SPEC" | tr -d '[:space:]')"
if [ -z "$trimmed" ] || [ "$trimmed" = '*' ]; then
  # global — echo all stdin, succeed if non-empty
  if grep -E '.*'; then exit 0; else exit 1; fi
fi

ERE=""
IFS=',' read -ra parts <<< "$SPEC"
for p in "${parts[@]}"; do
  g="$(printf '%s' "$p" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  [ -z "$g" ] && continue
  e="$(glob_to_ere "$g")"
  if [ -z "$ERE" ]; then ERE="$e"; else ERE="$ERE|$e"; fi
done
[ -z "$ERE" ] && exit 1

if grep -E "$ERE"; then exit 0; else exit 1; fi
```

- [x] **Step 4: Run test to verify it passes**

Run: `bash skills/woostack-init/scripts/tests/test-scope-match.sh; echo "exit=$?"`
Expected: all assertions pass, `exit=0`.

- [x] **Step 5: Commit**

```bash
git add skills/woostack-init/scripts/scope-match.sh skills/woostack-init/scripts/tests/test-scope-match.sh
git commit -m "feat(woostack-init): scope-match glob primitive + tests"
```

---

## Task 4: `build-index.sh`

**Files:**
- Create: `skills/woostack-init/scripts/build-index.sh`
- Test: `skills/woostack-init/scripts/tests/test-build-index.sh`

- [x] **Step 1: Write the failing test**

Create `skills/woostack-init/scripts/tests/test-build-index.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DIR/tests/assert.sh"
BI="$DIR/build-index.sh"

d="$(mk_memdir)"
# Out of alphabetical/type order on purpose.
mk_note "$d" zeta.md $'name: zeta\ntype: pattern\nscope: apps/web/**\nhook: zeta hook' 'body z'
mk_note "$d" alpha.md $'name: alpha\ntype: decision' $'First real line of alpha.\nmore'
mk_note "$d" beta.md $'name: beta\ntype: decision\nscope: a/**, b/**' 'body b'

bash "$BI" "$d"
idx="$(cat "$d/MEMORY.md")"

assert_contains "$idx" "- [alpha](alpha.md) \`decision\` scope=\`*\` — First real line of alpha." "alpha line w/ body-line hook + global scope"
assert_contains "$idx" "- [beta](beta.md) \`decision\` scope=\`a/**\`" "beta uses first scope glob"
assert_contains "$idx" "- [zeta](zeta.md) \`pattern\` scope=\`apps/web/**\` — zeta hook" "zeta uses hook field"

# sorted: decisions (alpha, beta) before pattern (zeta); alpha before beta
order="$(printf '%s\n' "$idx" | grep -n '\- \[' | tr '\n' ' ')"
a=$(printf '%s\n' "$idx" | grep -n 'alpha' | cut -d: -f1)
b=$(printf '%s\n' "$idx" | grep -n 'beta'  | cut -d: -f1)
z=$(printf '%s\n' "$idx" | grep -n 'zeta'  | cut -d: -f1)
[ "$a" -lt "$b" ] && [ "$b" -lt "$z" ] && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "  FAIL: sort order a<b<z ($a,$b,$z)"; }

# idempotent
cp "$d/MEMORY.md" "$d/.first"
bash "$BI" "$d"
assert_eq "$(cat "$d/MEMORY.md")" "$(cat "$d/.first")" "idempotent rebuild"

# never reads flat memory.md
echo "- flat bullet" > "$d/../memory.md" 2>/dev/null || true
rm -rf "$d"
finish
```

- [x] **Step 2: Run test to verify it fails**

Run: `bash skills/woostack-init/scripts/tests/test-build-index.sh; echo "exit=$?"`
Expected: FAIL — `build-index.sh` missing.

- [x] **Step 3: Write `build-index.sh`**

Create `skills/woostack-init/scripts/build-index.sh`:

```bash
#!/usr/bin/env bash
# build-index.sh — regenerate <memdir>/MEMORY.md from note frontmatter.
# Indexes the dir only; never reads/writes the flat memory.md. Idempotent.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib.sh"

MEM_DIR="${1:-.woostack/memory}"
INDEX="$MEM_DIR/MEMORY.md"

tmp="$(mktemp)"
shopt -s nullglob
for f in "$MEM_DIR"/*.md; do
  base="$(basename "$f")"
  [ "$base" = "MEMORY.md" ] && continue
  name="$(field "$f" name)"; type="$(field "$f" type)"
  scope="$(field "$f" scope)"; hook="$(field "$f" hook)"
  [ -z "$hook" ] && hook="$(first_body_line "$f")"
  first_scope="$(printf '%s' "$scope" | cut -d',' -f1 | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  [ -z "$first_scope" ] && first_scope='*'
  hook="$(printf '%s' "$hook" | cut -c1-80)"
  printf '%s\t%s\t- [%s](%s) `%s` scope=`%s` — %s\n' \
    "$type" "$name" "$name" "$base" "$type" "$first_scope" "$hook" >> "$tmp"
done

{
  echo "<!-- generated by build-index.sh — do not edit by hand -->"
  echo
  LC_ALL=C sort -t"$(printf '\t')" -k1,1 -k2,2 "$tmp" | cut -f3-
} > "$INDEX"
rm -f "$tmp"
```

- [x] **Step 4: Run test to verify it passes**

Run: `bash skills/woostack-init/scripts/tests/test-build-index.sh; echo "exit=$?"`
Expected: all pass, `exit=0`.

- [x] **Step 5: Commit**

```bash
git add skills/woostack-init/scripts/build-index.sh skills/woostack-init/scripts/tests/test-build-index.sh
git commit -m "feat(woostack-init): derived MEMORY.md index builder + tests"
```

---

## Task 5: `doctor.sh`

**Files:**
- Create: `skills/woostack-init/scripts/doctor.sh`
- Test: `skills/woostack-init/scripts/tests/test-doctor.sh`

- [x] **Step 1: Write the failing test**

Create `skills/woostack-init/scripts/tests/test-doctor.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DIR/tests/assert.sh"
DOC="$DIR/doctor.sh"

run_doctor() { # memdir → captures stderr; sets OUT, CODE
  set +e; OUT="$(bash "$DOC" "$1" 2>&1)"; CODE=$?; set -e
}

# clean store under a real git repo so scope-match has tracked files
repo="$(mktemp -d)"; ( cd "$repo" && git init -q && mkdir -p packages/api && touch packages/api/x.ts && git add -A && git commit -qm init )
md="$repo/.woostack/memory"; mkdir -p "$md"
mk_note "$md" ok.md $'name: ok\ntype: pattern\nscope: packages/api/**' 'fine body'
( cd "$repo" && run_doctor ".woostack/memory" )
assert_exit 0 "$CODE" "clean store exits 0"

# stale scope → warn, exit 0
mk_note "$md" stale.md $'name: stale\ntype: gotcha\nscope: nope/**' 'body'
( cd "$repo" && run_doctor ".woostack/memory" )
assert_contains "$OUT" "stale" "stale scope warned"
assert_exit 0 "$CODE" "warnings still exit 0"

# unresolved wikilink → warn
mk_note "$md" link.md $'name: link\ntype: pattern\nscope: packages/api/**' 'see [[ghost]] note'
( cd "$repo" && run_doctor ".woostack/memory" )
assert_contains "$OUT" "ghost" "unresolved wikilink warned"

# errors: dup name, bad type, missing field, malformed
err="$(mktemp -d)/m"; mkdir -p "$err"
mk_note "$err" d1.md $'name: dup\ntype: pattern' 'b'
mk_note "$err" d2.md $'name: dup\ntype: pattern' 'b'
run_doctor "$err"; assert_exit 1 "$CODE" "duplicate name errors"; assert_contains "$OUT" "duplicate" "dup msg"

err2="$(mktemp -d)/m"; mkdir -p "$err2"
mk_note "$err2" bad.md $'name: x\ntype: bogus' 'b'
run_doctor "$err2"; assert_exit 1 "$CODE" "bad type errors"

err3="$(mktemp -d)/m"; mkdir -p "$err3"
mk_note "$err3" nofield.md $'type: pattern' 'b'
run_doctor "$err3"; assert_exit 1 "$CODE" "missing name errors"

err4="$(mktemp -d)/m"; mkdir -p "$err4"
printf 'no frontmatter here\n' > "$err4/malformed.md"
run_doctor "$err4"; assert_exit 1 "$CODE" "malformed frontmatter errors"

rm -rf "$repo"
finish
```

- [x] **Step 2: Run test to verify it fails**

Run: `bash skills/woostack-init/scripts/tests/test-doctor.sh; echo "exit=$?"`
Expected: FAIL — `doctor.sh` missing.

- [x] **Step 3: Write `doctor.sh`**

Create `skills/woostack-init/scripts/doctor.sh`:

```bash
#!/usr/bin/env bash
# doctor.sh — lint the memory/ dir. Warnings exit 0; errors exit 1.
# Lints the dir only; the flat memory.md is free-form and never read.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib.sh"

MEM_DIR="${1:-.woostack/memory}"
VALID_TYPES=" decision pattern gotcha convention hotspot "
errors=0; warnings=0
seen="$(mktemp)"
paths="$(git ls-files 2>/dev/null || true)"

err()  { echo "::error:: $1" >&2; errors=$((errors+1)); }
warn() { echo "::warning:: $1" >&2; warnings=$((warnings+1)); }

shopt -s nullglob
for f in "$MEM_DIR"/*.md; do
  base="$(basename "$f")"
  [ "$base" = "MEMORY.md" ] && continue

  if [ "$(head -1 "$f")" != "---" ]; then
    err "$base: malformed — missing opening '---' frontmatter fence"; continue
  fi

  name="$(field "$f" name)"; type="$(field "$f" type)"
  body="$(note_body "$f" | tr -d '[:space:]')"

  [ -z "$name" ] && err "$base: missing required field: name"
  [ -z "$type" ] && err "$base: missing required field: type"
  [ -z "$body" ] && err "$base: empty body"
  if [ -n "$type" ] && [ "${VALID_TYPES/ $type /}" = "$VALID_TYPES" ]; then
    err "$base: unknown type: $type"
  fi

  if [ -n "$name" ]; then
    if grep -qxF "$name" "$seen"; then err "$base: duplicate name: $name"
    else echo "$name" >> "$seen"; fi
  fi

  scope="$(field "$f" scope)"
  if [ -n "$scope" ] && [ "$scope" != "*" ] && [ -n "$paths" ]; then
    if ! printf '%s\n' "$paths" | bash "$HERE/scope-match.sh" "$scope" >/dev/null 2>&1; then
      warn "$base: scope '$scope' matches no tracked files (stale)"
    fi
  fi

  while IFS= read -r link; do
    [ -z "$link" ] && continue
    [ -f "$MEM_DIR/$link.md" ] || warn "$base: unresolved [[$link]]"
  done < <(grep -oE '\[\[[^]]+\]\]' "$f" 2>/dev/null | sed 's/\[\[//; s/\]\]//' | sort -u)
done
rm -f "$seen"

echo "doctor: $errors error(s), $warnings warning(s)" >&2
[ "$errors" -eq 0 ]
```

- [x] **Step 4: Run test to verify it passes**

Run: `bash skills/woostack-init/scripts/tests/test-doctor.sh; echo "exit=$?"`
Expected: all pass, `exit=0`.

- [x] **Step 5: Run the whole suite**

Run: `bash skills/woostack-init/scripts/tests/run-tests.sh; echo "exit=$?"`
Expected: every `test-*.sh` reports `0 failed`, `exit=0`.

- [x] **Step 6: Commit**

```bash
git add skills/woostack-init/scripts/doctor.sh skills/woostack-init/scripts/tests/test-doctor.sh
git commit -m "feat(woostack-init): store linter (doctor) + tests"
```

---

## Task 6: Templates

**Files:**
- Create: `skills/woostack-init/templates/config.json`
- Create: `skills/woostack-init/templates/gitignore`
- Create: `skills/woostack-init/templates/example-note.md`

- [x] **Step 1: Write the templates**

`skills/woostack-init/templates/config.json`:
```json
{
  "review": {}
}
```

`skills/woostack-init/templates/gitignore` (copied to `.woostack/.gitignore`):
```
# Transient, per-clone — not shared knowledge.
metrics.json
*.local.*
```

`skills/woostack-init/templates/example-note.md`:
```
---
name: example-note
type: convention
scope: *
tags: example
hook: Delete me — example of the memory note format
updated: 2026-06-02
source:
---
This is an example scoped memory note. Replace or delete it.
Notes link each other in the body with wikilinks like [[example-note]].
Recall loads this only when a working-set path matches `scope`.
```

- [x] **Step 2: Verify the example note passes doctor and indexes**

Run:
```bash
tmp="$(mktemp -d)/memory"; mkdir -p "$tmp"
cp skills/woostack-init/templates/example-note.md "$tmp/"
bash skills/woostack-init/scripts/build-index.sh "$tmp" && cat "$tmp/MEMORY.md"
bash skills/woostack-init/scripts/doctor.sh "$tmp"; echo "doctor exit=$?"
```
Expected: index line `- [example-note](example-note.md) \`convention\` scope=\`*\` — Delete me — example of the memory note format`; doctor reports **no unresolved-link warning** (the example self-links `[[example-note]]`, which resolves) and **exits 0**. Confirm `doctor exit=0`.

- [x] **Step 3: Commit**

```bash
git add skills/woostack-init/templates/
git commit -m "feat(woostack-init): workspace templates (config, gitignore, example note)"
```

---

## Task 7: The contract — `references/memory.md`

**Files:**
- Create: `skills/woostack-init/references/memory.md`

- [x] **Step 1: Write the contract doc**

Create `skills/woostack-init/references/memory.md` with these sections (prose, normal English — NOT caveman):

1. **Purpose** — one paragraph: the scope-routed memory store, additive over the flat `.woostack/memory.md` global shard.
2. **Layout** — the `.woostack/` runtime tree (copy the spec §5.2 block).
3. **Note format** — the frontmatter schema (copy spec §5.3 verbatim: required `name`/`type`/body; enum; `scope` comma-glob; optional `hook`; `source`; **body `[[wikilinks]]` are the only link form, no `links:` field**).
4. **Glob→match semantics** — the spec §5.8 table (`*`→`[^/]*`, `**`→`.*`, exact escaped, comma=OR, empty/`*`=global).
5. **Derived index** — spec §5.4 line format; regenerated by `build-index.sh`, never hand-edited.
6. **Recall procedure** — the spec §4 numbered procedure (index-first → scope-match → one-hop body-wikilink expand). State explicitly that `recall.sh` orchestration arrives in increment B and that A ships only the `scope-match` primitive.
7. **Scripts** — one line each for `scope-match.sh`, `build-index.sh`, `doctor.sh` with usage.
8. **Degradation** — if a consuming skill can't find these scripts (single-skill install), it follows the documented procedure manually and says so.

Cross-link rule: link to `../../woostack-review/SKILL.md` for the `review` config namespace; do **not** restate it.

- [x] **Step 2: Verify cross-links resolve**

Run:
```bash
grep -oE '\]\([^)]+\)' skills/woostack-init/references/memory.md | sed 's/](//; s/)//' | while read -r l; do
  case "$l" in /*|http*) continue;; esac
  t="skills/woostack-init/references/$l"
  [ -e "$t" ] || echo "BROKEN: $l"
done; echo "link check done"
```
Expected: `link check done` with no `BROKEN:` lines.

- [x] **Step 3: Commit**

```bash
git add skills/woostack-init/references/memory.md
git commit -m "docs(woostack-init): canonical scope-routed memory contract"
```

---

## Task 8: `SKILL.md` — the `/woostack-init` verb

**Files:**
- Create: `skills/woostack-init/SKILL.md`

- [x] **Step 1: Write SKILL.md**

Create `skills/woostack-init/SKILL.md`. Frontmatter `description` must drive discovery (mention: initialize/scaffold/repair the `.woostack/` workspace, memory store, specs/plans, config). Body sections:

- **Overview** — what `/woostack-init` does and the two callers (brownfield user-invoked; greenfield via woostack-bootstrap).
- **Procedure** (the spec §5.5 flow as prose):
  1. Resolve target dir (arg or cwd); detect existing `.woostack/`.
  2. Create missing pieces from `templates/`: `memory/` (+ `.gitkeep`), `memory.md` (empty if absent — **never clobber**), `specs/`, `plans/`, `config.json`, `.gitignore` (from `templates/gitignore`).
  3. On any **existing** file: prompt keep/overwrite. Honor `--force` (overwrite all) and `--no-clobber` (skip existing silently); state which mode ran.
  4. Run `scripts/build-index.sh .woostack/memory` then `scripts/doctor.sh .woostack/memory`.
  5. Report created vs skipped + doctor warnings/errors.
- **Flags** — `--force`, `--no-clobber`.
- **Hard constraints** — never clobber `memory.md`/notes/`config.json` without explicit overwrite; the flat `memory.md` and other skills' files are out of scope; pure-bash scripts, no new runtime dep.
- **Reference** — link to `references/memory.md` for the store contract.

- [x] **Step 2: Lint-check the skill's own scripts still pass**

Run: `bash skills/woostack-init/scripts/tests/run-tests.sh; echo "exit=$?"`
Expected: `exit=0` (unchanged by docs).

- [x] **Step 3: Commit**

```bash
git add skills/woostack-init/SKILL.md
git commit -m "feat(woostack-init): /woostack-init verb (scaffold + repair workspace)"
```

---

## Task 9: Wire into AGENTS.md (five-skill collection)

**Files:**
- Modify: `AGENTS.md`

- [x] **Step 1: Update the four→five references**

Edit `AGENTS.md`:
- "What this repo is": change "The four skills are: …" to list five, adding `woostack-init`.
- Repo layout block: add the `woostack-init/` subtree (SKILL.md, references/memory.md, scripts/, templates/).
- "Two modes" → Mode B command table: add a row `| /woostack-init [path] | Scaffold/repair the .woostack/ workspace + memory store. |`.
- "Quick reference" table: add a row `| Initialize the .woostack workspace | skills/woostack-init/SKILL.md |` and `| Change the memory contract | skills/woostack-init/references/memory.md |`.
- Anywhere "four SKILL.md files" is enumerated as a do-not-move list: add the fifth path `skills/woostack-init/SKILL.md`.

- [x] **Step 2: Verify the count is consistent**

Run:
```bash
grep -n "four skills\|four SKILL\|The four" AGENTS.md || echo "no stale 'four' references"
grep -c "woostack-init" AGENTS.md
```
Expected: `no stale 'four' references`; `woostack-init` count ≥ 4 (intro, layout, command table, quick-ref).

- [x] **Step 3: Verify all AGENTS.md cross-links resolve**

Run:
```bash
grep -oE '\]\(([^)]+)\)' AGENTS.md | sed -E 's/\]\(//; s/\)//' | while read -r l; do
  case "$l" in http*|\#*) continue;; esac
  p="${l%%#*}"
  [ -e "$p" ] || echo "BROKEN: $l"
done; echo "agents link check done"
```
Expected: `agents link check done`, no `BROKEN:` lines.

- [x] **Step 4: Commit**

```bash
git add AGENTS.md
git commit -m "docs: register woostack-init as the fifth skill"
```

---

## Task 10: Final verification + dogfood

- [x] **Step 1: Full test suite**

Run: `bash skills/woostack-init/scripts/tests/run-tests.sh; echo "exit=$?"`
Expected: every suite `0 failed`, `exit=0`.

- [x] **Step 2: Dogfood the scripts on this very repo's `.woostack/`**

Run:
```bash
mkdir -p .woostack/memory
cp skills/woostack-init/templates/example-note.md .woostack/memory/ 2>/dev/null || true
bash skills/woostack-init/scripts/build-index.sh .woostack/memory && cat .woostack/memory/MEMORY.md
bash skills/woostack-init/scripts/doctor.sh .woostack/memory; echo "doctor exit=$?"
# clean up the throwaway example so we don't commit it
rm -f .woostack/memory/example-note.md .woostack/memory/MEMORY.md
rmdir .woostack/memory 2>/dev/null || true
```
Expected: index builds; the example's `[[example-note]]` self-link resolves (no unresolved-link warning) and `doctor exit=0`.

- [x] **Step 3: shellcheck (if available)**

Run: `command -v shellcheck >/dev/null && shellcheck skills/woostack-init/scripts/*.sh || echo "shellcheck not installed — skipped"`
Expected: no errors, or the skip notice. Fix any error-level findings.

- [x] **Step 4: Confirm nothing outside scope was touched**

Run: `git diff --stat origin/main -- skills/woostack-review skills/woostack-build skills/woostack-bootstrap skills/woostack-address-comments .woostack/memory.md`
Expected: **empty** — increment A touches none of the other skills, the review pipeline, or the flat `memory.md`.

- [x] **Step 5: Push + open PR (build skill step 7 — ask first)**

Per woostack-build, ask the user before opening the PR. On yes:
```bash
git push -u origin feat/woostack-init
gh pr create --base main --head feat/woostack-init --title "feat: woostack-init — workspace scaffold + scope-routed memory contract (increment A)" --body "<summary from spec>"
```

---

## Self-Review (completed during planning)

**Spec coverage:** §5.1 layout → Tasks 1–8; §5.2 runtime + gitignore/config → Tasks 6,8; §5.3 frontmatter → Tasks 2,7; §5.4 index → Task 4; §5.5 control flow → Task 8; §5.6 build-index → Task 4; §5.7 scope-match → Task 3; §5.8 glob semantics → Tasks 3,7; §5.9 doctor → Task 5; §6 error handling → Tasks 5,8; §7 testing → Tasks 1–5,10; non-goals (no other-skill edits) → Task 10 Step 4 guard. No gaps.

**Placeholder scan:** all code steps contain complete, runnable code. Task 7/8 (docs) specify exact section content + verification commands rather than full prose — acceptable for Markdown reference/skill files whose content is enumerated.

**Type consistency:** `field`/`first_body_line`/`note_body` defined in Task 2 `lib.sh`, used unchanged in Tasks 4–5. `scope-match.sh` stdin/`$1` contract consistent between Task 3 (definition), Task 5 (doctor consumer), and the contract doc. Index line format identical in Tasks 4 test and §5.4.
