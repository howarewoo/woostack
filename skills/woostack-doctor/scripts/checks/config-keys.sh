#!/usr/bin/env bash
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$HERE/../../../woostack-init/templates/config.json"
CONFIG_RESOLVER="$HERE/../../../woostack-init/scripts/config/resolve-config.sh"
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

resolver_error="$(mktemp)"
if [ ! -f "$CONFIG_RESOLVER" ] || ! effective_config="$(bash "$CONFIG_RESOLVER" "$WOO_ROOT" 2>"$resolver_error")"; then
  detail="$(cat "$resolver_error")"
  rm -f "$resolver_error"
  [ -n "$detail" ] || detail="layered config resolver is unavailable"
  emit error linear-policy report ".woostack/config.json" "$detail"
  exit 0
fi
rm -f "$resolver_error"
EFFECTIVE_CFG="$(mktemp)"
printf '%s\n' "$effective_config" >"$EFFECTIVE_CFG"
trap 'rm -f "$EFFECTIVE_CFG"' EXIT

while IFS= read -r key; do
  if ! jq -e --arg key "$key" 'has($key)' "$CFG" >/dev/null; then
    emit warn config-key auto ".woostack/config.json" "missing required config key: $key"
  fi
done < <(jq -r 'keys[]' "$TEMPLATE")

if jq -e 'has("artifacts")' "$EFFECTIVE_CFG" >/dev/null; then
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
allowed='["saveArtifacts","repository","workspace","team","projectStatuses","issueStates"]'
project_keys='["backlog","planned","started","completed","canceled"]'
issue_keys='["planned","executing","inReview","done","blocked"]'
issue_categories='{"planned":"backlog","executing":"started","inReview":"started","done":"completed","blocked":"started"}'
if jq -e 'has("linear")' "$EFFECTIVE_CFG" >/dev/null 2>&1; then
  if ! jq -e --argjson allowed "$allowed" '
    .linear | type == "object" and ((keys - $allowed) | length == 0)
  ' "$EFFECTIVE_CFG" >/dev/null 2>&1; then
    emit error linear-policy report ".woostack/config.json" "linear policy requires saveArtifacts, repository, workspace, team, projectStatuses, and issueStates only"
  fi

  if jq -e '.linear | has("saveArtifacts")' "$EFFECTIVE_CFG" >/dev/null 2>&1; then
    if ! jq -e '.linear.saveArtifacts | type == "boolean"' "$EFFECTIVE_CFG" >/dev/null 2>&1; then
      emit error linear-policy report ".woostack/config.json" "linear.saveArtifacts must be a boolean"
    fi
  fi

  save_artifacts="$(jq -r '.linear.saveArtifacts // false' "$EFFECTIVE_CFG")"
  has_provider_fields="$(jq -e '(.linear | keys - ["saveArtifacts"]) | length > 0' "$EFFECTIVE_CFG" >/dev/null 2>&1 && echo yes || echo no)"

  if [ "$save_artifacts" = "true" ] || [ "$has_provider_fields" = "yes" ]; then
    if ! jq -e '
      .linear
      and (.linear.repository | type == "string"
        and test("^https://github\\.com/[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?/[A-Za-z0-9](?:[A-Za-z0-9._-]*[A-Za-z0-9])?$"))
      and (.linear.workspace | type == "string" and test("\\S"))
      and (.linear.team | type == "string" and test("\\S"))
      and (.linear.projectStatuses | type == "object")
      and (.linear.issueStates | type == "object")
    ' "$EFFECTIVE_CFG" >/dev/null 2>&1; then
      emit error linear-policy report ".woostack/config.json" "linear policy requires repository, workspace, team, projectStatuses, and issueStates only"
    else
      if ! jq -e --argjson keys "$project_keys" '
        (.linear.projectStatuses | keys | sort) == ($keys | sort)
        and all(.linear.projectStatuses[]; type == "string" and test("\\S"))
      ' "$EFFECTIVE_CFG" >/dev/null 2>&1; then
        emit error linear-policy report ".woostack/config.json" "projectStatuses mapping is incomplete or contains invalid values"
      fi
      if ! jq -e --argjson keys "$issue_keys" '
        (.linear.issueStates | keys | sort) == ($keys | sort)
        and all(.linear.issueStates[]; type == "string" and test("\\S"))
      ' "$EFFECTIVE_CFG" >/dev/null 2>&1; then
        emit error linear-policy report ".woostack/config.json" "issueStates mapping is incomplete or contains invalid values"
      fi
    fi
  fi
fi

for name in specs plans fixes overnight; do
  dir="$WOO_ROOT/.woostack/$name"
  [ -d "$dir" ] || continue
  shopt -s nullglob dotglob
  entries=()
  for entry in "$dir"/*; do
    [ "${entry##*/}" = ".gitkeep" ] || entries+=("$entry")
  done
  shopt -u nullglob dotglob
  [ "${#entries[@]}" -eq 0 ] && continue
  emit error legacy-development-records report ".woostack/$name" "legacy development-record set requires verified migration classification"
done

[ "${WOOSTACK_DOCTOR_LIVE:-0}" = 1 ] || exit 0
save_artifacts_live="$(jq -r '.linear.saveArtifacts // false' "$EFFECTIVE_CFG")"
[ "$save_artifacts_live" = "true" ] || exit 0
receipt="${WOOSTACK_DOCTOR_LIVE_CONTEXT:-}"
if [ ! -r "$receipt" ] || ! jq -e \
  --argjson project_keys "$project_keys" \
  --argjson issue_keys "$issue_keys" \
  --argjson issue_categories "$issue_categories" \
  --slurpfile config "$EFFECTIVE_CFG" '
    . as $receipt
    | .schemaVersion == 1
      and .provider == "official-linear-mcp"
      and .mcpAvailable == true
      and .authenticated == true
      and .ready == true
      and (.workspaceResolution | type == "object" and (keys | sort) == ["name", "status"])
      and .workspaceResolution.status == "unique"
      and .workspaceResolution.name == .workspace
      and .teamResolution.status == "unique"
      and .teamResolution.key == .team
      and (.teamResolution.id | type == "string"
        and test("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$"))
      and .projectStatuses.complete == true
      and (.projectStatuses.resolved | keys | sort) == ($project_keys | sort)
      and all($project_keys[];
        . as $key
        | ($receipt.projectStatuses.resolved[$key]
          | .name == $config[0].linear.projectStatuses[$key] and .category == $key))
      and .issueStates.complete == true
      and (.issueStates.resolved | keys | sort) == ($issue_keys | sort)
      and all($issue_keys[];
        . as $key
        | ($receipt.issueStates.resolved[$key]
          | .name == $config[0].linear.issueStates[$key]
            and .category == $issue_categories[$key]))
      and .readBack.status == "verified"
      and .readBack.complete == true
      and .readBack.independent == true
  ' "$receipt" >/dev/null 2>&1; then
  emit error linear-live report ".woostack/config.json" "normalized Linear MCP receipt is missing, malformed, partial, or not ready"
  exit 0
fi

for field in workspace team repository; do
  expected="$(jq -r --arg field "$field" '.linear[$field]' "$EFFECTIVE_CFG")"
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
