#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/detect-angles.sh"

setup() {
  work="$(mktemp -d)"
  export OUTDIR="$work/out"
  mkdir -p "$OUTDIR"
  printf '%s\n' "$1" | jq -R . | jq -s '{files: [.[] | {path: .}]}' > "$OUTDIR/meta.json"
  printf '%s\n' "$2" > "$OUTDIR/diff.txt"
  printf '%s\n' '{"angles":{"force":[],"skip":[]}}' > "$OUTDIR/config.json"
}

# Ordinary code gets one general correctness worker, not overlapping quality
# workers or an always-on security worker.
setup "src/index.ts" '+const value = true'
bash "$SCRIPT" >/dev/null 2>&1
assert_eq "$(cat "$OUTDIR/angles.txt")" "bugs" "ordinary code dispatch is singular"
rm -rf "$work"

# Security matching is case-insensitive for common secret and auth spellings.
setup "src/loader.py" '+const API_KEY = payload.PASSWORD; authorization = header'
bash "$SCRIPT" >/dev/null 2>&1
assert_contains "$(cat "$OUTDIR/angles.txt")" "security" "uppercase secret token dispatches security"
rm -rf "$work"

# TSX and TypeScript syntax retain generic signals without specialized dispatch.
setup "src/component.tsx" '+type Props = { label: string }'
bash "$SCRIPT" >/dev/null 2>&1
assert_contains "$(cat "$OUTDIR/angles.txt")" "design" "TSX still dispatches generic design review"
assert_eq "$(grep -Ec '^(react|types)$' "$OUTDIR/angles.txt" || true)" "0" "TSX dispatches no removed specialist"
rm -rf "$work"

# Deterministic changed-line signal retains security even on an ordinary path.
setup "src/loader.ts" '+const token = response.access_token'
bash "$SCRIPT" >/dev/null 2>&1
assert_contains "$(cat "$OUTDIR/angles.txt")" "security" "secret token dispatches security"
rm -rf "$work"

# A generic source edit must not fan out into the removed broad angles.
setup "src/loader.ts" '+const value = response.value'
bash "$SCRIPT" >/dev/null 2>&1
assert_eq "$(grep -Ec '^(architecture|comments|simplify|production-readiness)$' "$OUTDIR/angles.txt" || true)" "0" "generic quality fanout stays disabled"
rm -rf "$work"

finish
