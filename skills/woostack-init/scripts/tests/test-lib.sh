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

# --- set_field ---
sfd="$(mktemp -d)"
mk_note "$sfd" n.md $'name: x\ntype: pattern\nscope: a/**' 'body [[link]] here'
# update existing key
set_field "$sfd/n.md" type "gotcha"
assert_eq "$(field "$sfd/n.md" type)" "gotcha" "set_field updates an existing key"
assert_eq "$(field "$sfd/n.md" name)" "x" "set_field: other fields preserved on update"
assert_contains "$(note_body "$sfd/n.md")" "body [[link]] here" "set_field: body preserved on update"
# insert absent key
set_field "$sfd/n.md" recall_count "1"
assert_eq "$(field "$sfd/n.md" recall_count)" "1" "set_field inserts an absent key"
assert_eq "$(field "$sfd/n.md" name)" "x" "set_field: fields intact after insert"
assert_contains "$(note_body "$sfd/n.md")" "body [[link]] here" "set_field: body intact after insert"
# date value round-trips
set_field "$sfd/n.md" last_recalled "2026-06-02"
assert_eq "$(field "$sfd/n.md" last_recalled)" "2026-06-02" "set_field: date value round-trips"
# malformed note (no frontmatter) → non-zero, file unchanged
printf 'no frontmatter\n' > "$sfd/bad.md"
set +e; set_field "$sfd/bad.md" recall_count 1; rc=$?; set -e
assert_exit 1 "$rc" "set_field fails on a note without frontmatter"
assert_eq "$(cat "$sfd/bad.md")" "no frontmatter" "set_field leaves a malformed note unchanged"
rm -rf "$sfd"

# --- telemetry sidecar ---
tmd="$(mktemp -d)"
tel_bump "$tmd" "alpha" "2026-06-11"
assert_eq "$(tel_get "$tmd" alpha recall_count)"  "1"          "tel_bump creates row count=1"
assert_eq "$(tel_get "$tmd" alpha last_recalled)" "2026-06-11" "tel_bump sets date"
tel_bump "$tmd" "alpha" "2026-06-12"
assert_eq "$(tel_get "$tmd" alpha recall_count)"  "2"          "tel_bump increments existing row"
assert_eq "$(tel_get "$tmd" alpha last_recalled)" "2026-06-12" "tel_bump refreshes date"
assert_eq "$(tel_get "$tmd" missing recall_count)" ""          "tel_get of unknown note is empty"
rm -rf "$tmd"

# --- del_field ---
dfd="$(mktemp -d)"; mk_note "$dfd" n.md $'name: x\ntype: pattern\nrecall_count: 3\nlast_recalled: 2026-01-01' 'body'
del_field "$dfd/n.md" recall_count
del_field "$dfd/n.md" last_recalled
assert_eq "$(field "$dfd/n.md" recall_count)"  "" "del_field removes recall_count"
assert_eq "$(field "$dfd/n.md" last_recalled)" "" "del_field removes last_recalled"
assert_eq "$(field "$dfd/n.md" name)" "x" "del_field preserves other fields"
assert_contains "$(note_body "$dfd/n.md")" "body" "del_field preserves body"
rm -rf "$dfd"

finish
