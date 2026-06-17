#!/usr/bin/env bash
set -euo pipefail

# Regression for the ADVERSARIAL path of the issue-#375 final-anchor guard.
# test-intersect-final-anchors.sh covers defender-only mode (disable_adversarial:
# true), but the fix notes (.woostack/fixes/2026-06-17-final-finding-anchors.md
# §1) identify the merged defender/prosecutor path as the primary leak: the merge
# keeps the DEFENDER object for a matched finding and only folds severity/blocking
# from the prosecutor, so a fuzzy or title-only match can prove validator
# agreement while the final object still carries the defender's stale file/line.
# intersect-findings.sh wires filter_final_anchors into both paths (line ~491
# defender-only, line ~748 adversarial); without an adversarial fixture, deleting
# the adversarial call would pass every test. This pins it.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/intersect-findings.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
export OUTDIR="$work"

# Adversarial ON (both validator passes present), metrics off.
cat > "$work/config.json" <<'JSON'
{}
JSON

# PR file set is src/app.ts only; other.ts is outside it.
cat > "$work/meta.json" <<'JSON'
{
  "files": [
    {"path": "src/app.ts"}
  ]
}
JSON

# Right-side lines 1-2 exist for src/app.ts; line 99 cannot anchor.
cat > "$work/diff.txt" <<'DIFF'
diff --git a/src/app.ts b/src/app.ts
index 1111111..2222222 100644
--- a/src/app.ts
+++ b/src/app.ts
@@ -1,2 +1,2 @@
 const keep = true;
+const changed = true;
DIFF

# Defender objects win text fields (file/line) through the merge:
#  - Stale line:  src/app.ts:99 — validators agree via pass-4 title match (the
#    prosecutor anchored the same issue at the postable line 2), but the merged
#    object keeps the defender's stale line 99. Must be dropped by the final guard.
#  - Stale file:  other.ts — exact-matched by the prosecutor, so it survives the
#    intersection; not in the PR file set, so the final guard must drop it.
#  - Valid:       src/app.ts:"2" — exact-matched, kept, and its string line is
#    rewritten to the canonical numeric anchor.
cat > "$work/findings.defender.json" <<'JSON'
[
  {"angle":"bugs","file":"src/app.ts","line":99,"title":"Stale defender anchor survives validators","description":"d","fix":"f","severity":"HIGH","blocking":true,"fix_type":"prose","suggestion":null},
  {"angle":"bugs","file":"other.ts","line":1,"title":"Drop stale file adversarial","description":"d","fix":"f","severity":"HIGH","blocking":true,"fix_type":"prose","suggestion":null},
  {"angle":"bugs","file":"src/app.ts","line":"2","title":"Keep valid adversarial finding","description":"d","fix":"f","severity":"HIGH","blocking":true,"fix_type":"prose","suggestion":null}
]
JSON
cat > "$work/findings.prosecutor.json" <<'JSON'
[
  {"angle":"bugs","file":"src/app.ts","line":2,"title":"Stale defender anchor survives validators","description":"d","fix":"f","severity":"HIGH","blocking":true,"fix_type":"prose","suggestion":null},
  {"angle":"bugs","file":"other.ts","line":1,"title":"Drop stale file adversarial","description":"d","fix":"f","severity":"HIGH","blocking":true,"fix_type":"prose","suggestion":null},
  {"angle":"bugs","file":"src/app.ts","line":2,"title":"Keep valid adversarial finding","description":"d","fix":"f","severity":"HIGH","blocking":true,"fix_type":"prose","suggestion":null}
]
JSON
cp "$work/findings.defender.json" "$work/raw_findings.json"

bash "$SCRIPT" >/tmp/intersect-final-anchors-adversarial.out 2>&1 \
  || { cat /tmp/intersect-final-anchors-adversarial.out; exit 1; }

# Guard the path was actually adversarial, not a silent defender-only fallback.
assert_eq "$(jq -r '.mode' "$work/validator-metrics.json")" "adversarial" "ran the adversarial merge path"

assert_eq "$(jq 'length' "$work/findings.json")" "1" "adversarial final anchor filter keeps only postable findings"
assert_eq "$(jq -r '.[0].title' "$work/findings.json")" "Keep valid adversarial finding" "adversarial filter drops merged stale file and stale line"
assert_eq "$(jq -r '.[0].line' "$work/findings.json")" "2" "adversarial filter writes canonical numeric line"
assert_eq "$(jq -r '.[0].line | type' "$work/findings.json")" "number" "adversarial filter stores canonical line as a number"

finish
