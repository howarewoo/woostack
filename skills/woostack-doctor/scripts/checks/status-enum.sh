#!/usr/bin/env bash
# status-enum.sh — status: must be a known phase; exact-match aliases auto-normalize.
# Enum is canonical in woostack-status/references/conventions.md; this is the linted copy
# (mirrors status.sh's VALID_PHASES — keep in sync when the enum changes).
#   diagnose:  status-enum.sh <WOO_ROOT>
#   repair:    status-enum.sh --fix <WOO_ROOT> <file>   (canonical self-derived; idempotent)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../woostack-init/scripts/lib.sh"
emit() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5"; }

VALID=" draft hardened approved planning ready executing in-review done abandoned "

# Curated, EXACT-MATCH alias table (misspelling/synonym → canonical). No fuzzy matching.
alias_for() {
  case "$1" in
    aproved|approve)              echo approved ;;
    hardend)                      echo hardened ;;
    in_review|inreview|reviewing) echo in-review ;;
    complete|completed|merged)    echo done ;;
    wip)                          echo executing ;;
    planned)                      echo planning ;;
    abandon|abandonded)           echo abandoned ;;
    *) return 1 ;;
  esac
}

if [ "${1:-}" = "--fix" ]; then
  root="$2"; file="$3"
  s="$(field "$file" status)"
  [ "${VALID/ $s /}" != "$VALID" ] && exit 0        # already valid → no-op
  canon="$(alias_for "$s")" || exit 0               # unknown, no alias → never auto-applied
  set_field "$file" status "$canon" || { emit error status-enum manual "${file#"$root"/}" "no frontmatter fence; set 'status: $canon' manually"; exit 1; }
  exit 0
fi
WOO_ROOT="${1:-.}"

shopt -s nullglob
for dir in specs plans fixes; do
  for f in "$WOO_ROOT/.woostack/$dir"/*.md; do
    [ "$(head -1 "$f")" != "---" ] && continue       # no fence → doc-type owns that report
    s="$(field "$f" status)"
    [ -z "$s" ] && continue                          # missing status → board concern, not enum
    [ "${VALID/ $s /}" != "$VALID" ] && continue     # valid phase → ok
    rp="${f#"$WOO_ROOT"/}"
    if canon="$(alias_for "$s")"; then
      emit error status-enum auto "$rp" "status: '$s' is an alias; normalize to '$canon'"
    else
      emit error status-enum report "$rp" "status: '$s' is not a known phase; set a valid status: manually"
    fi
  done
done
