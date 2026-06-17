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
DIFF

cat > "$work/findings.defender.json" <<'JSON'
[
  {"angle":"bugs","file":"src/app.ts","line":99,"title":"Drop stale line","description":"d","fix":"f","severity":"HIGH","blocking":true,"fix_type":"prose","suggestion":null},
  {"angle":"bugs","file":"other.ts","line":1,"title":"Drop stale file","description":"d","fix":"f","severity":"HIGH","blocking":true,"fix_type":"prose","suggestion":null},
  {"angle":"bugs","file":"src/app.ts","line":"2","title":"Keep valid line","description":"d","fix":"f","severity":"HIGH","blocking":true,"fix_type":"prose","suggestion":null}
]
JSON
cp "$work/findings.defender.json" "$work/raw_findings.json"

bash "$SCRIPT"

assert_eq "$(jq 'length' "$work/findings.json")" "1" "final anchor filter keeps only postable findings"
assert_eq "$(jq -r '.[0].title' "$work/findings.json")" "Keep valid line" "final anchor filter drops stale file and line"
assert_eq "$(jq -r '.[0].line' "$work/findings.json")" "2" "final anchor filter writes canonical numeric line"
assert_eq "$(jq -r '.[0].line | type' "$work/findings.json")" "number" "final anchor filter stores canonical line as a number"

finish
