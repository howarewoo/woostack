#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"

work="$(mktemp -d)"
repo="$work/repo"
mkdir -p "$repo/.woostack/specs" "$repo/.woostack/plans" "$repo/.woostack/fixes" "$repo/src"
pushd "$repo" >/dev/null
git init -q
git config user.email test@example.com
git config user.name "Test User"
printf 'one\n' > src/app.sh
cat > .woostack/specs/2026-07-14-feature.md <<'EOF'
---
type: spec
status: approved
branch: feature/demo
---
## 7. Acceptance criteria
- works
EOF
cat > .woostack/plans/2026-07-14-feature.md <<'EOF'
---
type: plan
source: .woostack/specs/2026-07-14-feature.md
status: executing
branch: feature/demo
---
**Source:** [[specs/2026-07-14-feature]]
- [x] implementation
EOF
cat > .woostack/fixes/2026-07-14-fix.md <<'EOF'
---
type: fix
status: executing
branch: fix/demo
---
- [x] fix implementation
EOF
git add .
git commit -q -m init

run_prefetch() {
  local out="$1" meta="$2"
  local diff=$'diff --git a/src/app.sh b/src/app.sh\n--- a/src/app.sh\n+++ b/src/app.sh\n@@ -1 +1,13 @@\n one\n+two\n+three\n+four\n+five\n+six\n+seven\n+eight\n+nine\n+ten\n+eleven\n+twelve\n+thirteen\n'
  OUTDIR="$out" \
  PR_NUMBER=1 \
  GITHUB_REPOSITORY=owner/repo \
  WOO_REVIEW_TEST_MODE=1 \
  WOO_REVIEW_FAKE_PR_REVIEWS_JSON='{"reviews":[]}' \
  WOO_REVIEW_FAKE_BOT_COMMENTS=0 \
  WOO_REVIEW_FAKE_META_JSON="$meta" \
  WOO_REVIEW_FAKE_FULL_DIFF="$diff" \
  WOO_REVIEW_FAKE_PRIOR_THREADS_JSON='{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[]}}}}}' \
    bash "$DIR/prefetch.sh"
}

meta=$(jq -cn '{headRefOid:"abc123",headRefName:"feature/other",baseRefName:"main",title:"feature",body:"Spec: .woostack/specs/2026-07-14-feature.md",author:{login:"human"},files:[{path:"src/app.sh",additions:12,deletions:0}]}')
stdout="$(run_prefetch "$work/trailer-out" "$meta")"
assert_contains "$stdout" "Prefetch complete" "trailer prefetch completes"
assert_contains "$(cat "$work/trailer-out/intent.md")" "## SOURCE: .woostack/specs/2026-07-14-feature.md" "prefetch composes trailer spec"
assert_contains "$(cat "$work/trailer-out/intent.md")" "## SOURCE: .woostack/plans/2026-07-14-feature.md" "prefetch composes linked plan"

meta=$(jq -cn '{headRefOid:"def456",headRefName:"fix/demo",baseRefName:"main",title:"fix",body:"",author:{login:"human"},files:[{path:"src/app.sh",additions:12,deletions:0}]}')
run_prefetch "$work/branch-out" "$meta" >/dev/null
assert_contains "$(cat "$work/branch-out/intent.md")" "## SOURCE: .woostack/fixes/2026-07-14-fix.md" "prefetch resolves fix branch"

meta=$(jq -cn '{headRefOid:"ghi789",headRefName:"feature/unknown",baseRefName:"main",title:"other",body:"",author:{login:"human"},files:[{path:"src/app.sh",additions:12,deletions:0}]}')
stdout="$(run_prefetch "$work/no-intent-out" "$meta")"
assert_contains "$stdout" "Prefetch complete" "no-intent prefetch remains successful"
[ ! -e "$work/no-intent-out/intent.md" ] && pass || fail "unresolved prefetch produces no intent"
[ -s "$work/no-intent-out/meta.json" ] && pass || fail "no-intent prefetch preserves metadata"
[ -s "$work/no-intent-out/diff.txt" ] && pass || fail "no-intent prefetch preserves diff"

popd >/dev/null
rm -rf "$work"
finish
