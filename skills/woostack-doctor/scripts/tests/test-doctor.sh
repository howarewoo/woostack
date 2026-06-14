#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DIR/../../woostack-init/scripts/tests/assert.sh"
DOC="$DIR/doctor.sh"

OUT=""; CODE=0
run_doctor() { # workspace-root → captures stderr+stdout; sets OUT, CODE
  set +e; OUT="$(bash "$DOC" "$1" 2>&1)"; CODE=$?; set -e
}
# mkws → echo a fresh workspace ROOT containing an empty .woostack/memory.
# The orchestrator takes the workspace root (not the memdir); notes go in
# "$root/.woostack/memory" and doctor is called with "$root".
mkws() { local r; r="$(mktemp -d)"; mkdir -p "$r/.woostack/memory"; printf '%s\n' "$r"; }

# clean store under a real git repo so scope-match has tracked files
repo="$(mktemp -d)"; ( cd "$repo" && git -c user.email=t@t -c user.name=t init -q && mkdir -p packages/api && touch packages/api/x.ts && git add -A && git -c user.email=t@t -c user.name=t commit -qm init )
md="$repo/.woostack/memory"; mkdir -p "$md"
mk_note "$md" ok.md $'name: ok\ntype: pattern\nscope: packages/api/**' 'fine body'
pushd "$repo" >/dev/null; run_doctor "."; popd >/dev/null
assert_exit 0 "$CODE" "clean store exits 0"

# stale scope → warn, exit 0
mk_note "$md" stale.md $'name: stale\ntype: gotcha\nscope: nope/**' 'body'
pushd "$repo" >/dev/null; run_doctor "."; popd >/dev/null
assert_contains "$OUT" "stale" "stale scope warned"
assert_exit 0 "$CODE" "warnings still exit 0"

# missing .woostack source → warn, exit 0
mk_note "$md" stale-source-spec.md $'name: stale-source-spec\ntype: pattern\nscope: packages/api/**\nsource: .woostack/specs/missing.md' 'body'
pushd "$repo" >/dev/null; run_doctor "."; popd >/dev/null
assert_contains "$OUT" "source '.woostack/specs/missing.md' is missing" "missing spec source warned"
assert_exit 0 "$CODE" "missing spec source is a warning"

mk_note "$md" stale-source-plan.md $'name: stale-source-plan\ntype: pattern\nscope: packages/api/**\nsource: .woostack/plans/missing.md' 'body'
pushd "$repo" >/dev/null; run_doctor "."; popd >/dev/null
assert_contains "$OUT" "source '.woostack/plans/missing.md' is missing" "missing plan source warned"
assert_exit 0 "$CODE" "missing plan source is a warning"

mkdir -p "$repo/.woostack/specs" "$repo/.woostack/plans"
touch "$repo/.woostack/specs/existing.md" "$repo/.woostack/plans/existing.md"
mk_note "$md" live-source-spec.md $'name: live-source-spec\ntype: pattern\nscope: packages/api/**\nsource: .woostack/specs/existing.md\nupdated: 2026-06-02' 'body'
mk_note "$md" live-source-plan.md $'name: live-source-plan\ntype: pattern\nscope: packages/api/**\nsource: .woostack/plans/existing.md\nupdated: 2026-06-02' 'body'
mk_note "$md" pr-source.md $'name: pr-source\ntype: convention\nscope: packages/api/**\nsource: pr-165\nupdated: 2026-06-02' 'body'
pushd "$repo" >/dev/null; run_doctor "."; popd >/dev/null
# Target the provenance warning specifically — these notes legitimately appear in
# an overlap cluster (they share scope packages/api/** with other store notes),
# so a bare-name check would false-fail. Intent: no stale-provenance warning.
assert_not_contains "$OUT" "live-source-spec.md: source" "existing spec source is not warned"
assert_not_contains "$OUT" "live-source-plan.md: source" "existing plan source is not warned"
assert_not_contains "$OUT" "pr-source.md: source" "PR source is not treated as a filesystem path"

# --- frontmatter source: as an Obsidian [[wikilink]] (specs/plans/fixes) ---
# The provenance + unresolved-link checks must accept [[<dir>/<basename>]] for the three
# authored artifact dirs, resolving against $WOO_ROOT/.woostack/, with no false unresolved-link.
mkdir -p "$repo/.woostack/fixes"; touch "$repo/.woostack/fixes/existing.md"
mk_note "$md" wl-spec-existing.md $'name: wl-spec-existing\ntype: pattern\nscope: packages/api/**\nsource: [[specs/existing]]\nupdated: 2026-06-02' 'body'
mk_note "$md" wl-plan-existing.md $'name: wl-plan-existing\ntype: pattern\nscope: packages/api/**\nsource: [[plans/existing]]\nupdated: 2026-06-02' 'body'
mk_note "$md" wl-fix-existing.md $'name: wl-fix-existing\ntype: pattern\nscope: packages/api/**\nsource: [[fixes/existing]]\nupdated: 2026-06-02' 'body'
mk_note "$md" wl-md-suffix.md $'name: wl-md-suffix\ntype: pattern\nscope: packages/api/**\nsource: [[plans/existing.md]]\nupdated: 2026-06-02' 'body'
pushd "$repo" >/dev/null; run_doctor "."; popd >/dev/null
assert_not_contains "$OUT" "wl-spec-existing.md: source" "existing spec wikilink source not warned"
assert_not_contains "$OUT" "wl-plan-existing.md: source" "existing plan wikilink source not warned"
assert_not_contains "$OUT" "wl-fix-existing.md: source" "existing fix wikilink source not warned (fixes/ validated)"
assert_not_contains "$OUT" "wl-md-suffix.md: source" "trailing .md in wikilink source tolerated"
assert_not_contains "$OUT" "unresolved [[specs/existing]]" "spec wikilink source is not a false unresolved-link"
assert_not_contains "$OUT" "unresolved [[plans/existing]]" "plan wikilink source is not a false unresolved-link"
assert_not_contains "$OUT" "unresolved [[fixes/existing]]" "fix wikilink source is not a false unresolved-link"
assert_not_contains "$OUT" "unresolved [[plans/existing.md]]" "trailing-.md wikilink is not a false unresolved-link"

# missing-target wikilink source → provenance warning on the resolved .woostack path.
# Distinct basenames (wl-missing*) so the assertion isolates the wikilink path and is not
# satisfied by the earlier path-form stale-source notes.
mk_note "$md" wl-spec-missing.md $'name: wl-spec-missing\ntype: pattern\nscope: packages/api/**\nsource: [[specs/wl-missing]]\nupdated: 2026-06-02' 'body'
mk_note "$md" wl-fix-missing.md $'name: wl-fix-missing\ntype: pattern\nscope: packages/api/**\nsource: [[fixes/wl-missing]]\nupdated: 2026-06-02' 'body'
pushd "$repo" >/dev/null; run_doctor "."; popd >/dev/null
assert_contains "$OUT" "source '.woostack/specs/wl-missing.md' is missing" "missing spec wikilink source warned"
assert_contains "$OUT" "source '.woostack/fixes/wl-missing.md' is missing" "missing fix wikilink source warned (fixes/ now validated)"
assert_exit 0 "$CODE" "wikilink provenance warnings still exit 0"

# --- distillation-gate backstop warnings ---
# missing source: → warn, exit 0
mk_note "$md" no-source.md $'name: no-source\ntype: pattern\nscope: packages/api/**\nupdated: 2026-06-02' 'body'
pushd "$repo" >/dev/null; run_doctor "."; popd >/dev/null
assert_contains "$OUT" "no-source.md: missing source:" "note without source: is warned"
assert_exit 0 "$CODE" "missing source: is a warning"

# non-glob scope (single literal path), distill-origin → warn
mk_note "$md" nonglob.md $'name: nonglob\ntype: pattern\nscope: packages/api/handler.ts\nupdated: 2026-06-02\nsource: .woostack/specs/existing.md' 'body'
pushd "$repo" >/dev/null; run_doctor "."; popd >/dev/null
assert_contains "$OUT" "nonglob.md: non-glob scope" "single literal scope warned as possible trivia"
assert_exit 0 "$CODE" "non-glob scope is a warning"

# all-literal multi-scope (no * anywhere) → warn
mk_note "$md" multilit.md $'name: multilit\ntype: pattern\nscope: a/b.ts, c/d.ts\nupdated: 2026-06-02\nsource: .woostack/specs/existing.md' 'body'
pushd "$repo" >/dev/null; run_doctor "."; popd >/dev/null
assert_contains "$OUT" "multilit.md: non-glob scope" "all-literal multi-scope warned"

# globbed scope → no warning
mk_note "$md" globbed.md $'name: globbed\ntype: pattern\nscope: packages/api/**\nupdated: 2026-06-02\nsource: .woostack/specs/existing.md' 'body'
pushd "$repo" >/dev/null; run_doctor "."; popd >/dev/null
assert_not_contains "$OUT" "globbed.md: non-glob scope" "a globbed scope is not flagged"

# global scope (*) → no warning
mk_note "$md" globalscope.md $'name: globalscope\ntype: pattern\nscope: *\nupdated: 2026-06-02\nsource: .woostack/specs/existing.md' 'body'
pushd "$repo" >/dev/null; run_doctor "."; popd >/dev/null
assert_not_contains "$OUT" "globalscope.md: non-glob scope" "global scope is exempt"

# multi-glob scope (contains *) → no warning
mk_note "$md" multiglob.md $'name: multiglob\ntype: pattern\nscope: packages/api/**, apps/*/x.ts\nupdated: 2026-06-02\nsource: .woostack/specs/existing.md' 'body'
pushd "$repo" >/dev/null; run_doctor "."; popd >/dev/null
assert_not_contains "$OUT" "multiglob.md: non-glob scope" "a multi-glob scope (contains *) is not flagged"

# absent scope field → exempt (global)
mk_note "$md" noscope.md $'name: noscope\ntype: pattern\nupdated: 2026-06-02\nsource: .woostack/specs/existing.md' 'body'
pushd "$repo" >/dev/null; run_doctor "."; popd >/dev/null
assert_not_contains "$OUT" "noscope.md: non-glob scope" "absent scope is exempt from non-glob warning"

# review-provenance (pr-*) with literal scope → exempt
mk_note "$md" review-pr.md $'name: review-pr\ntype: convention\nscope: packages/api/handler.ts\nupdated: 2026-06-02\nsource: pr-42' 'body'
pushd "$repo" >/dev/null; run_doctor "."; popd >/dev/null
assert_not_contains "$OUT" "review-pr.md: non-glob scope" "review-provenance note is exempt from non-glob warning"

# review-provenance (address-comments) with literal scope → exempt
mk_note "$md" review-ac.md $'name: review-ac\ntype: convention\nscope: packages/api/handler.ts\nupdated: 2026-06-02\nsource: address-comments' 'body'
pushd "$repo" >/dev/null; run_doctor "."; popd >/dev/null
assert_not_contains "$OUT" "review-ac.md: non-glob scope" "address-comments note is exempt"

# missing updated: → warn (cannot be aged), exit 0
muR="$(mkws)"; mu="$muR/.woostack/memory"
mk_note "$mu" noupd2.md $'name: noupd2\ntype: pattern\nscope: *\nsource: pr-1' 'body'
run_doctor "$muR"
assert_contains "$OUT" "noupd2.md: missing updated:" "note without updated: is warned"
assert_exit 0 "$CODE" "missing updated: is a warning"
assert_not_contains "$OUT" "dead note" "missing updated: does not also emit a dead-note signal"
rm -rf "$muR"

# unresolved wikilink → warn
mk_note "$md" link.md $'name: link\ntype: pattern\nscope: packages/api/**' 'see [[ghost]] note'
pushd "$repo" >/dev/null; run_doctor "."; popd >/dev/null
assert_contains "$OUT" "ghost" "unresolved wikilink warned"

# errors: dup name, bad type, missing field, malformed
errR="$(mkws)"; err="$errR/.woostack/memory"
mk_note "$err" d1.md $'name: dup\ntype: pattern' 'b'
mk_note "$err" d2.md $'name: dup\ntype: pattern' 'b'
run_doctor "$errR"; assert_exit 1 "$CODE" "duplicate name errors"; assert_contains "$OUT" "duplicate" "dup msg"

err2R="$(mkws)"; err2="$err2R/.woostack/memory"
mk_note "$err2" bad.md $'name: x\ntype: bogus' 'b'
run_doctor "$err2R"; assert_exit 1 "$CODE" "bad type errors"

err3R="$(mkws)"; err3="$err3R/.woostack/memory"
mk_note "$err3" nofield.md $'type: pattern' 'b'
run_doctor "$err3R"; assert_exit 1 "$CODE" "missing name errors"

err4R="$(mkws)"; err4="$err4R/.woostack/memory"
printf 'no frontmatter here\n' > "$err4/malformed.md"
run_doctor "$err4R"; assert_exit 1 "$CODE" "malformed frontmatter errors"

err5R="$(mkws)"; err5="$err5R/.woostack/memory"
mk_note "$err5" notype.md $'name: x' 'b'
run_doctor "$err5R"; assert_exit 1 "$CODE" "missing type errors"

err6R="$(mkws)"; err6="$err6R/.woostack/memory"
mk_note "$err6" nobody.md $'name: x\ntype: pattern' ''
run_doctor "$err6R"; assert_exit 1 "$CODE" "empty body errors"

# --- dead-note check ---
# old + never recalled → dead warning, exit 0
dd1R="$(mkws)"; dd1="$dd1R/.woostack/memory"
mk_note "$dd1" old.md $'name: old\ntype: pattern\nscope: *\nupdated: 2026-01-01' 'stale body'
OUT="$(WOOSTACK_NOW=2026-06-02 bash "$DOC" "$dd1R" 2>&1)"; CODE=$?
assert_contains "$OUT" "dead note" "old + zero recalls flagged as dead"
assert_exit 0 "$CODE" "dead note is a warning (exit 0)"

# old but recalled → not flagged
dd2R="$(mkws)"; dd2="$dd2R/.woostack/memory"
mk_note "$dd2" old.md $'name: old\ntype: pattern\nscope: *\nupdated: 2026-01-01' 'body'
printf 'old\t3\t2026-05-01\n' > "$dd2/.telemetry.tsv"
OUT="$(WOOSTACK_NOW=2026-06-02 bash "$DOC" "$dd2R" 2>&1)"
assert_not_contains "$OUT" "dead note" "a note recalled per the sidecar is never flagged dead"

# fresh updated → not flagged
dd3R="$(mkws)"; dd3="$dd3R/.woostack/memory"
mk_note "$dd3" fresh.md $'name: fresh\ntype: pattern\nscope: *\nupdated: 2026-05-30' 'body'
OUT="$(WOOSTACK_NOW=2026-06-02 bash "$DOC" "$dd3R" 2>&1)"
assert_not_contains "$OUT" "dead note" "a fresh note is not flagged"

# no updated: → not aged by the dead-note check, but does warn "missing updated:"
dd4R="$(mkws)"; dd4="$dd4R/.woostack/memory"
mk_note "$dd4" noupd.md $'name: noupd\ntype: pattern\nscope: *' 'body'
OUT="$(WOOSTACK_NOW=2026-06-02 bash "$DOC" "$dd4R" 2>&1)"
assert_not_contains "$OUT" "dead note" "a note without updated: gets no dead-note signal"
assert_contains "$OUT" "noupd.md: missing updated:" "a note without updated: is warned (cannot be aged)"

# WOOSTACK_DEAD_DAYS tightens the window
dd5R="$(mkws)"; dd5="$dd5R/.woostack/memory"
mk_note "$dd5" recent.md $'name: recent\ntype: pattern\nscope: *\nupdated: 2026-05-30' 'body'
OUT="$(WOOSTACK_NOW=2026-06-02 WOOSTACK_DEAD_DAYS=1 bash "$DOC" "$dd5R" 2>&1)"
assert_contains "$OUT" "dead note" "DEAD_DAYS=1 flags a 3-day-old never-recalled note"
rm -rf "$dd1R" "$dd2R" "$dd3R" "$dd4R" "$dd5R"

# --- overlap clusters (own git repo: needs tracked files) ---
orepo="$(mktemp -d)"
( cd "$orepo" && git -c user.email=t@t -c user.name=t init -q \
    && mkdir -p packages/api apps/web && touch packages/api/x.ts apps/web/y.tsx \
    && git add -A && git -c user.email=t@t -c user.name=t commit -qm init )
omd="$orepo/.woostack/memory"; mkdir -p "$omd"

# two notes matching the same tracked file → one cluster naming both (min-name order)
mk_note "$omd" c1.md $'name: c1\ntype: pattern\nscope: packages/api/**\nupdated: 2026-06-02\nsource: pr-1' 'b'
mk_note "$omd" c2.md $'name: c2\ntype: gotcha\nscope: packages/api/orpc/**, packages/api/x.ts\nupdated: 2026-06-02\nsource: pr-2' 'b'
pushd "$orepo" >/dev/null; run_doctor "."; popd >/dev/null
assert_contains "$OUT" "overlap cluster: c1.md, c2.md" "two notes on a shared file form one cluster"
assert_exit 0 "$CODE" "overlap cluster is a warning (exit 0)"

# add a disjoint note (apps/web only) → not in the api cluster
mk_note "$omd" web.md $'name: web\ntype: pattern\nscope: apps/web/**\nupdated: 2026-06-02\nsource: pr-3' 'b'
pushd "$orepo" >/dev/null; run_doctor "."; popd >/dev/null
assert_not_contains "$OUT" "web.md" "a disjoint-scope note is not clustered"
assert_contains "$OUT" "overlap cluster: c1.md, c2.md" "disjoint note does not disturb the api cluster"

# add a global note → never clustered
mk_note "$omd" g.md $'name: g\ntype: convention\nscope: *\nupdated: 2026-06-02\nsource: pr-4' 'b'
pushd "$orepo" >/dev/null; run_doctor "."; popd >/dev/null
assert_not_contains "$OUT" "overlap cluster: c1.md, c2.md, g.md" "global note is exempt from clustering"

# add a third api note → single cluster of three, sorted
mk_note "$omd" c3.md $'name: c3\ntype: pattern\nscope: packages/api/**\nupdated: 2026-06-02\nsource: pr-5' 'b'
pushd "$orepo" >/dev/null; run_doctor "."; popd >/dev/null
assert_contains "$OUT" "overlap cluster: c1.md, c2.md, c3.md" "three notes on a shared file form one sorted cluster"

# a stale note (matches no tracked file) is never clustered, only stale-warned
ostale="$(mktemp -d)"
( cd "$ostale" && git -c user.email=t@t -c user.name=t init -q \
    && mkdir -p packages/api && touch packages/api/x.ts \
    && git add -A && git -c user.email=t@t -c user.name=t commit -qm init )
osmd="$ostale/.woostack/memory"; mkdir -p "$osmd"
mk_note "$osmd" real.md  $'name: real\ntype: pattern\nscope: packages/api/**\nupdated: 2026-06-02\nsource: pr-1' 'b'
mk_note "$osmd" ghost.md $'name: ghost\ntype: pattern\nscope: zzz/**\nupdated: 2026-06-02\nsource: pr-2' 'b'
pushd "$ostale" >/dev/null; run_doctor "."; popd >/dev/null
assert_not_contains "$OUT" "overlap cluster" "a lone real note + a stale note form no cluster"
assert_contains "$OUT" "ghost.md: scope 'zzz/**' matches no tracked files (stale)" "stale note still stale-warned"

rm -rf "$orepo" "$ostale"

rm -rf "$repo"
finish
