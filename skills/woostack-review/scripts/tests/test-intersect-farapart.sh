#!/usr/bin/env bash
set -euo pipefail

# Regression: a finding BOTH validators keep but anchor far apart (and reword
# past the prefix-20 cutoff) was dropped by intersect — all three prior passes
# gate on |line delta| <= 10. Pass 4 (same-file, strong title-token overlap, no
# line window) recovers it. See intersect-findings.sh header.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/intersect-findings.sh"

work="$(mktemp -d)"
export OUTDIR="$work"

# Adversarial ON (both passes present), metrics off.
printf '%s\n' '{}' > "$work/config.json"

# --- Case 1: same real bug, anchored 83 lines apart, reworded title. ---
# This is the live action.yml Anthropic-runner finding from PR #185 dogfood:
# prosecutor anchored the OpenAI contrast line (314), defender the Anthropic
# block (231). Passes 1-3 all miss (delta 83 > 10, prefix-20 differs). Pass 4
# must pair them on the shared title tokens {anthropic, runner, force, tier}.
cat > "$work/findings.prosecutor.json" <<'JSON'
[
  {"angle":"bugs","file":"action.yml","line":314,"title":"Anthropic runner ignores force_tier; always uses Sonnet","description":"d","fix":"f","severity":"HIGH","blocking":true,"fix_type":"prose","suggestion":null}
]
JSON
cat > "$work/findings.defender.json" <<'JSON'
[
  {"angle":"infra","file":"action.yml","line":231,"title":"Anthropic runner bypasses run_model; force_tier ignored","description":"d","fix":"f","severity":"HIGH","blocking":true,"fix_type":"prose","suggestion":null}
]
JSON
cp "$work/findings.prosecutor.json" "$work/raw_findings.json"

bash "$SCRIPT" >/tmp/intersect-farapart.out 2>&1 || { cat /tmp/intersect-farapart.out; exit 1; }

F="$work/findings.json"
assert_eq "$(jq 'length' "$F")" "1" "far-apart agreed finding is kept (was dropped)"
assert_eq "$(jq -r '.[0].file' "$F")" "action.yml" "kept finding is the action.yml one"
assert_eq "$(jq -r '.[0].blocking' "$F")" "true" "blocking preserved (AND of both true)"
assert_eq "$(jq -r '.[0].severity' "$F")" "HIGH" "severity preserved (min of both HIGH)"
# Defender copy wins on text fields.
assert_eq "$(jq -r '.[0].title' "$F")" "Anthropic runner bypasses run_model; force_tier ignored" "defender title wins"

# --- Case 2 (negative): two UNRELATED findings in one file, far apart, no
# shared distinctive tokens — pass 4 must NOT merge them. ---
cat > "$work/findings.prosecutor.json" <<'JSON'
[
  {"angle":"bugs","file":"app.ts","line":10,"title":"Hardcoded request timeout constant","description":"d","fix":"f","severity":"MEDIUM","blocking":false,"fix_type":"prose","suggestion":null}
]
JSON
cat > "$work/findings.defender.json" <<'JSON'
[
  {"angle":"bugs","file":"app.ts","line":200,"title":"Unhandled promise rejection in loader","description":"d","fix":"f","severity":"HIGH","blocking":true,"fix_type":"prose","suggestion":null}
]
JSON
cp "$work/findings.prosecutor.json" "$work/raw_findings.json"

bash "$SCRIPT" >/tmp/intersect-farapart2.out 2>&1 || { cat /tmp/intersect-farapart2.out; exit 1; }
assert_eq "$(jq 'length' "$work/findings.json")" "0" "unrelated same-file findings are NOT over-merged"

rm -rf "$work"
finish
