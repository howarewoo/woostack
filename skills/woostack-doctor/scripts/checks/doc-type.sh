#!/usr/bin/env bash
# doc-type.sh — every spec/plan/fix carries a type: matching its dir.
# Owns the no-frontmatter-fence report for specs/plans/fixes (other doc checks skip fenceless docs).
#   diagnose:  doc-type.sh <WOO_ROOT>
#   repair:    doc-type.sh --fix <WOO_ROOT> <file>   (type self-derived from the file's dir)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../woostack-init/scripts/lib.sh"
emit() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5"; }

# want_for <file> → expected type from the parent dir, empty/non-zero if not a doc dir.
want_for() {
  case "$1" in
    */.woostack/specs/*) echo spec ;;
    */.woostack/plans/*) echo plan ;;
    */.woostack/fixes/*) echo fix ;;
    *) return 1 ;;
  esac
}

if [ "${1:-}" = "--fix" ]; then
  root="$2"; file="$3"
  want="$(want_for "$file")" || exit 0
  set_field "$file" type "$want" || { emit error doc-type manual "${file#"$root"/}" "no frontmatter fence; add 'type: $want' manually"; exit 1; }
  [ "$(field "$file" type)" = "$want" ] || { emit error doc-type manual "${file#"$root"/}" "type: did not update to '$want'"; exit 1; }
  exit 0
fi
WOO_ROOT="${1:-.}"

shopt -s nullglob
for dir in specs plans fixes; do
  case "$dir" in specs) want=spec ;; plans) want=plan ;; fixes) want=fix ;; esac
  for f in "$WOO_ROOT/.woostack/$dir"/*.md; do
    rp="${f#"$WOO_ROOT"/}"
    if [ "$(head -1 "$f")" != "---" ]; then
      emit warn doc-type report "$rp" "no frontmatter fence; cannot read/repair type: (expected '$want')"
      continue
    fi
    t="$(field "$f" type)"
    [ "$t" = "$want" ] && continue
    emit warn doc-type auto "$rp" "type: '${t:-<missing>}' should be '$want' (dir implies it)"
  done
done
