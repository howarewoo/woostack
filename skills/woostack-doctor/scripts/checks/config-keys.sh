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
    .artifacts | type == "object" and ((keys - ["provider", "github", "linear", "plane"]) | length == 0)
  ' "$EFFECTIVE_CFG" >/dev/null 2>&1; then
    emit error linear-policy report ".woostack/config.json" "artifacts configuration requires provider and supported provider objects only"
  fi

  if jq -e '.artifacts | has("provider")' "$EFFECTIVE_CFG" >/dev/null 2>&1; then
    if ! jq -e '.artifacts.provider | type == "string" and (. == "local" or . == "github" or . == "linear" or . == "plane")' "$EFFECTIVE_CFG" >/dev/null 2>&1; then
      emit error linear-policy report ".woostack/config.json" "artifacts.provider must be \"local\", \"github\", \"linear\", or \"plane\""
    fi
  fi
fi

provider="$(jq -r '.artifacts.provider // "local"' "$EFFECTIVE_CFG")"
project_keys='["backlog","planned","started","completed","canceled"]'
issue_keys='["planned","executing","inReview","done","blocked"]'
issue_categories='{"planned":"backlog","executing":"started","inReview":"started","done":"completed","blocked":"started"}'
linear_allowed='["repository","workspace","team","projectLabels","projectStatuses","issueStates"]'
plane_allowed='["baseUrl","workspace","repository","project","projectLabels","issueStates"]'
github_allowed='["owner","ownerType","statusField","visibility","projectStatuses"]'
github_receipt_keys='["authenticated","capabilities","ghAvailable","owner","ownerResolution","projectStatuses","provider","readBack","ready","repository","schemaVersion","scopes","viewer"]'
github_required_caps='["dependencyRead","dependencyWrite","independentReadBack","issueClose","issueDelete","issueRead","issueWrite","pagination","projectDelete","projectRead","projectWrite","statusFieldRead","statusFieldWrite"]'
if [ "$provider" = "github" ]; then
  if ! jq -e 'has("artifacts") and (.artifacts | type == "object") and (.artifacts | has("github")) and (.artifacts.github | type == "object")' "$EFFECTIVE_CFG" >/dev/null 2>&1; then
    emit error linear-policy report ".woostack/config.json" "github policy requires owner, projectStatuses, and optional ownerType, statusField, visibility only"
  elif ! jq -e --argjson allowed "$github_allowed" '
    .artifacts.github | type == "object" and ((keys - $allowed) | length == 0)
  ' "$EFFECTIVE_CFG" >/dev/null 2>&1; then
    emit error linear-policy report ".woostack/config.json" "github policy requires owner, projectStatuses, and optional ownerType, statusField, visibility only"
  elif ! jq -e '
    .artifacts.github
    and (.artifacts.github.owner | type == "string"
      and test("^[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?$"))
    and (if .artifacts.github | has("ownerType") then (.artifacts.github.ownerType == "organization" or .artifacts.github.ownerType == "user") else true end)
    and (if .artifacts.github | has("statusField") then (.artifacts.github.statusField | type == "string" and test("\\S")) else true end)
    and (if .artifacts.github | has("visibility") then (.artifacts.github.visibility == "private" or .artifacts.github.visibility == "public") else true end)
    and (.artifacts.github.projectStatuses | type == "object")
  ' "$EFFECTIVE_CFG" >/dev/null 2>&1; then
    emit error linear-policy report ".woostack/config.json" "github policy requires owner, projectStatuses, and optional ownerType, statusField, visibility only"
  else
    if ! jq -e --argjson keys "$issue_keys" '
      (.artifacts.github.projectStatuses | keys | sort) == ($keys | sort)
      and all(.artifacts.github.projectStatuses[]; type == "string" and test("\\S"))
      and ((.artifacts.github.projectStatuses | [.[]] | unique | length) == ($keys | length))
    ' "$EFFECTIVE_CFG" >/dev/null 2>&1; then
      emit error linear-policy report ".woostack/config.json" "projectStatuses mapping is incomplete or contains invalid values"
    fi
  fi
fi
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
elif [ "$provider" = "github" ]; then
  if [ ! -r "$receipt" ] || ! jq -e \
    --argjson allowed_keys "$github_receipt_keys" \
    --argjson required_caps "$github_required_caps" \
    --argjson issue_keys "$issue_keys" \
    --slurpfile config "$EFFECTIVE_CFG" '
      . as $receipt
      | ((. | keys | sort) == ($allowed_keys | sort))
        and .schemaVersion == 1
        and .provider == "official-gh-cli"
        and .ghAvailable == true
        and .authenticated == true
        and .ready == true
        and (.viewer | type == "object" and (keys | sort) == ["id", "login"] and (.login | type == "string" and test("\\S")) and (.id | type == "string" and test("\\S")))
        and (.scopes | type == "array" and (sort == ["project", "read:org", "repo"]))
        and (.ownerResolution | type == "object" and (keys | sort) == ["id", "login", "status", "type"])
        and .ownerResolution.status == "unique"
        and (.ownerResolution.login | type == "string" and test("\\S"))
        and (.ownerResolution.type == "organization" or .ownerResolution.type == "user")
        and (.ownerResolution.id | type == "string" and test("\\S"))
        and (.repository | type == "string"
          and test("^https://github\\.com/[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?/[A-Za-z0-9](?:[A-Za-z0-9._-]*[A-Za-z0-9])?$"))
        and (.projectStatuses | type == "object" and (keys | sort) == ["complete", "fieldId", "fieldType", "resolved", "statusField"])
        and .projectStatuses.complete == true
        and (.projectStatuses.statusField | type == "string" and test("\\S"))
        and (.projectStatuses.fieldId | type == "string" and test("\\S"))
        and (.projectStatuses.fieldType == "SINGLE_SELECT")
        and (.projectStatuses.resolved | type == "object" and (keys | sort) == ($issue_keys | sort))
        and all($issue_keys[];
          . as $key
          | ($receipt.projectStatuses.resolved[$key]
            | (type == "object" and (keys | sort) == ["id", "name"])
              and (.name == $config[0].artifacts.github.projectStatuses[$key])
              and (.id | type == "string" and test("\\S"))))
        and ([$receipt.projectStatuses.resolved[].id] | unique | length) == ($issue_keys | length)
        and (.capabilities | type == "object" and (keys | sort) == ($required_caps | sort) and all(.[]; type == "boolean"))
        and (.readBack | type == "object" and (keys | sort) == ["complete", "independent", "status"] and .status == "verified" and .complete == true and .independent == true)
    ' "$receipt" >/dev/null 2>&1; then
    emit error linear-live report ".woostack/config.json" "normalized GitHub CLI receipt is missing, malformed, partial, or not ready"
    exit 0
  fi

  expected_owner="$(jq -r '.artifacts.github.owner' "$EFFECTIVE_CFG")"
  actual_owner="$(jq -r '.owner // empty' "$receipt")"
  actual_login="$(jq -r '.ownerResolution.login // empty' "$receipt")"
  if [ "$actual_owner" != "$expected_owner" ] || [ "$actual_login" != "$expected_owner" ]; then
    emit error linear-live report ".woostack/config.json" "receipt owner does not match configured GitHub policy"
  fi

  if jq -e '.artifacts.github | has("ownerType")' "$EFFECTIVE_CFG" >/dev/null 2>&1; then
    expected_owner_type="$(jq -r '.artifacts.github.ownerType' "$EFFECTIVE_CFG")"
    actual_owner_type="$(jq -r '.ownerResolution.type // empty' "$receipt")"
    if [ "$actual_owner_type" != "$expected_owner_type" ]; then
      emit error linear-live report ".woostack/config.json" "receipt ownerType does not match configured GitHub policy"
    fi
  fi

  expected_status_field="$(jq -r '.artifacts.github.statusField // "Status"' "$EFFECTIVE_CFG")"
  actual_status_field="$(jq -r '.projectStatuses.statusField // empty' "$receipt")"
  if [ "$actual_status_field" != "$expected_status_field" ]; then
    emit error linear-live report ".woostack/config.json" "receipt statusField does not match configured GitHub policy"
  fi

  actual_repository="$(jq -r '.repository // empty' "$receipt")"
  git_remote="$(git -C "$WOO_ROOT" config --get remote.origin.url 2>/dev/null || true)"
  git_canonical_repo=""
  if [ -n "$git_remote" ]; then
    git_canonical_repo="$(printf '%s\n' "$git_remote" | sed -E -e 's#^git@github\.com:#https://github.com/#' -e 's#^ssh://git@github\.com/#https://github.com/#' -e 's#\.git$##')"
  fi
  if [ -z "$git_canonical_repo" ] || [ "$actual_repository" != "$git_canonical_repo" ]; then
    emit error linear-live report ".woostack/config.json" "receipt repository does not match target repository derived from Git"
  fi

  for capability in $(jq -r '.[]' <<<"$github_required_caps"); do
    if ! jq -e --arg capability "$capability" '.capabilities[$capability] == true' "$receipt" >/dev/null 2>&1; then
      emit error linear-live report ".woostack/config.json" "missing GitHub CLI capability: $capability"
    fi
  done
fi
