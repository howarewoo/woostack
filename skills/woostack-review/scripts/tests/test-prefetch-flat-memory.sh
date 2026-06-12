#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"

work="$(mktemp -d)"
out="$work/out"
pushd "$work" >/dev/null
git init -q
git config user.email test@example.com
git config user.name "Test User"
mkdir -p .woostack/memory src
printf -- '- legacy flat memory must not be recalled\n' > .woostack/memory.md
cat > .woostack/memory/scoped.md <<'NOTE'
---
name: scoped
type: pattern
scope: src/**
---
Scoped memory should be recalled.
NOTE
printf 'one\n' > src/app.sh
git add .
git commit -q -m init

meta='{"headRefOid":"abc123","baseRefName":"main","title":"feature work","body":"","author":{"login":"human"},"files":[{"path":"src/app.sh","additions":12,"deletions":0}]}'
diff=$'diff --git a/src/app.sh b/src/app.sh\n--- a/src/app.sh\n+++ b/src/app.sh\n@@ -1,1 +1,13 @@\n one\n+two\n+three\n+four\n+five\n+six\n+seven\n+eight\n+nine\n+ten\n+eleven\n+twelve\n+thirteen\n'

OUTDIR="$out" \
PR_NUMBER=1 \
GITHUB_REPOSITORY=owner/repo \
WOO_REVIEW_TEST_MODE=1 \
WOO_REVIEW_FAKE_PR_REVIEWS_JSON='{"reviews":[]}' \
WOO_REVIEW_FAKE_BOT_COMMENTS=0 \
WOO_REVIEW_FAKE_META_JSON="$meta" \
WOO_REVIEW_FAKE_FULL_DIFF="$diff" \
WOO_REVIEW_FAKE_PRIOR_THREADS_JSON='{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[]}}}}}' \
  bash "$DIR/prefetch.sh" >/tmp/review-prefetch-flat-memory.out

assert_contains "$(cat /tmp/review-prefetch-flat-memory.out)" "Prefetch complete" "prefetch completes"
assert_contains "$(cat "$out/memory.md")" "Scoped memory should be recalled" "scoped memory is composed"

rm -rf .woostack/memory
OUTDIR="$out" \
PR_NUMBER=1 \
GITHUB_REPOSITORY=owner/repo \
WOO_REVIEW_TEST_MODE=1 \
WOO_REVIEW_FAKE_PR_REVIEWS_JSON='{"reviews":[]}' \
WOO_REVIEW_FAKE_BOT_COMMENTS=0 \
WOO_REVIEW_FAKE_META_JSON="$meta" \
WOO_REVIEW_FAKE_FULL_DIFF="$diff" \
WOO_REVIEW_FAKE_PRIOR_THREADS_JSON='{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[]}}}}}' \
  bash "$DIR/prefetch.sh" >/tmp/review-prefetch-flat-memory-legacy.out

assert_contains "$(cat /tmp/review-prefetch-flat-memory-legacy.out)" "Prefetch complete" "flat-only prefetch completes"
assert_exit 1 "$([ -e "$out/memory.md" ]; echo $?)" "flat-only memory is not composed"

popd >/dev/null
rm -rf "$work"

finish
