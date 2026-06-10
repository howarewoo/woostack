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

# stack_aware:false accepted + emitted to canonical config.
setup '{"review":{"stack_aware":false}}'
bash "$SCRIPT" >/tmp/load-config-stack.out 2>&1
assert_eq "$(jq -r '.stack_aware' "$OUTDIR/config.json")" "false" "stack_aware:false emitted"
rm -rf "$work"

# stack_aware:true accepted + emitted.
setup '{"review":{"stack_aware":true}}'
bash "$SCRIPT" >/tmp/load-config-stack.out 2>&1
assert_eq "$(jq -r '.stack_aware' "$OUTDIR/config.json")" "true" "stack_aware:true emitted"
rm -rf "$work"

# Non-boolean stack_aware fails the loader loudly (non-zero exit).
setup '{"review":{"stack_aware":"yes"}}'
set +e
bash "$SCRIPT" >/tmp/load-config-stack.out 2>&1
rc=$?
set -e
assert_eq "$([ "$rc" -ne 0 ] && echo nonzero || echo zero)" "nonzero" "non-boolean stack_aware fails loader"
assert_contains "$(cat /tmp/load-config-stack.out)" "stack_aware" "error names the stack_aware key"
rm -rf "$work"

# stack_aware omitted: key stays unset in emitted config.
setup '{"review":{}}'
bash "$SCRIPT" >/tmp/load-config-stack.out 2>&1
assert_eq "$(jq -r '.stack_aware' "$OUTDIR/config.json")" "null" "missing stack_aware key is omitted"
rm -rf "$work"

finish
