---
name: review-stack-aware
type: spec
status: planning
date: 2026-06-09
branch: review-stack-aware
links:
  - "[[2026-06-03-bounded-review-swarms]]"
  - "[[2026-06-04-review-nit-comments]]"
  - "[[2026-06-06-review-self-contained]]"
---

# Stack-aware review — Design Spec

> Visualize on demand: render this file with [spec-template.html](spec-template.html) for a rich view. Markdown is the source of truth; the HTML is a presentation target only.

> `status:` is the build-loop phase enum: `draft → hardened → approved → planning → executing → in-review → done` (plus the terminal `abandoned`). The build loop authors each transition and `/woostack-status` reads it; the enum and join contracts are defined once in [conventions.md](../../woostack-status/references/conventions.md).

## 1. Problem

`woostack-review` reviews a stacked PR as if it were the whole feature. It flags issues that are intentionally fixed by later PRs in the same Graphite stack.

Concrete (issue #224): PR #222 is Increment 1 of the `woostack-debug` stack. Its body explicitly says it ships only `skills/woostack-debug/SKILL.md`; call-site wiring and command enumeration land in Increment 2. The review still flagged the new skill text for presenting `/woostack-debug` as public/routed "before the later stack PR lands." Technically accurate for the isolated diff, but noise — the missing work is already planned and shipped by a descendant PR.

woostack's whole model is PR-sized stacked increments. Review noise on intentionally deferred stack work makes the review gate less useful and trains authors to ignore valid comments.

## 2. Goal

When reviewing a PR that is part of a stack, `woostack-review` recognizes work that a **later PR in the same stack verifiably implements**, and **demotes** the corresponding "missing X" finding to a non-blocking, stack-aware nit (`Deferred to #N`) instead of a normal finding. Verification is authoritative — driven by the descendant PR's actual diff, not by this PR's body language alone. The feature is host-agnostic (works in the GitHub Action and every local host), gated by a config switch, and degrades to a low-confidence note rather than a blind suppression when descendant inspection fails.

## 3. Non-goals

- **No silent drop.** A covered finding is demoted to a visible nit, never removed. (Locked design decision.)
- **No `drop` mode / no three-way enum.** Only a boolean `review.stack_aware` off-switch; behavior is demote-only.
- **No Graphite runtime dependency.** Detection is plain GitHub base-branch chaining; `gt` is never invoked.
- **No ancestor/sibling awareness.** Only *descendant* (later) PRs are inspected. Ancestors are already merged-into-base or below this PR and are out of scope.
- **No cross-repo stacks.** Descendants are open PRs in the same repo.
- **No deferral of `security` findings.** Security gaps are never auto-deferred even if a descendant closes them.
- **No new always-on cost.** PRs with no open descendants pay essentially nothing (one empty `gh pr list`).
- **No change to the incremental-mode, event-floor, prior-thread, or memory machinery** beyond adding one artifact on the existing rail.

## 4. Approach

Five pieces, each on an existing rail in the review pipeline. **Judgment lives in the validator (LLM); mechanical demotion lives in the deterministic classifier.**

1. **Detect** the descendant set in `prefetch.sh` via a new testable `scripts/detect-stack.sh`: open PRs whose `baseRefName` equals this PR's `headRefName`, recursively (children → grandchildren), **depth-capped at 10** and **cycle-guarded by a seen-set of PR numbers** so a malformed/looping base chain terminates. Gated by `review.stack_aware` (default `true`); off ⇒ no-op, no artifact, ~zero cost. **No CI permission change needed** — the `detect` job that runs `prefetch.sh` already declares `pull-requests: read` (reusable-review.yml), exactly what `gh pr list` / `gh pr diff` require.
2. **Compose** a `stack.md` context artifact (same rail as `rules.md` / `memory.md`): per descendant — `#number`, title, body, changed-file list, and the **full descendant diff** (Q1 resolved: full diff, not file-list-only with on-demand fetch — keeps the validator a pure reader, host-agnostic, no agent-side `gh` shell-out). The combined artifact is section-aware-capped at ≤100KB with **no fixed per-descendant byte budget** — the existing diff-cap ranking fills the total, dropping lowest-value descendant sections first while metadata always survives. This gives the validator real descendant code to verify against.
3. **Judge** in the defender validator (`prompts/validator.md`) **only** — the prosecutor is left unchanged. The intersection takes the defender's copy of non-severity/blocking fields, so a defender-set `stack_deferred` survives the merge; the prosecutor still keeps the finding (it *is* real for the isolated diff) and the defender annotates it. For each merged finding that asserts something is *missing / not-yet-wired / presented-before-it-lands*, check whether a descendant's diff in `stack.md` actually adds it. If yes, annotate `stack_deferred: "#N"` and set it non-blocking. Body cues ("Increment N") are a trigger hint only; the descendant diff is the proof.
4. **Demote** deterministically in `intersect-findings.sh::classify_floor`: any finding with a non-empty `stack_deferred` is forced to `nit: true`, `blocking: false`, independent of `severity_floor` (mirrors the existing blocking-override branch, inverted).
5. **Render** in the `_header.md` body builder: a `stack_deferred` finding posts as a nit with appended wording `Deferred to #N …`. Event stays `APPROVE`.

**Config + docs surface:** `load-config.sh` whitelists + boolean-validates `stack_aware` (unknown keys inside `review` hard-error today, so this is mandatory); `_header.md` config table + artifact list + findings schema gain entries; `SKILL.md` gains a config-schema key, a key-reference line, a "Stack-aware review" section, and an artifact-table `stack.md` row.

## 5. Components & data flow

```
prefetch.sh
  meta fetch: + headRefName                      (new field)
  load-config.sh: parse review.stack_aware       (whitelist + bool)
  detect-stack.sh (gated on stack_aware):
    gh pr list --base <headRefName> --state open  → children
    recurse on each child head (depth cap, seen-set) → descendants
    per descendant: number,title,body,files,capped-diff
  → $OUTDIR/stack.md                              (≤100KB, absent if none/off)

angle workers + validator passes
  read stack.md as additional rubric (documented in _header.md)

validator.md (defender, deep tier)
  per finding: if "missing/deferred-X" AND descendant diff adds X
    → set stack_deferred="#N", blocking=false   (security excluded)
  if stack.md degraded → mark low-confidence instead of deferring

intersect-findings.sh (classify_floor)
  stack_deferred non-empty → nit=true, blocking=false  (floor-independent)
  validator-metrics.json: + stack_deferred_count

_header.md body builder
  stack_deferred present → render nit + "Deferred to #N" note → APPROVE-neutral
```

Artifact join: `stack.md` sits beside `rules.md` / `memory.md` / `prior-findings.json` in `$OUTDIR`; consumed by the same worker/validator brief. New finding field `stack_deferred` (string `#N` or null) flows worker→merge→validator→intersect→body-builder unchanged by the merge (intersection takes the defender's copy of non-severity/blocking fields).

## 6. Error handling

- **No descendants / feature off** → `detect-stack.sh` writes no `stack.md`; every downstream consumer already treats it as optional (mirrors `rules.md`). No behavior change.
- **`gh pr list` / `gh pr diff` failure on a descendant** (auth, rate-limit, private, force-push) → emit a `::warning::`, include the descendant's metadata it *did* fetch, and mark the descendant-diff portion degraded in `stack.md`. The validator then treats affected findings as **low-confidence notes**, never silent deferrals.
- **Malformed / cyclic stack** (a PR chain that loops) → seen-set cycle guard + depth cap stop the recursion; partial descendant set is still usable.
- **`stack.md` over 100KB** → section-aware cap drops lowest-value descendant-diff sections first (reuse the existing diff-cap ranking), records dropped paths, emits a `::warning::`; metadata (number/title/body/file-list) is never dropped.
- **Bad `stack_aware` value** (non-boolean) → `load-config.sh` emits the existing loud `::error file=.woostack/config.json,line=N::` and fails the run (no silent fallback), consistent with every other key.
- **Self-PR / event interactions** unchanged — deferral only ever lowers an event (blocking→nit), never raises it, so it cannot break the self-PR downgrade or the event-floor.

## 7. Acceptance criteria

- **AC1 — Descendant detection (base-branch chaining, recursive)**
  - happy: a PR with one open child (child `baseRefName` == parent `headRefName`) and one grandchild yields both in the descendant set.
  - error: `gh pr list` failing for a level emits a `::warning::` and returns the descendants gathered so far (no abort).
  - edge: a cyclic/self-referential base chain terminates via the seen-set; depth beyond the cap stops without error.
- **AC2 — `stack_aware` off-switch (default on)**
  - happy: default (key absent) runs detection; `review.stack_aware: false` skips detection entirely — no `stack.md`, no `gh pr list`.
  - error: a non-boolean `stack_aware` triggers the loud `::error file=…::` and a non-zero exit from `load-config.sh`.
  - edge: explicit `review.stack_aware: true` behaves identically to the absent default.
- **AC3 — `stack.md` composition + cap**
  - happy: with N descendants, `stack.md` contains each descendant's number, title, body, changed-file list, and capped diff.
  - error: a descendant whose diff fetch fails still appears with its metadata, flagged degraded.
  - edge: combined content over 100KB drops lowest-value diff sections first; metadata survives; a `::warning::` lists dropped paths.
- **AC4 — Deferral demotes a covered finding to a stack-aware nit**
  - happy: a "missing integration X" finding whose X is added by a descendant diff is rendered as a non-blocking nit carrying `Deferred to #N`; the review event stays `APPROVE`.
  - error: when `stack.md` is degraded for the relevant descendant, the finding is surfaced as a low-confidence note, not deferred or dropped.
  - edge: a `security`-angle finding, or a finding about wrong code *present in this PR*, is never deferred even if a descendant touches the same area.
- **AC5 — Classifier forces nit independent of `severity_floor`**
  - happy: a finding with `stack_deferred` set becomes `nit: true, blocking: false` under `severity_floor: high`.
  - error: N/A — `classify_floor` is pure over its inputs (no IO failure path).
  - edge: the same finding stays a nit under `severity_floor: low` (where its severity would otherwise be at/above floor); `validator-metrics.json` reports `stack_deferred_count`.

## 8. Testing

> Strategy only — harness, test levels, fixtures, CI. Per-behavior cases live in §7.

Shell-based unit tests under `skills/woostack-review/scripts/tests/`, matching the existing `test-*.sh` style and runner (`source assert.sh`, `mktemp -d` OUTDIR, `finish`). `detect-stack.sh` is tested with **`WOO_REVIEW_TEST_MODE=1`-gated `WOO_REVIEW_FAKE_*` env hooks** feeding canned `gh pr list` / `gh pr diff` JSON — the exact pattern `prefetch.sh` already uses for `WOO_REVIEW_FAKE_PR_REVIEWS_JSON` / `_PRIOR_THREADS_JSON` (CI-refused: the hooks hard-error when `GITHUB_ACTIONS=true`). This verifies detection, recursion to grandchildren, the depth cap, the cycle guard, and the off-switch with no network. `load-config.sh` gets a `stack_aware` accept (bool) / reject (non-bool → loud error + non-zero exit) case alongside the existing config tests. `intersect-findings.sh` gets a `stack_deferred → nit` case under both `severity_floor: high` and `low`, asserting `nit:true`, `blocking:false`, and `stack_deferred_count` in `validator-metrics.json`. Validator/body-builder behavior (LLM-judgment steps in `validator.md` / `_header.md`) is specified in prompt text and exercised by the deterministic classifier + render tests around it; no live-LLM test is added. New tests run in the same way the existing `scripts/tests/test-*.sh` do.

## 9. Resolved decisions (hardened)

All open questions resolved during spec harden:

- **Q1 — `stack.md` carries the full descendant diff** (section-aware-capped, ≤100KB total), not file-list-only with on-demand fetch. Keeps the validator a pure reader (no agent-side `gh`), deterministic and host-agnostic; cost is already bounded by the off-switch, zero-descendant common case, and the cap. *(confirmed)*
- **Q2 — depth cap = 10; cycle guard = seen-set of PR numbers; no fixed per-descendant byte budget** — the existing section-aware diff-cap ranking fills the 100KB total.
- **Q3 — defender-only reads `stack.md`.** The intersection takes the defender's copy of non-severity/blocking fields, so `stack_deferred` survives without teaching the prosecutor about stacks.
- **Q4 — `stack_deferred_count` lives in `validator-metrics.json` only**, not the review body summary (mirrors `disagreement_count`). The per-finding `Deferred to #N` note is the user-visible signal.
- **CI permissions — no change.** The `detect` job that runs `prefetch.sh` already has `pull-requests: read`, which is all `gh pr list` / `gh pr diff` need.
- **Test harness — `WOO_REVIEW_TEST_MODE`-gated `WOO_REVIEW_FAKE_*` hooks** (CI-refused), mirroring `prefetch.sh`'s existing canned-`gh` pattern; no network in tests.

No new questions remain — spec is hardened.
