#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../../.." && pwd)
PREFETCH="$SCRIPT_DIR/prefetch.sh"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/woostack-review-skill-small-diff.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM
mkdir -p "$TMP_ROOT/bin"
cat >"$TMP_ROOT/bin/gh" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = api ] && [ "${2:-}" = user ]; then
  printf '%s\n' tester
  exit 0
fi
printf 'unexpected gh invocation: %s\n' "$*" >&2
exit 97
SH
chmod +x "$TMP_ROOT/bin/gh"
TEST_PATH="$TMP_ROOT/bin:$PATH"

init_repo() {
  REPO="$TMP_ROOT/$1"
  mkdir -p "$REPO"
  git -C "$REPO" init -q
  git -C "$REPO" config user.email test@example.com
  git -C "$REPO" config user.name "Test User"
}

create_skill() {
  mkdir -p "$REPO/skills/example/references"
  cat >"$REPO/skills/example/SKILL.md" <<'EOF'
---
name: example
description: Review example packages safely.
---
# Example

[Guide](references/guide.md)

Stable body.
EOF
  printf '# Guide\n' >"$REPO/skills/example/references/guide.md"
}

meta_for() {
  path=$1
  additions=$2
  deletions=$3
  jq -cn \
    --arg head "$(git -C "$REPO" rev-parse HEAD)" \
    --arg path "$path" \
    --argjson additions "$additions" \
    --argjson deletions "$deletions" \
    '{headRefOid:$head,headRefName:"feature/small-skill",baseRefName:"main",title:"small change",body:"",author:{login:"human"},files:[{path:$path,additions:$additions,deletions:$deletions}]}'
}

run_prefetch() {
  out=$1
  meta=$2
  diff_file=$3
  reviews=${4:-'{"reviews":[]}'}
  incremental=${5:-}
  stdout_file="$TMP_ROOT/prefetch.$$.out"
  stderr_file="$TMP_ROOT/prefetch.$$.err"
  set +e
  (
    cd "$REPO"
    PATH="$TEST_PATH" \
    OUTDIR="$out" \
    PR_NUMBER=1 \
    GITHUB_REPOSITORY=owner/repo \
    GITHUB_WORKSPACE="$REPO" \
    WOO_REVIEW_TEST_MODE=1 \
    WOO_REVIEW_FAKE_PR_REVIEWS_JSON="$reviews" \
    WOO_REVIEW_FAKE_BOT_COMMENTS=0 \
    WOO_REVIEW_FAKE_META_JSON="$meta" \
    WOO_REVIEW_FAKE_FULL_DIFF="$(cat "$diff_file")" \
    WOO_REVIEW_FAKE_INCREMENTAL_DIFF="$incremental" \
    WOO_REVIEW_FAKE_PRIOR_THREADS_JSON='{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[]}}}}}' \
      bash "$PREFETCH"
  ) >"$stdout_file" 2>"$stderr_file"
  RUN_RC=$?
  set -e
  RUN_STDOUT=$(cat "$stdout_file")
  RUN_STDERR=$(cat "$stderr_file")
  rm -f "$stdout_file" "$stderr_file"
}

# A one-line edit to an existing, valid right-side SKILL.md is reviewable even
# when the full PR reports fewer than ten changed lines. Package validation and
# snapshotting must finish before the exemption is used.
init_repo present-skill
create_skill
git -C "$REPO" add .
git -C "$REPO" commit -q -m base
sed -i.bak 's/Review example packages safely/Review example packages carefully/' "$REPO/skills/example/SKILL.md"
rm "$REPO/skills/example/SKILL.md.bak"
git -C "$REPO" add skills/example/SKILL.md
git -C "$REPO" commit -q -m reviewable-change
present_diff="$TMP_ROOT/present-skill.diff"
git -C "$REPO" show --format= --no-ext-diff --binary HEAD -- skills/example/SKILL.md >"$present_diff"
present_out="$TMP_ROOT/present-skill-out"
run_prefetch "$present_out" "$(meta_for skills/example/SKILL.md 1 1)" "$present_diff"
assert_exit 0 "$RUN_RC" "one-line existing SKILL.md edit completes prefetch"
assert_not_contains "$RUN_STDOUT" "Skipping: <10 LOC changed" "present right-side SKILL.md bypasses the full-diff LOC floor"
assert_contains "$RUN_STDOUT" "Prefetch complete" "small SKILL.md edit remains reviewable"
assert_eq "$(jq -r '.packages | length' "$present_out/skill-packages.json")" "1" "small SKILL.md edit validates and snapshots its package"
OUTDIR="$present_out" bash "$SCRIPT_DIR/detect-angles.sh" >/dev/null
assert_eq "$(grep -cx 'skills' "$present_out/angles.txt" || true)" "1" "small SKILL.md edit enables the skills angle"

# The exemption is not a general small-source or Markdown exemption.
init_repo source
mkdir -p "$REPO/src"
printf 'const value = 1;\n' >"$REPO/src/app.js"
git -C "$REPO" add .
git -C "$REPO" commit -q -m base
printf 'const value = 2;\n' >"$REPO/src/app.js"
source_diff="$TMP_ROOT/source.diff"
git -C "$REPO" diff --no-ext-diff --binary -- src/app.js >"$source_diff"
run_prefetch "$TMP_ROOT/source-out" "$(meta_for src/app.js 1 1)" "$source_diff"
assert_exit 0 "$RUN_RC" "one-line non-skill source uses a successful skip"
assert_contains "$RUN_STDOUT" "Skipping: <10 LOC changed" "one-line non-skill source keeps the full-diff LOC skip"

init_repo markdown
printf '# Before\n' >"$REPO/README.md"
git -C "$REPO" add .
git -C "$REPO" commit -q -m base
printf '# After\n' >"$REPO/README.md"
markdown_diff="$TMP_ROOT/markdown.diff"
git -C "$REPO" diff --no-ext-diff --binary -- README.md >"$markdown_diff"
run_prefetch "$TMP_ROOT/markdown-out" "$(meta_for README.md 1 1)" "$markdown_diff"
assert_exit 0 "$RUN_RC" "one-line non-skill Markdown uses a successful skip"
assert_contains "$RUN_STDOUT" "Skipping: <10 LOC changed" "one-line non-skill Markdown preserves the existing LOC skip"

# A present touched skill that cannot validate fails closed before any LOC skip.
init_repo invalid-skill
create_skill
git -C "$REPO" add .
git -C "$REPO" commit -q -m base
sed -i.bak 's|references/guide.md|references/missing.md|' "$REPO/skills/example/SKILL.md"
rm "$REPO/skills/example/SKILL.md.bak"
git -C "$REPO" add skills/example/SKILL.md
git -C "$REPO" commit -q -m invalid-change
invalid_diff="$TMP_ROOT/invalid-skill.diff"
git -C "$REPO" show --format= --no-ext-diff --binary HEAD -- skills/example/SKILL.md >"$invalid_diff"
run_prefetch "$TMP_ROOT/invalid-skill-out" "$(meta_for skills/example/SKILL.md 1 1)" "$invalid_diff"
if [ "$RUN_RC" -ne 0 ]; then pass; else fail "invalid small SKILL.md edit must hard-fail prefetch"; fi
assert_contains "$RUN_STDERR" "skill package validation or snapshot failed" "invalid small SKILL.md edit reports package validation failure"
assert_not_contains "$RUN_STDOUT" "Skipping: <10 LOC changed" "validation failure occurs before the LOC floor"

# Incremental reviews already accept tiny fixups and remain unchanged.
init_repo incremental
mkdir -p "$REPO/src"
printf 'before\n' >"$REPO/src/app.js"
git -C "$REPO" add .
git -C "$REPO" commit -q -m base
printf 'after\n' >"$REPO/src/app.js"
incremental_diff="$TMP_ROOT/incremental.diff"
git -C "$REPO" diff --no-ext-diff --binary -- src/app.js >"$incremental_diff"
incremental_reviews='{"reviews":[{"author":{"login":"claude[bot]"},"body":"reviewed\n\n<!-- woostack-review:sha=deadbee -->","submittedAt":"2026-07-01T00:00:00Z"}]}'
run_prefetch "$TMP_ROOT/incremental-out" "$(meta_for src/app.js 1 1)" "$incremental_diff" "$incremental_reviews" "$(cat "$incremental_diff")"
assert_exit 0 "$RUN_RC" "tiny incremental non-skill diff completes"
assert_contains "$RUN_STDOUT" "Prefetch complete" "incremental tiny-fix behavior remains reviewable"
assert_not_contains "$RUN_STDOUT" "Skipping: <10 LOC changed" "incremental reviews remain outside the full-diff LOC floor"

# A committed SKILL.md deletion has no current/right-side package and therefore
# receives neither the LOC exemption nor the skills angle.
init_repo deleted-skill
create_skill
git -C "$REPO" add .
git -C "$REPO" commit -q -m base
git -C "$REPO" rm -q skills/example/SKILL.md
git -C "$REPO" commit -q -m delete-skill
deleted_diff="$TMP_ROOT/deleted-skill.diff"
git -C "$REPO" show --format= --no-ext-diff --binary HEAD -- skills/example/SKILL.md >"$deleted_diff"
deleted_out="$TMP_ROOT/deleted-skill-out"
run_prefetch "$deleted_out" "$(meta_for skills/example/SKILL.md 0 1)" "$deleted_diff"
assert_exit 0 "$RUN_RC" "small deleted SKILL.md uses a successful skip"
assert_contains "$RUN_STDOUT" "Skipping: <10 LOC changed" "deleted SKILL.md has no right-side LOC exemption"
assert_eq "$(jq -r '.packages | length' "$deleted_out/skill-packages.json")" "0" "deleted SKILL.md has no right-side package snapshot"
OUTDIR="$deleted_out" bash "$SCRIPT_DIR/detect-angles.sh" >/dev/null
assert_eq "$(grep -cx 'skills' "$deleted_out/angles.txt" || true)" "0" "deleted SKILL.md does not enable the skills angle"

finish
