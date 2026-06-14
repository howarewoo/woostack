#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$HERE/../../../woostack-init/templates/gitignore"
emit() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5"; }
[ -f "$TEMPLATE" ] || exit 0

if [ "${1:-}" = "--fix" ]; then FIX=1; WOO_ROOT="${2:-.}"; else FIX=0; WOO_ROOT="${1:-.}"; fi
GI="$WOO_ROOT/.woostack/.gitignore"

missing() {
  while IFS= read -r line; do
    case "$line" in ''|\#*) continue ;; esac
    [ -f "$GI" ] && grep -qxF "$line" "$GI" && continue
    printf '%s\n' "$line"
  done < "$TEMPLATE"
}

if [ "$FIX" -eq 1 ]; then
  [ -f "$GI" ] || : > "$GI"
  while IFS= read -r line; do [ -n "$line" ] && printf '%s\n' "$line" >> "$GI"; done < <(missing)
  exit 0
fi
while IFS= read -r line; do
  [ -n "$line" ] && emit warn gitignore-drift auto ".woostack/.gitignore" "missing managed line: $line"
done < <(missing)
