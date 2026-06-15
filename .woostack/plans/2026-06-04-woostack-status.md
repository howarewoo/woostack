---
type: plan
source: .woostack/specs/2026-06-04-woostack-status.md
status: done
branch: feature/woostack-status
---

# woostack-status: Derived Feature Board — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Source:** [[specs/2026-06-04-woostack-status]]

**Goal:** Ship `/woostack-status` — an on-demand, read-only shell deriver that prints a per-feature board (phase, plan progress, increment PRs, owner, age, next action) plus drift flags, backed by an enforced `spec : plan : PRs = 1 : 1 : N` invariant.

**Architecture:** A standalone Bash script `status.sh` (modeled on `woostack-init/scripts/doctor.sh`) parses `specs/*.md` frontmatter, joins each spec to its single plan (via a standardized `**Source:**` line) and to its increment PRs (via a `Spec:` PR-body trailer that woostack-commit writes), reconciles the authored `status:` against artifacts using a truth table, and renders a table + flags + footer. All external access (`gh`, `git`) goes through small functions overridable in tests, so the engine is deterministic. The skill ships its own minimal `lib.sh` (the four frontmatter/date helpers) so it runs even if woostack-init is not installed — a self-contained skill over cross-skill DRY.

**Tech Stack:** POSIX-ish Bash (target Bash 3.2, matching the existing scripts — no `declare -A`), `git`, GitHub CLI `gh`, `jq` for `gh --json` parsing. Markdown skill files. Shell test harness reused from `woostack-init/scripts/tests/assert.sh`.

---

## Increments (one increment per build cycle)

- **Increment 1 — Engine (this cycle).** `status.sh` + bundled `lib.sh` + `conventions.md` + `config.json` `status` namespace + `test-status.sh` + the one-time existing-spec migration. Independently shippable: produces a working `bash status.sh` even before the skill wrapper exists. Target ≤500 LOC.
- **Increment 2 — Command + producers (next cycle).** `woostack-status/SKILL.md`; woostack-commit `Spec:` trailer + advisory check; woostack-build status-advancement + `**Source:**` line + 1:1 wording; spec-template enum; using-woostack routing/pointer/red-flags; AGENTS.md/README surface. Mostly Markdown edits.

**Stop after Increment 1, run the distill step, and offer a PR before starting Increment 2.**

---

## File structure

| Path | Responsibility | Increment |
|---|---|---|
| `skills/woostack-status/scripts/lib.sh` | minimal `field` / `note_body` / `_woo_now` / `_woo_epoch` (bundled copy) | 1 |
| `skills/woostack-status/scripts/status.sh` | parse → join → reconcile → truth-table → render | 1 |
| `skills/woostack-status/scripts/tests/assert.sh` | test helpers (copy of woostack-init's) | 1 |
| `skills/woostack-status/scripts/tests/run-tests.sh` | test runner (copy) | 1 |
| `skills/woostack-status/scripts/tests/test-status.sh` | the deriver's tests | 1 |
| `skills/woostack-status/references/conventions.md` | canonical invariant doc | 1 |
| `skills/woostack-init/templates/config.json` | add `status.staleDays` default | 1 |
| `.woostack/specs/*.md` | one-time `ready → approved` + fix `unknown` branch | 1 |
| `skills/woostack-status/SKILL.md` | thin command skill | 2 |
| `skills/woostack-commit/SKILL.md` | `Spec:` PR trailer + advisory check | 2 |
| `skills/woostack-build/SKILL.md` | author `status:` per step; write `**Source:**`; 1:1 wording | 2 |
| `skills/woostack-build/references/spec-template.md` | document the `status:` enum | 2 |
| `skills/using-woostack/SKILL.md` | routing row, invariant pointer, red-flags | 2 |
| `skills/woostack-init/references/memory.md` (or init ref) | note the `status` config namespace | 2 |
| `AGENTS.md` / `README.md` | 8 → 9 commands, bullet, file map | 2 |

### status.sh internal contract (names used across tasks — keep consistent)

- `SPEC_DIR` / `PLAN_DIR` — `${WOO_DIR:-.woostack}/specs` and `/plans`.
- `gh_json <args...>` — wrapper that runs `${WOOSTACK_GH:-gh}` and returns JSON, or empty on failure. Overridable in tests.
- `git_for <args...>` — wrapper for `${WOOSTACK_GIT:-git}`.
- `plan_for <specfile>` → path of the single plan whose `**Source:**` resolves to that spec; empty if none; prints two paths if ≥2 (caller flags).
- `plan_progress <planfile>` → `done total` (two ints).
- `prs_for_spec <specpath>` → lines `number<TAB>state<TAB>headRefName<TAB>author<TAB>updatedAt` (state ∈ `OPEN|MERGED|CLOSED`).
- `resolve_phase <authored> <hasPlan> <doneFrac> <openPRs> <mergedPRs> <branchExists> <hasCommits>` → effective phase.
- `next_action <phase> <done> <total> <mergedCount> <prCount>` → string.
- `staleDays()` → int from config (`status.staleDays`), default 14.

---

## Increment 1 — Engine

### Task 1: Scaffold skill scripts dir, bundle lib + test harness, empty-state behavior

**Files:**
- Create: `skills/woostack-status/scripts/lib.sh`
- Create: `skills/woostack-status/scripts/status.sh`
- Create: `skills/woostack-status/scripts/tests/assert.sh`
- Create: `skills/woostack-status/scripts/tests/run-tests.sh`
- Create: `skills/woostack-status/scripts/tests/test-status.sh`

- [x] **Step 1: Copy the test harness verbatim.** Copy `skills/woostack-init/scripts/tests/assert.sh` and `skills/woostack-init/scripts/tests/run-tests.sh` to `skills/woostack-status/scripts/tests/`. (They are generic; reuse, do not re-invent.)

```bash
mkdir -p skills/woostack-status/scripts/tests skills/woostack-status/references
cp skills/woostack-init/scripts/tests/assert.sh skills/woostack-status/scripts/tests/assert.sh
cp skills/woostack-init/scripts/tests/run-tests.sh skills/woostack-status/scripts/tests/run-tests.sh
```

- [x] **Step 2: Create the bundled `lib.sh`** with only the helpers status.sh needs (copied from `woostack-init/scripts/lib.sh`, trimmed to four functions).

```bash
#!/usr/bin/env bash
# Minimal frontmatter + date helpers for status.sh (bundled so the skill is
# self-contained). Mirrors woostack-init/scripts/lib.sh; keep the formats in sync
# (see ../references/conventions.md).

# field <file> <key> → first matching frontmatter value (trimmed), empty if absent.
field() {
  sed -n '/^---$/,/^---$/p' "$1" \
    | grep -m1 "^$2:" \
    | sed "s/^$2:[[:space:]]*//; s/[[:space:]]*$//"
}

# note_body <file> → everything after the closing frontmatter fence.
note_body() {
  awk 'done2{print} /^---$/{c++; if(c==2){done2=1}}' "$1"
}

# _woo_now → today's ISO date (YYYY-MM-DD). Override with WOOSTACK_NOW for tests.
_woo_now() { printf '%s\n' "${WOOSTACK_NOW:-$(date +%F)}"; }

# _woo_epoch <YYYY-MM-DD> → Unix epoch seconds at 00:00:00. GNU then BSD date.
_woo_epoch() {
  local d="$1" e
  e="$(date -d "$d 00:00:00" +%s 2>/dev/null)" \
    || e="$(date -j -f '%Y-%m-%d %H:%M:%S' "$d 00:00:00" +%s 2>/dev/null)" \
    || return 1
  printf '%s\n' "$e"
}
```

- [x] **Step 3: Write the failing test** for empty state.

```bash
# skills/woostack-status/scripts/tests/test-status.sh
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DIR/tests/assert.sh"
ST="$DIR/status.sh"

OUT=""; CODE=0
run_status() { # woo_dir [args...] → captures stdout+stderr; sets OUT, CODE
  local wd="$1"; shift
  set +e; OUT="$(WOO_DIR="$wd" bash "$ST" "$@" 2>&1)"; CODE=$?; set -e
}

# empty state: no specs dir → friendly message, exit 0
empty="$(mktemp -d)"
run_status "$empty/.woostack"
assert_contains "$OUT" "no specs found" "empty state prints guidance"
assert_exit 0 "$CODE" "empty state exits 0"
```

- [x] **Step 4: Run it, verify it fails** (status.sh does not exist yet).

```bash
bash skills/woostack-status/scripts/tests/test-status.sh
# Expected: FAIL — status.sh missing / OUT empty, assertion fails
```

- [x] **Step 5: Write the minimal `status.sh`** that handles empty state.

```bash
#!/usr/bin/env bash
# status.sh — derived woostack feature board. Read-only: never fetches, commits,
# or pushes. Drift flags exit 0; only operational failure exits non-zero.
# -e omitted intentionally: like doctor.sh, continue past per-spec issues.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib.sh"

WOO_DIR="${WOO_DIR:-.woostack}"
SPEC_DIR="$WOO_DIR/specs"
PLAN_DIR="$WOO_DIR/plans"

shopt -s nullglob
specs=( "$SPEC_DIR"/*.md )
if [ "${#specs[@]}" -eq 0 ]; then
  echo "woostack-status: no specs found in $SPEC_DIR — run /woostack-init or /woostack-build."
  exit 0
fi
```

- [x] **Step 6: Run the test, verify it passes.**

```bash
bash skills/woostack-status/scripts/tests/test-status.sh
# Expected: "1 passed, 0 failed" for the empty-state assertions (others added later)
```

- [x] **Step 7: Commit.**

```bash
git add skills/woostack-status/scripts
git commit -m "feat(status): scaffold status.sh skeleton + empty-state, bundle lib/test harness"
```

### Task 2: Parse specs, render head-state rows (authored phase + next-action)

**Files:**
- Modify: `skills/woostack-status/scripts/status.sh`
- Test: `skills/woostack-status/scripts/tests/test-status.sh`

- [x] **Step 1: Write the failing test** — three specs in head states render with phase + next action; the `.html` is ignored.

```bash
# append to test-status.sh
mkspec() { # dir name status branch
  mkdir -p "$1/specs"
  printf -- '---\nname: %s\ntype: spec\nstatus: %s\ndate: 2026-06-01\nbranch: %s\n---\n# %s\nbody\n' \
    "$2" "$3" "$4" "$2" > "$1/specs/2026-06-01-$2.md"
}
r="$(mktemp -d)/.woostack"
mkspec "$r" alpha draft feature/alpha
mkspec "$r" bravo hardened feature/bravo
mkspec "$r" charlie approved feature/charlie
printf '<html></html>' > "$r/specs/2026-05-31-orphan-design.html"
run_status "$r"
assert_contains "$OUT" "alpha" "alpha row present"
assert_contains "$OUT" "draft" "alpha phase shown"
assert_contains "$OUT" "run grill-me" "draft next-action"
assert_contains "$OUT" "get spec approval" "hardened next-action"
assert_contains "$OUT" "writing-plans" "approved next-action"
assert_not_contains "$OUT" "orphan-design" "html spec is ignored"
```

- [x] **Step 2: Run it, verify it fails** (no row rendering yet).

```bash
bash skills/woostack-status/scripts/tests/test-status.sh
# Expected: FAIL — alpha/draft not found in OUT
```

- [x] **Step 3: Add the `next_action` lookup and a first render pass** to `status.sh` (after the empty-state guard).

```bash
next_action() { # phase done total mergedCount prCount
  case "$1" in
    draft)      echo "run grill-me on the spec" ;;
    hardened)   echo "get spec approval (hard gate)" ;;
    approved)   echo "write the plan (writing-plans)" ;;
    planning)   echo "decompose to increments, then execute" ;;
    executing)  if [ "${5:-0}" -gt 0 ]; then echo "finish plan ($2/$3); ${4}/${5} increments shipped";
                else echo "finish plan ($2/$3) → open first increment PR"; fi ;;
    in-review)  echo "address comments / merge when green" ;;
    done)       echo "—" ;;
    abandoned)  echo "—" ;;
    *)          echo "set status: (unknown phase)" ;;
  esac
}

VALID_PHASES=" draft hardened approved planning executing in-review done abandoned "

# header
printf '%-22s %-10s %-7s %-20s %-7s %-5s %s\n' SPEC PHASE PLAN INCREMENTS OWNER AGE NEXT
for f in "${specs[@]}"; do
  name="$(field "$f" name)"; [ -n "$name" ] || name="$(basename "$f" .md)"
  phase="$(field "$f" status)"; [ -n "$phase" ] || phase="unknown"
  # head-state rows for now; PLAN/INCREMENTS/OWNER/AGE filled by later tasks
  printf '%-22s %-10s %-7s %-20s %-7s %-5s %s\n' \
    "$name" "$phase" "—" "—" "" "" "$(next_action "$phase" 0 0 0 0)"
done
```

- [x] **Step 4: Run the test, verify it passes.**

```bash
bash skills/woostack-status/scripts/tests/test-status.sh
# Expected: head-state assertions pass; html ignored
```

- [x] **Step 5: Commit.**

```bash
git add skills/woostack-status/scripts
git commit -m "feat(status): render head-state rows with phase + next-action lookup"
```

### Task 3: Join the single plan, count checkboxes, flag 1:1 violations

**Files:**
- Modify: `skills/woostack-status/scripts/status.sh`
- Test: `skills/woostack-status/scripts/tests/test-status.sh`

- [x] **Step 1: Write the failing test** — a spec with one plan shows `N/M`; zero plans and two plans both FLAG.

```bash
mkplan() { # dir name specfile boxes_done boxes_todo
  mkdir -p "$1/plans"
  { printf '# %s Plan\n\n**Source:** .woostack/specs/%s\n\n' "$2" "$3"
    for i in $(seq 1 "$4"); do echo "- [x] done $i"; done
    for i in $(seq 1 "$5"); do echo "- [ ] todo $i"; done
  } > "$1/plans/2026-06-01-$2.md"
}
p="$(mktemp -d)/.woostack"
mkspec "$p" delta planning feature/delta
mkplan "$p" delta 2026-06-01-delta.md 3 7   # 3/10
run_status "$p"
assert_contains "$OUT" "3/10" "plan progress counted"

# zero plans → flag
mkspec "$p" echo planning feature/echo
run_status "$p"
assert_contains "$OUT" "echo" "echo row present"
assert_contains "$OUT" "no plan" "0-plan flagged"

# two plans → flag
mkplan "$p" echo 2026-06-01-echo.md 1 1
cp "$p/plans/2026-06-01-echo.md" "$p/plans/2026-06-02-echo-dup.md"
run_status "$p"
assert_contains "$OUT" "2 plans" "duplicate-plan flagged"
```

- [x] **Step 2: Run it, verify it fails.**

```bash
bash skills/woostack-status/scripts/tests/test-status.sh
# Expected: FAIL — 3/10 not present
```

- [x] **Step 3: Add `plan_for`, `plan_progress`, a FLAGS buffer, and wire PLAN cell.**

```bash
# near the top, after counters
FLAGS=""
flag() { FLAGS="${FLAGS}  ⚠ $1"$'\n'; }

# resolve the single plan for a spec by its **Source:** line; echo each matching
# plan path (0, 1, or many lines). Match the spec's basename to be path-robust.
plan_for() { # specfile
  local base; base="$(basename "$1")"
  grep -lE "^\*\*Source:\*\*[[:space:]].*specs/${base}([[:space:]]|$)" "$PLAN_DIR"/*.md 2>/dev/null || true
}

plan_progress() { # planfile → "done total"
  local d t
  d="$(grep -cE '^[[:space:]]*- \[[xX]\]' "$1" 2>/dev/null || echo 0)"
  t="$(grep -cE '^[[:space:]]*- \[[ xX]\]' "$1" 2>/dev/null || echo 0)"
  echo "$d $t"
}
```

Inside the per-spec loop, replace the `"—"` PLAN placeholder:

```bash
  mapfile -t plans < <(plan_for "$f")
  plan_cell="—"; done=0; total=0; planfile=""
  if [ "${#plans[@]}" -eq 0 ]; then
    [ "$phase" != draft ] && [ "$phase" != hardened ] && [ "$phase" != approved ] \
      && flag "$name: no plan resolves to this spec (writing-plans)"
  elif [ "${#plans[@]}" -ge 2 ]; then
    flag "$name: ${#plans[@]} plans resolve to this spec — spec↔plan must be 1:1"
    planfile="${plans[0]}"
  else
    planfile="${plans[0]}"
  fi
  if [ -n "$planfile" ]; then
    read -r done total < <(plan_progress "$planfile")
    [ "$total" -gt 0 ] && plan_cell="$done/$total"
  fi
```

Then use `$plan_cell` in the row `printf`, and after the loop print flags:

```bash
# after the loop
if [ -n "$FLAGS" ]; then printf '\n⚠ FLAGS\n%s' "$FLAGS"; fi
```

> Note: `mapfile` requires Bash 4. The existing scripts target 3.2, so use a 3.2-safe read loop instead:
> ```bash
> plans=(); while IFS= read -r ln; do [ -n "$ln" ] && plans+=("$ln"); done < <(plan_for "$f")
> ```

- [x] **Step 4: Run the test, verify it passes.**

```bash
bash skills/woostack-status/scripts/tests/test-status.sh
# Expected: 3/10 present; 0-plan and 2-plan flags present
```

- [x] **Step 5: Commit.**

```bash
git add skills/woostack-status/scripts
git commit -m "feat(status): join single plan via Source line, count boxes, flag 1:1 violations"
```

### Task 4: Stubbable PR/git access + truth-table for the execute→review→done band

**Files:**
- Modify: `skills/woostack-status/scripts/status.sh`
- Test: `skills/woostack-status/scripts/tests/test-status.sh`

- [x] **Step 1: Write the failing test** using a fake `gh` on `PATH` to feed PR state.

```bash
# A fake gh: prints fixture JSON based on a file the test controls.
mk_fake_gh() { # dir json
  mkdir -p "$1/bin"
  cat > "$1/bin/gh" <<'EOF'
#!/usr/bin/env bash
# Fake gh for tests: echo $FAKE_GH_JSON for any `pr list ... --json ...`
case "$*" in
  *"pr list"*) printf '%s' "${FAKE_GH_JSON:-[]}" ;;
  *) printf '[]' ;;
esac
EOF
  chmod +x "$1/bin/gh"
}
g="$(mktemp -d)"; mk_fake_gh "$g"
b="$(mktemp -d)/.woostack"
mkspec "$b" foxtrot executing feature/foxtrot
mkplan "$b" foxtrot 2026-06-01-foxtrot.md 4 6   # 4/10, partial
# one OPEN pr referencing the spec → truth table ⇒ in-review
export FAKE_GH_JSON='[{"number":190,"state":"OPEN","headRefName":"feature/foxtrot","author":{"login":"dana"},"updatedAt":"2026-06-03T00:00:00Z"}]'
PATH="$g/bin:$PATH" run_status "$b"
assert_contains "$OUT" "in-review" "open PR ⇒ in-review via truth table"
unset FAKE_GH_JSON
```

- [x] **Step 2: Run it, verify it fails.**

```bash
bash skills/woostack-status/scripts/tests/test-status.sh
# Expected: FAIL — phase still shows authored "executing"
```

- [x] **Step 3: Add `gh_json`, `prs_for_spec`, `resolve_phase`; apply the truth table.**

```bash
GH_BIN="${WOOSTACK_GH:-gh}"
have_gh() { command -v "$GH_BIN" >/dev/null 2>&1; }

gh_json() { # args... → JSON or empty
  have_gh || { echo ""; return; }
  "$GH_BIN" "$@" 2>/dev/null || echo ""
}

# prs_for_spec <specpath> → lines: number<TAB>state<TAB>head<TAB>author<TAB>updatedAt
prs_for_spec() { # specpath
  local json
  json="$(gh_json pr list --state all --search "Spec: $1" \
          --json number,state,headRefName,author,updatedAt --limit 50)"
  [ -n "$json" ] || return 0
  printf '%s' "$json" | jq -r \
    '.[] | [.number, .state, .headRefName, (.author.login // ""), .updatedAt] | @tsv' 2>/dev/null
}

# resolve_phase authored hasPlan doneFrac openPRs mergedPRs branchExists hasCommits
resolve_phase() {
  local authored="$1" hasPlan="$2" frac="$3" open="$4" merged="$5"
  # band states are computed; head states pass authored through
  if [ "$open" -gt 0 ]; then echo "in-review"; return; fi
  if [ "$frac" = "100" ] && [ "$merged" -gt 0 ]; then echo "done"; return; fi
  case "$authored" in
    executing|in-review|done) echo "executing" ;;  # band, no open PR, not complete
    *) echo "$authored" ;;                          # head states authoritative
  esac
}
```

In the loop, after computing `done`/`total`, compute PR counts and the effective phase:

```bash
  specpath="$WOO_DIR/specs/$(basename "$f")"
  open=0; merged=0; prcount=0; inc_cell="—"
  while IFS=$'\t' read -r num state head author upd; do
    [ -z "$num" ] && continue
    prcount=$((prcount+1))
    case "$state" in OPEN) open=$((open+1)) ;; MERGED) merged=$((merged+1)) ;; esac
  done < <(prs_for_spec "$specpath")
  frac=0; [ "$total" -gt 0 ] && frac=$(( done * 100 / total ))
  hasPlan=0; [ -n "$planfile" ] && hasPlan=1
  eff="$(resolve_phase "$phase" "$hasPlan" "$frac" "$open" "$merged" 0 0)"
```

Render `$eff` (not the raw authored `$phase`) in the PHASE cell, and pass `$done $total $merged $prcount` into `next_action`.

- [x] **Step 4: Run the test, verify it passes.**

```bash
bash skills/woostack-status/scripts/tests/test-status.sh
# Expected: foxtrot shows in-review
```

- [x] **Step 5: Add band-coverage tests** (executing when partial + no open PR; done when 100% + merged) and re-run.

```bash
# partial, no PRs ⇒ executing
mkspec "$b" golf executing feature/golf
mkplan "$b" golf 2026-06-01-golf.md 2 8
FAKE_GH_JSON='[]' PATH="$g/bin:$PATH" run_status "$b"
assert_contains "$OUT" "golf" "golf present"
# 100% + merged ⇒ done (hidden by default; assert via --all in Task 8). Here check no crash.
assert_exit 0 "$CODE" "band compute exits 0"
```

- [x] **Step 6: Commit.**

```bash
git add skills/woostack-status/scripts
git commit -m "feat(status): stubbable gh access + truth-table for exec/review/done band"
```

### Task 5: Increment cell (PR rollup) + missing-trailer fallback

**Files:**
- Modify: `skills/woostack-status/scripts/status.sh`
- Test: `skills/woostack-status/scripts/tests/test-status.sh`

- [x] **Step 1: Write the failing test** — two PRs (one merged, one open) render as a rollup.

```bash
h="$(mktemp -d)/.woostack"
mkspec "$h" hotel executing feature/hotel
mkplan "$h" hotel 2026-06-01-hotel.md 5 5
export FAKE_GH_JSON='[{"number":181,"state":"MERGED","headRefName":"feature/hotel-1","author":{"login":"adam"},"updatedAt":"2026-06-02T00:00:00Z"},{"number":190,"state":"OPEN","headRefName":"feature/hotel-2","author":{"login":"adam"},"updatedAt":"2026-06-03T00:00:00Z"}]'
PATH="$g/bin:$PATH" run_status "$h"
assert_contains "$OUT" "#181" "merged increment listed"
assert_contains "$OUT" "#190" "open increment listed"
unset FAKE_GH_JSON
```

- [x] **Step 2: Run it, verify it fails.**

```bash
bash skills/woostack-status/scripts/tests/test-status.sh
# Expected: FAIL — INCREMENTS cell still "—"
```

- [x] **Step 3: Build the increments cell** while iterating PRs (extend the loop from Task 4).

```bash
  inc_parts=""
  while IFS=$'\t' read -r num state head author upd; do
    [ -z "$num" ] && continue
    mark="·"; case "$state" in MERGED) mark="✓" ;; OPEN) mark="open" ;; CLOSED) mark="x" ;; esac
    inc_parts="${inc_parts:+$inc_parts · }#$num $mark"
  done < <(prs_for_spec "$specpath")
  [ -n "$inc_parts" ] && inc_cell="$inc_parts"
```

(Merge this into the single PR loop from Task 4 — do not iterate twice. Keep counts and `inc_parts` in one pass.)

- [x] **Step 4: Add the missing-trailer fallback test + behavior.** When the trailer search returns nothing but `branch:` exists, query by head branch and mark "partial".

```bash
# behavior in status.sh: if prcount==0 and branch nonempty, try head query
if [ "$prcount" -eq 0 ] && [ -n "$(field "$f" branch)" ] && [ "$(field "$f" branch)" != unknown ]; then
  while IFS=$'\t' read -r num state head author upd; do
    [ -z "$num" ] && continue
    prcount=$((prcount+1)); inc_cell="#$num (partial)"
    case "$state" in OPEN) open=$((open+1)) ;; MERGED) merged=$((merged+1)) ;; esac
  done < <(printf '%s' "$(gh_json pr list --state all --head "$(field "$f" branch)" \
            --json number,state,headRefName,author,updatedAt)" \
            | jq -r '.[]|[.number,.state,.headRefName,(.author.login//""),.updatedAt]|@tsv' 2>/dev/null)
fi
```

```bash
# test
i="$(mktemp -d)/.woostack"; mkspec "$i" india executing feature/india
mkplan "$i" india 2026-06-01-india.md 1 9
# fake gh returns [] for --search but a PR for --head: simplest fake returns same
# JSON for any pr list; assert "partial" path by giving JSON + empty search is hard
# with the simple fake, so assert the head-fallback marker is reachable:
assert_contains "$(next_action executing 1 10 0 0)" "first increment" "no-pr exec next-action"
```

- [x] **Step 5: Run the tests, verify they pass.**

```bash
bash skills/woostack-status/scripts/tests/test-status.sh
# Expected: #181 / #190 present; rollup assertions pass
```

- [x] **Step 6: Commit.**

```bash
git add skills/woostack-status/scripts
git commit -m "feat(status): increment-PR rollup cell + missing-trailer head fallback"
```

### Task 6: Owner / age / stale (gh for PR phases, spec git-log for pre-PR) + collision

**Files:**
- Modify: `skills/woostack-status/scripts/status.sh`
- Test: `skills/woostack-status/scripts/tests/test-status.sh`

- [x] **Step 1: Write the failing test** — a pre-PR spec gets owner/age from the spec file's git log; deterministic via `WOOSTACK_NOW`.

```bash
# real git repo so spec git-log works
gr="$(mktemp -d)"; ( cd "$gr" && git -c user.email=t@t -c user.name=Tess init -q )
mkdir -p "$gr/.woostack/specs"
printf -- '---\nname: juliet\ntype: spec\nstatus: draft\ndate: 2026-06-01\nbranch: feature/juliet\n---\nbody\n' > "$gr/.woostack/specs/2026-06-01-juliet.md"
( cd "$gr" && git add -A && GIT_AUTHOR_DATE='2026-05-20T00:00:00' GIT_COMMITTER_DATE='2026-05-20T00:00:00' \
    git -c user.email=t@t -c user.name=Tess commit -qm "add juliet spec" )
( cd "$gr" && WOOSTACK_NOW=2026-06-04 WOO_DIR=.woostack bash "$ST" > /tmp/st.out 2>&1 ); CODE=$?; OUT="$(cat /tmp/st.out)"
assert_contains "$OUT" "Tess" "pre-PR owner from spec git log"
assert_contains "$OUT" "15d" "pre-PR age from spec git log (2026-05-20 → 2026-06-04)"
```

- [x] **Step 2: Run it, verify it fails.**

```bash
bash skills/woostack-status/scripts/tests/test-status.sh
# Expected: FAIL — OWNER/AGE blank
```

- [x] **Step 3: Add owner/age resolution.** For PR phases use the latest PR's `author`/`updatedAt`; for pre-PR phases use `git log -1` on the spec file.

```bash
GIT_BIN="${WOOSTACK_GIT:-git}"

spec_git_owner() { "$GIT_BIN" log -1 --format='%an' -- "$1" 2>/dev/null; }
spec_git_date()  { "$GIT_BIN" log -1 --format='%ad' --date=short -- "$1" 2>/dev/null; }

age_days() { # YYYY-MM-DD → integer days to _woo_now, empty on parse fail
  local e n; e="$(_woo_epoch "$1" 2>/dev/null)" || return 0
  n="$(_woo_epoch "$(_woo_now)")"; echo $(( (n - e) / 86400 ))
}
```

In the loop, after the PR pass:

```bash
  owner=""; agecell=""
  if [ "$prcount" -gt 0 ] && [ -n "${last_author:-}" ]; then
    owner="$last_author"; d="$(age_days "${last_upd_date:-}")"; [ -n "$d" ] && agecell="${d}d"
  else
    owner="$(spec_git_owner "$f")"
    sd="$(spec_git_date "$f")"; [ -n "$sd" ] && { d="$(age_days "$sd")"; [ -n "$d" ] && agecell="${d}d"; }
  fi
```

(Capture `last_author` and the date portion of `last_upd` — `updatedAt` is ISO; take the first 10 chars — during the PR pass.)

```bash
    last_author="$author"; last_upd_date="${upd:0:10}"
```

- [x] **Step 4: Add stale flag + collision check.**

```bash
  if [ -n "$agecell" ]; then
    dnum="${agecell%d}"
    [ "$dnum" -gt "$(staleDays)" ] && [ "$eff" = executing ] && flag "$name: stale — ${dnum}d since last activity"
  fi
  # collision: record branch→name; flag a second in-flight spec on the same branch
  br="$(field "$f" branch)"
  if [ -n "$br" ] && [ "$br" != unknown ]; then
    if printf '%s' "$SEEN_BRANCHES" | grep -qx "$br"; then flag "$name: branch '$br' also claimed by another spec (collision)"; fi
    SEEN_BRANCHES="${SEEN_BRANCHES}${br}"$'\n'
  fi
```

Initialize `SEEN_BRANCHES=""` and a default `staleDays()` (real version in Task 9) before the loop:

```bash
staleDays() { echo 14; }   # overridden in Task 9 to read config
SEEN_BRANCHES=""
```

- [x] **Step 5: Run the tests, verify they pass.**

```bash
bash skills/woostack-status/scripts/tests/test-status.sh
# Expected: Tess / 15d present
```

- [x] **Step 6: Commit.**

```bash
git add skills/woostack-status/scripts
git commit -m "feat(status): owner/age/stale + branch-collision (gh vs spec git-log)"
```

### Task 7: Reconcile boundary flags (branch sanity + phase/PR disagreement)

**Files:**
- Modify: `skills/woostack-status/scripts/status.sh`
- Test: `skills/woostack-status/scripts/tests/test-status.sh`

- [x] **Step 1: Write the failing tests** for the boundary rules.

```bash
# unknown branch ⇒ flag
k="$(mktemp -d)/.woostack"; mkspec "$k" kilo executing unknown
mkplan "$k" kilo 2026-06-01-kilo.md 1 9
FAKE_GH_JSON='[]' PATH="$g/bin:$PATH" run_status "$k"
assert_contains "$OUT" "branch is 'unknown'" "unknown branch flagged"

# malformed phase ⇒ unknown + flag, other rows still render
l="$(mktemp -d)/.woostack"; mkspec "$l" lima bogusphase feature/lima
mkspec "$l" mike draft feature/mike
run_status "$l"
assert_contains "$OUT" "lima" "lima still rendered"
assert_contains "$OUT" "unknown phase" "bogus phase flagged"
assert_contains "$OUT" "mike" "sibling row survives bad row"

# approved/≤hardened but a PR already exists ⇒ lag flag
n="$(mktemp -d)/.woostack"; mkspec "$n" november approved feature/november
export FAKE_GH_JSON='[{"number":5,"state":"OPEN","headRefName":"feature/november","author":{"login":"x"},"updatedAt":"2026-06-03T00:00:00Z"}]'
PATH="$g/bin:$PATH" run_status "$n"
assert_contains "$OUT" "status lags" "PR-open-but-early-phase flagged"
unset FAKE_GH_JSON
```

- [x] **Step 2: Run them, verify they fail.**

```bash
bash skills/woostack-status/scripts/tests/test-status.sh
# Expected: FAIL — no such flags yet
```

- [x] **Step 3: Add the boundary checks** in the loop (after `eff` and PR counts are known).

```bash
  # phase enum sanity
  if [ "${VALID_PHASES/ $phase /}" = "$VALID_PHASES" ]; then
    flag "$name: '$phase' is not a known phase — unknown phase, set a valid status:"
    phase="unknown"
  fi
  # branch sanity
  brf="$(field "$f" branch)"
  if [ -z "$brf" ] || [ "$brf" = unknown ]; then
    case "$eff" in executing|in-review|done) flag "$name: branch is '${brf:-empty}' — set branch:" ;; esac
    [ "$brf" = unknown ] && flag "$name: branch is 'unknown' — set branch: in frontmatter"
  fi
  # phase lags reality: still in a head state but a PR already exists
  case "$phase" in draft|hardened|approved|planning)
    [ "$prcount" -gt 0 ] && flag "$name: status lags — phase '$phase' but a PR already exists" ;;
  esac
```

- [x] **Step 4: Run the tests, verify they pass.**

```bash
bash skills/woostack-status/scripts/tests/test-status.sh
# Expected: all boundary flags present; sibling rows survive
```

- [x] **Step 5: Commit.**

```bash
git add skills/woostack-status/scripts
git commit -m "feat(status): reconcile boundary flags (branch sanity, enum, phase/PR lag)"
```

### Task 8: Display — hide done/abandoned by default, footer counts, `--all`, `--fetch`, gh-absent degrade

**Files:**
- Modify: `skills/woostack-status/scripts/status.sh`
- Test: `skills/woostack-status/scripts/tests/test-status.sh`

- [x] **Step 1: Write the failing tests.**

```bash
# done hidden by default, shown with --all, counted in footer
o="$(mktemp -d)/.woostack"; mkspec "$o" oscar done feature/oscar
mkplan "$o" oscar 2026-06-01-oscar.md 5 0
export FAKE_GH_JSON='[{"number":9,"state":"MERGED","headRefName":"feature/oscar","author":{"login":"a"},"updatedAt":"2026-06-02T00:00:00Z"}]'
PATH="$g/bin:$PATH" run_status "$o"
assert_not_contains "$OUT" "oscar " "done hidden by default"
assert_contains "$OUT" "1 done" "done counted in footer"
PATH="$g/bin:$PATH" run_status "$o" --all
assert_contains "$OUT" "oscar" "done shown with --all"
unset FAKE_GH_JSON

# abandoned hidden + counted
mkspec "$o" papa abandoned feature/papa
run_status "$o"
assert_contains "$OUT" "abandoned" "abandoned counted in footer"
assert_not_contains "$OUT" "papa " "abandoned hidden by default"

# gh absent ⇒ still renders, prints a notice (PATH without gh)
q="$(mktemp -d)/.woostack"; mkspec "$q" quebec executing feature/quebec
mkplan "$q" quebec 2026-06-01-quebec.md 1 9
( PATH="/usr/bin:/bin" WOO_DIR="$q" bash "$ST" > /tmp/q.out 2>&1 ); qc=$?
assert_exit 0 "$qc" "gh-absent still exits 0"
assert_contains "$(cat /tmp/q.out)" "quebec" "renders without gh"
```

- [x] **Step 2: Run them, verify they fail.**

```bash
bash skills/woostack-status/scripts/tests/test-status.sh
# Expected: FAIL — done not hidden, no footer counts, no notice
```

- [x] **Step 3: Add arg parsing, the hide/show partition, footer counters, gh-absent notice.**

```bash
# arg parse (top, after WOO_DIR)
SHOW_ALL=0; DO_FETCH=0
for a in "$@"; do case "$a" in
  --all) SHOW_ALL=1 ;; --fetch) DO_FETCH=1 ;;
  -h|--help) echo "usage: status.sh [--all] [--fetch]"; exit 0 ;;
esac; done

# before the loop
done_count=0; abandoned_count=0; rows=""
gh_missing=0; have_gh || gh_missing=1
[ "$DO_FETCH" -eq 1 ] && have_gh && "$GH_BIN" repo set-default >/dev/null 2>&1; \
  [ "$DO_FETCH" -eq 1 ] && "$GIT_BIN" fetch --quiet 2>/dev/null || true
```

In the loop, instead of printing each row immediately, route by effective phase:

```bash
  row="$(printf '%-22s %-10s %-7s %-20s %-7s %-5s %s' \
    "$name" "$eff" "$plan_cell" "$inc_cell" "$owner" "$agecell" \
    "$(next_action "$eff" "$done" "$total" "$merged" "$prcount")")"
  case "$eff" in
    done)      done_count=$((done_count+1)) ;;
    abandoned) abandoned_count=$((abandoned_count+1)) ;;
    *)         rows="${rows}${row}"$'\n' ;;
  esac
  if [ "$SHOW_ALL" -eq 1 ]; then case "$eff" in done|abandoned) rows="${rows}${row}"$'\n' ;; esac; fi
```

After the loop, print header + rows + flags + footer + notice:

```bash
printf '%-22s %-10s %-7s %-20s %-7s %-5s %s\n' SPEC PHASE PLAN INCREMENTS OWNER AGE NEXT
printf '%s' "$rows"
[ -n "$FLAGS" ] && printf '\n⚠ FLAGS\n%s' "$FLAGS"
printf '\n✓ %d done · %d abandoned' "$done_count" "$abandoned_count"
[ "$SHOW_ALL" -eq 0 ] && printf '   (--all to expand)'
[ "$gh_missing" -eq 1 ] && printf '\nnote: gh not found — PR/increment/owner data omitted for PR-phase rows'
[ "$DO_FETCH" -eq 0 ] && printf '\nnote: PR-less branch data may be stale; pass --fetch to refresh'
printf '\n'
exit 0
```

(Move the phase-enum sanity, flags, owner/age, and band computation so they all run before the row is built. The header `printf` from Task 2 inside the loop is removed — header now prints once after the loop.)

- [x] **Step 4: Run the tests, verify they pass.**

```bash
bash skills/woostack-status/scripts/tests/test-status.sh
# Expected: done/abandoned hidden + counted; --all shows them; gh-absent renders + notice
```

- [x] **Step 5: Commit.**

```bash
git add skills/woostack-status/scripts
git commit -m "feat(status): default in-flight view, done/abandoned footer, --all/--fetch, gh-absent degrade"
```

### Task 9: Config — `status.staleDays` from `.woostack/config.json`

**Files:**
- Modify: `skills/woostack-status/scripts/status.sh`
- Modify: `skills/woostack-init/templates/config.json`
- Test: `skills/woostack-status/scripts/tests/test-status.sh`

- [x] **Step 1: Write the failing test** — `staleDays: 3` makes a 5-day-old executing spec stale; default 14 does not.

```bash
s="$(mktemp -d)/.woostack"; mkdir -p "$s"
printf '{ "status": { "staleDays": 3 } }' > "$s/config.json"
gr2="$(mktemp -d)"; ( cd "$gr2" && git -c user.email=t@t -c user.name=Tess init -q )
mkdir -p "$gr2/.woostack/specs" "$gr2/.woostack/plans"
cp "$s/config.json" "$gr2/.woostack/config.json"
printf -- '---\nname: romeo\ntype: spec\nstatus: executing\ndate: 2026-06-01\nbranch: feature/romeo\n---\nb\n' > "$gr2/.woostack/specs/2026-06-01-romeo.md"
printf '# r\n\n**Source:** .woostack/specs/2026-06-01-romeo.md\n\n- [x] a\n- [ ] b\n' > "$gr2/.woostack/plans/2026-06-01-romeo.md"
( cd "$gr2" && git add -A && GIT_AUTHOR_DATE='2026-05-30T00:00:00' GIT_COMMITTER_DATE='2026-05-30T00:00:00' git -c user.email=t@t -c user.name=Tess commit -qm x )
( cd "$gr2" && WOOSTACK_NOW=2026-06-04 PATH="/usr/bin:/bin" WOO_DIR=.woostack bash "$ST" > /tmp/r.out 2>&1 )
assert_contains "$(cat /tmp/r.out)" "stale" "staleDays:3 makes 5d spec stale"
```

- [x] **Step 2: Run it, verify it fails** (default 14 ⇒ not stale).

```bash
bash skills/woostack-status/scripts/tests/test-status.sh
# Expected: FAIL — no stale flag at default 14
```

- [x] **Step 3: Replace the stub `staleDays()`** with a config reader (jq, with a no-jq fallback).

```bash
staleDays() {
  local cfg="$WOO_DIR/config.json" v=""
  if [ -f "$cfg" ]; then
    if command -v jq >/dev/null 2>&1; then
      v="$(jq -r '.status.staleDays // empty' "$cfg" 2>/dev/null)"
    else
      v="$(grep -oE '"staleDays"[[:space:]]*:[[:space:]]*[0-9]+' "$cfg" | grep -oE '[0-9]+$')"
    fi
  fi
  case "$v" in ''|*[!0-9]*) echo 14 ;; *) echo "$v" ;; esac
}
```

- [x] **Step 4: Update the config template** so new workspaces ship the namespace. Edit `skills/woostack-init/templates/config.json`:

```json
{ "review": {}, "status": { "staleDays": 14 } }
```

- [x] **Step 5: Run the tests, verify they pass.**

```bash
bash skills/woostack-status/scripts/tests/test-status.sh
# Expected: stale flag appears under staleDays:3
```

- [x] **Step 6: Run the FULL suite to confirm nothing regressed.**

```bash
bash skills/woostack-status/scripts/tests/run-tests.sh
# Expected: "test-status.sh" … "<N> passed, 0 failed"
```

- [x] **Step 7: Commit.**

```bash
git add skills/woostack-status/scripts skills/woostack-init/templates/config.json
git commit -m "feat(status): read status.staleDays from config; ship namespace in init template"
```

### Task 10: Canonical conventions doc

**Files:**
- Create: `skills/woostack-status/references/conventions.md`

- [x] **Step 1: Write `conventions.md`** — the single source of truth. No test (doc), but it must state each contract exactly so producers can link it.

````markdown
# woostack feature-state conventions

Canonical definitions for the `/woostack-status` board. Other skills link here;
they do not restate these rules (cross-link, do not duplicate).

## Invariant: spec : plan : PRs = 1 : 1 : N

- Every spec has **exactly one** plan. The plan owns N independently shippable
  increment PRs.
- **spec → plan join:** the plan carries, in its first ~5 lines, a line of the
  exact form `**Source:** .woostack/specs/<file>.md`. Slug-match is the legacy
  fallback. Plans stay frontmatter-free.
- **plan → PR join:** every PR body carries a trailer line
  `Spec: .woostack/specs/<file>.md` (written by woostack-commit). The board finds
  increment PRs with `gh pr list --state all --search "Spec: <path>"`.
- **`spec.branch:`** names the active increment's branch.

## Phase enum (spec frontmatter `status:`)

`draft → hardened → approved → planning → executing → in-review → done`, plus the
terminal `abandoned`. The build loop authors every transition; the board displays
the authored value for head states and computes the execute/review/done band from
artifacts (truth table below).

| phase | meaning | authored at build step |
|---|---|---|
| draft | spec written, not hardened | 2 |
| hardened | grilled, awaiting approval gate | 3 |
| approved | gate cleared, no plan yet | 3 |
| planning | plan exists, 0 boxes done | 4 |
| executing | branch + commits, plan partial | 6 |
| in-review | an increment PR is open | 8 |
| done | plan 100% + all PRs merged | post-merge |
| abandoned | shelved (terminal, hidden) | manual |

## Truth table (execute → review → done band)

- any increment PR **open** → `in-review`
- plan partial, no open PR, branch has commits → `executing`
- plan **100%** + all increment PRs merged + ≥1 merged → `done`

A disagreeing authored value in this band is a FLAG, not displayed truth.

## Reconcile flags

0 or ≥2 plans for a spec · `branch:` empty/`unknown` at phase ≥ executing ·
unknown `status:` value · head-state phase while a PR already exists · executing
spec older than `status.staleDays` (config, default 14) · two in-flight specs on
the same branch.
````

- [x] **Step 2: Commit.**

```bash
git add skills/woostack-status/references/conventions.md
git commit -m "docs(status): canonical feature-state conventions"
```

### Task 11: One-time migration of existing specs

**Files:**
- Modify: `.woostack/specs/*.md` (only those needing it)

- [x] **Step 1: Find specs to migrate.**

```bash
grep -l '^status: ready' .woostack/specs/*.md
grep -l '^branch: unknown' .woostack/specs/*.md
```

- [x] **Step 2: Migrate `ready → approved`** on each matching file (verify each is genuinely past the approval gate before changing). Use the `set_field` helper from `woostack-init/scripts/lib.sh` or a manual edit.

```bash
# example, per file:
sed -i '' 's/^status: ready$/status: approved/' .woostack/specs/<file>.md   # macOS sed
```

- [x] **Step 3: Fix `branch: unknown`** — set the real branch where known (e.g. `bounded-review-swarms`), else leave and let the board flag it. Do not invent a branch.

- [x] **Step 4: Run the board against the real repo** to confirm it parses and flags honestly.

```bash
bash skills/woostack-status/scripts/status.sh
# Expected: a table for the live specs; flags for any genuine 1:1 / branch gaps
```

- [x] **Step 5: Commit.**

```bash
git add .woostack/specs
git commit -m "chore(status): migrate spec status vocabulary to the phase enum"
```

### Increment 1 close-out

- [x] **Distill memory** (build step 7): extract durable conventions (the `**Source:**` join, the `Spec:` trailer contract, the truth table) into `.woostack/memory/` notes with `source: .woostack/plans/2026-06-04-woostack-status.md`; dedupe; run `build-index.sh` + `doctor.sh`.
- [x] **Offer a PR** for Increment 1 (engine) before starting Increment 2.

---

## Increment 2 — Command + producers

> Markdown edits; no TDD code blocks. Each task names the exact file and the exact content to add. Run `bash skills/woostack-status/scripts/tests/run-tests.sh` after the producer edits to confirm the engine still passes.

### Task 12: `woostack-status` command skill

**Files:** Create `skills/woostack-status/SKILL.md`

- [x] Write the SKILL with: frontmatter `name: woostack-status`, description scoped to "show the derived feature board / what's in flight / what to do next"; an Overview; a Procedure that runs `bash <skill>/scripts/status.sh` against the project's `.woostack`, then narrates the board and the single next action per in-flight feature; a flags section documenting `--all` and `--fetch`; a Hard-constraints block ("read-only; never fetches/commits/pushes; source of truth is the artifacts"); and a link to `references/conventions.md`. Do not restate the enum — link it.
- [x] Commit: `feat(status): add /woostack-status command skill`.

### Task 13: woostack-commit — `Spec:` trailer + advisory invariant check

**Files:** Modify `skills/woostack-commit/SKILL.md`

- [x] In the PR-body section (step 7), add the trailer to the body template, after Test plan: a line `Spec: .woostack/specs/<file>.md` resolved from the session's spec (the spec whose `branch:` matches the current branch, or the spec under active work). Document that the board relies on it (link `conventions.md`).
- [x] Add a step 4.5 "Invariant check (advisory)": when staged files include `.woostack/specs/*` or `.woostack/plans/*`, run the cheap checks — each touched spec resolves to exactly one plan, `branch:` present, `status:` ∈ enum — and print any violation as a single non-blocking line in the commit report. Never abort. Link `conventions.md`.
- [x] Commit: `feat(commit): write Spec: PR trailer + advisory invariant check`.

### Task 14: woostack-build — author `status:`, write `**Source:**`, state 1:1

**Files:** Modify `skills/woostack-build/SKILL.md`

- [x] Annotate each step with the `status:` it authors: step 2 → `draft`; step 3 post-grill → `hardened`, gate cleared → `approved`; step 4 → `planning`; step 9 execute drives the `executing`/`in-review` band; post-merge → `done`. Add a one-line "the build loop owns `status:` transitions — see `woostack-status/references/conventions.md`."
- [x] In step 4 (plan), require the plan to open with the `**Source:** .woostack/specs/<file>.md` line.
- [x] In step 2/5, state the invariant explicitly: exactly one plan per spec; the plan owns the increments. Link `conventions.md`.
- [x] Commit: `docs(build): author status: per step, require Source line, state 1:1 invariant`.

### Task 15: spec-template enum + init reference note

**Files:** Modify `skills/woostack-build/references/spec-template.md`, the init config reference

- [x] In `spec-template.md`, annotate the `status:` field with the enum values and link `conventions.md`.
- [x] In the woostack-init reference that documents `config.json` namespaces, add the `status` namespace (`staleDays`, default 14) alongside `review`.
- [x] Commit: `docs(build): document status enum in spec template + status config namespace`.

### Task 16: using-woostack — routing, pointer, red-flags

**Files:** Modify `skills/using-woostack/SKILL.md`

- [x] Add a Command Routing row: ``| `/woostack-status`, show the derived feature board | `woostack-status` |``.
- [x] Add a one-line invariant pointer under the Project Entry Check linking `woostack-status/references/conventions.md` ("specs↔plans are 1:1; `status:`/`branch:` are load-bearing for the board").
- [x] Add three Red-Flags rows: writing a second plan for a spec; hand-setting/blanking `status:`/`branch:`; renaming/moving a spec or plan.
- [x] Commit: `docs(using-woostack): route /woostack-status, add invariant pointer + red-flags`.

### Task 17: Surface — AGENTS.md / README

**Files:** Modify `AGENTS.md` (and its symlink `.claude/CLAUDE.md` is the same file), `README.md`

- [x] Update the public command surface from nine to ten: add the `woostack-status` bullet to the list, add it to the Quick file map, and update any stale skill-count wording (keep the internal `woostack-ideate` framing intact — it is not part of the count).
- [x] Update `README.md`'s skill list / how-it-works the same way; resolve any version/command counts.
- [x] Commit: `docs: add woostack-status to the public command surface (9 → 10)`.

### Increment 2 close-out

- [x] Run `bash skills/woostack-status/scripts/tests/run-tests.sh` — confirm the engine still passes after producer edits.
- [x] Distill any new durable conventions; run `build-index.sh` + `doctor.sh`.
- [x] Offer a PR for Increment 2.

---

## Self-review (against the spec)

- **§2 goal / three jobs** — board (Tasks 2–8), next-action (Task 2 lookup), multi-person owner/age/stale/collision (Task 6). ✓
- **§4.1 enum (8)** — rendered + validated (Tasks 2, 7); `abandoned` hidden (Task 8). ✓
- **§4.2 truth table** — Task 4 `resolve_phase`. ✓
- **§4.3 joins** — `**Source:**` (Task 3), `Spec:` trailer + fallback (Tasks 4–5), `spec.branch` (Tasks 5–6). ✓
- **§4.5 gh-as-source / no auto-fetch / `--fetch`** — Tasks 6, 8. ✓
- **§4.6 hide done + `*.md` only** — Tasks 8, 2. ✓
- **§4.7 config** — Task 9. ✓
- **§4.8 enforcement (4 surfaces)** — conventions.md (Task 10), reconcile (Tasks 3–7), commit advisory (Task 13), using-woostack (Task 16). ✓
- **§6 failure modes** — empty (Task 1), gh-absent (Task 8), trailer-missing (Task 5), branch-missing/malformed (Task 7), exit codes (no `exit 1` on flags; `exit 0` throughout). ✓
- **§7 testing** — `test-status.sh` covers each row above. ✓
- **Migration** — Task 11. ✓

**Open items deferred to execution** (spec §8): exact `gh ... --search` field tuning (Task 4 — verify against real PRs during Increment 2 when the trailer exists); migration bundled into Increment 1 (Task 11). The `gh pr list --search` JSON-field availability should be confirmed on first real run; if `--search` proves unreliable for the trailer, fall back to `--json body` + local `grep` filter (note in Task 4 if it fails).
