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
mk_note "$md" live-source-spec.md $'name: live-source-spec\ntype: pattern\nscope: packages/api/**\nsource: .woostack/specs/existing.md\nupdated: 2026-06-02' 'body'
mk_note "$md" live-source-plan.md $'name: live-source-plan\ntype: pattern\nscope: packages/api/**\nsource: .woostack/plans/existing.md\nupdated: 2026-06-02' 'body'
mk_note "$md" pr-source.md $'name: pr-source\ntype: convention\nscope: packages/api/**\nsource: pr-165\nupdated: 2026-06-02' 'body'
pushd "$repo" >/dev/null; run_doctor ".woostack/memory"; popd >/dev/null
# Target the provenance warning specifically — these notes legitimately appear in
# an overlap cluster (they share scope packages/api/** with other store notes),
# so a bare-name check would false-fail. Intent: no stale-provenance warning.
assert_not_contains "$OUT" "live-source-spec.md: source" "existing spec source is not warned"
assert_not_contains "$OUT" "live-source-plan.md: source" "existing plan source is not warned"
assert_not_contains "$OUT" "pr-source.md: source" "PR source is not treated as a filesystem path"

# --- distillation-gate backstop warnings ---
# missing source: → warn, exit 0
mk_note "$md" no-source.md $'name: no-source\ntype: pattern\nscope: packages/api/**\nupdated: 2026-06-02' 'body'
pushd "$repo" >/dev/null; run_doctor ".woostack/memory"; popd >/dev/null
assert_contains "$OUT" "no-source.md: missing source:" "note without source: is warned"
assert_exit 0 "$CODE" "missing source: is a warning"

# non-glob scope (single literal path), distill-origin → warn
mk_note "$md" nonglob.md $'name: nonglob\ntype: pattern\nscope: packages/api/handler.ts\nupdated: 2026-06-02\nsource: .woostack/specs/existing.md' 'body'
pushd "$repo" >/dev/null; run_doctor ".woostack/memory"; popd >/dev/null
assert_contains "$OUT" "nonglob.md: non-glob scope" "single literal scope warned as possible trivia"
assert_exit 0 "$CODE" "non-glob scope is a warning"

# all-literal multi-scope (no * anywhere) → warn
mk_note "$md" multilit.md $'name: multilit\ntype: pattern\nscope: a/b.ts, c/d.ts\nupdated: 2026-06-02\nsource: .woostack/specs/existing.md' 'body'
pushd "$repo" >/dev/null; run_doctor ".woostack/memory"; popd >/dev/null
assert_contains "$OUT" "multilit.md: non-glob scope" "all-literal multi-scope warned"

# globbed scope → no warning
mk_note "$md" globbed.md $'name: globbed\ntype: pattern\nscope: packages/api/**\nupdated: 2026-06-02\nsource: .woostack/specs/existing.md' 'body'
pushd "$repo" >/dev/null; run_doctor ".woostack/memory"; popd >/dev/null
assert_not_contains "$OUT" "globbed.md: non-glob scope" "a globbed scope is not flagged"

# global scope (*) → no warning
mk_note "$md" globalscope.md $'name: globalscope\ntype: pattern\nscope: *\nupdated: 2026-06-02\nsource: .woostack/specs/existing.md' 'body'
pushd "$repo" >/dev/null; run_doctor ".woostack/memory"; popd >/dev/null
assert_not_contains "$OUT" "globalscope.md: non-glob scope" "global scope is exempt"

# multi-glob scope (contains *) → no warning
mk_note "$md" multiglob.md $'name: multiglob\ntype: pattern\nscope: packages/api/**, apps/*/x.ts\nupdated: 2026-06-02\nsource: .woostack/specs/existing.md' 'body'
pushd "$repo" >/dev/null; run_doctor ".woostack/memory"; popd >/dev/null
assert_not_contains "$OUT" "multiglob.md: non-glob scope" "a multi-glob scope (contains *) is not flagged"

# absent scope field → exempt (global)
mk_note "$md" noscope.md $'name: noscope\ntype: pattern\nupdated: 2026-06-02\nsource: .woostack/specs/existing.md' 'body'
pushd "$repo" >/dev/null; run_doctor ".woostack/memory"; popd >/dev/null
assert_not_contains "$OUT" "noscope.md: non-glob scope" "absent scope is exempt from non-glob warning"

# review-provenance (pr-*) with literal scope → exempt
mk_note "$md" review-pr.md $'name: review-pr\ntype: convention\nscope: packages/api/handler.ts\nupdated: 2026-06-02\nsource: pr-42' 'body'
pushd "$repo" >/dev/null; run_doctor ".woostack/memory"; popd >/dev/null
assert_not_contains "$OUT" "review-pr.md: non-glob scope" "review-provenance note is exempt from non-glob warning"

# review-provenance (address-comments) with literal scope → exempt
mk_note "$md" review-ac.md $'name: review-ac\ntype: convention\nscope: packages/api/handler.ts\nupdated: 2026-06-02\nsource: address-comments' 'body'
pushd "$repo" >/dev/null; run_doctor ".woostack/memory"; popd >/dev/null
assert_not_contains "$OUT" "review-ac.md: non-glob scope" "address-comments note is exempt"

# missing updated: → warn (cannot be aged), exit 0
mu="$(mktemp -d)/m"; mkdir -p "$mu"
mk_note "$mu" noupd2.md $'name: noupd2\ntype: pattern\nscope: *\nsource: pr-1' 'body'
OUT="$(bash "$DOC" "$mu" 2>&1)"; CODE=$?
assert_contains "$OUT" "noupd2.md: missing updated:" "note without updated: is warned"
assert_exit 0 "$CODE" "missing updated: is a warning"
assert_not_contains "$OUT" "dead note" "missing updated: does not also emit a dead-note signal"
rm -rf "$mu"

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
mk_note "$dd2" old.md $'name: old\ntype: pattern\nscope: *\nupdated: 2026-01-01' 'body'
printf 'old\t3\t2026-05-01\n' > "$dd2/.telemetry.tsv"
OUT="$(WOOSTACK_NOW=2026-06-02 bash "$DOC" "$dd2" 2>&1)"
assert_not_contains "$OUT" "dead note" "a note recalled per the sidecar is never flagged dead"

# fresh updated → not flagged
dd3="$(mktemp -d)/m"; mkdir -p "$dd3"
mk_note "$dd3" fresh.md $'name: fresh\ntype: pattern\nscope: *\nupdated: 2026-05-30' 'body'
OUT="$(WOOSTACK_NOW=2026-06-02 bash "$DOC" "$dd3" 2>&1)"
assert_not_contains "$OUT" "dead note" "a fresh note is not flagged"

# no updated: → not aged by the dead-note check, but does warn "missing updated:"
dd4="$(mktemp -d)/m"; mkdir -p "$dd4"
mk_note "$dd4" noupd.md $'name: noupd\ntype: pattern\nscope: *' 'body'
OUT="$(WOOSTACK_NOW=2026-06-02 bash "$DOC" "$dd4" 2>&1)"
assert_not_contains "$OUT" "dead note" "a note without updated: gets no dead-note signal"
assert_contains "$OUT" "noupd.md: missing updated:" "a note without updated: is warned (cannot be aged)"

# WOOSTACK_DEAD_DAYS tightens the window
dd5="$(mktemp -d)/m"; mkdir -p "$dd5"
mk_note "$dd5" recent.md $'name: recent\ntype: pattern\nscope: *\nupdated: 2026-05-30' 'body'
OUT="$(WOOSTACK_NOW=2026-06-02 WOOSTACK_DEAD_DAYS=1 bash "$DOC" "$dd5" 2>&1)"
assert_contains "$OUT" "dead note" "DEAD_DAYS=1 flags a 3-day-old never-recalled note"
rm -rf "$dd1" "$dd2" "$dd3" "$dd4" "$dd5"

# --- overlap clusters (own git repo: needs tracked files) ---
orepo="$(mktemp -d)"
( cd "$orepo" && git -c user.email=t@t -c user.name=t init -q \
    && mkdir -p packages/api apps/web && touch packages/api/x.ts apps/web/y.tsx \
    && git add -A && git -c user.email=t@t -c user.name=t commit -qm init )
omd="$orepo/.woostack/memory"; mkdir -p "$omd"

# two notes matching the same tracked file → one cluster naming both (min-name order)
mk_note "$omd" c1.md $'name: c1\ntype: pattern\nscope: packages/api/**\nupdated: 2026-06-02\nsource: pr-1' 'b'
mk_note "$omd" c2.md $'name: c2\ntype: gotcha\nscope: packages/api/orpc/**, packages/api/x.ts\nupdated: 2026-06-02\nsource: pr-2' 'b'
pushd "$orepo" >/dev/null; run_doctor ".woostack/memory"; popd >/dev/null
assert_contains "$OUT" "overlap cluster: c1.md, c2.md" "two notes on a shared file form one cluster"
assert_exit 0 "$CODE" "overlap cluster is a warning (exit 0)"

# add a disjoint note (apps/web only) → not in the api cluster
mk_note "$omd" web.md $'name: web\ntype: pattern\nscope: apps/web/**\nupdated: 2026-06-02\nsource: pr-3' 'b'
pushd "$orepo" >/dev/null; run_doctor ".woostack/memory"; popd >/dev/null
assert_not_contains "$OUT" "web.md" "a disjoint-scope note is not clustered"
assert_contains "$OUT" "overlap cluster: c1.md, c2.md" "disjoint note does not disturb the api cluster"

# add a global note → never clustered
mk_note "$omd" g.md $'name: g\ntype: convention\nscope: *\nupdated: 2026-06-02\nsource: pr-4' 'b'
pushd "$orepo" >/dev/null; run_doctor ".woostack/memory"; popd >/dev/null
assert_not_contains "$OUT" "overlap cluster: c1.md, c2.md, g.md" "global note is exempt from clustering"

# add a third api note → single cluster of three, sorted
mk_note "$omd" c3.md $'name: c3\ntype: pattern\nscope: packages/api/**\nupdated: 2026-06-02\nsource: pr-5' 'b'
pushd "$orepo" >/dev/null; run_doctor ".woostack/memory"; popd >/dev/null
assert_contains "$OUT" "overlap cluster: c1.md, c2.md, c3.md" "three notes on a shared file form one sorted cluster"

# a stale note (matches no tracked file) is never clustered, only stale-warned
ostale="$(mktemp -d)"
( cd "$ostale" && git -c user.email=t@t -c user.name=t init -q \
    && mkdir -p packages/api && touch packages/api/x.ts \
    && git add -A && git -c user.email=t@t -c user.name=t commit -qm init )
osmd="$ostale/.woostack/memory"; mkdir -p "$osmd"
mk_note "$osmd" real.md  $'name: real\ntype: pattern\nscope: packages/api/**\nupdated: 2026-06-02\nsource: pr-1' 'b'
mk_note "$osmd" ghost.md $'name: ghost\ntype: pattern\nscope: zzz/**\nupdated: 2026-06-02\nsource: pr-2' 'b'
pushd "$ostale" >/dev/null; run_doctor ".woostack/memory"; popd >/dev/null
assert_not_contains "$OUT" "overlap cluster" "a lone real note + a stale note form no cluster"
assert_contains "$OUT" "ghost.md: scope 'zzz/**' matches no tracked files (stale)" "stale note still stale-warned"

rm -rf "$orepo" "$ostale"

rm -rf "$repo"
finish
