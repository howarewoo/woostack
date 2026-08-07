#!/usr/bin/env bash
# omp-agents.sh — verify project-scoped OMP role agents.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROVISIONER="$HERE/../../../woostack-init/scripts/provision-omp-agents.sh"
emit() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5"; }

if [ "${1:-}" = "--fix" ]; then
  shift
  [ "$#" -le 1 ] || {
    echo "omp-agents.sh: usage: omp-agents.sh [--fix [workspace]]" >&2
    exit 2
  }
  WOO_ROOT="${1:-.}"
  exec /bin/bash "$PROVISIONER" "$WOO_ROOT"
fi

[ "$#" -le 1 ] || {
  echo "omp-agents.sh: usage: omp-agents.sh [workspace]" >&2
  exit 2
}
WOO_ROOT="${1:-.}"
while IFS=$'\t' read -r state path message; do
  [ -n "$state" ] || continue
  emit warn omp-agent auto "$path" "$state: $message; --fix repairs only woostack-managed OMP agent content"
done < <(/bin/bash "$PROVISIONER" --check "$WOO_ROOT")
