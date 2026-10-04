#!/usr/bin/env bash
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_RESOLVER="$HERE/../../../woostack-init/scripts/config/resolve-config.sh"
emit() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5"; }

WOO_ROOT="${1:-.}"
if [ -L "$WOO_ROOT/.woostack" ]; then
  emit error config-policy report ".woostack" ".woostack directory must not be a symlink; inspection stopped without following it"
  exit 0
fi
if ! command -v jq >/dev/null 2>&1; then
  emit error config-policy report ".woostack/config.json" "jq is required for canonical configuration validation"
  exit 0
fi

resolver_error="$(mktemp)"
if ! effective_config="$(bash "$CONFIG_RESOLVER" "$WOO_ROOT" 2>"$resolver_error")"; then
  detail="$(tr '\t\r\n' '   ' <"$resolver_error")"
  rm -f "$resolver_error"
  [ -n "$detail" ] || detail="canonical configuration resolver is unavailable"
  emit error config-policy report ".woostack/config.json" "$detail"
  exit 0
fi
while IFS= read -r notice; do
  [ -z "$notice" ] || emit warn retired-provider report ".woostack/config.json" "$notice"
done <"$resolver_error"
rm -f "$resolver_error"
if jq -e 'has("status") and (.status | type == "object" and has("staleDays"))' <<<"$effective_config" >/dev/null 2>&1; then
  emit warn retired-status-config report ".woostack/config.json" "top-level status.staleDays is retired; existing configuration is preserved and may be removed manually"
fi

retained_dir_has_data() {
  local dir="$1" entry
  [ -d "$dir" ] || return 1
  shopt -s nullglob dotglob
  for entry in "$dir"/*; do
    [ "${entry##*/}" = ".gitkeep" ] && continue
    shopt -u nullglob dotglob
    return 0
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
