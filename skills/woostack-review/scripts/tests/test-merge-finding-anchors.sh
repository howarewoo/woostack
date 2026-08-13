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
@@ -10,3 +10,4 @@
 const ten = true;
-old eleven
+const eleven = true;
+const elevenB = true;
 const twelve = true;
@@ -30,2 +30,2 @@
 const thirty = true;
+const thirtyOne = true;
DIFF

cat > "$work/findings.bugs.json" <<'JSON'
[
  {"angle":"bugs","file":"src/app.ts","line":"11","end_line":"12","title":"Keep valid range","failure_mode":"The changed branch skips validation","evidence":{"basis":"diff","detail":"The added branch returns before validation","related_files":[]},"confidence":0.95,"description":"The added branch returns before validation and accepts the record.","fix":"Run validation before returning the record.","severity":"HIGH","blocking":true,"fix_type":"prose","suggestion":null},
  {"angle":"bugs","file":"src/app.ts","line":12,"end_line":30,"title":"Degrade invalid range","failure_mode":"The changed branch bypasses authorization","evidence":{"basis":"diff","detail":"The added branch bypasses authorization","related_files":[]},"confidence":0.95,"description":"The added branch bypasses authorization and exposes the record.","fix":"Check authorization before returning the record.","severity":"HIGH","blocking":true,"fix_type":"prose","suggestion":null},
  {"angle":"bugs","file":"src/app.ts","line":"31","title":"Keep single anchor","failure_mode":"The changed branch writes stale state","evidence":{"basis":"diff","detail":"The added write uses stale state","related_files":[]},"confidence":0.9,"description":"The added write uses stale state and overwrites the current value.","fix":"Write the current state value.","severity":"HIGH","blocking":true,"fix_type":"prose","suggestion":null}
]
JSON

bash "$SCRIPT" >"$work/output.txt" 2>&1
assert_contains "$(cat "$work/output.txt")" "degraded 1 invalid range(s)" "merge reports one degraded invalid range"

assert_eq "$(jq 'length' "$work/raw_findings.json")" "3" "merge keeps every valid-start finding"
assert_eq "$(jq -r '.[] | select(.title == "Keep valid range") | [.line, .end_line] | @csv' "$work/raw_findings.json")" '11,12' "merge canonicalizes a valid range starting on an added line"
assert_eq "$(jq -r '.[] | select(.title == "Degrade invalid range") | has("end_line")' "$work/raw_findings.json")" "false" "merge strips a cross-hunk endpoint"
assert_eq "$(jq -r '.[] | select(.title == "Degrade invalid range") | .line' "$work/raw_findings.json")" "12" "merge retains the valid added start when range degrades"
assert_eq "$(jq -r '.[] | select(.title == "Keep single anchor") | has("end_line")' "$work/raw_findings.json")" "false" "merge leaves a single anchor unchanged"
assert_eq "$(jq -r '.[] | select(.title == "Keep single anchor") | .line | type' "$work/raw_findings.json")" "string" "merge preserves range-free finding representation"

finish
