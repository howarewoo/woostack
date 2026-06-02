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

# --- _woo_now / _woo_epoch ---
assert_eq "$(WOOSTACK_NOW=2026-01-02 _woo_now)" "2026-01-02" "_woo_now honors WOOSTACK_NOW"
e1="$(_woo_epoch 2026-01-01)"; e2="$(_woo_epoch 2026-01-02)"
assert_eq "$(( e2 - e1 ))" "86400" "_woo_epoch: one day apart = 86400s (time-of-day zeroed)"
set +e; _woo_epoch "not-a-date" >/dev/null 2>&1; rc=$?; set -e
assert_exit 1 "$rc" "_woo_epoch returns non-zero on unparseable input"

finish
