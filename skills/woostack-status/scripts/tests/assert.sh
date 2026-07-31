#!/usr/bin/env bash
# Minimal bash test helpers for the woostack-init scripts.
set -euo pipefail

PASS=0; FAIL=0

assert_eq() { # actual expected msg
  if [ "$1" = "$2" ]; then PASS=$((PASS+1)); else
    FAIL=$((FAIL+1)); echo "  FAIL: $3"; echo "    expected: [$2]"; echo "    actual:   [$1]"; fi
}
assert_contains() { # haystack needle msg
  if printf '%s' "$1" | grep -qF -- "$2"; then PASS=$((PASS+1)); else
    FAIL=$((FAIL+1)); echo "  FAIL: $3"; echo "    [$1] does not contain [$2]"; fi
}
assert_not_contains() { # haystack needle msg
  if printf '%s' "$1" | grep -qF -- "$2"; then
    FAIL=$((FAIL+1)); echo "  FAIL: $3"; echo "    [$1] unexpectedly contains [$2]"; else PASS=$((PASS+1)); fi
}
assert_exit() { # expected_code actual_code msg
  if [ "$1" = "$2" ]; then PASS=$((PASS+1)); else
    FAIL=$((FAIL+1)); echo "  FAIL: $3 (expected exit $1, got $2)"; fi
}
assert_file_exists() { # path msg
  if [ -s "$1" ]; then PASS=$((PASS+1)); else
    FAIL=$((FAIL+1)); echo "  FAIL: $2"; echo "    file missing or empty: [$1]"; fi
}
assert_file_absent() { # path msg
  if [ ! -e "$1" ]; then PASS=$((PASS+1)); else
    FAIL=$((FAIL+1)); echo "  FAIL: $2"; echo "    file exists: [$1]"; fi
}
finish() { echo "  $PASS passed, $FAIL failed"; [ "$FAIL" -eq 0 ]; }
