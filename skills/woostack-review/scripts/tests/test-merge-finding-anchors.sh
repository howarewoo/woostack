#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/merge-findings.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
export OUTDIR="$work"

cat > "$work/diff.txt" <<'DIFF'
diff --git a/src/app.ts b/src/app.ts
index 1111111..2222222 100644
--- a/src/app.ts
+++ b/src/app.ts
@@ -10,3 +10,3 @@
 const ten = true;
-old eleven
+const eleven = true;
 const twelve = true;
@@ -30,2 +30,2 @@
 const thirty = true;
+const thirtyOne = true;
DIFF

cat > "$work/findings.bugs.json" <<'JSON'
[
  {"angle":"bugs","file":"src/app.ts","line":"10","end_line":"12","title":"Keep valid range","description":"d","fix":"f"},
  {"angle":"bugs","file":"src/app.ts","line":10,"end_line":30,"title":"Degrade invalid range","description":"d","fix":"f"},
  {"angle":"bugs","file":"src/app.ts","line":"31","title":"Keep single anchor","description":"d","fix":"f"}
]
JSON

bash "$SCRIPT" >"$work/output.txt" 2>&1
assert_contains "$(cat "$work/output.txt")" "degraded 1 invalid range(s)" "merge reports one degraded invalid range"

assert_eq "$(jq 'length' "$work/raw_findings.json")" "3" "merge keeps every valid-start finding"
assert_eq "$(jq -r '.[] | select(.title == "Keep valid range") | [.line, .end_line] | @csv' "$work/raw_findings.json")" '10,12' "merge canonicalizes a valid range"
assert_eq "$(jq -r '.[] | select(.title == "Degrade invalid range") | has("end_line")' "$work/raw_findings.json")" "false" "merge strips a cross-hunk endpoint"
assert_eq "$(jq -r '.[] | select(.title == "Degrade invalid range") | .line' "$work/raw_findings.json")" "10" "merge retains the valid start when range degrades"
assert_eq "$(jq -r '.[] | select(.title == "Keep single anchor") | has("end_line")' "$work/raw_findings.json")" "false" "merge leaves a single anchor unchanged"
assert_eq "$(jq -r '.[] | select(.title == "Keep single anchor") | .line | type' "$work/raw_findings.json")" "string" "merge preserves range-free finding representation"

finish
