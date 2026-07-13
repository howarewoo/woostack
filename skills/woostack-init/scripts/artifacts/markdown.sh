#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$HERE/../lib.sh"

fail() {
  printf 'markdown adapter: %s\n' "$1" >&2
  exit 1
}

validate_frontmatter() {
  local file="$1"
  [[ -f "$file" ]] || fail "artifact file not found"
  [[ "$(sed -n '1p' "$file")" == '---' ]] || fail "malformed frontmatter"
  awk 'NR > 1 && $0 == "---" { found=1; exit } END { exit !found }' "$file" \
    || fail "malformed frontmatter"
}

read_field() {
  local file="$1" key="$2"
  awk -v key="$key" '
    NR == 1 && $0 == "---" { in_frontmatter=1; next }
    in_frontmatter && $0 == "---" { exit }
    in_frontmatter && index($0, key ":") == 1 {
      value=substr($0, length(key) + 2)
      sub(/^[[:space:]]*/, "", value)
      sub(/[[:space:]]*$/, "", value)
      print value
      exit
    }
  ' "$file"
}

emit_spec_only() {
  local spec_path="$1" basename="$2" stem="$3"
  local feature_name feature_status feature_branch spec_id revision
  feature_name="$(read_field "$spec_path" name)"
  [[ -n "$feature_name" ]] || feature_name="${stem#????-??-??-}"
  feature_status="$(read_field "$spec_path" status)"
  feature_branch="$(read_field "$spec_path" branch)"
  [[ -n "$feature_status" ]] || fail "spec status is missing"
  spec_id=".woostack/specs/$basename"
  revision="$(python3 - "$spec_path" <<'PY'
import hashlib
import sys

with open(sys.argv[1], "rb") as handle:
    print(hashlib.sha256(handle.read()).hexdigest())
PY
  )" || fail "spec revision could not be computed"
  jq -cn \
    --arg feature_id "$spec_id" \
    --arg title "$feature_name" \
    --arg status "$feature_status" \
    --arg branch "$feature_branch" \
    --arg spec_id "$spec_id" \
    --rawfile content "$spec_path" \
    --arg revision "$revision" '
      {
        backend: "markdown",
        feature: {
          id: $feature_id,
          url: null,
          title: $title,
          status: $status,
          branch: (if $branch == "" then null else $branch end)
        },
        spec: {
          id: $spec_id,
          url: null,
          content: $content,
          revision: $revision
        },
        plan: null,
        increments: []
      }
    '
}

feature() {
  local requested="$1" requested_dir repo_hint repo_root spec_dir spec_path woo_root
  local basename stem plan_dir plan_path spec_slug spec_name
  requested_dir="$(dirname "$requested")"
  [[ "$(basename "$requested_dir")" == 'specs' && "$(basename "$(dirname "$requested_dir")")" == '.woostack' ]] \
    || fail "spec path must be under .woostack/specs"
  repo_hint="$(dirname "$(dirname "$requested_dir")")"
  [[ ! -L "$repo_hint/.woostack" && ! -L "$repo_hint/.woostack/specs" ]] \
    || fail "spec directory symlinks are not allowed"
  repo_root="$(git -C "$repo_hint" rev-parse --show-toplevel 2>/dev/null)" \
    || fail "repository root not found"
  repo_root="$(cd "$repo_root" && pwd -P)"
  spec_dir="$(cd "$requested_dir" 2>/dev/null && pwd -P)" || fail "spec directory not found"
  [[ "$spec_dir" == "$repo_root/.woostack/specs" ]] || fail "spec path must be under repository .woostack/specs"
  spec_path="$spec_dir/$(basename "$requested")"
  [[ ! -L "$requested" && ! -L "$spec_path" ]] || fail "spec symlinks are not allowed"
  validate_frontmatter "$spec_path"
  [[ "$(read_field "$spec_path" type)" == 'spec' ]] || fail "artifact is not a spec"

  woo_root="$repo_root/.woostack"
  basename="$(basename "$spec_path")"
  stem="${basename%.md}"
  spec_slug="${stem#????-??-??-}"
  spec_name="$(read_field "$spec_path" name)"
  plan_dir="$woo_root/plans"
  [[ ! -L "$plan_dir" ]] || fail "plan symlink escapes are not allowed"
  if [[ ! -e "$plan_dir" ]]; then
    emit_spec_only "$spec_path" "$basename" "$stem"
    return
  fi
  [[ -d "$plan_dir" ]] || fail "plan path is not a directory"

  local -a matches=()
  local candidate candidate_base candidate_slug candidate_source canonical canonical_md legacy
  canonical="**Source:** [[specs/$stem]]"
  canonical_md="**Source:** [[specs/$basename]]"
  legacy="**Source:** .woostack/specs/$basename"
  shopt -s nullglob
  for candidate in "$plan_dir"/*.md; do
    [[ ! -L "$candidate" ]] || fail "plan symlinks are not allowed"
    if awk -v canonical="$canonical" -v canonical_md="$canonical_md" -v legacy="$legacy" '
      function trim(value) {
        sub(/^[[:space:]]*/, "", value)
        sub(/[[:space:]]*$/, "", value)
        return value
      }
      function matches_token(value, token) {
        return index(value, token) == 1 &&
          (length(value) == length(token) || substr(value, length(token) + 1, 1) ~ /[[:space:]]/)
      }
      function run_length(value, marker, count) {
        marker=substr(value, 1, 1)
        if (marker != "`" && marker != "~") return 0
        count=1
        while (substr(value, count + 1, 1) == marker) count++
        return count
      }
      $0 == "---" && frontmatter_fences < 2 { frontmatter_fences++; next }
      frontmatter_fences < 2 { next }
      {
        value=$0
        sub(/^[[:space:]]*/, "", value)
        run=run_length(value)
        marker=substr(value, 1, 1)
        rest=substr(value, run + 1)
        if (in_fence) {
          if (marker == fence_marker && run >= fence_length && rest ~ /^[[:space:]]*$/) {
            in_fence=0
          }
          next
        }
        if (run >= 3) {
          in_fence=1
          fence_marker=marker
          fence_length=run
          next
        }
        value=trim($0)
        if (matches_token(value, canonical) ||
            matches_token(value, canonical_md) ||
            matches_token(value, legacy)) found=1
      }
      END { exit !found }
    ' "$candidate"; then
      matches+=("$candidate")
    fi
  done

  if (( ${#matches[@]} == 0 )); then
    for candidate in "$plan_dir"/*.md; do
      candidate_base="$(basename "$candidate" .md)"
      candidate_slug="${candidate_base#????-??-??-}"
      candidate_source="$(read_field "$candidate" source)"
      if [[ -n "$candidate_source" && "$candidate_source" != ".woostack/specs/$basename" ]]; then
        continue
      fi
      if awk '
        function trim(value) {
          sub(/^[[:space:]]*/, "", value)
          sub(/[[:space:]]*$/, "", value)
          return value
        }
        function run_length(value, marker, count) {
          marker=substr(value, 1, 1)
          if (marker != "`" && marker != "~") return 0
          count=1
          while (substr(value, count + 1, 1) == marker) count++
          return count
        }
        $0 == "---" && frontmatter_fences < 2 { frontmatter_fences++; next }
        frontmatter_fences < 2 { next }
        {
          value=$0
          sub(/^[[:space:]]*/, "", value)
          run=run_length(value)
          marker=substr(value, 1, 1)
          rest=substr(value, run + 1)
          if (in_fence) {
            if (marker == fence_marker && run >= fence_length && rest ~ /^[[:space:]]*$/) in_fence=0
            next
          }
          if (run >= 3) {
            in_fence=1
            fence_marker=marker
            fence_length=run
            next
          }
          if (trim($0) ~ /^\*\*Source:\*\*/) found=1
        }
        END { exit !found }
      ' "$candidate"; then
        continue
      fi
      if [[ "$candidate_slug" == "$spec_slug" || ( -n "$spec_name" && "$candidate_slug" == "$spec_name" ) ]]; then
        matches+=("$candidate")
      fi
    done
  fi
  shopt -u nullglob

  if (( ${#matches[@]} == 0 )); then
    emit_spec_only "$spec_path" "$basename" "$stem"
    return
  fi
  (( ${#matches[@]} == 1 )) || fail "multiple plans join to spec"
  plan_path="${matches[0]}"
  validate_frontmatter "$plan_path"
  [[ "$(read_field "$plan_path" type)" == 'plan' ]] || fail "joined artifact is not a plan"

  local feature_name feature_status feature_branch spec_id plan_id parsed revision increments progress
  feature_name="$(read_field "$spec_path" name)"
  [[ -n "$feature_name" ]] || feature_name="${stem#????-??-??-}"
  feature_status="$(read_field "$plan_path" status)"
  feature_branch="$(read_field "$plan_path" branch)"
  [[ -n "$feature_status" ]] || fail "plan status is missing"
  spec_id=".woostack/specs/$basename"
  plan_id=".woostack/plans/$(basename "$plan_path")"
  parsed="$(python3 - "$spec_path" "$plan_path" "$plan_id" <<'PY'
import hashlib
import json
import re
import sys

spec_path, plan_path, plan_id = sys.argv[1:]
with open(spec_path, "rb") as handle:
    spec_bytes = handle.read()
with open(plan_path, encoding="utf-8") as handle:
    lines = handle.readlines()

heading = re.compile(r"^## Increment ([0-9]+)(?::| [-—] | \([^)\r\n]+\):)")
checkbox = re.compile(r"^[ \t]*-[ \t]+\[([ xX])\]")

frontmatter_fences = 0
body_start = None
for index, line in enumerate(lines):
    if line.rstrip("\r\n") == "---":
        frontmatter_fences += 1
        if frontmatter_fences == 2:
            body_start = index + 1
            break
body_lines = lines[body_start:]

def fence_marker(line):
    stripped = line.lstrip()
    if not stripped or stripped[0] not in (chr(96), "~"):
        return None
    marker = stripped[0]
    run = len(stripped) - len(stripped.lstrip(marker))
    if run < 3:
        return None
    return marker, run, stripped[run:].rstrip("\r\n")

def checkbox_values(section_lines):
    values = []
    active_marker = None
    active_length = 0
    for line in section_lines:
        fence = fence_marker(line)
        if fence is not None:
            marker, run, remainder = fence
            if active_marker is None:
                active_marker = marker
                active_length = run
            elif marker == active_marker and run >= active_length and not remainder.strip():
                active_marker = None
                active_length = 0
            continue
        if active_marker is None and (match := checkbox.match(line)):
            values.append(match.group(1))
    return values

sections = []
current = None
active_marker = None
active_length = 0

for line in body_lines:
    fence = fence_marker(line)
    if fence is not None:
        marker, run, remainder = fence
        if active_marker is None:
            active_marker = marker
            active_length = run
        elif marker == active_marker and run >= active_length and not remainder.strip():
            active_marker = None
            active_length = 0
        if current is not None:
            current["lines"].append(line)
        continue
    if active_marker is not None:
        if current is not None:
            current["lines"].append(line)
        continue
    match = heading.match(line.rstrip("\r\n"))
    if match:
        if current is not None:
            sections.append(current)
        current = {"ordinal": int(match.group(1)), "lines": []}
    elif current is not None:
        current["lines"].append(line)
if current is not None:
    sections.append(current)

if not sections:
    sections = [{"ordinal": 1, "lines": body_lines}]

ordinals = [section["ordinal"] for section in sections]
if len(ordinals) != len(set(ordinals)):
    raise SystemExit("plan has duplicate increment ordinals")

increments = []
completed_boxes = 0
total_boxes = 0
for section in sorted(sections, key=lambda item: item["ordinal"]):
    boxes = checkbox_values(section["lines"])
    done = sum(value.lower() == "x" for value in boxes)
    total = len(boxes)
    completed_boxes += done
    total_boxes += total
    status = "done" if total and done == total else "executing" if done else "planned"
    ordinal = section["ordinal"]
    increments.append({
        "id": f"{plan_id}#increment-{ordinal}",
        "identifier": None,
        "ordinal": ordinal,
        "status": status,
        "dependencies": [],
        "branch": None,
        "pullRequest": None,
        "content": "".join(section["lines"]).strip("\r\n"),
    })

print(json.dumps({
    "revision": hashlib.sha256(spec_bytes).hexdigest(),
    "increments": increments,
    "progress": {"completed": completed_boxes, "total": total_boxes},
}, separators=(",", ":")))
PY
  )" || fail "plan increments could not be parsed"
  revision="$(jq -r '.revision' <<<"$parsed")"
  increments="$(jq -c '.increments' <<<"$parsed")"
  progress="$(jq -c '.progress' <<<"$parsed")"

  jq -cn \
    --arg feature_id "$spec_id" \
    --arg title "$feature_name" \
    --arg status "$feature_status" \
    --arg branch "$feature_branch" \
    --arg spec_id "$spec_id" \
    --rawfile content "$spec_path" \
    --arg plan_id "$plan_id" \
    --rawfile plan_content "$plan_path" \
    --arg revision "$revision" \
    --argjson increments "$increments" \
    --argjson progress "$progress" '
      {
        backend: "markdown",
        feature: {
          id: $feature_id,
          url: null,
          title: $title,
          status: $status,
          branch: (if $branch == "" then null else $branch end)
        },
        spec: {
          id: $spec_id,
          url: null,
          content: $content,
          revision: $revision
        },
        progress: $progress,
        plan: {
          id: $plan_id,
          url: null,
          content: $plan_content
        },
        increments: $increments
      }
    '
}

[[ "${1:-}" == 'feature' ]] || fail "usage: markdown.sh feature <spec-path>"
[[ $# -eq 2 ]] || fail "usage: markdown.sh feature <spec-path>"
feature "$2"
