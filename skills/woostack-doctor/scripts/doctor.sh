#!/usr/bin/env bash
# doctor.sh — lint the memory/ dir. Warnings exit 0; errors exit 1.
# -e intentionally omitted: a linter must continue past per-note failures
# to report every error in one run, not abort on the first.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../woostack-init/scripts/lib.sh"

MEM_DIR="${1:-.woostack/memory}"
VALID_TYPES=" decision pattern gotcha convention hotspot "
errors=0; warnings=0
seen="$(mktemp)"
overlap_pairs="$(mktemp)"
paths="$(git ls-files 2>/dev/null || true)"

err()  { echo "::error:: $1" >&2; errors=$((errors+1)); }
warn() { echo "::warning:: $1" >&2; warnings=$((warnings+1)); }

shopt -s nullglob
for f in "$MEM_DIR"/*.md; do
  base="$(basename "$f")"
  [ "$base" = "MEMORY.md" ] && continue

  if [ "$(head -1 "$f")" != "---" ]; then
    err "$base: malformed — missing opening '---' frontmatter fence"; continue
  fi

  name="$(field "$f" name)"; type="$(field "$f" type)"
  body="$(note_body "$f" | tr -d '[:space:]')"

  [ -z "$name" ] && err "$base: missing required field: name"
  [ -z "$type" ] && err "$base: missing required field: type"
  [ -z "$body" ] && err "$base: empty body"
  if [ -n "$type" ] && [ "${VALID_TYPES/ $type /}" = "$VALID_TYPES" ]; then
    err "$base: unknown type: $type"
  fi

  if [ -n "$name" ]; then
    if grep -qxF "$name" "$seen"; then err "$base: duplicate name: $name"
    else echo "$name" >> "$seen"; fi
  fi

  scope="$(field "$f" scope)"
  if [ -n "$scope" ] && [ "$scope" != "*" ] && [ -n "$paths" ]; then
    matches="$(printf '%s\n' "$paths" | bash "$HERE/../../woostack-init/scripts/scope-match.sh" "$scope" 2>/dev/null)"
    if [ -z "$matches" ]; then
      warn "$base: scope '$scope' matches no tracked files (stale)"
    else
      while IFS= read -r p; do
        [ -n "$p" ] && printf '%s\t%s\n' "$p" "$base" >> "$overlap_pairs"
      done <<< "$matches"
    fi
  fi

  source_path="$(field "$f" source)"
  case "$source_path" in
    .woostack/specs/*|.woostack/plans/*)
      [ -f "$source_path" ] || warn "$base: source '$source_path' is missing (stale provenance)"
      ;;
  esac

  # Distillation gate: every note needs provenance (§7).
  [ -z "$source_path" ] && warn "$base: missing source: (provenance required)"

  # Non-glob scope = trivia signal. Exempt global (*) and review-provenance notes
  # (review records deliberately scope narrowly to suppress an accepted finding).
  case "$source_path" in pr-*|address-comments) is_review=1 ;; *) is_review= ;; esac
  if [ -n "$scope" ] && [ "$scope" != "*" ] && [ -z "$is_review" ] && [ "${scope#*\*}" = "$scope" ]; then
    warn "$base: non-glob scope '$scope' (possible trivia — prefer a glob)"
  fi

  while IFS= read -r link; do
    [ -z "$link" ] && continue
    [ -f "$MEM_DIR/$link.md" ] || warn "$base: unresolved [[$link]]"
  done < <(grep -oE '\[\[[^]]+\]\]' "$f" 2>/dev/null | sed 's/\[\[//; s/\]\]//' | sort -u)

  # Dead-note signal: old (by updated:) AND never recalled → prune candidate.
  # Requires updated: (no age basis otherwise). Warning only.
  upd="$(field "$f" updated)"
  if [ -n "$upd" ]; then
    upd_e="$(_woo_epoch "$upd" || true)"
    if [ -n "$upd_e" ]; then
      now_e="$(_woo_epoch "$(_woo_now)")"
      rc="$(tel_get "$MEM_DIR" "$name" recall_count)"; rc="${rc:-0}"
      case "$rc" in (*[!0-9]*) rc=0 ;; esac
      age=$(( ( now_e - upd_e ) / 86400 ))
      if [ "$age" -gt "${WOOSTACK_DEAD_DAYS:-90}" ] && [ "$rc" -eq 0 ]; then
        warn "$base: dead note — written ${age}d ago, never recalled (prune candidate)"
      fi
    fi
  else
    warn "$base: missing updated: (cannot be aged — add updated:)"
  fi
done

# Overlap clusters: non-global notes sharing >=1 tracked file. awk union-find,
# canonical cluster id = lexicographically smallest member name (deterministic
# output regardless of git ls-files / glob ordering). Warning-only.
if [ -s "$overlap_pairs" ]; then
  # union-find (awk owns the assoc arrays — bash 3.2 has no `declare -A`),
  # then group by canonical id and keep clusters of >=2 members.
  clusters="$(awk -F'\t' '
    function find(x,   r,t){ r=x; while(parent[r]!=r) r=parent[r];
      while(parent[x]!=x){ t=parent[x]; parent[x]=r; x=t } return r }
    function union(a,b,   ra,rb){ ra=find(a); rb=find(b); if(ra!=rb) parent[rb]=ra }
    { note=$2; if(!(note in parent)) parent[note]=note;
      f=$1; if(f in first) union(first[f], note); else first[f]=note }
    END{
      for(n in parent){ r=find(n); if(!(r in mn) || n < mn[r]) mn[r]=n }
      for(n in parent){ r=find(n); print mn[r] "\t" n }
    }
  ' "$overlap_pairs" | sort -u | awk -F'\t' '
    { members[$1] = members[$1] (members[$1]==""?"":", ") $2; cnt[$1]++ }
    END{ for(c in cnt) if(cnt[c] >= 2) print c "\t" members[c] }
  ' | sort)"
  # Loop in the main shell (here-string, not a pipeline) so warn's counter sticks.
  if [ -n "$clusters" ]; then
    while IFS="$(printf '\t')" read -r _cid _members; do
      [ -n "$_members" ] && warn "overlap cluster: $_members — intersecting scope, review for contradiction"
    done <<< "$clusters"
  fi
fi

rm -f "$seen" "$overlap_pairs"

echo "doctor: $errors error(s), $warnings warning(s)" >&2
[ "$errors" -eq 0 ]
