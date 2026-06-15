#!/usr/bin/env bash
# Issue #374: on a rebased branch the incremental marker is no longer an ancestor
# of HEAD, so the three-dot compare bleeds in commits the branch was rebased over
# (files NOT in the PR). prefetch.sh must intersect the incremental diff against
# the authoritative PR file set (meta.json .files[].path) so off-PR sections never
# reach the angle workers / posting stage (which 422s on out-of-PR paths).
#
# This drives the incremental path via the test hooks (WOO_REVIEW_FAKE_*), feeding
# an incremental diff that contains an in-PR file (src/app.sh) AND an off-PR leak
# (src/leaked.sh) while meta.json lists only src/app.sh. The leaked section must be
# dropped from diff.txt.
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
mkdir -p src
printf 'one\n' > src/app.sh
git add .
git commit -q -m init

# meta.json: PR scope is src/app.sh ONLY. headRefOid differs from the marker SHA
# so the no-new-commits short-circuit does not fire and the incremental path runs.
meta='{"headRefOid":"abc1234","baseRefName":"main","title":"feature work","body":"","author":{"login":"human"},"files":[{"path":"src/app.sh","additions":1,"deletions":0}]}'

# Incremental diff as the stale three-dot compare would produce it: the in-PR file
# plus a leaked off-PR file from the rebased-over base.
incr=$'diff --git a/src/app.sh b/src/app.sh\n--- a/src/app.sh\n+++ b/src/app.sh\n@@ -1,1 +1,2 @@\n one\n+two\ndiff --git a/src/leaked.sh b/src/leaked.sh\n--- a/src/leaked.sh\n+++ b/src/leaked.sh\n@@ -0,0 +1,1 @@\n+leaked\n'

# Trusted marker: a woostack-review bot review body carrying a prior-run SHA that
# differs from headRefOid. Bot authorship is trusted in both CI and local runs.
reviews='{"reviews":[{"author":{"login":"claude[bot]"},"body":"LGTM\n\n<!-- woostack-review:sha=deadbee -->","submittedAt":"2026-06-01T00:00:00Z"}]}'

OUTDIR="$out" \
PR_NUMBER=1 \
GITHUB_REPOSITORY=owner/repo \
WOO_REVIEW_TEST_MODE=1 \
WOO_REVIEW_FAKE_PR_REVIEWS_JSON="$reviews" \
WOO_REVIEW_FAKE_BOT_COMMENTS=0 \
WOO_REVIEW_FAKE_META_JSON="$meta" \
WOO_REVIEW_FAKE_INCREMENTAL_DIFF="$incr" \
WOO_REVIEW_FAKE_PRIOR_THREADS_JSON='{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[]}}}}}' \
  bash "$DIR/prefetch.sh" >/tmp/review-prefetch-incremental-rebase.out

stdout="$(cat /tmp/review-prefetch-incremental-rebase.out)"
diff_txt="$(cat "$out/diff.txt")"

assert_contains "$stdout" "Prefetch complete" "prefetch completes on the incremental path"
assert_contains "$diff_txt" "b/src/app.sh" "in-PR file section is kept"
assert_not_contains "$diff_txt" "src/leaked.sh" "off-PR (rebase-leaked) file section is dropped"

popd >/dev/null
rm -rf "$work"

finish
