#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

ruby -ryaml -rjson -e 'puts JSON.generate(YAML.load_file(ARGV.fetch(0)))' \
  "$ROOT/action.yml" >"$TMP/action.json"
ruby -ryaml -rjson -e 'puts JSON.generate(YAML.load_file(ARGV.fetch(0)))' \
  "$ROOT/.github/workflows/reusable-review.yml" >"$TMP/workflow.json"

action="$TMP/action.json"
workflow="$TMP/workflow.json"

file_mode() {
  stat -f '%Lp' "$1" 2>/dev/null || stat -c '%a' "$1"
}

assert_eq "$(jq -r '.inputs["linear-api-key"].required' "$action")" 'false' \
  "composite action exposes optional linear-api-key input"
assert_contains "$(jq -r '.inputs["linear-api-key"].description' "$action")" 'read-only' \
  "action credential contract names its read-only scope"

prefetch_index="$(jq -r '.runs.steps | map(.name) | index("Prefetch diff, metadata, rules, config, memory")' "$action")"
context_index="$(jq -r '.runs.steps | map(.name) | index("Resolve read-only artifact context")' "$action")"
detect_index="$(jq -r '.runs.steps | map(.name) | index("Detect review angles")' "$action")"
if [ "$prefetch_index" -lt "$context_index" ] && [ "$context_index" -lt "$detect_index" ]; then
  pass
else
  fail "artifact context executes after prefetch and before angle detection"
fi
assert_eq "$(jq -r '.runs.steps[] | select(.name=="Resolve read-only artifact context") | .run' "$action")" \
  'bash "${{ github.action_path }}/skills/woostack-review/scripts/resolve-artifact-context.sh"' \
  "action truly executes the artifact-context helper"
assert_eq "$(jq -r '.runs.steps[] | select(.name=="Resolve read-only artifact context") | .env.INPUT_LINEAR_API_KEY' "$action")" \
  "\${{ inputs['linear-api-key'] }}" \
  "action passes the optional secret only to the helper input env"
assert_eq "$(jq -r '.runs.steps[] | select(.name=="Resolve read-only artifact context") | .if' "$action")" \
  "steps.prefetch.outputs.skip != 'true' && (inputs.mode == 'full' || inputs.mode == 'detect')" \
  "action resolves remote artifact context only in the single full or detection pass"
assert_eq "$(jq -r '.runs.steps[] | select(.id=="prefetch") | .env.WOO_REVIEW_MODE' "$action")" \
  '${{ inputs.mode }}' "prefetch receives the action mode needed to preserve downloaded context"
assert_eq "$(jq '[.runs.steps[] | select(.name | startswith("Run review")) | (.env // {}) | has("INPUT_LINEAR_API_KEY")] | any' "$action")" \
  'false' "provider workers never inherit the Linear credential"

assert_eq "$(jq -r '(.on // .true).workflow_call.secrets.linear_api_key.required' "$workflow")" 'false' \
  "reusable workflow exposes optional Linear secret"
assert_eq "$(jq -r '.jobs.detect.steps[] | select(.id=="woo") | .with["linear-api-key"]' "$workflow")" \
  '${{ secrets.linear_api_key }}' "detect action alone receives the Linear secret as an action input"
assert_eq "$(jq -r '.jobs.detect.steps[] | select(.uses | strings | contains("actions/checkout")) | .with.ref' "$workflow")" \
  '${{ github.event.pull_request.head.sha || format('"'"'refs/pull/{0}/head'"'"', github.event.issue.number) }}' \
  "detect checks out the immutable PR head for pull-request and trusted comment runs"
for step in \
  'review:review1' \
  'review:Run angle review (retry once)' \
  'validate:Validate (prosecutor pass)' \
  'validate:Validate (defender pass + intersect + post)'; do
  job="${step%%:*}"
  selector="${step#*:}"
  value="$(jq -r --arg job "$job" --arg selector "$selector" '
    .jobs[$job].steps[] |
    select((.id // "") == $selector or (.name // "") == $selector) |
    .with["linear-api-key"] // "absent"
  ' "$workflow")"
  assert_eq "$value" 'absent' "$job/$selector consumes uploaded context without the Linear secret"
done

assert_eq "$(jq '[.jobs.review.steps[], .jobs.validate.steps[] | select(.name=="Decrypt remote artifact context")] | length' "$workflow")" \
  '2' "every downloaded base artifact is decrypted only inside its trusted consumer job"
assert_eq "$(jq '[.jobs.review.steps[], .jobs.validate.steps[] | select(.name=="Decrypt remote artifact context") | .env.INPUT_LINEAR_API_KEY == "${{ secrets.linear_api_key }}"] | all' "$workflow")" \
  'true' "decrypt steps receive the Linear secret without exposing it to provider actions"

seal="$TMP/seal.sh"
open="$TMP/open.sh"
jq -r '.jobs.detect.steps[] | select(.name=="Encrypt remote artifact context") | .run' "$workflow" >"$seal"
jq -r '.jobs.review.steps[] | select(.name=="Decrypt remote artifact context") | .run' "$workflow" >"$open"

sealed_out="$TMP/sealed"
mkdir -p "$sealed_out"
printf '%s\n' '{"backend":"linear","spec":{"content":"private Linear content"}}' \
  >"$sealed_out/artifact-context.json"
OUTDIR="$sealed_out" INPUT_LINEAR_API_KEY='test-encryption-key' bash "$seal"
[ ! -e "$sealed_out/artifact-context.json" ] && pass || fail "Linear plaintext is removed before artifact upload"
[ -s "$sealed_out/artifact-context.json.enc" ] && pass || fail "Linear context is uploaded only as ciphertext"
if grep -aq 'private Linear content' "$sealed_out/artifact-context.json.enc"; then
  fail "encrypted workflow artifact exposes remote Linear content"
else
  pass
fi

cp -R "$sealed_out" "$TMP/wrong-key"
set +e
OUTPUT="$(OUTDIR="$TMP/wrong-key" INPUT_LINEAR_API_KEY='wrong-key' bash "$open" 2>&1)"
RC=$?
set -e
assert_exit 1 "$RC" "wrong context key fails closed"
[ ! -e "$TMP/wrong-key/artifact-context.json" ] && pass || fail "failed decryption leaves no plaintext context"

OUTDIR="$sealed_out" INPUT_LINEAR_API_KEY='test-encryption-key' bash "$open"
assert_eq "$(jq -r '.spec.content' "$sealed_out/artifact-context.json")" \
  'private Linear content' "trusted review job restores the exact Linear context"
assert_eq "$(file_mode "$sealed_out/artifact-context.json")" '600' \
  "restored Linear context is private before consumers can read it"
[ ! -e "$sealed_out/artifact-context.json.enc" ] && pass || fail "trusted job removes ciphertext after restoration"

markdown_out="$TMP/markdown"
mkdir -p "$markdown_out"
printf '%s\n' '{"backend":"markdown","spec":{"content":"local"}}' >"$markdown_out/artifact-context.json"
OUTDIR="$markdown_out" INPUT_LINEAR_API_KEY='' bash "$seal"
[ -s "$markdown_out/artifact-context.json" ] && pass || fail "Markdown context remains available without a Linear key"
[ ! -e "$markdown_out/artifact-context.json.enc" ] && pass || fail "Markdown context is not unnecessarily encrypted"

assert_eq "$(jq -r '.jobs.detect.steps[] | select(.uses | strings | contains("upload-artifact")) | .with["retention-days"]' "$workflow")" \
  '1' "base artifact context retention is bounded to one day"
assert_eq "$(jq -r '.jobs.detect.steps[] | select(.uses | strings | contains("upload-artifact")) | .with.path' "$workflow")" \
  '/tmp/pr-review/' "base artifact upload carries encrypted remote or ordinary local context downstream"
assert_eq "$(jq -r '.jobs.detect.steps[] | select(.uses | strings | contains("upload-artifact")) | .with["include-hidden-files"]' "$workflow")" \
  'true' "base artifact upload preserves tracked dotfiles from package snapshots"

for job in detect review validate; do
  cleanup="$(jq -c --arg job "$job" '.jobs[$job].steps[-1] | {name,if,run}' "$workflow")"
  assert_contains "$cleanup" 'Remove local' "$job ends with local artifact cleanup"
  assert_contains "$cleanup" 'always()' "$job cleanup runs on every outcome"
  assert_contains "$cleanup" 'rm -rf /tmp/pr-review' "$job cleanup removes sensitive local context"
done

finish
