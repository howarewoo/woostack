#!/usr/bin/env bash
# memory.sh — lint .woostack/memory; emit findings. Severities preserved from the
# original doctor.sh (errors = malformed/missing-field/unknown-type/dup-name; rest warn).
# All memory findings are fixable=report (content repair is woostack-dream's job).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../../woostack-init/scripts/lib.sh"
WOO_ROOT="${1:-.}"
MEM_DIR="$WOO_ROOT/.woostack/memory"
[ -d "$MEM_DIR" ] || exit 0

emit() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5"; }
err()  { emit error "$1" report "$2" "$3"; }
warn() { emit warn  "$1" report "$2" "$3"; }

VALID_TYPES=" decision pattern gotcha convention hotspot "
LINEAR_UUID_RE='[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}'
seen="$(mktemp)"; overlap_pairs="$(mktemp)"
paths="$(cd "$WOO_ROOT" && git ls-files 2>/dev/null || true)"

# Authenticated provider work is controller-owned. This check consumes only the one normalized,
# non-secret receipt copied by doctor.sh; failed preflight is already a controller finding.
linear_live_ready=0
live_context="${WOOSTACK_DOCTOR_LIVE_CONTEXT:-}"
if [ "${WOOSTACK_DOCTOR_LIVE:-0}" = 1 ] && [ -r "$live_context" ] &&
  jq -e 'type == "object" and .ready == true' "$live_context" >/dev/null 2>&1; then
  linear_live_ready=1
fi

shopt -s nullglob
for f in "$MEM_DIR"/*.md; do
  base="$(basename "$f")"; [ "$base" = "MEMORY.md" ] && continue
  rp=".woostack/memory/$base"
  if [ "$(head -1 "$f")" != "---" ]; then
    err memory-malformed "$rp" "$base: malformed — missing opening '---' frontmatter fence"; continue
  fi
  name="$(field "$f" name)"; type="$(field "$f" type)"
  body="$(note_body "$f" | tr -d '[:space:]')"
  [ -z "$name" ] && err memory-field "$rp" "$base: missing required field: name"
  [ -z "$type" ] && err memory-field "$rp" "$base: missing required field: type"
  [ -z "$body" ] && err memory-field "$rp" "$base: empty body"
  if [ -n "$type" ] && [ "${VALID_TYPES/ $type /}" = "$VALID_TYPES" ]; then
    err memory-type "$rp" "$base: unknown type: $type"
  fi
  if [ -n "$name" ]; then
    if grep -qxF "$name" "$seen"; then err memory-dup "$rp" "$base: duplicate name: $name"
    else echo "$name" >> "$seen"; fi
  fi
  scope="$(field "$f" scope)"
  if [ -n "$scope" ] && [ "$scope" != "*" ] && [ -n "$paths" ]; then
    matches="$(printf '%s\n' "$paths" | bash "$HERE/../../../woostack-init/scripts/scope-match.sh" "$scope" 2>/dev/null)"
    if [ -z "$matches" ]; then
      warn memory-scope-stale "$rp" "$base: scope '$scope' matches no tracked files (stale)"
    else
      while IFS= read -r p; do [ -n "$p" ] && printf '%s\t%s\n' "$p" "$base" >> "$overlap_pairs"; done <<< "$matches"
    fi
  fi
  source_raw="$(field "$f" source)"
  # Wikilinks resolve locally. Linear URI syntax is parsed locally too; live identity/relation
  # outcomes may come only from the controller's normalized host-MCP receipt.
  source_path="$source_raw"
  case "$source_raw" in
    '[['*']]')
      _wl="${source_raw#\[\[}"; _wl="${_wl%\]\]}"; _wl="${_wl%.md}"
      case "$_wl" in specs/*|plans/*|fixes/*) source_path=".woostack/$_wl.md" ;; esac
      ;;
    linear://*)
      if [[ ! "$source_raw" =~ ^linear://(project|document|issue)/($LINEAR_UUID_RE)$ ]]; then
        warn memory-provenance "$rp" "$base: source '$source_raw' is malformed (expected linear://project|document|issue/<uuid>)"
      else
        source_kind="${BASH_REMATCH[1]}"
        source_id="$(printf '%s' "${BASH_REMATCH[2]}" | tr '[:upper:]' '[:lower:]')"
        canonical_source="linear://$source_kind/$source_id"
        if [ "$linear_live_ready" -eq 1 ] && ! jq -e \
          --arg uri "$canonical_source" --arg kind "$source_kind" --arg id "$source_id" '
            . as $receipt
            | ($receipt.provenance | type == "object")
              and (($receipt.provenance[$uri] // null) as $entry
                | ($entry | type == "object")
                  and ($entry.verified == true)
                  and ($entry.managedIdentityVerified == true)
                  and ($entry.relationsVerified == true)
                  and ($entry.kind == $kind)
                  and (($entry.id | type) == "string")
                  and (($entry.id | ascii_downcase) == $id)
                  and ($entry.repository == $receipt.repository)
                  and ($entry.workspace == $receipt.workspace)
                  and ($entry.team == $receipt.team))
          ' "$live_context" >/dev/null 2>&1; then
          err memory-provenance-live "$rp" "$base: source '$source_raw' has a missing, partial, foreign, or drifted host-MCP provenance receipt"
        fi
      fi
      ;;
  esac
  case "$source_path" in
    .woostack/specs/*|.woostack/plans/*|.woostack/fixes/*)
      [ -f "$WOO_ROOT/$source_path" ] || warn memory-provenance "$rp" "$base: source '$source_path' is missing (stale provenance)" ;;
  esac
  [ -z "$source_raw" ] && warn memory-provenance "$rp" "$base: missing source: (provenance required)"
  case "$source_raw" in pr-*|address-comments) is_review=1 ;; *) is_review= ;; esac
  if [ -n "$scope" ] && [ "$scope" != "*" ] && [ -z "$is_review" ] && [ "${scope#*\*}" = "$scope" ]; then
    warn memory-scope-trivia "$rp" "$base: non-glob scope '$scope' (possible trivia — prefer a glob)"
  fi
  while IFS= read -r link; do
    [ -z "$link" ] && continue
    # Artifact wikilinks ([[specs|plans|fixes/<basename>]], optional trailing .md) resolve
    # against the vault root, not the memory dir — so a provenance source: wikilink is not a
    # false unresolved-link. Plain note-to-note links resolve in the memory dir as before.
    case "$link" in
      specs/*|plans/*|fixes/*)
        [ -f "$WOO_ROOT/.woostack/${link%.md}.md" ] || warn memory-unresolved-link "$rp" "$base: unresolved [[$link]]" ;;
      *)
        [ -f "$MEM_DIR/$link.md" ] || warn memory-unresolved-link "$rp" "$base: unresolved [[$link]]" ;;
    esac
  done < <(grep -oE '\[\[[^]]+\]\]' "$f" 2>/dev/null | sed 's/\[\[//; s/\]\]//' | sort -u)
  upd="$(field "$f" updated)"
  if [ -n "$upd" ]; then
    upd_e="$(_woo_epoch "$upd" || true)"
    if [ -n "$upd_e" ]; then
      now_e="$(_woo_epoch "$(_woo_now)")"
      rc="$(tel_get "$MEM_DIR" "$name" recall_count)"; rc="${rc:-0}"
      case "$rc" in (*[!0-9]*) rc=0 ;; esac
      age=$(( ( now_e - upd_e ) / 86400 ))
      if [ "$age" -gt "${WOOSTACK_DEAD_DAYS:-90}" ] && [ "$rc" -eq 0 ]; then
        warn memory-dead "$rp" "$base: dead note — written ${age}d ago, never recalled (prune candidate)"
      fi
    fi
  else
    warn memory-no-updated "$rp" "$base: missing updated: (cannot be aged — add updated:)"
  fi
done

if [ -s "$overlap_pairs" ]; then
  clusters="$(awk -F'\t' '
    function find(x,   r,t){ r=x; while(parent[r]!=r) r=parent[r];
      while(parent[x]!=x){ t=parent[x]; parent[x]=r; x=t } return r }
    function union(a,b,   ra,rb){ ra=find(a); rb=find(b); if(ra!=rb) parent[rb]=ra }
    { note=$2; if(!(note in parent)) parent[note]=note;
      f=$1; if(f in first) union(first[f], note); else first[f]=note }
    END{ for(n in parent){ r=find(n); if(!(r in mn) || n < mn[r]) mn[r]=n }
         for(n in parent){ r=find(n); print mn[r] "\t" n } }
  ' "$overlap_pairs" | sort -u | awk -F'\t' '
    { members[$1] = members[$1] (members[$1]==""?"":", ") $2; cnt[$1]++ }
    END{ for(c in cnt) if(cnt[c] >= 2) print c "\t" members[c] }
  ' | sort)"
  if [ -n "$clusters" ]; then
    while IFS="$(printf '\t')" read -r _cid _members; do
      [ -n "$_members" ] && warn memory-overlap ".woostack/memory" "overlap cluster: $_members — intersecting scope, review for contradiction"
    done <<< "$clusters"
  fi
fi
rm -f "$seen" "$overlap_pairs"
exit 0
