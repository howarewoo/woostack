#!/usr/bin/env bash
# omp-session-name.sh — verify project-scoped OMP session-naming extension and settings.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROVISIONER="$HERE/../../../woostack-init/scripts/provision-omp-session-name.sh"
emit() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5"; }

if [ "${1:-}" = "--fix" ]; then
  shift
  [ "$#" -le 1 ] || {
    echo "omp-session-name.sh: usage: omp-session-name.sh [--fix [workspace]]" >&2
    exit 2
  }
  WOO_ROOT="${1:-.}"
  exec /bin/bash "$PROVISIONER" "$WOO_ROOT"
fi

[ "$#" -le 1 ] || {
  echo "omp-session-name.sh: usage: omp-session-name.sh [workspace]" >&2
  exit 2
}
WOO_ROOT="${1:-.}"
while IFS=$'\t' read -r state path message; do
  [ -n "$state" ] || continue
  emit warn omp-session-name auto "$path" "$state: $message; --fix repairs only woostack-managed OMP session-naming content"
done < <(/bin/bash "$PROVISIONER" --check "$WOO_ROOT")
