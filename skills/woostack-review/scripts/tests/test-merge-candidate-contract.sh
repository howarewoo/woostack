#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/merge-findings.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work"
export OUTDIR="$work"

cat > "$work/diff.txt" <<'DIFF'
diff --git a/src/api.ts b/src/api.ts
index 1111111..2222222 100644
--- a/src/api.ts
+++ b/src/api.ts
@@ -1,1 +1,3 @@
 const existing = true;
+return send(record);
+const changed = true;
diff --git a/src/store.ts b/src/store.ts
index 3333333..4444444 100644
--- a/src/store.ts
+++ b/src/store.ts
@@ -4,1 +4,2 @@
 const loaded = true;
+const ownership = false;
DIFF

cat > "$work/findings.security.json" <<'JSON'
[
  {
    "angle": "security",
    "file": "src/api.ts",
    "line": 2,
    "title": "Ownership check is bypassed",
    "failure_mode": "The endpoint returns a record without ownership enforcement",
    "evidence": {
      "basis": "diff",
      "detail": "The added return at src/api.ts:2 runs while src/store.ts adds an ownership=false path",
      "related_files": ["src/store.ts"]
    },
    "confidence": 0.96,
    "description": "The added return exposes a record before the ownership state is enforced.",
    "fix": "Enforce ownership before returning the record.",
    "severity": "HIGH",
    "blocking": true,
    "fix_type": "prose",
    "suggestion": null
  },
  {
    "angle": "bugs",
    "file": "src/api.ts",
    "line": 2,
    "title": "Different wording for same risk",
    "failure_mode": "The handler sends a record before checking ownership",
    "evidence": {
      "basis": "diff",
      "detail": "The added return at src/api.ts:2 runs while src/store.ts adds an ownership=false path",
      "related_files": ["src/store.ts"]
    },
    "confidence": 0.91,
    "description": "The added return exposes a record before the ownership state is enforced.",
    "fix": "Enforce ownership before returning the record.",
    "severity": "HIGH",
    "blocking": true,
    "fix_type": "prose",
    "suggestion": null
  },
  {
    "angle": "bugs",
    "file": "src/api.ts",
    "line": 3,
    "title": "Changed value is persisted incorrectly",
    "failure_mode": "The changed value overwrites the ownership state",
    "evidence": {
      "basis": "diff",
      "detail": "The added changed value is written at src/api.ts:3 after the ownership path",
      "related_files": ["src/store.ts"]
    },
    "confidence": 0.88,
    "description": "The added changed value overwrites the ownership state used by the endpoint.",
    "fix": "Preserve the ownership state when writing the changed value.",
    "severity": "HIGH",
    "blocking": true,
    "fix_type": "prose",
    "suggestion": null
  },
  {
    "angle": "bugs",
    "file": "src/api.ts",
    "line": 2,
    "title": "Missing evidence",
    "failure_mode": "The endpoint fails",
    "confidence": 0.8,
    "description": "The endpoint fails.",
    "fix": "Repair the endpoint.",
    "severity": "HIGH",
    "blocking": true,
    "fix_type": "prose",
    "suggestion": null
  },
  {
    "angle": "security",
    "file": "src/api.ts",
    "line": 2,
    "title": "Unbounded confidence",
    "failure_mode": "The endpoint leaks a secret",
    "evidence": {
      "basis": "diff",
      "detail": "The added return exposes a secret",
      "related_files": []
    },
    "confidence": 1.1,
    "description": "The endpoint leaks a secret.",
    "fix": "Remove the secret from the response.",
    "severity": "HIGH",
    "blocking": true,
    "fix_type": "prose",
    "suggestion": null
  },
  {
    "angle": "security",
    "file": "src/api.ts",
    "line": 1,
    "title": "Unchanged line",
    "failure_mode": "The endpoint leaks a token",
    "evidence": {
      "basis": "diff",
      "detail": "The unchanged line contains the token",
      "related_files": []
    },
    "confidence": 0.9,
    "description": "The endpoint leaks a token.",
    "fix": "Remove the token from the response.",
    "severity": "HIGH",
    "blocking": true,
    "fix_type": "prose",
    "suggestion": null
  },
  {
    "angle": "database",
    "file": "src/api.ts",
    "line": 2,
    "title": "Unsupported candidate",
    "failure_mode": "The candidate is unsupported",
    "evidence": {
      "basis": "diff",
      "detail": "The candidate is explicitly marked unsupported",
      "related_files": []
    },
    "confidence": 0.9,
    "description": "The candidate is explicitly unsupported.",
    "fix": "Discard the unsupported candidate.",
    "severity": "LOW",
    "blocking": false,
    "fix_type": "prose",
    "suggestion": null,
    "category": "unsupported"
  }
]
JSON

bash "$SCRIPT" >"$work/output.txt" 2>&1
assert_eq "$(jq 'length' "$work/raw_findings.json")" "2" "valid candidates survive while malformed candidates are rejected"
assert_eq "$(jq -r '.[0].failure_mode' "$work/raw_findings.json")" "The endpoint returns a record without ownership enforcement" "same-anchor paraphrases dedup by canonical anchor"
assert_eq "$(jq -r '[.[].line] | map(tostring) | join(",")' "$work/raw_findings.json")" "2,3" "different changed anchors survive dedup"
assert_eq "$(jq -r '.[0].evidence.related_files[0]' "$work/raw_findings.json")" "src/store.ts" "cross-file risk evidence survives"
assert_eq "$(jq '[.[] | select(.category == "unsupported")] | length' "$work/raw_findings.json")" "0" "unsupported candidate is rejected before raw findings"

finish
