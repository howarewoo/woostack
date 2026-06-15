#!/usr/bin/env bash
# plan-source.sh — plans carry the canonical **Source:** join line, and source: frontmatter
# names the same spec. Three codes:
#   plan-source       missing **Source:** line  (auto when source: resolves to a spec, else report)
#   plan-source-sync  source: basename != line basename  (auto: sync source: ← the line)
#   plan-source-link  **Source:** line is a legacy bare-path, not the [[specs/x]] wikilink (auto)
#   diagnose:  plan-source.sh <WOO_ROOT>
#   repair:    plan-source.sh --fix <WOO_ROOT> <plan> source-line
#              plan-source.sh --fix <WOO_ROOT> <plan> source-sync
#              plan-source.sh --fix <WOO_ROOT> <plan> source-link
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../woostack-init/scripts/lib.sh"
emit() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5"; }

# basename_of <ref> — reduce any Source reference form to bare <basename>:
#   .woostack/specs/x.md | specs/x.md | specs/x | [[specs/x]] | any of these + trailing text
basename_of() {
  local s="$1"
  s="${s##*specs/}"; s="${s%%]*}"; s="${s%% *}"; s="${s%.md}"
  printf '%s\n' "$s"
}
# line_base <plan> — basename named by the **Source:** line, empty if none.
line_base() {
  local raw tok
  raw="$(grep -m1 -E '^\*\*Source:\*\*' "$1" 2>/dev/null)"; [ -z "$raw" ] && return 0
  tok="$(printf '%s' "$raw" | grep -oE 'specs/[A-Za-z0-9._-]+' | head -1)"; [ -z "$tok" ] && return 0
  basename_of "$tok"
}

if [ "${1:-}" = "--fix" ]; then
  root="$2"; plan="$3"; mode="$4"
  case "$mode" in
    source-line)
      grep -qE '^\*\*Source:\*\*' "$plan" && exit 0       # already present → no-op
      base="$(basename_of "$(field "$plan" source)")"
      [ -z "$base" ] && { emit warn plan-source report "${plan#"$root"/}" "no source: frontmatter to derive the **Source:** line"; exit 1; }
      [ -f "$root/.woostack/specs/$base.md" ] || { emit warn plan-source report "${plan#"$root"/}" "source: names 'specs/$base' but no such spec exists; resolve manually"; exit 1; }
      awk -v line="**Source:** [[specs/$base]]" '
        {print}
        f==0 && /^---$/{c++; if(c==2){print ""; print line; f=1}}' "$plan" > "$plan.t" && mv "$plan.t" "$plan" || { rm -f "$plan.t"; emit error plan-source manual "${plan#"$root"/}" "could not rewrite the plan to insert the **Source:** line"; exit 1; }
      grep -qE '^\*\*Source:\*\*' "$plan" || { emit error plan-source manual "${plan#"$root"/}" "no closing frontmatter fence to anchor the **Source:** line; add it manually"; exit 1; }
      exit 0 ;;
    source-sync)
      lb="$(line_base "$plan")"; [ -z "$lb" ] && exit 0
      set_field "$plan" source ".woostack/specs/$lb.md" || { emit error plan-source-sync manual "${plan#"$root"/}" "no frontmatter fence; set source: manually"; exit 1; }
      [ "$(basename_of "$(field "$plan" source)")" = "$lb" ] || { emit error plan-source-sync manual "${plan#"$root"/}" "source: did not sync to '$lb'"; exit 1; }   # phantom-repair guard (spec §6)
      exit 0 ;;
    source-link)
      grep -E '^\*\*Source:\*\*' "$plan" | grep -qF '[[specs/' && exit 0   # already a wikilink → no-op
      lb="$(line_base "$plan")"; [ -z "$lb" ] && exit 0                     # no **Source:** line → nothing to canonicalize
      # Replace only the path token on the **Source:** line; preserve the prefix and any trailing text.
      awk -v lb="$lb" '
        d==0 && /^\*\*Source:\*\*/ { sub(/(\.woostack\/)?specs\/[A-Za-z0-9._-]+(\.md)?/, "[[specs/" lb "]]"); d=1 }
        {print}' "$plan" > "$plan.t" && mv "$plan.t" "$plan" || { rm -f "$plan.t"; emit error plan-source-link manual "${plan#"$root"/}" "could not rewrite the **Source:** line"; exit 1; }
      grep -E '^\*\*Source:\*\*' "$plan" | grep -qF "[[specs/$lb]]" || { emit error plan-source-link manual "${plan#"$root"/}" "**Source:** line did not canonicalize to [[specs/$lb]]"; exit 1; }   # phantom-repair guard
      exit 0 ;;
    *) exit 2 ;;
  esac
fi
WOO_ROOT="${1:-.}"

shopt -s nullglob
for plan in "$WOO_ROOT/.woostack/plans"/*.md; do
  rp="${plan#"$WOO_ROOT"/}"
  lb="$(line_base "$plan")"
  if [ -z "$lb" ]; then
    sbase="$(basename_of "$(field "$plan" source)")"
    if [ -n "$sbase" ] && [ -f "$WOO_ROOT/.woostack/specs/$sbase.md" ]; then
      emit warn plan-source auto "$rp" "missing **Source:** line; derive [[specs/$sbase]] from source: frontmatter"
    else
      emit warn plan-source report "$rp" "missing **Source:** line and no source: frontmatter resolving to a spec to derive from"
    fi
    continue
  fi
  # The **Source:** line exists (lb non-empty). Its canonical form is the [[specs/<basename>]]
  # wikilink — symmetric with the spec's [[plans/<basename>]] backlink, so the Obsidian graph
  # links both ways. A legacy bare-path line still resolves (basename_of accepts it), so this is
  # a gated nudge toward the wikilink, never a CI break.
  case "$(grep -m1 -E '^\*\*Source:\*\*' "$plan")" in
    *"[[specs/"*) : ;;
    *) emit warn plan-source-link auto "$rp" "**Source:** line uses a legacy bare-path; canonicalize to the [[specs/$lb]] wikilink" ;;
  esac
  sbase="$(basename_of "$(field "$plan" source)")"
  if [ -n "$sbase" ] && [ "$sbase" != "$lb" ]; then
    emit warn plan-source-sync auto "$rp" "source: names '$sbase' but **Source:** line names '$lb'; sync source: to the canonical line"
  elif [ -z "$sbase" ]; then
    emit warn plan-source-sync auto "$rp" "**Source:** line names '$lb' but source: frontmatter is absent; sync source: from the line"
  fi
done
