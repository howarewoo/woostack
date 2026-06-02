#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DIR/tests/assert.sh"
DOC="$DIR/doctor.sh"

OUT=""; CODE=0
run_doctor() { # memdir → captures stderr; sets OUT, CODE
  set +e; OUT="$(bash "$DOC" "$1" 2>&1)"; CODE=$?; set -e
}

# clean store under a real git repo so scope-match has tracked files
repo="$(mktemp -d)"; ( cd "$repo" && git -c user.email=t@t -c user.name=t init -q && mkdir -p packages/api && touch packages/api/x.ts && git add -A && git -c user.email=t@t -c user.name=t commit -qm init )
md="$repo/.woostack/memory"; mkdir -p "$md"
mk_note "$md" ok.md $'name: ok\ntype: pattern\nscope: packages/api/**' 'fine body'
pushd "$repo" >/dev/null; run_doctor ".woostack/memory"; popd >/dev/null
assert_exit 0 "$CODE" "clean store exits 0"

# stale scope → warn, exit 0
mk_note "$md" stale.md $'name: stale\ntype: gotcha\nscope: nope/**' 'body'
pushd "$repo" >/dev/null; run_doctor ".woostack/memory"; popd >/dev/null
assert_contains "$OUT" "stale" "stale scope warned"
assert_exit 0 "$CODE" "warnings still exit 0"

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

# unresolved wikilink → warn
mk_note "$md" link.md $'name: link\ntype: pattern\nscope: packages/api/**' 'see [[ghost]] note'
pushd "$repo" >/dev/null; run_doctor ".woostack/memory"; popd >/dev/null
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

err5="$(mktemp -d)/m"; mkdir -p "$err5"
mk_note "$err5" notype.md $'name: x' 'b'
run_doctor "$err5"; assert_exit 1 "$CODE" "missing type errors"

err6="$(mktemp -d)/m"; mkdir -p "$err6"
mk_note "$err6" nobody.md $'name: x\ntype: pattern' ''
run_doctor "$err6"; assert_exit 1 "$CODE" "empty body errors"

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

rm -rf "$repo"
finish
