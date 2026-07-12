#!/usr/bin/env bash
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$TEST_DIR/../artifacts/linear-request.sh"
DOCUMENT="$TEST_DIR/../artifacts/graphql/preflight.graphql"
PREFLIGHT="$TEST_DIR/../artifacts/linear-preflight.sh"
FIXTURES="$TEST_DIR/fixtures/linear"
# shellcheck disable=SC1091
source "$TEST_DIR/assert.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/state"

cat > "$TMP/bin/curl" <<'FAKE_CURL'
#!/usr/bin/env bash
set -u
state="${FAKE_CURL_STATE:?}"
count=0
[ ! -f "$state/count" ] || count="$(cat "$state/count")"
count=$((count + 1))
printf '%s\n' "$count" > "$state/count"
if [ -n "${LINEAR_API_KEY:-}" ]; then
  : > "$state/env-secret-$count"
fi

output=''
headers=''
previous=''
: > "$state/args-$count"
: > "$state/request-headers-$count"
for arg in "$@"; do
  printf '%s\n' "$arg" >> "$state/args-$count"
  case "$previous" in
    --output) output="$arg" ;;
    --data-binary)
      case "$arg" in
        @*) cp "${arg#@}" "$state/request-body-$count" ;;
      esac
      ;;
    --dump-header) headers="$arg" ;;
    --header)
      case "$arg" in
        @*) cat "${arg#@}" >> "$state/request-headers-$count" ;;
        *) printf '%s\n' "$arg" >> "$state/request-headers-$count" ;;
      esac
      ;;
  esac
  previous="$arg"
done

prefix="$state/response-$count"
[ -f "$prefix.status" ] || prefix="$state/response-default"
[ -z "$output" ] || cp "$prefix.body" "$output"
[ -z "$headers" ] || cp "$prefix.headers" "$headers"
exit_code="$(cat "$prefix.exit")"
[ "$exit_code" -eq 0 ] || exit "$exit_code"
printf '%s' "$(cat "$prefix.status")"
FAKE_CURL
chmod +x "$TMP/bin/curl"

export PATH="$TMP/bin:$PATH"
export FAKE_CURL_STATE="$TMP/state"
export LINEAR_RETRY_DELAY_SECONDS=0
SECRET='lin_api_SECRET-value-[42]'
printf '%s\n' 'mutation TransportMutation { __typename }' > "$TMP/mutation.graphql"
printf '%s\n' 'query FirstOperation { __typename } mutation SecondOperation { __typename }' > "$TMP/multiple-operations.graphql"
cat > "$TMP/adversarial-mutation.graphql" <<'GRAPHQL'
# query Fake { __typename }
mutation# a comment may directly follow a name token
RealMutation { __typename }
GRAPHQL
cat > "$TMP/string-and-comment-keywords.graphql" <<'GRAPHQL'
# mutation FakeMutation { __typename }
fragment query on User { id }
query RealQuery {
  echo(value: "mutation StringFake { __typename }")
  block(value: """query BlockFake { __typename }""")
}
GRAPHQL
printf '%s\n' '{ viewer { id } }' > "$TMP/shorthand-query.graphql"

reset_queue() {
  rm -f "$TMP/state"/*
}

queue_response() {
  local attempt="$1"
  local status="$2"
  local body="$3"
  local headers="${4:-}"
  local exit_code="${5:-0}"
  printf '%s\n' "$status" > "$TMP/state/response-$attempt.status"
  cp "$body" "$TMP/state/response-$attempt.body"
  printf '%s' "$headers" > "$TMP/state/response-$attempt.headers"
  printf '%s\n' "$exit_code" > "$TMP/state/response-$attempt.exit"
}

run_request() {
  local operation="$1"
  local document="${2:-$DOCUMENT}"
  local variables='{}'
  [ "$#" -lt 3 ] || variables="$3"
  local key="${4-$SECRET}"
  : > "$TMP/stdout"
  : > "$TMP/stderr"
  set +e
  LINEAR_API_KEY="$key" bash "$SCRIPT" --operation "$operation" --document "$document" --variables "$variables" >"$TMP/stdout" 2>"$TMP/stderr"
  RUN_RC=$?
  set -e
  RUN_STDOUT="$(cat "$TMP/stdout")"
  RUN_STDERR="$(cat "$TMP/stderr")"
  RUN_ATTEMPTS=0
  [ ! -f "$TMP/state/count" ] || RUN_ATTEMPTS="$(cat "$TMP/state/count")"
}

assert_secret_safe() {
  local label="$1"
  assert_not_contains "$RUN_STDOUT" "$SECRET" "$label stdout redacts API key"
  assert_not_contains "$RUN_STDERR" "$SECRET" "$label stderr redacts API key"
  assert_not_contains "$RUN_STDOUT$RUN_STDERR" 'Authorization:' "$label output omits authorization header"
}

# Missing credentials fail before curl.
reset_queue
run_request query "$DOCUMENT" '{}' ''
assert_exit 1 "$RUN_RC" "missing LINEAR_API_KEY is rejected"
assert_contains "$RUN_STDERR" 'missing_credentials' "missing credential is classified"
assert_eq "$RUN_ATTEMPTS" '0' "missing credential makes no HTTP request"

reset_queue
injected_key=$'line-one\nInjected: header'
run_request query "$DOCUMENT" '{}' "$injected_key"
assert_exit 1 "$RUN_RC" "credential containing a newline is rejected"
assert_contains "$RUN_STDERR" 'invalid_credentials' "header-injection credential is classified"
assert_not_contains "$RUN_STDERR" 'line-one' "invalid credential value is not printed"
assert_eq "$RUN_ATTEMPTS" '0' "invalid credential makes no HTTP request"

# A successful response is emitted as one canonical JSON object and the request is POSTed safely.
reset_queue
queue_response 1 200 "$FIXTURES/http-success.json" $'HTTP/2 200\r\ncontent-type: application/json\r\n\r\n'
run_request query
assert_exit 0 "$RUN_RC" "successful query exits zero"
assert_eq "$RUN_STDOUT" '{"data":{"viewer":{"id":"viewer-1","name":"Ada"}}}' "success output is canonical JSON"
assert_eq "$RUN_STDERR" '' "successful query is quiet on stderr"
assert_eq "$RUN_ATTEMPTS" '1' "successful query makes one request"
assert_contains "$(cat "$TMP/state/args-1")" 'https://api.linear.app/graphql' "request targets Linear GraphQL endpoint"
assert_contains "$(cat "$TMP/state/args-1")" 'POST' "request uses POST"
assert_contains "$(cat "$TMP/state/request-headers-1")" "Authorization: $SECRET" "request authenticates with LINEAR_API_KEY"
assert_not_contains "$(cat "$TMP/state/args-1")" "$SECRET" "API key is absent from curl process arguments"
expected_request="$(jq -cn --rawfile query "$DOCUMENT" '{query:$query,variables:{}}')"
assert_eq "$(jq -c . "$TMP/state/request-body-1")" "$expected_request" "request preserves the GraphQL document and variables"
assert_secret_safe success
if [ -e "$TMP/state/env-secret-1" ]; then
  fail "LINEAR_API_KEY is absent from curl environment"
else
  pass
fi

reset_queue
queue_response 1 200 "$FIXTURES/http-success.json" $'HTTP/2 200\r\n\r\n'
queue_response 2 200 "$FIXTURES/http-success.json" $'HTTP/2 200\r\n\r\n'
run_request query "$TMP/mutation.graphql"
assert_exit 2 "$RUN_RC" "mutation document cannot be labeled as a query"
assert_contains "$RUN_STDERR" 'classification=operation_mismatch' "operation mismatch is classified"
assert_eq "$RUN_ATTEMPTS" '0' "mutation-as-query is rejected before any retryable request"

reset_queue
run_request query "$TMP/multiple-operations.graphql"
assert_exit 2 "$RUN_RC" "multi-operation document is rejected as ambiguous"
assert_contains "$RUN_STDERR" 'classification=ambiguous_operation' "multi-operation ambiguity is classified"
assert_eq "$RUN_ATTEMPTS" '0' "ambiguous document makes no request"

reset_queue
queue_response 1 200 "$FIXTURES/http-success.json" $'HTTP/2 200\r\n\r\n'
run_request mutation "$TMP/adversarial-mutation.graphql"
assert_exit 0 "$RUN_RC" "comment-adjacent mutation token is derived correctly"
assert_eq "$RUN_ATTEMPTS" '1' "comment-adjacent mutation makes one mutation request"

reset_queue
queue_response 1 200 "$FIXTURES/http-success.json" $'HTTP/2 200\r\n\r\n'
run_request query "$TMP/string-and-comment-keywords.graphql"
assert_exit 0 "$RUN_RC" "operation keywords in comments and strings are ignored"
assert_eq "$RUN_ATTEMPTS" '1' "real query remains the sole derived operation"

reset_queue
queue_response 1 200 "$FIXTURES/http-success.json" $'HTTP/2 200\r\n\r\n'
run_request query "$TMP/shorthand-query.graphql"
assert_exit 0 "$RUN_RC" "shorthand query is recognized"
assert_eq "$RUN_ATTEMPTS" '1' "shorthand query makes one query request"

# Authentication, authorization, client, and rate-limit failures never retry.
for status in 401 403 422; do
  reset_queue
  queue_response 1 "$status" "$FIXTURES/http-graphql-errors.json" $'HTTP/2 400\r\n\r\n'
  run_request query
  assert_exit 1 "$RUN_RC" "HTTP $status fails"
  expected='terminal_client'
  [ "$status" = 401 ] && expected='authentication'
  [ "$status" = 403 ] && expected='authorization'
  assert_contains "$RUN_STDERR" "classification=$expected" "HTTP $status is classified"
  assert_eq "$RUN_ATTEMPTS" '1' "HTTP $status is not retried"
  assert_secret_safe "HTTP $status"
done

reset_queue
queue_response 1 429 "$FIXTURES/http-graphql-errors.json" $'HTTP/2 429\r\nRetry-After: 17\r\nx-ratelimit-requests-reset: 23\r\n\r\n'
run_request query
assert_exit 1 "$RUN_RC" "HTTP 429 fails"
assert_contains "$RUN_STDERR" 'classification=rate_limit' "HTTP 429 is classified"
assert_contains "$RUN_STDERR" 'retry_after=17s' "Retry-After timing is extracted"
assert_contains "$RUN_STDERR" 'rate_limit_reset=23' "Linear reset timing is extracted"
assert_eq "$RUN_ATTEMPTS" '1' "rate limit stops instead of sleeping through a gate"
assert_secret_safe 'HTTP 429'

# Explicitly transient query failures retry exactly three total attempts.
reset_queue
for attempt in 1 2 3; do
  queue_response "$attempt" 503 "$FIXTURES/http-graphql-errors.json" $'HTTP/2 503\r\n\r\n'
done
run_request query
assert_exit 1 "$RUN_RC" "exhausted server failure fails"
assert_contains "$RUN_STDERR" 'classification=retryable_server' "5xx is classified retryable"
assert_contains "$RUN_STDERR" 'attempt=3/3' "final retry state is reported"
assert_eq "$RUN_ATTEMPTS" '3' "query retries are bounded"
assert_secret_safe 'HTTP 5xx'

reset_queue
queue_response 1 000 "$FIXTURES/http-graphql-errors.json" '' 7
queue_response 2 200 "$FIXTURES/http-success.json" $'HTTP/2 200\r\n\r\n'
run_request query
assert_exit 0 "$RUN_RC" "query recovers from transient curl failure"
assert_eq "$RUN_ATTEMPTS" '2' "transport failure query is retried"
assert_contains "$RUN_STDERR" 'classification=retryable_transport attempt=1/3 retrying' "transport retry is classified"
assert_secret_safe 'transport retry'

reset_queue
queue_response 1 000 "$FIXTURES/http-graphql-errors.json" '' 60
queue_response 2 200 "$FIXTURES/http-success.json" $'HTTP/2 200\r\n\r\n'
run_request query
assert_exit 1 "$RUN_RC" "certificate failure is terminal"
assert_contains "$RUN_STDERR" 'classification=terminal_transport' "certificate failure is classified terminal"
assert_eq "$RUN_ATTEMPTS" '1' "certificate failure is not retried"
assert_secret_safe 'certificate failure'

# Mutations are never blindly retried, including server and transport uncertainty.
reset_queue
queue_response 1 503 "$FIXTURES/http-graphql-errors.json" $'HTTP/2 503\r\n\r\n'
run_request mutation "$TMP/mutation.graphql"
assert_exit 1 "$RUN_RC" "mutation 5xx fails"
assert_eq "$RUN_ATTEMPTS" '1' "mutation 5xx is not blindly retried"
assert_contains "$RUN_STDERR" 'retry=forbidden_for_mutation' "unknown mutation outcome reports retry prohibition"
assert_secret_safe 'mutation 5xx'

reset_queue
queue_response 1 000 "$FIXTURES/http-graphql-errors.json" '' 28
run_request mutation "$TMP/mutation.graphql"
assert_exit 1 "$RUN_RC" "mutation transport uncertainty fails"
assert_eq "$RUN_ATTEMPTS" '1' "mutation transport uncertainty is not blindly retried"
assert_contains "$RUN_STDERR" 'classification=unknown_mutation_outcome' "unknown mutation outcome is classified"
assert_secret_safe 'mutation transport failure'

# GraphQL errors fail closed even with HTTP 200 or partial data.
for fixture in http-graphql-errors.json http-partial-errors.json; do
  reset_queue
  queue_response 1 200 "$FIXTURES/$fixture" $'HTTP/2 200\r\n\r\n'
  run_request query
  assert_exit 1 "$RUN_RC" "$fixture fails"
  assert_contains "$RUN_STDERR" 'classification=graphql_errors' "$fixture is classified"
  assert_eq "$RUN_STDOUT" '' "$fixture emits no partial response"
  assert_eq "$RUN_ATTEMPTS" '1' "$fixture is not retried"
  assert_secret_safe "$fixture"
done

reset_queue
queue_response 1 200 "$FIXTURES/http-malformed.json" $'HTTP/2 200\r\n\r\n'
run_request query
assert_exit 1 "$RUN_RC" "malformed JSON fails"
assert_contains "$RUN_STDERR" 'classification=malformed_response' "malformed JSON is classified"
assert_eq "$RUN_STDOUT" '' "malformed response body is not echoed"
assert_secret_safe 'malformed JSON'

reset_queue
printf '%s\n' '{}' > "$TMP/no-data.json"
queue_response 1 200 "$TMP/no-data.json" $'HTTP/2 200\r\n\r\n'
run_request query
assert_exit 1 "$RUN_RC" "success envelope without data fails closed"
assert_contains "$RUN_STDERR" 'classification=malformed_response' "missing GraphQL data is classified"
assert_eq "$RUN_STDOUT" '' "missing-data response body is not echoed"

# Reflected credentials are redacted even from an otherwise successful JSON response.
reset_queue
printf '{"data":{"echo":"Authorization: %s","key":"%s"}}\n' "$SECRET" "$SECRET" > "$TMP/reflected.json"
queue_response 1 200 "$TMP/reflected.json" $'HTTP/2 200\r\n\r\n'
run_request query
assert_exit 0 "$RUN_RC" "reflected-key response remains valid"
assert_contains "$RUN_STDOUT" '[REDACTED]' "reflected API key is replaced"
assert_secret_safe 'reflected key'

# Preflight remains read-only and exposes cardinalities needed to block missing/ambiguous mappings before writes.
if [ -f "$DOCUMENT" ]; then
  document_text="$(cat "$DOCUMENT")"
else
  document_text=''
fi
assert_contains "$document_text" 'query WoostackPreflight' "preflight is a named query"
assert_not_contains "$document_text" 'mutation WoostackPreflight' "preflight document contains no mutation operation"
for field in viewer organization teams projectStatuses workflowStates mutationCapabilities; do
  assert_contains "$document_text" "$field" "preflight resolves $field"
done
for capability in projectCreate projectUpdate documentCreate documentUpdate issueCreate issueUpdate issueRelationCreate; do
  assert_contains "$document_text" "$capability" "preflight pins required $capability capability"
done
assert_contains "$document_text" 'pageInfo' "preflight requests connection completeness"
assert_contains "$document_text" 'hasNextPage' "preflight requests pagination state"
PROJECT_STATUSES='{"draft":"Draft","hardened":"Hardened","approved":"Approved","planning":"Planning","ready":"Ready","executing":"In Progress","inReview":"In Review","done":"Completed","abandoned":"Canceled"}'
ISSUE_STATES='{"planned":"Backlog","executing":"In Progress","inReview":"In Review","done":"Done","blocked":"Blocked"}'

run_preflight_validation() {
  local response="$1"
  local workspace="$2"
  local team="$3"
  local project_statuses="$4"
  local issue_states="$5"
  : > "$TMP/preflight-stdout"
  : > "$TMP/preflight-stderr"
  set +e
  LINEAR_API_KEY="$SECRET" bash "$PREFLIGHT" \
    --response "$response" \
    --workspace "$workspace" \
    --team "$team" \
    --project-statuses "$project_statuses" \
    --issue-states "$issue_states" \
    >"$TMP/preflight-stdout" 2>"$TMP/preflight-stderr"
  PREFLIGHT_RC=$?
  set -e
  PREFLIGHT_STDOUT="$(cat "$TMP/preflight-stdout")"
  PREFLIGHT_STDERR="$(cat "$TMP/preflight-stderr")"
}

reset_queue
queue_response 1 200 "$FIXTURES/http-preflight-success.json" $'HTTP/2 200\r\n\r\n'
run_request query
printf '%s\n' "$RUN_STDOUT" > "$TMP/preflight-response.json"
run_preflight_validation "$TMP/preflight-response.json" acme ENG "$PROJECT_STATUSES" "$ISSUE_STATES"
assert_exit 0 "$PREFLIGHT_RC" "complete preflight resolves successfully"
assert_eq "$PREFLIGHT_STDERR" '' "successful preflight is quiet"
assert_eq "$(jq -r '.workspace.id' <<<"$PREFLIGHT_STDOUT")" 'org-1' "preflight resolves workspace UUID"
assert_eq "$(jq -r '.team.id' <<<"$PREFLIGHT_STDOUT")" 'team-1' "preflight resolves team UUID"
assert_eq "$(jq -r '.projectStatuses.abandoned' <<<"$PREFLIGHT_STDOUT")" 'ps-abandoned' "preflight resolves every configured project status"
assert_eq "$(jq -r '.issueStates.blocked' <<<"$PREFLIGHT_STDOUT")" 'ws-blocked' "preflight resolves team-scoped issue states"
assert_not_contains "$PREFLIGHT_STDOUT$PREFLIGHT_STDERR" "$SECRET" "preflight success output contains no API key"

assert_preflight_blocks_write() {
  local fixture="$1"
  local project_statuses="$2"
  local issue_states="$3"
  local classification="$4"
  local path="$5"
  local selected_team="${6:-ENG}"
  reset_queue
  queue_response 1 200 "$FIXTURES/$fixture" $'HTTP/2 200\r\n\r\n'
  queue_response 2 200 "$FIXTURES/http-success.json" $'HTTP/2 200\r\n\r\n'
  run_request query
  printf '%s\n' "$RUN_STDOUT" > "$TMP/preflight-response.json"
  run_preflight_validation "$TMP/preflight-response.json" acme "$selected_team" "$project_statuses" "$issue_states"
  if [ "$PREFLIGHT_RC" -eq 0 ]; then
    LINEAR_API_KEY="$SECRET" bash "$SCRIPT" --operation mutation --document "$TMP/mutation.graphql" --variables '{}' >/dev/null 2>/dev/null || true
  fi
  guarded_attempts="$(cat "$TMP/state/count")"
  assert_exit 1 "$PREFLIGHT_RC" "$fixture preflight fails closed"
  assert_contains "$PREFLIGHT_STDERR" "classification=$classification" "$fixture reports classified preflight failure"
  assert_contains "$PREFLIGHT_STDERR" "path=$path" "$fixture reports failing config path"
  assert_eq "$guarded_attempts" '1' "$fixture blocks before a subsequent mutation request"
  assert_not_contains "$PREFLIGHT_STDOUT$PREFLIGHT_STDERR" "$SECRET" "$fixture diagnostics contain no API key"
}

assert_preflight_blocks_write http-preflight-missing.json '{"draft":"Draft"}' '{"planned":"Backlog"}' missing_mapping linear.team
assert_preflight_blocks_write http-preflight-ambiguous.json '{"draft":"Draft"}' '{"planned":"Backlog"}' ambiguous_mapping linear.projectStatuses.draft
assert_preflight_blocks_write http-preflight-wrong-team.json '{"draft":"Draft"}' '{"planned":"Backlog"}' missing_mapping linear.issueStates.planned
assert_preflight_blocks_write http-preflight-missing-capability.json '{"draft":"Draft"}' '{"planned":"Backlog"}' missing_capability schema.mutation.issueRelationCreate
assert_preflight_blocks_write http-preflight-partial-page.json '{"draft":"Draft"}' '{"planned":"Backlog"}' incomplete_preflight_response data.teams.pageInfo.hasNextPage OPS

finish
