---
type: plan
source: .woostack/specs/2026-06-09-review-stack-aware.md
status: executing
branch: review-stack-aware-markers
---

**Source:** .woostack/specs/2026-06-09-review-stack-aware.md

# Stack-aware review (deferral markers) Implementation Plan

**Goal:** Teach `woostack-review` to honor an inline `woostack-defer(<ref>): <reason>` marker — authored by `woostack-execute` under an approved plan and read straight from the PR's own diff — and demote the matching "missing X" finding to a non-blocking `Deferred to <ref>` nit. No descendant-PR fetching, no `stack.md`. The cost of declaring "this gap is intentional" moves upstream to `woostack-plan` (instructs the marker) and `woostack-execute` (writes/removes it).

**Architecture:** Three review-side edits honor the marker: the defender validator (`prompts/validator.md`) scans the diff it already holds and annotates `deferred_to: "<ref>"` on a covered finding; mechanical demotion is deterministic in `intersect-findings.sh::classify_floor` (forces `nit:true, blocking:false`, gated by `review.defer_markers`); the `_header.md` body builder renders the deferral note. Two upstream edits emit the marker: `woostack-plan` authors paired drop/remove steps, `woostack-execute` writes and removes the token. The canonical token is defined once in the spec (§4.0); every side references it, none redefines it.

**Tech Stack:** Bash, Python 3 stdlib (`json`), `jq`. Shell unit tests under `scripts/tests/` using `assert.sh`. Prompt/skill edits verified by concrete `grep`/`bash -n` presence checks (no live-LLM test).

---

## Increment 1: Review honors the deferral marker

> One independently shippable PR. Adds the `defer_markers` config key, the classifier demotion + metric, the defender directive, and the render/doc surface. End-to-end: a `woostack-defer(...)` marker in a diff demotes a covered finding to a `Deferred to <ref>` nit. Markers can be hand-authored until Increment 2 teaches plan/execute to emit them.

### Task 1: `defer_markers` config key (load-config.sh)

**Files:**
- Modify: `skills/woostack-review/scripts/load-config.sh:91` (REVIEW_KEYS), `:231` (validation block region), `:53` (schema comment)
- Test: `skills/woostack-review/scripts/tests/test-load-config-defer-markers.sh`

- [x] **Step 1: Write the failing test**

```bash
# skills/woostack-review/scripts/tests/test-load-config-defer-markers.sh
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

# defer_markers:false accepted + emitted to canonical config.
setup '{"review":{"defer_markers":false}}'
bash "$SCRIPT" >/tmp/load-config-defer.out 2>&1
assert_eq "$(jq -r '.defer_markers' "$OUTDIR/config.json")" "false" "defer_markers:false emitted"
rm -rf "$work"

# defer_markers:true accepted + emitted.
setup '{"review":{"defer_markers":true}}'
bash "$SCRIPT" >/tmp/load-config-defer.out 2>&1
assert_eq "$(jq -r '.defer_markers' "$OUTDIR/config.json")" "true" "defer_markers:true emitted"
rm -rf "$work"

# Non-boolean defer_markers fails the loader loudly (non-zero exit).
setup '{"review":{"defer_markers":"yes"}}'
set +e
bash "$SCRIPT" >/tmp/load-config-defer.out 2>&1
rc=$?
set -e
assert_eq "$([ "$rc" -ne 0 ] && echo nonzero || echo zero)" "nonzero" "non-boolean defer_markers fails loader"
assert_contains "$(cat /tmp/load-config-defer.out)" "defer_markers" "error names the defer_markers key"
rm -rf "$work"

finish
```

- [x] **Step 2: Run the test, confirm it fails**

Run: `bash skills/woostack-review/scripts/tests/test-load-config-defer-markers.sh`
Expected: FAIL — the first assertion errors because `defer_markers` is an unknown `review` key today, so `load-config.sh` exits non-zero with `unknown review key(s): defer_markers` and `$OUTDIR/config.json` is never written (`jq` returns empty, not `false`).

- [x] **Step 3: Minimal implementation**

Add `defer_markers` to the recognized keys set (`load-config.sh:91-95`, after `nits`):

```python
REVIEW_KEYS = {
    "angles", "severity_floor", "ignore", "project_rules",
    "authors_skip", "release_rollup_pattern", "models", "fix_commands",
    "disable_adversarial", "metrics", "chunking", "force_tier", "nits",
    "defer_markers",
}
```

Add a validation block next to the other boolean keys (after the `nits` block, ~line 235):

```python
if "defer_markers" in raw:
    val = raw["defer_markers"]
    if not isinstance(val, bool):
        loud("`defer_markers` must be a boolean (true/false), got {}".format(type(val).__name__))
    out["defer_markers"] = val
```

Add the doc line to the schema comment block (after the `nits` comment, ~line 54):

```bash
#   defer_markers       bool       (issue #224: honor inline woostack-defer(<ref>)
#                                   markers — demote a finding a later increment
#                                   completes to a non-blocking Deferred-to nit;
#                                   default true. false ignores the markers.)
```

- [x] **Step 4: Run the test, confirm it passes**

Run: `bash skills/woostack-review/scripts/tests/test-load-config-defer-markers.sh`
Expected: PASS — `5 passed, 0 failed`. Regression: the existing load-config suite still passes.

- [x] **Step 5: Commit**

```bash
gt create -m "feat(review): accept review.defer_markers config key (#224)"
```

### Task 2: classify_floor deferral demotion + off-switch + `deferred_count` (intersect-findings.sh)

**Files:**
- Modify: `skills/woostack-review/scripts/intersect-findings.sh` — config resolve (~line 88, after `nits_enabled`), `classify_floor()` signature + loop (~line 293/309), `write_metrics()` (~line 122), and both `write_metrics` call sites (~line 345, ~line 606)
- Test: `skills/woostack-review/scripts/tests/test-intersect-deferred.sh`

- [x] **Step 1: Write the failing test**

```bash
# skills/woostack-review/scripts/tests/test-intersect-deferred.sh
#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$DIR/../../.." && pwd)"
source "$ROOT/skills/woostack-init/scripts/tests/assert.sh"
SCRIPT="$DIR/intersect-findings.sh"

# A finding carrying deferred_to must become a non-blocking nit regardless of
# severity_floor. Defender-only (disable_adversarial) isolates the floor classifier.
setup() { # $1 = severity_floor ; $2 = defer_markers ("true"/"false")
  work="$(mktemp -d)"
  export OUTDIR="$work"
  printf '{"disable_adversarial":true,"severity_floor":"%s","defer_markers":%s}\n' "$1" "$2" > "$OUTDIR/config.json"
  cat > "$OUTDIR/findings.defender.json" <<'JSON'
[
  {"angle":"bugs","file":"x.ts","line":3,"severity":"HIGH","blocking":true,
   "title":"Missing call-site wiring","description":"d","fix":"f","fix_type":"prose",
   "suggestion":null,"rule_quote":null,"deferred_to":"increment 3"}
]
JSON
  printf '[]\n' > "$OUTDIR/raw_findings.json"
}

# floor=high, defer on: HIGH would normally be a normal blocking finding; the
# deferred_to override must still demote it to a nit.
setup "high" "true"
bash "$SCRIPT" >/tmp/intersect-deferred.out 2>&1
assert_eq "$(jq -r '.[0].nit' "$OUTDIR/findings.json")" "true" "deferred_to -> nit (floor=high)"
assert_eq "$(jq -r '.[0].blocking' "$OUTDIR/findings.json")" "false" "deferred_to -> non-blocking (floor=high)"
assert_eq "$(jq -r '.deferred_count' "$OUTDIR/validator-metrics.json")" "1" "deferred_count counted"
rm -rf "$work"

# floor=low, defer on: HIGH is at/above floor (would be a normal finding); the
# override must STILL force nit — proving it is floor-independent.
setup "low" "true"
bash "$SCRIPT" >/tmp/intersect-deferred.out 2>&1
assert_eq "$(jq -r '.[0].nit' "$OUTDIR/findings.json")" "true" "deferred_to -> nit (floor=low, floor-independent)"
assert_eq "$(jq -r '.[0].blocking' "$OUTDIR/findings.json")" "false" "deferred_to -> non-blocking (floor=low)"
rm -rf "$work"

# Hard off-switch: defer_markers=false -> deferred_to is ignored; the HIGH blocking
# finding stays a normal blocking finding and is NOT counted.
setup "high" "false"
bash "$SCRIPT" >/tmp/intersect-deferred.out 2>&1
assert_eq "$(jq -r '.[0].nit' "$OUTDIR/findings.json")" "false" "defer off -> not demoted"
assert_eq "$(jq -r '.[0].blocking' "$OUTDIR/findings.json")" "true" "defer off -> stays blocking"
assert_eq "$(jq -r '.deferred_count' "$OUTDIR/validator-metrics.json")" "0" "defer off -> deferred_count 0"
rm -rf "$work"

finish
```

- [x] **Step 2: Run the test, confirm it fails**

Run: `bash skills/woostack-review/scripts/tests/test-intersect-deferred.sh`
Expected: FAIL — under `floor=high` the HIGH blocking finding stays `nit:false, blocking:true` (no override yet), and `.deferred_count` is `null` in `validator-metrics.json` (key absent).

- [x] **Step 3: Minimal implementation**

Resolve the off-switch from config (after the `nits_enabled` block, ~line 88, before `severity_floor`):

```bash
# Resolve defer_markers opt-out from config.json (default true). false => never
# honor woostack-defer markers; the floor classifier ignores deferred_to.
defer_markers_enabled="true"
if [ -f "$CONFIG" ]; then
  v="$(jq -r '.defer_markers' "$CONFIG" 2>/dev/null || echo null)"
  [ "$v" = "false" ] && defer_markers_enabled="false"
fi
```

Pass it into `classify_floor()` (signature, ~line 293) and add the override branch as the FIRST branch of the per-finding loop (~line 309):

```bash
classify_floor() {
  python3 - "$FINAL" "$severity_floor" "$nits_enabled" "$defer_markers_enabled" <<'PY'
import json, sys

final_p, floor, nits, defer_markers = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
RANK = {"low": 0, "medium": 1, "high": 2}
floor_rank = RANK.get(floor, 2)
nits_on = nits != "false"
defer_on = defer_markers != "false"
```

```python
out = []
for f in findings:
    # Stack-aware deferral (issue #224): a finding the defender confirmed a later
    # increment fills (via a woostack-defer marker) is forced to a non-blocking nit,
    # INDEPENDENT of the floor. Hard off-switch: defer_markers=false ignores it.
    dt = f.get("deferred_to")
    if defer_on and isinstance(dt, str) and dt.strip():
        f["nit"] = True
        f["blocking"] = False
        out.append(f)
        continue
    # Unknown/missing severity -> MEDIUM (matches sev_rank() used in the merge).
    rank = RANK.get((f.get("severity") or "").lower(), 1)
    ...
```

Extend `write_metrics()` to emit `deferred_count` (add a 10th positional arg, ~line 122-144):

```bash
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
```

Compute the count (demoted-deferral findings only) after `classify_floor` and pass it at BOTH call sites. Defender-only path (~line 344-345):

```bash
  nit_count="$(jq '[.[] | select(.nit == true)] | length' "$FINAL")"
  deferred_count="$(jq '[.[] | select((.deferred_to // "") != "" and .nit == true)] | length' "$FINAL")"
  write_metrics "$mode" "$degraded" null "$defender_count" "$kept_count" 0 0 0 "$nit_count" "$deferred_count"
```

Adversarial path (~line 599-606):

```bash
nit_count="$(jq '[.[] | select(.nit == true)] | length' "$FINAL")"
deferred_count="$(jq '[.[] | select((.deferred_to // "") != "" and .nit == true)] | length' "$FINAL")"
...
write_metrics adversarial false "$prosecutor_count" "$defender_count" "$kept_count" "$disagreement_count" "$dropped_by_defender" "$dropped_by_prosecutor" "$nit_count" "$deferred_count"
```

- [x] **Step 4: Run the test, confirm it passes**

Run: `bash skills/woostack-review/scripts/tests/test-intersect-deferred.sh`
Expected: PASS — `14 passed, 0 failed`. Then regression: `bash skills/woostack-review/scripts/tests/test-intersect-nits.sh` → still passes.

- [x] **Step 5: Commit**

```bash
gt modify -c -m "feat(review): demote deferred_to findings to nits in classifier (#224)"
```

### Task 3: Defender deferral-marker judgment (validator.md)

**Files:**
- Modify: `skills/woostack-review/prompts/validator.md` — Step 2, a new sub-step `4b` between Memory Check (`:45`) and Severity Check (`:46`)

- [x] **Step 1: Write the failing test (concrete verification)**

Prompt text — verify by presence of the directive the runtime reads.

Run: `grep -c 'woostack-defer' skills/woostack-review/prompts/validator.md; grep -c 'deferred_to' skills/woostack-review/prompts/validator.md`
Expected (current): `0`, `0`.

- [x] **Step 2: Confirm the gap**

Run: `grep -n 'Memory Check' skills/woostack-review/prompts/validator.md`
Expected: prints the Memory Check line (the anchor the new sub-step follows); no `woostack-defer` directive exists yet.

- [x] **Step 3: Minimal implementation**

Insert a new sub-step in Step 2 immediately after "4. **Memory Check**" (append as `4b`, before "5. **Severity Check**"):

```markdown
4b. **Deferral-marker Check** (issue #224): scan the diff for deferral markers of the exact form `woostack-defer(<ref>): <reason>` (the literal token is `woostack-defer`, case-sensitive). For each finding that asserts something is **missing, not yet wired, or presented before it lands** (e.g. "X is referenced before it is defined", "command not yet routed", "integration absent"), check whether a marker that is **co-located** with the finding — in the same diff hunk, or within a few lines of the flagged code — plausibly covers that exact gap.
   - If a co-located marker covers it: set the finding's `deferred_to` field to that marker's `<ref>` verbatim (e.g. `"increment 3"`) and set `blocking: false`. Do NOT drop it — it is demoted downstream to a non-blocking `Deferred to <ref>` nit, staying visible and auditable.
   - **Co-location is required.** A marker in a different hunk or a different file does NOT cover the finding — leave such findings unchanged. This stops a stray marker from silencing an unrelated same-file finding.
   - **Never** set `deferred_to` on a `security`-angle finding, on a finding about WRONG code that is present in THIS PR, or against a bare `TODO`/`FIXME` — only the `woostack-defer` token defers (deferral is for *missing/deferred* work a later increment completes).
   - The marker `<reason>` is a hint to LOOK, never proof — you still judge that the marker actually covers this finding's gap. A marker that does not match leaves the finding unchanged (`deferred_to` unset/null).
   - If `/tmp/pr-review/config.json` sets `defer_markers: false`, skip this check entirely.
```

Note the `deferred_to` schema field is documented centrally in `_header.md` (Task 4); the validator only needs to know to *set* it.

- [x] **Step 4: Run the verification, confirm it passes**

Run: `grep -c 'woostack-defer' skills/woostack-review/prompts/validator.md; grep -c 'deferred_to' skills/woostack-review/prompts/validator.md; grep -Ec 'co-located|same diff hunk' skills/woostack-review/prompts/validator.md`
Expected: `≥2`, `≥2`, `≥1` (the co-location guard). Confirm the security exclusion is present: `grep -n 'Never.*security' skills/woostack-review/prompts/validator.md` prints the guard line.

- [x] **Step 5: Commit**

```bash
gt modify -c -m "feat(review): defender annotates deferred_to from woostack-defer markers (#224)"
```

### Task 4: Render `Deferred to <ref>` + document field + config table (_header.md)

**Files:**
- Modify: `skills/woostack-review/prompts/_header.md` — angle-guard note (~line 38, near the `rules.md`/`memory.md` rubric guidance), config table (~line 86, after the `chunking.max_loc` row), Findings Schema (~line 404, after `rule_quote`), schema note (~line 446, near the `nit` note), and the body-builder python (~line 245)

- [x] **Step 1: Write the failing test (concrete verification)**

Run: `grep -c 'woostack-defer' skills/woostack-review/prompts/_header.md; grep -c 'deferred_to' skills/woostack-review/prompts/_header.md; grep -c 'Deferred to' skills/woostack-review/prompts/_header.md`
Expected (current): `0`, `0`, `0`.

- [x] **Step 2: Confirm the gap**

Run: `grep -n 'chunking.max_loc' skills/woostack-review/prompts/_header.md | head -1; grep -n 'body = f' skills/woostack-review/prompts/_header.md | head -1`
Expected: prints the config-table anchor row and the body-builder `body = f"**{title}**…"` line; no `deferred_to` handling yet.

- [x] **Step 3: Minimal implementation**

Add the angle-guard note (~line 38, near the `rules.md`/`memory.md` rubric guidance), so no angle worker double-reports the marker:

```markdown
A `woostack-defer(<ref>): <reason>` comment in the diff is an **intentional deferral signal** (issue #224), not a stray `TODO`. Do NOT raise a finding to flag or remove it. Only the defender validator acts on it — it demotes the *separate* missing/not-yet-wired finding the marker covers (see `validator.md`). Treat the marker line itself as inert.
```

Add the config-table row (~line 86, after the `chunking.max_loc` row):

```markdown
| `defer_markers` | `intersect-findings.sh` (floor classifier) + `validator.md` (defender) | Stage 4c / validation — default `true`; honors inline `woostack-defer(<ref>)` markers, demoting a covered finding to a `Deferred to <ref>` nit. `false` ignores the markers |
```

Add the schema field (in the Findings Schema JSON, ~line 404, after `rule_quote` — add a trailing comma to the `rule_quote` line):

```json
    "rule_quote": "exact quoted rule text if rule-based, else null",
    "deferred_to": "the <ref> of a woostack-defer marker (e.g. \"increment 3\") this finding is deferred to, set by the defender when a marker covers the missing work; else null"
```

Add a note after the schema explaining it is defender-set + downstream-driven (near the `nit` field note, ~line 446):

```markdown
`deferred_to` is a string (the marker `<ref>`, e.g. `"increment 3"`) or null, set by the defender validator (`validator.md`) when an inline `woostack-defer(<ref>)` marker in the diff covers the work a finding flags as missing. `intersect-findings.sh` forces any finding carrying a non-empty `deferred_to` to `nit: true, blocking: false` (independent of `severity_floor`, gated by `review.defer_markers`), and the body builder appends a `Deferred to <ref>` line. Never set on `security` findings or on wrong code present in this PR.
```

Render the deferral note in the body builder (~line 245, right after `body = f"**{title}**\n\n{description}"`, before the `Fix:` append):

```python
    body = f"**{title}**\n\n{description}"
    dt = (f.get("deferred_to") or "").strip()
    if dt:
        body += f"\n\n_Deferred to {dt} — a later increment completes this; non-blocking._"
    if fix:
        body += f"\n\nFix: {fix}"
```

- [x] **Step 4: Run the verification, confirm it passes**

Run: `grep -c 'woostack-defer' skills/woostack-review/prompts/_header.md; grep -c 'deferred_to' skills/woostack-review/prompts/_header.md; grep -c 'Deferred to' skills/woostack-review/prompts/_header.md; grep -c 'intentional deferral signal' skills/woostack-review/prompts/_header.md`
Expected: `≥2`, `≥3`, `≥2`, `≥1` (the angle-guard). Confirm the render edit sits inside the body builder: `grep -n 'Deferred to' skills/woostack-review/prompts/_header.md` shows the line within the `body = ` builder block.

- [x] **Step 5: Commit**

```bash
gt modify -c -m "docs(review): document deferred_to field + render Deferred-to note (#224)"
```

---

## Increment 2: Plan declares, execute resolves, status surfaces

> One independently shippable PR, stacked on Increment 1. Teaches the upstream phases to own the marker lifecycle: `woostack-plan` authors paired drop/remove steps, `woostack-execute` writes the marker and removes every match when it implements the increment, and `woostack-status` lists any surviving marker as an open deferral. All reference the spec's §4.0 token — single source of truth.

### Task 5: Deferral-marker doctrine in woostack-plan (SKILL.md)

**Files:**
- Modify: `skills/woostack-plan/SKILL.md` — a new subsection after "## PR-sized increments" (~line 66)

- [x] **Step 1: Write the failing test (concrete verification)**

Run: `grep -c 'woostack-defer' skills/woostack-plan/SKILL.md`
Expected (current): `0`.

- [x] **Step 2: Confirm the gap**

Run: `grep -n 'PR-sized increments' skills/woostack-plan/SKILL.md | head -1`
Expected: prints the section header the new subsection follows.

- [x] **Step 3: Minimal implementation**

Add a subsection after the "## PR-sized increments" section (~line 66, before "## Optional: independent tracks"):

```markdown
## Deferral markers (stacked increments)

A PR-sized increment often *intentionally* defers integration to a later increment — Increment 1
ships a skill file, Increment 2 wires its call sites. Reviewing the isolated diff would flag that
deferred work as "missing." To keep the review gate quiet **without** pulling the other PRs in the
stack, the plan declares the deferral inline:

When an increment leaves a gap a later increment fills, author **two paired steps**:

1. In the **deferring** increment, a step that drops a deferral marker at the gap site —
   `woostack-defer(increment N): <reason>` — in the file's comment syntax (e.g.
   `// woostack-defer(increment 3): call sites wired in increment 3`). The literal token is
   `woostack-defer`; `<ref>` is the increment that completes the work.
2. In the **implementing** increment (N), a step that **removes** that marker as part of wiring the
   work, so the marker exists exactly while the gap is open.

The marker is the single signal `woostack-review` reads to demote a "missing X" finding to a
non-blocking `Deferred to N` nit (see [`woostack-review`](../woostack-review/SKILL.md) for the
canonical token; `review.defer_markers` gates it, default on). Never plan a marker over a
`security` gap or over wrong code — deferral is only for *missing* work a later increment adds.
```

- [x] **Step 4: Run the verification, confirm it passes**

Run: `grep -c 'woostack-defer' skills/woostack-plan/SKILL.md`
Expected: `≥2`. Confirm the section renders: `grep -n 'Deferral markers' skills/woostack-plan/SKILL.md` prints the new header.

- [x] **Step 5: Commit**

```bash
gt create -m "feat(plan): author paired woostack-defer drop/remove steps for deferrals (#224)"
```

### Task 6: Marker write/remove doctrine in woostack-execute (SKILL.md)

**Files:**
- Modify: `skills/woostack-execute/SKILL.md` — a short doctrine subsection after "## Per-increment cadence" (~before "## Terminal state")

- [x] **Step 1: Write the failing test (concrete verification)**

Run: `grep -c 'woostack-defer' skills/woostack-execute/SKILL.md`
Expected (current): `0`.

- [x] **Step 2: Confirm the gap**

Run: `grep -n 'Per-increment cadence' skills/woostack-execute/SKILL.md | head -1`
Expected: prints the cadence header the doctrine note attaches to.

- [x] **Step 3: Minimal implementation**

Add a brief subsection after the "## Per-increment cadence" block (before "## Terminal state"):

```markdown
## Deferral markers

When a plan step says to **drop** a deferral marker (an increment that defers integration to a
later one), write it verbatim at the named site in the file's comment syntax —
`woostack-defer(increment N): <reason>` (literal token `woostack-defer`; see
[`woostack-plan`](../woostack-plan/SKILL.md) and [`woostack-review`](../woostack-review/SKILL.md)
for the canonical form).

When you implement the increment a marker names, **remove** it: delete the plan-named line as part
of wiring the work, then grep the tree for any remaining `woostack-defer(increment N)` matching the
increment you are completing and remove every occurrence (belt-and-suspenders, so a forgotten site
cannot strand a marker). Markers exist only while the gap is open. `woostack-review` reads the
marker to demote the matching "missing X" finding to a non-blocking `Deferred to N` nit — the text
must match the token exactly; `woostack-status` lists any marker still in the tree as an open
deferral.
```

- [x] **Step 4: Run the verification, confirm it passes**

Run: `grep -c 'woostack-defer' skills/woostack-execute/SKILL.md; grep -Ec 'grep the tree|remove every occurrence' skills/woostack-execute/SKILL.md`
Expected: `≥1`, `≥1` (the self-clean directive). Confirm the section renders: `grep -n 'Deferral markers' skills/woostack-execute/SKILL.md` prints the new header.

- [x] **Step 5: Commit**

```bash
gt modify -c -m "feat(execute): write/remove woostack-defer markers per plan (#224)"
```

### Task 7: Surface open deferrals in woostack-status (SKILL.md)

**Files:**
- Modify: `skills/woostack-status/SKILL.md` — a new read-only step in "## Procedure" (after "Surface the flags", ~line 49)

- [x] **Step 1: Write the failing test (concrete verification)**

Run: `grep -c 'woostack-defer' skills/woostack-status/SKILL.md`
Expected (current): `0`.

- [x] **Step 2: Confirm the gap**

Run: `grep -n 'Surface the flags' skills/woostack-status/SKILL.md | head -1`
Expected: prints the procedure step the new step follows.

- [x] **Step 3: Minimal implementation**

Add a read-only procedure step after "Surface the flags" (~line 49):

```markdown
4. **List open deferrals (read-only).** Scan the working tree for deferral markers —
   `grep -rn 'woostack-defer(' . | grep -v '/.git/'` (or a ripgrep equivalent) — and print each as
   an open deferral: `<file>:<line> — deferred to <ref>`. These are the `woostack-defer(<ref>)`
   markers `woostack-execute` writes for work a later increment completes (issue #224); a marker
   still present after its increment landed is a **stale deferral** worth resolving. This is
   read-only **surfacing** — never edit or remove a marker. Omit the section entirely when the scan
   finds none. (A consumer repo carries the token only at real deferral sites. The woostack repo
   itself also has illustrative `woostack-defer(...)` in `skills/**` / `.woostack/` docs; exclude
   those doc paths if the example noise distracts.)
```

- [x] **Step 4: Run the verification, confirm it passes**

Run: `grep -c 'woostack-defer' skills/woostack-status/SKILL.md; grep -c 'open deferral' skills/woostack-status/SKILL.md`
Expected: `≥1`, `≥1`. Confirm the step renders: `grep -n 'open deferrals' skills/woostack-status/SKILL.md` prints the new step header.

- [x] **Step 5: Commit**

```bash
gt modify -c -m "feat(status): list open woostack-defer deferrals on the board (#224)"
```

---

## Increment 3: User-facing SKILL.md docs (review)

> One independently shippable docs PR, stacked on Increment 2. Brings the human-facing review `SKILL.md` in line with the shipped behavior.

### Task 8: Document marker-based stack-aware review in SKILL.md

**Files:**
- Modify: `skills/woostack-review/SKILL.md` — config-schema block (~line 134, near `nits`), key reference (~line 176, after the `nits` bullet), and a new "Stack-aware review" section (after "## Incremental Mode", ~line 68)

- [x] **Step 1: Write the failing test (concrete verification)**

Run: `grep -c 'defer_markers' skills/woostack-review/SKILL.md; grep -c 'woostack-defer' skills/woostack-review/SKILL.md`
Expected (current): `0`, `0`.

- [x] **Step 2: Confirm the gap**

Run: `grep -n 'Incremental Mode' skills/woostack-review/SKILL.md | head -1`
Expected: prints the section header the new "Stack-aware review" section follows.

- [x] **Step 3: Minimal implementation**

Add the config-schema key inside the `review` object (~line 134, after `"nits": true,`):

```json
    "nits": true,
    "defer_markers": true,
```

Add the key-reference bullet (~line 176, after the `nits` bullet):

```markdown
- **`defer_markers`** — `true` | `false`; default **`true`**. When `true`, the defender validator honors inline `woostack-defer(<ref>)` markers (authored by `woostack-execute` under an approved plan): a finding that flags work a later increment intentionally completes is demoted to a non-blocking `Deferred to <ref>` nit instead of a normal finding (issue #224). Set `false` to ignore the markers. Never defers `security` findings or wrong code present in this PR; reads the marker from the PR's own diff, so it fetches no other PRs.
```

Add a new section after "## Incremental Mode" (~line 68):

```markdown
## Stack-aware review (`review.defer_markers`, issue #224)

woostack encourages PR-sized **stacked** increments, so an early increment often *intentionally*
defers integration to a later one. Reviewing the isolated diff would flag that deferred work as
"missing" — noise that trains authors to ignore the review gate.

Rather than fetch the other PRs in the stack to verify the deferral, woostack declares it inline.
When `woostack-execute` runs an increment that defers work, it writes a **deferral marker** at the
gap site — `woostack-defer(increment N): <reason>` — and the later increment removes it when it
wires the work (both steps are authored by [`woostack-plan`](../woostack-plan/SKILL.md)). The marker
lives in the PR's own diff.

When `review.defer_markers` is `true` (the default), the **defender validator** scans the diff for
these markers; for a finding that asserts something is *missing / not-yet-wired / presented-before-
it-lands*, it checks whether a marker covers that gap. If so it sets `deferred_to: "<ref>"`;
`intersect-findings.sh` then forces the finding to a non-blocking **`Deferred to <ref>` nit**
(visible, auditable, event-neutral → `APPROVE`), independent of `severity_floor`. Guards: `security`
findings are never deferred; a finding about wrong code *present in this PR* is never deferred; a
bare `TODO` is never honored (only the `woostack-defer` token). Set `review.defer_markers: false`
to turn the feature off. Because the signal is in the diff already, the review fetches **no other
PRs** — the cost of declaring intent is paid once, upstream, at plan/execute time.
```

- [x] **Step 4: Run the verification, confirm it passes**

Run: `grep -c 'defer_markers' skills/woostack-review/SKILL.md; grep -c 'woostack-defer' skills/woostack-review/SKILL.md`
Expected: `≥3`, `≥2`. Spot-check the section renders: `grep -n 'Stack-aware review' skills/woostack-review/SKILL.md` prints the new header.

- [x] **Step 5: Commit**

```bash
gt modify -c -m "docs(review): document marker-based stack-aware review in SKILL.md (#224)"
```

---

## Self-review (run before handing back)

- [ ] **Spec coverage** — every spec requirement maps to a task above:
  - §4.0 marker token (defined once) → referenced by Tasks 3, 5, 6, 7, 8 (none redefines it)
  - §4.1 honor: defender judgment (co-located + reason) → Task 3; classifier demotion + off-switch + metric → Task 2; render → Task 4; config key → Task 1
  - §4.2 declare/resolve/surface: plan paired steps → Task 5; execute write/remove + self-clean → Task 6; status open-deferrals scan → Task 7
  - docs surface (_header config table + schema + note; review SKILL section/key/schema) → Tasks 4, 8
- [ ] **AC coverage** — AC1 (marker honored happy/error/edge) → defender directive (Task 3) carrying the co-location + match-or-leave + bare-TODO guards, exercised end-to-end by the classifier (Task 2) + render (Task 4); AC2 (guards) → validator.md security/in-PR-code/TODO guards (Task 3) + classifier hard off-switch (Task 2 test, defer=false); AC3 (`defer_markers` config happy/error/edge) → test-load-config-defer-markers (accept bool / reject non-bool) + test-intersect-deferred off-switch case; AC4 (classifier floor-independent + metric) → test-intersect-deferred (floor high AND low + `deferred_count`); AC5 (plan/execute declare+resolve, token parity) → Tasks 5 + 6 presence checks asserting the *same* `woostack-defer` token the validator greps (Task 3); AC6 (stale-marker resolution & surfacing) → execute self-clean (Task 6) + status read-only open-deferrals list (Task 7).
- [ ] **No placeholders** — every step carries real code, exact commands, expected output.
- [ ] **Type consistency** — `deferred_to` is a string `"<ref>"` or null everywhere (validator sets, intersect reads `(.deferred_to // "") != ""`, body builder reads `(f.get("deferred_to") or "").strip()`); `defer_markers` is a bool everywhere; the literal token `woostack-defer` is byte-identical across validator.md (greps, Task 3), `woostack-plan` (emits, Task 5), `woostack-execute` (writes/self-cleans, Task 6), `woostack-status` (scans, Task 7), and the review `SKILL.md` (docs, Task 8). Cross-token parity check: `grep -rl 'woostack-defer' skills/ | wc -l` ≥ 5 after the stack lands.
- [ ] **Supersession** — confirm no residue of the closed diff-verify design (`detect-stack.sh`, `stack.md`, `stack_aware`, `stack_deferred`, `WOO_REVIEW_FAKE_STACK_*`) is introduced by any task; this plan adds none.

> woostack plan conventions: frontmatter-free; opens with `**Source:**`; basename mirrors the spec (`2026-06-09-review-stack-aware`); no sub-skill banner; prompt/doc edits use concrete grep/`bash -n` verifications in place of a runner.
