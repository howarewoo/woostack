#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$SCRIPT_DIR"
. "$SCRIPT_DIR/path-utils.sh"
if [ -z "${WOOSTACK_NATIVE_NODE:-}" ]; then
  WOOSTACK_NATIVE_NODE=$(command -v "${NODE:-node}")
  export WOOSTACK_NATIVE_NODE
fi
if command -v cygpath >/dev/null 2>&1; then
  TMPDIR=$(shell_native_path "$("$WOOSTACK_NATIVE_NODE" -p "require('node:os').tmpdir()")")
  export TMPDIR
fi
export NODE="$SCRIPT_DIR/node-native-paths.sh"

status=0
for test_file in test-*.sh; do
  [ -f "$test_file" ] || continue
  printf '== %s ==\n' "$test_file"
  if ! bash "$test_file"; then
    status=1
  fi
done

printf '== node contract tests ==\n'
if ! "$NODE" --test test-*.test.mjs; then
  status=1
fi
exit "$status"
