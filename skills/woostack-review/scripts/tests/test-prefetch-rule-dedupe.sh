#!/usr/bin/env bash
# Regression for issue #445: project-rule discovery must include each unique
# rules document once even when common agent-rule filenames are symlink aliases
# or config globs point at copied content.
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
mkdir -p .claude .woostack docs src
printf 'canonical review rule\n' > AGENTS.md
ln -s AGENTS.md GEMINI.md
ln -s ../AGENTS.md .claude/CLAUDE.md
ln -s ../AGENTS.md src/AGENTS.md
cp AGENTS.md docs/copied-rules.md
printf 'distinct docs-only rule\n' > docs/unique-rules.md
cat > .woostack/config.json <<'JSON'
{
  "review": {
    "project_rules": [
      "AGENTS.md",
      ".claude/CLAUDE.md",
      "docs/copied-rules.md",
      "docs/unique-rules.md"
    ]
  }
}
JSON
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
  bash "$DIR/prefetch.sh" >/tmp/review-prefetch-rule-dedupe.out

rules="$(cat "$out/rules.md")"
stdout="$(cat /tmp/review-prefetch-rule-dedupe.out)"

assert_contains "$stdout" "Prefetch complete" "prefetch completes"
assert_eq "$(printf '%s\n' "$rules" | grep -c '^## SOURCE:')" "2" \
  "aliases collapse to one entry while distinct-content rules stay separate"
assert_eq "$(printf '%s\n' "$rules" | grep -c '^canonical review rule$')" "1" \
  "canonical rule body appears once"
assert_contains "$rules" "## SOURCE: AGENTS.md" "first discovered source label is preserved"
assert_contains "$rules" "## SOURCE: docs/unique-rules.md" \
  "distinct-content rule file keeps its own source section"
assert_eq "$(printf '%s\n' "$rules" | grep -c '^distinct docs-only rule$')" "1" \
  "distinct rule body is emitted"

popd >/dev/null
rm -rf "$work"

finish
