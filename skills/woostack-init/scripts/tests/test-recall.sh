#!/usr/bin/env bash
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DIR/tests/assert.sh"
source "$DIR/lib.sh"
RECALL="$DIR/recall.sh"

# Build a fixture .woostack with flat file + scoped notes.
woo="$(mktemp -d)"; md="$woo/memory"; mkdir -p "$md"
printf -- '- accepted: do not flag X\n' > "$woo/memory.md"
mk_note "$md" api.md      $'name: api\ntype: pattern\nscope: packages/api/**' 'API note body'
mk_note "$md" web.md      $'name: web\ntype: pattern\nscope: apps/web/**' 'WEB note [[api]] body'
mk_note "$md" glob.md     $'name: glob\ntype: convention\nscope: *' 'GLOBAL note body'
paths="$(mktemp)"; printf 'packages/api/x.ts\n' > "$paths"

out="$(bash "$RECALL" "$woo" "$paths")"
assert_contains "$out" "API note body" "matched scoped note included"
assert_not_contains "$out" "WEB note" "unmatched note excluded"
assert_contains "$out" "GLOBAL note body" "global (scope:*) note always included"
assert_contains "$out" "do not flag X" "flat global shard always included"

# one-hop: changing apps/web pulls web.md, which links [[api]] -> api.md too
printf 'apps/web/y.tsx\n' > "$paths"
out="$(bash "$RECALL" "$woo" "$paths")"
assert_contains "$out" "WEB note" "web matched"
assert_contains "$out" "API note body" "one-hop [[api]] pulled in"

# two hops do NOT chain: make api link [[deep]]; deep must NOT appear via web->api->deep
mk_note "$md" deep.md $'name: deep\ntype: pattern\nscope: zzz/**' 'DEEP note body'
mk_note "$md" api.md  $'name: api\ntype: pattern\nscope: packages/api/**' 'API note [[deep]] body'
out="$(bash "$RECALL" "$woo" "$paths")"
assert_not_contains "$out" "DEEP note body" "two-hop not chained"

# only-flat-file repo degrades to flat content
woo2="$(mktemp -d)"; printf -- '- only flat here\n' > "$woo2/memory.md"
out="$(bash "$RECALL" "$woo2" "$paths")"
assert_contains "$out" "only flat here" "only-flat repo: flat content emitted"

# neither source -> empty, exit 0
woo3="$(mktemp -d)"
set +e; out="$(bash "$RECALL" "$woo3" "$paths")"; code=$?; set -e
assert_eq "$out" "" "no memory -> empty output"
assert_exit 0 "$code" "no memory -> exit 0"

# cap protects global: cap=70 sits between global_out(~54B) and global+api_chunk(~87B)
# so global survives intact while the scoped note is dropped — NOT the tail-cap branch.
printf 'packages/api/x.ts\n' > "$paths"
out="$(RECALL_CAP=70 bash "$RECALL" "$woo" "$paths" 2>/dev/null)"
assert_contains "$out" "do not flag X" "global protected under cap"
assert_not_contains "$out" "API note" "scoped note dropped under cap"
err="$(RECALL_CAP=70 bash "$RECALL" "$woo" "$paths" 2>&1 >/dev/null)"
assert_contains "$err" "dropped" "drop logged to stderr"

# ordering: higher match-count note appears before lower in output
woo4="$(mktemp -d)"; md4="$woo4/memory"; mkdir -p "$md4"
mk_note "$md4" wide.md   $'name: wide\ntype: pattern\nscope: packages/**'     'WIDE note body'
mk_note "$md4" narrow.md $'name: narrow\ntype: pattern\nscope: packages/api/**' 'NARROW note body'
paths2="$(mktemp)"; printf 'packages/api/x.ts\npackages/lib/y.ts\n' > "$paths2"
out="$(bash "$RECALL" "$woo4" "$paths2")"
wide_line="$(printf '%s\n' "$out" | grep -n 'WIDE note' | cut -d: -f1)"
narrow_line="$(printf '%s\n' "$out" | grep -n 'NARROW note' | cut -d: -f1)"
# wide matches 2 paths, narrow matches 1 — wide must sort first
[ -n "$wide_line" ] && [ -n "$narrow_line" ] && [ "$wide_line" -lt "$narrow_line" ] \
  && PASS=$((PASS+1)) \
  || { FAIL=$((FAIL+1)); echo "  FAIL: ordering — wide(line $wide_line) should precede narrow(line $narrow_line)"; }

rm -rf "$woo" "$woo2" "$woo3" "$woo4" "$paths2"

# --- telemetry stamping ---
woo5="$(mktemp -d)"; md5="$woo5/memory"; mkdir -p "$md5"
mk_note "$md5" a.md $'name: a\ntype: pattern\nscope: pkg/**'      'A body [[b]]'
mk_note "$md5" b.md $'name: b\ntype: pattern\nscope: zzz/**'      'B linked body'
mk_note "$md5" g.md $'name: g\ntype: convention\nscope: *'        'G global body'
p5="$(mktemp)"; printf 'pkg/x.ts\n' > "$p5"

WOOSTACK_NOW=2026-06-02 bash "$RECALL" "$woo5" "$p5" >/dev/null
assert_eq "$(field "$md5/a.md" recall_count)"  "1"          "matched note stamped count=1"
assert_eq "$(field "$md5/a.md" last_recalled)" "2026-06-02" "matched note last_recalled stamped"
assert_eq "$(field "$md5/b.md" recall_count)"  "1"          "one-hop linked note stamped"
assert_eq "$(field "$md5/g.md" recall_count)"  "1"          "global (scope:*) note stamped"

# second run bumps the cumulative count and refreshes the date
WOOSTACK_NOW=2026-06-03 bash "$RECALL" "$woo5" "$p5" >/dev/null
assert_eq "$(field "$md5/a.md" recall_count)"  "2"          "second run bumps count to 2"
assert_eq "$(field "$md5/a.md" last_recalled)" "2026-06-03" "second run refreshes last_recalled"

# best-effort: a read-only memory dir makes stamping fail, but recall still
# produces output and exits 0, logging the failure to stderr.
chmod -R a-w "$md5" 2>/dev/null || true
set +e
out="$(WOOSTACK_NOW=2026-06-04 bash "$RECALL" "$woo5" "$p5" 2>/dev/null)"; code=$?
err="$(WOOSTACK_NOW=2026-06-04 bash "$RECALL" "$woo5" "$p5" 2>&1 >/dev/null)"
set -e
chmod -R u+w "$md5" 2>/dev/null || true
assert_exit 0 "$code"            "recall exits 0 even when stamping fails"
assert_contains "$out" "A body"  "recall output intact when stamping fails"
assert_contains "$err" "stamp failed" "stamp failure logged to stderr"
rm -rf "$woo5" "$p5"

# --- recency tiebreak: equal match-count, newer updated: ranks first ---
woo6="$(mktemp -d)"; md6="$woo6/memory"; mkdir -p "$md6"
mk_note "$md6" older.md $'name: older\ntype: pattern\nscope: packages/api/**\nupdated: 2026-01-01' 'OLDER body'
mk_note "$md6" newer.md $'name: newer\ntype: pattern\nscope: packages/api/**\nupdated: 2026-06-02' 'NEWER body'
p6="$(mktemp)"; printf 'packages/api/x.ts\n' > "$p6"
out="$(bash "$RECALL" "$woo6" "$p6")"
o_line="$(printf '%s\n' "$out" | grep -n 'OLDER body' | cut -d: -f1)"
n_line="$(printf '%s\n' "$out" | grep -n 'NEWER body' | cut -d: -f1)"
[ -n "$o_line" ] && [ -n "$n_line" ] && [ "$n_line" -lt "$o_line" ] \
  && PASS=$((PASS+1)) \
  || { FAIL=$((FAIL+1)); echo "  FAIL: recency tie — newer(line $n_line) should precede older(line $o_line)"; }

# --- undated loses the tie to a dated note of equal count ---
woo7="$(mktemp -d)"; md7="$woo7/memory"; mkdir -p "$md7"
mk_note "$md7" undated.md $'name: undated\ntype: pattern\nscope: packages/api/**' 'STALE body'
mk_note "$md7" dated.md   $'name: dated\ntype: pattern\nscope: packages/api/**\nupdated: 2026-06-02' 'FRESH body'
p7="$(mktemp)"; printf 'packages/api/x.ts\n' > "$p7"
out="$(bash "$RECALL" "$woo7" "$p7")"
u_line="$(printf '%s\n' "$out" | grep -n 'STALE body' | cut -d: -f1)"
d_line="$(printf '%s\n' "$out" | grep -n 'FRESH body' | cut -d: -f1)"
[ -n "$u_line" ] && [ -n "$d_line" ] && [ "$d_line" -lt "$u_line" ] \
  && PASS=$((PASS+1)) \
  || { FAIL=$((FAIL+1)); echo "  FAIL: undated tie — dated(line $d_line) should precede undated(line $u_line)"; }

# --- under a tight cap, the OLDER same-count note is the one dropped ---
cap_out="$(RECALL_CAP=40 bash "$RECALL" "$woo6" "$p6" 2>/dev/null)"
assert_contains "$cap_out" "NEWER body" "newer note survives the cap on a tie"
assert_not_contains "$cap_out" "OLDER body" "older note dropped first under cap on a tie"

rm -rf "$woo6" "$p6" "$woo7" "$p7"

finish
