---
name: review-metrics-tokens-overlap
type: spec
status: approved
date: 2026-06-02
branch: feature/review-metrics-overlap
links:
---

# Review metrics: cross-angle overlap (+ deferred token cost) — Design Spec

> **Plan:** [[plans/2026-06-02-review-metrics-overlap]]

> Visualize on demand: render this file with [spec-template.html](spec-template.html) for a rich view. Markdown is the source of truth; the HTML is a presentation target only.

## 1. Problem

`woostack-review`'s opt-in per-angle metrics (`findings.metrics.json` per run,
folded into a rolling `.woostack/metrics.json`) record signal/noise per angle
(raw vs kept, dropped-by-validator, severity). They cannot answer two
operationally important questions:

1. **Which angles are redundant?** When several angles independently raise the
   same issue, that duplicated effort is invisible. An angle whose findings are
   nearly always also found by another angle is a candidate to drop.
2. **Which angles are expensive but low-value?** There is no token-cost signal,
   so an angle that burns many tokens to surface few kept findings is invisible.

## 2. Goal & scope split

Two signals were requested; they have very different feasibility, so they ship
as **two increments**:

- **Increment 1 (this spec / this cycle) — cross-angle overlap.** Fully
  deterministic, host-independent, no capture dependency.
- **Increment 2 (next cycle) — per-angle tokens.** Deferred because token usage
  is **not capturable on a bare chat host** (see §8). Designed here so the schema
  evolves coherently, but **not implemented in this increment**.

Both stay behind the existing opt-in (`review.metrics: true`, default off). No
new gate.

### Increment 1 goal

For each angle, record a `overlap_with` map counting, per *other* angle, how many
of this angle's findings that other angle also raised (total pairwise hits), plus
an `overlap_total`. Measured on the **raw** (pre-validation) finding set. Folded
into the rolling aggregate so redundancy is visible across runs.

## 3. Non-goals

- **No new gate / no default-on.** Behind `review.metrics: true` exactly as today.
- **No fuzzy overlap matching.** Overlap clustering uses the exact identity key
  already used by dedup. The fuzzy line/title matcher in `intersect-findings.sh`
  is prosecutor-vs-defender and is **not** reused here.
- **No token implementation this cycle.** §7 records the deferred design only.
- **`validator-metrics.json` unchanged.** Only `findings.metrics.json` and the
  rolling aggregate gain fields.

## 4. Approach (Increment 1 — overlap)

### 4.1 Overlap computation (`intersect-findings.sh` → `emit_angle_metrics`)

`emit_angle_metrics` already loads `raw_findings.json` and is the per-run
assembler for `findings.metrics.json`. Extend its embedded Python:

- **Anchor filter.** Skip any raw finding missing `file` **or** a usable `line`
  (`safe_line` returns 0 / non-int). Unanchored findings are not credibly "the
  same issue" as another and must not form phantom clusters. They still count
  toward existing per-angle counts (`raw_count` etc.) — only overlap excludes
  them.
- **Cluster** the surviving findings by identity key
  `(file, safe_line(line), title_stem(title))`, where `title_stem` is the
  existing lowercase-alphanumeric-truncated-to-40 helper used in
  `merge-findings.sh` / `intersect-findings.sh`. This is the merge-findings dedup
  key **minus `angle`**, so identity is consistent across stages.
- merge-findings already collapsed within-angle duplicates in
  `raw_findings.json`, so within one cluster (fixed `title_stem`) an angle appears
  **at most once** → each cluster is a set of distinct angles `S`.
- For a cluster with angle set `S`: for each `a ∈ S`, and each `b ∈ S, b ≠ a`,
  `overlap_with[a][b] += 1`. Solo clusters (`|S| == 1`) contribute nothing. No
  angle ever counts itself (it appears once per cluster).
- `overlap_total[a] = sum(overlap_with[a].values())`.

Angle attribution uses the finding's `.angle` field (schema-required; missing →
existing `_unknown` bucket, unchanged).

### 4.2 `findings.metrics.json` schema (per-angle rec gains)

```json
"overlap_total": 3,
"overlap_with": { "security": 2, "types": 1 }
```

`overlap_with` is empty `{}` and `overlap_total` is `0` for an angle whose
findings never co-occur. No top-level change in this increment.

### 4.3 Rolling fold (`metrics-fold.sh`) + schema bump

- Bump `SCHEMA_VERSION 1 → 2`. An existing v1 `.woostack/metrics.json` hits the
  already-implemented version-mismatch path: backed up to `.bak`, reseeded.
  Acceptable — per-clone, gitignored, cheaply rebuilt.
- Per-angle slot init gains `overlap_total: 0` and `overlap_with: {}`.
- Fold per angle present in the run:
  - `slot.overlap_total += run overlap_total`
  - for each `(b, n)` in run `overlap_with[a]`: `slot.overlap_with[b] += n`
    (missing key initialized to 0).
- Reseed on the bump means no half-populated legacy slots to migrate.

### 4.4 Docs (`skills/woostack-review/SKILL.md`)

- **Artifact table**: update the `findings.metrics.json` row's key list with
  `overlap_total`, `overlap_with`.
- **`metrics` config note** (line ~165 / ~222): mention the new per-angle overlap
  fields and the rolling aggregate's new totals. Note schema is now v2.

## 5. Components & data flow (Increment 1)

```
Stage 4 merge-findings.sh
  └─ raw_findings.json   (unchanged; within-angle dedup already applied)

Stage 4 intersect-findings.sh → emit_angle_metrics  (EXTENDED)
  reads:  raw_findings.json (+ existing inputs)
  writes: findings.metrics.json
          per angle: …existing… + overlap_total, overlap_with

Stage 6.5 metrics-fold.sh  (EXTENDED, schema v2)
  reads:  findings.metrics.json + existing .woostack/metrics.json
  writes: .woostack/metrics.json
          per angle: …existing totals… + overlap_total, overlap_with
```

Boundaries unchanged: `emit_angle_metrics` owns per-run assembly,
`metrics-fold.sh` owns aggregation. Each independently testable from on-disk
fixtures.

## 6. Error handling (Increment 1)

- **Unanchored findings** — excluded from overlap (cannot crash clustering;
  `safe_line` / `title_stem` normalize inputs).
- **`emit_angle_metrics` failure** — already non-fatal (`|| echo "::warning::…"`).
  New code stays inside the guarded block; a bug here never sinks a review.
- **Schema bump on stale aggregate** — existing reseed-with-`.bak` path; the v1
  version check already rejects the old file.
- **Metrics off** — unchanged no-op: no `findings.metrics.json`, fold no-op.

## 7. Testing (Increment 1)

`skills/woostack-review/scripts/tests/` (follow existing harness conventions):

- **Overlap math** — 3-angle cluster → each angle `overlap_total == 2` with
  correct `overlap_with`; solo finding → `overlap_total == 0`,
  `overlap_with == {}`; two separate clusters sum per angle.
- **Unanchored exclusion** — findings missing `file`/`line` do not appear in any
  `overlap_with` and don't inflate another angle's totals.
- **Within-angle non-self-count** — same angle across chunks (already collapsed
  by merge) never counts overlap with itself.
- **Fold accumulation** — two folded runs sum `overlap_total` and merge-add
  `overlap_with`.
- **Fold v1→v2 reseed** — pre-existing v1 aggregate backed up to `.bak` and
  reseeded at v2 without crashing.
- **Metrics-off no-op** — unchanged.

## 8. Deferred: per-angle tokens (Increment 2, next cycle)

**Why deferred — capture gap.** On a bare Claude Code chat host the orchestrator
model only receives a sub-agent's final message via the `Task` result; it
**cannot observe the sub-agent's token usage**. The `skills` CLI install
(`npx skills add …`) writes skill files + symlinks only — it never wires a
consumer `SubagentStop` hook, and `woostack-init` scaffolds `.woostack/`, not
`.claude/settings.json`. So a naive "orchestrator writes `usage.<angle>.json`"
contract yields `null` for essentially every chat-host install.

**Planned next-cycle design (not built here):**

- Per-angle `usage.<angle>[.chunk-<id>].json` = `{input_tokens, output_tokens}`,
  summed per angle; `tokens: {input, output, total} | null` per angle in
  `findings.metrics.json`; top-level `tokens_degraded: bool`.
- Concrete producers: **CI `action.yml`** (claude-code-action reports usage; the
  metrics artifact is already uploaded) and an **optional shipped
  `scripts/capture-usage.sh` + documented `SubagentStop` hook** the chat-host
  consumer pastes into their own `settings.json`.
- Rolling fold: `tokens_input_total`, `tokens_output_total`, `tokens_total`,
  `token_runs_present` (honest averaging), top-level `tokens_degraded_runs`.
  Schema bump `2 → 3`.
- Degraded-by-default and stated plainly: no proxy/estimate, no pretending the
  chat host captures tokens for free.

## 9. Open questions

- **Exact vs fuzzy overlap key (resolved: exact).** Independent angles may anchor
  the same issue at slightly different lines or word the title past the 40-char
  stem, so exact keying can undercount. We accept undercount for determinism and
  zero false merges. Revisit only if real runs show material undercount.
- **Schema bump reseeds rolling history (resolved: accept).** v1→v2 discards the
  accumulated local aggregate (backed up to `.bak`). Acceptable: per-clone,
  gitignored, cheaply rebuilt.
