#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$HERE/../../../woostack-init/templates/config.json"
emit() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5"; }
[ -f "$TEMPLATE" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

if [ "${1:-}" = "--fix" ]; then FIX=1; WOO_ROOT="${2:-.}"; key="${3:-}"; else FIX=0; WOO_ROOT="${1:-.}"; fi
CFG="$WOO_ROOT/.woostack/config.json"

if [ "$FIX" -eq 1 ]; then
  # An empty key arg would make jq write a bogus "" entry into config.json
  # (silent corruption). Require a real key; the orchestrator always passes one.
  [ -n "$key" ] || { echo "config-keys.sh: --fix requires a key argument" >&2; exit 2; }
  [ -f "$CFG" ] || echo '{}' > "$CFG"
  val="$(jq -c --arg k "$key" '.[$k]' "$TEMPLATE")"
  tmp="$(mktemp)"; jq --arg k "$key" --argjson v "$val" '.[$k]=$v' "$CFG" > "$tmp" && mv "$tmp" "$CFG"
  exit $?
fi
req_keys="$(jq -r 'keys[]' "$TEMPLATE")"
for k in $req_keys; do
  if [ ! -f "$CFG" ] || [ "$(jq --arg k "$k" 'has($k)' "$CFG" 2>/dev/null)" != "true" ]; then
    emit warn config-key auto ".woostack/config.json" "missing required config key: $k"
  fi
done
