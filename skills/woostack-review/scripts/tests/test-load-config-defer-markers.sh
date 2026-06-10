#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/load-config.sh"

setup() { # $1 = config json body
  work="$(mktemp -d)"
  export OUTDIR="$work/out"
  export GITHUB_WORKSPACE="$work/repo"
  mkdir -p "$OUTDIR" "$GITHUB_WORKSPACE/.woostack"
  printf '%s\n' "$1" > "$GITHUB_WORKSPACE/.woostack/config.json"
}

# defer_markers:false accepted + emitted to canonical config.
setup '{"review":{"defer_markers":false}}'
bash "$SCRIPT" >/tmp/load-config-defer.out 2>&1
assert_eq "$(jq -r '.defer_markers' "$OUTDIR/config.json")" "false" "defer_markers:false emitted"
rm -rf "$work"

# defer_markers:true accepted + emitted.
setup '{"review":{"defer_markers":true}}'
bash "$SCRIPT" >/tmp/load-config-defer.out 2>&1
assert_eq "$(jq -r '.defer_markers' "$OUTDIR/config.json")" "true" "defer_markers:true emitted"
rm -rf "$work"

# Non-boolean defer_markers fails the loader loudly (non-zero exit).
setup '{"review":{"defer_markers":"yes"}}'
set +e
bash "$SCRIPT" >/tmp/load-config-defer.out 2>&1
rc=$?
set -e
assert_eq "$([ "$rc" -ne 0 ] && echo nonzero || echo zero)" "nonzero" "non-boolean defer_markers fails loader"
assert_contains "$(cat /tmp/load-config-defer.out)" "defer_markers" "error names the defer_markers key"
rm -rf "$work"

finish
