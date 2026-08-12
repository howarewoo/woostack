#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/intersect-findings.sh"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
export OUTDIR="$work/out"; mkdir -p "$OUTDIR"
printf '{"severity_floor":"high","nits":true,"defer_markers":true}\n' > "$OUTDIR/config.json"
cat > "$OUTDIR/findings.adjudicator.json" <<'JSON'
[
 {"angle":"bugs","file":"a.ts","line":1,"title":"Concrete bug","description":"d","failure_mode":"f","evidence":{"basis":"diff","detail":"e"},"confidence":0.9,"severity":"HIGH","blocking":true,"fix_type":"prose","fix":"f"},
 {"angle":"bugs","file":"a.ts","line":2,"title":"Small concern","description":"d","failure_mode":"f","evidence":{"basis":"diff","detail":"e"},"confidence":0.8,"severity":"MEDIUM","blocking":false,"fix_type":"prose","fix":"f"},
 {"angle":"bugs","file":"a.ts","line":3,"title":"Deferred gap","description":"d","failure_mode":"f","evidence":{"basis":"contract","detail":"e"},"confidence":0.8,"severity":"HIGH","blocking":true,"deferred_to":"increment 2","fix_type":"prose","fix":"f"}
]
JSON
bash "$SCRIPT" >/dev/null
assert_eq "$(jq 'length' "$OUTDIR/findings.json")" "3" "one adjudicator output is sufficient"
assert_eq "$(jq -r '.[0].blocking' "$OUTDIR/findings.json")" "true" "concrete changed-line bug survives"
assert_eq "$(jq -r '.[1].nit' "$OUTDIR/findings.json")" "true" "below-floor candidate becomes nit"
assert_eq "$(jq -r '.[2].blocking' "$OUTDIR/findings.json")" "false" "deferred candidate is non-blocking"
printf '{"severity_floor":"high","nits":false,"defer_markers":false}\n' > "$OUTDIR/config.json"
cat > "$OUTDIR/findings.adjudicator.json" <<'JSON'
[
 {"angle":"bugs","file":"a.ts","line":1,"title":"Dropped concern","description":"d","failure_mode":"f","evidence":{"basis":"diff","detail":"e"},"confidence":0.8,"severity":"MEDIUM","blocking":false,"fix_type":"prose","fix":"f"},
 {"angle":"bugs","file":"a.ts","line":2,"title":"Explicit deferral disabled","description":"d","failure_mode":"f","evidence":{"basis":"contract","detail":"e"},"confidence":0.9,"severity":"HIGH","blocking":true,"deferred_to":"increment 2","fix_type":"prose","fix":"f"},
 {"angle":"security","file":"a.ts","line":3,"title":"Security cannot defer","description":"d","failure_mode":"f","evidence":{"basis":"diff","detail":"e"},"confidence":0.9,"severity":"HIGH","blocking":true,"deferred_to":"increment 2","fix_type":"prose","fix":"f"}
]
JSON
bash "$SCRIPT" >/dev/null
assert_eq "$(jq 'length' "$OUTDIR/findings.json")" "2" "disabled nits drop below-floor findings"
assert_eq "$(jq '[.[] | select(.blocking == true)] | length' "$OUTDIR/findings.json")" "2" "disabled and security deferrals remain blocking"

printf '{"severity_floor":"high","nits":true,"defer_markers":true}\n' > "$OUTDIR/config.json"
cat > "$OUTDIR/findings.adjudicator.json" <<'JSON'
[
 {"angle":"bugs","file":"","line":1,"title":"Missing path","description":"d","failure_mode":"f","evidence":{"basis":"diff","detail":"e"},"confidence":0.9,"severity":"HIGH","blocking":true,"fix_type":"prose","fix":"f"},
 {"angle":"bugs","file":"a.ts","line":2,"title":"Missing evidence","description":"d","failure_mode":"f","confidence":0.9,"severity":"HIGH","blocking":true,"fix_type":"prose","fix":"f"}
]
JSON
rc=0; bash "$SCRIPT" >/dev/null 2>&1 || rc=$?
assert_exit 1 "$rc" "malformed adjudicator findings block finalization"
cat > "$OUTDIR/meta.json" <<'JSON'
{"files":[{"path":"src/app.ts"}]}
JSON
cat > "$OUTDIR/diff.txt" <<'DIFF'
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
printf '{"severity_floor":"high","nits":true,"defer_markers":true,"metrics":true}\n' > "$OUTDIR/config.json"
cat > "$OUTDIR/findings.adjudicator.json" <<'JSON'
[
 {"angle":"bugs","file":"src/app.ts","line":2,"title":"Keep valid line","description":"d","failure_mode":"f","evidence":{"basis":"diff","detail":"e"},"confidence":0.9,"severity":"HIGH","blocking":true,"fix_type":"prose","fix":"f"},
 {"angle":"bugs","file":"src/app.ts","line":99,"title":"Drop stale line","description":"d","failure_mode":"f","evidence":{"basis":"diff","detail":"e"},"confidence":0.9,"severity":"HIGH","blocking":true,"fix_type":"prose","fix":"f"},
 {"angle":"bugs","file":"src/app.ts","line":1,"end_line":30,"title":"Degrade invalid range","description":"d","failure_mode":"f","evidence":{"basis":"diff","detail":"e"},"confidence":0.9,"severity":"HIGH","blocking":true,"fix_type":"prose","fix":"f"}
]
JSON
cp "$OUTDIR/findings.adjudicator.json" "$OUTDIR/raw_findings.json"
bash "$SCRIPT" >/dev/null
assert_eq "$(jq 'length' "$OUTDIR/findings.json")" "2" "finalizer drops unresolvable changed-line anchors"
assert_eq "$(jq -r '.[] | select(.title == "Degrade invalid range") | has("end_line")' "$OUTDIR/findings.json")" "false" "finalizer degrades an invalid range to its valid start"
assert_eq "$(jq -r '.schema_version' "$OUTDIR/findings.metrics.json")" "4" "finalizer emits schema-version-four metrics"
assert_eq "$(jq -r '.angles.bugs.raw_count' "$OUTDIR/findings.metrics.json")" "3" "metrics count raw adjudicator candidates"
assert_eq "$(jq -r '.angles.bugs.kept' "$OUTDIR/findings.metrics.json")" "2" "metrics count final kept findings"
assert_eq "$(jq -r '.angles.bugs.dropped_by_adjudicator' "$OUTDIR/findings.metrics.json")" "1" "metrics count rejected candidates"
assert_eq "$(jq -r '.angles.bugs.blocking_count' "$OUTDIR/findings.metrics.json")" "2" "metrics count blocking findings"
rm "$OUTDIR/findings.adjudicator.json"; rc=0; bash "$SCRIPT" >/dev/null 2>&1 || rc=$?
assert_exit 1 "$rc" "missing adjudicator output blocks"
finish
