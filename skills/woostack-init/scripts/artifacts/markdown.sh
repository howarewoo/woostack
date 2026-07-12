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

# woostack-defer(increment 5): workflow skills begin consuming the backend adapter in increment 5
feature() {
  local requested="$1" spec_dir spec_path woo_root basename stem plan_dir plan_path
  spec_dir="$(cd "$(dirname "$requested")" 2>/dev/null && pwd -P)" || fail "spec directory not found"
  spec_path="$spec_dir/$(basename "$requested")"
  [[ ! -L "$requested" && ! -L "$spec_path" ]] || fail "spec symlinks are not allowed"
  validate_frontmatter "$spec_path"
  [[ "$(read_field "$spec_path" type)" == 'spec' ]] || fail "artifact is not a spec"

  [[ "$(basename "$spec_dir")" == 'specs' && "$(basename "$(dirname "$spec_dir")")" == '.woostack' ]] \
    || fail "spec path must be under .woostack/specs"
  woo_root="$(dirname "$spec_dir")"
  basename="$(basename "$spec_path")"
  stem="${basename%.md}"
  plan_dir="$woo_root/plans"
  [[ -d "$plan_dir" ]] || fail "matching plan not found"
  [[ ! -L "$plan_dir" ]] || fail "plan symlink escapes are not allowed"

  local -a matches=()
  local candidate line canonical legacy
  canonical="**Source:** [[specs/$stem]]"
  legacy="**Source:** .woostack/specs/$basename"
  shopt -s nullglob
  for candidate in "$plan_dir"/*.md; do
    [[ ! -L "$candidate" ]] || fail "plan symlinks are not allowed"
    line="$(awk '
      $0 == "---" { fences++; next }
      fences >= 2 && $0 !~ /^[[:space:]]*$/ {
        value=$0
        sub(/^[[:space:]]*/, "", value)
        sub(/[[:space:]]*$/, "", value)
        print value
        exit
      }
    ' "$candidate")"
    if [[ "$line" == "$canonical" || "$line" == "$legacy" ]]; then
      matches+=("$candidate")
    fi
  done
  shopt -u nullglob

  if (( ${#matches[@]} == 0 )); then
    candidate="$plan_dir/$basename"
    [[ -f "$candidate" ]] && matches+=("$candidate")
  fi
  (( ${#matches[@]} > 0 )) || fail "matching plan not found"
  (( ${#matches[@]} == 1 )) || fail "multiple plans join to spec"
  plan_path="${matches[0]}"
  validate_frontmatter "$plan_path"
  [[ "$(read_field "$plan_path" type)" == 'plan' ]] || fail "joined artifact is not a plan"

  local feature_name feature_status feature_branch spec_id plan_id parsed revision increments
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
sections = []
current = None
in_fence = False
fence_length = 0

for line in lines:
    stripped = line.lstrip()
    tick_run = len(stripped) - len(stripped.lstrip(chr(96)))
    if tick_run >= 3:
        if not in_fence:
            in_fence = True
            fence_length = tick_run
        elif tick_run >= fence_length:
            in_fence = False
            fence_length = 0
        continue
    if in_fence:
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

ordinals = [section["ordinal"] for section in sections]
if not ordinals:
    raise SystemExit("plan has no increments")
if len(ordinals) != len(set(ordinals)):
    raise SystemExit("plan has duplicate increment ordinals")

increments = []
for section in sorted(sections, key=lambda item: item["ordinal"]):
    boxes = [match.group(1) for line in section["lines"] if (match := checkbox.match(line))]
    done = sum(value.lower() == "x" for value in boxes)
    total = len(boxes)
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
}, separators=(",", ":")))
PY
  )" || fail "plan increments could not be parsed"
  revision="$(jq -r '.revision' <<<"$parsed")"
  increments="$(jq -c '.increments' <<<"$parsed")"

  jq -cn \
    --arg feature_id "$spec_id" \
    --arg title "$feature_name" \
    --arg status "$feature_status" \
    --arg branch "$feature_branch" \
    --arg spec_id "$spec_id" \
    --rawfile content "$spec_path" \
    --arg revision "$revision" \
    --argjson increments "$increments" '
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
        increments: $increments
      }
    '
}

[[ "${1:-}" == 'feature' ]] || fail "usage: markdown.sh feature <spec-path>"
[[ $# -eq 2 ]] || fail "usage: markdown.sh feature <spec-path>"
feature "$2"
