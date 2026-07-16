#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$SCRIPT_DIR"

status=0
for test_file in test-*.sh; do
  [ -f "$test_file" ] || continue
  printf '== %s ==\n' "$test_file"
  if ! bash "$test_file"; then
    status=1
  fi
done
exit "$status"
