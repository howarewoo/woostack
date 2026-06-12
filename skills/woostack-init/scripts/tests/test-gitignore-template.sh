#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DIR/tests/assert.sh"

template="$DIR/../templates/gitignore"
body="$(cat "$template")"

assert_contains "$body" "metrics.json" "gitignore template ignores metrics"
assert_contains "$body" "*.local.*" "gitignore template ignores local scratch files"
assert_contains "$body" "visuals/" "gitignore template ignores rendered visuals"
assert_contains "$body" "overnight/" "gitignore template ignores overnight reports"
assert_not_contains "$body" "$(printf 'memory.md')" "gitignore template no longer ignores a flat shard"
assert_exit 1 "$(grep -qxF 'memory.md' "$template"; echo $?)" "no bare 'memory.md' line in gitignore template"
assert_contains "$body" "memory/" "gitignore template ignores scoped local memory"
assert_contains "$body" "worktrees/" "gitignore template ignores per-PR worktrees"

finish
