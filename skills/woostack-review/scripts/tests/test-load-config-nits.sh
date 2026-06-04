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

# nits:false accepted + emitted to canonical config.
setup '{"review":{"nits":false}}'
bash "$SCRIPT" >/tmp/load-config-nits.out 2>&1
assert_eq "$(jq -r '.nits' "$OUTDIR/config.json")" "false" "nits:false emitted"
rm -rf "$work"

# nits:true accepted + emitted.
setup '{"review":{"nits":true}}'
bash "$SCRIPT" >/tmp/load-config-nits.out 2>&1
assert_eq "$(jq -r '.nits' "$OUTDIR/config.json")" "true" "nits:true emitted"
rm -rf "$work"

# Non-boolean nits fails the loader loudly (non-zero exit).
setup '{"review":{"nits":"yes"}}'
set +e
bash "$SCRIPT" >/tmp/load-config-nits.out 2>&1
rc=$?
set -e
assert_eq "$([ "$rc" -ne 0 ] && echo nonzero || echo zero)" "nonzero" "non-boolean nits fails loader"
assert_contains "$(cat /tmp/load-config-nits.out)" "nits" "error names the nits key"
rm -rf "$work"

finish
