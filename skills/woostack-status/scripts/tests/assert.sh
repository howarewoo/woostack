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
finish() { echo "  $PASS passed, $FAIL failed"; [ "$FAIL" -eq 0 ]; }

# Build a throwaway memory dir; echoes its path.
mk_memdir() { mktemp -d; }
# Write a note: mk_note <dir> <filename> <frontmatter-block> <body>
mk_note() { printf -- '---\n%s\n---\n%s\n' "$3" "$4" > "$1/$2"; }
