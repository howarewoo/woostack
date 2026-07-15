#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/resolve-diff-line.sh"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

diff="$work/diff.txt"
cache="$work/cache.json"
cat > "$diff" <<'DIFF'
diff --git a/src/app.ts b/src/app.ts
index 1111111..2222222 100644
--- a/src/app.ts
+++ b/src/app.ts
@@ -10,3 +10,3 @@
 const ten = true;
-old eleven
+const eleven = true;
 const twelve = true;
@@ -20,1 +20,0 @@
-deleted only
@@ -30,2 +30,2 @@
 const thirty = true;
+const thirtyOne = true;
DIFF

resolve() {
  bash "$SCRIPT" --file src/app.ts --diff "$diff" --cache "$cache" "$@"
}

assert_eq "$(resolve --line 10 --no-cache)" "10" "single-line valid anchor stays compatible"
assert_eq "$(resolve --line 20 --no-cache)" "null" "single-line deletion-only anchor stays rejected"
assert_eq "$(resolve --line 99 --no-cache)" "null" "single-line out-of-hunk anchor stays rejected"
assert_eq "$(resolve --line nope --no-cache)" "null" "single-line malformed anchor stays rejected"

assert_eq "$(resolve --line 10 --end 12 --no-cache)" "10:12" "same-hunk RIGHT-side range resolves"
assert_eq "$(resolve --line 10 --end 30 --no-cache)" "10" "cross-hunk endpoint degrades to start"
assert_eq "$(resolve --line 10 --end 10 --no-cache)" "10" "equal endpoint degrades to start"
assert_eq "$(resolve --line 12 --end 10 --no-cache)" "12" "reversed endpoint degrades to start"
assert_eq "$(resolve --line 10 --end nope --no-cache)" "10" "malformed endpoint degrades to start"
assert_eq "$(resolve --line 10 --end 20 --no-cache)" "10" "deletion-only endpoint degrades to start"
assert_eq "$(resolve --line 10 --end 99 --no-cache)" "10" "out-of-hunk endpoint degrades to start"
assert_eq "$(resolve --line 99 --end 30 --no-cache)" "null" "invalid start remains unresolvable"

assert_eq "$(resolve --line 10 --end 12)" "10:12" "valid range is cached"
assert_eq "$(resolve --line 10 --end 30)" "10" "cache key includes endpoint"

finish
