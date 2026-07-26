#!/usr/bin/env bash
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$HERE/../../../woostack-init/templates/config.json"
emit() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5"; }

if [ "${1:-}" = "--fix" ]; then
  WOO_ROOT="${2:-.}"
  key="${3:-}"
  [ -n "$key" ] || { echo "config-keys.sh: --fix requires a key argument" >&2; exit 2; }
  command -v jq >/dev/null 2>&1 || exit 2
  CFG="$WOO_ROOT/.woostack/config.json"
  [ -f "$CFG" ] || echo '{}' >"$CFG"
  value="$(jq -c --arg key "$key" '.[$key]' "$TEMPLATE")"
  tmp="$(mktemp)"
  jq --arg key "$key" --argjson value "$value" '.[$key]=$value' "$CFG" >"$tmp" && mv "$tmp" "$CFG"
  exit $?
fi

WOO_ROOT="${1:-.}"
CFG="$WOO_ROOT/.woostack/config.json"
[ -f "$TEMPLATE" ] || exit 0
if ! command -v jq >/dev/null 2>&1; then
  emit error linear-policy report ".woostack/config.json" "jq is required for static Linear policy validation"
  exit 0
fi
if [ ! -f "$CFG" ] || ! jq -e 'type == "object"' "$CFG" >/dev/null 2>&1; then
  emit error linear-policy report ".woostack/config.json" "missing or malformed configuration object"
  exit 0
fi

while IFS= read -r key; do
  if ! jq -e --arg key "$key" 'has($key)' "$CFG" >/dev/null; then
    emit warn config-key auto ".woostack/config.json" "missing required config key: $key"
  fi
done < <(jq -r 'keys[]' "$TEMPLATE")

if jq -e 'has("artifacts")' "$CFG" >/dev/null; then
  emit error linear-policy report ".woostack/config.json" "development backend selectors are not supported"
fi
credential_path="$(jq -r '
  paths as $p
  | ($p | map(tostring) | join(".")) as $name
  | select($name | test("api.?key|token|secret|password|authorization|credential"; "i"))
  | $name
' "$CFG" 2>/dev/null | head -n 1)"
if [ -n "$credential_path" ]; then
  emit error linear-policy report ".woostack/config.json" "credential-like configuration key: $credential_path"
fi

allowed='["repository","workspace","team","projectStatuses","issueStates"]'
if ! jq -e --argjson allowed "$allowed" '
  .linear | type == "object" and ((keys - $allowed) | length == 0)
  and (.repository | type == "string" and test("^https://github\\.com/[^/]+/[^/]+$"))
  and (.workspace | type == "string" and length > 0)
  and (.team | type == "string" and length > 0)
  and (.projectStatuses | type == "object")
  and (.issueStates | type == "object")
' "$CFG" >/dev/null 2>&1; then
  emit error linear-policy report ".woostack/config.json" "linear policy requires repository, workspace, team, projectStatuses, and issueStates only"
else
  project_keys='["designApproved","specHardened","specApproved","planning","ready","executionApproved","executing","inReview","done","abandoned","paused"]'
  issue_keys='["planned","executing","inReview","done","blocked"]'
  if ! jq -e --argjson keys "$project_keys" '
    (.linear.projectStatuses | keys | sort) == ($keys | sort)
    and all(.linear.projectStatuses[]; type == "string" and length > 0)
  ' "$CFG" >/dev/null; then
    emit error linear-policy report ".woostack/config.json" "projectStatuses mapping is incomplete or contains invalid values"
  fi
  if ! jq -e --argjson keys "$issue_keys" '
    (.linear.issueStates | keys | sort) == ($keys | sort)
    and all(.linear.issueStates[]; type == "string" and length > 0)
  ' "$CFG" >/dev/null; then
    emit error linear-policy report ".woostack/config.json" "issueStates mapping is incomplete or contains invalid values"
  fi
fi

for name in specs plans fixes overnight; do
  dir="$WOO_ROOT/.woostack/$name"
  [ -d "$dir" ] || continue
  shopt -s nullglob dotglob
  entries=("$dir"/*)
  shopt -u nullglob dotglob
  [ "${#entries[@]}" -eq 0 ] && continue
  emit error legacy-development-records report ".woostack/$name" "legacy development-record set requires verified migration classification"
done

[ "${WOOSTACK_DOCTOR_LIVE:-0}" = 1 ] || exit 0
receipt="${WOOSTACK_DOCTOR_LIVE_CONTEXT:-}"
if [ ! -r "$receipt" ] || ! jq -e 'type == "object" and .ready == true' "$receipt" >/dev/null 2>&1; then
  emit error linear-live report ".woostack/config.json" "normalized Linear MCP receipt is missing, malformed, or not ready"
  exit 0
fi

for field in workspace team repository; do
  expected="$(jq -r --arg field "$field" '.linear[$field]' "$CFG")"
  actual="$(jq -r --arg field "$field" '.[$field] // empty' "$receipt")"
  if [ "$actual" != "$expected" ]; then
    emit error linear-live report ".woostack/config.json" "receipt $field does not match configured Linear policy"
  fi
done

required_capabilities=(
  projectRead projectWrite projectUpdateRead projectUpdateWrite
  issueRead issueWrite commentRead commentWrite relationRead relationWrite
  ownerRead ownerWrite independentReadBack
)
for capability in "${required_capabilities[@]}"; do
  if ! jq -e --arg capability "$capability" '.capabilities[$capability] == true' "$receipt" >/dev/null 2>&1; then
    emit error linear-live report ".woostack/config.json" "missing Linear MCP capability: $capability"
  fi
done
