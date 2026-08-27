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

if jq -e 'has("linear") and (.linear | type == "object") and (.linear | has("saveArtifacts")) or (has("artifacts") and (.artifacts | type == "object") and ((.artifacts | has("saveArtifacts")) or (.artifacts.linear? | type == "object" and has("saveArtifacts"))))' "$EFFECTIVE_CFG" >/dev/null 2>&1; then
  emit error linear-policy report ".woostack/config.json" "linear.saveArtifacts is deprecated; migrate to artifacts.provider and artifacts.linear"
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

if jq -e 'has("artifacts")' "$EFFECTIVE_CFG" >/dev/null 2>&1; then
  if ! jq -e '
    .artifacts | type == "object" and ((keys - ["provider", "linear", "plane"]) | length == 0)
  ' "$EFFECTIVE_CFG" >/dev/null 2>&1; then
    emit error linear-policy report ".woostack/config.json" "artifacts configuration requires provider and supported provider objects only"
  fi

  if jq -e '.artifacts | has("provider")' "$EFFECTIVE_CFG" >/dev/null 2>&1; then
    if ! jq -e '.artifacts.provider | type == "string" and (. == "local" or . == "linear" or . == "plane")' "$EFFECTIVE_CFG" >/dev/null 2>&1; then
      emit error linear-policy report ".woostack/config.json" "artifacts.provider must be \"local\", \"linear\", or \"plane\""
    fi
  fi
fi

provider="$(jq -r '.artifacts.provider // "local"' "$EFFECTIVE_CFG")"
project_keys='["backlog","planned","started","completed","canceled"]'
issue_keys='["planned","executing","inReview","done","blocked"]'
issue_categories='{"planned":"backlog","executing":"started","inReview":"started","done":"completed","blocked":"started"}'
linear_allowed='["repository","workspace","team","projectLabels","projectStatuses","issueStates"]'
plane_allowed='["baseUrl","workspace","repository","project","projectLabels","issueStates"]'
if [ "$provider" = "linear" ]; then
  if ! jq -e 'has("artifacts") and (.artifacts | type == "object") and (.artifacts | has("linear")) and (.artifacts.linear | type == "object")' "$EFFECTIVE_CFG" >/dev/null 2>&1; then
    emit error linear-policy report ".woostack/config.json" "linear policy requires repository, workspace, team, projectLabels, projectStatuses, and issueStates only"
  elif ! jq -e --argjson allowed "$linear_allowed" '
    .artifacts.linear | type == "object" and ((keys - $allowed) | length == 0)
  ' "$EFFECTIVE_CFG" >/dev/null 2>&1; then
    emit error linear-policy report ".woostack/config.json" "linear policy requires repository, workspace, team, projectLabels, projectStatuses, and issueStates only"
  elif ! jq -e '
    .artifacts.linear
    and (.artifacts.linear.repository | type == "string"
      and test("^https://github\\.com/[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?/[A-Za-z0-9](?:[A-Za-z0-9._-]*[A-Za-z0-9])?$"))
    and (.artifacts.linear.workspace | type == "string" and test("\\S"))
    and (.artifacts.linear.team | type == "string" and test("\\S"))
    and (.artifacts.linear | has("projectLabels"))
    and (.artifacts.linear.projectStatuses | type == "object")
    and (.artifacts.linear.issueStates | type == "object")
  ' "$EFFECTIVE_CFG" >/dev/null 2>&1; then
    emit error linear-policy report ".woostack/config.json" "linear policy requires repository, workspace, team, projectLabels, projectStatuses, and issueStates only"
  else
    if ! jq -e --argjson keys "$project_keys" '
      (.artifacts.linear.projectStatuses | keys | sort) == ($keys | sort)
      and all(.artifacts.linear.projectStatuses[]; type == "string" and test("\\S"))
    ' "$EFFECTIVE_CFG" >/dev/null 2>&1; then
      emit error linear-policy report ".woostack/config.json" "projectStatuses mapping is incomplete or contains invalid values"
    fi
    if ! jq -e --argjson keys "$issue_keys" '
      (.artifacts.linear.issueStates | keys | sort) == ($keys | sort)
      and all(.artifacts.linear.issueStates[]; type == "string" and test("\\S"))
    ' "$EFFECTIVE_CFG" >/dev/null 2>&1; then
      emit error linear-policy report ".woostack/config.json" "issueStates mapping is incomplete or contains invalid values"
    fi
    if ! jq -e '
      .artifacts.linear.projectLabels | type == "array" and all(.[]; type == "string" and test("\\S"))
    ' "$EFFECTIVE_CFG" >/dev/null 2>&1; then
      emit error linear-policy report ".woostack/config.json" "projectLabels must be an array of non-empty strings"
    fi
  fi
fi
if [ "$provider" = "plane" ]; then
  if ! jq -e 'has("artifacts") and (.artifacts | type == "object") and (.artifacts | has("plane")) and (.artifacts.plane | type == "object")' "$EFFECTIVE_CFG" >/dev/null 2>&1; then
    emit error linear-policy report ".woostack/config.json" "plane policy requires baseUrl, workspace, repository, project, projectLabels, and issueStates only"
  elif ! jq -e --argjson allowed "$plane_allowed" '
    .artifacts.plane | type == "object" and ((keys - $allowed) | length == 0)
  ' "$EFFECTIVE_CFG" >/dev/null 2>&1; then
    emit error linear-policy report ".woostack/config.json" "plane policy requires baseUrl, workspace, repository, project, projectLabels, and issueStates only"
  elif ! jq -e '
    .artifacts.plane
    and (.artifacts.plane.baseUrl | type == "string" and test("^https?://[^?#\\s]+$"))
    and (.artifacts.plane.workspace | type == "string" and test("\\S"))
    and (.artifacts.plane.repository | type == "string"
      and test("^https://github\\.com/[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?/[A-Za-z0-9](?:[A-Za-z0-9._-]*[A-Za-z0-9])?$"))
    and (.artifacts.plane.project | type == "string" and test("\\S"))
    and (.artifacts.plane | has("projectLabels"))
    and (.artifacts.plane.issueStates | type == "object")
  ' "$EFFECTIVE_CFG" >/dev/null 2>&1; then
    emit error linear-policy report ".woostack/config.json" "plane policy requires baseUrl, workspace, repository, project, projectLabels, and issueStates only"
  else
    if ! jq -e --argjson keys "$issue_keys" '
      (.artifacts.plane.issueStates | keys | sort) == ($keys | sort)
      and all(.artifacts.plane.issueStates[]; type == "string" and test("\\S"))
    ' "$EFFECTIVE_CFG" >/dev/null 2>&1; then
      emit error linear-policy report ".woostack/config.json" "issueStates mapping is incomplete or contains invalid values"
    fi
    if ! jq -e '
      .artifacts.plane.projectLabels | type == "array" and length > 0 and all(.[]; type == "string" and test("\\S"))
    ' "$EFFECTIVE_CFG" >/dev/null 2>&1; then
      emit error linear-policy report ".woostack/config.json" "projectLabels must be an array of non-empty strings"
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
receipt="${WOOSTACK_DOCTOR_LIVE_CONTEXT:-}"
if [ "$provider" = "linear" ]; then
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
            | .name == $config[0].artifacts.linear.projectStatuses[$key] and .category == $key))
        and .issueStates.complete == true
        and (.issueStates.resolved | keys | sort) == ($issue_keys | sort)
        and all($issue_keys[];
          . as $key
          | ($receipt.issueStates.resolved[$key]
            | .name == $config[0].artifacts.linear.issueStates[$key]
              and .category == $issue_categories[$key]))
        and .readBack.status == "verified"
        and .readBack.complete == true
        and .readBack.independent == true
    ' "$receipt" >/dev/null 2>&1; then
    emit error linear-live report ".woostack/config.json" "normalized Linear MCP receipt is missing, malformed, partial, or not ready"
    exit 0
  fi

  for field in workspace team repository; do
    expected="$(jq -r --arg field "$field" '.artifacts.linear[$field]' "$EFFECTIVE_CFG")"
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

  if jq -e '.artifacts.linear.projectLabels? | type == "array" and length > 0' "$EFFECTIVE_CFG" >/dev/null 2>&1; then
    label_capabilities=(projectLabelRead projectLabelWrite)
    for capability in "${label_capabilities[@]}"; do
      if ! jq -e --arg capability "$capability" '.capabilities[$capability] == true' "$receipt" >/dev/null 2>&1; then
        emit error linear-live report ".woostack/config.json" "missing Linear MCP capability: $capability"
      fi
    done
  fi
elif [ "$provider" = "plane" ]; then
  if [ ! -r "$receipt" ] || ! jq -e \
    --argjson issue_keys "$issue_keys" \
    --argjson issue_categories "$issue_categories" \
    --slurpfile config "$EFFECTIVE_CFG" '
      . as $receipt
      | .schemaVersion == 1
        and .provider == "official-plane-mcp"
        and .mcpAvailable == true
        and .authenticated == true
        and .ready == true
        and (.workspaceResolution | type == "object" and (keys | sort) == ["name", "status"])
        and .workspaceResolution.status == "unique"
        and .workspaceResolution.name == .workspace
        and .issueStates.complete == true
        and (.issueStates.resolved | keys | sort) == ($issue_keys | sort)
        and all($issue_keys[];
          . as $key
          | ($receipt.issueStates.resolved[$key]
            | .name == $config[0].artifacts.plane.issueStates[$key]
              and .category == $issue_categories[$key]))
        and .readBack.status == "verified"
        and .readBack.complete == true
        and .readBack.independent == true
    ' "$receipt" >/dev/null 2>&1; then
    emit error linear-live report ".woostack/config.json" "normalized Plane MCP receipt is missing, malformed, partial, or not ready"
    exit 0
  fi

  for field in baseUrl workspace repository project; do
    expected="$(jq -r --arg field "$field" '.artifacts.plane[$field]' "$EFFECTIVE_CFG")"
    actual="$(jq -r --arg field "$field" '.[$field] // empty' "$receipt")"
    if [ "$field" = "baseUrl" ]; then
      actual="$(jq -nr --arg url "$actual" '$url | sub("/+$"; "") | if test("^https?://(api|app)\\.plane\\.so$"; "i") then "https://api.plane.so" else . end')"
      expected="$(jq -nr --arg url "$expected" '$url | sub("/+$"; "") | if test("^https?://(api|app)\\.plane\\.so$"; "i") then "https://api.plane.so" else . end')"
    fi
    if [ "$actual" != "$expected" ]; then
      emit error linear-live report ".woostack/config.json" "receipt $field does not match configured Plane policy"
    fi
  done

  plane_required_capabilities=(
    projectRead projectWrite
    issueRead issueWrite relationRead relationWrite
    projectLabelRead projectLabelWrite
    independentReadBack
  )
  for capability in "${plane_required_capabilities[@]}"; do
    if ! jq -e --arg capability "$capability" '.capabilities[$capability] == true' "$receipt" >/dev/null 2>&1; then
      emit error linear-live report ".woostack/config.json" "missing Plane MCP capability: $capability"
    fi
  done
fi
