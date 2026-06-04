# Review Nit Comments Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Surface validated-but-below-`severity_floor` review findings as non-blocking "nit" comments instead of dropping them, reframing `severity_floor` from a drop gate into a blocking/visibility threshold (default-on, `review.nits` opt-out).

**Architecture:** Move the floor out of the two validator passes (`validator-prosecutor.md`, `validator.md`) and into a single classifier in `scripts/intersect-findings.sh` that runs after the final `severity = min` / `blocking = AND` merge. The classifier tags below-floor non-blocking findings `nit:true` (or drops them under `nits:false`), keeps below-floor blocking findings as normal findings (blocking overrides the floor), and records `nit_count`. `prompts/_header.md` renders nits (`Nit:` prefix + `NIT` footer) and treats them as event-neutral. CI rides the shared scripts/prompts unchanged.

**Tech Stack:** Bash + embedded Python 3 (`jq`-driven config), Markdown skill prompts, shell-based test harness (`assert.sh`).

**Source spec:** `.woostack/specs/2026-06-04-review-nit-comments.md`

**Increment scope:** This is a single PR-sized increment (~300 LOC across scripts, prompts, docs, tests). `woostack-execute` owns the commit/review/distill cadence; the per-task `git add`/commit steps below collapse into that one increment's commit.

---

## File Structure

| File | Responsibility | Change |
|---|---|---|
| `skills/woostack-review/scripts/load-config.sh` | Validate `.woostack/config.json` → canonical config | Add `nits` to whitelist + bool validation |
| `skills/woostack-review/scripts/intersect-findings.sh` | Merge validator passes → `findings.json` + metrics | **Floor classifier**, `nit_count`, pre-floor disagreement, schema v3 |
| `skills/woostack-review/scripts/metrics-fold.sh` | Fold per-run metrics → rolling aggregate | `nit_total`, aggregate `SCHEMA_VERSION` 2→3 |
| `skills/woostack-review/prompts/_header.md` | Shared render/event/status contract + payload builder | Render nits, event-neutral nits, STATUS_LINE, schema, config table |
| `skills/woostack-review/prompts/validator.md` | Defender pass | Remove floor drop (step 6) |
| `skills/woostack-review/prompts/validator-prosecutor.md` | Prosecutor pass | Remove floor drop (step 6) |
| `skills/woostack-review/prompts/anthropic.md` `openai.md` `google.md` `opencode.md` | Provider orchestration | Event-rule prose sync |
| `skills/woostack-review/SKILL.md` | User-facing docs | Reframe `severity_floor`, `nits` config, metrics row, Stage 5 |
| `skills/woostack-review/scripts/tests/test-intersect-nits.sh` | **New** classifier test | Create |
| `skills/woostack-review/scripts/tests/test-load-config-nits.sh` | **New** loader test | Create |
| `skills/woostack-review/scripts/tests/test-intersect-overlap.sh` | Existing | Bump schema assertion 2→3 |
| `skills/woostack-review/scripts/tests/test-metrics-fold-overlap.sh` | Existing | v3 reseed + `nit_total` |

Tests run individually: `bash skills/woostack-review/scripts/tests/<file>.sh` (no shared runner in this dir).

**Line numbers below are hints against the pre-change file** — they drift as edits land (inserting the classifier shifts everything after it). Match by the quoted **content**, not the line number: `Read` the file, locate the shown old text, then `Edit`. For the multi-sentence prose replacements (Task 5), read the current list item first and replace it whole.

**Verified unchanged (do not edit):** `action.yml`, `.github/workflows/reusable-review.yml`, `test-intersect-farapart.sh` (its findings are HIGH or never intersect, so the classifier leaves its assertions intact). CI rides the shared `prompts/` + `scripts/` via the `validate` mode (`WOO_REVIEW_SEQUENTIAL_VALIDATE=1` → `validator.md` calls `intersect-findings.sh` → posts via `_header.md`).

---

## Task 1: Config loader accepts `review.nits`

**Files:**
- Modify: `skills/woostack-review/scripts/load-config.sh:85-89` (whitelist), after `:223` (validation), `:49-52` (header doc)
- Test: `skills/woostack-review/scripts/tests/test-load-config-nits.sh` (create)

- [x] **Step 1: Write the failing test**

Create `skills/woostack-review/scripts/tests/test-load-config-nits.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/load-config.sh"

setup() { # $1 = config json body
  work="$(mktemp -d)"
  export OUTDIR="$work/out"
  export GITHUB_WORKSPACE="$work/repo"
  mkdir -p "$OUTDIR" "$GITHUB_WORKSPACE/.woostack"
  printf '%s\n' "$1" > "$GITHUB_WORKSPACE/.woostack/config.json"
}

# nits:false accepted + emitted to canonical config.
setup '{"review":{"nits":false}}'
bash "$SCRIPT" >/tmp/load-config-nits.out 2>&1
assert_eq "$(jq -r '.nits' "$OUTDIR/config.json")" "false" "nits:false emitted"
rm -rf "$work"

# nits:true accepted + emitted.
setup '{"review":{"nits":true}}'
bash "$SCRIPT" >/tmp/load-config-nits.out 2>&1
assert_eq "$(jq -r '.nits' "$OUTDIR/config.json")" "true" "nits:true emitted"
rm -rf "$work"

# Non-boolean nits fails the loader loudly (non-zero exit).
setup '{"review":{"nits":"yes"}}'
set +e
bash "$SCRIPT" >/tmp/load-config-nits.out 2>&1
rc=$?
set -e
assert_eq "$([ "$rc" -ne 0 ] && echo nonzero || echo zero)" "nonzero" "non-boolean nits fails loader"
assert_contains "$(cat /tmp/load-config-nits.out)" "nits" "error names the nits key"
rm -rf "$work"

finish
```

- [x] **Step 2: Run test to verify it fails**

Run: `bash skills/woostack-review/scripts/tests/test-load-config-nits.sh`
Expected: FAIL — `nits:false emitted` assertion fails (loader currently errors on the unknown `nits` key, so `$OUTDIR/config.json` has no `.nits`), or the loud-error case fails because the key is unknown rather than type-checked.

- [x] **Step 3: Add `nits` to the review-key whitelist**

In `skills/woostack-review/scripts/load-config.sh`, change the `REVIEW_KEYS` set (lines 85-89):

```python
REVIEW_KEYS = {
    "angles", "severity_floor", "ignore", "project_rules",
    "authors_skip", "release_rollup_pattern", "models", "fix_commands",
    "disable_adversarial", "metrics", "chunking", "force_tier", "nits",
}
```

- [x] **Step 4: Add the boolean validation block**

In the same file, immediately after the `metrics` validation block (after line 223, which ends `        out["metrics"] = val`), add:

```python
if "nits" in raw:
    val = raw["nits"]
    if not isinstance(val, bool):
        loud("`nits` must be a boolean (true/false), got {}".format(type(val).__name__))
    out["nits"] = val
```

- [x] **Step 5: Document the key in the header comment**

In the same file, in the key-list comment block, add a line after the `metrics` entry (the block around lines 48-53):

```bash
#   nits                bool       (surface below-floor validated findings as
#                                   non-blocking nits; default true. false
#                                   restores the old below-floor drop. blocking
#                                   findings still surface regardless.)
```

- [x] **Step 6: Run test to verify it passes**

Run: `bash skills/woostack-review/scripts/tests/test-load-config-nits.sh`
Expected: PASS — `3 passed, 0 failed` (or more).

- [x] **Step 7: Stage**

```bash
git add skills/woostack-review/scripts/load-config.sh skills/woostack-review/scripts/tests/test-load-config-nits.sh
```

---

## Task 2: Floor classifier in `intersect-findings.sh`

**Files:**
- Modify: `skills/woostack-review/scripts/intersect-findings.sh` (config resolution ~`:79`, `write_metrics` `:106-126`, `emit_angle_metrics` python `:221-247`, new `classify_floor` fn, defender-only path `:265-267`, adversarial tail `:511-523`)
- Test: `skills/woostack-review/scripts/tests/test-intersect-nits.sh` (create); `test-intersect-overlap.sh:55` (update)

- [x] **Step 1: Write the failing classifier test**

Create `skills/woostack-review/scripts/tests/test-intersect-nits.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/intersect-findings.sh"

# Defender-only mode keeps fixtures minimal: findings.defender.json becomes
# findings.json after the classifier runs. Four findings exercise every branch:
#   HIGH blocking      -> normal (at/above floor)
#   MEDIUM non-block   -> nit (below floor, nits on)
#   LOW non-block      -> nit (below floor, nits on)
#   LOW blocking       -> normal blocking (blocking overrides floor)
run() { # $1 = config json
  work="$(mktemp -d)"; export OUTDIR="$work"
  printf '%s\n' "$1" > "$work/config.json"
  cat > "$work/findings.defender.json" <<'JSON'
[
  {"angle":"bugs","file":"a.ts","line":1,"severity":"HIGH","blocking":true,"title":"High blocker"},
  {"angle":"bugs","file":"a.ts","line":2,"severity":"MEDIUM","blocking":false,"title":"Medium thing"},
  {"angle":"bugs","file":"a.ts","line":3,"severity":"LOW","blocking":false,"title":"Low thing"},
  {"angle":"security","file":"a.ts","line":4,"severity":"LOW","blocking":true,"title":"Low but blocking"}
]
JSON
  cp "$work/findings.defender.json" "$work/raw_findings.json"
  bash "$SCRIPT" >/tmp/intersect-nits.out 2>&1
  F="$work/findings.json"
}

# --- default nits ON, floor high ---
run '{"disable_adversarial": true}'
assert_eq "$(jq 'length' "$F")" "4" "nits on: all four kept"
assert_eq "$(jq -r '.[0].nit' "$F")" "false" "HIGH at/above floor -> not nit"
assert_eq "$(jq -r '.[1].nit' "$F")" "true" "MEDIUM below floor -> nit"
assert_eq "$(jq -r '.[1].blocking' "$F")" "false" "nit forced non-blocking"
assert_eq "$(jq -r '.[2].nit' "$F")" "true" "LOW below floor -> nit"
assert_eq "$(jq -r '.[3].nit' "$F")" "false" "below-floor blocking -> normal (override)"
assert_eq "$(jq -r '.[3].blocking' "$F")" "true" "blocking override keeps blocking:true"
assert_eq "$(jq -r '.nit_count' "$work/validator-metrics.json")" "2" "validator-metrics nit_count == 2"
rm -rf "$work"

# --- nits OFF: below-floor non-blocking dropped; blocking override survives ---
run '{"disable_adversarial": true, "nits": false}'
assert_eq "$(jq 'length' "$F")" "2" "nits off: MEDIUM+LOW non-blocking dropped"
assert_eq "$(jq -r '[.[].title] | sort | join(",")' "$F")" "High blocker,Low but blocking" "kept = HIGH + below-floor blocking"
assert_eq "$(jq -r '.nit_count' "$work/validator-metrics.json")" "0" "nits off: nit_count == 0"
rm -rf "$work"

# --- floor medium: MEDIUM normal, LOW nit ---
run '{"disable_adversarial": true, "severity_floor": "medium"}'
assert_eq "$(jq -r '.[1].nit' "$F")" "false" "floor medium: MEDIUM normal"
assert_eq "$(jq -r '.[2].nit' "$F")" "true" "floor medium: LOW nit"
rm -rf "$work"

# --- floor low: nothing is a nit ---
run '{"disable_adversarial": true, "severity_floor": "low"}'
assert_eq "$(jq -r '[.[] | select(.nit == true)] | length' "$F")" "0" "floor low: no nits"
rm -rf "$work"

# --- per-angle metrics: nit_count + nonblocking redefinition + schema v3 ---
run '{"disable_adversarial": true, "metrics": true}'
M="$work/findings.metrics.json"
assert_eq "$(jq -r '.schema_version' "$M")" "3" "per-run metrics schema_version == 3"
assert_eq "$(jq -r '.angles.bugs.nit_count' "$M")" "2" "bugs nit_count == 2"
assert_eq "$(jq -r '.angles.bugs.nonblocking_count' "$M")" "0" "bugs nonblocking = kept-blocking-nit = 0"
rm -rf "$work"

finish
```

- [x] **Step 2: Run test to verify it fails**

Run: `bash skills/woostack-review/scripts/tests/test-intersect-nits.sh`
Expected: FAIL — no `nit` field on findings, no `nit_count` in `validator-metrics.json`, `schema_version` is 2.

- [x] **Step 3: Resolve `nits` + `severity_floor` near the other config reads**

In `skills/woostack-review/scripts/intersect-findings.sh`, after the `metrics_enabled` resolution block (after line 79, before `RAW="$OUTDIR/raw_findings.json"` at line 80), add:

```bash
# Resolve nits opt-out from config.json (default true). NOTE: jq's `//` treats
# `false` as empty, so `.nits // true` would coerce an explicit false back to
# true — detect the opt-out explicitly instead.
nits_enabled="true"
if [ -f "$CONFIG" ]; then
  v="$(jq -r '.nits' "$CONFIG" 2>/dev/null || echo null)"
  [ "$v" = "false" ] && nits_enabled="false"
fi

# Resolve severity_floor (default high). Already shape-validated by
# load-config.sh; re-default defensively here since this is the floor's home.
severity_floor="$(jq -r '.severity_floor // "high"' "$CONFIG" 2>/dev/null | tr '[:upper:]' '[:lower:]')"
case "$severity_floor" in low|medium|high) ;; *) severity_floor="high" ;; esac
```

- [x] **Step 4: Add the `classify_floor` function**

In the same file, immediately after the `emit_angle_metrics()` function definition closes (after line 253, the `}` before the `if [ "$disable_adversarial" ...` block), add:

```bash
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
  python3 - "$FINAL" "$severity_floor" "$nits_enabled" <<'PY'
import json, sys

final_p, floor, nits = sys.argv[1], sys.argv[2], sys.argv[3]
RANK = {"low": 0, "medium": 1, "high": 2}
floor_rank = RANK.get(floor, 2)
nits_on = nits != "false"

try:
    findings = json.load(open(final_p))
    if not isinstance(findings, list):
        findings = []
except (OSError, ValueError):
    findings = []

out = []
for f in findings:
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
```

- [x] **Step 5: Add `nit_count` to `write_metrics`**

In the same file, change the `write_metrics()` function (lines 106-126) to take a 9th arg and emit it:

```bash
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
    '{
      mode: $mode,
      degraded: $degraded,
      prosecutor_count: $prosecutor_count,
      defender_count: $defender_count,
      kept_count: $kept_count,
      disagreement_count: $disagreement_count,
      dropped_by_defender: $dropped_by_defender,
      dropped_by_prosecutor: $dropped_by_prosecutor,
      nit_count: $nit_count
    }' > "$METRICS"
}
```

- [x] **Step 6: Classify in the defender-only / `disable_adversarial` path**

In the same file, change the defender-only block (lines 265-268). Replace:

```bash
  cp "$DEFENDER" "$FINAL"
  write_metrics "$mode" "$degraded" null "$defender_count" "$defender_count" 0 0 0
  echo "intersect-findings: mode=$mode degraded=$degraded kept=$defender_count"
  emit_angle_metrics "$mode" "$degraded" || echo "::warning::emit_angle_metrics failed (non-fatal)" >&2
```

with:

```bash
  cp "$DEFENDER" "$FINAL"
  classify_floor
  kept_count="$(jq 'length' "$FINAL")"
  nit_count="$(jq '[.[] | select(.nit == true)] | length' "$FINAL")"
  write_metrics "$mode" "$degraded" null "$defender_count" "$kept_count" 0 0 0 "$nit_count"
  echo "intersect-findings: mode=$mode degraded=$degraded kept=$kept_count nits=$nit_count"
  emit_angle_metrics "$mode" "$degraded" || echo "::warning::emit_angle_metrics failed (non-fatal)" >&2
```

- [x] **Step 7: Classify in the adversarial path + pre-floor disagreement**

In the same file, change the adversarial tail (lines 511-523). Replace:

```bash
kept_count="$(jq 'length' "$FINAL")"
# Disagreement: findings either pass kept but the other dropped.
# Equivalent to (defender_count - kept) + (prosecutor_count - kept).
dropped_by_defender="$((prosecutor_count - kept_count))"
dropped_by_prosecutor="$((defender_count - kept_count))"
if [ "$dropped_by_defender" -lt 0 ]; then dropped_by_defender=0; fi
if [ "$dropped_by_prosecutor" -lt 0 ]; then dropped_by_prosecutor=0; fi
disagreement_count="$((dropped_by_defender + dropped_by_prosecutor))"

write_metrics adversarial false "$prosecutor_count" "$defender_count" "$kept_count" "$disagreement_count" "$dropped_by_defender" "$dropped_by_prosecutor"

echo "intersect-findings: mode=adversarial degraded=false prosecutor=$prosecutor_count defender=$defender_count kept=$kept_count disagreement=$disagreement_count"
emit_angle_metrics adversarial false || echo "::warning::emit_angle_metrics failed (non-fatal)" >&2
```

with:

```bash
# Pre-floor intersection size — the true prosecutor∩defender agreement.
# Disagreement MUST be measured BEFORE the floor classifier, because under
# nits:false the classifier drops below-floor non-blocking agreements; counting
# those as cross-pass disagreement would be a lie. kept_count is the
# post-classification (shown) count. Under nits:on the two are equal.
intersection_size="$(jq 'length' "$FINAL")"
classify_floor
kept_count="$(jq 'length' "$FINAL")"
nit_count="$(jq '[.[] | select(.nit == true)] | length' "$FINAL")"
dropped_by_defender="$((prosecutor_count - intersection_size))"
dropped_by_prosecutor="$((defender_count - intersection_size))"
if [ "$dropped_by_defender" -lt 0 ]; then dropped_by_defender=0; fi
if [ "$dropped_by_prosecutor" -lt 0 ]; then dropped_by_prosecutor=0; fi
disagreement_count="$((dropped_by_defender + dropped_by_prosecutor))"

write_metrics adversarial false "$prosecutor_count" "$defender_count" "$kept_count" "$disagreement_count" "$dropped_by_defender" "$dropped_by_prosecutor" "$nit_count"

echo "intersect-findings: mode=adversarial degraded=false prosecutor=$prosecutor_count defender=$defender_count kept=$kept_count nits=$nit_count disagreement=$disagreement_count"
emit_angle_metrics adversarial false || echo "::warning::emit_angle_metrics failed (non-fatal)" >&2
```

- [x] **Step 8: Add `nit_count` + redefine `nonblocking_count` + bump per-run schema to 3**

In the same file, in the `emit_angle_metrics` Python heredoc: change the schema literal (line 221) from `2` to `3`:

```python
out = {"schema_version": 3, "mode": mode, "degraded": degraded == "true", "angles": {}}
```

Then change the per-angle `rec` (lines 228-236) to compute and include `nit_count`, redefining `nonblocking_count`:

```python
    nit = sum(1 for f in final if angle_of(f) == a and bool(f.get("nit")))
    rec = {
        "raw_count": rawn,
        "defender_kept": defk,
        "kept": kept,
        "dropped_by_prosecutor": max(0, defk - kept),
        "blocking_count": blk,
        "nit_count": nit,
        "nonblocking_count": kept - blk - nit,
        "severity": sev_hist(final, a),
    }
```

- [x] **Step 9: Run the new classifier test to verify it passes**

Run: `bash skills/woostack-review/scripts/tests/test-intersect-nits.sh`
Expected: PASS — all assertions pass.

- [x] **Step 10: Update the overlap test's schema assertion**

In `skills/woostack-review/scripts/tests/test-intersect-overlap.sh`, line 54-55, change the comment + value from `2` to `3`:

```bash
# schema_version of the per-run doc bumped to 3 (nit_count addition).
assert_eq "$(jq -r '.schema_version' "$M")" "3" "per-run metrics schema_version == 3"
```

- [x] **Step 11: Run the overlap test to verify it still passes**

Run: `bash skills/woostack-review/scripts/tests/test-intersect-overlap.sh`
Expected: PASS — overlap metrics unaffected (computed from `raw_findings.json`); schema is now 3.

- [x] **Step 12: Stage**

```bash
git add skills/woostack-review/scripts/intersect-findings.sh \
        skills/woostack-review/scripts/tests/test-intersect-nits.sh \
        skills/woostack-review/scripts/tests/test-intersect-overlap.sh
```

---

## Task 3: Rolling aggregate gains `nit_total`

**Files:**
- Modify: `skills/woostack-review/scripts/metrics-fold.sh:23` (version), slot template `:94-104`, fold body `:106-120`
- Test: `skills/woostack-review/scripts/tests/test-metrics-fold-overlap.sh` (update)

- [x] **Step 1: Update the fold test to expect v3 + `nit_total`**

In `skills/woostack-review/scripts/tests/test-metrics-fold-overlap.sh`:

Change `write_run()` (lines 17-29) to emit a v3 per-run doc with `nit_count`:

```bash
write_run() {
  cat > "$OUTDIR/findings.metrics.json" <<JSON
{
  "schema_version": 3,
  "mode": "defender-only",
  "degraded": false,
  "angles": {
    "bugs":     {"raw_count": 1, "kept": 1, "nit_count": 1, "overlap_total": 2, "overlap_with": {"security": 1, "types": 1}},
    "security": {"raw_count": 1, "kept": 1, "nit_count": 0, "overlap_total": 1, "overlap_with": {"bugs": 1}}
  }
}
JSON
}
```

Change the seed + reseed assertions (lines 33-43). Replace:

```bash
# --- v1 reseed: a stale v1 aggregate must be backed up and replaced at v2. ---
mkdir -p "$GITHUB_WORKSPACE/.woostack"
printf '%s\n' '{"schema_version": 1, "runs": 9, "angles": {}}' > "$ROLLING"

write_run
bash "$SCRIPT" >/tmp/fold-overlap-1.out 2>&1

assert_eq "$(test -f "$ROLLING.bak" && echo yes || echo no)" "yes" "stale v1 aggregate backed up to .bak"
assert_eq "$(jq -r '.schema_version' "$ROLLING")" "2" "aggregate reseeded at schema_version 2"
assert_eq "$(jq -r '.runs' "$ROLLING")" "1" "reseeded aggregate counts this run as run 1"
assert_eq "$(jq -r '.angles.bugs.overlap_total' "$ROLLING")" "2" "bugs overlap_total folded"
assert_eq "$(jq -r '.angles.bugs.overlap_with.security' "$ROLLING")" "1" "bugs->security folded"
```

with:

```bash
# --- v2 reseed: an old v2 aggregate must be backed up and replaced at v3. ---
mkdir -p "$GITHUB_WORKSPACE/.woostack"
printf '%s\n' '{"schema_version": 2, "runs": 9, "angles": {}}' > "$ROLLING"

write_run
bash "$SCRIPT" >/tmp/fold-overlap-1.out 2>&1

assert_eq "$(test -f "$ROLLING.bak" && echo yes || echo no)" "yes" "stale v2 aggregate backed up to .bak"
assert_eq "$(jq -r '.schema_version' "$ROLLING")" "3" "aggregate reseeded at schema_version 3"
assert_eq "$(jq -r '.runs' "$ROLLING")" "1" "reseeded aggregate counts this run as run 1"
assert_eq "$(jq -r '.angles.bugs.overlap_total' "$ROLLING")" "2" "bugs overlap_total folded"
assert_eq "$(jq -r '.angles.bugs.overlap_with.security' "$ROLLING")" "1" "bugs->security folded"
assert_eq "$(jq -r '.angles.bugs.nit_total' "$ROLLING")" "1" "bugs nit_total folded"
```

Add a `nit_total` accumulation assertion to the second-run block (after line 53):

```bash
assert_eq "$(jq -r '.angles.bugs.nit_total' "$ROLLING")" "2" "bugs nit_total summed across runs"
```

- [x] **Step 2: Run the fold test to verify it fails**

Run: `bash skills/woostack-review/scripts/tests/test-metrics-fold-overlap.sh`
Expected: FAIL — aggregate reseeds at 2 (not 3); `nit_total` absent.

- [x] **Step 3: Bump the aggregate schema version**

In `skills/woostack-review/scripts/metrics-fold.sh`, line 23:

```bash
SCHEMA_VERSION=3
```

- [x] **Step 4: Add `nit_total` to the slot template**

In the same file, in the `slot = agg["angles"].setdefault(...)` template (lines 94-104), add `"nit_total": 0,` after `"blocking_total": 0,`:

```python
    slot = agg["angles"].setdefault(angle, {
        "runs_present": 0,
        "raw_total": 0,
        "kept_total": 0,
        "dropped_by_defender_total": 0,
        "dropped_by_prosecutor_total": 0,
        "blocking_total": 0,
        "nit_total": 0,
        "severity_total": {s: 0 for s in SEVS},
        "overlap_total": 0,
        "overlap_with": {},
    })
```

- [x] **Step 5: Fold `nit_count` into `nit_total`**

In the same file, after the `blocking_total` fold line (line 110, `slot["blocking_total"] += num(rec.get("blocking_count"))`), add a defensive default + fold:

```python
    slot.setdefault("nit_total", 0)
    slot["nit_total"] += num(rec.get("nit_count"))
```

- [x] **Step 6: Run the fold test to verify it passes**

Run: `bash skills/woostack-review/scripts/tests/test-metrics-fold-overlap.sh`
Expected: PASS.

- [x] **Step 7: Stage**

```bash
git add skills/woostack-review/scripts/metrics-fold.sh \
        skills/woostack-review/scripts/tests/test-metrics-fold-overlap.sh
```

---

## Task 4: Render nits + event-neutral in `_header.md`

**Files:**
- Modify: `skills/woostack-review/prompts/_header.md` — Per-repo Config table (~`:81-91`), Output Contract (`:121`), STATUS_LINE (`:125-129`), payload-builder Python (event `:200-207`, render `:224-265`), Findings Schema (`:317-332`), Inline Comment Format (`:352-371`)

This file is a Markdown contract with an embedded Python payload builder; it is exercised live during posting, so verification is a manual fixture run (Step 8).

- [x] **Step 1: Add the `nits` row to the per-repo Config table**

In the config-key table (lines 81-91), add a row after the `severity_floor` row, and correct the `severity_floor` row's stage (the floor is now consumed by the classifier at Stage 4c, not the validator):

```markdown
| `severity_floor` | `intersect-findings.sh` (floor classifier) | Stage 4c — **defaults to `high`**; below-floor validated findings become nits, not drops |
| `nits` | `intersect-findings.sh` (floor classifier) | Stage 4c — default `true`; `false` drops below-floor non-blocking findings (old behavior) |
```

- [x] **Step 2: Make the Output Contract event line nit-aware**

In the "Output Contract" section (line 121), replace:

```
Every run MUST end with one batched GitHub Review submitted via `gh api repos/<repo>/pulls/<PR>/reviews` containing all inline comments, the summary, and the `STATUS_LINE` in the **review body**. The review `event` is the native blocking gate: `APPROVE` (0 findings), `COMMENT` (no blocking findings), or `REQUEST_CHANGES` (≥1 blocking finding). PR labels MUST NOT be added, removed, or otherwise mutated.
```

with:

```
Every run MUST end with one batched GitHub Review submitted via `gh api repos/<repo>/pulls/<PR>/reviews` containing all inline comments, the summary, and the `STATUS_LINE` in the **review body**. The review `event` is the native blocking gate: `REQUEST_CHANGES` (≥1 blocking finding or open prior thread), `COMMENT` (≥1 non-nit non-blocking finding), or `APPROVE` (no findings, or only nits — nits post inline but never withhold approval). PR labels MUST NOT be added, removed, or otherwise mutated.
```

- [x] **Step 3: Update the STATUS_LINE shapes**

In the "STATUS_LINE (exact format)" section (lines 125-129), replace the list with:

```markdown
Counts: `BLOCKING_COUNT` (blocking findings), `NONBLOCKING_COUNT` (non-nit, non-blocking findings), `NIT_COUNT` (findings with `nit: true`). The `H HIGH, M MEDIUM, L LOW` breakdown counts non-nit findings only. The ` + Q nit(s)` suffix appears only when `NIT_COUNT > 0`.

- `BLOCKING_COUNT >= 1` → `**Status: CHANGES REQUESTED** — N blocking finding(s) (H HIGH, M MEDIUM, L LOW) + K non-blocking[ + Q nit(s)]. See inline comments.`
- `BLOCKING_COUNT == 0, NONBLOCKING_COUNT >= 1` → `**Status: APPROVED WITH SUGGESTIONS** — N non-blocking finding(s) (H HIGH, M MEDIUM, L LOW)[ + Q nit(s)]. See inline comments.`
- `BLOCKING_COUNT == 0, NONBLOCKING_COUNT == 0, NIT_COUNT >= 1` → `**Status: APPROVED** — No blocking findings, Q nit(s). See inline comments.`
- All zero → `**Status: APPROVED** — No validated findings.`
```

- [x] **Step 4: Make the event computation treat nits as event-neutral**

In the payload-builder Python, replace the event block (lines 200-207):

```python
has_new_blocking = any(f.get("blocking", False) for f in findings)
has_open_priors  = any(p.get("status") == "open" for p in priors)
if not findings and not has_open_priors:
    event = "APPROVE"
elif has_new_blocking or has_open_priors:
    event = "REQUEST_CHANGES"
else:
    event = "COMMENT"
```

with:

```python
has_new_blocking = any(f.get("blocking", False) for f in findings)
has_open_priors  = any(p.get("status") == "open" for p in priors)
# Nits are event-neutral: a non-nit, non-blocking finding triggers COMMENT; a PR
# whose only findings are nits (or none) APPROVEs. Nit comments still post inline
# under APPROVE — they inform without withholding the green check.
has_non_nit = any(not f.get("nit", False) for f in findings)
if has_new_blocking or has_open_priors:
    event = "REQUEST_CHANGES"
elif has_non_nit:
    event = "COMMENT"
else:
    event = "APPROVE"
```

- [x] **Step 5: Render the `Nit:` prefix**

In the same Python, in the per-finding loop, after the field reads (after line 234, `blocking = bool(f.get("blocking", False))`), add the nit read + title prefix. Replace:

```python
    title = f["title"].strip()
    description = f["description"].strip()
    fix = (f.get("fix") or "").strip()
    angle = (f.get("angle") or "").strip()
    severity = (f.get("severity") or "").strip().upper()
    blocking = bool(f.get("blocking", False))

    body = f"**{title}**\n\n{description}"
```

with:

```python
    nit = bool(f.get("nit", False))
    title = f["title"].strip()
    # Guard against an angle that already phrased the title as "Nit: …".
    if nit and not title.lower().startswith("nit:"):
        title = f"Nit: {title}"
    description = f["description"].strip()
    fix = (f.get("fix") or "").strip()
    angle = (f.get("angle") or "").strip()
    severity = (f.get("severity") or "").strip().upper()
    blocking = bool(f.get("blocking", False))

    body = f"**{title}**\n\n{description}"
```

- [x] **Step 6: Render the `NIT` footer tag**

In the same Python, replace the footer severity segment (lines 259-261):

```python
    if severity in {"HIGH", "MEDIUM", "LOW"}:
        sev_tag = f"{severity} · BLOCKING" if blocking else severity
        footer_parts.append(f"<strong>{sev_tag}</strong>")
```

with:

```python
    if severity in {"HIGH", "MEDIUM", "LOW"}:
        if nit:
            sev_tag = f"{severity} · NIT"
        elif blocking:
            sev_tag = f"{severity} · BLOCKING"
        else:
            sev_tag = severity
        footer_parts.append(f"<strong>{sev_tag}</strong>")
```

- [x] **Step 7: Add `nit` to the Findings Schema + Inline Comment Format docs**

In the Findings Schema JSON example (lines 318-332), add the `nit` field after `"blocking": true,`:

```json
    "blocking": true,
    "nit": false,
```

Then add a sentence to the schema prose (after the `fix_type` discriminator section, around line 350) and to the Inline Comment Format section (around line 369):

```markdown
`nit` is a boolean set by `intersect-findings.sh` (the floor classifier), not by angle agents: `true` marks a validated below-floor non-blocking finding. The body builder renders a `nit: true` finding with a `Nit:` title prefix and a `· NIT` footer tag, and the event computation treats it as event-neutral (a PR whose only findings are nits still `APPROVE`s). A nit is always non-blocking; a below-floor finding that is `blocking: true` stays a normal finding (`nit: false`).
```

- [x] **Step 8: Manual verification of the payload builder**

Extract the builder logic to a temp harness and confirm a nit renders correctly and yields `APPROVE`. Run:

```bash
mkdir -p /tmp/pr-review
cat > /tmp/pr-review/findings.json <<'JSON'
[
  {"angle":"bugs","file":"a.ts","line":3,"severity":"LOW","blocking":false,"nit":true,
   "title":"Prefer const over let","description":"`let` is never reassigned.","fix":"Use `const`.","fix_type":"prose","suggestion":null}
]
JSON
echo '[]' > /tmp/pr-review/prior-findings.json
HEAD_SHA=deadbeef python3 - <<'PY'
import json, os, re
findings = json.load(open("/tmp/pr-review/findings.json"))
priors = json.load(open("/tmp/pr-review/prior-findings.json"))
has_new_blocking = any(f.get("blocking", False) for f in findings)
has_open_priors  = any(p.get("status") == "open" for p in priors)
has_non_nit = any(not f.get("nit", False) for f in findings)
if has_new_blocking or has_open_priors:
    event = "REQUEST_CHANGES"
elif has_non_nit:
    event = "COMMENT"
else:
    event = "APPROVE"
f = findings[0]
nit = bool(f.get("nit", False))
title = f["title"].strip()
if nit and not title.lower().startswith("nit:"):
    title = f"Nit: {title}"
severity = (f.get("severity") or "").upper()
blocking = bool(f.get("blocking", False))
sev_tag = f"{severity} · NIT" if nit else (f"{severity} · BLOCKING" if blocking else severity)
print("event =", event)
print("title =", title)
print("footer =", sev_tag)
PY
```

Expected output:
```
event = APPROVE
title = Nit: Prefer const over let
footer = LOW · NIT
```

- [x] **Step 9: Stage**

```bash
git add skills/woostack-review/prompts/_header.md
```

---

## Task 5: Stop the validator passes from flooring

**Files:**
- Modify: `skills/woostack-review/prompts/validator.md` (input note `:16`, step 6 `:47`)
- Modify: `skills/woostack-review/prompts/validator-prosecutor.md` (input note `:16`, step 6 `:42`)

- [x] **Step 1: Defender pass — replace the floor-drop step**

In `skills/woostack-review/prompts/validator.md`, replace step 6 (line 47, the `**Severity Floor (...)**` item) with:

```markdown
6. **Severity Floor — applied downstream now (do NOT drop by severity here)**: The `severity_floor` filter has moved to `scripts/intersect-findings.sh` (Stage 4c). It reframes the floor from a drop gate into a blocking/visibility threshold: below-floor validated findings become non-blocking **nits**, below-floor **blocking** findings still surface as normal findings, and below-floor non-blocking findings are dropped only when `review.nits: false`. Your job is to keep every validated finding (after any allowed *downgrade* in step 5) so the downstream classifier can see it. Do not read or apply `severity_floor`.
```

- [x] **Step 2: Defender pass — correct the config input note**

In the same file, change the config-input bullet (line 16). Replace:

```markdown
- **Per-repo config** (always present): /tmp/pr-review/config.json — parsed `.woostack/config.json` (defaults to `{"severity_floor":"high"}`). The validator only reads `.severity_floor` from this file; other keys are consumed upstream.
```

with:

```markdown
- **Per-repo config** (always present): /tmp/pr-review/config.json — parsed `.woostack/config.json`. The validator no longer reads any severity key from it; `severity_floor` and `nits` are consumed downstream by `intersect-findings.sh` (Stage 4c). Other keys are consumed upstream.
```

- [x] **Step 3: Prosecutor pass — replace the floor-drop step**

In `skills/woostack-review/prompts/validator-prosecutor.md`, replace step 6 (line 42, `**Severity Floor**: Read ...`) with:

```markdown
6. **Severity Floor — applied downstream now (do NOT drop by severity here)**: The `severity_floor` filter has moved to `scripts/intersect-findings.sh` (Stage 4c), which turns below-floor validated findings into non-blocking nits (keeping below-floor blocking findings as normal findings, dropping below-floor non-blocking findings only under `review.nits: false`). Keep every validated finding (after any allowed *downgrade* in step 5) so the classifier can see it. Do not read or apply `severity_floor`.
```

- [x] **Step 4: Prosecutor pass — correct the config input note**

In the same file, change the config-input bullet (line 16). Replace:

```markdown
- **Per-repo config** (always present): /tmp/pr-review/config.json — read `.severity_floor` only (defaults to `high`).
```

with:

```markdown
- **Per-repo config** (always present): /tmp/pr-review/config.json — the prosecutor no longer reads any severity key; `severity_floor` / `nits` are consumed downstream by `intersect-findings.sh` (Stage 4c).
```

- [x] **Step 5: Verify no stray floor-drop instruction remains**

Run: `grep -nE "Drop findings strictly below|severity_floor // \"high\"" skills/woostack-review/prompts/validator.md skills/woostack-review/prompts/validator-prosecutor.md`
Expected: no matches (the drop instructions are gone).

- [x] **Step 6: Stage**

```bash
git add skills/woostack-review/prompts/validator.md skills/woostack-review/prompts/validator-prosecutor.md
```

---

## Task 6: Sync provider-prompt event prose

**Files:**
- Modify: `skills/woostack-review/prompts/anthropic.md:148`, `openai.md:101`, `google.md:144`, `opencode.md:107`

Each prompt restates the event rule in one sentence. None embeds the payload builder — these are prose-accuracy edits only.

- [x] **Step 1: anthropic.md**

In `skills/woostack-review/prompts/anthropic.md` line 148, replace the substring:

```
`COMMENT` when there are only non-blocking new findings and no unresolved priors, `APPROVE` only when both new findings and prior unresolved threads are empty.
```

with:

```
`COMMENT` when a non-nit non-blocking new finding exists and there are no unresolved priors, `APPROVE` when the only new findings are nits (posted inline) or there are none, and prior unresolved threads are empty.
```

Also change `Compute BLOCKING_COUNT, NONBLOCKING_COUNT, HIGH_COUNT, MEDIUM_COUNT, LOW_COUNT.` to `Compute BLOCKING_COUNT, NONBLOCKING_COUNT, NIT_COUNT, HIGH_COUNT, MEDIUM_COUNT, LOW_COUNT.`

- [x] **Step 2: openai.md**

In `skills/woostack-review/prompts/openai.md` line 101, apply the identical two replacements (the event sentence and the `Compute …_COUNT` list — add `NIT_COUNT` after `NONBLOCKING_COUNT`).

- [x] **Step 3: google.md**

In `skills/woostack-review/prompts/google.md` line 144, replace:

```
`COMMENT` when only non-blocking new findings exist and no unresolved priors, `APPROVE` only when both new findings and prior unresolved threads are empty.
```

with:

```
`COMMENT` when a non-nit non-blocking new finding exists and no unresolved priors, `APPROVE` when the only new findings are nits (posted inline) or there are none, and prior unresolved threads are empty.
```

(google.md says "Compute counts" generically — no `_COUNT` list to extend.)

- [x] **Step 4: opencode.md**

In `skills/woostack-review/prompts/opencode.md` line 107, apply the same event-sentence replacement as google.md (it uses the identical "`COMMENT` when there are only non-blocking new findings and no unresolved priors, `APPROVE` only when both new findings and prior unresolved threads are empty." phrasing — replace with the anthropic.md Step 1 replacement text). "Compute counts" is generic — no list to extend.

- [x] **Step 5: Verify the stale phrasing is gone**

Run: `grep -rn "only non-blocking new findings" skills/woostack-review/prompts/`
Expected: no matches.

- [x] **Step 6: Stage**

```bash
git add skills/woostack-review/prompts/anthropic.md skills/woostack-review/prompts/openai.md \
        skills/woostack-review/prompts/google.md skills/woostack-review/prompts/opencode.md
```

---

## Task 7: Update SKILL.md docs

**Files:**
- Modify: `skills/woostack-review/SKILL.md` — Noise control (`:85-87`), config schema block (`:122-166`), key reference (`:170`), findings.metrics row (`:236`), Stage 5 (`:426-432`)

- [x] **Step 1: Rewrite the "Noise control (`severity_floor`)" section**

In `skills/woostack-review/SKILL.md`, replace the section (lines 85-87):

```markdown
### Noise control (`severity_floor`)

`severity_floor` **defaults to `high`** — by default only high-priority findings surface. Widen it per-repo in `.woostack/config.json` (`review.severity_floor` set to `"low"` or `"medium"`). The validator applies the floor after its own severity check.
```

with:

```markdown
### Noise control (`severity_floor` + nits)

`severity_floor` **defaults to `high`** and is a **blocking/visibility threshold**, not a drop gate. Findings at/above the floor are normal findings; validated findings **below** the floor are surfaced as non-blocking **nits** (`Nit:` title prefix, `· NIT` footer) rather than dropped. A below-floor finding that is `blocking: true` is never demoted — it surfaces as a normal blocking finding (blocking overrides the floor). Nits are event-neutral: a PR whose only findings are nits still gets `APPROVE`, with the nits posted inline.

The floor is applied in one place — `scripts/intersect-findings.sh` (Stage 4c) — after the adversarial intersection, so swarm, CI, and defender-only paths agree. Widen the floor per-repo with `review.severity_floor` (`"low"` / `"medium"`).

Set **`review.nits: false`** to restore the old behavior: below-floor non-blocking findings are dropped entirely. (Below-floor *blocking* findings still surface — the override is a global safety rule independent of this knob.)
```

- [x] **Step 2: Add `nits` to the config schema block**

In the full schema JSON (lines 122-166), add `"nits": true,` after the `"severity_floor": "high",` line (line 128):

```json
    "severity_floor": "high",
    "nits": true,
```

- [x] **Step 3: Add `nits` to the key reference**

In the "Key reference" list, after the `severity_floor` bullet (line 170), add:

```markdown
- **`nits`** — `true` | `false`; default **`true`**. When `true`, validated findings below `severity_floor` surface as non-blocking nits instead of being dropped. Set `false` to drop them (the pre-reframe behavior). Below-floor `blocking` findings always surface regardless.
```

Also update the `severity_floor` bullet (line 170) to reflect the reframe — replace "drops findings below the floor" with "findings below the floor surface as non-blocking nits (see `nits`); set `low`/`medium` to treat more findings as normal."

- [x] **Step 4: Update the `findings.metrics.json` artifact row**

In the artifact reference table (line 236), update the `findings.metrics.json` row's "Notes" to add `nit_count`, note the `nonblocking_count` redefinition, and bump to schema v3:

```markdown
| `findings.metrics.json` | `intersect-findings.sh` | metrics fold, telemetry | Per-angle signal/noise breakdown. Emitted **only when `review.metrics: true`**. Keyed by angle: `raw_count`, `prosecutor_kept`, `defender_kept`, `kept`, `dropped_by_defender`, `dropped_by_prosecutor`, `blocking_count`, `nit_count`, `nonblocking_count` (= `kept − blocking − nit`), `severity`, `overlap_total`, `overlap_with` (schema v3) |
```

- [x] **Step 5: Update Stage 5 event determination**

In Stage 5 "Report" (lines 426-432), update the event-build bullet. Replace the line:

```
- Submit one `gh api repos/<repo>/pulls/<PR>/reviews` POST containing all inline comments + the summary + status line. The review `event` (`APPROVE` / `COMMENT` / `REQUEST_CHANGES`) is the native gate — any blocking finding triggers `REQUEST_CHANGES`.
```

with:

```
- Submit one `gh api repos/<repo>/pulls/<PR>/reviews` POST containing all inline comments + the summary + status line. The review `event` (`APPROVE` / `COMMENT` / `REQUEST_CHANGES`) is the native gate: any blocking finding (or open prior thread) triggers `REQUEST_CHANGES`; a non-nit non-blocking finding triggers `COMMENT`; nits are event-neutral, so a PR whose only findings are nits gets `APPROVE` with the nits posted inline.
```

- [x] **Step 6: Verify the docs are internally consistent**

Run: `grep -nE "severity_floor|nits|nit_count" skills/woostack-review/SKILL.md`
Expected: the noise-control section, config schema, key reference, metrics row, and Stage 5 all reference the reframe consistently; no remaining "drops findings below the floor" / "validator applies the floor" phrasing implying a drop gate.

- [x] **Step 7: Stage**

```bash
git add skills/woostack-review/SKILL.md
```

---

## Task 8: Full verification + commit

- [x] **Step 1: Run the full review test suite**

Run:
```bash
for t in skills/woostack-review/scripts/tests/test-*.sh; do
  echo "=== $t ==="; bash "$t" || { echo "FAILED: $t"; break; }
done
```
Expected: every test prints `N passed, 0 failed`; no `FAILED:` line.

- [x] **Step 2: Sanity-check the classifier end-to-end (adversarial path)**

Run:
```bash
work="$(mktemp -d)"; export OUTDIR="$work"
printf '%s\n' '{}' > "$work/config.json"
cat > "$work/findings.prosecutor.json" <<'JSON'
[{"angle":"bugs","file":"a.ts","line":2,"severity":"MEDIUM","blocking":false,"title":"Medium thing"}]
JSON
cp "$work/findings.prosecutor.json" "$work/findings.defender.json"
cp "$work/findings.prosecutor.json" "$work/raw_findings.json"
bash skills/woostack-review/scripts/intersect-findings.sh
echo "--- findings.json ---"; jq -c '.[] | {severity,blocking,nit}' "$work/findings.json"
echo "--- validator-metrics ---"; jq -c '{kept_count,nit_count,disagreement_count}' "$work/validator-metrics.json"
rm -rf "$work"
```
Expected: finding shows `{"severity":"MEDIUM","blocking":false,"nit":true}`; metrics show `nit_count:1`, `disagreement_count:0`.

- [x] **Step 3: Confirm the shipped CI assets were not touched**

Run: `git status --porcelain action.yml .github/workflows/reusable-review.yml`
Expected: no output (these ride the shared `prompts/`+`scripts/` change; they must not appear in the diff).

- [x] **Step 4: Commit the increment**

```bash
git add skills/woostack-review/
git commit -m "feat(review): surface below-floor validated findings as nits

Reframe severity_floor from a drop gate into a blocking/visibility
threshold. Validated findings below the floor now post as non-blocking
nit comments (Nit: prefix, NIT footer) instead of being dropped; blocking
findings override the floor; review.nits:false restores the old drop.
Floor classification centralized in intersect-findings.sh.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

(Under `woostack-build`, `woostack-execute` drives the actual commit via `woostack-commit` — this message is the intent.)

---

## Self-Review

**Spec coverage** (against `.woostack/specs/2026-06-04-review-nit-comments.md`):

- §4 validator passes stop flooring → Task 5. ✓
- §4 classifier in intersect (4-branch rule incl. blocking-override) → Task 2 Steps 3-4, 6-7. ✓
- §4 renderer + event + STATUS_LINE + Output Contract → Task 4. ✓
- §4 provider prompt prose sync → Task 6. ✓
- §4 config loader whitelist + bool → Task 1. ✓
- §4 config + docs (SKILL severity_floor/nits/metrics row/Stage 5) → Task 7. ✓
- §5 `nit` schema field → Task 4 Step 7. ✓
- §5 disagreement pre-floor → Task 2 Step 7. ✓
- §5 validator-metrics `nit_count` → Task 2 Steps 5-7. ✓
- §5 findings.metrics `nit_count` + `nonblocking_count` redefine + schema v3 → Task 2 Step 8. ✓
- §5 rolling aggregate `nit_total` + v3 → Task 3. ✓
- §6 missing-`nit` default, double-`Nit:` guard, `nits` parse (jq `//` pitfall), unknown severity → Task 2 Step 3-4, Task 4 Step 5. ✓
- §7 all listed test cases → Tasks 1-3 tests + Task 4 manual. ✓
- action.yml/reusable workflow unchanged → no task (verified during hardening). ✓

**Placeholder scan:** No TBD/TODO; every code step shows full content. ✓

**Type consistency:** `nit` boolean used identically in classifier (`f["nit"]`), renderer (`f.get("nit")`), event (`f.get("nit", False)`), metrics (`f.get("nit")`); `nit_count` (per-run + validator-metrics) and `nit_total` (aggregate) named consistently; `nits_enabled`/`severity_floor` shell vars match the `classify_floor` args. ✓
