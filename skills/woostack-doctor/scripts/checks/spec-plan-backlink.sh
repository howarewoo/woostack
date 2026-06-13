#!/usr/bin/env bash
# spec-plan-backlink.sh — every plan's source spec must carry [[plans/<plan-basename>]].
# Calling convention (uniform across all checks):
#   diagnose:  <check> <WOO_ROOT>
#   repair:    <check> --fix <WOO_ROOT> <extra-args...>
# $1 is overloaded (root or "--fix"), so resolve mode BEFORE deriving any path.
set -uo pipefail
emit() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5"; }

if [ "${1:-}" = "--fix" ]; then
  # --fix <root> <spec> <plan-basename> : insert the callout after the first H1 (idempotent).
  spec="$3"; pbase="$4"
  grep -qF "[[plans/$pbase]]" "$spec" 2>/dev/null && exit 0
  awk -v line="> **Plan:** [[plans/$pbase]]" '
    {print} d==0 && /^# /{print ""; print line; d=1}' "$spec" > "$spec.t" \
    && mv "$spec.t" "$spec"
  exit $?
fi
WOO_ROOT="${1:-.}"

# spec_for <plan-file> → absolute spec path (Source line, else same-basename), empty if none.
spec_for() {
  local plan="$1" pbase src
  pbase="$(basename "$plan")"
  src="$(grep -m1 -E '^\*\*Source:\*\*' "$plan" 2>/dev/null | grep -oE 'specs/[^])[:space:]]+\.md' | head -1)"
  if [ -n "$src" ] && [ -f "$WOO_ROOT/.woostack/$src" ]; then
    printf '%s\n' "$WOO_ROOT/.woostack/$src"; return
  fi
  [ -f "$WOO_ROOT/.woostack/specs/$pbase" ] && printf '%s\n' "$WOO_ROOT/.woostack/specs/$pbase"
}

shopt -s nullglob
for plan in "$WOO_ROOT"/.woostack/plans/*.md; do
  pbase="$(basename "$plan" .md)"
  spec="$(spec_for "$plan")"
  [ -z "$spec" ] && continue
  grep -qF "[[plans/$pbase]]" "$spec" \
    || emit warn spec-plan-backlink auto "${spec#$WOO_ROOT/}" \
         "spec missing Obsidian backlink [[plans/$pbase]] to its plan"
done
