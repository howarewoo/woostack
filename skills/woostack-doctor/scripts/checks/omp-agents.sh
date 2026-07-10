#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
emit() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5"; }
if [ "${1:-}" = "--fix" ]; then FIX=1; WOO_ROOT="${2:-.}"; else FIX=0; WOO_ROOT="${1:-.}"; fi
GEN="$HERE/../../../woostack-init/scripts/gen-omp-agents.sh"
[ -d "$WOO_ROOT/.omp" ] || exit 0          # not an omp workspace -> silent
[ -f "$GEN" ] || exit 0
if [ "$FIX" -eq 1 ]; then
  WOOSTACK_ROOT="$WOO_ROOT" bash "$GEN" >/dev/null 2>&1 || true
  exit 0
fi
tmp="$(mktemp -d)" || exit 0            # mktemp failed -> stay read-only, never fall through to live .omp/agents
WOOSTACK_ROOT="$WOO_ROOT" WOO_OMP_AGENTS_DIR="$tmp" bash "$GEN" >/dev/null 2>&1 || true
for want in "$tmp"/woostack-*.md; do
  [ -e "$want" ] || continue
  base="$(basename "$want")"; have="$WOO_ROOT/.omp/agents/$base"
  if [ ! -f "$have" ]; then
    emit warn omp-agents-missing auto "$have" "generated omp tier def missing"
  elif ! diff -q "$want" "$have" >/dev/null 2>&1; then
    emit warn omp-agents-drift auto "$have" "generated omp tier def drifted from .woostack/config.json"
  fi
done
rm -rf "$tmp"
