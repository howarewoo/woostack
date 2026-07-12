#!/usr/bin/env bash
set -eu

tests=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
found=0
for test_script in "$tests"/test-*.sh; do
  [ -e "$test_script" ] || continue
  found=1
  printf '==> %s\n' "$(basename "$test_script")"
  bash "$test_script"
done

if [ "$found" -eq 0 ]; then
  printf 'FAIL: no focused response tests discovered\n' >&2
  exit 1
fi
printf 'PASS: all focused response tests\n'
