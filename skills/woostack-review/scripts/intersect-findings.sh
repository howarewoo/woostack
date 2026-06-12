#!/usr/bin/env bash
# intersect-findings.sh — adversarial validator merge step (issue #13).
#
# Inputs (in $OUTDIR, defaults to /tmp/pr-review):
#   findings.prosecutor.json   array — output of validator-prosecutor.md
#   findings.defender.json     array — output of validator.md (defender)
#   config.json                {disable_adversarial?: bool, ...}
#
# Outputs:
#   findings.json              final validated findings (intersection, or
#                              copy of defender output when adversarial is off)
#   validator-metrics.json     {prosecutor_count, defender_count,
#                               kept_count, disagreement_count,
#                               dropped_by_defender, dropped_by_prosecutor,
#                               deferred_count, mode: "adversarial" | "defender-only",
#                               degraded: bool}
#
# Intersection key: four-pass match. Pass 1 is exact `(file, line, title_stem)`
# where `title_stem` is lowercase alphanumeric truncated to 40 chars — same
# key used by prior-thread dedupe in _header.md so the two stay consistent.
# Pass 2 is a fuzzy fallback for the unmatched remainder: same `file`, line
# within ±10, and `title_stem` matches on its first 20 characters (so minor
# rewording survives). Ties resolved by smallest absolute line delta. Pass 3 is
# a location-only fallback: same `file` and line within ±10 with NO title
# constraint, smallest delta wins, ambiguous ties skipped. It exists because
# cross-angle dedupe in merge-findings.sh can leave the same issue with
# different titles in the two validator inputs, so the title-gated passes drop a
# finding both passes actually agreed on (the bug behind disagreement_count
# inflation). Pass 4 is a title-similarity fallback with NO line window: passes
# 1-3 ALL gate on |line delta| <= 10, so a finding both validators kept but
# anchored far apart in the same file (one at the buggy line, the other at a
# contrast line — e.g. action.yml:231 vs :314 for the same Anthropic-runner
# issue) is still dropped. Pass 4 pairs the remaining unmatched defender
# findings to a same-file prosecutor finding by distinctive title-token overlap
# alone, requiring >= 2 shared significant tokens AND an unambiguous winner.
# Dropping agreed findings is a worse failure than an occasional over-merge, and
# the merge is conservative (lower severity, AND of blocking), so a wrong
# pairing can never escalate a finding. Together these stop genuine agreement
# from being dropped when the two validators anchor the same finding at
# slightly different lines (e.g. 33 vs 39 for the same REVOKE block), reword the
# headline past the prefix-20 cutoff, or anchor it at unrelated lines entirely.
#
# When `disable_adversarial: true` is set in config.json, OR
# findings.prosecutor.json is missing/empty, intersection is skipped and
# findings.defender.json is copied verbatim to findings.json. This is the
# cost-sensitive opt-out described in issue #13's acceptance criteria.
#
# Merge rules for findings present in BOTH passes:
#   - severity: take the LOWER (more conservative) of the two values
#               (LOW < MEDIUM < HIGH).
#   - blocking: AND of the two (`true` only if both passes say blocking).
#   - other fields (title, description, fix, suggestion, fix_type, rule_quote):
#     prefer the DEFENDER's copy — it ran the stricter shape + fix_type checks
#     so its rewrites are the canonical version.

set -euo pipefail

# shellcheck source=skills/woostack-review/scripts/resolve-outdir.sh
source "$(dirname "${BASH_SOURCE[0]:-$0}")/resolve-outdir.sh"
PROSECUTOR="$OUTDIR/findings.prosecutor.json"
DEFENDER="$OUTDIR/findings.defender.json"
FINAL="$OUTDIR/findings.json"
PRECLASSIFY="$OUTDIR/findings.preclassify.json"
METRICS="$OUTDIR/validator-metrics.json"
CONFIG="$OUTDIR/config.json"

# Resolve disable_adversarial from config.json (default false).
disable_adversarial="false"
if [ -f "$CONFIG" ]; then
  v="$(jq -r '.disable_adversarial // false' "$CONFIG" 2>/dev/null || echo false)"
  case "$v" in true|false) disable_adversarial="$v" ;; *) disable_adversarial="false" ;; esac
fi

# Resolve metrics opt-in from config.json (default false). Gates the per-angle
# findings.metrics.json emit (issue #41). validator-metrics.json is unaffected.
metrics_enabled="false"
if [ -f "$CONFIG" ]; then
  v="$(jq -r '.metrics // false' "$CONFIG" 2>/dev/null || echo false)"
  case "$v" in true|false) metrics_enabled="$v" ;; *) metrics_enabled="false" ;; esac
fi

# Resolve nits opt-out from config.json (default true). NOTE: jq's `//` treats
# `false` as empty, so `.nits // true` would coerce an explicit false back to
# true — detect the opt-out explicitly instead.
nits_enabled="true"
if [ -f "$CONFIG" ]; then
  v="$(jq -r '.nits' "$CONFIG" 2>/dev/null || echo null)"
  [ "$v" = "false" ] && nits_enabled="false"
fi

# Resolve defer_markers opt-out from config.json (default true). false => never
# honor woostack-defer markers; the floor classifier ignores deferred_to.
defer_markers_enabled="true"
if [ -f "$CONFIG" ]; then
  v="$(jq -r '.defer_markers' "$CONFIG" 2>/dev/null || echo null)"
  [ "$v" = "false" ] && defer_markers_enabled="false"
fi

# Resolve severity_floor (default high). Already shape-validated by
# load-config.sh; re-default defensively here since this is the floor's home.
severity_floor="$(jq -r '.severity_floor // "high"' "$CONFIG" 2>/dev/null | tr '[:upper:]' '[:lower:]')"
case "$severity_floor" in low|medium|high) ;; *) severity_floor="high" ;; esac

RAW="$OUTDIR/raw_findings.json"
ANGLE_METRICS="$OUTDIR/findings.metrics.json"

# Defender output is mandatory. If absent we cannot post a review at all —
# upstream is broken and we should fail loudly.
if [ ! -s "$DEFENDER" ]; then
  echo "::error::intersect-findings: $DEFENDER missing or empty — defender validator did not run" >&2
  exit 1
fi
if ! jq -e 'type == "array"' "$DEFENDER" >/dev/null 2>&1; then
  echo "::error::intersect-findings: $DEFENDER is not a JSON array" >&2
  exit 1
fi

defender_count="$(jq 'length' "$DEFENDER")"

# Defender-only path (adversarial disabled OR prosecutor file missing).
prosecutor_present="false"
if [ -s "$PROSECUTOR" ] && jq -e 'type == "array"' "$PROSECUTOR" >/dev/null 2>&1; then
  prosecutor_present="true"
fi

# Single writer for validator-metrics.json so the two emit sites share one
# schema. Args: mode degraded prosecutor_count defender_count kept_count
# disagreement dropped_by_defender dropped_by_prosecutor. Numeric/null args are
# raw JSON (e.g. `null`, `0`); degraded is `true`/`false`.
write_metrics() {
  jq -n \
    --arg mode "$1" \
    --argjson degraded "$2" \
    --argjson prosecutor_count "$3" \
    --argjson defender_count "$4" \
    --argjson kept_count "$5" \
    --argjson disagreement_count "$6" \
    --argjson dropped_by_defender "$7" \
    --argjson dropped_by_prosecutor "$8" \
    --argjson nit_count "$9" \
    --argjson deferred_count "${10}" \
    '{
      mode: $mode,
      degraded: $degraded,
      prosecutor_count: $prosecutor_count,
      defender_count: $defender_count,
      kept_count: $kept_count,
      disagreement_count: $disagreement_count,
      dropped_by_defender: $dropped_by_defender,
      dropped_by_prosecutor: $dropped_by_prosecutor,
      nit_count: $nit_count,
      deferred_count: $deferred_count
    }' > "$METRICS"
}

# Per-angle signal/noise breakdown (issue #41). Writes findings.metrics.json
# keyed by angle. No-op unless metrics_enabled=true. Reads the merged raw set
# plus both validator passes and the final intersection — all already on disk —
# and attributes counts by each finding's .angle. In defender-only mode the
# prosecutor file is absent; prosecutor-derived numbers come out null.
# Args: mode degraded
emit_angle_metrics() {
  [ "$metrics_enabled" = "true" ] || return 0
  python3 - "$RAW" "$PROSECUTOR" "$DEFENDER" "$FINAL" "$ANGLE_METRICS" "$1" "$2" "$PRECLASSIFY" <<'PY'
import json, re, sys

raw_p, pros_p, def_p, final_p, out_p, mode, degraded, pre_p = sys.argv[1:9]

def load(path):
    try:
        with open(path) as fh:
            data = json.load(fh)
        return data if isinstance(data, list) else []
    except (OSError, ValueError):
        return []

def present(path):
    try:
        open(path).close()
        return True
    except OSError:
        return False

raw_present = present(raw_p)
raw   = load(raw_p)
defn  = load(def_p)
final = load(final_p)
has_pros = mode != "defender-only"
pros = load(pros_p) if has_pros else []

def angle_of(f):
    a = f.get("angle")
    return a if isinstance(a, str) and a else "_unknown"

def count_by_angle(items):
    out = {}
    for f in items:
        out[angle_of(f)] = out.get(angle_of(f), 0) + 1
    return out

raw_c, pros_c, def_c, final_c = (count_by_angle(x) for x in (raw, pros, defn, final))
# Pre-floor intersection per angle: the cross-pass agreement BEFORE the floor
# classifier dropped any below-floor non-blocking findings (nits:false). The
# per-angle dropped_by_* disagreement counts are based on this, not the
# post-floor `final`, so a floor-drop is never miscounted as cross-pass
# disagreement (mirrors the top-level intersection_size accounting). Falls back
# to final_c when no snapshot exists (nits:on => pre == final anyway).
pre = load(pre_p)
pre_c = count_by_angle(pre) if pre else final_c
angles = sorted(set(raw_c) | set(pros_c) | set(def_c) | set(final_c))

SEVS = ("HIGH", "MEDIUM", "LOW")

def sev_hist(items, a):
    h = {s: 0 for s in SEVS}
    for f in items:
        if angle_of(f) == a:
            s = (f.get("severity") or "").upper()
            if s in h:
                h[s] += 1
    return h

def blocking_count(items, a):
    return sum(1 for f in items if angle_of(f) == a and bool(f.get("blocking", False)))

# Cross-angle overlap (redundancy signal). Cluster RAW findings by identity
# key (file, line, title_stem) — the merge-findings dedup key minus `angle` —
# so the same logical issue raised by multiple angles lands in one cluster.
# Unanchored findings (no file or no positive integer line) are EXCLUDED:
# without a stable anchor they cannot credibly be "the same issue" as another,
# and would otherwise form phantom clusters under a degenerate key.
def _title_stem(s):
    return re.sub(r"[^a-z0-9]+", "", (s or "").lower())[:40]

clusters = {}
for f in raw:
    file = f.get("file")
    try:
        line = int(f.get("line"))
    except (TypeError, ValueError):
        continue
    if not file or line <= 0:
        continue
    key = (file, line, _title_stem(f.get("title")))
    clusters.setdefault(key, set()).add(angle_of(f))

overlap_with = {a: {} for a in angles}
for angle_set in clusters.values():
    if len(angle_set) < 2:
        continue
    for a in angle_set:
        bucket = overlap_with.setdefault(a, {})
        for b in angle_set:
            if a != b:
                bucket[b] = bucket.get(b, 0) + 1

out = {"schema_version": 3, "mode": mode, "degraded": degraded == "true", "angles": {}}

for a in angles:
    kept = final_c.get(a, 0)
    defk = def_c.get(a, 0)
    blk  = blocking_count(final, a)
    rawn = raw_c.get(a, 0) if raw_present else max(defk, kept, pros_c.get(a, 0))
    nit = sum(1 for f in final if angle_of(f) == a and bool(f.get("nit")))
    rec = {
        "raw_count": rawn,
        "defender_kept": defk,
        "kept": kept,
        "dropped_by_prosecutor": max(0, defk - pre_c.get(a, 0)),
        "blocking_count": blk,
        "nit_count": nit,
        "nonblocking_count": kept - blk - nit,
        "severity": sev_hist(final, a),
    }
    ow = overlap_with.get(a, {})
    rec["overlap_with"] = ow
    rec["overlap_total"] = sum(ow.values())
    if has_pros:
        prok = pros_c.get(a, 0)
        rec["prosecutor_kept"] = prok
        rec["dropped_by_defender"] = max(0, prok - pre_c.get(a, 0))
    else:
        rec["prosecutor_kept"] = None
        rec["dropped_by_defender"] = None
    out["angles"][a] = rec

with open(out_p, "w") as fh:
    json.dump(out, fh, indent=2, sort_keys=True)
    fh.write("\n")
PY
}

# Floor classifier — reframes severity_floor from a drop gate into a
# blocking/visibility threshold. Rewrites $FINAL in place, setting an explicit
# `nit` boolean on every surviving finding:
#   at/above floor                         -> nit:false (normal, unchanged)
#   below floor + blocking:true            -> nit:false (blocking overrides floor)
#   below floor + non-blocking + nits on   -> nit:true, blocking:false (nit)
#   below floor + non-blocking + nits off  -> dropped
# Runs on the merged findings.json in BOTH validator modes so the floor has one
# implementation across swarm, CI, and defender-only paths.
classify_floor() {
  python3 - "$FINAL" "$severity_floor" "$nits_enabled" "$defer_markers_enabled" <<'PY'
import json, sys

final_p, floor, nits, defer_markers = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
RANK = {"low": 0, "medium": 1, "high": 2}
floor_rank = RANK.get(floor, 2)
nits_on = nits != "false"
defer_on = defer_markers != "false"

try:
    findings = json.load(open(final_p))
    if not isinstance(findings, list):
        findings = []
except (OSError, ValueError):
    findings = []

out = []
for f in findings:
    # Stack-aware deferral (issue #224): a finding the defender confirmed a later
    # increment fills (via a woostack-defer marker) is forced to a non-blocking
    # nit, INDEPENDENT of the floor. Hard off-switch: defer_markers=false
    # ignores it.
    dt = f.get("deferred_to")
    if defer_on and isinstance(dt, str) and dt.strip():
        f["nit"] = True
        f["blocking"] = False
        out.append(f)
        continue

    # Unknown/missing severity -> MEDIUM (matches sev_rank() used in the merge).
    rank = RANK.get((f.get("severity") or "").lower(), 1)
    if rank >= floor_rank:
        f["nit"] = False
        out.append(f)
    elif bool(f.get("blocking")):           # blocking overrides the floor
        f["nit"] = False
        out.append(f)
    elif nits_on:
        f["nit"] = True
        f["blocking"] = False
        out.append(f)
    # else: below floor, non-blocking, nits off -> drop

with open(final_p, "w") as fh:
    json.dump(out, fh, indent=2)
    fh.write("\n")
PY
}

if [ "$disable_adversarial" = "true" ] || [ "$prosecutor_present" = "false" ]; then
  mode="defender-only"
  # degraded = the adversarial pass was EXPECTED but the prosecutor output is
  # missing/invalid (a silent failure). A legitimate `disable_adversarial: true`
  # opt-out is NOT degraded. Only the former should be surfaced to the user.
  degraded="false"
  if [ "$disable_adversarial" != "true" ]; then
    degraded="true"
    echo "::warning::intersect-findings: prosecutor findings absent — falling back to defender-only output (degraded)" >&2
  fi
  cp "$DEFENDER" "$FINAL"
  cp "$FINAL" "$PRECLASSIFY"   # pre-floor snapshot for per-angle disagreement metrics
  classify_floor
  kept_count="$(jq 'length' "$FINAL")"
  nit_count="$(jq '[.[] | select(.nit == true)] | length' "$FINAL")"
  deferred_count="$(jq '[.[] | select((.deferred_to // "") != "" and .nit == true)] | length' "$FINAL")"
  write_metrics "$mode" "$degraded" null "$defender_count" "$kept_count" 0 0 0 "$nit_count" "$deferred_count"
  echo "intersect-findings: mode=$mode degraded=$degraded kept=$kept_count nits=$nit_count"
  emit_angle_metrics "$mode" "$degraded" || echo "::warning::emit_angle_metrics failed (non-fatal)" >&2
  exit 0
fi

prosecutor_count="$(jq 'length' "$PROSECUTOR")"

# Two-pass intersection. Pass 1 is exact (file, line, title_stem). Pass 2
# attempts fuzzy match for the remainder: same file, |line_a - line_b| <= 10,
# title_stem prefix-20 matches, smallest line delta wins ties. A defender
# finding can match at most one prosecutor finding; each match is consumed.
python3 - "$PROSECUTOR" "$DEFENDER" "$FINAL" <<'PY'
import json
import re
import sys

prosecutor_path, defender_path, final_path = sys.argv[1:4]

with open(prosecutor_path, "r") as fh:
    prosecutor = json.load(fh)
with open(defender_path, "r") as fh:
    defender = json.load(fh)


def title_stem(s):
    return re.sub(r"[^a-z0-9]+", "", (s or "").lower())[:40]


def title_stem_prefix(s, n=20):
    return title_stem(s)[:n]


# Generic review filler that carries no identifying signal. Excluded from the
# significant-token set so two unrelated findings can't pair on shared filler.
_TITLE_STOPWORDS = {
    "always", "never", "value", "values", "when", "that", "this", "with",
    "from", "into", "your", "will", "does", "only", "also", "more", "less",
    "than", "then", "here", "there", "where", "which", "what", "while",
    "each", "both", "same", "other", "uses", "used", "should", "could",
    "would", "must", "missing", "incorrect", "wrong", "issue",
}


def significant_tokens(s):
    """Distinctive title tokens: alphanumeric words >=4 chars, lowercased,
    minus generic filler. Used by pass 4 to pair the same finding when the two
    validators reword the headline AND anchor it far apart (so the line-gated
    passes 1-3 all miss). Returns a set for overlap counting."""
    return {
        t for t in re.split(r"[^a-z0-9]+", (s or "").lower())
        if len(t) >= 4 and t not in _TITLE_STOPWORDS
    }


def safe_line(v):
    try:
        return int(v)
    except (TypeError, ValueError):
        return 0


SEV_RANK = {"LOW": 0, "MEDIUM": 1, "HIGH": 2}
SEV_LABEL = {0: "LOW", 1: "MEDIUM", 2: "HIGH"}


def sev_rank(s):
    return SEV_RANK.get((s or "").upper(), 1)


def sev_label(n):
    return SEV_LABEL.get(max(0, min(2, n)), "MEDIUM")


def exact_key(f):
    return (
        f.get("file") or "",
        safe_line(f.get("line")),
        title_stem(f.get("title")),
    )


# Pass 1: exact tuple match.
pros_by_exact = {}
for pf in prosecutor:
    pros_by_exact.setdefault(exact_key(pf), []).append(pf)

kept = []
matched_pros_ids = set()
unmatched_def = []

for df in defender:
    key = exact_key(df)
    pool = pros_by_exact.get(key, [])
    chosen = None
    for pf in pool:
        if id(pf) in matched_pros_ids:
            continue
        chosen = pf
        break
    if chosen is None:
        unmatched_def.append(df)
        continue
    matched_pros_ids.add(id(chosen))
    merged = dict(df)
    merged["severity"] = sev_label(min(sev_rank(df.get("severity")), sev_rank(chosen.get("severity"))))
    merged["blocking"] = bool(df.get("blocking", False)) and bool(chosen.get("blocking", False))
    kept.append(merged)

# Pass 2: fuzzy fallback. For each unmatched defender finding, find the
# closest unmatched prosecutor finding by same `file`, |line delta| <= 10,
# prefix-20 title stem equal. Ties broken by smallest line delta.
LINE_WINDOW = 10
fuzzy_matches = 0
for df in unmatched_def[:]:
    df_file = df.get("file") or ""
    df_line = safe_line(df.get("line"))
    df_prefix = title_stem_prefix(df.get("title"))
    if not df_file or not df_prefix:
        continue
    best = None
    best_delta = LINE_WINDOW + 1
    for pf in prosecutor:
        if id(pf) in matched_pros_ids:
            continue
        if (pf.get("file") or "") != df_file:
            continue
        pf_line = safe_line(pf.get("line"))
        delta = abs(df_line - pf_line)
        if delta > LINE_WINDOW:
            continue
        if title_stem_prefix(pf.get("title")) != df_prefix:
            continue
        if delta < best_delta:
            best = pf
            best_delta = delta
    if best is None:
        continue
    matched_pros_ids.add(id(best))
    unmatched_def.remove(df)
    merged = dict(df)
    merged["severity"] = sev_label(min(sev_rank(df.get("severity")), sev_rank(best.get("severity"))))
    merged["blocking"] = bool(df.get("blocking", False)) and bool(best.get("blocking", False))
    kept.append(merged)
    fuzzy_matches += 1

# Pass 3: location-only fallback. Cross-angle dedupe in merge-findings.sh can
# leave the SAME issue with different titles in the two validator inputs, so
# passes 1 and 2 (both title-gated) drop it even though both passes agreed.
# Here we match the remaining unmatched defender findings on `(file, line)`
# proximity alone — no title constraint — within the same ±10 window, smallest
# line delta wins. An ambiguous tie (two prosecutor candidates equidistant) is
# skipped to avoid an arbitrary merge. Rationale: dropping a finding both passes
# raised is a worse failure than an occasional over-merge, and the merge is
# conservative (lower severity, AND of blocking), so a wrong pairing cannot
# escalate a finding — at worst it keeps one that should have been kept anyway.
location_matches = 0
for df in unmatched_def[:]:
    df_file = df.get("file") or ""
    df_line = safe_line(df.get("line"))
    if not df_file:
        continue
    best = None
    best_delta = LINE_WINDOW + 1
    tie = False
    for pf in prosecutor:
        if id(pf) in matched_pros_ids:
            continue
        if (pf.get("file") or "") != df_file:
            continue
        delta = abs(df_line - safe_line(pf.get("line")))
        if delta > LINE_WINDOW:
            continue
        if delta < best_delta:
            best = pf
            best_delta = delta
            tie = False
        elif delta == best_delta:
            tie = True
    if best is None or tie:
        continue
    matched_pros_ids.add(id(best))
    unmatched_def.remove(df)
    merged = dict(df)
    merged["severity"] = sev_label(min(sev_rank(df.get("severity")), sev_rank(best.get("severity"))))
    merged["blocking"] = bool(df.get("blocking", False)) and bool(best.get("blocking", False))
    kept.append(merged)
    location_matches += 1

# Pass 4: same-file title-similarity fallback, with NO line window. Passes 1-3
# all gate on |line delta| <= 10, so they drop a finding both validators kept
# when the two anchor it far apart — e.g. one validator anchors the buggy line
# and the other a contrast line in the same file (action.yml:231 vs :314 for
# the same "Anthropic runner ignores force_tier" issue). Here we pair the
# remaining unmatched defender findings to an unmatched prosecutor finding in
# the SAME file by distinctive title-token overlap alone. Guards against
# over-merging two genuinely different same-file findings: require >= 2 shared
# significant tokens AND an unambiguous winner (strictly more overlap than the
# runner-up). Merge stays conservative (lower severity, AND of blocking), so a
# wrong pairing can never escalate a finding.
MIN_SHARED_TOKENS = 2
title_matches = 0
for df in unmatched_def[:]:
    df_file = df.get("file") or ""
    if not df_file:
        continue
    df_tokens = significant_tokens(df.get("title"))
    if len(df_tokens) < MIN_SHARED_TOKENS:
        continue
    best = None
    best_overlap = 0
    runner_up = 0
    for pf in prosecutor:
        if id(pf) in matched_pros_ids:
            continue
        if (pf.get("file") or "") != df_file:
            continue
        overlap = len(df_tokens & significant_tokens(pf.get("title")))
        if overlap > best_overlap:
            runner_up = best_overlap
            best = pf
            best_overlap = overlap
        elif overlap > runner_up:
            runner_up = overlap
    if best is None or best_overlap < MIN_SHARED_TOKENS or best_overlap == runner_up:
        continue
    matched_pros_ids.add(id(best))
    unmatched_def.remove(df)
    merged = dict(df)
    merged["severity"] = sev_label(min(sev_rank(df.get("severity")), sev_rank(best.get("severity"))))
    merged["blocking"] = bool(df.get("blocking", False)) and bool(best.get("blocking", False))
    kept.append(merged)
    title_matches += 1

with open(final_path, "w") as fh:
    json.dump(kept, fh, indent=2)
    fh.write("\n")

sys.stderr.write(
    f"intersect-findings: fuzzy-matched {fuzzy_matches} finding(s) on second pass, "
    f"{location_matches} on location-only third pass, "
    f"{title_matches} on title-similarity fourth pass\n"
)
PY

# Pre-floor intersection size — the true prosecutor∩defender agreement.
# Disagreement MUST be measured BEFORE the floor classifier, because under
# nits:false the classifier drops below-floor non-blocking agreements; counting
# those as cross-pass disagreement would be a lie. kept_count is the
# post-classification (shown) count. Under nits:on the two are equal.
intersection_size="$(jq 'length' "$FINAL")"
cp "$FINAL" "$PRECLASSIFY"   # pre-floor snapshot for per-angle disagreement metrics
classify_floor
kept_count="$(jq 'length' "$FINAL")"
nit_count="$(jq '[.[] | select(.nit == true)] | length' "$FINAL")"
deferred_count="$(jq '[.[] | select((.deferred_to // "") != "" and .nit == true)] | length' "$FINAL")"
dropped_by_defender="$((prosecutor_count - intersection_size))"
dropped_by_prosecutor="$((defender_count - intersection_size))"
if [ "$dropped_by_defender" -lt 0 ]; then dropped_by_defender=0; fi
if [ "$dropped_by_prosecutor" -lt 0 ]; then dropped_by_prosecutor=0; fi
disagreement_count="$((dropped_by_defender + dropped_by_prosecutor))"

write_metrics adversarial false "$prosecutor_count" "$defender_count" "$kept_count" "$disagreement_count" "$dropped_by_defender" "$dropped_by_prosecutor" "$nit_count" "$deferred_count"

echo "intersect-findings: mode=adversarial degraded=false prosecutor=$prosecutor_count defender=$defender_count kept=$kept_count nits=$nit_count disagreement=$disagreement_count"
emit_angle_metrics adversarial false || echo "::warning::emit_angle_metrics failed (non-fatal)" >&2
