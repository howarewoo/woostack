#!/usr/bin/env bash
# resolve-diff-line.sh — validate one post-patch line, or an optional range,
# against the RIGHT side of the prefetched unified diff. Emits the canonical
# line, `<start>:<end>` for a valid same-hunk range, or `null` when the start
# cannot be resolved. An invalid endpoint degrades to the valid start.
#
# Rationale: the GitHub Pull Request Review API rejects comments whose `line`
# does not correspond to a `+` (added) or ` ` (context) line on the RIGHT side
# of the diff. Findings posted with raw source-file lines that fall in a
# deletion-only region, or outside any hunk, return HTTP 422 "Line could not
# be resolved." Sub-agents call this helper before writing the `line` field on
# each finding; the merge step also runs a final-pass safety check.
#
# Usage:
#   bash resolve-diff-line.sh --file <path> --line <N> [--end <N>]
#                              [--diff <path>] [--cache <path>] [--no-cache]
#
# Exit codes:
#   0  always (success). Output is the resolved line or `null`. Callers
#      branch on the stdout value, not the exit status, so a missing diff
#      file falls through to `null` without spurious failure annotations.
#
# Env / defaults:
#   OUTDIR=/tmp/pr-review
#   --diff defaults to "$OUTDIR/diff.filtered.txt" if present, else "$OUTDIR/diff.txt".
#   --cache defaults to "$OUTDIR/diff-line-cache.json" (a flat map keyed by
#   "<path>:<line>" or "<path>:<line>:<end>").

set -euo pipefail

# shellcheck source=skills/woostack-review/scripts/resolve-outdir.sh
source "$(dirname "${BASH_SOURCE[0]:-$0}")/resolve-outdir.sh"
FILE=""
LINE=""
END=""
END_SET=0
DIFF=""
CACHE=""
USE_CACHE=1

while [ $# -gt 0 ]; do
  case "$1" in
    --file)     FILE="$2"; shift 2 ;;
    --line)     LINE="$2"; shift 2 ;;
    --end)      END="$2"; END_SET=1; shift 2 ;;
    --diff)     DIFF="$2"; shift 2 ;;
    --cache)    CACHE="$2"; shift 2 ;;
    --no-cache) USE_CACHE=0; shift ;;
    -h|--help)
      sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "::error::resolve-diff-line: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$FILE" ] || [ -z "$LINE" ]; then
  echo "::error::resolve-diff-line: --file and --line are required" >&2
  exit 2
fi

# Default diff path: ignore-filtered when prefetch produced it, else the raw diff.
if [ -z "$DIFF" ]; then
  if [ -f "$OUTDIR/diff.filtered.txt" ]; then
    DIFF="$OUTDIR/diff.filtered.txt"
  else
    DIFF="$OUTDIR/diff.txt"
  fi
fi
if [ -z "$CACHE" ]; then
  CACHE="$OUTDIR/diff-line-cache.json"
fi

if [ ! -s "$DIFF" ]; then
  echo "null"
  exit 0
fi

# Python core — the bash side is just argv plumbing. Reads the cache, looks up
# the requested anchor, parses unified hunks on miss, and writes the cache
# atomically.
python3 - "$FILE" "$LINE" "$END" "$END_SET" "$DIFF" "$CACHE" "$USE_CACHE" <<'PY'
import json
import os
import re
import sys
import tempfile

file_arg, line_arg, end_arg, end_set_flag, diff_path, cache_path, use_cache_flag = sys.argv[1:8]
end_requested = end_set_flag == "1"
use_cache = use_cache_flag == "1"


def parse_positive(value):
    try:
        parsed = int(str(value).strip())
    except (TypeError, ValueError):
        return None
    return parsed if parsed > 0 else None


target_line = parse_positive(line_arg)
if target_line is None:
    print("null")
    sys.exit(0)

cache_key = f"{file_arg}:{target_line}"
if end_requested:
    cache_key += f":{end_arg}"
cache = {}
if use_cache and os.path.exists(cache_path):
    try:
        with open(cache_path, "r") as fh:
            cache = json.load(fh) or {}
    except (json.JSONDecodeError, OSError):
        cache = {}
    if cache_key in cache:
        print(cache[cache_key])
        sys.exit(0)


def emit(result):
    out = "null" if result is None else str(result)
    if use_cache:
        cache[cache_key] = out
        # Atomic write: tempfile in the same dir + rename. Avoids torn writes
        # when two angle workers race to memoize the same lookup.
        cache_dir = os.path.dirname(cache_path) or "."
        try:
            os.makedirs(cache_dir, exist_ok=True)
            fd, tmp = tempfile.mkstemp(prefix=".diff-line-cache.", dir=cache_dir)
            with os.fdopen(fd, "w") as fh:
                json.dump(cache, fh)
            os.replace(tmp, cache_path)
        except OSError:
            pass
    print(out)
    sys.exit(0)


# Parse the unified diff once and map each RIGHT-side line to its hunk. Range
# endpoints are post-patch lines and GitHub rejects cross-hunk ranges.
file_header_re = re.compile(r"^diff --git a/(?P<a>.+?) b/(?P<b>.+?)$")
hunk_header_re = re.compile(r"^@@ -\d+(?:,\d+)? \+(?P<new_start>\d+)(?:,\d+)? @@")

right_line = None
in_target = False
hunk_id = 0
anchors = {}

try:
    with open(diff_path, "r", errors="replace") as fh:
        for raw in fh:
            line = raw.rstrip("\n")
            match = file_header_re.match(line)
            if match:
                in_target = match.group("b") == file_arg
                right_line = None
                continue
            if line.startswith("--- ") or line.startswith("+++ "):
                continue
            if not in_target:
                continue
            match = hunk_header_re.match(line)
            if match:
                hunk_id += 1
                right_line = int(match.group("new_start"))
                continue
            if right_line is None:
                continue

            head = line[:1]
            if head in ("+", " "):
                if right_line == target_line and not end_requested:
                    emit(right_line)
                anchors.setdefault(right_line, hunk_id)
                right_line += 1
            elif head == "-":
                continue
            elif head == "\\":
                continue
            else:
                right_line = None
except OSError:
    emit(None)

start_hunk = anchors.get(target_line)
if start_hunk is None:
    emit(None)
if not end_requested:
    emit(target_line)

end_line = parse_positive(end_arg)
if (
    end_line is None
    or end_line <= target_line
    or anchors.get(end_line) != start_hunk
):
    emit(target_line)

emit(f"{target_line}:{end_line}")
PY
