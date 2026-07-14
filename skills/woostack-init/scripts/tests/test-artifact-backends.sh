#!/usr/bin/env bash
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$TEST_DIR/../artifacts/resolve-backend.sh"
MARKDOWN="$TEST_DIR/../artifacts/markdown.sh"
TEMPLATE="$TEST_DIR/../../templates/config.json"
# shellcheck disable=SC1091
source "$TEST_DIR/assert.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

make_repo() {
  local name="$1"
  local repo="$TMP/$name"
  mkdir -p "$repo/.woostack"
  git -C "$repo" init -q
  printf '%s\n' "$repo"
}

write_config() {
  local repo="$1"
  local config="$2"
  printf '%s\n' "$config" > "$repo/.woostack/config.json"
}

complete_linear_config() {
  local repository="${1:-}"
  jq -cn --arg repository "$repository" '
    {
      artifacts: {specPlan: "linear"},
      linear: ({
        workspace: "acme",
        team: "ENG",
        projectStatuses: {
          draft: "Draft",
          hardened: "Hardened",
          approved: "Approved",
          planning: "Planning",
          ready: "Ready",
          executing: "In Progress",
          inReview: "In Review",
          done: "Completed",
          abandoned: "Canceled"
        },
        issueStates: {
          planned: "Backlog",
          executing: "In Progress",
          inReview: "In Review",
          done: "Done",
          blocked: "Blocked"
        }
      } + if $repository == "" then {} else {repository: $repository} end)
    }'
}

run_failure() {
  local repo="$1"
  local output
  if output="$(bash "$SCRIPT" "$repo" 2>&1)"; then
    fail "resolver should reject invalid config"
    RUN_FAILURE_OUTPUT="$output"
    return
  fi
  pass
  RUN_FAILURE_OUTPUT="$output"
}

repo="$(make_repo missing-config)"
actual="$(bash "$SCRIPT" "$repo")"
assert_eq "$actual" '{"backend":"markdown","repository":null,"linear":null}' "absent config defaults to Markdown"

repo="$(make_repo default-markdown)"
write_config "$repo" '{}'
actual="$(bash "$SCRIPT" "$repo")"
assert_eq "$actual" '{"backend":"markdown","repository":null,"linear":null}' "missing selector defaults to Markdown"

repo="$(make_repo explicit-markdown)"
write_config "$repo" '{"artifacts":{"specPlan":"markdown"}}'
actual="$(bash "$SCRIPT" "$repo")"
assert_eq "$actual" '{"backend":"markdown","repository":null,"linear":null}' "explicit Markdown resolves without Linear config"

repo="$(make_repo markdown-secret)"
secret_value='DO-NOT-LEAK-MARKDOWN'
write_config "$repo" "$(jq -cn --arg value "$secret_value" '{artifacts:{specPlan:"markdown"},linear:{nested:{apiKey:$value}}}')"
run_failure "$repo"
assert_contains "$RUN_FAILURE_OUTPUT" 'linear.nested.apiKey' "Markdown mode still rejects Linear credential keys"
assert_not_contains "$RUN_FAILURE_OUTPUT" "$secret_value" "Markdown credential diagnostic does not leak its value"

repo="$(make_repo linear-override)"
git -C "$repo" remote add origin https://github.com/ignored/by-override.git
config="$(complete_linear_config acme/widgets)"
write_config "$repo" "$config"
actual="$(bash "$SCRIPT" "$repo")"
expected="$(jq -c '{backend:"linear",repository:.linear.repository,linear:(.linear | del(.repository))}' <<<"$config")"
assert_eq "$actual" "$expected" "explicit repository identity takes precedence over GitHub origin"

repo="$(make_repo linear-github-https)"
git -C "$repo" remote add origin https://github.com/example/remote-repo.git
config="$(complete_linear_config)"
write_config "$repo" "$config"
actual="$(bash "$SCRIPT" "$repo")"
assert_eq "$(jq -r '.repository' <<<"$actual")" 'example/remote-repo' "HTTPS GitHub origin supplies repository identity"

repo="$(make_repo linear-github-ssh)"
git -C "$repo" remote add origin git@github.com:example/ssh-repo.git
write_config "$repo" "$config"
actual="$(bash "$SCRIPT" "$repo")"
assert_eq "$(jq -r '.repository' <<<"$actual")" 'example/ssh-repo' "SSH GitHub origin supplies repository identity"

repo="$(make_repo linear-github-ssh-url)"
git -C "$repo" remote add origin ssh://git@github.com/example/ssh-url-repo.git
write_config "$repo" "$config"
actual="$(bash "$SCRIPT" "$repo")"
assert_eq "$(jq -r '.repository' <<<"$actual")" 'example/ssh-url-repo' "SSH URL GitHub origin supplies repository identity"

repo="$(make_repo linear-github-git-url)"
git -C "$repo" remote add origin git://github.com/example/git-url-repo.git
write_config "$repo" "$config"
actual="$(bash "$SCRIPT" "$repo")"
assert_eq "$(jq -r '.repository' <<<"$actual")" 'example/git-url-repo' "git URL GitHub origin supplies repository identity"

repo="$(make_repo invalid-selector)"
write_config "$repo" '{"artifacts":{"specPlan":"database"}}'
run_failure "$repo"
assert_contains "$RUN_FAILURE_OUTPUT" 'artifacts.specPlan' "unsupported selector diagnostic names config path"
assert_not_contains "$RUN_FAILURE_OUTPUT" 'database' "unsupported selector diagnostic does not echo config value"

repo="$(make_repo invalid-json)"
write_config "$repo" '{"artifacts":'
run_failure "$repo"
assert_contains "$RUN_FAILURE_OUTPUT" '.woostack/config.json' "malformed JSON diagnostic names only the config path"
assert_not_contains "$RUN_FAILURE_OUTPUT" '{"artifacts":' "malformed JSON diagnostic does not echo config content"

repo="$(make_repo invalid-artifacts-shape)"
write_config "$repo" '{"artifacts":"not-an-object"}'
run_failure "$repo"
assert_contains "$RUN_FAILURE_OUTPUT" 'artifacts' "invalid artifacts object is diagnosed by path"
assert_not_contains "$RUN_FAILURE_OUTPUT" 'not-an-object' "invalid artifacts diagnostic does not echo config value"

for required_path in linear.workspace linear.team; do
  repo="$(make_repo "missing-${required_path#linear.}")"
  config="$(complete_linear_config acme/widgets)"
  config="$(jq -c "del(.$required_path)" <<<"$config")"
  write_config "$repo" "$config"
  run_failure "$repo"
  assert_contains "$RUN_FAILURE_OUTPUT" "$required_path" "missing $required_path is diagnosed"
done

assert_invalid_required_value() {
  local path="$1"
  local value="$2"
  local label="$3"
  repo="$(make_repo "invalid-required-$label")"
  config="$(complete_linear_config acme/widgets)"
  config="$(jq -c --arg path "$path" --argjson value "$value" 'setpath($path | split("."); $value)' <<<"$config")"
  write_config "$repo" "$config"
  run_failure "$repo"
  assert_contains "$RUN_FAILURE_OUTPUT" "$path" "$label required-string value is rejected by path"
}

assert_invalid_required_value linear.workspace '123' workspace-number
assert_invalid_required_value linear.workspace '""' workspace-empty
assert_invalid_required_value linear.workspace '"   "' workspace-whitespace
assert_invalid_required_value linear.team '{}' team-object
assert_invalid_required_value linear.team '[]' team-array
assert_invalid_required_value linear.team '"\t"' team-whitespace
assert_invalid_required_value linear.projectStatuses.draft '""' project-status-empty
assert_invalid_required_value linear.projectStatuses.draft '"  "' project-status-whitespace
assert_invalid_required_value linear.issueStates.blocked 'null' issue-state-null
assert_invalid_required_value linear.issueStates.blocked '{}' issue-state-object

for mapping in draft hardened approved planning ready executing inReview "done" abandoned; do
  repo="$(make_repo "missing-project-$mapping")"
  config="$(complete_linear_config acme/widgets)"
  config="$(jq -c --arg mapping "$mapping" 'del(.linear.projectStatuses[$mapping])' <<<"$config")"
  write_config "$repo" "$config"
  run_failure "$repo"
  assert_contains "$RUN_FAILURE_OUTPUT" "linear.projectStatuses.$mapping" "missing project status $mapping is diagnosed"
done

for mapping in planned executing inReview "done" blocked; do
  repo="$(make_repo "missing-issue-$mapping")"
  config="$(complete_linear_config acme/widgets)"
  config="$(jq -c --arg mapping "$mapping" 'del(.linear.issueStates[$mapping])' <<<"$config")"
  write_config "$repo" "$config"
  run_failure "$repo"
  assert_contains "$RUN_FAILURE_OUTPUT" "linear.issueStates.$mapping" "missing issue state $mapping is diagnosed"
done

repo="$(make_repo missing-repository)"
write_config "$repo" "$(complete_linear_config)"
run_failure "$repo"
assert_contains "$RUN_FAILURE_OUTPUT" 'linear.repository' "repository override is required without a GitHub origin"

for invalid_repository in '123' '{}' '[]' '""' '"   "' '"../repo"' '"acme/.."' '"https:/github.com"' '"acme/repo/extra"'; do
  repo="$(make_repo "invalid-repository-$PASS-$FAIL")"
  git -C "$repo" remote add origin https://github.com/fallback/must-not-be-used.git
  config="$(complete_linear_config)"
  config="$(jq -c --argjson repository "$invalid_repository" '.linear.repository = $repository' <<<"$config")"
  write_config "$repo" "$config"
  run_failure "$repo"
  assert_contains "$RUN_FAILURE_OUTPUT" 'linear.repository' "invalid explicit repository is rejected instead of falling back"
  assert_not_contains "$RUN_FAILURE_OUTPUT" 'must-not-be-used' "repository diagnostic does not expose or select fallback remote"
done

repo="$(make_repo unknown-linear-key)"
config="$(complete_linear_config acme/widgets)"
unknown_value='DO-NOT-LEAK-UNKNOWN'
config="$(jq -c --arg value "$unknown_value" '.linear.auth = $value' <<<"$config")"
write_config "$repo" "$config"
run_failure "$repo"
assert_contains "$RUN_FAILURE_OUTPUT" 'linear.auth' "unknown Linear keys are rejected by path"
assert_not_contains "$RUN_FAILURE_OUTPUT" "$unknown_value" "unknown-key diagnostic does not leak its value"

secret_keys=(
  apiKey
  API_KEY
  api_token
  token
  access-token
  personal-token
  Personal_Access_Token
  privateKey
  accessKey
  credentialFile
  credentials_path
  Authorization
  authorization_header
  dbPassword
  passwordHash
  clientSecret
  secretKey
)
secret_index=0
for secret_key in "${secret_keys[@]}"; do
  repo="$(make_repo "secret-$secret_index")"
  config="$(complete_linear_config acme/widgets)"
  secret_value="DO-NOT-LEAK-$secret_index"
  config="$(jq -c --arg key "$secret_key" --arg value "$secret_value" '.linear.nested = [{safe: true}, {($key): $value}]' <<<"$config")"
  write_config "$repo" "$config"
  run_failure "$repo"
  assert_contains "$RUN_FAILURE_OUTPUT" "$secret_key" "recursive credential-key rejection names only its path"
  assert_not_contains "$RUN_FAILURE_OUTPUT" "$secret_value" "credential-key diagnostic does not leak its value"
  secret_index=$((secret_index + 1))
done

assert_eq "$(jq -c '.artifacts' "$TEMPLATE")" '{"specPlan":"markdown"}' "config template selects Markdown by default"
assert_eq "$(jq -r '[paths(scalars) as $p | ($p[-1] | tostring | ascii_downcase | gsub("[^a-z0-9]"; "")) | select(test("(apikey|token|credentials?(file|path)|authorization|password|secret|privatekey|accesskey)"))] | length' "$TEMPLATE")" '0' "config template contains no credential placeholders"

write_feature_pair() {
  local repo="$1"
  local basename="$2"
  local source_line="$3"
  mkdir -p "$repo/.woostack/specs" "$repo/.woostack/plans"
  cat > "$repo/.woostack/specs/$basename.md" <<EOF
---
name: ${basename#????-??-??-}
type: spec
status: approved
date: 2026-07-12
branch: feature/${basename#????-??-??-}
---

# Adapter spec

Spec body.
EOF
  cat > "$repo/.woostack/plans/$basename.md" <<EOF
---
type: plan
source: .woostack/specs/$basename.md
status: executing
branch: feature/${basename#????-??-??-}
---

# Adapter plan

$source_line

## Increment 2 - Second

  - [x] completed task
    - [ ] pending task

## Increment 1 (stacked follow-up): First

- [x] completed task
- [x] completed follow-up

\`\`\`\`markdown
## Increment 99: fenced heading
- [ ] fenced checkbox
\`\`\`text
- [ ] nested fenced checkbox
\`\`\`
\`\`\`\`

~~~markdown
## Increment 98: tilde-fenced heading
- [ ] tilde-fenced checkbox
~~~~

## Increment 3: Third

    - [ ] pending task

## Increment 4: Partial plan at EOF

Work remains to be decomposed.
EOF
}

run_markdown_failure() {
  local spec="$1"
  local output
  if output="$(bash "$MARKDOWN" feature "$spec" 2>&1)"; then
    fail "Markdown adapter should reject invalid artifact join"
    MARKDOWN_FAILURE_OUTPUT="$output"
    return
  fi
  pass
  MARKDOWN_FAILURE_OUTPUT="$output"
}

repo="$(make_repo markdown-canonical)"
basename='2026-07-12-feature.v2+api_core'
write_feature_pair "$repo" "$basename" "**Source:** [[specs/$basename]]"
spec_path="$repo/.woostack/specs/$basename.md"
spec_before="$(shasum -a 256 "$spec_path" | cut -d ' ' -f 1)"
plan_before="$(shasum -a 256 "$repo/.woostack/plans/$basename.md" | cut -d ' ' -f 1)"
actual="$(bash "$MARKDOWN" feature "$spec_path")"
assert_eq "$(jq -c 'keys' <<<"$actual")" '["backend","feature","increments","spec"]' "Markdown model has deterministic top-level fields"
assert_eq "$(jq -c '.backend' <<<"$actual")" '"markdown"' "Markdown model identifies its backend"
assert_eq "$(jq -c '.feature | {id,url,title,status,branch}' <<<"$actual")" \
  "$(jq -cn --arg id ".woostack/specs/$basename.md" --arg title 'feature.v2+api_core' --arg branch 'feature/feature.v2+api_core' '{id:$id,url:null,title:$title,status:"executing",branch:$branch}')" \
  "canonical wikilink preserves feature identity, lifecycle status, and branch"
assert_eq "$(jq -c '.spec | {id,url,content:(.content | contains("Spec body."))}' <<<"$actual")" \
  "$(jq -cn --arg id ".woostack/specs/$basename.md" '{id:$id,url:null,content:true}')" \
  "spec content is normalized"
assert_eq "$(jq -r '.spec.revision' <<<"$actual")" "$spec_before" "spec revision is the deterministic content digest"
assert_eq "$(jq -c '[.increments[] | keys]' <<<"$actual")" \
  '[["branch","content","dependencies","id","identifier","ordinal","pullRequest","status"],["branch","content","dependencies","id","identifier","ordinal","pullRequest","status"],["branch","content","dependencies","id","identifier","ordinal","pullRequest","status"],["branch","content","dependencies","id","identifier","ordinal","pullRequest","status"]]' \
  "every increment exposes the complete normalized contract"
assert_eq "$(jq -c '[.increments[] | {id,identifier,ordinal,status,dependencies,branch,pullRequest}]' <<<"$actual")" \
  "$(jq -cn --arg plan ".woostack/plans/$basename.md" '[
    {id:($plan + "#increment-1"),identifier:null,ordinal:1,status:"done",dependencies:[],branch:null,pullRequest:null},
    {id:($plan + "#increment-2"),identifier:null,ordinal:2,status:"executing",dependencies:[],branch:null,pullRequest:null},
    {id:($plan + "#increment-3"),identifier:null,ordinal:3,status:"planned",dependencies:[],branch:null,pullRequest:null},
    {id:($plan + "#increment-4"),identifier:null,ordinal:4,status:"planned",dependencies:[],branch:null,pullRequest:null}
  ]')" \
  "out-of-order plan sections have deterministic IDs and checkbox-derived statuses"
assert_eq "$(jq -c '[
  (.increments[0].content | contains("completed follow-up") and contains("tilde-fenced heading") and (contains("Second") | not)),
  (.increments[1].content | contains("completed task") and (contains("First") | not)),
  (.increments[2].content | contains("pending task") and (contains("Partial plan") | not)),
  (.increments[3].content == "Work remains to be decomposed.")
]' <<<"$actual")" '[true,true,true,true]' "increment content preserves each section boundary"
assert_eq "$(shasum -a 256 "$spec_path" | cut -d ' ' -f 1)" "$spec_before" "adapter does not rewrite the spec"
assert_eq "$(shasum -a 256 "$repo/.woostack/plans/$basename.md" | cut -d ' ' -f 1)" "$plan_before" "adapter does not rewrite the plan"
printf '\nChanged spec body.\n' >> "$spec_path"
changed_spec_revision="$(shasum -a 256 "$spec_path" | cut -d ' ' -f 1)"
changed_actual="$(bash "$MARKDOWN" feature "$spec_path")"
assert_eq "$(jq -r '.spec.revision' <<<"$changed_actual")" "$changed_spec_revision" "spec revision changes with content"

repo="$(make_repo markdown-legacy)"
basename='2026-07-12-legacy.feature-test'
write_feature_pair "$repo" "$basename" "**Source:** .woostack/specs/$basename.md"
cat > "$repo/.woostack/plans/unrelated-example.md" <<EOF
---
type: plan
status: planning
branch: feature/unrelated
---

# Documentation example

\`\`\`\`markdown
**Source:** .woostack/specs/$basename.md
## Increment 99: Example
- [ ] example only
\`\`\`
\`\`\`\`
EOF

actual="$(bash "$MARKDOWN" feature "$repo/.woostack/specs/$basename.md")"
assert_eq "$(jq -r '.feature.id' <<<"$actual")" ".woostack/specs/$basename.md" "legacy source line resolves the plan"
assert_eq "$(jq -r '.increments | length' <<<"$actual")" '4' "legacy plan emits every increment including a partial final section"
assert_eq "$(jq -r '.increments | map(.ordinal) | join(",")' <<<"$actual")" '1,2,3,4' "fenced example headings are ignored"

repo="$(make_repo markdown-annotated-source)"
basename='2026-07-12-annotated-source'
write_feature_pair "$repo" "$basename" "**Source:** [[specs/$basename]] (stacked feature)"
mv "$repo/.woostack/plans/$basename.md" "$repo/.woostack/plans/different-plan-name.md"
actual="$(bash "$MARKDOWN" feature "$repo/.woostack/specs/$basename.md")"
assert_eq "$(jq -r '.feature.id' <<<"$actual")" ".woostack/specs/$basename.md" "annotated canonical source resolves a differently named plan"

repo="$(make_repo markdown-canonical-md)"
basename='2026-07-12-canonical-md'
write_feature_pair "$repo" "$basename" "**Source:** [[specs/$basename.md]]"
mv "$repo/.woostack/plans/$basename.md" "$repo/.woostack/plans/different-md-plan-name.md"
actual="$(bash "$MARKDOWN" feature "$repo/.woostack/specs/$basename.md")"
assert_eq "$(jq -r '.feature.id' <<<"$actual")" ".woostack/specs/$basename.md" "optional .md wikilink resolves a differently named plan"

repo="$(make_repo markdown-basename-fallback)"
basename='2026-07-12-basename-fallback'
write_feature_pair "$repo" "$basename" ""
actual="$(bash "$MARKDOWN" feature "$repo/.woostack/specs/$basename.md")"
assert_eq "$(jq -r '.feature.id' <<<"$actual")" ".woostack/specs/$basename.md" "same-basename plan resolves without a Source line"

repo="$(make_repo markdown-slug-fallback)"
basename='2026-07-12-slug-fallback'
write_feature_pair "$repo" "$basename" ""
mv "$repo/.woostack/plans/$basename.md" "$repo/.woostack/plans/2026-07-13-slug-fallback.md"
actual="$(bash "$MARKDOWN" feature "$repo/.woostack/specs/$basename.md")"
assert_eq "$(jq -r '.feature.id' <<<"$actual")" ".woostack/specs/$basename.md" "date-stripped slug fallback preserves legacy joins"

repo="$(make_repo markdown-slug-fallback-owned)"
write_feature_pair "$repo" '2026-07-13-owned-slug' '**Source:** [[specs/2026-07-13-owned-slug]]'
cp "$repo/.woostack/specs/2026-07-13-owned-slug.md" "$repo/.woostack/specs/2026-07-12-owned-slug.md"
run_markdown_failure "$repo/.woostack/specs/2026-07-12-owned-slug.md"
assert_contains "$MARKDOWN_FAILURE_OUTPUT" 'matching plan not found' "slug fallback excludes plans explicitly owned by another spec"

repo="$(make_repo markdown-large-plan)"
basename='2026-07-12-large-plan'
write_feature_pair "$repo" "$basename" "**Source:** [[specs/$basename]]"
awk 'BEGIN { for (i=0; i<20000; i++) print "Large trailing body line " i }' >> "$repo/.woostack/plans/$basename.md"
actual="$(bash "$MARKDOWN" feature "$repo/.woostack/specs/$basename.md")"
assert_eq "$(jq -r '.increments | length' <<<"$actual")" '4' "large valid plans resolve without a pipefail SIGPIPE"

repo="$(make_repo markdown-missing)"
mkdir -p "$repo/.woostack/specs" "$repo/.woostack/plans"
printf '%s\n' '---' 'name: orphan' 'type: spec' 'status: approved' 'branch: feature/orphan' '---' '# Orphan' > "$repo/.woostack/specs/2026-07-12-orphan.md"
run_markdown_failure "$repo/.woostack/specs/2026-07-12-orphan.md"
assert_contains "$MARKDOWN_FAILURE_OUTPUT" 'plan' "missing plan join is diagnosed"

repo="$(make_repo markdown-duplicate)"
write_feature_pair "$repo" '2026-07-12-duplicate' '**Source:** [[specs/2026-07-12-duplicate]]'
cp "$repo/.woostack/plans/2026-07-12-duplicate.md" "$repo/.woostack/plans/another-plan.md"
run_markdown_failure "$repo/.woostack/specs/2026-07-12-duplicate.md"
assert_contains "$MARKDOWN_FAILURE_OUTPUT" 'multiple' "duplicate plan joins are rejected"

repo="$(make_repo markdown-malformed)"
mkdir -p "$repo/.woostack/specs"
printf '%s\n' 'name: malformed' '# no frontmatter' > "$repo/.woostack/specs/2026-07-12-malformed.md"
run_markdown_failure "$repo/.woostack/specs/2026-07-12-malformed.md"
assert_contains "$MARKDOWN_FAILURE_OUTPUT" 'frontmatter' "malformed spec frontmatter is rejected"

repo="$(make_repo markdown-unterminated-spec)"
mkdir -p "$repo/.woostack/specs"
printf '%s\n' '---' 'name: unterminated' 'type: spec' 'status: approved' '# no closing fence' > "$repo/.woostack/specs/2026-07-12-unterminated.md"
run_markdown_failure "$repo/.woostack/specs/2026-07-12-unterminated.md"
assert_contains "$MARKDOWN_FAILURE_OUTPUT" 'frontmatter' "unterminated spec frontmatter is rejected"

repo="$(make_repo markdown-malformed-plan)"
write_feature_pair "$repo" '2026-07-12-malformed-plan' '**Source:** [[specs/2026-07-12-malformed-plan]]'
printf '%s\n' '**Source:** [[specs/2026-07-12-malformed-plan]]' '# no frontmatter' > "$repo/.woostack/plans/2026-07-12-malformed-plan.md"
run_markdown_failure "$repo/.woostack/specs/2026-07-12-malformed-plan.md"
assert_contains "$MARKDOWN_FAILURE_OUTPUT" 'frontmatter' "joined plan without frontmatter is rejected"

repo="$(make_repo markdown-unterminated-plan)"
write_feature_pair "$repo" '2026-07-12-unterminated-plan' '**Source:** [[specs/2026-07-12-unterminated-plan]]'
printf '%s\n' '---' 'type: plan' 'status: planning' '**Source:** [[specs/2026-07-12-unterminated-plan]]' '# no closing fence' > "$repo/.woostack/plans/2026-07-12-unterminated-plan.md"
run_markdown_failure "$repo/.woostack/specs/2026-07-12-unterminated-plan.md"
assert_contains "$MARKDOWN_FAILURE_OUTPUT" 'frontmatter' "unterminated joined-plan frontmatter is rejected"

repo="$(make_repo markdown-duplicate-ordinal)"
write_feature_pair "$repo" '2026-07-12-duplicate-ordinal' '**Source:** [[specs/2026-07-12-duplicate-ordinal]]'
cat >> "$repo/.woostack/plans/2026-07-12-duplicate-ordinal.md" <<'EOF'

## Increment 2: Duplicate

- [ ] duplicate ordinal
EOF
run_markdown_failure "$repo/.woostack/specs/2026-07-12-duplicate-ordinal.md"
assert_contains "$MARKDOWN_FAILURE_OUTPUT" 'increments' "duplicate increment ordinals fail normalization"

repo="$(make_repo markdown-headingless)"
basename='2026-07-12-headingless'
write_feature_pair "$repo" "$basename" "**Source:** [[specs/$basename]]"
cat > "$repo/.woostack/plans/$basename.md" <<EOF
---
type: plan
status: executing
branch: feature/headingless
---

# Legacy plan

**Source:** [[specs/$basename]]

- [x] completed legacy task
- [ ] pending legacy task
EOF
actual="$(bash "$MARKDOWN" feature "$repo/.woostack/specs/$basename.md")"
assert_eq "$(jq -c '.increments | map({ordinal,status,content:(.content | contains("Legacy plan") and contains("pending legacy task"))})' <<<"$actual")" \
  '[{"ordinal":1,"status":"executing","content":true}]' "headingless legacy plan becomes one checkbox-derived increment"

repo="$(make_repo markdown-spec-symlink)"
mkdir -p "$repo/.woostack/specs" "$repo/.woostack/plans" "$repo/outside"
printf '%s\n' '---' 'name: escaped' 'type: spec' 'status: approved' '---' '# escaped' > "$repo/outside/escaped.md"
ln -s "$repo/outside/escaped.md" "$repo/.woostack/specs/2026-07-12-escaped.md"
run_markdown_failure "$repo/.woostack/specs/2026-07-12-escaped.md"
assert_contains "$MARKDOWN_FAILURE_OUTPUT" 'symlink' "spec symlink escapes are rejected"

repo="$(make_repo markdown-directory-symlink)"
outside_repo="$(make_repo markdown-directory-target)"
write_feature_pair "$outside_repo" '2026-07-12-directory-link' '**Source:** [[specs/2026-07-12-directory-link]]'
ln -s "$outside_repo/.woostack/specs" "$repo/.woostack/specs"
run_markdown_failure "$repo/.woostack/specs/2026-07-12-directory-link.md"
assert_contains "$MARKDOWN_FAILURE_OUTPUT" 'symlink' "spec directory symlink escapes are rejected"

repo="$(make_repo markdown-plan-directory-symlink)"
outside_repo="$(make_repo markdown-plan-directory-target)"
write_feature_pair "$repo" '2026-07-12-plan-directory-link' '**Source:** [[specs/2026-07-12-plan-directory-link]]'
write_feature_pair "$outside_repo" '2026-07-12-plan-directory-link' '**Source:** [[specs/2026-07-12-plan-directory-link]]'
rm -rf "$repo/.woostack/plans"
ln -s "$outside_repo/.woostack/plans" "$repo/.woostack/plans"
run_markdown_failure "$repo/.woostack/specs/2026-07-12-plan-directory-link.md"
assert_contains "$MARKDOWN_FAILURE_OUTPUT" 'symlink' "plan directory symlink escapes are rejected"

repo="$(make_repo markdown-plan-symlink)"
write_feature_pair "$repo" '2026-07-12-plan-link' '**Source:** [[specs/2026-07-12-plan-link]]'
mv "$repo/.woostack/plans/2026-07-12-plan-link.md" "$repo/outside-plan.md"
ln -s "$repo/outside-plan.md" "$repo/.woostack/plans/2026-07-12-plan-link.md"
run_markdown_failure "$repo/.woostack/specs/2026-07-12-plan-link.md"
assert_contains "$MARKDOWN_FAILURE_OUTPUT" 'symlink' "plan symlink escapes are rejected"

finish
