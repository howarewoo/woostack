#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/merge-findings.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/out"

cat > "$work/out/findings.skills.json" <<'JSON'
{
  "angle": "skills",
  "file": "skills/example/SKILL.md",
  "line": 1,
  "title": "Split large skill",
  "description": "d",
  "fix": "f",
  "severity": "MEDIUM",
  "blocking": false,
  "fix_type": "prose",
  "suggestion": null
}
JSON

cat > "$work/out/findings.docs.json" <<'JSON'
{"not":"a finding"}
JSON

log="$work/merge-findings.log"
OUTDIR="$work/out" bash "$SCRIPT" > "$log"

assert_eq "$(jq -r 'length' "$work/out/raw_findings.json")" "1" "single finding object recovered"
assert_eq "$(jq -r '.[0].angle' "$work/out/raw_findings.json")" "skills" "recovered finding preserved"
assert_eq "$(grep -c 'Recovered single finding object as array' "$log")" "1" "recovery warning emitted"
assert_eq "$(grep -c 'Skipping malformed/non-array findings file' "$log")" "1" "non-finding object remains invalid"

finish
