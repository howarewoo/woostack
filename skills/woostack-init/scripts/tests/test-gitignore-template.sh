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
assert_not_contains "$(cat "$DIR/../../../.woostack/.obsidian/app.json")" "overnight/" "workspace navigation does not preserve the retired report corpus"
assert_contains "$body" "respond/evidence/" "gitignore template ignores response evidence"
assert_exit 1 "$(grep -qx 'respond/' "$template"; echo $?)" "template keeps response reports tracked"
assert_not_contains "$body" "$(printf 'memory.md')" "gitignore template no longer ignores a flat shard"
assert_exit 1 "$(grep -qxF 'memory.md' "$template"; echo $?)" "no bare 'memory.md' line in gitignore template"
assert_exit 1 "$(grep -qx 'memory/' "$template"; echo $?)" "template no longer ignores the whole scoped store"
assert_contains "$body" "memory/.telemetry.tsv"  "template ignores the telemetry sidecar"
assert_contains "$body" "memory/.dream-watermark" "template ignores the dream watermark"
assert_contains "$body" "worktrees/" "gitignore template ignores per-PR worktrees"

# Wisdom is a TRACKED store — the template must NOT ignore it.
assert_exit 1 "$(grep -qx 'wisdom/' "$template"; echo $?)" "template does not ignore the wisdom store"
assert_not_contains "$body" "$(printf 'wisdom/')" "gitignore template keeps wisdom/ tracked"

finish
