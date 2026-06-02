#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DIR/tests/assert.sh"
SM="$DIR/scope-match.sh"

paths=$'packages/api/orpc/x.ts\npackages/web/y.tsx\napps/admin/z.ts\nREADME.md'

# ** crosses slashes
out="$(printf '%s\n' "$paths" | bash "$SM" 'packages/api/**')"
assert_contains "$out" "packages/api/orpc/x.ts" "** matches subtree"
assert_not_contains "$out" "packages/web/y.tsx" "** excludes sibling"

# * does not cross a slash
out="$(printf '%s\n' "$paths" | bash "$SM" 'apps/*/z.ts')"
assert_contains "$out" "apps/admin/z.ts" "* matches one segment"

out="$(printf '%s\n' "$paths" | bash "$SM" 'apps/*.ts' || true)"
assert_not_contains "$out" "apps/admin/z.ts" "* does not cross slash"

# exact + dot escaping
out="$(printf '%s\n' "$paths" | bash "$SM" 'README.md')"
assert_contains "$out" "README.md" "exact literal match"
out="$(printf '%s\n' "$paths" | bash "$SM" 'READMEXmd' || true)"
assert_not_contains "$out" "README.md" "dot is escaped, not any-char"

# comma list = OR
out="$(printf '%s\n' "$paths" | bash "$SM" 'packages/web/**, apps/*/z.ts')"
assert_contains "$out" "packages/web/y.tsx" "comma list alt 1"
assert_contains "$out" "apps/admin/z.ts" "comma list alt 2"

# global: empty or *
out="$(printf '%s\n' "$paths" | bash "$SM" '*')"
assert_contains "$out" "README.md" "star is global"
out="$(printf '%s\n' "$paths" | bash "$SM" '')"
assert_contains "$out" "packages/api/orpc/x.ts" "empty is global"

# exit status: no match → 1
set +e
printf '%s\n' "$paths" | bash "$SM" 'nope/**' >/dev/null; code=$?
set -e
assert_exit 1 "$code" "no match exits 1"

# regression: global on empty stdin → exit 1, no output
set +e; out="$(printf '' | bash "$SM" '*')"; code=$?; set -e
assert_eq "$out" "" "global on empty stdin prints nothing"
assert_exit 1 "$code" "global on empty stdin exits 1"

# anchoring: bare segment must not match mid-path
out="$(printf '%s\n' "$paths" | bash "$SM" 'api' || true)"
assert_not_contains "$out" "packages/api/orpc/x.ts" "anchored, no substring match"

finish
