---
type: plan
source: .woostack/specs/2026-06-13-woostack-doctor.md
status: done
branch: feature/woostack-doctor
---

**Source:** [[specs/2026-06-13-woostack-doctor]]

# /woostack-doctor — workspace health: diagnose + gated repair — Implementation Plan

**Goal:** Ship `/woostack-doctor`, the 17th public command: a headless, exit-coded **diagnose
engine** for a repo's `.woostack/` workspace plus an interactive, gated **repair layer**
(propose → approve → apply → hand to `woostack-commit`). First shipped convention: the spec↔plan
Obsidian backlink, demonstrated end-to-end (lint + repair + backfill).

**Architecture:** New bundle `skills/woostack-doctor/` (`SKILL.md`, `scripts/`, `references/`).
The buried memory linter `skills/woostack-init/scripts/doctor.sh` **moves** here and is refactored
into an **orchestrator** (`doctor.sh`) that runs pluggable **checks** (`checks/*.sh`), each emitting
a tab-delimited finding stream `severity⇥code⇥fixable⇥path⇥message`. The orchestrator groups the
report, prints GitHub annotations to stderr, dumps machine-readable findings to stdout (for the
repair layer), and exits nonzero iff any `error`. Shared libs (`lib.sh`, `scope-match.sh`,
`build-index.sh`, `graph.sh`) stay `woostack-init`'s foundational infra; the moved engine sources
them cross-skill via `../../woostack-init/scripts/`. `woostack-init` and `woostack-dream` call the
engine at its new path. Repair is agent-driven in `SKILL.md`: each fixable check ships a `--fix`
apply path; the agent proposes a changeset, gates on approval, applies, then invokes
`woostack-commit`. Pure bash + coreutils, headless; no app runtime.

**Tech Stack:** bash (3.2-compatible, matching existing scripts), coreutils, `awk`/`sed`/`grep`,
git. Tests: the repo's existing `assert.sh` harness, sourced cross-skill.

**Increment shape:** one linear `gt` stack (each increment depends on the previous: move →
contract → checks → repair → dogfood → surface). No `## Track:` headings.

---

## Increment 1: Move the engine + rewire callers (behavior-preserving)

> independently shippable PR (≤500 LOC) — Graphite-stacked branch. No behavior change: the memory
> linter runs identically from its new home. (AC1)

### Task 1.1: Relocate the engine and its test

**Files:**
- Move: `skills/woostack-init/scripts/doctor.sh` → `skills/woostack-doctor/scripts/doctor.sh`
- Move: `skills/woostack-init/scripts/tests/test-doctor.sh` → `skills/woostack-doctor/scripts/tests/test-doctor.sh`
- Create: `skills/woostack-doctor/scripts/tests/run-tests.sh`

- [x] Create the new dirs and move with git (preserves history):
  ```bash
  cd "$(git rev-parse --show-toplevel)"
  mkdir -p skills/woostack-doctor/scripts/checks skills/woostack-doctor/scripts/tests skills/woostack-doctor/references
  git mv skills/woostack-init/scripts/doctor.sh skills/woostack-doctor/scripts/doctor.sh
  git mv skills/woostack-init/scripts/tests/test-doctor.sh skills/woostack-doctor/scripts/tests/test-doctor.sh
  ```
- [x] Fix the two cross-skill source/call lines in `skills/woostack-doctor/scripts/doctor.sh`
  (was `"$HERE/lib.sh"` / `"$HERE/scope-match.sh"`, now in `woostack-init`):
  ```bash
  # line 7:
  source "$HERE/../../woostack-init/scripts/lib.sh"
  # line 45 (inside the loop):
  matches="$(printf '%s\n' "$paths" | bash "$HERE/../../woostack-init/scripts/scope-match.sh" "$scope" 2>/dev/null)"
  ```
- [x] Point the moved test at the cross-skill `assert.sh`. The test header is
  `DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"` (= `scripts/`), then
  `source "$DIR/tests/assert.sh"` and `DOC="$DIR/doctor.sh"`. `DOC` already resolves after the
  move; `assert.sh` stays in `woostack-init`, so only line 4's source path changes:
  ```bash
  source "$DIR/../../woostack-init/scripts/tests/assert.sh"
  ```
  The rest of the body (`run_doctor`, `mk_note`, the assertions) is unchanged in this increment —
  Inc 1's `doctor.sh` is still the verbatim memory linter (takes the memdir as `$1`, emits the old
  `::warning::`/`::error::` format), so every existing assertion passes.
- [x] Create `skills/woostack-doctor/scripts/tests/run-tests.sh` (mirror of init's runner):
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
- [x] Verify the moved suite is green from its new home:
  ```bash
  bash skills/woostack-doctor/scripts/tests/run-tests.sh
  ```
  Expected: ends `0 failed` (all existing memory-linter assertions pass unchanged).
- [x] Verify the init suite still passes with `test-doctor.sh` gone from it:
  ```bash
  bash skills/woostack-init/scripts/tests/run-tests.sh
  ```
  Expected: green; no `test-doctor.sh` line in its output.

### Task 1.2: Rewire `woostack-init` to the new engine path

**Files:**
- Modify: `skills/woostack-init/SKILL.md` (lines ~13–14, 80, 83, 87, 115, 118)

- [x] In `skills/woostack-init/SKILL.md`, change the invocation from
  `bash scripts/doctor.sh .woostack/memory` to the new path and note the cross-skill dependency:
  ```
  bash ../woostack-doctor/scripts/doctor.sh .woostack/memory
  ```
  Update the surrounding prose (lines 13–14, 83, 87) so "runs `doctor.sh`" reads "runs
  `woostack-doctor`'s `doctor.sh` engine"; in the headless-tooling list (115, 118) keep `doctor`
  but point to its new home.
- [x] Confirm no stale path remains in init:
  ```bash
  grep -rn "woostack-init/scripts/doctor" skills/woostack-init/ ; echo "exit=$?"
  ```
  Expected: no matches (`exit=1`).

### Task 1.3: Rewire `woostack-dream`'s three doctor references

**Files:**
- Modify: `skills/woostack-dream/SKILL.md` (lines 8, 20, 69)

- [x] Replace all `../woostack-init/scripts/doctor.sh` with `../woostack-doctor/scripts/doctor.sh`:
  ```bash
  sed -i.bak 's#\.\./woostack-init/scripts/doctor\.sh#../woostack-doctor/scripts/doctor.sh#g' skills/woostack-dream/SKILL.md && rm -f skills/woostack-dream/SKILL.md.bak
  ```
- [x] Confirm the move left no dangling reference anywhere in the repo:
  ```bash
  grep -rn "woostack-init/scripts/doctor" skills/ .github/ action.yml 2>/dev/null ; echo "exit=$?"
  ```
  Expected: no matches (`exit=1`). (This is AC1's "stale reference fails" guard, run by hand here
  and as a test in Task 1.4.)

### Task 1.4: Lock the no-stale-path invariant with a test

**Files:**
- Create: `skills/woostack-doctor/scripts/tests/test-no-stale-paths.sh`

- [x] Write the failing test first:
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  source "$HERE/../../../woostack-init/scripts/tests/assert.sh"
  ROOT="$(cd "$HERE/../../../.." && pwd)"
  hits="$(grep -rn "woostack-init/scripts/doctor" "$ROOT/skills" 2>/dev/null || true)"
  assert_eq "$hits" "" "no skill references the old woostack-init/scripts/doctor.sh path"
  finish
  ```
- [x] Run it; expect green (Tasks 1.2–1.3 already removed the references):
  ```bash
  bash skills/woostack-doctor/scripts/tests/test-no-stale-paths.sh
  ```
  Expected: `1 passed, 0 failed`.

---

## Increment 2: Orchestrator + finding contract + memory check extraction

> independently shippable PR — introduces the diagnose-engine contract. Memory-lint *flags and
> severities are preserved*; only the output format and entrypoint change. (AC2)

### Task 2.1: Extract memory lint into a finding-emitting check

**Files:**
- Create: `skills/woostack-doctor/scripts/checks/memory.sh`

- [x] Create `checks/memory.sh` by moving the per-note loop + overlap-cluster block from the old
  `doctor.sh` **verbatim**, with two mechanical substitutions: (a) source libs cross-skill; (b)
  replace `err`/`warn` with a finding emitter. Header + helpers:
  ```bash
  #!/usr/bin/env bash
  # memory.sh — lint .woostack/memory; emit findings. Severities preserved from the
  # original doctor.sh (errors = malformed/missing-field/unknown-type/dup-name; the rest warn).
  set -uo pipefail
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  source "$HERE/../../../woostack-init/scripts/lib.sh"
  WOO_ROOT="${1:-.}"
  MEM_DIR="$WOO_ROOT/.woostack/memory"
  [ -d "$MEM_DIR" ] || exit 0   # no store → nothing to lint

  # emit <severity> <code> <fixable> <path> <message>
  emit() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5"; }
  err()  { emit error "$1" report "$2" "$3"; }
  warn() { emit warn  "$1" report "$2" "$3"; }
  ```
- [x] Move the body of the old `for f in "$MEM_DIR"/*.md` loop and the overlap-cluster `awk`
  block **verbatim**, rewriting each `err "<msg>"` / `warn "<msg>"` call to the 3-arg
  `err <code> <path> <msg>` / `warn <code> <path> <msg>` form, using these codes (path = `$base`,
  or `MEM_DIR` for the cluster line):
  - malformed fence → `err memory-malformed "$base" "..."`
  - missing name/type/body → `err memory-field "$base" "..."`
  - unknown type → `err memory-type "$base" "..."`
  - duplicate name → `err memory-dup "$base" "..."`
  - stale scope → `warn memory-scope-stale "$base" "..."`
  - missing/stale `source:` → `warn memory-provenance "$base" "..."`
  - non-glob scope → `warn memory-scope-trivia "$base" "..."`
  - unresolved `[[link]]` → `warn memory-unresolved-link "$base" "..."` (kept **warn**, as in the
    original, to avoid newly failing consumer CI; the spec's "structural=error" applies to the
    new checks, not this preserved behavior)
  - missing `updated:` → `warn memory-no-updated "$base" "..."`
  - dead note → `warn memory-dead "$base" "..."`
  - overlap cluster → `warn memory-overlap "$MEM_DIR" "..."`
  Drop the old trailing `echo "doctor: ... "` summary and the final `[ "$errors" -eq 0 ]` exit
  test — the orchestrator now owns aggregation and exit code. `checks/memory.sh` always exits 0
  (findings carry severity).

### Task 2.2: The orchestrator

**Files:**
- Modify: `skills/woostack-doctor/scripts/doctor.sh` (replace contents — it is now the orchestrator)

- [x] Replace `doctor.sh` with the orchestrator:
  ```bash
  #!/usr/bin/env bash
  # doctor.sh — woostack workspace health orchestrator. Runs checks/*.sh, groups
  # findings, exits nonzero iff any error. --check = CI mode (annotations + exit only).
  set -uo pipefail
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  CHECK_ONLY=0; TARGET="."
  for a in "$@"; do
    case "$a" in
      --check) CHECK_ONLY=1 ;;
      -*) echo "doctor: unknown flag: $a" >&2; exit 2 ;;
      *)  TARGET="$a" ;;
    esac
  done

  WOO_ROOT="$(cd "$TARGET" 2>/dev/null && pwd)" \
    || { echo "doctor: path not found: $TARGET" >&2; exit 2; }
  if [ ! -d "$WOO_ROOT/.woostack" ]; then
    echo "doctor: no .woostack/ at $WOO_ROOT — run woostack-init first" >&2
    exit 2
  fi

  findings="$(mktemp)"
  shopt -s nullglob
  for chk in "$HERE"/checks/*.sh; do
    bash "$chk" "$WOO_ROOT" >> "$findings" 2>/dev/null || true
  done

  errors=0; warnings=0
  TAB="$(printf '\t')"
  while IFS="$TAB" read -r sev code fixable path msg; do
    [ -z "${sev:-}" ] && continue
    case "$sev" in
      error) errors=$((errors+1)); echo "::error:: [$code] $path: $msg" >&2 ;;
      warn)  warnings=$((warnings+1)); echo "::warning:: [$code] $path: $msg" >&2 ;;
    esac
  done < "$findings"

  # Machine-readable dump for the interactive repair layer (suppressed in CI mode).
  [ "$CHECK_ONLY" -eq 0 ] && cat "$findings"
  rm -f "$findings"

  echo "doctor: $errors error(s), $warnings warning(s)" >&2
  [ "$errors" -eq 0 ]
  ```

### Task 2.3: Update the moved test to the contract; add orchestrator tests

**Files:**
- Modify: `skills/woostack-doctor/scripts/tests/test-doctor.sh`
- Create: `skills/woostack-doctor/scripts/tests/test-orchestrator.sh`

- [x] In `test-doctor.sh`, the memory-lint assertions still hold but the annotation lines now carry
  a `[code]` prefix. Where a test asserted `::warning::` + a message substring, it still passes
  (substring match). Add `WOO=` fixture wrapping: the engine now takes a repo root, so build
  fixtures as `$WOO/.woostack/memory/...` and call `bash "$DOCTOR" "$WOO"`. Update the harness
  helper calls accordingly (memory dir → `"$WOO/.woostack/memory"`).
- [x] Write `test-orchestrator.sh` (red first — orchestrator behaviors):
  ```bash
  #!/usr/bin/env bash
  set -uo pipefail
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  source "$HERE/../../../woostack-init/scripts/tests/assert.sh"
  DOCTOR="$HERE/../doctor.sh"

  # no .woostack → exit 2 with guidance
  empty="$(mktemp -d)"
  out="$(bash "$DOCTOR" "$empty" 2>&1)"; code=$?
  assert_exit 2 "$code" "missing .woostack exits 2"
  assert_contains "$out" "run woostack-init" "missing-workspace message points to init"

  # clean workspace → exit 0
  clean="$(mktemp -d)"; mkdir -p "$clean/.woostack/memory"
  bash "$DOCTOR" "$clean" >/dev/null 2>&1; assert_exit 0 "$?" "clean workspace exits 0"

  # an error finding → exit nonzero; a warn-only run → exit 0
  warnws="$(mktemp -d)"; mkdir -p "$warnws/.woostack/memory"
  printf -- '---\nname: n\ntype: gotcha\n---\nbody [[ghost]]\n' > "$warnws/.woostack/memory/n.md"
  bash "$DOCTOR" "$warnws" >/dev/null 2>&1; assert_exit 0 "$?" "warn-only exits 0"
  errws="$(mktemp -d)"; mkdir -p "$errws/.woostack/memory"
  printf 'no fence\n' > "$errws/.woostack/memory/bad.md"
  bash "$DOCTOR" "$errws" >/dev/null 2>&1; assert_exit 1 "$?" "error finding exits 1"

  # --check suppresses the stdout findings dump
  dump="$(bash "$DOCTOR" --check "$warnws" 2>/dev/null)"
  assert_eq "$dump" "" "--check suppresses machine dump on stdout"
  finish
  ```
- [x] Run the suite; iterate `memory.sh`/orchestrator until green:
  ```bash
  bash skills/woostack-doctor/scripts/tests/run-tests.sh
  ```
  Expected: `0 failed`.

---

## Increment 3: spec↔plan backlink check + repair

> independently shippable PR — the seed convention: lint + `--fix`. (AC3)

### Task 3.1: The check

**Files:**
- Create: `skills/woostack-doctor/scripts/checks/spec-plan-backlink.sh`

- [x] Write the check (diagnose default; `--fix <spec> <plan-basename>` apply path). It reuses the
  `status.sh` join (Source line → spec; else same-basename fallback) and requires the spec to carry
  a folder-qualified `[[plans/<plan-basename>]]`:
  ```bash
  #!/usr/bin/env bash
  # spec-plan-backlink.sh — every plan's source spec must carry [[plans/<plan-basename>]].
  # Calling convention (uniform across all checks):
  #   diagnose:  <check> <WOO_ROOT>
  #   repair:    <check> --fix <WOO_ROOT> <extra-args...>
  # $1 is overloaded (root or "--fix"), so mode MUST be resolved before deriving any path.
  set -uo pipefail
  emit() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5"; }

  if [ "${1:-}" = "--fix" ]; then
    # --fix <root> <spec> <plan-basename> : insert the callout after the first H1 (idempotent).
    spec="$3"; pbase="$4"
    grep -qF "[[plans/$pbase]]" "$spec" 2>/dev/null && exit 0
    awk -v line="> **Plan:** [[plans/$pbase]]" '
      {print} d==0 && /^# /{print ""; print line; d=1}' "$spec" > "$spec.t" \
      && mv "$spec.t" "$spec"
    exit $?
  fi
  WOO_ROOT="${1:-.}"

  # spec_for <plan-file> → absolute spec path (Source line, else same-basename), empty if none.
  spec_for() {
    local plan="$1" pbase src
    pbase="$(basename "$plan")"
    src="$(grep -m1 -E '^\*\*Source:\*\*' "$plan" 2>/dev/null | grep -oE 'specs/[^])[:space:]]+\.md' | head -1)"
    if [ -n "$src" ] && [ -f "$WOO_ROOT/.woostack/$src" ]; then
      printf '%s\n' "$WOO_ROOT/.woostack/$src"; return
    fi
    [ -f "$WOO_ROOT/.woostack/specs/$pbase" ] && printf '%s\n' "$WOO_ROOT/.woostack/specs/$pbase"
  }

  shopt -s nullglob
  for plan in "$WOO_ROOT"/.woostack/plans/*.md; do
    pbase="$(basename "$plan" .md)"
    spec="$(spec_for "$plan")"
    [ -z "$spec" ] && continue   # spec-less plan → memory/provenance checks own that
    grep -qF "[[plans/$pbase]]" "$spec" \
      || emit warn spec-plan-backlink auto "${spec#$WOO_ROOT/}" \
           "spec missing Obsidian backlink [[plans/$pbase]] to its plan"
  done
  ```

### Task 3.2: Tests

**Files:**
- Create: `skills/woostack-doctor/scripts/tests/test-spec-plan-backlink.sh`

- [x] Write the test (red first):
  ```bash
  #!/usr/bin/env bash
  set -uo pipefail
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  source "$HERE/../../../woostack-init/scripts/tests/assert.sh"
  CHK="$HERE/../checks/spec-plan-backlink.sh"

  mk() { # build a workspace with one spec+plan pair; echo root
    local root; root="$(mktemp -d)"; mkdir -p "$root/.woostack/specs" "$root/.woostack/plans"
    printf -- '---\nname: x\ntype: spec\n---\n\n# X — Design Spec\n\n## 1. Problem\n' > "$root/.woostack/specs/2026-06-13-x.md"
    printf -- '**Source:** .woostack/specs/2026-06-13-x.md\n\n# X Plan\n' > "$root/.woostack/plans/2026-06-13-x.md"
    printf '%s\n' "$root"
  }

  # isolated spec → finding
  r="$(mk)"
  out="$(bash "$CHK" "$r")"
  assert_contains "$out" "spec-plan-backlink" "isolated spec is flagged"
  assert_contains "$out" "[[plans/2026-06-13-x]]" "message names the expected backlink"

  # --fix inserts it; re-run clean; re-fix idempotent  (--fix <root> <spec> <pbase>)
  bash "$CHK" --fix "$r" "$r/.woostack/specs/2026-06-13-x.md" "2026-06-13-x"
  assert_contains "$(cat "$r/.woostack/specs/2026-06-13-x.md")" "> **Plan:** [[plans/2026-06-13-x]]" "fix inserts the callout"
  assert_eq "$(bash "$CHK" "$r")" "" "after fix, no finding"
  bash "$CHK" --fix "$r" "$r/.woostack/specs/2026-06-13-x.md" "2026-06-13-x"
  cnt="$(grep -cF "[[plans/2026-06-13-x]]" "$r/.woostack/specs/2026-06-13-x.md")"
  assert_eq "$cnt" "1" "fix is idempotent (no duplicate callout)"

  # slug-mismatch: plan Source names a differently-named spec
  r2="$(mktemp -d)"; mkdir -p "$r2/.woostack/specs" "$r2/.woostack/plans"
  printf -- '---\nname: y\ntype: spec\n---\n\n# Y\n' > "$r2/.woostack/specs/2026-06-13-y-long.md"
  printf -- '**Source:** .woostack/specs/2026-06-13-y-long.md\n\n# Y Plan\n' > "$r2/.woostack/plans/2026-06-13-y.md"
  assert_contains "$(bash "$CHK" "$r2")" "y-long.md" "slug-mismatch resolves via Source line"

  # spec-less plan → not flagged
  r3="$(mktemp -d)"; mkdir -p "$r3/.woostack/specs" "$r3/.woostack/plans"
  printf -- '**Source:** .woostack/specs/missing.md\n\n# Z Plan\n' > "$r3/.woostack/plans/2026-06-13-z.md"
  assert_eq "$(bash "$CHK" "$r3")" "" "spec-less plan is not flagged by this check"
  finish
  ```
- [x] Run; iterate until green:
  ```bash
  bash skills/woostack-doctor/scripts/tests/test-spec-plan-backlink.sh
  ```
  Expected: `0 failed`.

---

## Increment 4: Workspace-health checks (orphan worktree, gitignore drift, config keys)

> independently shippable PR — the broad-health checks, each with `--fix`. (AC4)

### Task 4.1: Orphan-worktree check

**Files:**
- Create: `skills/woostack-doctor/scripts/checks/orphan-worktree.sh`

- [x] Write it — flag dirs under `.woostack/worktrees/` not registered with git; `auto` only when
  prunable (clean), else `report`:
  ```bash
  #!/usr/bin/env bash
  # orphan-worktree.sh — flag worktree drift under .woostack/worktrees/. SAFE: the only
  # auto repair is `git worktree prune` (clears git's admin entries for already-gone dirs);
  # a present unregistered dir may hold uncommitted work, so it is always `report` (manual).
  set -uo pipefail
  emit() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5"; }

  if [ "${1:-}" = "--fix" ]; then
    # --fix <root> : prune stale registrations only. Never removes a present dir.
    ( cd "${2:-.}" && git worktree prune ) 2>/dev/null || true
    exit 0
  fi
  WOO_ROOT="${1:-.}"
  wt_dir="$WOO_ROOT/.woostack/worktrees"
  [ -d "$wt_dir" ] || exit 0

  registered="$(cd "$WOO_ROOT" && git worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2}')"
  # (a) present dir not registered → manual review (may hold work) = report
  shopt -s nullglob
  for d in "$wt_dir"/*/; do
    d="${d%/}"; abs="$(cd "$d" 2>/dev/null && pwd)" || continue
    case "$registered" in *"$abs"*) continue ;; esac
    emit warn orphan-worktree report "${d#$WOO_ROOT/}" "unregistered worktree dir (manual review/remove — may hold work)"
  done
  # (b) registered worktree whose dir is gone → stale registration = auto prune
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    case "$p" in "$wt_dir"/*) [ -d "$p" ] || emit warn orphan-worktree auto "${p#$WOO_ROOT/}" "stale worktree registration (git worktree prune)" ;; esac
  done <<< "$registered"
  ```

### Task 4.2: `.gitignore` drift check

**Files:**
- Create: `skills/woostack-doctor/scripts/checks/gitignore-drift.sh`

- [x] Write it — each shipped-template line absent from the consumer `.woostack/.gitignore` is a
  finding; `--fix` appends only the missing lines (per-line presence, no reorder):
  ```bash
  #!/usr/bin/env bash
  set -uo pipefail
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  TEMPLATE="$HERE/../../woostack-init/templates/gitignore"
  emit() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5"; }
  [ -f "$TEMPLATE" ] || exit 0

  if [ "${1:-}" = "--fix" ]; then FIX=1; WOO_ROOT="${2:-.}"; else FIX=0; WOO_ROOT="${1:-.}"; fi
  GI="$WOO_ROOT/.woostack/.gitignore"

  missing() { # echo template lines (non-blank, non-comment) absent from $GI
    while IFS= read -r line; do
      case "$line" in ''|\#*) continue ;; esac
      [ -f "$GI" ] && grep -qxF "$line" "$GI" && continue
      printf '%s\n' "$line"
    done < "$TEMPLATE"
  }

  if [ "$FIX" -eq 1 ]; then   # --fix <root> : append only the missing managed lines
    [ -f "$GI" ] || : > "$GI"
    while IFS= read -r line; do [ -n "$line" ] && printf '%s\n' "$line" >> "$GI"; done < <(missing)
    exit 0
  fi

  while IFS= read -r line; do
    [ -n "$line" ] && emit warn gitignore-drift auto ".woostack/.gitignore" "missing managed line: $line"
  done < <(missing)
  ```
  Note: `--fix` here re-runs `missing` against the *current* `$GI`, so it is idempotent.

### Task 4.3: `config.json` key-presence check

**Files:**
- Create: `skills/woostack-doctor/scripts/checks/config-keys.sh`

- [x] Write it — required keys = the keys in the shipped init `config.json` template; missing →
  finding; `--fix` adds the missing top-level key with its template default (jq when present, else a
  reported manual edit):
  ```bash
  #!/usr/bin/env bash
  set -uo pipefail
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  TEMPLATE="$HERE/../../woostack-init/templates/config.json"
  emit() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5"; }
  [ -f "$TEMPLATE" ] || exit 0
  command -v jq >/dev/null 2>&1 || exit 0   # key check needs jq; absent → skip silently

  if [ "${1:-}" = "--fix" ]; then FIX=1; WOO_ROOT="${2:-.}"; key="${3:-}"; else FIX=0; WOO_ROOT="${1:-.}"; fi
  CFG="$WOO_ROOT/.woostack/config.json"

  if [ "$FIX" -eq 1 ]; then
    # --fix <root> <key> : merge the template's value for <key> into CFG.
    [ -f "$CFG" ] || echo '{}' > "$CFG"
    val="$(jq -c --arg k "$key" '.[$k]' "$TEMPLATE")"
    tmp="$(mktemp)"; jq --arg k "$key" --argjson v "$val" '.[$k]=$v' "$CFG" > "$tmp" && mv "$tmp" "$CFG"
    exit $?
  fi

  req_keys="$(jq -r 'keys[]' "$TEMPLATE")"
  for k in $req_keys; do
    if [ ! -f "$CFG" ] || [ "$(jq --arg k "$k" 'has($k)' "$CFG" 2>/dev/null)" != "true" ]; then
      emit warn config-key auto ".woostack/config.json" "missing required config key: $k"
    fi
  done
  ```

### Task 4.4: Tests for the three health checks

**Files:**
- Create: `skills/woostack-doctor/scripts/tests/test-health-checks.sh`

- [x] Write the test (red first) covering each check's fire + clean + idempotent fix:
  ```bash
  #!/usr/bin/env bash
  set -uo pipefail
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  source "$HERE/../../../woostack-init/scripts/tests/assert.sh"
  C="$HERE/../checks"

  # gitignore-drift
  r="$(mktemp -d)"; mkdir -p "$r/.woostack"; : > "$r/.woostack/.gitignore"
  assert_contains "$(bash "$C/gitignore-drift.sh" "$r")" "gitignore-drift" "empty .gitignore drifts"
  bash "$C/gitignore-drift.sh" --fix "$r"
  assert_eq "$(bash "$C/gitignore-drift.sh" "$r")" "" "after fix, no drift"
  before="$(wc -l < "$r/.woostack/.gitignore")"; bash "$C/gitignore-drift.sh" --fix "$r"
  assert_eq "$(wc -l < "$r/.woostack/.gitignore")" "$before" "gitignore fix idempotent"

  # config-keys (skips cleanly when jq absent)
  if command -v jq >/dev/null 2>&1; then
    r2="$(mktemp -d)"; mkdir -p "$r2/.woostack"; echo '{}' > "$r2/.woostack/config.json"
    assert_contains "$(bash "$C/config-keys.sh" "$r2")" "config-key" "empty config missing keys"
    bash "$C/config-keys.sh" --fix "$r2" review
    bash "$C/config-keys.sh" --fix "$r2" status
    assert_eq "$(bash "$C/config-keys.sh" "$r2")" "" "after fixing all keys, clean"
  fi

  # orphan-worktree
  r3="$(mktemp -d)"; ( cd "$r3" && git init -q && git commit -q --allow-empty -m init )
  mkdir -p "$r3/.woostack/worktrees/ghost"
  assert_contains "$(bash "$C/orphan-worktree.sh" "$r3")" "orphan-worktree" "unregistered worktree dir flagged"
  finish
  ```
- [x] Run; iterate until green:
  ```bash
  bash skills/woostack-doctor/scripts/tests/test-health-checks.sh
  ```
  Expected: `0 failed`.

---

## Increment 5: Skill shell + gated repair layer

> independently shippable PR — the `SKILL.md` command surface + the propose→approve→apply→commit
> procedure that drives the `--fix` paths. (AC5)

### Task 5.1: `SKILL.md` and the check catalog reference

**Files:**
- Create: `skills/woostack-doctor/SKILL.md`
- Create: `skills/woostack-doctor/references/checks.md`

- [x] Write `SKILL.md` with: a concise `description:` (run-anytime diagnose + gated repair of
  `.woostack/`; the 17th command; never merges); the command forms `/woostack-doctor [path]`
  (default = diagnose then offer repair) and `/woostack-doctor [path] --check` (CI: diagnose-only,
  exit-coded); the procedure:
  1. Run the engine `bash <doctor>/scripts/doctor.sh [path]`; read the machine findings (stdout).
  2. Group `fixable=auto` findings into a **proposed changeset** (one line per repair: code, path,
     what will change). Present it.
  3. **HARD GATE:** mutate nothing until the user approves. `report`-only findings are listed as
     "manual / judgment" and never auto-applied.
  4. On approval: for each approved finding, invoke the owning check's `--fix` path. File repairs
     mutate the working tree; the filesystem-only repair (`orphan-worktree --fix`) runs directly.
  5. After file repairs, hand to [`woostack-commit`](../woostack-commit/SKILL.md) (fresh branch +
     PR; respects branch protection; **never merges**). Filesystem-only repairs need no commit.
  6. Re-run the engine to confirm clean; report residue.
  Hard constraints: never scaffold (absent `.woostack/` → tell user to run `woostack-init`); never
  reconcile the board (that is `woostack-status`); never curate memory content (that is
  `woostack-dream`); never auto-apply; never merge. Cross-link `conventions.md` for the spec↔plan
  join; do not restate it.
- [x] Write `references/checks.md`: a table of every check — `code`, what it flags, severity,
  `fixable` (auto/report), and the `--fix` contract. Link it from `SKILL.md`.

### Task 5.2: Repair-composition integration test

**Files:**
- Create: `skills/woostack-doctor/scripts/tests/test-repair-apply.sh`

- [x] Test that the diagnose→apply round-trip clears findings across all auto checks at once (the
  agent's apply loop, exercised mechanically — the `woostack-commit` handoff is asserted at the
  boundary, not by opening a real PR):
  ```bash
  #!/usr/bin/env bash
  set -uo pipefail
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  source "$HERE/../../../woostack-init/scripts/tests/assert.sh"
  D="$HERE/../doctor.sh"; C="$HERE/../checks"

  r="$(mktemp -d)"; ( cd "$r" && git init -q && git commit -q --allow-empty -m init )
  mkdir -p "$r/.woostack/specs" "$r/.woostack/plans" "$r/.woostack/memory"
  : > "$r/.woostack/.gitignore"
  printf -- '---\nname: x\ntype: spec\n---\n\n# X\n## 1. Problem\n' > "$r/.woostack/specs/2026-06-13-x.md"
  printf -- '**Source:** .woostack/specs/2026-06-13-x.md\n\n# X Plan\n' > "$r/.woostack/plans/2026-06-13-x.md"

  # diagnose: expect spec-plan-backlink + gitignore-drift (warn-only → exit 0)
  bash "$D" "$r" >/dev/null 2>&1; assert_exit 0 "$?" "warn-only diagnose exits 0"
  found="$(bash "$D" "$r" 2>/dev/null)"
  assert_contains "$found" "spec-plan-backlink" "backlink finding present pre-repair"
  assert_contains "$found" "gitignore-drift" "gitignore finding present pre-repair"

  # apply every auto fix (uniform: --fix <root> <extra...>), then confirm clean
  bash "$C/spec-plan-backlink.sh" --fix "$r" "$r/.woostack/specs/2026-06-13-x.md" "2026-06-13-x"
  bash "$C/gitignore-drift.sh" --fix "$r"
  residue="$(bash "$D" "$r" 2>/dev/null | grep -E 'spec-plan-backlink|gitignore-drift' || true)"
  assert_eq "$residue" "" "after applying auto fixes, those findings clear"
  finish
  ```
- [x] Run the full doctor suite green:
  ```bash
  bash skills/woostack-doctor/scripts/tests/run-tests.sh
  ```
  Expected: `0 failed`.

---

## Increment 6: Dogfood — born-linked spec template + backfill

> independently shippable PR — applies the convention to this repo: template gains the callout, all
> existing specs are backfilled, `doctor.sh` on `.woostack/` is clean for `spec-plan-backlink`. (AC6)

### Task 6.1: Spec template carries the backlink

**Files:**
- Modify: `skills/woostack-build/references/spec-template.md`

- [x] Add the callout below the existing `> status:` callout (use `{{DATE}}-{{SLUG}}`, the plan
  basename — **not** `{{SLUG}}` alone):
  ```
  > **Plan:** [[plans/{{DATE}}-{{SLUG}}]]
  ```
- [x] Verify the placeholder reconstructs the basename (the spec file is `{{DATE}}-{{SLUG}}.md`):
  ```bash
  grep -n "Plan:.*\[\[plans/{{DATE}}-{{SLUG}}\]\]" skills/woostack-build/references/spec-template.md
  ```
  Expected: one match.

### Task 6.2: Backfill every existing spec

**Files:**
- Modify: all `.woostack/specs/*.md` with a plan (40 same-basename + 3 slug-mismatch via Source)

- [x] Run the backfill (reuses the check's join + idempotent `--fix`):
  ```bash
  cd "$(git rev-parse --show-toplevel)"
  CHK=skills/woostack-doctor/scripts/checks/spec-plan-backlink.sh
  for plan in .woostack/plans/*.md; do
    pbase="$(basename "$plan" .md)"
    src="$(grep -m1 -E '^\*\*Source:\*\*' "$plan" | grep -oE 'specs/[^])[:space:]]+\.md' | head -1)"
    spec=".woostack/$src"; [ -f "$spec" ] || spec=".woostack/specs/$pbase.md"
    [ -f "$spec" ] || continue
    bash "$CHK" --fix . "$spec" "$pbase"   # --fix <root> <spec> <pbase>; root=. (repo cwd)
  done
  ```
- [x] Confirm the engine reports no `spec-plan-backlink` finding on the real store:
  ```bash
  bash skills/woostack-doctor/scripts/doctor.sh . 2>&1 | grep spec-plan-backlink ; echo "exit=$?"
  ```
  Expected: no matches (`exit=1`).
- [x] Spot-check one previously-isolated spec now carries the callout:
  ```bash
  grep -n "Plan:.*\[\[plans/2026-06-12-output-discipline\]\]" .woostack/specs/2026-06-12-output-discipline.md
  ```
  Expected: one match.

---

## Increment 7: Command surface — register the 17th command

> independently shippable PR — adoption surface + trim init's repair claim. (AC7)

### Task 7.1: AGENTS.md / CLAUDE.md

**Files:**
- Modify: `AGENTS.md` (the "sixteen skills" surface, file map, Modes B list)

- [x] Change "sixteen skills" → "seventeen skills" and add the
  [`woostack-doctor`](skills/woostack-doctor/SKILL.md) bullet to the command-surface list.
- [x] Add a Quick file map entry:
  ```
  - Workspace health (diagnose + gated repair) engine:
    [`skills/woostack-doctor/SKILL.md`](skills/woostack-doctor/SKILL.md)
  ```
- [x] Add `/woostack-doctor` to the Modes B command list. Note the engine move: the line about
  init "runs the index builder and store linter" now points at `woostack-doctor`'s engine.

### Task 7.2: using-woostack routing + init trim

**Files:**
- Modify: `skills/using-woostack/SKILL.md` (routing table)
- Modify: `skills/woostack-init/SKILL.md` (description + repair claim)

- [x] Add a `/woostack-doctor` row to the using-woostack routing table (intent: "check/repair my
  .woostack workspace health").
- [x] Trim `woostack-init`'s description/SKILL so its "repair" reads **scaffold-only** (create
  missing structure) and points to `woostack-doctor` for lint/repair of existing content.

### Task 7.3: Docs site nav + framing

**Files:**
- Modify: `site/` nav config + framing page listing the skills (locate with the grep below)

- [x] Find where the site enumerates skills and add `woostack-doctor`:
  ```bash
  grep -rln "woostack-dream\|woostack-tdd\|sixteen" site/ --include=*.ts --include=*.tsx --include=*.mdx --include=*.json
  ```
  Add the doctor entry to each match (nav + any authored framing list). Per-skill reference pages
  are generated from `SKILL.md`, so no page authoring is needed.
- [x] Confirm the surface count is consistent across the repo:
  ```bash
  grep -rn "sixteen skills\|sixteen public" . --include=*.md ; echo "exit=$?"
  ```
  Expected: no matches (`exit=1`) — all updated to seventeen.

---

## Self-review

- **Spec coverage:** AC1 → Inc 1 (move, no-stale-path test). AC2 → Inc 2 (orchestrator, exit codes,
  `--check`). AC3 → Inc 3 (backlink check + `--fix` + slug-mismatch + spec-less edges). AC4 → Inc 4
  (orphan worktree, gitignore drift, config keys + idempotent fixes). AC5 → Inc 5 (SKILL repair
  procedure + apply-composition test + commit-handoff boundary). AC6 → Inc 6 (template callout +
  backfill + clean run). AC7 → Inc 7 (AGENTS.md, using-woostack, site, init trim, count guard).
- **Severity reconciliation:** memory `unresolved-link` is preserved as `warn` (Inc 2) to avoid
  newly failing consumer CI; structural-breakage→error applies to the new checks. Noted in Inc 2.
- **Placeholder scan:** every step carries runnable code/commands + expected output. Large
  relocations (memory loop, overlap awk) are precise "move verbatim with these substitutions"
  instructions against named existing code, not placeholders.
- **Type/contract consistency:** the finding tuple `severity⇥code⇥fixable⇥path⇥message` is identical
  across the orchestrator, every check, and every test. The `--fix` calling convention is **uniform**
  — `<check> --fix <WOO_ROOT> <extra-args...>` — and every check resolves `--fix` mode *before*
  deriving any path, so `$1` is never mistaken for the root (the bug a naive `WOO_ROOT="${1:-.}"` +
  `[ "$1" = --fix ]` would cause). Call sites (Inc 3/5 tests, Inc 6 backfill) all pass the root.
- **Plan-harden refinements (step 6):** (1) orphan-worktree repair is **safe** — the only `auto`
  fix is `git worktree prune` (clears stale admin entries for already-gone dirs); a *present*
  unregistered dir is always `report` (may hold work), satisfying AC4's "never auto-prune work".
  (2) memory `unresolved-link` severity preserved as `warn`. (3) Inc 1's test edit touches only the
  `assert.sh` source line (vars are `DIR`/`DOC`; `DOC` already resolves post-move).
- **Dependency:** doctor sources `../../woostack-init/scripts/{lib,scope-match}.sh` and reads init's
  `templates/{gitignore,config.json}`; both ship in the same collection (siblings under `skills/`).
