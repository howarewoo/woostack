#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"

assert_file_contains() { # path needle message
  if grep -qF -- "$2" "$1"; then
    pass
  else
    fail "$3"
  fi
}

work="$(mktemp -d)"
repo="$work/repo"
trap 'rm -rf "$work"' EXIT
mkdir -p "$repo/src"
pushd "$repo" >/dev/null
git init -q
git config user.email test@example.com
git config user.name "Test User"
printf 'one\n' >src/app.sh
git add .
git commit -q -m init
head_oid="$(git rev-parse HEAD)"

threads='{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[{"isResolved":false,"path":"src/app.sh","line":2,"comments":{"nodes":[{"body":"**Open finding**\n\nDetails","author":{"login":"reviewer"}}]}},{"isResolved":true,"path":"src/app.sh","line":3,"comments":{"nodes":[{"body":"**Resolved finding**","author":{"login":"reviewer"}}]}}]}}}}}'

run_prefetch() {
  local out="$1" meta="$2"
  local diff=$'diff --git a/src/app.sh b/src/app.sh\n--- a/src/app.sh\n+++ b/src/app.sh\n@@ -1 +1,13 @@\n one\n+two\n+three\n+four\n+five\n+six\n+seven\n+eight\n+nine\n+ten\n+eleven\n+twelve\n+thirteen\n'
  OUTDIR="$out" \
  PR_NUMBER=1 \
  GITHUB_REPOSITORY=owner/repo \
  WOO_REVIEW_TEST_MODE=1 \
  GITHUB_ACTIONS=false \
  WOO_REVIEW_FAKE_PR_REVIEWS_JSON='{"reviews":[]}' \
  WOO_REVIEW_FAKE_BOT_COMMENTS=0 \
  WOO_REVIEW_FAKE_META_JSON="$meta" \
  WOO_REVIEW_FAKE_FULL_DIFF="$diff" \
  WOO_REVIEW_FAKE_PRIOR_THREADS_JSON="$threads" \
    bash "$DIR/prefetch.sh"
}

project_id="11111111-1111-4111-8111-111111111111"
project_meta="$(jq -cn --arg head "$head_oid" --arg project "$project_id" '{
  headRefOid:$head,
  headRefName:"feature/other",
  baseRefName:"main",
  title:"feature",
  body:("Summary\n\nLinear-Project: " + $project + "\nLinear-Issue: APP-42"),
  author:{login:"human"},
  files:[{path:"src/app.sh",additions:12,deletions:0}]
}')"
stdout="$(run_prefetch "$work/project-out" "$project_meta")"
assert_contains "$stdout" "Prefetch complete" "exact project/issue prefetch completes"
project_attribution="$(cat "$work/project-out/attribution.md")"
assert_contains "$project_attribution" "authoritative-issue-context: absent" \
  "prefetch never represents trailer text as authoritative context"
assert_contains "$project_attribution" "delivery-boundary: local-mcp-verification-required" \
  "local attribution requires later official-MCP verification"
assert_contains "$project_attribution" "trailer-syntax: exact-project-issue" \
  "ordered project/issue suffix is classified exactly"
assert_contains "$project_attribution" "Linear-Project: $project_id" \
  "project trailer string is preserved exactly"
assert_contains "$project_attribution" "Linear-Issue: APP-42" \
  "issue trailer string is preserved exactly"
[ ! -e "$work/project-out/intent.md" ] && pass ||
  fail "prefetch must not manufacture contract intent"

issue_meta="$(jq -cn --arg head "$head_oid" '{
  headRefOid:$head,
  headRefName:"fix/work-item",
  baseRefName:"main",
  title:"fix",
  body:"Summary\n\nLinear-Issue: APP-43",
  author:{login:"human"},
  files:[{path:"src/app.sh",additions:12,deletions:0}]
}')"
run_prefetch "$work/issue-out" "$issue_meta" >/dev/null
issue_attribution="$(cat "$work/issue-out/attribution.md")"
assert_contains "$issue_attribution" "trailer-syntax: exact-issue" \
  "standalone issue suffix is classified without a synthetic project"
assert_contains "$issue_attribution" "Linear-Issue: APP-43" \
  "standalone issue trailer string is preserved exactly"
assert_not_contains "$issue_attribution" "Linear-Project:" \
  "standalone attribution does not invent a project trailer"

invalid_meta="$(jq -cn --arg head "$head_oid" --arg project "$project_id" '{
  headRefOid:$head,
  headRefName:"feature/other",
  baseRefName:"main",
  title:"feature",
  body:("- Spec: .woostack/specs/legacy.md\n\nLinear-Project: " + $project + "\nLinear-Issue: APP-44"),
  author:{login:"human"},
  files:[{path:"src/app.sh",additions:12,deletions:0}]
}')"
run_prefetch "$work/invalid-out" "$invalid_meta" >/dev/null
invalid_attribution="$(cat "$work/invalid-out/attribution.md")"
assert_contains "$invalid_attribution" "trailer-syntax: invalid" \
  "wrapped legacy or mixed attribution is non-authoritative"
assert_not_contains "$invalid_attribution" "exact-trailers:" \
  "invalid remote text is not copied as a verified-looking trailer block"

reordered_meta="$(jq -cn --arg head "$head_oid" --arg project "$project_id" '{
  headRefOid:$head,
  headRefName:"feature/reordered",
  baseRefName:"main",
  title:"feature",
  body:("Linear-Issue: APP-45\nLinear-Project: " + $project),
  author:{login:"human"},
  files:[{path:"src/app.sh",additions:12,deletions:0}]
}')"
run_prefetch "$work/reordered-out" "$reordered_meta" >/dev/null
assert_contains "$(cat "$work/reordered-out/attribution.md")" "trailer-syntax: invalid" \
  "reordered trailer candidates never become exact attribution"
assert_not_contains "$(cat "$work/reordered-out/attribution.md")" "exact-trailers:" \
  "reordered trailer candidates are not emitted as exact strings"

duplicate_meta="$(jq -cn --arg head "$head_oid" --arg project "$project_id" '{
  headRefOid:$head,
  headRefName:"feature/duplicate",
  baseRefName:"main",
  title:"feature",
  body:("Linear-Project: " + $project + "\nLinear-Issue: APP-46\nLinear-Issue: APP-46"),
  author:{login:"human"},
  files:[{path:"src/app.sh",additions:12,deletions:0}]
}')"
run_prefetch "$work/duplicate-out" "$duplicate_meta" >/dev/null
assert_contains "$(cat "$work/duplicate-out/attribution.md")" "trailer-syntax: invalid" \
  "duplicate trailer candidates never become exact attribution"
assert_not_contains "$(cat "$work/duplicate-out/attribution.md")" "exact-trailers:" \
  "duplicate trailer candidates are not emitted as exact strings"

lookalike_meta="$(jq -cn --arg head "$head_oid" --arg project "$project_id" '{
  headRefOid:$head,
  headRefName:"feature/lookalike",
  baseRefName:"main",
  title:"feature",
  body:("linear-project: " + $project + "\nlinear-issue: APP-47"),
  author:{login:"human"},
  files:[{path:"src/app.sh",additions:12,deletions:0}]
}')"
run_prefetch "$work/lookalike-out" "$lookalike_meta" >/dev/null
assert_contains "$(cat "$work/lookalike-out/attribution.md")" "trailer-syntax: invalid" \
  "wrong-capitalization lookalikes are classified as invalid"
assert_not_contains "$(cat "$work/lookalike-out/attribution.md")" "exact-trailers:" \
  "wrong-capitalization lookalikes are never emitted as exact strings"

branch_meta="$(jq -cn --arg head "$head_oid" '{
  headRefOid:$head,
  headRefName:"feature/looks-like-a-local-spec",
  baseRefName:"main",
  title:"feature",
  body:"",
  author:{login:"human"},
  files:[{path:"src/app.sh",additions:12,deletions:0}]
}')"
run_prefetch "$work/branch-out" "$branch_meta" >/dev/null
assert_contains "$(cat "$work/branch-out/attribution.md")" "trailer-syntax: absent" \
  "branch resemblance never discovers development authority"
[ ! -e "$work/branch-out/intent.md" ] && pass ||
  fail "branch resemblance must not create contract intent"

assert_eq "$(jq 'length' "$work/project-out/prior-findings.json")" "2" \
  "GitHub review-thread extraction remains intact"
assert_eq "$(jq -r '.[0].status' "$work/project-out/prior-findings.json")" "open" \
  "open review threads still floor the GitHub review event"
assert_eq "$(jq -r '.[1].status' "$work/project-out/prior-findings.json")" "resolved" \
  "resolved review threads remain dedupe context"
assert_eq "$(jq -c '.[0]' "$work/project-out/prior-findings.json")" \
  '{"file":"src/app.sh","line":2,"title":"Open finding","author":"reviewer","status":"open"}' \
  "open GraphQL thread fields retain their posting-floor shape"
assert_eq "$(jq -c '.[1]' "$work/project-out/prior-findings.json")" \
  '{"file":"src/app.sh","line":3,"title":"Resolved finding","author":"reviewer","status":"resolved"}' \
  "resolved GraphQL thread fields retain their dedupe shape"

prefetch_source="$(cat "$DIR/prefetch.sh")"
action_source="$(cat "$ROOT/action.yml")"
workflow_source="$(cat "$ROOT/.github/workflows/reusable-review.yml")"
skill_source="$(cat "$ROOT/skills/woostack-review/SKILL.md")"
worker_source="$(cat "$ROOT/skills/woostack-review/prompts/_worker-header.md")"
orchestrator_source="$(cat "$ROOT/skills/woostack-review/prompts/_orchestrator-header.md")"

assert_file_contains "$DIR/prefetch.sh" \
  'ATTRIBUTION_DELIVERY="ci-diff-only-advisory"' \
  "CI attribution is labeled diff-only advisory"
assert_file_contains "$DIR/prefetch.sh" \
  'rm -f "$OUTDIR/intent.md"' \
  "prefetch removes any inherited contract context before CI handoff"
assert_file_contains "$DIR/prefetch.sh" "gh api graphql" \
  "GitHub GraphQL review-thread behavior is preserved"
assert_file_contains "$DIR/prefetch.sh" "reviewThreads(first: 100)" \
  "GitHub GraphQL still requests review threads"
for forbidden in "resolve-intent.sh" "resolve-artifact-context.sh" \
  "artifact-context" "INPUT_LINEAR_API_KEY" "LINEAR_API_KEY"; do
  assert_not_contains "$prefetch_source" "$forbidden" \
    "prefetch has no local authority, credential, or custom-context path: $forbidden"
done
[ ! -e "$DIR/resolve-artifact-context.sh" ] && pass ||
  fail "custom artifact-context resolver is deleted"
[ ! -e "$DIR/tests/test-resolve-artifact-context.sh" ] && pass ||
  fail "obsolete artifact-context resolver test is deleted"
[ ! -e "$DIR/tests/test-action-artifact-context.sh" ] && pass ||
  fail "obsolete action artifact-context test is deleted"

for forbidden in "linear-api-key" "linear_api_key" "INPUT_LINEAR_API_KEY" \
  "LINEAR_API_KEY" "artifact-context" "resolve-artifact-context.sh"; do
  assert_not_contains "$action_source" "$forbidden" \
    "composite action has no Linear credential or adapter path: $forbidden"
done
for forbidden in "linear-api-key" "linear_api_key" "INPUT_LINEAR_API_KEY" \
  "LINEAR_API_KEY" "artifact-context" "resolve-artifact-context.sh" "openssl enc" \
  "Encrypt remote artifact context" "Decrypt remote artifact context" "intent.md"; do
  assert_not_contains "$workflow_source" "$forbidden" \
    "reusable workflow has no key, adapter context, or crypto handoff: $forbidden"
done
assert_contains "$action_source" "CI-only, diff-only advisory extension" \
  "composite action labels its delivery authority"
assert_contains "$workflow_source" "exact PR trailer candidate, but no authoritative Linear issue context" \
  "reusable workflow labels uploaded review evidence non-authoritative"

assert_contains "$skill_source" "Through official MCP, completely read and independently verify" \
  "local review requires verified official-MCP context"
assert_contains "$skill_source" "Missing MCP, authentication, capability" \
  "missing local MCP blocks contract-aware acceptance"
assert_contains "$skill_source" "linear://issue/<verified-stable-uuid>" \
  "local prompt context records verified Linear provenance"
assert_contains "$worker_source" '"authority":"advisory-only"' \
  "worker receipts are explicitly advisory-only"
assert_contains "$orchestrator_source" "claims neither Linear read-back nor issue acceptance" \
  "CI review body discloses the absent authority boundary"

popd >/dev/null
trap - EXIT
rm -rf "$work"
finish
