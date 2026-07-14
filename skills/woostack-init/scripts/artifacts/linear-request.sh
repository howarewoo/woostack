#!/usr/bin/env bash
set -euo pipefail

ENDPOINT='https://api.linear.app/graphql'
MAX_QUERY_ATTEMPTS=3
RETRY_DELAY_SECONDS="${LINEAR_RETRY_DELAY_SECONDS:-1}"

usage() {
  echo 'usage: linear-request.sh --operation <query|mutation> --document <path> --variables <json>' >&2
  exit 2
}

operation=''
document=''
variables=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    --operation)
      [ "$#" -ge 2 ] || usage
      operation="$2"
      shift 2
      ;;
    --document)
      [ "$#" -ge 2 ] || usage
      document="$2"
      shift 2
      ;;
    --variables)
      [ "$#" -ge 2 ] || usage
      variables="$2"
      shift 2
      ;;
    *) usage ;;
  esac
done

case "$operation" in
  query|mutation) ;;
  *) usage ;;
esac
[ -n "$document" ] && [ -f "$document" ] && [ -r "$document" ] || {
  echo "linear-request: operation=$operation classification=invalid_document" >&2
  exit 2
}
[ -n "$variables" ] || {
  echo "linear-request: operation=$operation classification=invalid_variables" >&2
  exit 2
}
if [ -z "${LINEAR_API_KEY:-}" ]; then
  echo "linear-request: operation=$operation classification=missing_credentials" >&2
  exit 1
fi
case "$LINEAR_API_KEY" in
  *$'\r'*|*$'\n'*)
    echo "linear-request: operation=$operation classification=invalid_credentials" >&2
    exit 1
    ;;
esac
linear_api_key="$LINEAR_API_KEY"
unset LINEAR_API_KEY

if ! command -v python3 >/dev/null 2>&1; then
  echo "linear-request: operation=$operation classification=parser_unavailable" >&2
  exit 2
fi
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! detected_operation="$(python3 "$script_dir/graphql-operation.py" "$document")"; then
  echo "linear-request: operation=$operation classification=invalid_operation" >&2
  exit 2
fi
case "$detected_operation" in
  query|mutation)
    if [ "$detected_operation" != "$operation" ]; then
      echo "linear-request: operation=$operation classification=operation_mismatch" >&2
      exit 2
    fi
    ;;
  ambiguous_operation|invalid_operation|unsupported_operation)
    echo "linear-request: operation=$operation classification=$detected_operation" >&2
    exit 2
    ;;
  *)
    echo "linear-request: operation=$operation classification=invalid_operation" >&2
    exit 2
    ;;
esac
if ! jq -e 'type == "object"' >/dev/null 2>&1 <<<"$variables"; then
  echo "linear-request: operation=$operation classification=invalid_variables" >&2
  exit 2
fi
case "$RETRY_DELAY_SECONDS" in
  ''|*[!0-9]*) RETRY_DELAY_SECONDS=1 ;;
esac

request_dir="$(mktemp -d "${TMPDIR:-/tmp}/woostack-linear-request.XXXXXX")"
trap 'rm -rf "$request_dir"' EXIT
trap 'exit 1' HUP INT TERM
request="$request_dir/request.json"
body="$request_dir/body.json"
headers="$request_dir/headers"
curl_stderr="$request_dir/curl.stderr"
curl_headers="$request_dir/request.headers"
api_key_file="$request_dir/api-key"

if ! jq -cn --rawfile query "$document" --argjson variables "$variables" \
  '{query: $query, variables: $variables}' >"$request"; then
  echo "linear-request: operation=$operation classification=invalid_request" >&2
  exit 2
fi
printf 'Content-Type: application/json\nAuthorization: %s\n' "$linear_api_key" > "$curl_headers"
printf '%s' "$linear_api_key" > "$api_key_file"
chmod 600 "$curl_headers" "$api_key_file"
unset linear_api_key

header_value() {
  local wanted="$1"
  local line=''
  local name=''
  local value=''
  [ -f "$headers" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    name="${line%%:*}"
    if [ "$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')" = "$wanted" ]; then
      value="${line#*:}"
      while [ "${value# }" != "$value" ]; do value="${value# }"; done
      printf '%s' "$value"
      return 0
    fi
  done < "$headers"
}

retry_query() {
  local classification="$1"
  local attempt="$2"
  if [ "$operation" = query ] && [ "$attempt" -lt "$MAX_QUERY_ATTEMPTS" ]; then
    echo "linear-request: operation=query classification=$classification attempt=$attempt/$MAX_QUERY_ATTEMPTS retrying" >&2
    if [ "$RETRY_DELAY_SECONDS" -gt 0 ]; then
      sleep "$RETRY_DELAY_SECONDS"
    fi
    return 0
  fi
  return 1
}

is_retryable_curl_code() {
  case "$1" in
    5|6|7|18|28|35|52|55|56|92) return 0 ;;
    *) return 1 ;;
  esac
}

attempt=1
while [ "$attempt" -le "$MAX_QUERY_ATTEMPTS" ]; do
  : > "$body"
  : > "$headers"
  : > "$curl_stderr"
  status='000'
  if status="$(curl --disable --silent --show-error \
      --request POST \
      --url "$ENDPOINT" \
      --header "@$curl_headers" \
      --data-binary "@$request" \
      --output "$body" \
      --dump-header "$headers" \
      --write-out '%{http_code}' \
      --connect-timeout 10 \
      --max-time 30 \
      2>"$curl_stderr")"; then
    curl_rc=0
  else
    curl_rc=$?
  fi

  if [ "$curl_rc" -ne 0 ]; then
    if ! is_retryable_curl_code "$curl_rc"; then
      echo "linear-request: operation=$operation classification=terminal_transport curl_code=$curl_rc" >&2
      exit 1
    fi
    if retry_query retryable_transport "$attempt"; then
      attempt=$((attempt + 1))
      continue
    fi
    if [ "$operation" = mutation ]; then
      echo "linear-request: operation=mutation classification=unknown_mutation_outcome retry=forbidden_for_mutation" >&2
    else
      echo "linear-request: operation=query classification=retryable_transport attempt=$attempt/$MAX_QUERY_ATTEMPTS" >&2
    fi
    exit 1
  fi

  case "$status" in
    2??)
      if ! jq -e 'type == "object"' "$body" >/dev/null 2>&1; then
        echo "linear-request: operation=$operation classification=malformed_response http_status=$status" >&2
        exit 1
      fi
      if jq -e '(.errors? // []) | length > 0' "$body" >/dev/null 2>&1; then
        echo "linear-request: operation=$operation classification=graphql_errors http_status=$status" >&2
        exit 1
      fi
      if ! jq -e 'has("data") and .data != null' "$body" >/dev/null 2>&1; then
        echo "linear-request: operation=$operation classification=malformed_response http_status=$status" >&2
        exit 1
      fi
      jq -cS --rawfile key "$api_key_file" '
        def redact:
          if type == "object" then
            with_entries(
              if (.key | test("authorization|api[_-]?key|token"; "i")) then
                .value = "[REDACTED]"
              else
                .value |= redact
              end
            )
          elif type == "array" then map(redact)
          elif type == "string" then
            if test("authorization"; "i") then "[REDACTED]"
            else split($key) | join("[REDACTED]")
            end
          else .
          end;
        redact
      ' "$body"
      exit 0
      ;;
    401)
      echo "linear-request: operation=$operation classification=authentication http_status=401" >&2
      exit 1
      ;;
    403)
      echo "linear-request: operation=$operation classification=authorization http_status=403" >&2
      exit 1
      ;;
    429)
      retry_after="$(header_value retry-after)"
      rate_limit_reset="$(header_value x-ratelimit-requests-reset)"
      diagnostic="linear-request: operation=$operation classification=rate_limit http_status=429"
      [ -z "$retry_after" ] || diagnostic="$diagnostic retry_after=${retry_after}s"
      [ -z "$rate_limit_reset" ] || diagnostic="$diagnostic rate_limit_reset=$rate_limit_reset"
      printf '%s\n' "$diagnostic" >&2
      exit 1
      ;;
    5??)
      if retry_query retryable_server "$attempt"; then
        attempt=$((attempt + 1))
        continue
      fi
      if [ "$operation" = mutation ]; then
        echo "linear-request: operation=mutation classification=retryable_server http_status=$status attempt=1/1 retry=forbidden_for_mutation" >&2
      else
        echo "linear-request: operation=query classification=retryable_server http_status=$status attempt=$attempt/$MAX_QUERY_ATTEMPTS" >&2
      fi
      exit 1
      ;;
    4??)
      echo "linear-request: operation=$operation classification=terminal_client http_status=$status" >&2
      exit 1
      ;;
    *)
      if retry_query retryable_transport "$attempt"; then
        attempt=$((attempt + 1))
        continue
      fi
      if [ "$operation" = mutation ]; then
        echo "linear-request: operation=mutation classification=unknown_mutation_outcome retry=forbidden_for_mutation" >&2
      else
        echo "linear-request: operation=query classification=retryable_transport attempt=$attempt/$MAX_QUERY_ATTEMPTS" >&2
      fi
      exit 1
      ;;
  esac
done

exit 1
