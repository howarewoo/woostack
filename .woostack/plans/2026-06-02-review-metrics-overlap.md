# Cross-Angle Overlap Metric — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a per-angle cross-angle overlap signal to woostack-review's opt-in metrics so redundant review angles (those whose findings other angles also raise) are visible per run and in the rolling aggregate.

**Architecture:** Extend the existing per-run assembler `emit_angle_metrics` (embedded Python in `intersect-findings.sh`) to cluster raw findings by `(file, line, title_stem)` — excluding unanchored findings — and emit `overlap_total` + `overlap_with` per angle. Extend `metrics-fold.sh` to accumulate those into the rolling `.woostack/metrics.json` and bump its schema version 1→2 (existing version-mismatch path reseeds the old aggregate). Document in `SKILL.md`. Tokens are a separate, deferred increment (spec §8).

**Tech Stack:** Bash + embedded Python 3 + `jq`; bash test harness under `skills/woostack-review/scripts/tests/` sourcing `skills/woostack-init/scripts/tests/assert.sh`.

**Source:** specs/2026-06-02-review-metrics-tokens-overlap.md (Increment 1; tokens deferred per spec §8).

---

## File Structure

- **Modify** `skills/woostack-review/scripts/intersect-findings.sh` — inside `emit_angle_metrics`'s Python heredoc: add overlap clustering + two per-angle keys; bump the per-run doc's `schema_version` to 2.
- **Modify** `skills/woostack-review/scripts/metrics-fold.sh` — `SCHEMA_VERSION=2`; per-angle slot init + accumulation of `overlap_total` / `overlap_with`.
- **Modify** `skills/woostack-review/SKILL.md` — artifact-table row for `findings.metrics.json` (add keys); `metrics` config note (mention overlap + schema v2).
- **Create** `skills/woostack-review/scripts/tests/test-intersect-overlap.sh` — drives `intersect-findings.sh` over fixtures, asserts overlap shape.
- **Create** `skills/woostack-review/scripts/tests/test-metrics-fold-overlap.sh` — drives `metrics-fold.sh`, asserts accumulation + v1→v2 reseed.

source: .woostack/specs/2026-06-02-review-metrics-tokens-overlap.md
---

## Task 1: Overlap computation in `emit_angle_metrics`

**Files:**
- Test: `skills/woostack-review/scripts/tests/test-intersect-overlap.sh` (create)
- Modify: `skills/woostack-review/scripts/intersect-findings.sh` (the `emit_angle_metrics` Python heredoc)

- [x] **Step 1: Write the failing test**

Create `skills/woostack-review/scripts/tests/test-intersect-overlap.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/intersect-findings.sh"

work="$(mktemp -d)"
export OUTDIR="$work"

# Metrics on; defender-only (no prosecutor) keeps the fixture minimal — overlap
# is computed from raw_findings.json regardless of validator mode.
printf '%s\n' '{"metrics": true, "disable_adversarial": true}' > "$work/config.json"

# Raw set: one 3-angle cluster (bugs+security+types at foo.ts:42, same title),
# one solo finding (bugs at bar.ts:7), one UNANCHORED finding (no line) that
# must be excluded from overlap.
cat > "$work/raw_findings.json" <<'JSON'
[
  {"angle":"bugs","file":"foo.ts","line":42,"title":"Null deref on user","severity":"HIGH"},
  {"angle":"security","file":"foo.ts","line":42,"title":"Null deref on user","severity":"HIGH"},
  {"angle":"types","file":"foo.ts","line":42,"title":"Null deref on user","severity":"MEDIUM"},
  {"angle":"bugs","file":"bar.ts","line":7,"title":"Off by one","severity":"LOW"},
  {"angle":"security","file":"baz.ts","title":"Unanchored secret","severity":"HIGH"}
]
JSON

# Defender output is mandatory and becomes findings.json in defender-only mode.
cp "$work/raw_findings.json" "$work/findings.defender.json"

bash "$SCRIPT" >/tmp/intersect-overlap.out 2>&1

M="$work/findings.metrics.json"
assert_eq "$(test -f "$M" && echo yes || echo no)" "yes" "findings.metrics.json emitted"

# bugs co-occurs with security and types once each at foo.ts:42 → total 2.
assert_eq "$(jq -r '.angles.bugs.overlap_total' "$M")" "2" "bugs overlap_total == 2"
assert_eq "$(jq -r '.angles.bugs.overlap_with.security' "$M")" "1" "bugs overlaps security once"
assert_eq "$(jq -r '.angles.bugs.overlap_with.types' "$M")" "1" "bugs overlaps types once"

# security overlaps bugs + types; the unanchored baz.ts finding is excluded.
assert_eq "$(jq -r '.angles.security.overlap_total' "$M")" "2" "security overlap_total == 2"
assert_eq "$(jq -r '.angles.security.overlap_with | has(\"baz\")' "$M")" "false" "no phantom angle key"

# types overlaps bugs + security.
assert_eq "$(jq -r '.angles.types.overlap_total' "$M")" "2" "types overlap_total == 2"

# The solo bugs finding at bar.ts adds no self-overlap; bugs map has exactly
# two keys (security, types).
assert_eq "$(jq -r '.angles.bugs.overlap_with | keys | length' "$M")" "2" "bugs overlap_with has 2 keys, no self"
assert_eq "$(jq -r '.angles.bugs.overlap_with | has(\"bugs\")' "$M")" "false" "bugs never overlaps itself"

# schema_version of the per-run doc bumped to 2.
assert_eq "$(jq -r '.schema_version' "$M")" "2" "per-run metrics schema_version == 2"

rm -rf "$work"
finish
```

- [x] **Step 2: Run test to verify it fails**

Run: `bash skills/woostack-review/scripts/tests/test-intersect-overlap.sh`
Expected: FAIL — `overlap_total` is `null` (jq prints `null`, not `2`), and `schema_version` is `1`. (The script still produces `findings.metrics.json`, so the first assert passes; the overlap asserts fail.)

- [x] **Step 3: Implement overlap in the `emit_angle_metrics` heredoc**

In `skills/woostack-review/scripts/intersect-findings.sh`, find the Python heredoc inside `emit_angle_metrics()`. Make three edits.

(a) Change the import line at the top of that heredoc from:

```python
import json, sys
```
to:
```python
import json, re, sys
```

(b) Immediately **before** the line `out = {"schema_version": 1, "mode": mode, "degraded": degraded == "true", "angles": {}}`, insert the clustering block:

```python
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
```

(c) Change the per-run doc version and add the two keys to each angle's `rec`. Change:

```python
out = {"schema_version": 1, "mode": mode, "degraded": degraded == "true", "angles": {}}
```
to:
```python
out = {"schema_version": 2, "mode": mode, "degraded": degraded == "true", "angles": {}}
```

Then, inside the `for a in angles:` loop, **after** the `rec = { ... }` literal is assigned and before `if has_pros:`, add:

```python
    ow = overlap_with.get(a, {})
    rec["overlap_with"] = ow
    rec["overlap_total"] = sum(ow.values())
```

- [x] **Step 4: Run test to verify it passes**

Run: `bash skills/woostack-review/scripts/tests/test-intersect-overlap.sh`
Expected: PASS — `0 failed`.

- [x] **Step 5: Commit**

```bash
git add skills/woostack-review/scripts/intersect-findings.sh skills/woostack-review/scripts/tests/test-intersect-overlap.sh
git commit -m "feat(review): per-angle cross-angle overlap in findings.metrics.json"
```

---

## Task 2: Accumulate overlap in the rolling fold + schema bump

**Files:**
- Test: `skills/woostack-review/scripts/tests/test-metrics-fold-overlap.sh` (create)
- Modify: `skills/woostack-review/scripts/metrics-fold.sh`

- [x] **Step 1: Write the failing test**

Create `skills/woostack-review/scripts/tests/test-metrics-fold-overlap.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/metrics-fold.sh"

work="$(mktemp -d)"
export OUTDIR="$work/out"
export GITHUB_WORKSPACE="$work/repo"
mkdir -p "$OUTDIR" "$GITHUB_WORKSPACE"

printf '%s\n' '{"metrics": true}' > "$OUTDIR/config.json"

# A per-run metrics doc with overlap fields (shape emitted by Task 1).
write_run() {
  cat > "$OUTDIR/findings.metrics.json" <<JSON
{
  "schema_version": 2,
  "mode": "defender-only",
  "degraded": false,
  "angles": {
    "bugs":     {"raw_count": 1, "kept": 1, "overlap_total": 2, "overlap_with": {"security": 1, "types": 1}},
    "security": {"raw_count": 1, "kept": 1, "overlap_total": 1, "overlap_with": {"bugs": 1}}
  }
}
JSON
}

ROLLING="$GITHUB_WORKSPACE/.woostack/metrics.json"

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

# --- accumulation: a second identical run doubles the sums + map values. ---
write_run
bash "$SCRIPT" >/tmp/fold-overlap-2.out 2>&1

assert_eq "$(jq -r '.runs' "$ROLLING")" "2" "second fold increments runs"
assert_eq "$(jq -r '.angles.bugs.overlap_total' "$ROLLING")" "4" "bugs overlap_total summed across runs"
assert_eq "$(jq -r '.angles.bugs.overlap_with.types' "$ROLLING")" "2" "bugs->types summed across runs"
assert_eq "$(jq -r '.angles.security.overlap_with.bugs' "$ROLLING")" "2" "security->bugs summed across runs"

rm -rf "$work"
finish
```

- [x] **Step 2: Run test to verify it fails**

Run: `bash skills/woostack-review/scripts/tests/test-metrics-fold-overlap.sh`
Expected: FAIL — with `SCHEMA_VERSION=1` the stale v1 file is treated as current (no `.bak`, `schema_version` stays 1), and `overlap_total` folds to `null`.

- [x] **Step 3: Bump the schema version**

In `skills/woostack-review/scripts/metrics-fold.sh`, change:

```bash
SCHEMA_VERSION=1
```
to:
```bash
SCHEMA_VERSION=2
```

- [x] **Step 4: Add overlap to the slot template and accumulation**

In the Python heredoc of `metrics-fold.sh`, the per-angle slot is created with `agg["angles"].setdefault(angle, { ... })`. Add the two overlap keys to that template dict (alongside `"severity_total"`):

```python
        "overlap_total": 0,
        "overlap_with": {},
```

Then, in the accumulation block that currently ends with the `severity_total` loop:

```python
    sev = rec.get("severity") or {}
    for s in SEVS:
        slot["severity_total"][s] += num(sev.get(s))
```
add immediately after it:

```python
    # Guard for aggregates seeded before overlap existed (defensive; reseed on
    # the version bump normally makes every slot use the new template).
    slot.setdefault("overlap_total", 0)
    slot.setdefault("overlap_with", {})
    slot["overlap_total"] += num(rec.get("overlap_total"))
    for b, n in (rec.get("overlap_with") or {}).items():
        slot["overlap_with"][b] = num(slot["overlap_with"].get(b)) + num(n)
```

- [x] **Step 5: Run test to verify it passes**

Run: `bash skills/woostack-review/scripts/tests/test-metrics-fold-overlap.sh`
Expected: PASS — `0 failed`.

- [x] **Step 6: Commit**

```bash
git add skills/woostack-review/scripts/metrics-fold.sh skills/woostack-review/scripts/tests/test-metrics-fold-overlap.sh
git commit -m "feat(review): fold cross-angle overlap into rolling metrics, schema v2"
```

---

## Task 3: Document overlap in SKILL.md

**Files:**
- Modify: `skills/woostack-review/SKILL.md`

- [x] **Step 1: Update the `findings.metrics.json` artifact-table row**

Find the table row (around line 222) beginning:

```
| `findings.metrics.json` | `intersect-findings.sh` | metrics fold, telemetry | Per-angle signal/noise breakdown. Emitted **only when `review.metrics: true`** in config. Keyed by angle: `raw_count`, `prosecutor_kept`, `defender_kept`, `kept`, `dropped_by_defender`, `dropped_by_prosecutor`, `blocking_count`, `nonblocking_count`, `severity` |
```

Append the two new keys to its key list so it ends:

```
… `blocking_count`, `nonblocking_count`, `severity`, `overlap_total`, `overlap_with` (per-other-angle co-occurrence counts on the raw set; schema v2) |
```

- [x] **Step 2: Update the `metrics` config note**

Find the bullet (around line 165):

```
- **`metrics`**: opt in to per-angle signal/noise metrics (bool, default `false`) — emit `findings.metrics.json` per run and fold a rolling `.woostack/metrics.json` aggregate (local only). See Stage 6.5.
```

Replace it with:

```
- **`metrics`**: opt in to per-angle signal/noise metrics (bool, default `false`) — emit `findings.metrics.json` per run and fold a rolling `.woostack/metrics.json` aggregate (local only). Each angle also carries `overlap_total` + `overlap_with` (how often another angle raised the same issue, on the raw pre-validation set — a redundancy signal). Aggregate schema is v2; an older v1 aggregate is reseeded on first fold. See Stage 6.5.
```

- [x] **Step 3: Verify no cross-links broke**

Run: `grep -n "findings.metrics.json\|review.metrics\|overlap" skills/woostack-review/SKILL.md`
Expected: the updated row + bullet appear; no other reference contradicts the new keys.

- [x] **Step 4: Commit**

```bash
git add skills/woostack-review/SKILL.md
git commit -m "docs(review): document overlap metric + schema v2 in SKILL.md"
```

---

## Task 4: Full verification

**Files:** none (verification only)

- [x] **Step 1: Run both new tests**

Run:
```bash
bash skills/woostack-review/scripts/tests/test-intersect-overlap.sh
bash skills/woostack-review/scripts/tests/test-metrics-fold-overlap.sh
```
Expected: each prints `0 failed`.

- [x] **Step 2: Run the rest of the review/init test suite to catch regressions**

Run:
```bash
for t in skills/woostack-review/scripts/tests/*.sh skills/woostack-init/scripts/tests/*.sh; do
  echo "== $t =="; bash "$t" || { echo "FAILED: $t"; exit 1; }
done
```
Expected: every test reports `0 failed`; no `FAILED:` line.

- [x] **Step 3: Lint the touched shell scripts**

Run: `shellcheck skills/woostack-review/scripts/intersect-findings.sh skills/woostack-review/scripts/metrics-fold.sh`
Expected: no new warnings introduced by these edits. (If `shellcheck` is unavailable, note it and skip — the embedded Python is not shellcheck-covered anyway.)

- [x] **Step 4: Sanity-check JSON shape end-to-end**

Run the Task 1 fixture once more and pretty-print:
```bash
OUTDIR="$(mktemp -d)"; export OUTDIR
printf '%s\n' '{"metrics": true, "disable_adversarial": true}' > "$OUTDIR/config.json"
cat > "$OUTDIR/raw_findings.json" <<'JSON'
[{"angle":"bugs","file":"foo.ts","line":42,"title":"Null deref","severity":"HIGH"},
 {"angle":"security","file":"foo.ts","line":42,"title":"Null deref","severity":"HIGH"}]
JSON
cp "$OUTDIR/raw_findings.json" "$OUTDIR/findings.defender.json"
bash skills/woostack-review/scripts/intersect-findings.sh >/dev/null 2>&1
jq '.angles | {bugs: .bugs.overlap_with, security: .security.overlap_with}' "$OUTDIR/findings.metrics.json"
rm -rf "$OUTDIR"
```
Expected: `{"bugs":{"security":1},"security":{"bugs":1}}`.

---

## Self-Review

- **Spec coverage:** §4.1 overlap compute → Task 1. §4.2 schema (`overlap_total`/`overlap_with`) → Task 1. §4.3 fold + v1→v2 bump → Task 2. §4.4 docs → Task 3. §7 tests: overlap math, unanchored exclusion, within-angle non-self-count → Task 1 test; fold accumulation + v1→v2 reseed → Task 2 test; metrics-off no-op already covered by existing behavior (no code path changed for the off case — no new test needed). All covered.
- **Placeholder scan:** none — every code/step is concrete.
- **Type consistency:** key names `overlap_total` / `overlap_with` identical across Task 1 (emit), Task 2 (fold), Task 3 (docs), and both tests. Per-run doc `schema_version` and fold `SCHEMA_VERSION` both → 2.
```
