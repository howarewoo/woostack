#!/usr/bin/env bash
# status.sh - derived woostack feature board. Read-only: never fetches, commits,
# or pushes. Drift flags exit 0; only operational failures should exit non-zero.
# -e omitted intentionally: keep rendering past per-spec issues.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib.sh"

WOO_DIR="${WOO_DIR:-.woostack}"
SPEC_DIR="$WOO_DIR/specs"
PLAN_DIR="$WOO_DIR/plans"
GH_BIN="${WOOSTACK_GH:-gh}"
GIT_BIN="${WOOSTACK_GIT:-git}"
SHOW_ALL=0
DO_FETCH=0

for a in "$@"; do
  case "$a" in
    --all) SHOW_ALL=1 ;;
    --fetch) DO_FETCH=1 ;;
    -h|--help) echo "usage: status.sh [--all] [--fetch]"; exit 0 ;;
  esac
done

shopt -s nullglob
specs=( "$SPEC_DIR"/*.md )
if [ "${#specs[@]}" -eq 0 ]; then
  echo "woostack-status: no specs found in $SPEC_DIR - run /woostack-init or /woostack-build."
  exit 0
fi

FLAGS=""
SEEN_BRANCHES=""
VALID_PHASES=" draft hardened approved planning executing in-review done abandoned "

flag() { FLAGS="${FLAGS}  ! $1"$'\n'; }

have_gh() { command -v "$GH_BIN" >/dev/null 2>&1; }

gh_json() {
  have_gh || { echo ""; return; }
  "$GH_BIN" "$@" 2>/dev/null || echo ""
}

git_for() {
  "$GIT_BIN" "$@" 2>/dev/null
}

branch_ref() {
  local br="$1"
  [ -n "$br" ] || return 0
  if git_for rev-parse --verify --quiet "refs/heads/$br" >/dev/null; then
    printf '%s\n' "$br"
    return
  fi
  if git_for rev-parse --verify --quiet "refs/remotes/origin/$br" >/dev/null; then
    printf '%s\n' "origin/$br"
  fi
}

branch_has_commits() {
  local br="$1" ref base count
  ref="$(branch_ref "$br")"
  [ -n "$ref" ] || return 1
  for base in origin/main main origin/master master; do
    if git_for rev-parse --verify --quiet "$base" >/dev/null; then
      count="$(git_for rev-list --count "$base..$ref")"
      [ "${count:-0}" -gt 0 ]
      return
    fi
  done
  count="$(git_for rev-list --count "$ref")"
  [ "${count:-0}" -gt 0 ]
}

staleDays() {
  local cfg="$WOO_DIR/config.json" v=""
  if [ -f "$cfg" ]; then
    if command -v jq >/dev/null 2>&1; then
      v="$(jq -r '.status.staleDays // empty' "$cfg" 2>/dev/null)"
    else
      v="$(grep -oE '"staleDays"[[:space:]]*:[[:space:]]*[0-9]+' "$cfg" | grep -oE '[0-9]+$')"
    fi
  fi
  case "$v" in ''|*[!0-9]*) echo 14 ;; *) echo "$v" ;; esac
}

plan_for() {
  local base found slug specname p pbase pslug
  base="$(basename "$1")"
  found="$(grep -lE "^\*\*Source:\*\*[[:space:]].*specs/${base}([[:space:]]|$)" "$PLAN_DIR"/*.md 2>/dev/null || true)"
  if [ -n "$found" ]; then
    printf '%s\n' "$found"
    return
  fi

  slug="${base%.md}"
  slug="${slug#????-??-??-}"
  specname="$(field "$1" name)"
  for p in "$PLAN_DIR"/*.md; do
    [ -e "$p" ] || continue
    pbase="$(basename "$p" .md)"
    pslug="${pbase#????-??-??-}"
    if [ "$pslug" = "$slug" ] || { [ -n "$specname" ] && [ "$pslug" = "$specname" ]; }; then
      printf '%s\n' "$p"
    fi
  done
}

plan_progress() {
  local d t
  d="$(grep -cE '^[[:space:]]*- \[[xX]\]' "$1" 2>/dev/null || true)"
  t="$(grep -cE '^[[:space:]]*- \[[ xX]\]' "$1" 2>/dev/null || true)"
  echo "${d:-0} ${t:-0}"
}

prs_for_spec() {
  local base json
  base="$(basename "$1")"
  json="$(gh_json pr list --state all --search "$base" \
          --json number,state,headRefName,author,updatedAt,body --limit 50)"
  [ -n "$json" ] || return 0
  # gh --search is fuzzy (tokenizes the path), so it cross-matches look-alike PRs. Narrow
  # with the search, then exact-match a Spec: trailer value in each PR body. The needle
  # `specs/<basename>` is WOO_DIR-independent and unique per spec (date-stamped name), so an
  # untrailered, sibling, suffixed, or prose-only mention can no longer attach to the wrong spec.
  printf '%s' "$json" | jq -r --arg needle "specs/$base" \
    '.[] | select((.body // "") | split("\n") | any(
            test("^[[:space:]]*Spec:[[:space:]]")
            and (sub("^[[:space:]]*Spec:[[:space:]]*"; "") | gsub("[[:space:]]+$"; "") | endswith($needle))
          ))
        | [.number, .state, .headRefName, (.author.login // ""), .updatedAt] | @tsv' 2>/dev/null
}

prs_for_branch() {
  local branch="$1" json
  [ -n "$branch" ] || return 0
  json="$(gh_json pr list --state all --head "$branch" \
          --json number,state,headRefName,author,updatedAt --limit 20)"
  [ -n "$json" ] || return 0
  printf '%s' "$json" | jq -r \
    '.[] | [.number, .state, .headRefName, (.author.login // ""), .updatedAt] | @tsv' 2>/dev/null
}

resolve_phase() {
  local authored="$1" hasPlan="$2" frac="$3" open="$4" merged="$5" prcount="$6" branchExists="$7" hasCommits="$8"
  if [ "$open" -gt 0 ]; then echo "in-review"; return; fi
  if [ "$frac" = "100" ] && [ "$merged" -gt 0 ] && [ "$merged" -eq "$prcount" ]; then echo "done"; return; fi
  # Legacy/untrailered features have no discoverable PR, so the rule above can't confirm
  # done. Trust an explicit authored `done` only when the plan is 100% complete, no
  # increment PR was found, and no active branch work is visible; discovered increments
  # still have to satisfy the merged==prcount rule above, so a closed-unmerged PR keeps the
  # feature visible.
  if [ "$authored" = "done" ] && [ "$frac" = "100" ] && [ "$prcount" -eq 0 ] &&
     [ "$branchExists" -eq 0 ] && [ "$hasCommits" -eq 0 ]; then echo "done"; return; fi
  if [ "$hasPlan" -eq 1 ] && [ "$frac" -gt 0 ] && [ "$frac" -lt 100 ] && [ "$hasCommits" -eq 1 ]; then
    echo "executing"
    return
  fi
  case "$authored" in
    executing|in-review|done)
      if [ "$hasPlan" -eq 1 ] || [ "$branchExists" -eq 1 ] || [ "$hasCommits" -eq 1 ]; then
        echo "executing"
      else
        echo "$authored"
      fi
      ;;
    *) echo "$authored" ;;
  esac
}

next_action() {
  case "$1" in
    draft)      echo "run grill-me on the spec" ;;
    hardened)   echo "get spec approval (hard gate)" ;;
    approved)   echo "write the plan (writing-plans)" ;;
    planning)   echo "decompose to increments, then execute" ;;
    executing)  if [ "${5:-0}" -gt 0 ]; then echo "finish plan ($2/$3); $4/$5 increments shipped";
                else echo "finish plan ($2/$3) - open first increment PR"; fi ;;
    in-review)  echo "address comments / merge when green" ;;
    done)       echo "-" ;;
    abandoned)  echo "-" ;;
    *)          echo "set status: (unknown phase)" ;;
  esac
}

spec_git_owner() { git_for log -1 --format='%an' -- "$1"; }
spec_git_date()  { git_for log -1 --format='%ad' --date=short -- "$1"; }

age_days() {
  local e n
  e="$(_woo_epoch "$1" 2>/dev/null)" || return 0
  n="$(_woo_epoch "$(_woo_now)")" || return 0
  echo $(( (n - e) / 86400 ))
}

row_has() {
  case "$1" in ''|*[!0-9]*) return 1 ;; *) return 0 ;; esac
}

gh_missing=0
have_gh || gh_missing=1
if [ "$DO_FETCH" -eq 1 ]; then
  have_gh && "$GH_BIN" repo set-default >/dev/null 2>&1
  "$GIT_BIN" fetch --quiet 2>/dev/null || true
fi

done_count=0
abandoned_count=0
rows=""

for f in "${specs[@]}"; do
  name="$(field "$f" name)"; [ -n "$name" ] || name="$(basename "$f" .md)"
  phase="$(field "$f" status)"; [ -n "$phase" ] || phase="unknown"
  raw_phase="$phase"

  if [ "${VALID_PHASES/ $phase /}" = "$VALID_PHASES" ]; then
    flag "$name: '$phase' is not a known phase - unknown phase, set a valid status:"
    phase="unknown"
  fi

  plans=()
  while IFS= read -r ln; do [ -n "$ln" ] && plans+=("$ln"); done < <(plan_for "$f")
  plan_cell="-"; done=0; total=0; planfile=""
  if [ "${#plans[@]}" -eq 0 ]; then
    case "$phase" in draft|hardened|approved|abandoned) : ;; *) flag "$name: no plan resolves to this spec (writing-plans)" ;; esac
  elif [ "${#plans[@]}" -ge 2 ]; then
    flag "$name: ${#plans[@]} plans resolve to this spec - spec<->plan must be 1:1"
    planfile="${plans[0]}"
  else
    planfile="${plans[0]}"
  fi
  if [ -n "$planfile" ]; then
    read -r done total < <(plan_progress "$planfile")
    [ "$total" -gt 0 ] && plan_cell="$done/$total"
  fi

  specpath="$WOO_DIR/specs/$(basename "$f")"
  br="$(field "$f" branch)"
  open=0; merged=0; prcount=0; inc_cell="-"; inc_parts=""
  last_author=""; last_upd_date=""
  while IFS=$'\t' read -r num state head author upd; do
    [ -z "$num" ] && continue
    prcount=$((prcount+1))
    case "$state" in OPEN) open=$((open+1)) ;; MERGED) merged=$((merged+1)) ;; esac
    mark="."; case "$state" in MERGED) mark="merged" ;; OPEN) mark="open" ;; CLOSED) mark="closed" ;; esac
    inc_parts="${inc_parts:+$inc_parts . }#$num $mark"
    last_author="$author"; last_upd_date="${upd:0:10}"
  done < <(prs_for_spec "$specpath")

  if [ "$prcount" -eq 0 ] && [ -n "$br" ] && [ "$br" != unknown ]; then
    while IFS=$'\t' read -r num state head author upd; do
      [ -z "$num" ] && continue
      prcount=$((prcount+1))
      case "$state" in OPEN) open=$((open+1)) ;; MERGED) merged=$((merged+1)) ;; esac
      inc_cell="#$num (partial)"
      last_author="$author"; last_upd_date="${upd:0:10}"
    done < <(prs_for_branch "$br")
  fi
  [ -n "$inc_parts" ] && inc_cell="$inc_parts"

  frac=0; [ "$total" -gt 0 ] && frac=$(( done * 100 / total ))
  hasPlan=0; [ -n "$planfile" ] && hasPlan=1
  branchExists=0; hasCommits=0
  if [ -n "$br" ] && [ "$br" != unknown ]; then
    [ -n "$(branch_ref "$br")" ] && branchExists=1
    branch_has_commits "$br" && hasCommits=1
  fi
  eff="$(resolve_phase "$phase" "$hasPlan" "$frac" "$open" "$merged" "$prcount" "$branchExists" "$hasCommits")"

  if [ -z "$br" ] || [ "$br" = unknown ]; then
    case "$eff" in executing|in-review|done) flag "$name: branch is '${br:-empty}' - set branch:" ;; esac
    [ "$br" = unknown ] && flag "$name: branch is 'unknown' - set branch: in frontmatter"
  fi

  case "$phase" in
    draft|hardened|approved|planning)
      [ "$prcount" -gt 0 ] && flag "$name: status lags - phase '$phase' but a PR already exists" ;;
  esac

  if [ -n "$br" ] && [ "$br" != unknown ]; then
    if printf '%s' "$SEEN_BRANCHES" | grep -qx "$br"; then
      flag "$name: branch '$br' also claimed by another spec (collision)"
    fi
    SEEN_BRANCHES="${SEEN_BRANCHES}${br}"$'\n'
  fi

  owner=""; agecell=""
  if [ "$prcount" -gt 0 ] && [ -n "$last_author" ]; then
    owner="$last_author"
    d="$(age_days "$last_upd_date")"; [ -n "$d" ] && agecell="${d}d"
  else
    owner="$(spec_git_owner "$f")"
    sd="$(spec_git_date "$f")"
    if [ -n "$sd" ]; then d="$(age_days "$sd")"; [ -n "$d" ] && agecell="${d}d"; fi
  fi

  if [ -n "$agecell" ]; then
    dnum="${agecell%d}"
    row_has "$dnum" && [ "$dnum" -gt "$(staleDays)" ] && [ "$eff" = executing ] \
      && flag "$name: stale - ${dnum}d since last activity"
  fi

  row="$(printf '%-22s %-10s %-7s %-20s %-7s %-5s %s' \
    "$name" "$eff" "$plan_cell" "$inc_cell" "$owner" "$agecell" \
    "$(next_action "$eff" "$done" "$total" "$merged" "$prcount")")"
  case "$eff" in
    done) done_count=$((done_count+1)) ;;
    abandoned) abandoned_count=$((abandoned_count+1)) ;;
    *) rows="${rows}${row}"$'\n' ;;
  esac
  if [ "$SHOW_ALL" -eq 1 ]; then
    case "$eff" in done|abandoned) rows="${rows}${row}"$'\n' ;; esac
  fi
done

printf '%-22s %-10s %-7s %-20s %-7s %-5s %s\n' SPEC PHASE PLAN INCREMENTS OWNER AGE NEXT
printf '%s' "$rows"
[ -n "$FLAGS" ] && printf '\n! FLAGS\n%s' "$FLAGS"
printf '\n%d done . %d abandoned' "$done_count" "$abandoned_count"
[ "$SHOW_ALL" -eq 0 ] && printf '   (--all to expand)'
[ "$gh_missing" -eq 1 ] && printf '\nnote: gh not found - PR/increment/owner data omitted for PR-phase rows'
[ "$DO_FETCH" -eq 0 ] && printf '\nnote: PR-less branch data may be stale; pass --fetch to refresh'
printf '\n'
exit 0
