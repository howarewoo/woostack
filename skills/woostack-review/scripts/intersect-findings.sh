#!/usr/bin/env bash
# Finalize the one independently adjudicated finding set.
# The adjudicator writes findings.adjudicator.json; this script applies deterministic severity,
# deferral, and changed-line ownership before publishing findings.json exactly once.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$SCRIPT_DIR/resolve-outdir.sh"
SOURCE="$OUTDIR/findings.adjudicator.json"
FINAL="$OUTDIR/findings.json"
METRICS="$OUTDIR/validator-metrics.json"
CONFIG="$OUTDIR/config.json"
[ -s "$SOURCE" ] || { echo "::error::intersect-findings: missing adjudicator output: $SOURCE" >&2; exit 1; }
jq -e 'type == "array"' "$SOURCE" >/dev/null || { echo "::error::intersect-findings: adjudicator output is not an array" >&2; exit 1; }
severity_floor="high"; nits_enabled="true"; defer_markers_enabled="true"; metrics_enabled="false"
if [ -s "$CONFIG" ]; then
  severity_floor="$(jq -r '.severity_floor // "high"' "$CONFIG" 2>/dev/null | tr '[:upper:]' '[:lower:]')"
  [ "$severity_floor" = low ] || [ "$severity_floor" = medium ] || [ "$severity_floor" = high ] || severity_floor=high
  [ "$(jq -r 'if has("nits") then .nits else true end' "$CONFIG" 2>/dev/null)" = false ] && nits_enabled=false
  [ "$(jq -r 'if has("defer_markers") then .defer_markers else true end' "$CONFIG" 2>/dev/null)" = false ] && defer_markers_enabled=false
  [ "$(jq -r '.metrics // false' "$CONFIG" 2>/dev/null)" = true ] && metrics_enabled=true
fi
TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT
python3 - "$SOURCE" "$TMP" "$severity_floor" "$nits_enabled" "$defer_markers_enabled" <<'PY'
import json, math, sys
source, target, floor, nits, defer = sys.argv[1:]
ranks = {"LOW": 0, "MEDIUM": 1, "HIGH": 2}
allowed_angles = {
    "bugs", "security", "conventions", "acceptance", "seo", "aeo", "design",
    "database", "tests", "api", "infra", "observability", "i18n", "docs",
    "deps", "skills", "architecture", "comments", "simplify", "production-readiness",
}
required_strings = ("file", "title", "description", "failure_mode", "fix")
items = json.load(open(source))
if not isinstance(items, list):
    raise SystemExit("adjudicator output is not an array")
result = []
def invalid(index, reason):
    raise SystemExit(f"invalid adjudicator finding {index}: {reason}")
for index, item in enumerate(items):
    if not isinstance(item, dict):
        invalid(index, "not an object")
    if item.get("angle") not in allowed_angles:
        invalid(index, "unsupported angle")
    if any(not isinstance(item.get(key), str) or not item[key].strip() for key in required_strings):
        invalid(index, "missing required string")
    line = item.get("line")
    if isinstance(line, bool) or not isinstance(line, int) or line <= 0:
        invalid(index, "invalid line")
    if "end_line" in item and (
        isinstance(item["end_line"], bool)
        or not isinstance(item["end_line"], int)
        or item["end_line"] <= line
    ):
        invalid(index, "invalid end_line")
    if item.get("severity") not in ranks or not isinstance(item.get("blocking"), bool):
        invalid(index, "invalid severity or blocking")
    confidence = item.get("confidence")
    if isinstance(confidence, bool) or not isinstance(confidence, (int, float)):
        invalid(index, "invalid confidence")
    if not math.isfinite(confidence) or not 0 <= confidence <= 1:
        invalid(index, "invalid confidence")
    evidence = item.get("evidence")
    if not isinstance(evidence, dict) or evidence.get("basis") not in {"diff", "execution", "contract"}:
        invalid(index, "invalid evidence basis")
    if not isinstance(evidence.get("detail"), str) or not evidence["detail"].strip():
        invalid(index, "missing evidence detail")
    if item.get("fix_type") not in {"suggestion", "prose"}:
        invalid(index, "invalid fix_type")
    copy = dict(item)
    if copy["fix_type"] == "suggestion":
        suggestion = copy.get("suggestion")
        if not isinstance(suggestion, str) or not suggestion.strip() or len(suggestion.splitlines()) > 10:
            copy["fix_type"] = "prose"
            copy["suggestion"] = None
    else:
        copy["suggestion"] = None
    deferred = copy.get("deferred_to")
    if defer != "false" and copy["angle"] != "security" and isinstance(deferred, str) and deferred.strip():
        copy["nit"] = True
        copy["blocking"] = False
    else:
        rank = ranks[copy["severity"]]
        if rank >= ranks[floor.upper()] or copy["blocking"]:
            copy["nit"] = False
        elif nits != "false":
            copy["nit"] = True
            copy["blocking"] = False
        else:
            continue
    result.append(copy)
with open(target, "w") as fh:
    json.dump(result, fh, indent=2)
    fh.write("\n")
PY
mv "$TMP" "$FINAL"
resolver="$SCRIPT_DIR/resolve-diff-line.sh"; diff_path=""
[ -s "$OUTDIR/diff.filtered.txt" ] && diff_path="$OUTDIR/diff.filtered.txt"
[ -n "$diff_path" ] || [ ! -s "$OUTDIR/diff.txt" ] || diff_path="$OUTDIR/diff.txt"
if [ -n "$diff_path" ] && [ -f "$resolver" ]; then
  TMP="$(mktemp)"
  python3 - "$FINAL" "$TMP" "$OUTDIR" "$resolver" <<'PY'
import json, os, subprocess, sys
source, target, outdir, resolver = sys.argv[1:]
findings = json.load(open(source)); allowed = set()
for name in ("changed-paths.filtered.txt", "changed-paths.txt"):
    path = os.path.join(outdir, name)
    if os.path.isfile(path): allowed.update(x.strip() for x in open(path) if x.strip())
if not allowed and os.path.isfile(os.path.join(outdir, "meta.json")):
    try:
        meta = json.load(open(os.path.join(outdir, "meta.json"))); allowed.update(x.get("path") for x in meta.get("files", []) if isinstance(x, dict) and x.get("path"))
    except (OSError, ValueError, AttributeError): pass
kept = []
for finding in findings:
    path, line = finding.get("file"), finding.get("line")
    if not path or line is None: continue
    if allowed and path not in allowed: continue
    cmd = ["bash", resolver, "--file", str(path), "--line", str(line)]
    if "end_line" in finding: cmd += ["--end", str(finding.get("end_line"))]
    try: resolved = subprocess.run(cmd, env={"OUTDIR": outdir, "PATH": os.environ.get("PATH", "")}, capture_output=True, text=True, check=False)
    except OSError: continue
    value = resolved.stdout.strip()
    if resolved.returncode or not value or value == "null": continue
    try:
        if ":" in value: start, end = (int(x) for x in value.split(":", 1))
        else: start, end = int(value), None
    except ValueError: continue
    normalized = dict(finding); normalized["line"] = start
    if end is None: normalized.pop("end_line", None)
    else: normalized["end_line"] = end
    kept.append(normalized)
with open(target, "w") as fh: json.dump(kept, fh, indent=2); fh.write("\n")
PY
  mv "$TMP" "$FINAL"
fi
if [ "$metrics_enabled" = true ]; then
  python3 - "$OUTDIR/raw_findings.json" "$FINAL" "$OUTDIR/findings.metrics.json" <<'PY'
import json, os, re, sys
raw_path, final_path, target = sys.argv[1:]
def load(path):
    try:
        with open(path) as fh:
            value = json.load(fh)
        return value if isinstance(value, list) else []
    except (OSError, ValueError):
        return []
raw, final = load(raw_path), load(final_path)
def angle(item):
    value = item.get("angle")
    return value if isinstance(value, str) and value else "_unknown"
def counts(items):
    result = {}
    for item in items:
        result[angle(item)] = result.get(angle(item), 0) + 1
    return result
raw_counts, final_counts = counts(raw), counts(final)
angles = sorted(set(raw_counts) | set(final_counts))
clusters = {}
for item in raw:
    path, line = item.get("file"), item.get("line")
    if not path or isinstance(line, bool) or not isinstance(line, int) or line <= 0:
        continue
    stem = re.sub(r"[^a-z0-9]+", "", str(item.get("title", "")).lower())[:40]
    clusters.setdefault((path, line, stem), set()).add(angle(item))
overlap = {name: {} for name in angles}
for names in clusters.values():
    if len(names) < 2:
        continue
    for name in names:
        for other in names:
            if name != other:
                overlap[name][other] = overlap[name].get(other, 0) + 1
severity_names = ("HIGH", "MEDIUM", "LOW")
records = {}
for name in angles:
    kept = final_counts.get(name, 0)
    selected = [item for item in final if angle(item) == name]
    related = overlap.get(name, {})
    records[name] = {
        "raw_count": raw_counts.get(name, 0),
        "adjudicator_kept": kept,
        "kept": kept,
        "dropped_by_adjudicator": max(0, raw_counts.get(name, 0) - kept),
        "blocking_count": sum(item.get("blocking") is True for item in selected),
        "nit_count": sum(item.get("nit") is True for item in selected),
        "nonblocking_count": sum(item.get("blocking") is False and item.get("nit") is not True for item in selected),
        "severity": {severity: sum(item.get("severity") == severity for item in selected) for severity in severity_names},
        "overlap_total": sum(related.values()),
        "overlap_with": related,
    }
with open(target, "w") as fh:
    json.dump({"schema_version": 4, "mode": "adjudicator", "degraded": False, "angles": records}, fh, indent=2, sort_keys=True)
    fh.write("\n")
PY
fi
kept_count="$(jq 'length' "$FINAL")"; nit_count="$(jq '[.[] | select(.nit == true)] | length' "$FINAL")"; deferred_count="$(jq '[.[] | select((.deferred_to // "") != "" and .nit == true)] | length' "$FINAL")"
jq -n --argjson kept "$kept_count" --argjson nits "$nit_count" --argjson deferred "$deferred_count" '{mode:"adjudicator", degraded:false, adjudicator_count:$kept, kept_count:$kept, nit_count:$nits, deferred_count:$deferred}' > "$METRICS"
echo "intersect-findings: mode=adjudicator kept=$kept_count nits=$nit_count"
