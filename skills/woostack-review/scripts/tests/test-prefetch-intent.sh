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

earlier_issue_meta="$(jq -cn --arg head "$head_oid" --arg project "$project_id" '{
  headRefOid:$head,
  headRefName:"feature/conflicting-issue",
  baseRefName:"main",
  title:"feature",
  body:("Linear-Issue: UNTRUSTED-999\n\nLinear-Project: " + $project + "\nLinear-Issue: APP-44"),
  author:{login:"human"},
  files:[{path:"src/app.sh",additions:12,deletions:0}]
}')"
run_prefetch "$work/earlier-issue-out" "$earlier_issue_meta" >/dev/null
earlier_issue_attribution="$(cat "$work/earlier-issue-out/attribution.md")"
assert_contains "$earlier_issue_attribution" "trailer-syntax: invalid" \
  "an earlier conflicting issue invalidates an otherwise valid final pair"
assert_not_contains "$earlier_issue_attribution" "exact-trailers:" \
  "conflicting issue candidates are not emitted as exact attribution"

retired_spec_meta="$(jq -cn --arg head "$head_oid" '{
  headRefOid:$head,
  headRefName:"fix/retired-spec",
  baseRefName:"main",
  title:"fix",
  body:"Spec: .woostack/fixes/retired.md\n\nLinear-Issue: APP-48",
  author:{login:"human"},
  files:[{path:"src/app.sh",additions:12,deletions:0}]
}')"
run_prefetch "$work/retired-spec-out" "$retired_spec_meta" >/dev/null
retired_spec_attribution="$(cat "$work/retired-spec-out/attribution.md")"
assert_contains "$retired_spec_attribution" "trailer-syntax: invalid" \
  "an earlier retired Spec candidate invalidates a final issue suffix"
assert_not_contains "$retired_spec_attribution" "exact-trailers:" \
  "mixed retired and Linear candidates are not emitted as exact attribution"

duplicate_project_meta="$(jq -cn --arg head "$head_oid" --arg project "$project_id" '{
  headRefOid:$head,
  headRefName:"feature/duplicate-project",
  baseRefName:"main",
  title:"feature",
  body:("Linear-Project: " + $project + "\nLinear-Project: " + $project + "\nLinear-Issue: APP-49"),
  author:{login:"human"},
  files:[{path:"src/app.sh",additions:12,deletions:0}]
}')"
run_prefetch "$work/duplicate-project-out" "$duplicate_project_meta" >/dev/null
duplicate_project_attribution="$(cat "$work/duplicate-project-out/attribution.md")"
assert_contains "$duplicate_project_attribution" "trailer-syntax: invalid" \
  "duplicate project candidates never become exact attribution"
assert_not_contains "$duplicate_project_attribution" "exact-trailers:" \
  "duplicate project candidates are not emitted as exact strings"

benign_prose_meta="$(jq -cn --arg head "$head_oid" '{
  headRefOid:$head,
  headRefName:"fix/benign-prose",
  baseRefName:"main",
  title:"fix",
  body:"Summary mentions Linear-Project, Linear-Issue, and Spec without trailer syntax.\n\nLinear-Issue: APP-50",
  author:{login:"human"},
  files:[{path:"src/app.sh",additions:12,deletions:0}]
}')"
run_prefetch "$work/benign-prose-out" "$benign_prose_meta" >/dev/null
benign_prose_attribution="$(cat "$work/benign-prose-out/attribution.md")"
assert_contains "$benign_prose_attribution" "trailer-syntax: exact-issue" \
  "benign prose without exact trailer syntax does not add a candidate"
assert_contains "$benign_prose_attribution" "Linear-Issue: APP-50" \
  "the valid final issue suffix survives benign prose mentions"

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
for obsolete in \
  "$DIR/resolve-artifact-context.sh" \
  "$DIR/resolve-intent.sh" \
  "$DIR/parse-artifact-trailers.py" \
  "$DIR/tests/test-resolve-artifact-context.sh" \
  "$DIR/tests/test-action-artifact-context.sh" \
  "$DIR/tests/test-resolve-intent.sh"; do
  [ ! -e "$obsolete" ] && pass ||
    fail "obsolete local artifact reader remains: $obsolete"
done

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
for obsolete in "validate-prosecutor" "validate-adjudicator" \
  "disable_adversarial" "findings.prosecutor" "findings.defender"; do
  assert_not_contains "$action_source" "$obsolete" \
    "composite action has no removed validator mode/config path: $obsolete"
  assert_not_contains "$workflow_source" "$obsolete" \
    "reusable workflow has no removed validator mode/config path: $obsolete"
done
assert_eq "$(printf '%s\n' "$workflow_source" | grep -c 'mode: validate')" "1" \
  "reusable workflow invokes exactly one validate action"
assert_contains "$workflow_source" "pattern: findings-*" \
  "single validate job downloads every angle artifact"
assert_eq "$(printf '%s\n' "$workflow_source" | grep -c 'uses: howarewoo/woostack@a3dcbe88ad7606d722231646c7efc4fa2d6f737f')" "4" \
  "reusable workflow pins every phase to the single-adjudicator action revision"
assert_contains "$action_source" "prompts/validator.md" \
  "validate mode loads the sole evidence adjudicator"
assert_contains "$action_source" "WOO_REVIEW_SEQUENTIAL_VALIDATE" \
  "validate mode enables adjudicator finalization and posting"
assert_file_contains "$ROOT/skills/woostack-review/prompts/validator.md" \
  'verify-receipts.sh" --validators' \
  "CI adjudicator receipt gates finalization"
assert_file_contains "$ROOT/skills/woostack-review/prompts/validator.md" \
  'intersect-findings.sh' \
  "verified adjudicator output reaches deterministic finalization"
assert_contains "$action_source" "Validate execution mode" \
  "composite action rejects retired and unknown modes"
assert_contains "$action_source" 'full|detect|review|validate)' \
  "composite action accepts only the public execution modes"
assert_contains "$action_source" 'Bash(bash \"$WOO_REVIEW_ACTION_PATH/scripts/verify-receipts.sh\" --validators)' \
  "Anthropic adjudicator may run the exact receipt gate"
assert_contains "$action_source" 'Bash(bash \"$WOO_REVIEW_ACTION_PATH/scripts/intersect-findings.sh\")' \
  "Anthropic adjudicator may run the exact deterministic finalizer"
assert_not_contains "$action_source" '"Bash(bash:*)"' \
  "Anthropic runner does not grant arbitrary bash execution"

assert_file_contains "$ROOT/skills/woostack-review/prompts/_worker-header.md" \
  'other than `"advisory-only"`' \
  "worker receipts are explicitly advisory-only"
assert_file_contains "$ROOT/skills/woostack-review/prompts/_orchestrator-header.md" \
  "no parent-supplied contract context was available" \
  "CI review body discloses the absent contract boundary"

popd >/dev/null
trap - EXIT
rm -rf "$work"
finish
