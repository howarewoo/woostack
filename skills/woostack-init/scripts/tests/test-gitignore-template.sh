#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DIR/tests/assert.sh"

template="$DIR/../templates/gitignore"
body="$(cat "$template")"

assert_contains "$body" "metrics.json" "gitignore template ignores metrics"
assert_contains "$body" "*.local.*" "gitignore template ignores local scratch files"
assert_contains "$body" "visuals/" "gitignore template ignores rendered visuals"
assert_not_contains "$body" "overnight/" "gitignore template does not preserve the retired local report corpus"
assert_not_contains "$(cat "$DIR/../../../.gitignore")" ".woostack/overnight/" "repository ignore rules do not preserve the retired report corpus"
assert_not_contains "$(cat "$DIR/../../../.woostack/.gitignore")" "overnight/" "workspace ignore rules do not preserve the retired report corpus"
assert_contains "$body" "respond/evidence/" "gitignore template ignores response evidence"
assert_exit 1 "$(grep -qx 'respond/' "$template"; echo $?)" "template keeps response reports tracked"
assert_contains "$body" "worktrees/" "gitignore template ignores per-PR worktrees"


finish
