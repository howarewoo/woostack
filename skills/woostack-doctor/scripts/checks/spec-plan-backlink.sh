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
  root="$2"; spec="$3"; pbase="$4"
  grep -qF "[[plans/$pbase]]" "$spec" 2>/dev/null && exit 0
  awk -v line="> **Plan:** [[plans/$pbase]]" '
    {print} d==0 && /^# /{print ""; print line; d=1}' "$spec" > "$spec.t" \
    && mv "$spec.t" "$spec"
  # The awk anchors the callout to the first H1; a spec with no H1 heading leaves
  # the file unchanged, so the backlink is never inserted. Confirm it actually
  # landed instead of reporting a phantom-successful repair (the orchestrator
  # reads exit 0 as "fixed" and would otherwise re-warn on the next diagnose).
  if ! grep -qF "[[plans/$pbase]]" "$spec"; then
    emit error spec-plan-backlink manual "${spec#"$root"/}" \
      "no H1 heading to anchor backlink [[plans/$pbase]]; add it to the spec manually"
    exit 1
  fi
  exit 0
fi
WOO_ROOT="${1:-.}"

# spec_for <plan-file> → absolute spec path (Source line, else same-basename), empty if none.
spec_for() {
  local plan="$1" pbase src
  pbase="$(basename "$plan")"
  # The **Source:** line may be a bare path (`.woostack/specs/<base>.md`) or an Obsidian
  # wikilink (`[[specs/<base>]]`, no `.md`). The char class already stops at `]`/`)`/space, so
  # it extracts `specs/<base>` from either form; normalize to exactly one `.md` before the
  # existence test.
  src="$(grep -m1 -E '^\*\*Source:\*\*' "$plan" 2>/dev/null | grep -oE 'specs/[^])[:space:]]+' | head -1)"
  if [ -n "$src" ]; then
    src="${src%.md}.md"
    [ -f "$WOO_ROOT/.woostack/$src" ] && { printf '%s\n' "$WOO_ROOT/.woostack/$src"; return; }
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
