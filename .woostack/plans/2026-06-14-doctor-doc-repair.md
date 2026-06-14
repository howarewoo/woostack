---
type: plan
source: .woostack/specs/2026-06-14-doctor-doc-repair.md
status: ready
branch: feature/doctor-doc-repair
---

**Source:** [[specs/2026-06-14-doctor-doc-repair]]

# Doctor doc-template + static-status-drift repair — Implementation Plan

**Goal:** Extend `woostack-doctor` with content-only checks that diagnose and (gated) repair
specs/plans/fixes against their templates and the `conventions.md` status enum — `doc-type`,
`status-enum` (with a curated alias table), `status-band`, `plan-source` + `plan-source-sync` —
without any git/PR/network access.

**Architecture:** Pure extension of doctor's existing check pattern. Each check is a standalone
`scripts/checks/*.sh` emitting `severity⇥code⇥fixable⇥path⇥message`, auto-discovered by
`doctor.sh`'s `for chk in "$HERE"/checks/*.sh` glob (no orchestrator edit). Checks `source
woostack-init/scripts/lib.sh` for `field`/`set_field` and use the `${VALID/ $x /}` membership idiom
(as `memory.sh` and `status.sh` do). Calling convention: `<check> <WOO_ROOT>` to diagnose, `<check>
--fix <WOO_ROOT> <args...>` to repair; `--fix` self-computes the canonical value so it is
idempotent. Findings emit the path as `${file#"$WOO_ROOT"/}` → `.woostack/<dir>/<file>.md` (tests
assert against that exact form). The boundary doctrine (doctor owns static authoring drift; status
owns the git/PR band) ships in Increment 2 alongside `status-enum`, the check that defines it.

**Tech Stack:** POSIX-ish bash, `awk`/`sed`/`grep`; doctor's bash test harness
(`scripts/tests/run-tests.sh` + `woostack-init/scripts/tests/assert.sh`: `assert_eq actual
expected msg`, `assert_contains haystack needle msg` (fixed-string `grep -qF`),
`assert_not_contains`, `assert_exit expected actual msg`, `finish`).

> Paths below are repo-relative to `skills/woostack-doctor/` unless prefixed otherwise. `<wi>` =
> `skills/woostack-init`. Helpers `field`/`set_field`/`note_body` live in `<wi>/scripts/lib.sh`.
> The status enum is canonical in `skills/woostack-status/references/conventions.md`; checks hold a
> linted copy and link it. There are no `## Track:` headings → one linear `gt` stack on top of the
> spec+plan PR; no `woostack-defer` markers (each increment is self-contained via auto-discovery).

---

## Increment 1: `doc-type` — type: must match the artifact dir

Ships `scripts/checks/doc-type.sh` (warn/auto; owns the no-fence report for specs/plans/fixes) +
its test + its `checks.md` row. Independently shippable: auto-discovered, self-documented.

### Task 1.1: failing test for `doc-type` diagnose

- [x] Create `scripts/tests/test-doc-type.sh` with the diagnose cases (red — script absent):

```bash
#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../woostack-init/scripts/tests/assert.sh"
set +e
C="$HERE/../checks"

r="$(mktemp -d)"
mkdir -p "$r/.woostack/specs" "$r/.woostack/plans" "$r/.woostack/fixes"
# good spec (no finding)
printf -- '---\nname: a\ntype: spec\nstatus: draft\n---\n\n# A\n' > "$r/.woostack/specs/a.md"
# plan mis-typed as spec
printf -- '---\ntype: spec\nstatus: planning\n---\n\n**Source:** [[specs/a]]\n\n# A Plan\n' > "$r/.woostack/plans/a.md"
# spec missing type:
printf -- '---\nname: b\nstatus: draft\n---\n\n# B\n' > "$r/.woostack/specs/b.md"
# fenceless doc (report, not auto)
printf -- '# C\nno frontmatter\n' > "$r/.woostack/fixes/c.md"

out="$(bash "$C/doc-type.sh" "$r")"
assert_eq "$(printf '%s\n' "$out" | grep -c 'doc-type')" "3" "three doc-type findings"
assert_contains "$out" "$(printf 'auto\t.woostack/plans/a.md')" "mis-typed plan is auto"
assert_contains "$out" "$(printf 'auto\t.woostack/specs/b.md')" "missing-type spec is auto"
assert_contains "$out" "$(printf 'report\t.woostack/fixes/c.md')" "fenceless doc is report"
finish
```

- [x] Run it, confirm it fails because the script does not exist yet:

```
bash scripts/tests/test-doc-type.sh; echo "exit=$?"
```

Expected: a `bash: .../checks/doc-type.sh: No such file or directory` error and `exit=1` (the
assertions on empty output fail). This is the red state.

### Task 1.2: implement `doc-type.sh`

- [x] Create `scripts/checks/doc-type.sh`:

```bash
#!/usr/bin/env bash
# doc-type.sh — every spec/plan/fix carries a type: matching its dir.
# Owns the no-frontmatter-fence report for specs/plans/fixes (other doc checks skip fenceless docs).
#   diagnose:  doc-type.sh <WOO_ROOT>
#   repair:    doc-type.sh --fix <WOO_ROOT> <file>   (type self-derived from the file's dir)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../woostack-init/scripts/lib.sh"
emit() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5"; }

# want_for <file> → expected type from the parent dir, empty/non-zero if not a doc dir.
want_for() {
  case "$1" in
    */.woostack/specs/*) echo spec ;;
    */.woostack/plans/*) echo plan ;;
    */.woostack/fixes/*) echo fix ;;
    *) return 1 ;;
  esac
}

if [ "${1:-}" = "--fix" ]; then
  root="$2"; file="$3"
  want="$(want_for "$file")" || exit 0
  set_field "$file" type "$want" || { emit error doc-type manual "${file#"$root"/}" "no frontmatter fence; add 'type: $want' manually"; exit 1; }
  [ "$(field "$file" type)" = "$want" ] || { emit error doc-type manual "${file#"$root"/}" "type: did not update to '$want'"; exit 1; }
  exit 0
fi
WOO_ROOT="${1:-.}"

shopt -s nullglob
for dir in specs plans fixes; do
  case "$dir" in specs) want=spec ;; plans) want=plan ;; fixes) want=fix ;; esac
  for f in "$WOO_ROOT/.woostack/$dir"/*.md; do
    rp="${f#"$WOO_ROOT"/}"
    if [ "$(head -1 "$f")" != "---" ]; then
      emit warn doc-type report "$rp" "no frontmatter fence; cannot read/repair type: (expected '$want')"
      continue
    fi
    t="$(field "$f" type)"
    [ "$t" = "$want" ] && continue
    emit warn doc-type auto "$rp" "type: '${t:-<missing>}' should be '$want' (dir implies it)"
  done
done
```

- [x] Run the test, confirm diagnose cases pass:

```
bash scripts/tests/test-doc-type.sh; echo "exit=$?"
```

Expected: `OK`/passed lines then `exit=0`.

### Task 1.3: failing test for `doc-type --fix` + idempotency

- [x] Append the repair cases to `scripts/tests/test-doc-type.sh` (before `finish`):

```bash
# --- repair ---
bash "$C/doc-type.sh" --fix "$r" "$r/.woostack/plans/a.md"
assert_eq "$(field "$r/.woostack/plans/a.md" type)" "plan" "mis-typed plan repaired"
bash "$C/doc-type.sh" --fix "$r" "$r/.woostack/specs/b.md"
assert_eq "$(field "$r/.woostack/specs/b.md" type)" "spec" "missing-type spec repaired (inserted)"
# idempotent re-fix
bash "$C/doc-type.sh" --fix "$r" "$r/.woostack/plans/a.md"
assert_eq "$(grep -c '^type:' "$r/.woostack/plans/a.md")" "1" "re-fix is a no-op (single type: line)"
# only the fenceless report remains
res="$(bash "$C/doc-type.sh" "$r")"
assert_eq "$(printf '%s\n' "$res" | grep -c 'auto')" "0" "no auto findings remain after repair"
assert_contains "$res" ".woostack/fixes/c.md" "fenceless report persists"
# no git/gh invocation in the check source
assert_eq "$(grep -nE '(^|[^[:alnum:]_])(git|gh)[[:space:]]' "$C/doc-type.sh")" "" "doc-type calls no git/gh"
```

- [x] Run it, confirm everything passes:

```
bash scripts/tests/test-doc-type.sh; echo "exit=$?"
```

Expected: all passed, `exit=0`.

### Task 1.4: catalog row in `references/checks.md`

- [x] Add a row to the check table in `references/checks.md`:

```
| `doc-type` | spec/plan/fix `type:` missing or not matching its dir | warn | auto | `<root> <file>` |
```

- [x] Confirm the path-integrity test stays green:

```
bash scripts/tests/test-no-stale-paths.sh; echo "exit=$?"
```

Expected: `exit=0`.

### Task 1.5: commit increment 1

- [x] Hand to `woostack-commit` (it cuts the Graphite branch + PR on top of the spec+plan PR).
  Subject: `feat(doctor): doc-type check — repair spec/plan/fix type: to match dir`.

---

## Increment 2: `status-enum` — normalize alias status values, report unknowns (+ boundary doctrine)

Ships `scripts/checks/status-enum.sh` (error; auto on alias hit, report on miss) + test +
`checks.md` row, **plus** the SKILL.md boundary amendment and the `checks.md` static-vs-computed
narrative — the doctrine ships with the check that defines it, so no PR in the stack contradicts
itself. Skips fenceless docs (doc-type owns that) and empty `status:` (board concern).

### Task 2.1: failing test for `status-enum` diagnose

- [x] Create `scripts/tests/test-status-enum.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../woostack-init/scripts/tests/assert.sh"
set +e
C="$HERE/../checks"

r="$(mktemp -d)"
mkdir -p "$r/.woostack/specs" "$r/.woostack/plans" "$r/.woostack/fixes"
printf -- '---\ntype: spec\nstatus: approved\n---\n\n# ok\n'   > "$r/.woostack/specs/ok.md"   # valid → none
printf -- '---\ntype: spec\nstatus: aproved\n---\n\n# typo\n'  > "$r/.woostack/specs/typo.md" # alias → auto
printf -- '---\ntype: plan\nstatus: in_review\n---\n\n# al\n'  > "$r/.woostack/plans/al.md"   # alias → auto
printf -- '---\ntype: fix\nstatus: frobnicate\n---\n\n# unk\n' > "$r/.woostack/fixes/unk.md"  # unknown → report

out="$(bash "$C/status-enum.sh" "$r")"
assert_eq "$(printf '%s\n' "$out" | grep -c 'status-enum')" "3" "three status-enum findings"
assert_contains "$out" "$(printf 'error\tstatus-enum\tauto\t.woostack/specs/typo.md')" "alias is error+auto"
assert_contains "$out" "$(printf 'error\tstatus-enum\tauto\t.woostack/plans/al.md')" "in_review alias is auto"
assert_contains "$out" "$(printf 'error\tstatus-enum\treport\t.woostack/fixes/unk.md')" "unknown is error+report"
finish
```

- [x] Run it, confirm red (`exit=1`).

### Task 2.2: implement `status-enum.sh`

- [x] Create `scripts/checks/status-enum.sh`:

```bash
#!/usr/bin/env bash
# status-enum.sh — status: must be a known phase; exact-match aliases auto-normalize.
# Enum is canonical in woostack-status/references/conventions.md; this is the linted copy
# (mirrors status.sh's VALID_PHASES — keep in sync when the enum changes).
#   diagnose:  status-enum.sh <WOO_ROOT>
#   repair:    status-enum.sh --fix <WOO_ROOT> <file>   (canonical self-derived; idempotent)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../woostack-init/scripts/lib.sh"
emit() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5"; }

VALID=" draft hardened approved planning ready executing in-review done abandoned "

# Curated, EXACT-MATCH alias table (misspelling/synonym → canonical). No fuzzy matching.
alias_for() {
  case "$1" in
    aproved|approve)              echo approved ;;
    hardend)                      echo hardened ;;
    in_review|inreview|reviewing) echo in-review ;;
    complete|completed|merged)    echo done ;;
    wip)                          echo executing ;;
    planned)                      echo planning ;;
    abandon|abandonded)           echo abandoned ;;
    *) return 1 ;;
  esac
}

if [ "${1:-}" = "--fix" ]; then
  root="$2"; file="$3"
  s="$(field "$file" status)"
  [ "${VALID/ $s /}" != "$VALID" ] && exit 0        # already valid → no-op
  canon="$(alias_for "$s")" || exit 0               # unknown, no alias → never auto-applied
  set_field "$file" status "$canon" || { emit error status-enum manual "${file#"$root"/}" "no frontmatter fence; set 'status: $canon' manually"; exit 1; }
  [ "$(field "$file" status)" = "$canon" ] || { emit error status-enum manual "${file#"$root"/}" "status: did not update to '$canon'"; exit 1; }   # phantom-repair guard (spec §6)
  exit 0
fi
WOO_ROOT="${1:-.}"

shopt -s nullglob
for dir in specs plans fixes; do
  for f in "$WOO_ROOT/.woostack/$dir"/*.md; do
    [ "$(head -1 "$f")" != "---" ] && continue       # no fence → doc-type owns that report
    s="$(field "$f" status)"
    [ -z "$s" ] && continue                          # missing status → board concern, not enum
    [ "${VALID/ $s /}" != "$VALID" ] && continue     # valid phase → ok
    rp="${f#"$WOO_ROOT"/}"
    if canon="$(alias_for "$s")"; then
      emit error status-enum auto "$rp" "status: '$s' is an alias; normalize to '$canon'"
    else
      emit error status-enum report "$rp" "status: '$s' is not a known phase; set a valid status: manually"
    fi
  done
done
```

- [x] Run the test, confirm diagnose passes (`exit=0`).

### Task 2.3: failing test for `--fix`, report-not-applied, idempotency

- [x] Append to `scripts/tests/test-status-enum.sh` (before `finish`):

```bash
# --- repair: alias auto-fixes ---
bash "$C/status-enum.sh" --fix "$r" "$r/.woostack/specs/typo.md"
assert_eq "$(field "$r/.woostack/specs/typo.md" status)" "approved" "aproved → approved"
bash "$C/status-enum.sh" --fix "$r" "$r/.woostack/plans/al.md"
assert_eq "$(field "$r/.woostack/plans/al.md" status)" "in-review" "in_review → in-review"
# report value is NEVER mutated, even if --fix is called on it
bash "$C/status-enum.sh" --fix "$r" "$r/.woostack/fixes/unk.md"
assert_eq "$(field "$r/.woostack/fixes/unk.md" status)" "frobnicate" "unknown status untouched by --fix"
# idempotent
bash "$C/status-enum.sh" --fix "$r" "$r/.woostack/specs/typo.md"
assert_eq "$(field "$r/.woostack/specs/typo.md" status)" "approved" "re-fix no-op"
# only the unknown (report) finding remains
res="$(bash "$C/status-enum.sh" "$r")"
assert_eq "$(printf '%s\n' "$res" | grep -c 'auto')" "0" "no auto findings remain"
assert_contains "$res" ".woostack/fixes/unk.md" "report finding persists"
assert_eq "$(grep -nE '(^|[^[:alnum:]_])(git|gh)[[:space:]]' "$C/status-enum.sh")" "" "status-enum calls no git/gh"
```

- [x] Run, confirm green (`exit=0`).

### Task 2.4: catalog row + boundary doctrine

- [x] Add the row to `references/checks.md`:

```
| `status-enum` | `status:` value not in the conventions enum | error | auto (alias hit) / report | `<root> <file>` |
```

- [x] In `references/checks.md`, after the table add a short subsection documenting: (a) the
  **static-vs-computed-drift boundary** — doctor repairs authoring-time status drift (enum/alias);
  `woostack-status` owns the git/PR-derived execute→done band and is never written here; (b) the
  curated **exact-match alias table** contents from `status-enum.sh`; (c) the **consumer-CI
  migration** note — the one new way `--check` can newly fail is an unknown `status:` value
  (`error`). Link `conventions.md` for the canonical enum; do not restate it.

- [x] In `skills/woostack-doctor/SKILL.md`, refine the **Never reconcile the board** hard
  constraint to draw the line, replacing its bullet body with:

```
- **Never reconcile the board** (that is `woostack-status`) and **never curate memory content**
  (that is `woostack-dream`). Doctor repairs **static, authoring-time** doc drift — `type:`, the
  `status:` enum (normalizing exact-match aliases), and the plan→spec `**Source:**` join — and
  **reports** judgment-only signals (dead notes, wrong-band status). It **never computes or writes
  the git/PR-derived execute→done band**; that stays `woostack-status`'s read-only computed truth.
```

- [x] Also extend the SKILL.md description's "store integrity and conventions" enumeration to
  mention doc-template + status-drift coverage (keep it concise).

- [x] Confirm `bash scripts/tests/test-no-stale-paths.sh; echo "exit=$?"` → `exit=0`.

### Task 2.5: commit increment 2

- [x] Hand to `woostack-commit`. Subject:
  `feat(doctor): status-enum check + board-boundary doctrine — normalize alias status, report unknowns`.

---

## Increment 3: `status-band` — report status authored on the wrong artifact

Ships `scripts/checks/status-band.sh` (warn/report; skips `fixes/`) + test + `checks.md` row, plus
the enum-sites memory-note update (both enum-consuming checks now exist → no forward reference).

### Task 3.1: failing test for `status-band`

- [x] Create `scripts/tests/test-status-band.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../woostack-init/scripts/tests/assert.sh"
set +e
C="$HERE/../checks"

r="$(mktemp -d)"
mkdir -p "$r/.woostack/specs" "$r/.woostack/plans" "$r/.woostack/fixes"
printf -- '---\ntype: spec\nstatus: approved\n---\n\n# ok\n'  > "$r/.woostack/specs/ok.md"  # in-band → none
printf -- '---\ntype: spec\nstatus: executing\n---\n\n# x\n'  > "$r/.woostack/specs/x.md"   # plan-band on spec → report
printf -- '---\ntype: plan\nstatus: executing\n---\n\n# ok\n' > "$r/.woostack/plans/ok.md"  # in-band → none
printf -- '---\ntype: plan\nstatus: hardened\n---\n\n# y\n'   > "$r/.woostack/plans/y.md"   # spec-band on plan → report
printf -- '---\ntype: fix\nstatus: executing\n---\n\n# f\n'   > "$r/.woostack/fixes/f.md"   # fixes skipped → none

out="$(bash "$C/status-band.sh" "$r")"
assert_eq "$(printf '%s\n' "$out" | grep -c 'status-band')" "2" "exactly two band findings"
assert_contains "$out" "$(printf 'warn\tstatus-band\treport\t.woostack/specs/x.md')" "plan-band value on spec"
assert_contains "$out" "$(printf 'warn\tstatus-band\treport\t.woostack/plans/y.md')" "spec-band value on plan"
assert_not_contains "$out" ".woostack/fixes/f.md" "fixes/ skipped"
# --fix is a no-op for a report check
bash "$C/status-band.sh" --fix "$r" "$r/.woostack/specs/x.md"; assert_exit 0 "$?" "--fix no-op exits 0"
assert_eq "$(field "$r/.woostack/specs/x.md" status)" "executing" "report check never mutates"
assert_eq "$(grep -nE '(^|[^[:alnum:]_])(git|gh)[[:space:]]' "$C/status-band.sh")" "" "status-band calls no git/gh"
finish
```

- [x] Run, confirm red (`exit=1`).

### Task 3.2: implement `status-band.sh`

- [x] Create `scripts/checks/status-band.sh`:

```bash
#!/usr/bin/env bash
# status-band.sh — report-only. specs own draft/hardened/approved; plans own
# planning/ready/executing/in-review/done. 'abandoned' is terminal for both. fixes/ skipped
# (a fix is its own spec+plan, no opposite band). Never repairs — can't pick the right value.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../woostack-init/scripts/lib.sh"
emit() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5"; }
[ "${1:-}" = "--fix" ] && exit 0          # report-only: --fix is a no-op
WOO_ROOT="${1:-.}"

SPEC_BAND=" draft hardened approved "
PLAN_BAND=" planning ready executing in-review done "

scan() {                                  # scan <dir> <opposite-band> <msg>
  local dir="$1" band="$2" msg="$3" f s rp
  shopt -s nullglob
  for f in "$WOO_ROOT/.woostack/$dir"/*.md; do
    [ "$(head -1 "$f")" != "---" ] && continue
    s="$(field "$f" status)"; [ -z "$s" ] && continue
    if [ "${band/ $s /}" != "$band" ]; then
      rp="${f#"$WOO_ROOT"/}"
      emit warn status-band report "$rp" "$msg '$s'"
    fi
  done
}
scan specs "$PLAN_BAND" "spec carries plan-band status; specs own draft/hardened/approved, move lifecycle to the plan:"
scan plans "$SPEC_BAND" "plan carries spec-band status; plans own planning..done, set a plan-lifecycle status:"
# fixes/ intentionally not scanned.
```

- [x] Run the test, confirm green (`exit=0`).

### Task 3.3: catalog row

- [x] Add to `references/checks.md`:

```
| `status-band` | status value in the other artifact's band (spec↔plan); skips fixes/ | warn | report | — |
```

- [x] `bash scripts/tests/test-no-stale-paths.sh; echo "exit=$?"` → `exit=0`.

### Task 3.4: update the enum-sites memory note (distill)

- [x] Update the user memory note `woostack-add-phase-enum-value.md`: add doctor's `status-enum.sh`
  (`VALID`) and `status-band.sh` (`SPEC_BAND`/`PLAN_BAND`) as new sites that must change when the
  phase enum changes, bump `updated:`, and refresh the MEMORY.md hook line if it cites a site
  count. `woostack-execute` writes this during the increment.

### Task 3.5: commit increment 3

- [x] Hand to `woostack-commit`. Subject:
  `feat(doctor): status-band check — report status authored on the wrong artifact`.

---

## Increment 4: `plan-source` + `plan-source-sync` — the plan→spec join line

Ships `scripts/checks/plan-source.sh` (two codes; warn) + test + two `checks.md` rows, then closes
the stack with a whole-suite run and an auto-discovery smoke. Parses the Source line with the
board's tolerant form-agnostic matcher and normalizes basenames before comparing.

### Task 4.1: failing test for `plan-source` / `plan-source-sync` diagnose

- [ ] Create `scripts/tests/test-plan-source.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../woostack-init/scripts/tests/assert.sh"
set +e
C="$HERE/../checks"

r="$(mktemp -d)"
mkdir -p "$r/.woostack/specs" "$r/.woostack/plans"
printf -- '---\ntype: spec\nstatus: approved\n---\n\n# A\n' > "$r/.woostack/specs/a.md"
printf -- '---\ntype: spec\nstatus: approved\n---\n\n# B\n' > "$r/.woostack/specs/b.md"
# (i) missing line, source: resolves to a.md → auto
printf -- '---\ntype: plan\nsource: .woostack/specs/a.md\nstatus: planning\n---\n\n# A Plan\n' > "$r/.woostack/plans/miss-auto.md"
# (ii) missing line, no source: + no same-basename spec → report
printf -- '---\ntype: plan\nstatus: planning\n---\n\n# Orphan Plan\n' > "$r/.woostack/plans/orphan.md"
# (iii) line names b but source: names a → sync mismatch (auto)
printf -- '---\ntype: plan\nsource: .woostack/specs/a.md\nstatus: planning\n---\n\n**Source:** [[specs/b]]\n\n# Mismatch\n' > "$r/.woostack/plans/sync.md"
# (iv) line bare-path w/ trailing text, source: same base → in sync, no finding
printf -- '---\ntype: plan\nsource: .woostack/specs/a.md\nstatus: planning\n---\n\n**Source:** specs/a.md (shipped #1)\n\n# OK\n' > "$r/.woostack/plans/ok.md"
# (v) line present, source: frontmatter absent → sync from line (auto)
printf -- '---\ntype: plan\nstatus: planning\n---\n\n**Source:** [[specs/a]]\n\n# No Source Key\n' > "$r/.woostack/plans/line-no-key.md"

out="$(bash "$C/plan-source.sh" "$r")"
assert_contains "$out" "$(printf 'warn\tplan-source\tauto\t.woostack/plans/miss-auto.md')" "missing line w/ resolvable source: is auto"
assert_contains "$out" "$(printf 'warn\tplan-source\treport\t.woostack/plans/orphan.md')" "orphan plan is report"
assert_contains "$out" "$(printf 'warn\tplan-source-sync\tauto\t.woostack/plans/sync.md')" "source/line basename mismatch"
assert_contains "$out" "$(printf 'warn\tplan-source-sync\tauto\t.woostack/plans/line-no-key.md')" "line present, source: absent is auto sync"
assert_not_contains "$out" ".woostack/plans/ok.md" "normalized in-sync plan has no finding"
finish
```

- [ ] Run, confirm red (`exit=1`).

### Task 4.2: implement `plan-source.sh`

- [ ] Create `scripts/checks/plan-source.sh`:

```bash
#!/usr/bin/env bash
# plan-source.sh — plans carry the canonical **Source:** join line, and source: frontmatter
# names the same spec. Two codes:
#   plan-source       missing **Source:** line  (auto when source: resolves to a spec, else report)
#   plan-source-sync  source: basename != line basename  (auto: sync source: ← the line)
#   diagnose:  plan-source.sh <WOO_ROOT>
#   repair:    plan-source.sh --fix <WOO_ROOT> <plan> source-line
#              plan-source.sh --fix <WOO_ROOT> <plan> source-sync
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../woostack-init/scripts/lib.sh"
emit() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5"; }

# basename_of <ref> — reduce any Source reference form to bare <basename>:
#   .woostack/specs/x.md | specs/x.md | specs/x | [[specs/x]] | any of these + trailing text
basename_of() {
  local s="$1"
  s="${s##*specs/}"; s="${s%%]*}"; s="${s%% *}"; s="${s%.md}"
  printf '%s\n' "$s"
}
# line_base <plan> — basename named by the **Source:** line, empty if none.
line_base() {
  local raw tok
  raw="$(grep -m1 -E '^\*\*Source:\*\*' "$1" 2>/dev/null)"; [ -z "$raw" ] && return 0
  tok="$(printf '%s' "$raw" | grep -oE 'specs/[A-Za-z0-9._-]+' | head -1)"; [ -z "$tok" ] && return 0
  basename_of "$tok"
}

if [ "${1:-}" = "--fix" ]; then
  root="$2"; plan="$3"; mode="$4"
  case "$mode" in
    source-line)
      grep -qE '^\*\*Source:\*\*' "$plan" && exit 0       # already present → no-op
      base="$(basename_of "$(field "$plan" source)")"
      [ -z "$base" ] && { emit warn plan-source report "${plan#"$root"/}" "no source: frontmatter to derive the **Source:** line"; exit 1; }
      awk -v line="**Source:** [[specs/$base]]" '
        {print}
        f==0 && /^---$/{c++; if(c==2){print ""; print line; f=1}}' "$plan" > "$plan.t" && mv "$plan.t" "$plan"
      grep -qE '^\*\*Source:\*\*' "$plan" || { emit error plan-source manual "${plan#"$root"/}" "no closing frontmatter fence to anchor the **Source:** line; add it manually"; exit 1; }
      exit 0 ;;
    source-sync)
      lb="$(line_base "$plan")"; [ -z "$lb" ] && exit 0
      set_field "$plan" source ".woostack/specs/$lb.md" || { emit error plan-source-sync manual "${plan#"$root"/}" "no frontmatter fence; set source: manually"; exit 1; }
      [ "$(basename_of "$(field "$plan" source)")" = "$lb" ] || { emit error plan-source-sync manual "${plan#"$root"/}" "source: did not sync to '$lb'"; exit 1; }   # phantom-repair guard (spec §6)
      exit 0 ;;
    *) exit 2 ;;
  esac
fi
WOO_ROOT="${1:-.}"

shopt -s nullglob
for plan in "$WOO_ROOT/.woostack/plans"/*.md; do
  rp="${plan#"$WOO_ROOT"/}"
  lb="$(line_base "$plan")"
  if [ -z "$lb" ]; then
    sbase="$(basename_of "$(field "$plan" source)")"
    if [ -n "$sbase" ] && [ -f "$WOO_ROOT/.woostack/specs/$sbase.md" ]; then
      emit warn plan-source auto "$rp" "missing **Source:** line; derive [[specs/$sbase]] from source: frontmatter"
    else
      emit warn plan-source report "$rp" "missing **Source:** line and no source: frontmatter resolving to a spec to derive from"
    fi
    continue
  fi
  sbase="$(basename_of "$(field "$plan" source)")"
  if [ -n "$sbase" ] && [ "$sbase" != "$lb" ]; then
    emit warn plan-source-sync auto "$rp" "source: names '$sbase' but **Source:** line names '$lb'; sync source: to the canonical line"
  elif [ -z "$sbase" ]; then
    emit warn plan-source-sync auto "$rp" "**Source:** line names '$lb' but source: frontmatter is absent; sync source: from the line"
  fi
done
```

- [ ] Run the test, confirm diagnose passes (`exit=0`).

### Task 4.3: failing test for both `--fix` modes + idempotency

- [ ] Append to `scripts/tests/test-plan-source.sh` (before `finish`):

```bash
# --- repair: insert missing line ---
bash "$C/plan-source.sh" --fix "$r" "$r/.woostack/plans/miss-auto.md" source-line
assert_eq "$(grep -m1 -E '^\*\*Source:\*\*' "$r/.woostack/plans/miss-auto.md")" "**Source:** [[specs/a]]" "line inserted as wikilink"
# inserted line sits before the H1
assert_eq "$(grep -nE '^\*\*Source:\*\*|^# ' "$r/.woostack/plans/miss-auto.md" | head -1 | grep -c 'Source')" "1" "Source line precedes H1"
# idempotent
bash "$C/plan-source.sh" --fix "$r" "$r/.woostack/plans/miss-auto.md" source-line
assert_eq "$(grep -cE '^\*\*Source:\*\*' "$r/.woostack/plans/miss-auto.md")" "1" "re-insert is a no-op"
# --- repair: sync source: ← line ---
bash "$C/plan-source.sh" --fix "$r" "$r/.woostack/plans/sync.md" source-sync
assert_eq "$(field "$r/.woostack/plans/sync.md" source)" ".woostack/specs/b.md" "source: synced to the line's spec"
# clean diagnose after repairs (orphan report remains)
res="$(bash "$C/plan-source.sh" "$r")"
assert_eq "$(printf '%s\n' "$res" | grep -c 'auto')" "0" "no auto findings remain"
assert_contains "$res" ".woostack/plans/orphan.md" "orphan report persists"
assert_eq "$(grep -nE '(^|[^[:alnum:]_])(git|gh)[[:space:]]' "$C/plan-source.sh")" "" "plan-source calls no git/gh"
```

- [ ] Run, confirm green (`exit=0`).

### Task 4.4: catalog rows

- [ ] Add to `references/checks.md`:

```
| `plan-source` | plan missing the `**Source:**` join line | warn | auto (source: resolves) / report | `<root> <plan> source-line` |
| `plan-source-sync` | plan `source:` basename ≠ `**Source:**` line basename | warn | auto | `<root> <plan> source-sync` |
```

- [ ] `bash scripts/tests/test-no-stale-paths.sh; echo "exit=$?"` → `exit=0`.

### Task 4.5: whole-suite + auto-discovery smoke

- [ ] Run the entire doctor suite green:

```
bash skills/woostack-doctor/scripts/tests/run-tests.sh; echo "exit=$?"
```

Expected: every `== test-*.sh ==` block passes, `exit=0`.

- [ ] Smoke: seed a scratch workspace with one bad case per check and confirm `doctor.sh`
  auto-discovers all four new codes, and `--check` exits nonzero **only** when an unknown `status:`
  is present:

```bash
r="$(mktemp -d)"; mkdir -p "$r/.woostack/specs" "$r/.woostack/plans" "$r/.woostack/fixes"
printf -- '---\ntype: spec\nstatus: executing\n---\n\n# s\n' > "$r/.woostack/specs/s.md"   # doc-type? no; status-band yes
printf -- '---\nstatus: planning\n---\n\n# p\n'             > "$r/.woostack/plans/p.md"    # doc-type (missing) + plan-source(report)
D=skills/woostack-doctor/scripts/doctor.sh
bash "$D" "$r" | grep -oE 'doc-type|status-band|plan-source' | sort -u    # expect the codes present
bash "$D" "$r" --check; echo "exit (no bad status) = $?"                  # expect 0 (all warn)
printf -- '---\ntype: fix\nstatus: zzz\n---\n\n# f\n' > "$r/.woostack/fixes/f.md"          # unknown status → error
bash "$D" "$r" --check; echo "exit (bad status) = $?"                     # expect 1
```

Expected: codes listed; first `--check` exit `0`, second exit `1`.

### Task 4.6: commit increment 4

- [ ] Hand to `woostack-commit`. Subject:
  `feat(doctor): plan-source + plan-source-sync checks — repair the plan→spec join line`.

---

## Self-review notes

- **Spec coverage:** AC1→Inc1, AC2/AC3→Inc2, AC4→Inc3, AC5/AC6→Inc4; AC7 (no-git grep asserts per
  check + the existing approval gate)→every increment's test; AC8 (auto-discovery + catalog +
  `test-no-stale-paths` + the Inc4 smoke)→each increment's catalog task + Task 4.5. Every AC and
  filled happy/error/edge case maps to a task.
- **Placeholder scan:** every check + test step carries complete code and exact run/expect; no TBD.
- **Type consistency:** `basename_of`/`line_base` used identically in diagnose and `--fix`;
  `field`/`set_field` reused from `lib.sh`; `emit` signature uniform; membership uses the
  `${VAR/ $x /}` idiom everywhere; findings path column is `.woostack/<dir>/<file>.md` in both the
  emit and every test needle.
- **Decomposition:** 4 independently shippable increments, one linear `gt` stack on the spec+plan
  PR, no `## Track:` headings, no `woostack-defer` markers (auto-discovery makes each self-contained).
