#!/usr/bin/env bash
# doctor.sh — provider-free woostack workspace health orchestrator.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK_ONLY=0
TARGET="."

while [ "$#" -gt 0 ]; do
  case "$1" in
    --check) CHECK_ONLY=1; shift ;;
    -*) echo "doctor: unknown flag: $1" >&2; exit 2 ;;
    *) TARGET="$1"; shift ;;
  esac
done

WOO_ROOT="$(cd "$TARGET" 2>/dev/null && pwd)" \
  || { echo "doctor: path not found: $TARGET" >&2; exit 2; }
if [ ! -d "$WOO_ROOT/.woostack" ]; then
  echo "doctor: no .woostack/ at $WOO_ROOT — run woostack-init first" >&2
  exit 2
fi

findings="$(mktemp)"
trap 'rm -f "$findings"' EXIT

shopt -s nullglob
for chk in "$HERE"/checks/*.sh; do
  bash "$chk" "$WOO_ROOT" >>"$findings" 2>/dev/null || true
done

errors=0
warnings=0
TAB="$(printf '\t')"
while IFS="$TAB" read -r sev code fixable path msg; do
  [ -z "${sev:-}" ] && continue
  case "$sev" in
    error) errors=$((errors+1)); echo "::error:: [$code] $path: $msg" >&2 ;;
    warn) warnings=$((warnings+1)); echo "::warning:: [$code] $path: $msg" >&2 ;;
  esac
done <"$findings"

[ "$CHECK_ONLY" -eq 0 ] && cat "$findings"
echo "doctor: $errors error(s), $warnings warning(s)" >&2
[ "$errors" -eq 0 ]
