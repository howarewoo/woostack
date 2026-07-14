#!/usr/bin/env bash
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DIR/tests/assert.sh"
source "$DIR/lib.sh"
RECALL="$DIR/recall.sh"

# Build a fixture .woostack with scoped notes.
woo="$(mktemp -d)"; md="$woo/memory"; mkdir -p "$md"
# Global memory now = global-scoped notes only.
mk_note "$md" gx.md       $'name: gx\ntype: convention\nscope: *\nupdated: 2026-06-02' '- accepted: do not flag X'
bash "$DIR/build-index.sh" "$md" >/dev/null
mk_note "$md" api.md      $'name: api\ntype: pattern\nscope: packages/api/**' 'API note body'
mk_note "$md" web.md      $'name: web\ntype: pattern\nscope: apps/web/**' 'WEB note [[api]] body'
mk_note "$md" glob.md     $'name: glob\ntype: convention\nscope: *' 'GLOBAL note body'
paths="$(mktemp)"; printf 'packages/api/x.ts\n' > "$paths"

out="$(bash "$RECALL" "$woo" "$paths")"
assert_contains "$out" "API note body" "matched scoped note included"
assert_not_contains "$out" "WEB note" "unmatched note excluded"
assert_contains "$out" "GLOBAL note body" "global (scope:*) note always included"
assert_contains "$out" "do not flag X" "global-scoped note always included"

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

# neither source -> empty, exit 0
woo3="$(mktemp -d)"
set +e; out="$(bash "$RECALL" "$woo3" "$paths")"; code=$?; set -e
assert_eq "$out" "" "no memory -> empty output"
assert_exit 0 "$code" "no memory -> exit 0"

# only-flat-file repo also degrades to empty; flat memory.md is no longer read.
woo2="$(mktemp -d)"; printf -- '- only flat here\n' > "$woo2/memory.md"
set +e; out="$(bash "$RECALL" "$woo2" "$paths")"; code=$?; set -e
assert_eq "$out" "" "only-flat repo -> empty output"
assert_exit 0 "$code" "only-flat repo -> exit 0"

# cap protects global: cap=70 sits between global_out(~54B) and global+api_chunk(~87B)
# so global survives intact while the scoped note is dropped — NOT the tail-cap branch.
printf 'packages/api/x.ts\n' > "$paths"
out="$(RECALL_CAP=70 bash "$RECALL" "$woo" "$paths" 2>/dev/null)"
assert_contains "$out" "do not flag X" "global-scoped note protected under cap"
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
mk_note "$md5" alpha.md $'name: a\ntype: pattern\nscope: pkg/**'  'A body [[b]]'
mk_note "$md5" b.md $'name: b\ntype: pattern\nscope: zzz/**'      'B linked body'
mk_note "$md5" g.md $'name: g\ntype: convention\nscope: *'        'G global body'
p5="$(mktemp)"; printf 'pkg/x.ts\n' > "$p5"

WOOSTACK_NOW=2026-06-02 bash "$RECALL" "$woo5" "$p5" >/dev/null
assert_eq "$(tel_get "$md5" a recall_count)"  "1"          "matched note stamped count=1"
assert_eq "$(tel_get "$md5" a last_recalled)" "2026-06-02" "matched note last_recalled stamped"
assert_eq "$(tel_get "$md5" b recall_count)"  "1"          "one-hop linked note stamped"
assert_eq "$(tel_get "$md5" g recall_count)"  "1"          "global note stamped"
assert_eq "$(field "$md5/alpha.md" recall_count)" "" "recall does not write telemetry into note frontmatter"

# second run bumps the cumulative count and refreshes the date
WOOSTACK_NOW=2026-06-03 bash "$RECALL" "$woo5" "$p5" >/dev/null
assert_eq "$(tel_get "$md5" a recall_count)"  "2"          "second run bumps count to 2"
assert_eq "$(tel_get "$md5" a last_recalled)" "2026-06-03" "second run refreshes last_recalled"

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

# ===== tag-hop recall axis =====

# --- AC1/AC2/AC4/AC6: general tag expansion, one-hop bound, global-not-source, dedup ---
wooT1="$(mktemp -d)"; mdT1="$wooT1/memory"; mkdir -p "$mdT1"
mk_note "$mdT1" hit.md     $'name: hit\ntype: pattern\nscope: packages/api/**\ntags: orpc, Errors' 'HIT scoped body'
mk_note "$mdT1" rel.md     $'name: rel\ntype: pattern\nscope: apps/web/**\ntags: errors, onlyrel' 'REL tagged body'
mk_note "$mdT1" second.md  $'name: second\ntype: pattern\nscope: yyy/**\ntags: onlyrel' 'SECOND body'
mk_note "$mdT1" nomatch.md $'name: nomatch\ntype: pattern\nscope: zzz/**\ntags: unrelated' 'NOMATCH body'
mk_note "$mdT1" gseed.md   $'name: gseed\ntype: convention\nscope: *\ntags: errors' 'GSEED global body'
mk_note "$mdT1" gsrc.md    $'name: gsrc\ntype: convention\nscope: *\ntags: globonly' 'GSRC global body'
mk_note "$mdT1" gtarget.md $'name: gtarget\ntype: pattern\nscope: qqq/**\ntags: globonly' 'GTARGET body'
pT1="$(mktemp)"; printf 'packages/api/x.ts\n' > "$pT1"
out="$(bash "$RECALL" "$wooT1" "$pT1")"
assert_contains "$out" "## Tag-related notes"  "tag-related section rendered"
assert_contains "$out" "REL tagged body"       "AC1 happy: shared-tag note surfaced (case-insensitive Errors/errors)"
assert_not_contains "$out" "NOMATCH body"      "AC1 edge: no-shared-tag note not pulled"
assert_not_contains "$out" "SECOND body"       "AC2 edge: one-hop only — tag shared with a tag-linked note not pulled"
assert_not_contains "$out" "GTARGET body"      "AC4 happy: global tags do not seed expansion"
cnt_gseed="$(printf '%s\n' "$out" | grep -c 'GSEED global body' || true)"
assert_eq "$cnt_gseed" "1"                     "AC4 edge: global candidate skipped, not duplicated into tag-related"
cnt_hit="$(printf '%s\n' "$out" | grep -c 'HIT scoped body' || true)"
assert_eq "$cnt_hit" "1"                       "AC6 edge: scoped note not duplicated into tag-related"
# section order: Scoped < Tag-related < Global (spec §4)
sc="$(printf '%s\n' "$out" | grep -n '## Scoped memory'   | cut -d: -f1 || true)"
tg="$(printf '%s\n' "$out" | grep -n '## Tag-related notes'| cut -d: -f1 || true)"
gl="$(printf '%s\n' "$out" | grep -n '## Global memory'    | cut -d: -f1 || true)"
[ -n "$sc" ] && [ -n "$tg" ] && [ -n "$gl" ] && [ "$sc" -lt "$tg" ] && [ "$tg" -lt "$gl" ] \
  && PASS=$((PASS+1)) \
  || { FAIL=$((FAIL+1)); echo "  FAIL: section order — Scoped($sc) < Tag-related($tg) < Global($gl)"; }

# AC6 happy: a tag-linked note is stamped in telemetry (fresh run for a clean count)
WOOSTACK_NOW=2026-06-02 bash "$RECALL" "$wooT1" "$pT1" >/dev/null 2>&1 || true
# (rel was stamped on the first `out` run above; assert cumulative count >=1)
rel_count="$(tel_get "$mdT1" rel recall_count)"
[ -n "$rel_count" ] && [ "$rel_count" -ge 1 ] \
  && PASS=$((PASS+1)) \
  || { FAIL=$((FAIL+1)); echo "  FAIL: AC6 telemetry — tag-linked note stamped (count=$rel_count)"; }
rm -rf "$wooT1" "$pT1"

# --- AC3: tag-related is lowest cap precedence (dropped first; scoped kept) ---
wooT2="$(mktemp -d)"; mdT2="$wooT2/memory"; mkdir -p "$mdT2"
mk_note "$mdT2" anchor.md $'name: anchor\ntype: pattern\nscope: packages/api/**\ntags: errors' 'ANCHOR body'
mk_note "$mdT2" big.md    $'name: big\ntype: pattern\nscope: apps/web/**\ntags: errors' 'BIG tag body PADPADPADPADPADPADPADPADPADPADPADPADPADPADPADPAD'
pT2="$(mktemp)"; printf 'packages/api/x.ts\n' > "$pT2"
capout="$(RECALL_CAP=40 bash "$RECALL" "$wooT2" "$pT2" 2>/dev/null)"
assert_contains "$capout" "ANCHOR body"      "AC3 edge: scoped note kept under cap"
assert_not_contains "$capout" "BIG tag body" "AC3 happy: tag-related note dropped under cap"
caperr="$(RECALL_CAP=40 bash "$RECALL" "$wooT2" "$pT2" 2>&1 >/dev/null)"
assert_contains "$caperr" "dropped tag-related" "AC3: tag-related drop logged to stderr"
rm -rf "$wooT2" "$pT2"

# --- AC3 extra (spec §6 global tail-cap): globals over cap suppress tag-related too ---
wooT2b="$(mktemp -d)"; mdT2b="$wooT2b/memory"; mkdir -p "$mdT2b"
mk_note "$mdT2b" a2.md  $'name: a2\ntype: pattern\nscope: packages/api/**\ntags: errors' 'A2 body'
mk_note "$mdT2b" r2.md  $'name: r2\ntype: pattern\nscope: apps/web/**\ntags: errors' 'R2 tag body'
mk_note "$mdT2b" bg.md  $'name: bg\ntype: convention\nscope: *' 'BIG GLOBAL body PADPADPADPADPADPADPADPADPADPADPADPAD'
pT2b="$(mktemp)"; printf 'packages/api/x.ts\n' > "$pT2b"
tail_out="$(RECALL_CAP=20 bash "$RECALL" "$wooT2b" "$pT2b" 2>/dev/null)"
tail_err="$(RECALL_CAP=20 bash "$RECALL" "$wooT2b" "$pT2b" 2>&1 >/dev/null)"
assert_not_contains "$tail_out" "## Tag-related notes" "global tail-cap: tag-related suppressed with scoped/linked"
assert_not_contains "$tail_out" "R2 tag body"          "global tail-cap: tag-related note not emitted"
assert_contains "$tail_err" "exceed cap"               "global tail-cap branch logged"
rm -rf "$wooT2b" "$pT2b"

# --- AC5: no tags anywhere -> no tag-related section (regression / no-op) ---
wooT3="$(mktemp -d)"; mdT3="$wooT3/memory"; mkdir -p "$mdT3"
mk_note "$mdT3" p1.md $'name: p1\ntype: pattern\nscope: packages/api/**' 'P1 body'
mk_note "$mdT3" p2.md $'name: p2\ntype: pattern\nscope: apps/web/**\ntags:   ,  ' 'P2 empty-tags body'
mk_note "$mdT3" g1.md $'name: g1\ntype: convention\nscope: *' 'G1 global body'
pT3="$(mktemp)"; printf 'packages/api/x.ts\n' > "$pT3"
out3="$(bash "$RECALL" "$wooT3" "$pT3")"
assert_not_contains "$out3" "## Tag-related notes" "AC5: no/empty tags -> no tag-related section"
assert_contains "$out3" "P1 body"       "AC5: scoped output unchanged when no tags"
assert_contains "$out3" "G1 global body" "AC5: global output unchanged when no tags"
rm -rf "$wooT3" "$pT3"

# --- AC7: ordering under cap (shared-count desc; recency then name tiebreak) ---
wooT4="$(mktemp -d)"; mdT4="$wooT4/memory"; mkdir -p "$mdT4"
mk_note "$mdT4" anc.md $'name: anc\ntype: pattern\nscope: packages/api/**\ntags: a, b' 'ANC body'
mk_note "$mdT4" two.md $'name: two\ntype: pattern\nscope: xxx/**\ntags: a, b' 'TWO body PADPADPADPADPADPAD'
mk_note "$mdT4" one.md $'name: one\ntype: pattern\nscope: yyy/**\ntags: a'    'ONE body PADPADPADPADPADPAD'
pT4="$(mktemp)"; printf 'packages/api/x.ts\n' > "$pT4"
out4="$(bash "$RECALL" "$wooT4" "$pT4")"
two_line="$(printf '%s\n' "$out4" | grep -n 'TWO body' | cut -d: -f1 || true)"
one_line="$(printf '%s\n' "$out4" | grep -n 'ONE body' | cut -d: -f1 || true)"
[ -n "$two_line" ] && [ -n "$one_line" ] && [ "$two_line" -lt "$one_line" ] \
  && PASS=$((PASS+1)) \
  || { FAIL=$((FAIL+1)); echo "  FAIL: AC7 order — two(line $two_line) should precede one(line $one_line)"; }
# under a cap that fits only one tag-related note, the higher-shared-count note survives
cap4="$(RECALL_CAP=60 bash "$RECALL" "$wooT4" "$pT4" 2>/dev/null)"
assert_contains "$cap4" "TWO body"     "AC7 happy: higher shared-tag-count note kept under cap"
assert_not_contains "$cap4" "ONE body" "AC7 happy: lower shared-tag-count note dropped under cap"
rm -rf "$wooT4" "$pT4"

# --- AC7 edge: equal shared-count -> newer updated ranks first ---
wooT5="$(mktemp -d)"; mdT5="$wooT5/memory"; mkdir -p "$mdT5"
mk_note "$mdT5" anc2.md $'name: anc2\ntype: pattern\nscope: packages/api/**\ntags: a' 'ANC2 body'
mk_note "$mdT5" tnew.md $'name: tnew\ntype: pattern\nscope: xxx/**\ntags: a\nupdated: 2026-06-02' 'TNEW body'
mk_note "$mdT5" told.md $'name: told\ntype: pattern\nscope: yyy/**\ntags: a\nupdated: 2026-01-01' 'TOLD body'
pT5="$(mktemp)"; printf 'packages/api/x.ts\n' > "$pT5"
out5="$(bash "$RECALL" "$wooT5" "$pT5")"
tnew_line="$(printf '%s\n' "$out5" | grep -n 'TNEW body' | cut -d: -f1 || true)"
told_line="$(printf '%s\n' "$out5" | grep -n 'TOLD body' | cut -d: -f1 || true)"
[ -n "$tnew_line" ] && [ -n "$told_line" ] && [ "$tnew_line" -lt "$told_line" ] \
  && PASS=$((PASS+1)) \
  || { FAIL=$((FAIL+1)); echo "  FAIL: AC7 recency — tnew(line $tnew_line) should precede told(line $told_line)"; }
rm -rf "$wooT5" "$pT5"

finish
