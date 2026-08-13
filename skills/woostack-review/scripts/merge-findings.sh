#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=skills/woostack-review/scripts/resolve-outdir.sh
source "$(dirname "${BASH_SOURCE[0]:-$0}")/resolve-outdir.sh"
MERGED_FILE="$OUTDIR/raw_findings.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

echo "[]" > "$MERGED_FILE"

# Final findings are owned by the sole adjudicator and deterministic finalizer. Adjudicator and
# final artifacts are excluded from candidate merging.
shopt -s nullglob
ALL=("$OUTDIR"/findings.*.json)
FILES=()
for f in "${ALL[@]+"${ALL[@]}"}"; do
  case "$f" in
    "$OUTDIR"/findings.json|"$OUTDIR"/findings.adjudicator.json) continue ;;
  esac
  FILES+=("$f")
done

if [ ${#FILES[@]} -eq 0 ]; then
  echo "No findings found to merge."
  exit 0
fi

# Robust merge: per-file parse, recover from prose preambles, skip empty /
# unrecoverable, keep only JSON arrays. One bad angle file must not sink the
# whole review.
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
: > "$TMP"

merged_count=0
recovered_count=0
for f in "${FILES[@]}"; do
  if [ ! -s "$f" ]; then
    echo "::warning::Skipping empty findings file: $f"
    continue
  fi
  if jq -e 'type == "array"' "$f" >/dev/null 2>&1; then
    cat "$f" >> "$TMP"
    printf '\n' >> "$TMP"
    merged_count=$((merged_count + 1))
    continue
  fi
  if jq -e 'type == "object" and has("file") and has("line") and has("title") and has("description") and has("fix")' "$f" >/dev/null 2>&1; then
    jq '[.]' "$f" >> "$TMP"
    printf '\n' >> "$TMP"
    merged_count=$((merged_count + 1))
    recovered_count=$((recovered_count + 1))
    echo "::warning::Recovered single finding object as array from $f"
    continue
  fi
  # Prose-preamble + bad-escape recovery. Sub-agents occasionally emit text
  # like "I have completed the review..." before the JSON array, and inside
  # strings they sometimes write invalid JSON escapes (\x, \!, bare control
  # bytes) — both make jq reject the file. Three-stage recovery:
  #   1. Strip preamble + trailing prose around the outermost balanced `[...]`.
  #   2. Try strict json.loads.
  #   3. Sanitize: strip bare control bytes (U+0000–U+001F except \t\n\r),
  #      replace invalid `\<char>` escapes with the literal char, retry with
  #      strict=False.
  # Only sub-agents authored by woostack-review write these files; recovery is
  # tolerant of LLM-introduced noise, NOT of attacker-supplied JSON. The
  # downstream finding schema still validates structure.
  RECOVERED="$(python3 - "$f" <<'PY' 2>/dev/null || true
import json
import re
import sys

with open(sys.argv[1], "r", errors="replace") as fh:
    text = fh.read()

start = text.find("[")
if start < 0:
    sys.exit(1)

# Walk from the first `[` matching brackets, respecting strings and escapes.
depth = 0
in_str = False
esc = False
end = -1
for i in range(start, len(text)):
    ch = text[i]
    if in_str:
        if esc:
            esc = False
        elif ch == "\\":
            esc = True
        elif ch == '"':
            in_str = False
        continue
    if ch == '"':
        in_str = True
    elif ch == "[":
        depth += 1
    elif ch == "]":
        depth -= 1
        if depth == 0:
            end = i
            break

if end < 0:
    sys.exit(1)

candidate = text[start:end + 1]


def sanitize(s):
    # Strip bare control bytes inside strings (tab/newline/CR remain valid
    # escape source chars; json.loads strict=False also accepts them).
    s = re.sub(r"[\x00-\x08\x0b\x0c\x0e-\x1f]", "", s)
    # Replace invalid `\<char>` escapes (anything not in the JSON spec) with
    # the bare char. Walk the string state to avoid touching content outside
    # JSON strings.
    out = []
    i = 0
    in_str = False
    while i < len(s):
        ch = s[i]
        if in_str:
            if ch == "\\" and i + 1 < len(s):
                nxt = s[i + 1]
                if nxt in '"\\/bfnrt':
                    out.append(ch)
                    out.append(nxt)
                    i += 2
                    continue
                if nxt == "u" and i + 5 < len(s) and re.match(r"[0-9a-fA-F]{4}", s[i + 2:i + 6]):
                    out.append(s[i:i + 6])
                    i += 6
                    continue
                # Invalid escape — drop the backslash, keep the char.
                out.append(nxt)
                i += 2
                continue
            if ch == '"':
                in_str = False
            out.append(ch)
            i += 1
            continue
        if ch == '"':
            in_str = True
        out.append(ch)
        i += 1
    return "".join(out)


data = None
for attempt in (candidate, sanitize(candidate)):
    try:
        data = json.loads(attempt, strict=False)
        break
    except json.JSONDecodeError:
        continue

if isinstance(data, dict) and all(k in data for k in ("file", "line", "title", "description", "fix")):
    data = [data]

if data is None or not isinstance(data, list):
    sys.exit(1)

print(json.dumps(data))
PY
)"
  if [ -n "$RECOVERED" ]; then
    printf '%s\n' "$RECOVERED" >> "$TMP"
    merged_count=$((merged_count + 1))
    recovered_count=$((recovered_count + 1))
    echo "::warning::Recovered JSON array from preamble in $f"
    continue
  fi
  echo "::warning::Skipping malformed/non-array findings file: $f"
done

if [ "$merged_count" -eq 0 ]; then
  echo "No usable findings files after validation."
  exit 0
fi

jq -s 'add // []' "$TMP" > "$MERGED_FILE"

# Candidate admission is deliberately deterministic and fail-closed. The first
# pass is allowed to recover transport noise, but raw_findings.json may contain
# only an evidence-bearing candidate with a bounded confidence, a concrete
# mechanism, an actionable fix, and a schema-valid severity. Narrative title
# similarity is not evidence and is never used here.
TMP_VALIDATED="$(mktemp)"
trap 'rm -f "$TMP" "$TMP_VALIDATED"' EXIT
python3 - "$MERGED_FILE" "$TMP_VALIDATED" "$OUTDIR" <<'PY'
import json
import math
import os
import re
import sys

source, target, outdir = sys.argv[1:4]
diff_path = ""
for candidate_diff in (
    os.path.join(outdir, "diff.filtered.txt"),
    os.path.join(outdir, "diff.txt"),
):
    if os.path.isfile(candidate_diff):
        diff_path = candidate_diff
        break
allowed_paths = set()
if diff_path:
    with open(diff_path, "r", errors="replace") as diff_file:
        for raw in diff_file:
            if raw.startswith("diff --git "):
                parts = raw.rstrip("\n").split()
                path = parts[3]
                allowed_paths.add(path[2:] if path.startswith("b/") else path)
if os.path.isfile(os.path.join(outdir, "meta.json")):
    try:
        with open(os.path.join(outdir, "meta.json"), "r") as meta_file:
            meta = json.load(meta_file)
        allowed_paths.update(
            item.get("path") for item in meta.get("files", [])
            if isinstance(item, dict) and isinstance(item.get("path"), str)
        )
    except (OSError, ValueError, AttributeError):
        pass
inventory = os.path.join(outdir, "skill-packages.json")
if os.path.isfile(inventory):
    try:
        with open(inventory, "r") as inventory_file:
            inventory_data = json.load(inventory_file)
        def collect_paths(value):
            if isinstance(value, dict):
                for key, child in value.items():
                    if key in {"path", "skillPath", "packagePath"} and isinstance(child, str):
                        allowed_paths.add(child)
                    collect_paths(child)
            elif isinstance(value, list):
                for child in value:
                    collect_paths(child)
        collect_paths(inventory_data)
    except (OSError, ValueError):
        pass
allowed_angles = {
    "bugs", "security", "conventions", "acceptance", "seo", "aeo", "design",
    "react", "database", "tests", "api", "infra", "observability", "types",
    "i18n", "docs", "deps", "skills", "architecture", "comments", "simplify",
    "production-readiness",
}
allowed_evidence = {"diff", "execution", "contract"}
reject_classes = {
    "tooling", "tooling-owned", "unsupported", "speculative", "pre-existing", "style",
    "style-only", "generic-maintainability", "maintainability",
}
reject_text = re.compile(
    r"\b(?:eslint|biome|prettier|tsc|lint-catchable|style-only|"
    r"pre-existing|speculative|generic maintainability)\b",
    re.IGNORECASE,
)

with open(source, "r") as fh:
    candidates = json.load(fh)

kept = []
rejected = 0
for candidate in candidates:
    if not isinstance(candidate, dict):
        rejected += 1
        continue

    required = (
        "angle", "file", "line", "title", "description", "failure_mode",
        "evidence", "confidence", "severity", "blocking", "fix_type", "fix",
    )
    if any(key not in candidate for key in required):
        rejected += 1
        continue
    if candidate["angle"] not in allowed_angles:
        rejected += 1
        continue
    if not isinstance(candidate["file"], str) or not candidate["file"].strip():
        rejected += 1
        continue
    try:
        line = int(str(candidate["line"]).strip())
    except (TypeError, ValueError):
        rejected += 1
        continue
    if line <= 0:
        rejected += 1
        continue
    if "end_line" in candidate:
        try:
            end_line = int(str(candidate["end_line"]).strip())
        except (TypeError, ValueError):
            rejected += 1
            continue
        if end_line <= line:
            rejected += 1
            continue
    if candidate["severity"] not in {"HIGH", "MEDIUM", "LOW"}:
        rejected += 1
        continue
    if not isinstance(candidate["blocking"], bool):
        rejected += 1
        continue
    if candidate["fix_type"] not in {"suggestion", "prose"}:
        rejected += 1
        continue
    if not isinstance(candidate["title"], str) or not candidate["title"].strip():
        rejected += 1
        continue
    if not isinstance(candidate["description"], str) or not candidate["description"].strip():
        rejected += 1
        continue
    if not isinstance(candidate["failure_mode"], str) or not candidate["failure_mode"].strip():
        rejected += 1
        continue
    if not isinstance(candidate["fix"], str) or not candidate["fix"].strip():
        rejected += 1
        continue

    confidence = candidate["confidence"]
    if isinstance(confidence, bool) or not isinstance(confidence, (int, float)):
        rejected += 1
        continue
    if not math.isfinite(confidence) or confidence < 0 or confidence > 1:
        rejected += 1
        continue

    evidence = candidate["evidence"]
    if not isinstance(evidence, dict):
        rejected += 1
        continue
    if evidence.get("basis") not in allowed_evidence:
        rejected += 1
        continue
    if not isinstance(evidence.get("detail"), str) or not evidence["detail"].strip():
        rejected += 1
        continue
    if len(evidence["detail"]) > 2000:
        rejected += 1
        continue
    related = evidence.get("related_files", [])
    if not isinstance(related, list) or any(
        not isinstance(path, str) or not path.strip() for path in related
    ):
        rejected += 1
        continue
    if any(path not in allowed_paths for path in related):
        rejected += 1
        continue

    classes = {
        str(candidate.get(key, "")).strip().lower()
        for key in ("classification", "disposition", "category")
        if candidate.get(key) is not None
    }
    if classes & reject_classes:
        rejected += 1
        continue
    if any(candidate.get(key) is True for key in (
        "tooling_owned", "speculative", "pre_existing", "style_only",
        "generic_maintainability",
    )):
        rejected += 1
        continue
    narrative = " ".join(
        str(candidate.get(key, "")) for key in
        ("title", "description", "failure_mode", "fix")
    )
    if reject_text.search(narrative):
        rejected += 1
        continue

    kept.append(candidate)

with open(target, "w") as fh:
    json.dump(kept, fh)
print(f"merge-findings: candidate admission rejected {rejected} candidate(s)", file=sys.stderr)
PY
mv "$TMP_VALIDATED" "$MERGED_FILE"

# Safety net: validate each finding's start and optional endpoint on the RIGHT
# side of the prefetched diff. Invalid starts are dropped; invalid ranges
# degrade to the valid start so one bad endpoint cannot sink the review.
DIFF_FOR_RESOLVE=""
if [ -s "$OUTDIR/diff.filtered.txt" ]; then
  DIFF_FOR_RESOLVE="$OUTDIR/diff.filtered.txt"
elif [ -s "$OUTDIR/diff.txt" ]; then
  DIFF_FOR_RESOLVE="$OUTDIR/diff.txt"
fi

if [ -n "$DIFF_FOR_RESOLVE" ] && [ -f "$SCRIPT_DIR/resolve-diff-line.sh" ]; then
  PRE_RESOLVE=$(jq 'length' "$MERGED_FILE")
  TMP_RESOLVED="$(mktemp)"
  trap 'rm -f "$TMP" "$TMP_RESOLVED"' EXIT
  python3 - "$MERGED_FILE" "$TMP_RESOLVED" "$SCRIPT_DIR/resolve-diff-line.sh" "$OUTDIR" "$DIFF_FOR_RESOLVE" <<'PY'
import json
import os
import re
import subprocess
import sys

merged_path, out_path, resolver, outdir, diff_path = sys.argv[1:6]

with open(merged_path, "r") as fh:
    findings = json.load(fh)

added_lines = {}
current_path = None
right_line = None
with open(diff_path, "r", errors="replace") as diff_file:
    for raw in diff_file:
        text = raw.rstrip("\n")
        if text.startswith("diff --git "):
            parts = text.split()
            path = parts[3] if len(parts) >= 4 else None
            current_path = path[2:] if path and path.startswith("b/") else path
            right_line = None
            continue
        if current_path is None:
            continue
        match = re.match(r"^@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@", text)
        if match:
            right_line = int(match.group(1))
            continue
        if right_line is None or text.startswith("\\"):
            continue
        if text.startswith("+++ "):
            continue
        if text.startswith("+"):
            added_lines.setdefault(current_path, set()).add(right_line)
            right_line += 1
        elif text.startswith(" "):
            right_line += 1


kept = []
dropped = 0
degraded = 0
for finding in findings:
    path = finding.get("file")
    line = finding.get("line")
    if not path or line in (None, ""):
        dropped += 1
        continue
    try:
        requested_line = int(str(line).strip())
    except (TypeError, ValueError):
        dropped += 1
        continue
    if requested_line not in added_lines.get(path, set()):
        dropped += 1
        continue

    command = [
        "bash", resolver,
        "--file", str(path),
        "--line", str(line),
    ]
    has_end = "end_line" in finding
    if has_end:
        command.extend(["--end", str(finding.get("end_line"))])

    try:
        result = subprocess.run(
            command,
            env={"OUTDIR": outdir, "PATH": os.environ.get("PATH", "")},
            check=False,
            capture_output=True,
            text=True,
        )
    except OSError:
        dropped += 1
        continue

    resolved = result.stdout.strip()
    if result.returncode != 0 or resolved == "null" or not resolved:
        dropped += 1
        continue
    if not has_end:
        kept.append(finding)
        continue

    try:
        if ":" in resolved:
            start_text, end_text = resolved.split(":", 1)
            canonical_start = int(start_text)
            canonical_end = int(end_text)
        else:
            canonical_start = int(resolved)
            canonical_end = None
    except ValueError:
        dropped += 1
        continue

    normalized = dict(finding)
    normalized["line"] = canonical_start
    if canonical_end is not None:
        normalized["end_line"] = canonical_end
    else:
        normalized.pop("end_line", None)
        if has_end:
            degraded += 1
    kept.append(normalized)

with open(out_path, "w") as fh:
    json.dump(kept, fh)

message = (
    "merge-findings: resolve-diff-line "
    f"dropped {dropped} finding(s) with unresolvable lines"
)
if degraded:
    message += f"; degraded {degraded} invalid range(s)"
sys.stderr.write(message + "\n")
PY
  mv "$TMP_RESOLVED" "$MERGED_FILE"
  POST_RESOLVE=$(jq 'length' "$MERGED_FILE")
  if [ "$PRE_RESOLVE" != "$POST_RESOLVE" ]; then
    echo "Merge: line-resolve safety net dropped $((PRE_RESOLVE - POST_RESOLVE)) finding(s)"
  fi
else
  echo "::warning::Merge rejected candidates because no diff resolver was available"
  echo "[]" > "$MERGED_FILE"
fi

if [ "$recovered_count" -gt 0 ]; then
  echo "Merge: recovered JSON from $recovered_count file(s) with preamble"
fi

# Cross-chunk and cross-angle duplicates share one deterministic identity:
# canonical changed path plus canonical RIGHT-side start line. This deliberately
# collapses paraphrased failure mechanisms at the same anchor while retaining
# separate findings on different changed anchors.
BEFORE_COUNT=$(jq 'length' "$MERGED_FILE")
python3 - "$MERGED_FILE" "$MERGED_FILE.deduped" <<'PY'
import json
import sys

source, target = sys.argv[1:3]
with open(source, "r") as fh:
    findings = json.load(fh)

seen = set()
kept = []
for finding in findings:
    key = (finding["file"].strip(), int(str(finding["line"]).strip()))
    if key in seen:
        continue
    seen.add(key)
    kept.append(finding)

with open(target, "w") as fh:
    json.dump(kept, fh)
PY
mv "$MERGED_FILE.deduped" "$MERGED_FILE"
AFTER_COUNT=$(jq 'length' "$MERGED_FILE")

echo "Merged $merged_count finding files into $MERGED_FILE (anchor dedup: $BEFORE_COUNT -> $AFTER_COUNT)"
