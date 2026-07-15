#!/usr/bin/env bash
# status.sh - derived woostack feature board. Markdown stays read-only. Linear
# mode authenticates, reconciles only merge-backed terminal transitions, and
# verifies every write before rendering. Operational failures exit non-zero.
# -e omitted intentionally: keep rendering past per-spec Markdown issues.
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
NO_OPEN=0

fail_status() {
  printf 'woostack-status: %s\n' "$1" >&2
  exit 1
}

for a in "$@"; do
  case "$a" in
    --all) SHOW_ALL=1 ;;
    --fetch) DO_FETCH=1 ;;
    --no-open) NO_OPEN=1 ;;
    -h|--help) echo "usage: status.sh [--all] [--fetch] [--no-open]"; exit 0 ;;
  esac
done

command -v jq >/dev/null 2>&1 || fail_status "jq is required for artifact adapters"
REPO_ROOT="$(cd "$(dirname "$WOO_DIR")" 2>/dev/null && pwd -P)" \
  || fail_status "repository root is unavailable"
artifact_backend_init "$REPO_ROOT" || fail_status "artifact backend resolution failed"

shopt -s nullglob
specs=()
if [ "$WOO_ARTIFACT_BACKEND" = markdown ]; then
  specs=( "$SPEC_DIR"/*.md "$WOO_DIR"/fixes/*.md )
  if [ "${#specs[@]}" -eq 0 ]; then
    echo "woostack-status: no specs or fixes found in $SPEC_DIR or $WOO_DIR/fixes - run /woostack-init, /woostack-build, or /woostack-fix."
    exit 0
  fi
fi

FLAGS=""
SEEN_BRANCHES=""
VALID_PHASES=" draft hardened approved planning ready executing in-review done abandoned "

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
  local base found slug specname p pbase pslug nomd
  base="$(basename "$1")"
  # The **Source:** line may be a bare path (`.woostack/specs/<base>.md`) or an Obsidian
  # wikilink (`[[specs/<base>]]`, no `.md`). Match `specs/<slug>` with an optional `.md` and a
  # `]`/space/EOL right boundary — the boundary preserves the exact-slug guarantee (`…-foo`
  # never matches `…-foo-bar`).
  nomd="${base%.md}"
  found="$(grep -lE "^\*\*Source:\*\*[[:space:]].*specs/${nomd}(\.md)?(\]|[[:space:]]|$)" "$PLAN_DIR"/*.md 2>/dev/null || true)"
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
  # Count task checkboxes, but NOT example boxes inside fenced code blocks
  # (a plan that embeds a template/SKILL.md literal carries `- [ ]` lines that
  # are content, not tasks). Fence rule (CommonMark): an opening fence is a run
  # of >=3 backticks; the close must be a run >= the opening length, so the
  # inner ``` of an embedded block never closes its enclosing ```` fence.
  awk '
    BEGIN { d=0; t=0; infence=0; flen=0 }
    {
      s=$0; sub(/^[[:space:]]+/,"",s)
      if (substr(s,1,3)=="```") {
        run=0; while (substr(s,run+1,1)=="`") run++
        if (infence==0) { infence=1; flen=run }
        else if (run>=flen) { infence=0; flen=0 }
        next
      }
      if (infence) next
      if ($0 ~ /^[[:space:]]*- \[[ xX]\]/) {
        t++
        if ($0 ~ /^[[:space:]]*- \[[xX]\]/) d++
      }
    }
    END { printf "%d %d\n", d, t }
  ' "$1" 2>/dev/null || echo "0 0"
}

prs_for_spec() {
  local base suffix json
  base="$(basename "$1")"
  if [[ "$1" == *"/fixes/"* ]]; then
    suffix="fixes/$base"
  else
    suffix="specs/$base"
  fi
  json="$(gh_json pr list --state all --search "$base" \
          --json number,state,headRefName,author,updatedAt,body,url --limit 50)"
  [ -n "$json" ] || return 0
  # gh --search is fuzzy (tokenizes the path), so it cross-matches look-alike PRs. Narrow
  # with the search, then exact-match a Spec: trailer value in each PR body. The needle
  # `specs/<basename>` or `fixes/<basename>` is WOO_DIR-independent and unique per spec, so an
  # untrailered, sibling, suffixed, or prose-only mention can no longer attach to the wrong spec.
  printf '%s' "$json" | jq -r --arg needle "$suffix" \
    '.[] | select((.body // "") | split("\n") | any(
            test("^[[:space:]]*Spec:[[:space:]]")
            and (sub("^[[:space:]]*Spec:[[:space:]]*"; "") | gsub("[[:space:]]+$"; "") | endswith($needle))
          ))
        | [.number, .state, .headRefName, (.author.login // ""), .updatedAt, (.url // "")] | @tsv' 2>/dev/null
}

prs_for_branch() {
  local branch="$1" json
  [ -n "$branch" ] || return 0
  json="$(gh_json pr list --state all --head "$branch" \
          --json number,state,headRefName,author,updatedAt,url --limit 20)"
  [ -n "$json" ] || return 0
  printf '%s' "$json" | jq -r \
    '.[] | [.number, .state, .headRefName, (.author.login // ""), .updatedAt, (.url // "")] | @tsv' 2>/dev/null
}

resolve_phase() {
  local authored="$1" hasPlan="$2" frac="$3" open="$4" merged="$5" prcount="$6" branchExists="$7" hasCommits="$8" total="${9:-0}"
  # A CLOSED (unmerged) PR is workflow noise: judge completeness against active PRs only
  # (open + merged) so a closed increment neither blocks done nor inflates the tally. The
  # prcount==0 legacy paths below intentionally stay keyed on prcount. The
  # merged==active_prcount checks below are deliberately kept even though the open>0 early
  # return makes them always-true today: they are the executable statement of the
  # "all active PRs merged" invariant, robust to a future reordering of that return.
  local active_prcount=$((open + merged))
  if [ "$open" -gt 0 ]; then echo "in-review"; return; fi
  # An authored `abandoned` is a terminal human decision: never override it with
  # artifact-derived done (stale executing/in-review/done fields are still advanced).
  if [ "$authored" != "abandoned" ] && [ "$frac" = "100" ] && [ "$merged" -gt 0 ] && [ "$merged" -eq "$active_prcount" ]; then echo "done"; return; fi
  # A zero-checkbox plan carries no progress signal (frac stays 0, so the rules
  # above and below can never confirm done). Trust an explicit authored done when
  # at least one active increment PR is merged (a closed-unmerged PR is noise and does not
  # block done), or — mirroring the legacy rule below — when nothing was discovered.
  if [ "$authored" = "done" ] && [ "$total" -eq 0 ]; then
    if [ "$merged" -gt 0 ] && [ "$merged" -eq "$active_prcount" ]; then echo "done"; return; fi
    if [ "$prcount" -eq 0 ] && [ "$hasCommits" -eq 0 ]; then echo "done"; return; fi
  fi
  # Legacy/untrailered features have no discoverable PR, so the rule above can't confirm
  # done. Trust an explicit authored `done` only when the plan is 100% complete, no
  # increment PR was found, and no active branch commits are visible; discovered increments
  # are judged by the merged==active_prcount rule above, where a closed-unmerged PR is
  # noise rather than a blocker.
  if [ "$authored" = "done" ] && [ "$frac" = "100" ] && [ "$prcount" -eq 0 ] &&
     [ "$hasCommits" -eq 0 ]; then echo "done"; return; fi
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
  local phase="$1" done="${2:-0}" total="${3:-0}" merged="${4:-0}" prcount="${5:-0}" file="${6:-}"
  if [[ "$file" == *"/fixes/"* ]]; then
    case "$phase" in
      draft)      echo "harden the fix plan (woostack-harden)" ;;
      hardened)   echo "review committed fix plan and approve execution (hard gate)" ;;
      approved)   echo "execute the fix (woostack-fix)" ;;
      executing)  if [ "$prcount" -gt 0 ]; then echo "finish fix ($done/$total); $merged/$prcount increments shipped";
                  else echo "finish fix ($done/$total) - open the fix PR"; fi ;;
      in-review)  echo "address comments / merge when green" ;;
      done)       echo "-" ;;
      abandoned)  echo "-" ;;
      *)          echo "set status: (unknown phase)" ;;
    esac
    return
  fi
  case "$phase" in
    draft)      echo "harden the spec (woostack-harden)" ;;
    hardened)   echo "get spec approval (hard gate)" ;;
    approved)   echo "write the plan (woostack-plan)" ;;
    planning)   echo "harden the plan (woostack-harden)" ;;
    ready)      echo "open spec+plan PR, then execute (woostack-execute)" ;;
    executing)  if [ "$prcount" -gt 0 ]; then echo "finish plan ($done/$total); $merged/$prcount increments shipped";
                else echo "finish plan ($done/$total) - open first increment PR"; fi ;;
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

html_escape() {
  local s="$1"
  s="${s//&/&amp;}"; s="${s//</&lt;}"; s="${s//>/&gt;}"; s="${s//\"/&quot;}"
  printf '%s' "$s"
}

terminal_safe() {
  jq -Rrs 'gsub("[\u0000-\u001f\u007f-\u009f]"; "")' <<<"$1"
}

chip() {
  local mark="$1" num="$2" label="$3" url="${4:-}"
  if [ -n "$url" ]; then
    printf '<a class="chip c-%s" href="%s" target="_blank" rel="noopener noreferrer">#%s %s</a>' \
      "$mark" "$(html_escape "$url")" "$num" "$label"
  else
    printf '<span class="chip c-%s">#%s %s</span>' "$mark" "$num" "$label"
  fi
}

linear_pr_evidence() {
  local repository="$1" referenced="$2" raw parsed
  have_gh || fail_status "gh is required to verify Linear pull request state"
  if ! raw="$("$GH_BIN" api --paginate --slurp \
    "repos/$repository/pulls?state=all&per_page=100" 2>/dev/null)"; then
    fail_status "paginated GitHub pull request query failed"
  fi
  if ! parsed="$(jq -c --arg repository "$repository" --argjson referenced "$referenced" '
    def trailers($name):
      ((.body // "") | split("\n") |
        map(select(test("^[[:space:]]*" + $name + ":[[:space:]]*")) |
          sub("^[[:space:]]*" + $name + ":[[:space:]]*"; "") |
          gsub("[[:space:]]+$"; "")));
    (if all(.[]; type=="array") then (add // []) else . end) |
    map({
      number:.number,
      state:(if (.mergedAt // .merged_at) != null then "MERGED"
             elif ((.state // "")|ascii_downcase)=="open" then "OPEN"
             else "CLOSED" end),
      url:(.html_url // .url),
      mergedAt:(.mergedAt // .merged_at),
      updatedAt:(.updatedAt // .updated_at),
      author:(.author // {login:(.user.login // "")}),
      body:(.body // "")
    }) |
    map(select(.url as $url | $referenced | index($url))) |
    [
      .[] |
      (trailers("Linear-Project")) as $projects |
      (trailers("Linear-Issue")) as $issues |
      if (($projects|length)==0 and ($issues|length)==0) then empty
      elif (($projects|length)==1 and ($issues|length)==1) then
        if (
          ($projects[0] | test("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$")) and
          ($issues[0] | test("^[A-Z][A-Z0-9]*-[1-9][0-9]*$")) and
          (.url == ("https://github.com/" + $repository + "/pull/" + (.number|tostring))) and
          (.state=="OPEN" or .state=="CLOSED" or .state=="MERGED") and
          ((.state=="MERGED" and .mergedAt!=null) or (.state!="MERGED" and .mergedAt==null))
        ) then {
          projectId:$projects[0],
          issueIdentifier:$issues[0],
          url:.url,
          merged:(.state=="MERGED"),
          number:.number,
          author:(.author.login // ""),
          updatedAt:.updatedAt
        } else error("invalid Linear trailer or PR state") end
      else error("ambiguous Linear trailers") end
    ]
  ' <<<"$raw" 2>/dev/null)"; then
    fail_status "Linear pull request trailers are ambiguous or invalid"
  fi
  printf '%s\n' "$parsed"
}

linear_preflight() {
  local linear
  [[ -n "${LINEAR_API_KEY:-}" ]] || fail_status "LINEAR_API_KEY is required for Linear status"
  linear="$(jq -c '.linear' <<<"$WOO_BACKEND_CONFIG")"
  linear_adapter preflight \
    --workspace "$(jq -r '.workspace' <<<"$linear")" \
    --team "$(jq -r '.team' <<<"$linear")" \
    --project-statuses "$(jq -c '.projectStatuses' <<<"$linear")" \
    --issue-states "$(jq -c '.issueStates' <<<"$linear")" >/dev/null \
    || fail_status "Linear authentication or schema preflight failed"
}

linear_reconcile_model() {
  local model="$1" evidence_all="$2" repository="$3" status_map="$4" issue_map="$5"
  local project status evidence_file eligible eligible_ids eligible_count expected_snapshot expected_project_done inc id identifier url receipt after project_will_finish
  project="$(jq -r '.feature.id' <<<"$model")"
  status="$(jq -r '.feature.status' <<<"$model")"

  evidence_file="$(mktemp)"
  jq -c --arg project "$project" '[.[] | select(.projectId==$project)]' \
    <<<"$evidence_all" >"$evidence_file"
  if ! jq -e --arg project "$project" --argjson evidence "$(cat "$evidence_file")" '
    (.increments) as $increments |
    ($evidence | group_by(.projectId,.issueIdentifier) | all(.[]; length==1)) and
    all($evidence[]; . as $item |
      any($increments[]; .identifier==$item.issueIdentifier and .pullRequest==$item.url)
    ) and
    all($increments[] | select(.pullRequest!=null); . as $issue |
      ([$evidence[] | select(
        .issueIdentifier==$issue.identifier and .url==$issue.pullRequest
      )] | length)==1
    ) and
    all($increments[] | select(.status=="done"); . as $issue |
      ([$evidence[] | select(
        .issueIdentifier==$issue.identifier and .url==$issue.pullRequest and .merged==true
      )] | length)==1
    )
  ' >/dev/null 2>&1 <<<"$model"; then
    rm -f "$evidence_file"
    fail_status "Linear pull request attribution is missing, ambiguous, or mismatched for project $project"
  fi
  [[ "$status" == inReview || "$status" == done ]] || {
    rm -f "$evidence_file"
    printf '%s\n' "$model"
    return
  }
  eligible="$(jq -c --arg project "$project" --argjson evidence "$(cat "$evidence_file")" '
    [.increments[] | select(.status=="inReview") | . as $issue |
      [$evidence[] | select(
        .projectId==$project and
        .issueIdentifier==$issue.identifier and
        .url==$issue.pullRequest and
        .merged==true
      )] | select(length==1) | $issue]
  ' <<<"$model")"
  eligible_ids="$(jq -c '[.[].id]' <<<"$eligible")"
  eligible_count="$(jq 'length' <<<"$eligible")"
  expected_snapshot="$(jq -c '{
    projectStatus:.feature.status,
    issues:(.increments | map({id,status}) | sort_by(.id))
  }' <<<"$model")"
  while IFS= read -r inc; do
    identifier="$(jq -r '.identifier' <<<"$inc")"
    url="$(jq -r '.pullRequest' <<<"$inc")"
    printf 'preview: Linear issue %s inReview -> done via %s\n' "$identifier" "$url" >&2
  done < <(jq -c '.[]' <<<"$eligible")

  project_will_finish=false
  if [[ "$status" == inReview && "$(jq '.increments|length' <<<"$model")" -gt 0 ]] &&
     jq -e --argjson eligible "$eligible_ids" '
       all(.increments[]; . as $issue | .status=="done" or any($eligible[]; .==$issue.id))
     ' >/dev/null 2>&1 <<<"$model"; then
    project_will_finish=true
    printf 'preview: Linear project %s inReview -> done (all managed issues done)\n' "$project" >&2
  fi

  expected_project_done=false
  [[ "$status" == done || "$project_will_finish" == true ]] && expected_project_done=true
  if ! receipt="$(linear_adapter status-reconcile \
    --project "$project" --repository "$repository" \
    --status-map "$status_map" --issue-state-map "$issue_map" \
    --pull-requests-file "$evidence_file" \
    --expected-eligible "$eligible_ids" \
    --expected-project-transition "$project_will_finish" \
    --expected-snapshot "$expected_snapshot")"; then
    rm -f "$evidence_file"
    fail_status "Linear terminal reconciliation API failed for project $project"
  fi
  rm -f "$evidence_file"
  jq -e '.verified==true and (.pending|length)==0' >/dev/null 2>&1 <<<"$receipt" \
    || fail_status "Linear terminal reconciliation read-back mismatch for project $project"
  jq -e --argjson issue_count "$eligible_count" --argjson project_write "$project_will_finish" --argjson expected_done "$expected_project_done" --argjson eligible "$eligible_ids" '
    ([.attempted[] | select(.=="issueUpdate")]|length)==$issue_count and
    ([.completed[] | select(.=="issueUpdate")]|length)==$issue_count and
    ([.attempted[] | select(.!="issueUpdate" and .!="projectUpdate")]|length)==0 and
    (.eligibleIssues|sort)==($eligible|sort) and
    ([.completed[] | select(.!="issueUpdate" and .!="projectUpdate")]|length)==0 and
    ([.attempted[] | select(.=="projectUpdate")]|length)==(if $project_write then 1 else 0 end) and
    ([.completed[] | select(.=="projectUpdate")]|length)==(if $project_write then 1 else 0 end) and
    .projectDone==$expected_done
  ' >/dev/null 2>&1 <<<"$receipt" \
    || fail_status "Linear reconciliation receipt does not match the write preview for project $project"

  if ! after="$(linear_adapter feature-read --project "$project" --repository "$repository" \
    --status-map "$status_map" --issue-state-map "$issue_map")"; then
    fail_status "Linear feature read-back failed for project $project"
  fi
  while IFS= read -r id; do
    jq -e --arg id "$id" 'any(.increments[]; .id==$id and .status=="done")' \
      >/dev/null 2>&1 <<<"$after" \
      || fail_status "Linear issue read-back mismatch for $id"
  done < <(jq -r '.[]' <<<"$eligible_ids")
  if [[ "$project_will_finish" == true || "$status" == done ]]; then
    jq -e '.feature.status=="done" and all(.increments[]; .status=="done")' \
      >/dev/null 2>&1 <<<"$after" \
      || fail_status "Linear project read-back mismatch for $project"
  else
    jq -e '.feature.status!="done"' >/dev/null 2>&1 <<<"$after" \
      || fail_status "Linear project changed without a matching write preview for $project"
  fi
  printf '%s\n' "$after"
}

append_linear_row() {
  local model="$1" evidence="$2" name phase plan_cell done total inc_cell inc_html inc status mark
  local merged prcount owner last_date agecell d frac next row bar hrow name_raw name_html
  name_raw="$(jq -r '.feature.title' <<<"$model")"
  name="$(terminal_safe "$name_raw")"
  phase="$(jq -r '.feature.status' <<<"$model")"
  [[ "$phase" == inReview ]] && phase="in-review"
  total="$(jq '.increments|length' <<<"$model")"
  done="$(jq '[.increments[] | select(.status=="done")]|length' <<<"$model")"
  plan_cell="-"; [[ "$total" -gt 0 ]] && plan_cell="$done/$total"
  inc_cell="-"; inc_html=""; merged=0; prcount=0
  while IFS= read -r inc; do
    status="$(jq -r '.status' <<<"$inc")"
    identifier="$(jq -r '.identifier' <<<"$inc")"
    case "$status" in done) mark=merged ;; inReview) mark=open ;; blocked) mark=closed ;; *) mark=partial ;; esac
    inc_cell="${inc_cell#-}"; inc_cell="${inc_cell:+$inc_cell . }#$identifier $status"
    inc_html="${inc_html}$(chip "$mark" "$identifier" "$status")"
    if [[ "$(jq -r '.pullRequest // empty' <<<"$inc")" != "" ]]; then
      prcount=$((prcount+1))
      jq -e --arg identifier "$identifier" 'any(.[]; .issueIdentifier==$identifier and .merged)' \
        >/dev/null 2>&1 <<<"$evidence" && merged=$((merged+1))
    fi
  done < <(jq -c '.increments[]' <<<"$model")

  owner="$(jq -r 'sort_by(.updatedAt) | last | .author // ""' <<<"$evidence")"
  last_date="$(jq -r 'sort_by(.updatedAt) | last | .updatedAt // "" | .[0:10]' <<<"$evidence")"
  agecell=""
  if [[ -n "$last_date" ]]; then d="$(age_days "$last_date")"; [[ -n "$d" ]] && agecell="${d}d"; fi
  if [[ -n "$agecell" && "$phase" == executing ]]; then
    d="${agecell%d}"
    row_has "$d" && [[ "$d" -gt "$(staleDays)" ]] && flag "$name: stale - ${d}d since last activity"
  fi
  frac=0; [[ "$total" -gt 0 ]] && frac=$(( done * 100 / total ))
  next="$(next_action "$phase" "$done" "$total" "$merged" "$prcount" "")"
  row="$(printf '%-22s %-10s %-7s %-20s %-7s %-5s %s' \
    "$name" "$phase" "$plan_cell" "$inc_cell" "$owner" "$agecell" "$next")"
  bar=""; [[ "$total" -gt 0 ]] && bar="<div class=\"bar\"><div style=\"width:${frac}%\"></div></div>"
  [[ -n "$inc_html" ]] || inc_html="$(html_escape "$inc_cell")"
  name_html="$(html_escape "$name") <span class=\"source-linear\">Linear</span>"
  hrow="<tr data-backend=\"linear\"><td>$name_html</td><td><span class=\"badge p-$phase\">$(html_escape "$phase")</span></td><td>$(html_escape "$plan_cell")$bar</td><td>$inc_html</td><td>$(html_escape "$owner")</td><td>$(html_escape "$agecell")</td><td>$(html_escape "$next")</td></tr>"$'\n'
  case "$phase" in
    done) done_count=$((done_count+1)); html_hidden_rows="${html_hidden_rows}${hrow}"; [[ "$SHOW_ALL" -eq 1 ]] && rows="${rows}${row}"$'\n' ;;
    abandoned) abandoned_count=$((abandoned_count+1)); html_hidden_rows="${html_hidden_rows}${hrow}"; [[ "$SHOW_ALL" -eq 1 ]] && rows="${rows}${row}"$'\n' ;;
    *) rows="${rows}${row}"$'\n'; html_rows="${html_rows}${hrow}" ;;
  esac
}

run_linear_board() {
  local repository status_map issue_map eligible evidence ids project model reconciled project_evidence referenced
  local -a models=()
  repository="$(jq -r '.repository' <<<"$WOO_BACKEND_CONFIG")"
  status_map="$(jq -c '.linear.projectStatuses' <<<"$WOO_BACKEND_CONFIG")"
  issue_map="$(jq -c '.linear.issueStates' <<<"$WOO_BACKEND_CONFIG")"
  eligible='["draft","hardened","approved","planning","ready","executing","inReview","done","abandoned"]'
  linear_preflight
  if ! ids="$(linear_project_ids "$repository" "$status_map" "$eligible")"; then
    fail_status "Linear managed project discovery failed"
  fi
  while IFS= read -r project; do
    [[ -n "$project" ]] || continue
    if ! model="$(linear_adapter feature-read --project "$project" --repository "$repository" \
      --status-map "$status_map" --issue-state-map "$issue_map")"; then
      fail_status "Linear feature read failed for project $project"
    fi
    jq -e '
      all(.increments[] | select(.status=="inReview");
        (.branch|type=="string") and (.branch|length>0) and
        (.pullRequest|type=="string") and (.pullRequest|length>0)
      )
    ' >/dev/null 2>&1 <<<"$model" \
      || fail_status "Linear inReview issue is missing its branch or pull request"
    models+=("$model")
  done <<<"$ids"
  referenced="$(printf '%s\n' "${models[@]}" | jq -sc \
    '[.[].increments[].pullRequest | select(type=="string" and length>0)] | unique')"
  jq -e --arg prefix "https://github.com/$repository/pull/" '
    all(.[]; startswith($prefix) and (ltrimstr($prefix)|test("^[1-9][0-9]*$")))
  ' >/dev/null 2>&1 <<<"$referenced" \
    || fail_status "Linear model contains a foreign or invalid pull request"
  if ! evidence="$(linear_pr_evidence "$repository" "$referenced")"; then
    fail_status "GitHub Linear pull request verification failed"
  fi
  for model in "${models[@]}"; do
    project="$(jq -r '.feature.id' <<<"$model")"
    if ! reconciled="$(linear_reconcile_model "$model" "$evidence" "$repository" "$status_map" "$issue_map")"; then
      fail_status "Linear terminal reconciliation failed for project $project"
    fi
    project_evidence="$(jq -c --arg project "$project" '[.[] | select(.projectId==$project)]' <<<"$evidence")"
    append_linear_row "$reconciled" "$project_evidence"
  done
}

render_html() {
  local tpl="$HERE/board-template.html" out="$WOO_DIR/visuals/status-board.html"
  if [ ! -f "$tpl" ]; then
    printf '\nnote: board template missing (%s) - HTML board skipped' "$tpl"; return 1
  fi
  if ! mkdir -p "$WOO_DIR/visuals" 2>/dev/null; then
    printf '\nnote: cannot create %s/visuals - HTML board skipped' "$WOO_DIR"; return 1
  fi
  WOO_HTML_ROWS="$html_rows" WOO_HTML_HIDDEN="$html_hidden_rows" \
  WOO_HTML_FLAGS="$html_flags" WOO_HTML_FOOTER="$(html_escape "$html_footer")" \
  WOO_HTML_GENERATED="$(html_escape "generated $(date '+%Y-%m-%d %H:%M') · $(pwd)")" \
  awk '
    index($0, "<!--WOO_ROWS-->")        { printf "%s", ENVIRON["WOO_HTML_ROWS"]; next }
    index($0, "<!--WOO_HIDDEN_ROWS-->") { printf "%s", ENVIRON["WOO_HTML_HIDDEN"]; next }
    index($0, "<!--WOO_FLAGS-->")       { printf "%s", ENVIRON["WOO_HTML_FLAGS"]; next }
    index($0, "<!--WOO_FOOTER-->")      { printf "%s", ENVIRON["WOO_HTML_FOOTER"]; next }
    index($0, "<!--WOO_GENERATED-->")   { printf "%s", ENVIRON["WOO_HTML_GENERATED"]; next }
    { print }
  ' "$tpl" > "$out" 2>/dev/null || {
    printf '\nnote: cannot write %s - HTML board skipped' "$out"; return 1
  }
  printf '\nboard: %s' "$out"
  return 0
}

maybe_open() {
  local f="$1"
  if [ "$NO_OPEN" -eq 1 ] || [ "${WOO_STATUS_NO_OPEN:-}" = "1" ] || [ -n "${CI:-}" ] || [ -n "${GITHUB_ACTIONS:-}" ]; then return 0; fi
  if command -v open >/dev/null 2>&1 && open "$f" 2>/dev/null; then return 0; fi
  if command -v xdg-open >/dev/null 2>&1 && xdg-open "$f" >/dev/null 2>&1; then return 0; fi
  printf '\nnote: no opener found - open %s manually' "$f"
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
html_rows=""
html_hidden_rows=""
html_flags=""
html_footer=""

if [ "$WOO_ARTIFACT_BACKEND" = linear ]; then
  gh_missing=0
  run_linear_board
else
for f in "${specs[@]}"; do
  spec_phase="$(field "$f" status)"; [ -n "$spec_phase" ] || spec_phase="unknown"
  phase="$spec_phase"
  raw_phase="$phase"

  plan_cell="-"; done=0; total=0; planfile=""
  markdown_model=""
  if [[ "$f" == *"/fixes/"* ]]; then
    planfile="$f"
    name="[FIX] $(field "$f" name)"; [ "$name" != "[FIX] " ] || name="[FIX] $(basename "$f" .md)"
    specpath="$WOO_DIR/fixes/$(basename "$f")"
  else
    name="$(field "$f" name)"; [ -n "$name" ] || name="$(basename "$f" .md)"
    specpath="$WOO_DIR/specs/$(basename "$f")"
    
    plans=()
    while IFS= read -r ln; do [ -n "$ln" ] && plans+=("$ln"); done < <(plan_for "$f")
    if [ "${#plans[@]}" -eq 0 ]; then
      case "$phase" in draft|hardened|approved|abandoned) : ;; *) flag "$name: no plan resolves to this spec (woostack-plan)" ;; esac
    elif [ "${#plans[@]}" -ge 2 ]; then
      flag "$name: ${#plans[@]} plans resolve to this spec - spec<->plan must be 1:1"
      planfile="${plans[0]}"
    else
      planfile="${plans[0]}"
    fi
    if [ -n "$planfile" ] && grep -qE '^## Increment [0-9]+' "$planfile"; then
      if ! markdown_model="$(markdown_feature_model "$f" 2>/dev/null)"; then
        flag "$name: normalized Markdown adapter failed"
        continue
      fi
    fi

    if [ -n "$planfile" ]; then
      phase="$(field "$planfile" status)"; [ -n "$phase" ] || phase="unknown"
      raw_phase="$phase"
    fi
    if jq -e '.backend=="markdown"' >/dev/null 2>&1 <<<"$markdown_model"; then
      name="$(jq -r '.feature.title' <<<"$markdown_model")"
      phase="$(jq -r '.feature.status' <<<"$markdown_model")"
      raw_phase="$phase"
    fi
  fi

  if [ "${VALID_PHASES/ $phase /}" = "$VALID_PHASES" ]; then
    flag "$name: '$phase' is not a known phase - unknown phase, set a valid status:"
    phase="unknown"
  fi

  if jq -e '.backend=="markdown"' >/dev/null 2>&1 <<<"$markdown_model"; then
    done="$(jq '.progress.completed' <<<"$markdown_model")"
    total="$(jq '.progress.total' <<<"$markdown_model")"
    [ "$total" -gt 0 ] && plan_cell="$done/$total"
  elif [ -n "$planfile" ]; then
    read -r done total < <(plan_progress "$planfile")
    [ "$total" -gt 0 ] && plan_cell="$done/$total"
  fi
  if [[ "$f" == *"/fixes/"* ]] || [ -z "$planfile" ]; then
    br="$(field "$f" branch)"
  else
    br="$(field "$planfile" branch)"
  fi
  if jq -e '.backend=="markdown" and .feature.branch!=null' >/dev/null 2>&1 <<<"$markdown_model"; then
    br="$(jq -r '.feature.branch' <<<"$markdown_model")"
  fi
  open=0; merged=0; prcount=0; inc_cell="-"; inc_parts=""; inc_html=""
  last_author=""; last_upd_date=""
  while IFS=$'\t' read -r num state head author upd url; do
    [ -z "$num" ] && continue
    prcount=$((prcount+1))
    case "$state" in OPEN) open=$((open+1)) ;; MERGED) merged=$((merged+1)) ;; esac
    mark="."; case "$state" in MERGED) mark="merged" ;; OPEN) mark="open" ;; CLOSED) mark="closed" ;; esac
    inc_parts="${inc_parts:+$inc_parts . }#$num $mark"
    inc_html="${inc_html}$(chip "$mark" "$num" "$mark" "$url")"
    last_author="$author"; last_upd_date="${upd:0:10}"
  done < <(prs_for_spec "$specpath")

  if [ "$prcount" -eq 0 ] && [ -n "$br" ] && [ "$br" != unknown ]; then
    while IFS=$'\t' read -r num state head author upd url; do
      [ -z "$num" ] && continue
      prcount=$((prcount+1))
      case "$state" in OPEN) open=$((open+1)) ;; MERGED) merged=$((merged+1)) ;; esac
      inc_cell="#$num (partial)"
      inc_html="$(chip partial "$num" "(partial)" "$url")"
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
  eff="$(resolve_phase "$phase" "$hasPlan" "$frac" "$open" "$merged" "$prcount" "$branchExists" "$hasCommits" "$total")"

  if [ -z "$br" ] || [ "$br" = unknown ]; then
    case "$eff" in executing|in-review|done) flag "$name: branch is '${br:-empty}' - set branch:" ;; esac
    [ "$br" = unknown ] && flag "$name: branch is 'unknown' - set branch: in frontmatter"
  fi

  # `ready` is intentionally absent: the spec+plan handoff PR is opened *at* `ready` (see
  # conventions.md), so a PR existing there is expected, not drift. Flag only the genuinely
  # pre-PR head states.
  case "$phase" in
    draft|hardened|approved|planning)
      [ "$prcount" -gt 0 ] && flag "$name: status lags - phase '$phase' but a PR already exists" ;;
  esac

  # Branch collision is an in-flight concern only: a done/abandoned branch is not in-flight,
  # so terminal rows neither flag a collision nor get recorded (conventions.md: two in-flight rows).
  if [ -n "$br" ] && [ "$br" != unknown ] && [ "$eff" != done ] && [ "$eff" != abandoned ]; then
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

  next="$(next_action "$eff" "$done" "$total" "$merged" "$prcount" "$f")"
  row="$(printf '%-22s %-10s %-7s %-20s %-7s %-5s %s' \
    "$name" "$eff" "$plan_cell" "$inc_cell" "$owner" "$agecell" \
    "$next")"
  bar=""
  if [ "$total" -gt 0 ]; then
    bar="<div class=\"bar\"><div style=\"width:${frac}%\"></div></div>"
  fi
  [ -n "$inc_html" ] || inc_html="$(html_escape "$inc_cell")"
  hrow="<tr><td>$(html_escape "$name")</td><td><span class=\"badge p-$eff\">$(html_escape "$eff")</span></td><td>$(html_escape "$plan_cell")$bar</td><td>$inc_html</td><td>$(html_escape "$owner")</td><td>$(html_escape "$agecell")</td><td>$(html_escape "$next")</td></tr>"$'\n'
  case "$eff" in
    done) done_count=$((done_count+1)) ;;
    abandoned) abandoned_count=$((abandoned_count+1)) ;;
    *) rows="${rows}${row}"$'\n' ;;
  esac
  case "$eff" in
    done|abandoned) html_hidden_rows="${html_hidden_rows}${hrow}" ;;
    *) html_rows="${html_rows}${hrow}" ;;
  esac
  if [ "$SHOW_ALL" -eq 1 ]; then
    case "$eff" in done|abandoned) rows="${rows}${row}"$'\n' ;; esac
  fi
done
fi

if [ -n "$FLAGS" ]; then
  html_flags="<div class=\"flags\"><h2>! FLAGS</h2><ul>"
  while IFS= read -r ln; do
    [ -n "$ln" ] || continue
    html_flags="${html_flags}<li>$(html_escape "${ln#  ! }")</li>"
  done <<< "$FLAGS"
  html_flags="${html_flags}</ul></div>"
fi
if [ -z "$html_rows" ] && [ -n "$html_hidden_rows" ]; then
  html_rows="<tr><td colspan=\"7\" class=\"empty\">All specs are done or abandoned - see the collapsed section below</td></tr>"$'\n'
fi

gh_note="note: gh not found - PR/increment/owner data omitted for PR-phase rows"
fetch_note="note: PR-less branch data may be stale; pass --fetch to refresh"
html_footer="$done_count done · $abandoned_count abandoned"
if [ "$WOO_ARTIFACT_BACKEND" = markdown ]; then
  [ "$gh_missing" -eq 1 ] && html_footer="$html_footer"$'\n'"$gh_note"
  [ "$DO_FETCH" -eq 0 ] && html_footer="$html_footer"$'\n'"$fetch_note"
fi

printf '%-22s %-10s %-7s %-20s %-7s %-5s %s\n' FEATURE PHASE PLAN INCREMENTS OWNER AGE NEXT
printf '%s' "$rows"
[ -n "$FLAGS" ] && printf '\n! FLAGS\n%s' "$FLAGS"
printf '\n%d done . %d abandoned' "$done_count" "$abandoned_count"
[ "$SHOW_ALL" -eq 0 ] && printf '   (--all to expand)'
if [ "$WOO_ARTIFACT_BACKEND" = markdown ]; then
  [ "$gh_missing" -eq 1 ] && printf '\n%s' "$gh_note"
  [ "$DO_FETCH" -eq 0 ] && printf '\n%s' "$fetch_note"
fi
if render_html; then
  maybe_open "$WOO_DIR/visuals/status-board.html"
fi
printf '\n'
exit 0
