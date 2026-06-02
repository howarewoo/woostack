#!/usr/bin/env bash
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DIR/tests/assert.sh"
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

# cap protects global: tiny cap still keeps flat shard, drops scoped
printf 'packages/api/x.ts\n' > "$paths"
out="$(RECALL_CAP=40 bash "$RECALL" "$woo" "$paths" 2>/dev/null)"
assert_contains "$out" "do not flag X" "global protected under tiny cap"

rm -rf "$woo" "$woo2" "$woo3"
finish
