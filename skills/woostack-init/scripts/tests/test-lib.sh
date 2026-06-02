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
