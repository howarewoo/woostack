#!/usr/bin/env bash
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DIR/tests/assert.sh"
G="$DIR/graph.sh"

md="$(mktemp -d)"
mk_note "$md" a.md $'name: a\ntype: pattern' 'links to [[b]] and [[c]]'
mk_note "$md" b.md $'name: b\ntype: pattern' 'b body, points to [[c]]'
mk_note "$md" c.md $'name: c\ntype: pattern' 'c body, no links'

# --links (default mode is --links)
out="$(bash "$G" "$md" a)"
assert_contains "$out" "b" "a links to b"
assert_contains "$out" "c" "a links to c"
out="$(bash "$G" "$md" a --links)"
assert_contains "$out" "b" "explicit --links b"

# note name tolerant of .md suffix
out="$(bash "$G" "$md" a.md --links)"
assert_contains "$out" "b" ".md suffix tolerated"

# no links -> empty, exit 0
set +e; out="$(bash "$G" "$md" c --links)"; code=$?; set -e
assert_eq "$out" "" "c has no links -> empty"
assert_exit 0 "$code" "no links -> exit 0"

# --backlinks: who links to c? a and b
out="$(bash "$G" "$md" c --backlinks)"
assert_contains "$out" "a" "a backlinks c"
assert_contains "$out" "b" "b backlinks c"
out="$(bash "$G" "$md" b --backlinks)"
assert_contains "$out" "a" "a backlinks b"
assert_not_contains "$out" "c" "c does not backlink b"

# backlinks of a dangling target (no file) still works
out="$(bash "$G" "$md" ghost --backlinks)"
assert_eq "$out" "" "no backlinks to ghost"

# --links on missing note -> exit 1
set +e; bash "$G" "$md" nope --links >/dev/null 2>&1; code=$?; set -e
assert_exit 1 "$code" "missing note --links exits 1"

# obsidian branch is NOT used by default (no WOOSTACK_OBSIDIAN) even if obsidian exists
out="$(bash "$G" "$md" a --links)"
assert_contains "$out" "b" "default uses grep path"

# dot in note name must not wildcard-match via unescaped ERE
mk_note "$md" 'a.b.md'   $'name: a.b\ntype: pattern'   'body'
mk_note "$md" 'decoy.md' $'name: decoy\ntype: pattern' 'links [[aXb]]'
out="$(bash "$G" "$md" 'a.b' --backlinks)"
assert_not_contains "$out" "decoy" "dot in note name is escaped, no wildcard false-match"

# unknown mode (neither --links nor --backlinks) -> exit 2
set +e; bash "$G" "$md" a --bad-mode >/dev/null 2>&1; code=$?; set -e
assert_exit 2 "$code" "unknown mode exits 2"

rm -rf "$md"
finish
