#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOADER="$HERE/../../../woostack-respond/scripts/load-respond-config.sh"
emit() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5"; }

if [ "${1:-}" = "--fix" ]; then
  echo "respond.sh: response findings require manual repair" >&2
  exit 2
fi
ROOT="${1:-.}"
CFG="$ROOT/.woostack/config.json"

if [ -x "$LOADER" ] || [ -f "$LOADER" ]; then
  err="$(mktemp)"
  if ! bash "$LOADER" "$CFG" >/dev/null 2>"$err"; then
    message="$(cat "$err")"
    case "$message" in
      *credential*|*token*|*api_key*|*password*|*cookie*|*authorization*|*secret*|*mutation_authority*)
        emit warn respond-credentials report ".woostack/config.json" "$message" ;;
      *) emit warn respond-config report ".woostack/config.json" "$message" ;;
    esac
  fi
  rm -f "$err"
fi

evidence="$ROOT/.woostack/respond/evidence"
[ -d "$evidence" ] || exit 0
now="${WOOSTACK_NOW_EPOCH:-$(date +%s)}"
case "$now" in *[!0-9]*|'') now="$(date +%s)" ;; esac
for run in "$evidence"/*; do
  [ -d "$run" ] || continue
  mtime="$(stat -f %m "$run" 2>/dev/null || stat -c %Y "$run" 2>/dev/null || echo "$now")"
  age=$((now - mtime))
  if [ "$age" -gt 86400 ]; then
    name="${run##*/}"
    emit warn respond-stale-evidence report ".woostack/respond/evidence/$name" \
      "transient response evidence is older than 24 hours; inspect the failed-run handback, then delete this directory manually"
  fi
done
