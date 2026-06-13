#!/usr/bin/env bash
# doctor.sh — woostack workspace health orchestrator. Runs checks/*.sh, groups
# findings, exits nonzero iff any error. --check = CI mode (annotations + exit only).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CHECK_ONLY=0; TARGET="."
for a in "$@"; do
  case "$a" in
    --check) CHECK_ONLY=1 ;;
    -*) echo "doctor: unknown flag: $a" >&2; exit 2 ;;
    *)  TARGET="$a" ;;
  esac
done

WOO_ROOT="$(cd "$TARGET" 2>/dev/null && pwd)" \
  || { echo "doctor: path not found: $TARGET" >&2; exit 2; }
if [ ! -d "$WOO_ROOT/.woostack" ]; then
  echo "doctor: no .woostack/ at $WOO_ROOT — run woostack-init first" >&2
  exit 2
fi

findings="$(mktemp)"
shopt -s nullglob
for chk in "$HERE"/checks/*.sh; do
  bash "$chk" "$WOO_ROOT" >> "$findings" 2>/dev/null || true
done

errors=0; warnings=0
TAB="$(printf '\t')"
while IFS="$TAB" read -r sev code fixable path msg; do
  [ -z "${sev:-}" ] && continue
  case "$sev" in
    error) errors=$((errors+1)); echo "::error:: [$code] $path: $msg" >&2 ;;
    warn)  warnings=$((warnings+1)); echo "::warning:: [$code] $path: $msg" >&2 ;;
  esac
done < "$findings"

[ "$CHECK_ONLY" -eq 0 ] && cat "$findings"
rm -f "$findings"

echo "doctor: $errors error(s), $warnings warning(s)" >&2
[ "$errors" -eq 0 ]
