---
name: review-stack-aware
type: spec
status: approved
date: 2026-06-09
branch: review-stack-aware-markers
links:
  - "[[2026-06-03-bounded-review-swarms]]"
  - "[[2026-06-04-review-nit-comments]]"
  - "[[2026-06-06-review-self-contained]]"
  - "[[2026-06-05-woostack-plan]]"
  - "[[2026-06-04-woostack-execute]]"
---

# Stack-aware review — Design Spec

> **Plan:** [[plans/2026-06-09-review-stack-aware]]

> Visualize on demand: render this file with [spec-template.html](spec-template.html) for a rich view. Markdown is the source of truth; the HTML is a presentation target only.

> `status:` is the build-loop phase enum: `draft → hardened → approved → planning → executing → in-review → done` (plus the terminal `abandoned`). The build loop authors each transition and `/woostack-status` reads it; the enum and join contracts are defined once in [conventions.md](../../woostack-status/references/conventions.md).

## 1. Problem

`woostack-review` reviews a stacked PR as if it were the whole feature. It flags issues that are intentionally fixed by a **later increment in the same plan**.

Concrete (issue #224): PR #222 is Increment 1 of the `woostack-debug` stack. Its body explicitly says it ships only `skills/woostack-debug/SKILL.md`; call-site wiring and command enumeration land in Increment 2. The review still flagged the new skill text for presenting `/woostack-debug` as public/routed "before the later stack PR lands." Technically accurate for the isolated diff, but noise — the missing work is already planned and shipped by a later increment.

woostack's whole model is PR-sized stacked increments. Review noise on intentionally deferred stack work makes the review gate less useful and trains authors to ignore valid comments.

**Why this is a rewrite.** The first design (shipped as the now-closed PRs #276–#278) solved this by *detecting and fetching the descendant PRs*: `prefetch.sh` ran a new `detect-stack.sh` that listed open PRs, base-branch-chained to find descendants, fetched **every descendant's full diff** via `gh pr diff`, and composed a `stack.md` artifact (BFS chaining, cycle guard, depth cap, 100KB byte cap, degraded-diff handling) so the validator could verify a "missing X" finding against the descendant's real code. It worked, but the cost recurs on **every review of every stacked PR**: N extra `gh` round-trips plus N descendant diffs inflating every angle worker's and the validator's context window. The signal — "this gap is intentional, a later increment fills it" — is already known at **plan time**. This rewrite moves the signal to where it is cheapest to carry: an inline **deferral marker** authored during plan/execute and read straight from the PR's *own* diff. Review fetches zero other PRs.

## 2. Goal

When reviewing a stacked increment, `woostack-review` recognizes a gap that a later increment intentionally fills by honoring an inline **deferral marker** — `woostack-defer(<ref>): <reason>` — that `woostack-execute` writes at the deferral site under an approved, hardened plan. A "missing X" finding that lands on a marker covering that same gap is **demoted** to a non-blocking, visible `Deferred to <ref>` nit instead of a normal finding.

The marker lives in the PR's own diff, so detection costs nothing extra at review time — no descendant-PR listing, no diff fetching, no `stack.md`. The burden of declaring intent moves **upstream** to `woostack-plan` (which instructs where to drop and later remove the marker) and `woostack-execute` (which writes and removes it). The feature is host-agnostic, gated by `review.defer_markers` (default `true`), and trusts the marker because its provenance is the approved plan, not arbitrary author text — a woostack-specific token (never a bare `TODO`) keeps casual comments from silencing the gate. Security findings are never deferred.

## 3. Non-goals

- **No descendant-PR fetching.** No `detect-stack.sh`, no `gh pr list`/`gh pr diff` for siblings, no `stack.md`. This design **supersedes and removes** the closed diff-verify approach (PRs #276–#278).
- **No silent drop.** A covered finding is demoted to a visible nit, never removed. (Locked design decision.)
- **No `drop` mode / no three-way enum.** Only a boolean `review.defer_markers` off-switch; behavior is demote-only.
- **No bare-`TODO` honoring.** Only the woostack-specific `woostack-defer(...)` token demotes a finding, so an ordinary `// TODO` comment can never suppress a review finding.
- **No deferral of `security` findings.** Security gaps are never auto-deferred even if a marker claims a later increment closes them.
- **No deferral of wrong code present in this PR.** The marker only covers *missing / not-yet-wired* work a later increment completes; it never excuses incorrect code that is actually in this diff.
- **No staleness policing by *review*.** The review gate never chases orphaned markers — that keeps the review path lean. Resolution is owned upstream instead (§4.2): `woostack-execute` removes every matching marker when it implements the increment, and `woostack-status` surfaces any `woostack-defer` marker still in the tree as an open deferral. The review gate itself stays out of it.
- **No Graphite/host dependency.** The marker is plain text in the unified diff; nothing chains branches or shells out to `gt`.
- **No change to the incremental-mode, event-floor, prior-thread, or memory machinery** beyond the existing finding-field rail the demotion already rides.

## 4. Approach

A deferral marker authored upstream, honored by the existing review machinery. Six pieces; **judgment lives in the validator (LLM); mechanical demotion lives in the deterministic classifier** — unchanged from the prior design, but the *source of truth* is now the in-diff marker, not a fetched descendant diff.

### 4.0 The marker (defined once)

A deferral marker is a single comment line, in whatever comment syntax the file uses:

```
woostack-defer(<ref>): <human-readable reason>
```

- `<ref>` — where the work lands: `increment N` (preferred — stable across the plan, known before any later PR exists) or a PR `#N`. Captured verbatim from between the parentheses.
- `<reason>` — what is deferred, in enough words that a reviewer can match it to a finding (e.g. `call-site wiring lands here`).
- The literal token is **`woostack-defer`**, matched case-sensitively. Examples across languages:
  - `// woostack-defer(increment 3): call sites wired in increment 3`
  - `# woostack-defer(increment 2): enum value added next increment`
  - `<!-- woostack-defer(increment 2): command routed after this lands -->`

The token is the canonical contract: `woostack-plan`, `woostack-execute`, and `woostack-review` all reference §4.0, none redefine it.

### 4.1 Honor (review)

1. **Judge** in the defender validator (`prompts/validator.md`) **only** — the prosecutor is unchanged; the intersection takes the defender's copy of non-severity/blocking fields, so a defender-set `deferred_to` survives the merge. For each merged finding that asserts something is *missing / not-yet-wired / presented-before-it-lands*, the defender scans **the PR diff it already holds** for a `woostack-defer(...)` marker that is **co-located** with the finding — in the same diff hunk, or within a few lines of the flagged code — **and** whose reason plausibly covers that gap. If one exists, it sets `deferred_to: "<ref>"` and `blocking: false`. Co-location is the primary guard: a marker only ever demotes the finding at *its own site*, never a same-file finding elsewhere, and detection stays chunk-safe because the marker sits on the very lines the finding flags. The marker reason is a hint; the defender still judges that the marker actually covers *this* finding. **Never** set `deferred_to` on a `security`-angle finding, on a finding about wrong code present in this PR, or against a bare `TODO`.
2. **Demote** deterministically in `intersect-findings.sh::classify_floor`: any finding with a non-empty `deferred_to` is forced to `nit: true`, `blocking: false`, independent of `severity_floor` (mirrors the existing blocking-override branch, inverted). `validator-metrics.json` gains `deferred_count`.
3. **Render** in the `_header.md` body builder: a `deferred_to` finding posts as a nit with appended wording `Deferred to <ref> — completed by a later increment; non-blocking.` Event stays `APPROVE`.
4. **Config:** `load-config.sh` whitelists + boolean-validates `defer_markers` (unknown keys inside `review` hard-error today, so this is mandatory); default `true`. `false` ⇒ the validator skips the marker scan entirely and no finding is ever deferred.

Angle workers may *see* the marker (it is just a comment in their chunk) and are free to raise the finding anyway — that keeps each worker honest about the isolated diff; the **defender alone** demotes, so deferral has a single auditable owner.

### 4.2 Declare, resolve, surface (plan + execute + status) — the burden shift

5. **`woostack-plan`** — when a step intentionally defers integration to a later increment, the plan authors **two** linked instructions: a "drop a `woostack-defer(increment N): …` marker at <site>" step in the deferring increment, and a paired "remove the `woostack-defer` marker at <site>" step inside increment N's implementation. The plan references §4.0 for the token; it never invents its own.
6. **`woostack-execute`** — writes the marker when it executes the deferring step. When it executes the **implementing** increment, it removes the marker — both the plan-named site and, belt-and-suspenders, any other `woostack-defer(increment N)` for the increment it is completing (a tree grep + remove), so a forgotten site cannot strand a marker. Markers thus exist exactly while the gap is open. A short doctrine line points at §4.0 so an executor encountering "drop/remove a deferral marker" knows the exact token.
7. **`woostack-status`** — its read-only board scans the working tree for `woostack-defer(...)` markers and lists each as an **open deferral** (file + `<ref>`). An orphaned marker (implementing increment landed but the marker survived) is therefore visible on the board, never silent. Status never edits or removes markers — surfacing only.

This is the inversion the rewrite buys: the cost of declaring "this gap is intentional" is paid **once, upstream, by the author of the work**, instead of **every review** re-deriving it by fetching and reading sibling PRs. Resolution and visibility are owned upstream too (execute removes, status surfaces) so the review path never grows a staleness check.

## 5. Components & data flow

```
woostack-plan (deferral step)
  emits: "increment N: drop woostack-defer(increment N+k) marker at <site>"
  emits: "increment N+k: remove woostack-defer marker at <site>"

woostack-execute
  deferring increment    → writes  woostack-defer(<ref>): <reason>  into the code
  implementing increment → removes the marker (plan site + tree-grep belt-and-suspenders)

woostack-status (read-only)
  greps tree for woostack-defer(...) → lists open deferrals (file + <ref>); never edits

woostack-review (on the deferring increment's PR)
  prefetch.sh: unchanged (no detect-stack.sh, no stack.md)
  load-config.sh: parse review.defer_markers           (whitelist + bool)

  angle workers
    see the marker as an ordinary comment; may still raise "missing X"

  validator.md (defender, deep tier)
    scan THIS PR's diff for woostack-defer(<ref>) markers
    per finding: if "missing/deferred-X" AND a marker covers X
      → set deferred_to="<ref>", blocking=false   (security & in-PR-wrong-code excluded;
                                                    bare TODO excluded; skipped if defer_markers=false)

  intersect-findings.sh (classify_floor)
    deferred_to non-empty → nit=true, blocking=false   (floor-independent)
    validator-metrics.json: + deferred_count

  _header.md body builder
    deferred_to present → render nit + "Deferred to <ref>" note → APPROVE-neutral
```

New finding field `deferred_to` (string `"<ref>"` or null) flows worker → merge → validator → intersect → body-builder; the merge takes the defender's copy of non-severity/blocking fields, so the defender-set value survives. No new artifact joins `$OUTDIR` — the marker is already inside `diff.txt`.

## 6. Error handling

- **Feature off / no marker** → the defender's marker scan finds nothing (or is skipped when `defer_markers: false`); every finding stays exactly as the workers/intersection produced it. No behavior change, no extra cost.
- **Marker present but irrelevant** (a `woostack-defer` whose reason does not match any finding's gap) → the defender judges coverage and leaves non-matching findings untouched. A marker never blanket-demotes; it demotes only the finding it actually covers.
- **Bad `defer_markers` value** (non-boolean) → `load-config.sh` emits the existing loud `::error file=.woostack/config.json,line=N::` and fails the run (no silent fallback), consistent with every other key.
- **Marker on a security finding / on wrong-in-PR code** → the defender's guards refuse the deferral; the finding stays a normal blocking finding. Deferral can only ever lower an event (blocking→nit), never raise it, so it cannot break the self-PR downgrade or the event-floor.
- **Marker flagged as a comment-smell** → an angle worker that sees the `woostack-defer(...)` comment must NOT raise it as a stray `TODO`/dangling-marker finding. `_header.md` tells every angle the marker is an intentional deferral signal owned by the defender; only the defender acts on it. This prevents double-reporting the marker the feature deliberately introduces.
- **Stale marker** (the implementing increment landed but the marker was not removed) → resolved upstream, not by the review gate: `woostack-execute` removes every match when it implements the increment, and `woostack-status` lists any survivor as an open deferral (§4.2). The review path carries no staleness check.

## 7. Acceptance criteria

- **AC1 — Marker honored (defender → demotion)**
  - happy: a "missing integration X" finding that lands in the same hunk as `// woostack-defer(increment 3): X wired in increment 3` covering X is rendered as a non-blocking nit carrying `Deferred to increment 3`; the review event stays `APPROVE`.
  - error: a `woostack-defer` marker that is **not co-located** with the finding (a different hunk or file), or whose reason does not match it, leaves the finding unchanged (no blanket demotion).
  - edge: a bare `// TODO: wire X later` (no woostack token) never demotes the finding.
- **AC2 — Guards (never-defer set)**
  - happy: a `security`-angle "missing auth check" finding is **not** deferred even when a `woostack-defer` marker sits on the same lines.
  - error: a finding about wrong code *present in this PR* is not deferred even if a marker is nearby.
  - edge: with `review.defer_markers: false`, a marker that would otherwise demote a finding is ignored and the finding stays normal/blocking.
- **AC3 — `defer_markers` config (default on)**
  - happy: default (key absent) honors markers; explicit `true` behaves identically.
  - error: a non-boolean `defer_markers` triggers the loud `::error file=…::` and a non-zero exit from `load-config.sh`.
  - edge: `false` is accepted and emitted to the canonical config; the validator skips the marker scan.
- **AC4 — Classifier forces nit independent of `severity_floor`**
  - happy: a finding with `deferred_to` set becomes `nit: true, blocking: false` under `severity_floor: high`.
  - error: N/A — `classify_floor` is pure over its inputs (no IO failure path).
  - edge: the same finding stays a nit under `severity_floor: low` (where its severity would otherwise be at/above floor); `validator-metrics.json` reports `deferred_count`.
- **AC5 — Plan/execute declare and resolve the marker**
  - happy: a plan whose increment defers integration authors a "drop `woostack-defer(increment N)` marker" step in the deferring increment **and** a paired "remove the marker" step in increment N; both reference the §4.0 token.
  - error: the marker token the plan/execute doctrine names matches the token the validator greps (single source — §4.0); a mismatch is a spec violation, caught by the cross-token presence checks in §8.
  - edge: an increment that defers nothing authors no marker step (the doctrine fires only on an actual deferral).
- **AC6 — Stale-marker resolution & surfacing**
  - happy: when `woostack-execute` implements the increment a marker names, it removes every matching `woostack-defer(increment N)` from the tree (plan-named site plus a belt-and-suspenders tree grep).
  - error: a marker left in the tree (executor skipped removal) is listed by `woostack-status` as an open deferral — visible, not silently ignored.
  - edge: `woostack-status` lists open deferrals **read-only** — it never edits or removes a marker.

## 8. Testing

> Strategy only — harness, test levels, fixtures, CI. Per-behavior cases live in §7.

Shell-based unit tests under `skills/woostack-review/scripts/tests/`, matching the existing `test-*.sh` style and runner (`source assert.sh`, `mktemp -d` OUTDIR, `finish`). The deterministic, IO-shaped pieces get real harnesses:

- `load-config.sh` gets a `defer_markers` accept (bool) / reject (non-bool → loud error + non-zero exit) case alongside the existing config tests.
- `intersect-findings.sh` gets a `deferred_to → nit` case under both `severity_floor: high` and `low`, asserting `nit:true`, `blocking:false`, and `deferred_count` in `validator-metrics.json`.

The LLM-judgment pieces (`validator.md` defender directive; `_header.md` render note; `woostack-plan` and `woostack-execute` marker doctrine) are specified in prompt/skill text and verified by **concrete presence checks** — `grep`/`bash -n` confirming the directive, the guards, the render line, and the *same* `woostack-defer` token on every side (plan emits, execute writes, validator greps). This is the existing prompt-edit verification pattern (no live-LLM test). Because the marker arrives inside the PR's own diff, there is **no fake-`gh` stack harness** to maintain — a direct simplification over the closed design's `WOO_REVIEW_FAKE_STACK_*` hooks.

## 9. Resolved decisions (hardened)

Open questions resolved during the rewrite discussion:

- **Q1 — Marker over fetch.** The deferral signal is carried by an inline `woostack-defer(<ref>)` marker read from the PR's own diff, not by fetching and embedding descendant PR diffs. *Why:* the prior diff-verify design (closed PRs #276–#278) paid N `gh` round-trips + N descendant diffs of context on **every** review of a stacked PR; the marker pays that cost once, upstream, at plan/execute time. *Trade accepted:* review trusts the marker's claim instead of re-verifying it against descendant code; the trust is bounded because the marker is authored by `woostack-execute` under an approved, hardened plan and uses a woostack-specific token a casual comment can't forge by accident.
- **Q2 — Token = `woostack-defer(<ref>): <reason>`**, defined once in §4.0; `<ref>` prefers `increment N` (stable, exists before any later PR) over `#N`. Bare `TODO` is explicitly excluded so ordinary comments can't suppress findings.
- **Q3 — Defender-only honors the marker.** Verified in `intersect-findings.sh`: the adversarial merge builds each kept finding as `dict(df)` (the defender's whole object), overriding only `severity` and `blocking` (Pass 1–3). A defender-set `deferred_to` therefore survives the intersection with no new field whitelisted and no prosecutor changes. The deferral finding is raised by **both** passes (it *is* real for the isolated diff), so it is always matched-and-kept, never an unmatched-defender drop. The defender-only path `cp`s the defender output verbatim, so `deferred_to` survives there trivially.
- **Q4 — `deferred_count` lives in `validator-metrics.json` only**, not the review body summary (mirrors `disagreement_count`). The per-finding `Deferred to <ref>` note is the user-visible signal.
- **Q5 — Resolution is the implementing increment's job.** The increment that fills the gap removes the marker (its plan step says so); review does not police staleness.
- **Q6 — Security & wrong-in-PR-code are never deferred**, regardless of marker — same guard the prior design carried, now the only verification the defender must enforce.
- **Q7 — Marker↔finding match = co-location + reason.** The defender demotes only when a `woostack-defer` marker sits in the same diff hunk (or within a few lines of the flagged code) **and** its reason plausibly covers the finding's gap. Co-location is the primary guard: it stops a stray marker from silencing an unrelated same-file finding, and it makes detection chunk-safe (marker and finding occupy the same diff region, so they land in the same worker/validator chunk). Same-file-only and reason-only matching were both rejected as too easy to mis-fire.
- **Q8 — Stale-marker lifecycle = execute self-clean + status surface (not review).** Beyond the plan's paired remove-step, `woostack-execute` greps the tree and removes every `woostack-defer(increment N)` when it implements increment N, and `woostack-status` lists any surviving marker as an open deferral. The review gate is deliberately left out of staleness (rejected the "review flags contradiction" option) to keep the lean review path free of extra state.

No new questions remain — spec is hardened.
