---
name: review-nit-comments
type: spec
status: done
date: 2026-06-04
branch: feature/review-nit-comments
links:
---

# Review Nit Comments (below-floor findings surface as nits) — Design Spec

> **Plan:** [[plans/2026-06-04-review-nit-comments]]

> Visualize on demand: render this file with [spec-template.html](spec-template.html) for a rich view. Markdown is the source of truth; the HTML is a presentation target only.

## 1. Problem

`woostack-review` applies `severity_floor` (default `high`) as a **drop gate inside both
validator passes**: `prompts/validator-prosecutor.md` step 6 and `prompts/validator.md` step 6
each `Drop findings strictly below it`. A finding that survives the full skeptical pipeline —
both the prosecutor (inclusive) and defender (exclusive) passes agree it is real — is then
discarded outright if its severity is below the floor. With the default floor of `high`, every
validated MEDIUM and LOW finding vanishes silently.

That throws away signal. Validation already removed false positives; what remains below the
floor is a real, low-importance issue the author would often want to know about. The floor's
job is **noise control on what blocks / demands attention**, not erasure of every confirmed
low-severity observation. Today there is no middle ground between "blocks the PR" and "never
mentioned."

## 2. Goal

When a finding is validated (kept by the adversarial pipeline) but its final severity is below
`severity_floor`, surface it as a **nit**: a non-blocking, event-neutral inline comment marked
as optional, instead of dropping it.

The design must:

- keep below-floor validated findings instead of dropping them, classifying them as nits;
- never let a nit block: a nit forces `blocking: false` and never raises the review event;
- mark nits distinctly on the PR — `Nit:` title prefix and a `NIT` footer tag — posted inline
  like any other comment;
- make this the **default** behavior (reframe `severity_floor` from a drop gate to a
  blocking/visibility threshold), with a `review.nits` opt-out that restores today's drop;
- apply the floor in exactly **one** place so swarm and CI paths behave identically;
- keep the existing event semantics for blocking and at/above-floor non-blocking findings;
- keep memory-accepted, rule-quote, dedup, and `fix_type` behavior unchanged.

## 3. Non-goals

- Do not change angle detection, chunking, prefetch, or the swarm orchestration.
- Do not add a separate `nit_floor` band — below-floor is uniformly nit (or dropped when
  `nits: false`). (Considered and rejected during ideation for config-surface minimalism.)
- Do not change what makes a finding *blocking* (the Blocking Criteria in `_header.md` stand).
- Do not let nits change the review event: a PR whose only findings are nits still `APPROVE`s.
- Do not add a new application build, app lockfile, or CI workflow for this repository.
- Do not alter cross-PR memory drop semantics — accepted/known issues never become nits.
- Do not re-route or re-fetch anything; this is a classification + rendering change only.

## 4. Approach

Centralize the floor in `scripts/intersect-findings.sh` and stop the two validator passes from
dropping by severity. The floor moves from "drop inside each pass" to "classify once, after the
final severity is known."

**Validator passes (`validator-prosecutor.md`, `validator.md`).** Remove the "Severity Floor"
step (step 6 in each). Replace it with an explicit instruction that severity-based filtering is
now applied downstream by `intersect-findings.sh`, and that the pass MUST keep every validated
finding regardless of severity (after its own allowed *downgrade*) so the classifier can see it.
Every other step — dedup, prosecutor/defender audit, memory drop, rule-quote check, severity
downgrade, comment-shape, `fix_type` enforcement — is unchanged. The `config.json` input note in
each pass changes from "reads `.severity_floor`" to "reads nothing severity-related" (the floor
is no longer consumed in the passes).

**Classifier (`intersect-findings.sh`).** The script already computes the final set with
`severity = min(prosecutor, defender)` and `blocking = prosecutor AND defender`. After the final
set is produced — in **both** the adversarial-intersection path and the defender-only /
`disable_adversarial` copy path — apply a single classification pass over the final findings:

- read `severity_floor` (default `high`) and `nits` (default `true`) from `$OUTDIR/config.json`;
- for each finding, compare its final `severity` to the floor (`LOW < MEDIUM < HIGH`):
  - at/above floor → `nit: false` (normal finding, unchanged);
  - below floor **and** `blocking == true` → **blocking overrides the floor** (global safety
    rule): `nit: false`, `blocking` stays `true`. A blocking issue is never demoted to a nit; it
    still triggers `REQUEST_CHANGES`. Applies regardless of the `nits` knob, and fixes today's
    latent footgun where a below-floor blocking finding is silently floor-dropped;
  - below floor **and** `blocking == false` **and** `nits != false` → `nit: true`,
    `blocking: false` (nit);
  - below floor **and** `blocking == false` **and** `nits == false` → **drop**.

`nits: false` therefore restores the old *nit* behavior (below-floor non-blocking findings are
dropped) but is **not** a byte-exact old-behavior restore: the blocking-override safety rule still
surfaces a below-floor blocking finding under `nits: false`.

Because the classifier runs on the merged `findings.json` regardless of mode, the floor has one
implementation and swarm vs. CI vs. defender-only all agree. CI's sequential validator already
calls `intersect-findings.sh` at its step 3, so it inherits the change with no separate edit.

**Renderer + event (`prompts/_header.md`).** The Python payload builder reads the new `nit`
field and:

- renders the title as `Nit: <title>` when `nit` is true;
- appends a `NIT` tag to the attribution footer's severity segment (e.g. `LOW · NIT`); nits are
  never blocking, so `· BLOCKING` never co-occurs;
- computes the review event treating nits as event-neutral (see §5);
- emits the new STATUS_LINE shapes with a `+ Q nit(s)` suffix (see §5).

The `_header.md` edits span: the payload-builder Python (render + event), the STATUS_LINE
section, the **Output Contract** paragraph (its "`COMMENT` (no blocking findings)" line must
become nit-aware — nits-only is `APPROVE`), the Findings Schema (`nit` field), and the per-repo
config-key table (`nits`).

**Provider orchestrator prompts.** `anthropic.md`, `openai.md`, `google.md`, and `opencode.md`
do **not** embed the payload builder (only `_header.md` does), but each restates the event rule
in one prose sentence: *"`COMMENT` when there are only non-blocking new findings…"*. That summary
becomes inaccurate because a nit is a non-blocking new finding that must yield `APPROVE`. Update
that one sentence in each of the four files so the human-readable summary stays correct
(`COMMENT` when a non-nit non-blocking finding exists; `APPROVE` when the only new findings are
nits or there are none). Also add `NIT_COUNT` to the "Compute …_COUNT" list each restates. No
executable logic is duplicated — these are prose-accuracy edits only.

**Config loader (`scripts/load-config.sh`).** `load-config.sh` validates `.woostack/config.json`
against a `REVIEW_KEYS` whitelist and **fails the workflow loudly on any unknown `review` key**.
`nits` must therefore be added there, mirroring the existing `disable_adversarial` / `metrics`
boolean handling: add `"nits"` to `REVIEW_KEYS`; add a validation block that `loud()`s if the
value is not a boolean; emit `out["nits"]` only when the key is present (absent ⇒ not written, and
the downstream classifier defaults it to `true` via `jq -r '.nits // true'`). Also add `nits` to
the loader's header-comment key list. Without this whitelist entry, any repo that sets
`review.nits` would hard-fail its review.

**Config + docs.** Add `review.nits` (boolean, default `true`) to the config schema and the
key-reference in `SKILL.md`. Rewrite the "Noise control (`severity_floor`)" section to describe
the reframe. The `_header.md` per-repo config-key table also gets a `nits` row (consumed by
`intersect-findings.sh` at Stage 4c). Update the `findings.metrics.json` artifact-table row in `SKILL.md` (line ~236) for
the new `nit_count` field, the redefined `nonblocking_count`, and `schema v3`. Update the Stage 5
report description (event determination) for the nits-event rule.

`action.yml` and `.github/workflows/reusable-review.yml` ship the same `prompts/` and `scripts/`
assets, so they ride the change unchanged — verified, not patched, during execution.

## 5. Components & data flow

```
angle workers ─► merge-findings.sh ─► prosecutor pass ─┐
                                       defender pass  ─┴► intersect-findings.sh
                                                            ├─ merge: severity=min, blocking=AND
                                                            ├─ NEW: floor classify (nit / drop)
                                                            └─► findings.json ─► _header.md render + post
```

**`findings.json` schema — new field.** Each finding gains:

```json
{ "nit": false }
```

`nit: true` ⇒ the finding is validated, below `severity_floor`, **and** non-blocking; it renders
as a nit. A below-floor finding that is `blocking: true` is **not** a nit (`nit: false`) — the
blocking-override keeps it a normal blocking finding. `nit: false` (or absent, treated as false)
⇒ normal finding. The classifier sets this field explicitly on every finding in `findings.json`.

**Classifier placement in `intersect-findings.sh`.** Two write sites produce `findings.json`:

1. the defender-only / `disable_adversarial` path (`cp "$DEFENDER" "$FINAL"`);
2. the adversarial intersection path (the Python `json.dump(kept, ...)`).

A single post-step runs after either site, reading `$FINAL`, applying the floor/nits rules, and
rewriting `$FINAL` in place. Implementing it once (a small Python or jq pass invoked after both
branches, before `kept_count` / metrics are computed) avoids divergence. `kept_count` and the
metrics are then computed from the post-classification `$FINAL`, so a `nits: false` drop is
reflected in counts.

**Event determination (`_header.md`).** Let `findings` be the final set:

- `has_blocking = any(f.blocking)` — nits are `blocking: false`, so they never contribute;
- `has_open_priors` — unchanged (open prior threads floor to `REQUEST_CHANGES`);
- `non_nit = [f for f in findings if not f.nit]`;
- event:
  - `REQUEST_CHANGES` if `has_blocking or has_open_priors`;
  - else `COMMENT` if `non_nit` is non-empty (a real, non-blocking, at/above-floor finding);
  - else `APPROVE` (covers both "only nits" and "no findings"). The nit comments are still
    included in the review's `comments` array, so `APPROVE` carries them inline.

**STATUS_LINE shapes (`_header.md`).** Counts: `BLOCKING_COUNT`, `NONBLOCKING_COUNT` (non-nit,
non-blocking), `NIT_COUNT`. The `+ Q nit(s)` suffix appears only when `NIT_COUNT > 0`.

- `BLOCKING_COUNT >= 1` → `**Status: CHANGES REQUESTED** — N blocking finding(s) (H HIGH, M MEDIUM, L LOW) + K non-blocking[ + Q nit(s)]. See inline comments.`
- `BLOCKING_COUNT == 0, NONBLOCKING_COUNT >= 1` → `**Status: APPROVED WITH SUGGESTIONS** — N non-blocking finding(s) (H HIGH, M MEDIUM, L LOW)[ + Q nit(s)]. See inline comments.`
- `BLOCKING_COUNT == 0, NONBLOCKING_COUNT == 0, NIT_COUNT >= 1` → `**Status: APPROVED** — No blocking findings, Q nit(s). See inline comments.`
- All zero → `**Status: APPROVED** — No validated findings.`

The H/M/L breakdown on the blocking and non-blocking lines counts non-nit findings only; nits
are summarized by the single `Q nit(s)` count (nits are MEDIUM/LOW by definition of being below
the default floor, so a severity histogram on them adds little).

**`validator-metrics.json` accounting.** The classifier runs **after** the intersection and
**before** counts are computed. `disagreement_count` is measured on the **pre-floor** intersection
(the true prosecutor∩defender agreement): `disagreement = (prosecutor_count − intersection_size) +
(defender_count − intersection_size)`, where `intersection_size` is the agreed-set size before the
floor classifier touches it. `kept_count` is the **post-classification** `findings.json` length
(what is actually shown). Under the default `nits: on` no finding is dropped, so
`intersection_size == kept_count` and the formula is unchanged; the two diverge only under the
`nits: false` opt-out, where floor-dropped agreements are correctly excluded from disagreement
rather than miscounted as cross-pass disagreement. The two validator passes now emit below-floor
findings (they no longer floor), so `prosecutor_count` / `defender_count` grow to include them —
this is honest raw-pass sizing, and the pre-floor `intersection_size` keeps the disagreement metric
a true cross-pass measure. `write_metrics` takes the pre-floor `intersection_size` for the
disagreement math and the post-floor `kept_count` for the `kept_count` field.

`validator-metrics.json` also gains a top-level `nit_count` (count of nits in the final set) for
observability parity. It is cheap (the classifier already knows the nit count) and lets a run's
nit volume be read without enabling the opt-in per-angle metrics.

**Metrics (`findings.metrics.json`, opt-in via `review.metrics`).** The per-angle `emit_angle_metrics`
in `intersect-findings.sh` reads the final set. Add `nit_count` per angle and redefine
`nonblocking_count = kept - blocking_count - nit_count` so nits do not inflate the non-blocking
tally. Because `nonblocking_count`'s meaning changes (a semantic shift, not a purely additive
field), bump the per-run `findings.metrics.json` `schema_version` **2 → 3** (the literal at
`intersect-findings.sh` line 221) and update its assertion in
`scripts/tests/test-intersect-overlap.sh`.

**Rolling aggregate (`metrics-fold.sh` → `.woostack/metrics.json`, local-only).** `metrics-fold.sh`
folds the per-run record into the rolling aggregate. It does **not** read `nonblocking_count`
today, so that redefinition does not touch it, but it must gain nit parity: read `rec.nit_count`
and accumulate a per-angle `nit_total` in the angle slot template, and bump its own aggregate
`SCHEMA_VERSION` (the `SCHEMA_VERSION=2` constant, distinct from the per-run version) **2 → 3**.
The fold's existing reseed-on-version-mismatch path then backs up any existing v2 aggregate to
`.bak` and reseeds — a one-time, documented history reset identical to the prior v1 → v2 bump
(it is per-clone local data, never committed). Update `scripts/tests/test-metrics-fold-overlap.sh`
to seed a v3 per-run record and assert the aggregate reseeds at `schema_version 3` with
`nit_total` accumulated.

## 6. Error handling

- **Missing/absent `nit` field at render.** The renderer treats a missing `nit` as `false`
  (normal finding). The classifier always writes the field, but defensive default keeps old
  artifacts and any hand-built finding rendering correctly.
- **Double `Nit:` prefix.** An angle may already phrase a title as `Nit: …`. The renderer adds
  the `Nit:` prefix only when the title does not already start with a case-insensitive `nit:`,
  so the rendered headline never becomes `Nit: Nit: …`.
- **`nits` config parse.** `nits` defaults to **on**, so it must NOT use `jq -r '.nits // true'`:
  jq's `//` treats `false` as empty, coercing an explicit `false` back to `true` and silently
  ignoring the opt-out. Detect the opt-out explicitly instead — `v="$(jq -r '.nits' "$CONFIG")"`
  then `[ "$v" = "false" ] && nits_enabled="false"` (absent/`null`/anything else ⇒ on). An
  unknown/invalid value must not crash intersect.
- **Floor parse.** `severity_floor` is already validated upstream by `load-config.sh`; the
  classifier reads it with a `// "high"` default and case-insensitive compare, mirroring the
  current validator behavior. An unrecognized floor value defaults to `high`.
- **Defender-only / degraded path.** The classifier runs on the copied defender output too, so a
  degraded (prosecutor-absent) run still produces correctly classified nits. Degradation
  reporting (`degraded: true`, the ⚠️ body line) is unchanged.
- **`nits: false` drop is honest.** Because `kept_count` and metrics are computed after
  classification, a dropped below-floor finding is reflected in counts exactly as a pre-floor
  drop would have been — no phantom "kept" inflation.
- **Self-PR downgrade unchanged.** Event downgrade for self-authored PRs still applies to
  `REQUEST_CHANGES` / `APPROVE`; nits-only `APPROVE` is unaffected (APPROVE on your own PR is
  already downgraded to `COMMENT` by the existing guard, which is acceptable).

## 7. Testing

Follow the existing review script-test style under `skills/woostack-review/scripts/tests/`. Add
focused `intersect-findings.sh` cases driven by fixture `findings.prosecutor.json` /
`findings.defender.json` (and a `config.json`):

- below-floor finding that both passes keep is classified `nit: true`, `blocking: false`, and is
  present in `findings.json` (default `nits` on, floor `high`);
- at/above-floor finding is `nit: false` and unchanged;
- `review.nits: false` drops the below-floor finding entirely (parity with old behavior);
- floor interaction: with `severity_floor: medium`, a MEDIUM finding is normal and a LOW finding
  is a nit; with `severity_floor: low`, nothing is a nit;
- a finding both passes keep but the defender downgraded below the floor becomes a nit (downgrade
  then classify ordering);
- a below-floor finding with `blocking: true` surfaces as a normal blocking finding (`nit: false`,
  `blocking: true`) under **both** `nits: true` and `nits: false` — the blocking-override safety
  rule (it is never dropped or demoted to a nit);
- defender-only / `disable_adversarial` path also classifies nits correctly;
- `disagreement_count` is measured pre-floor: with `nits: false` dropping a below-floor agreed
  finding, `disagreement_count` does **not** inflate (the dropped finding was an agreement);
- `nit_count` / `nonblocking_count` accounting in `findings.metrics.json` when `metrics` is on,
  and the per-run `schema_version` is `3` (`test-intersect-overlap.sh`);
- `metrics-fold.sh` reseeds an existing v2 aggregate to `schema_version 3` and accumulates
  `nit_total` from a v3 per-run record (`test-metrics-fold-overlap.sh`).
- `load-config.sh` accepts `review.nits: true|false` (emits it to the canonical config) and
  `loud()`-fails on a non-boolean `nits` value — covered by a focused config-loader case (a new
  `scripts/tests/` test, since none exists for the loader today) or, if that is deferred, by a
  documented manual config check in the plan.

Renderer behavior (`_header.md` Python) is validated by a small fixture-driven check if a
harness exists, otherwise by a documented manual case in the plan: a `nit: true` finding renders
`Nit:` prefix + `· NIT` footer and produces `event = APPROVE` when it is the only finding.

No app build or CI workflow is added for this repository.

## 8. Resolved decisions

Settled during spec hardening (no blocking open questions remain):

- **Default behavior** — nits ON by default; `severity_floor` reframed from a drop gate to a
  blocking/visibility threshold. `review.nits: false` drops below-floor non-blocking findings
  (the old nit behavior), but is not a byte-exact restore (see blocking-override below).
- **Blocking overrides the floor (global)** — a `blocking: true` finding is never demoted to a
  nit, even below the floor; it surfaces as a normal blocking finding and triggers
  `REQUEST_CHANGES`. This rule is independent of the `nits` knob (applies under `nits: false`
  too) and fixes today's latent footgun where the floor silently drops a below-floor blocking
  finding.
- **Nits-only review event** — `APPROVE` with the nit comments posted inline (nits are
  event-neutral; they never withhold the green check).
- **Nit marking** — `Nit:` title prefix + `· NIT` footer tag, posted inline per nit.
- **Floor location** — single classifier in `intersect-findings.sh`, after the intersection /
  defender-only copy, before counts. The two validator passes no longer floor.
- **`disagreement_count` honesty** — measured on the pre-floor intersection size; `kept_count`
  is the post-classification count. They diverge only under `nits: false`.
- **Metrics visibility** — top-level `nit_count` in `validator-metrics.json`; per-angle
  `nit_count` + redefined `nonblocking_count` in `findings.metrics.json` (per-run
  `schema_version` 2 → 3); `nit_total` in the rolling aggregate with `metrics-fold.sh`
  `SCHEMA_VERSION` 2 → 3 (one-time reseed of existing v2 aggregates, as with v1 → v2).
- **Unknown/missing severity** — `intersect-findings.sh` already defaults an unrecognized
  severity to `MEDIUM` (`sev_rank` → 1). A validated finding with no usable severity therefore
  classifies as a nit under the default `high` floor — the conservative outcome (surfaced,
  non-blocking, never dropped). No special-casing needed; noted here so it is intentional.
