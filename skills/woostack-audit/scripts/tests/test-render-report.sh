#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/render-report.sh"

export OUTDIR="$(mktemp -d)/out"; mkdir -p "$OUTDIR"
cat > "$OUTDIR/findings.json" <<'JSON'
[{"angle":"simplify","severity":"HIGH","file":"src/a.ts","line":1,"title":"Unused export `a`","description":"nothing references a","fix":"delete it"},
{"angle":"production-readiness","severity":"LOW","file":"src/b.py","line":2,"title":"No timeout on fetch","description":"call can hang","fix":"add a deadline"}]
JSON
out="$(mktemp -d)/report.md"
AUDIT_REPORT_PATH="$out" AUDIT_TARGET="src" bash "$SCRIPT" >/dev/null 2>&1 && ec=0 || ec=$?
assert_eq "$ec" "0" "renderer exits 0"
body="$(cat "$out")"
assert_contains "$body" "## HIGH" "groups by severity"
assert_contains "$body" "src/a.ts:1" "anchors finding"
assert_contains "$body" "/woostack-fix" "suggests a next step"
assert_not_contains "$body" "REQUEST_CHANGES" "no PR-event language (report-only)"

# Zero findings -> clean report, exit 0.
echo '[]' > "$OUTDIR/findings.json"
AUDIT_REPORT_PATH="$out" AUDIT_TARGET="src" bash "$SCRIPT" >/dev/null 2>&1 && ec=0 || ec=$?
assert_eq "$ec" "0" "clean exits 0"
assert_contains "$(cat "$out")" "clean" "clean report states clean"

# All three severities -> every section renders, in HIGH > MEDIUM > LOW order (input is shuffled).
cat > "$OUTDIR/findings.json" <<'JSON'
[{"angle":"bugs","severity":"LOW","file":"src/c.ts","line":3,"title":"Lo","description":"d","fix":"f"},
{"angle":"bugs","severity":"HIGH","file":"src/a.ts","line":1,"title":"Hi","description":"d","fix":"f"},
{"angle":"bugs","severity":"MEDIUM","file":"src/b.ts","line":2,"title":"Mid","description":"d","fix":"f"}]
JSON
AUDIT_REPORT_PATH="$out" AUDIT_TARGET="src" bash "$SCRIPT" >/dev/null 2>&1 && ec=0 || ec=$?
assert_eq "$ec" "0" "multi-severity exits 0"
body="$(cat "$out")"
assert_contains "$body" "## MEDIUM" "renders the MEDIUM section"
assert_contains "$body" "## LOW" "renders the LOW section"
hi="$(grep -n '^## HIGH' "$out" | head -1 | cut -d: -f1)"
md="$(grep -n '^## MEDIUM' "$out" | head -1 | cut -d: -f1)"
lo="$(grep -n '^## LOW' "$out" | head -1 | cut -d: -f1)"
assert_eq "$([ "$hi" -lt "$md" ] && [ "$md" -lt "$lo" ] && echo y || echo n)" "y" "sections sorted HIGH<MEDIUM<LOW"

# Explicit null optional fields are reachable (jq `has()` passes null through the merge schema
# gate). The renderer must not crash on the null `description` join and must not emit literal
# "None" for a null `fix`; a null `angle` falls back to "?".
cat > "$OUTDIR/findings.json" <<'JSON'
[{"angle":null,"severity":"MEDIUM","file":"src/x.ts","line":9,"title":"Null fields","description":null,"fix":null}]
JSON
AUDIT_REPORT_PATH="$out" AUDIT_TARGET="src" bash "$SCRIPT" >/dev/null 2>&1 && ec=0 || ec=$?
assert_eq "$ec" "0" "null optional fields do not crash the renderer"
body="$(cat "$out")"
assert_contains "$body" "Null fields" "renders the finding title with null fields"
assert_not_contains "$body" "**Fix:** None" "null fix is not rendered as the literal string None"
finish
