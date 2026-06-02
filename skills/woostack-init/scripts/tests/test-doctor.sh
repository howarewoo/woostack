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

rm -rf "$repo"
finish
