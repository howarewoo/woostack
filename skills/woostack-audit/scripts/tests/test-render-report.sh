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
finish
