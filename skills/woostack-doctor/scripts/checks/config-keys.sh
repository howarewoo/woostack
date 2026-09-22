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
  [ -f "$TEMPLATE" ] || exit 2
  if ! jq -e --arg key "$key" 'has($key)' "$TEMPLATE" >/dev/null 2>&1; then
    echo "config-keys.sh: unsupported template key: $key" >&2
    exit 2
  fi
  CFG="$WOO_ROOT/.woostack/config.json"
  [ -d "$WOO_ROOT/.woostack" ] || { echo "config-keys.sh: .woostack is missing" >&2; exit 2; }
  if [ -L "$CFG" ] || { [ -e "$CFG" ] && [ ! -f "$CFG" ]; }; then
    echo "config-keys.sh: config.json must be a regular non-symlink file" >&2
    exit 2
  fi
  if [ -f "$CFG" ]; then
    jq -e 'type == "object"' "$CFG" >/dev/null 2>&1 || {
      echo "config-keys.sh: config.json must contain a JSON object" >&2
      exit 2
    }
    if jq -e --arg key "$key" 'has($key)' "$CFG" >/dev/null 2>&1; then
      exit 0
    fi
  else
    printf '{}\n' >"$CFG" || exit 1
  fi
  value="$(jq -c --arg key "$key" '.[$key]' "$TEMPLATE")" || exit 1
  tmp="$(mktemp)"
  if ! jq --arg key "$key" --argjson value "$value" '.[$key]=$value' "$CFG" >"$tmp"; then
    rm -f "$tmp"
    exit 1
  fi
  mv "$tmp" "$CFG"
  exit $?
fi

WOO_ROOT="${1:-.}"
CFG="$WOO_ROOT/.woostack/config.json"
[ -f "$TEMPLATE" ] || exit 0
if ! command -v jq >/dev/null 2>&1; then
  emit error config-policy report ".woostack/config.json" "jq is required for canonical configuration validation"
  exit 0
fi

resolver_error="$(mktemp)"
if ! effective_config="$(bash "$CONFIG_RESOLVER" "$WOO_ROOT" 2>"$resolver_error")"; then
  detail="$(cat "$resolver_error")"
  rm -f "$resolver_error"
  [ -n "$detail" ] || detail="canonical configuration resolver is unavailable"
  emit error config-policy report ".woostack/config.json" "$detail"
  exit 0
fi
while IFS= read -r notice; do
  [ -z "$notice" ] || emit warn retired-provider report ".woostack/config.json" "$notice"
done <"$resolver_error"
rm -f "$resolver_error"
EFFECTIVE_CFG="$(mktemp)"
printf '%s\n' "$effective_config" >"$EFFECTIVE_CFG"
trap 'rm -f "$EFFECTIVE_CFG"' EXIT

if [ -f "$CFG" ]; then
  base_config="$(cat "$CFG")"
else
  base_config='{}'
fi
while IFS= read -r key; do
  if ! jq -e --arg key "$key" 'has($key)' <<<"$base_config" >/dev/null 2>&1; then
    emit warn config-key auto ".woostack/config.json" "missing required config key: $key"
  fi
done < <(jq -r 'keys[]' "$TEMPLATE")
if jq -e 'has("status") and (.status | type == "object" and has("staleDays"))' "$EFFECTIVE_CFG" >/dev/null 2>&1; then
  emit warn retired-status-config report ".woostack/config.json" "top-level status.staleDays is retired; existing configuration is preserved and may be removed manually"
fi


retained_dir_has_data() {
  local dir="$1" entry
  [ -d "$dir" ] || return 1
  shopt -s nullglob dotglob
  for entry in "$dir"/*; do
    if [ "${entry##*/}" != ".gitkeep" ]; then
      shopt -u nullglob dotglob
      return 0
    fi
  done
  shopt -u nullglob dotglob
  return 1
}
for name in specs plans fixes overnight tmp/runs runs; do
  dir="$WOO_ROOT/.woostack/$name"
  if retained_dir_has_data "$dir"; then
    emit warn retained-data report ".woostack/$name" \
      "retained historical data is preserved and inactive; no automatic migration or provider publication is available"
  fi
done

[ "${WOOSTACK_DOCTOR_LIVE:-0}" = 1 ] || exit 0
receipt="${WOOSTACK_DOCTOR_LIVE_CONTEXT:-}"
status_keys='["planned","executing","inReview","done","blocked"]'
receipt_keys='["authenticated","capabilities","interfaceAvailable","owner","ownerResolution","projectStatuses","provider","readBack","ready","repository","schemaVersion","viewer"]'
capability_names='["dependencyRead","dependencyWrite","independentReadBack","issueRead","issueWrite","pagination","projectRead","projectWrite","statusFieldRead","statusFieldWrite"]'
required_capabilities=(projectRead statusFieldRead pagination independentReadBack)

if [ ! -r "$receipt" ] || ! jq -e \
  --argjson allowed_keys "$receipt_keys" \
  --argjson capability_names "$capability_names" \
  --argjson status_keys "$status_keys" '
    . as $receipt
    | ((keys | sort) == ($allowed_keys | sort))
      and .schemaVersion == 1
      and .provider == "authorized-github"
      and .interfaceAvailable == true
      and .authenticated == true
      and .ready == true
      and (.viewer | type == "object" and (keys | sort) == ["id", "login"]
        and (.login | type == "string" and test("\\S"))
        and (.id | type == "string" and test("\\S")))
      and (.owner | type == "string" and test("\\S"))
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
      and .projectStatuses.fieldType == "SINGLE_SELECT"
      and (.projectStatuses.resolved | type == "object" and (keys | sort) == ($status_keys | sort))
      and all($status_keys[];
        . as $key
        | ($receipt.projectStatuses.resolved[$key]
          | (type == "object" and (keys | sort) == ["id", "name"])
            and (.name | type == "string" and test("\\S"))
            and (.id | type == "string" and test("\\S"))))
      and ([$receipt.projectStatuses.resolved[].id] | unique | length) == ($status_keys | length)
      and ([$receipt.projectStatuses.resolved[].name] | unique | length) == ($status_keys | length)
      and (.capabilities | type == "object"
        and ((keys - $capability_names) | length) == 0
        and all(.[]; type == "boolean"))
      and (.readBack | type == "object" and (keys | sort) == ["complete", "independent", "status"]
        and .status == "verified" and .complete == true and .independent == true)
  ' "$receipt" >/dev/null 2>&1; then
  emit error github-live report ".woostack/config.json" \
    "normalized GitHub capability receipt is missing, malformed, partial, or not ready"
  exit 0
fi

actual_owner="$(jq -r '.owner // empty' "$receipt")"
actual_login="$(jq -r '.ownerResolution.login // empty' "$receipt")"
if [ "$actual_owner" != "$actual_login" ]; then
  emit error github-live report ".woostack/config.json" "receipt owner and resolved owner do not match"
fi
if jq -e 'has("github") and (.github | has("owner"))' "$EFFECTIVE_CFG" >/dev/null 2>&1; then
  expected_owner="$(jq -r '.github.owner' "$EFFECTIVE_CFG")"
  if [ "$actual_owner" != "$expected_owner" ]; then
    emit error github-live report ".woostack/config.json" "receipt owner does not match configured GitHub policy"
  fi
fi
if jq -e 'has("github") and (.github | has("ownerType"))' "$EFFECTIVE_CFG" >/dev/null 2>&1; then
  expected_owner_type="$(jq -r '.github.ownerType' "$EFFECTIVE_CFG")"
  actual_owner_type="$(jq -r '.ownerResolution.type // empty' "$receipt")"
  if [ "$actual_owner_type" != "$expected_owner_type" ]; then
    emit error github-live report ".woostack/config.json" "receipt ownerType does not match configured GitHub policy"
  fi
fi
expected_status_field="$(jq -r '.github.statusField // "Status"' "$EFFECTIVE_CFG")"
actual_status_field="$(jq -r '.projectStatuses.statusField // empty' "$receipt")"
if [ "$actual_status_field" != "$expected_status_field" ]; then
  emit error github-live report ".woostack/config.json" "receipt statusField does not match configured GitHub policy"
fi
if jq -e 'has("github") and (.github | has("projectStatuses"))' "$EFFECTIVE_CFG" >/dev/null 2>&1; then
  for key in planned executing inReview done blocked; do
    expected_name="$(jq -r --arg key "$key" '.github.projectStatuses[$key]' "$EFFECTIVE_CFG")"
    actual_name="$(jq -r --arg key "$key" '.projectStatuses.resolved[$key].name // empty' "$receipt")"
    if [ "$actual_name" != "$expected_name" ]; then
      emit error github-live report ".woostack/config.json" "receipt Status option $key does not match configured GitHub policy"
    fi
  done
fi

git_remote="$(git -C "$WOO_ROOT" config --get remote.origin.url 2>/dev/null || true)"
git_canonical_repo=""
if [ -n "$git_remote" ]; then
  git_canonical_repo="$(printf '%s\n' "$git_remote" | sed -E -e 's#^git@github\.com:#https://github.com/#' -e 's#^ssh://git@github\.com/#https://github.com/#' -e 's#\.git$##')"
fi
actual_repository="$(jq -r '.repository // empty' "$receipt")"
if [ -z "$git_canonical_repo" ] || [ "$actual_repository" != "$git_canonical_repo" ]; then
  emit error github-live report ".woostack/config.json" "receipt repository does not match target repository derived from Git"
fi
for capability in "${required_capabilities[@]}"; do
  if ! jq -e --arg capability "$capability" '.capabilities[$capability] == true' "$receipt" >/dev/null 2>&1; then
    emit error github-live report ".woostack/config.json" "missing GitHub capability: $capability"
  fi
done
