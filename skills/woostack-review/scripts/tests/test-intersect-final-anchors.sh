#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/intersect-findings.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
export OUTDIR="$work"

cat > "$work/config.json" <<'JSON'
{"disable_adversarial": true}
JSON

cat > "$work/meta.json" <<'JSON'
{
  "files": [
    {"path": "src/app.ts"}
  ]
}
JSON

cat > "$work/diff.txt" <<'DIFF'
diff --git a/src/app.ts b/src/app.ts
index 1111111..2222222 100644
--- a/src/app.ts
+++ b/src/app.ts
@@ -1,2 +1,2 @@
 const keep = true;
+const changed = true;
@@ -30,1 +30,1 @@
 const later = true;
DIFF

cat > "$work/findings.defender.json" <<'JSON'
[
  {"angle":"bugs","file":"src/app.ts","line":99,"title":"Drop stale line","description":"d","fix":"f","severity":"HIGH","blocking":true,"fix_type":"prose","suggestion":null},
  {"angle":"bugs","file":"other.ts","line":1,"title":"Drop stale file","description":"d","fix":"f","severity":"HIGH","blocking":true,"fix_type":"prose","suggestion":null},
  {"angle":"bugs","file":"src/app.ts","line":"2","title":"Keep valid line","description":"d","fix":"f","severity":"HIGH","blocking":true,"fix_type":"prose","suggestion":null},
  {"angle":"bugs","file":"src/app.ts","line":"1","end_line":"2","title":"Keep valid range","description":"d","fix":"f","severity":"HIGH","blocking":true,"fix_type":"prose","suggestion":null},
  {"angle":"bugs","file":"src/app.ts","line":1,"end_line":30,"title":"Degrade cross-hunk range","description":"d","fix":"f","severity":"HIGH","blocking":true,"fix_type":"prose","suggestion":null},
  {"angle":"bugs","file":"src/app.ts","line":30,"title":"Keep range-free finding","description":"d","fix":"f","severity":"HIGH","blocking":true,"fix_type":"prose","suggestion":null}
]
JSON
cp "$work/findings.defender.json" "$work/raw_findings.json"

bash "$SCRIPT" >"$work/output.txt" 2>&1
assert_contains "$(cat "$work/output.txt")" "degraded 1 invalid range(s)" "defender-only filter reports one degraded invalid range"

assert_eq "$(jq 'length' "$work/findings.json")" "4" "final anchor filter keeps only postable findings"
assert_eq "$(jq -r '[.[].title] | index("Drop stale line")' "$work/findings.json")" "null" "final anchor filter drops a stale line"
assert_eq "$(jq -r '.[] | select(.title == "Keep valid line") | .line' "$work/findings.json")" "2" "final anchor filter writes canonical numeric line"
assert_eq "$(jq -r '.[] | select(.title == "Keep valid line") | .line | type' "$work/findings.json")" "number" "final anchor filter stores canonical line as a number"
assert_eq "$(jq -r '.[] | select(.title == "Keep valid range") | [.line, .end_line] | @csv' "$work/findings.json")" '1,2' "defender-only filter canonicalizes a same-hunk range"
assert_eq "$(jq -r '.[] | select(.title == "Keep valid range") | .end_line | type' "$work/findings.json")" "number" "defender-only filter stores canonical endpoint as a number"
assert_eq "$(jq -r '.[] | select(.title == "Degrade cross-hunk range") | has("end_line")' "$work/findings.json")" "false" "defender-only filter strips a cross-hunk endpoint"
assert_eq "$(jq -r '.[] | select(.title == "Degrade cross-hunk range") | .line' "$work/findings.json")" "1" "defender-only filter keeps a valid start when range degrades"
assert_eq "$(jq -r '.[] | select(.title == "Keep range-free finding") | has("end_line")' "$work/findings.json")" "false" "defender-only filter leaves range-free findings unchanged"

finish
