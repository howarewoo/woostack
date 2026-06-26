---
name: woostack-audit
type: spec
status: approved
date: 2026-06-25
branch: feature/woostack-audit
links:
---

# woostack-audit — Standing-code multi-angle audit — Design Spec

> Visualize on demand: render this file with [spec-template.html](spec-template.html) for a rich view. Markdown is the source of truth; the HTML is a presentation target only.

> `status:` is the build-loop phase enum: `draft → hardened → approved → planning → ready → executing → in-review → done` (plus the terminal `abandoned`). The build loop authors each transition and `/woostack-status` reads it; the enum and join contracts are defined once in [conventions.md](../../woostack-status/references/conventions.md).

> **Plan:** [[plans/2026-06-25-woostack-audit]]

## 1. Problem

`woostack-review` gates a *change*: it is diff-scoped, runs in a PR/CI, and posts a GitHub
review carrying a blocking event. There is **no woostack command to audit standing code** — a
file, directory, module, or whole repo *at rest*, on demand, outside any PR.

The two focus areas named for this work have no first-class home today:

- **Code simplification** (ponytail's whole-repo over-engineering audit → a "delete-list").
- **Production readiness** (impeccable's graded technical-quality / hardening audit).

`woostack-review`'s angles are all *diff-relative* ("only flag complexity **this diff**
introduced") and never run outside a PR, so a developer who wants "audit this module for
over-engineering and production-readiness" has nothing to invoke.

## 2. Goal

A new public skill **`woostack-audit`** that audits an **explicit standing-code target** from
multiple angles — focused on **simplification + production readiness** — and emits a **ranked,
report-only** findings document that hands off to `woostack-fix` / `woostack-build`.

Built by **repointing the `woostack-review` engine** at standing code via an **all-added
synthetic diff**, for maximal reuse of review's swarm, adversarial validators, severity model,
chunking, and cross-PR memory. Audit owns only a thin diff-synthesis front-end and a
report-renderer back-end.

## 3. Non-goals

- **Not a gate.** No PR event (`APPROVE`/`REQUEST_CHANGES`), no CI integration, no GitHub
  posting.
- **No auto-fix, no merge.** Report only — it points at `/woostack-fix` and `/woostack-build`,
  exactly as review points at `woostack-debug`.
- **No diff/PR machinery.** No incremental SHA marker, no prior-thread event floor, no
  defer-markers — those are change-scoped concepts.
- **Not a replacement for `woostack-review`.** They are complementary: review audits a
  *change*, audit audits code *at rest*.
- **No new severity scale in v1.** Reuse review's `HIGH`/`MEDIUM`/`LOW`; do not introduce a
  parallel P0–P3 scale.

## 4. Approach

**Repoint the review engine.** Audit owns a thin Stage-1-equivalent that synthesizes an
all-added diff from the target, reuses review Stages 2–4 verbatim, then renders a report.

**Synthetic diff (the key trick).** For each in-scope file under the target, run
`git diff --no-index /dev/null <file>` → a `new file` `diff --git` section whose **every line is
a `+` add on the diff's RIGHT side**. Concatenate the sections into `diff.txt`. This satisfies
two review invariants for free:

1. **Anchors resolve.** Every line is anchorable on the diff's RIGHT side, so
   `resolve-diff-line.sh` and the whole line-anchored finding pipeline work unchanged.
2. **Diff-relative angles become standing-code audits.** Each angle's "introduced by this diff"
   clause now means "the whole file is in scope" — so `bugs`, `observability`, `types`, etc.
   audit code at rest with **no edit to their prompts**.

**Pipeline:**

```
build-target-diff.sh  (NEW)  → diff.txt (+ chunks via chunk-diff.sh) + meta.json
                               + memory.md (recall.sh) + rules.md (project-rule discovery)
detect-angles.sh      (REUSED; audit catalog: simplify + production-readiness always-on)
run-bounded-swarm.sh → verify-receipts.sh   (REUSED unchanged)
merge-findings → prosecutor → defender → intersect-findings   (REUSED unchanged)
render-report.sh      (NEW)  → .woostack/audits/<date>-<slug>.md + terminal summary
```

**Dropped vs review:** PR fetch, incremental marker, prior-thread event floor, GitHub post,
defer markers, the PR event.

**Command:** `/woostack-audit <target> [--fast|--deep] [--simplify|--prod-only]`

- `target` is **required** — no bare default (avoids a whole-repo token bomb). `--all` is the
  sanctioned whole-repo opt-in (audits repo root).
- Tier flags reuse review's `FORCE_TIER`. Lens flags narrow the angle set (see §5 / AC3).

## 5. Components & data flow

**Two new angles** (lockstep ×2, per `[[review-add-angle-sites]]`) — added to review's **shared**
`prompts/angles/`, and **active for `woostack-review` too** (not default-off): they fire on a
review diff under the same condition `architecture`/`comments` do (the diff touches
general-purpose source files), giving every source-touching PR a ponytail-style + prod-readiness
pass. For **audit** they are **always-on**. One shared catalog, one lockstep location.

- **`simplify`** — the ponytail ladder: *does this need to exist (YAGNI) → already in the
  codebase (reuse) → stdlib → native platform feature → installed dep → one line → the minimum
  that works*. Output is a **delete-list**. Hunts: dead code, **cross-file unused exports** (the
  worker scans the tree for references and flags only zero-reference non-definition symbols — the
  whole-tree capability `architecture`'s per-file diff cannot see), whole-tree duplication,
  thin/identity abstractions, speculative generality. **"Lazy, not negligent" carve-out:** never
  recommends cutting validation, error handling, security, or accessibility.
  - **Scope-split with `architecture`** (precedent: `types.md` defers to `react` when active):
    when `architecture` is also active — i.e. a `woostack-review` diff — `simplify` **defers
    within-change structural-shape** findings (nesting, layering, spaghetti, naming) to it and
    owns only **existence/YAGNI, cross-file dead code, and duplication**. When `architecture` is
    absent — i.e. an **audit** — `simplify` owns the full simplification surface. No double-report
    in either mode.
- **`production-readiness`** — the resilience/operability posture **no existing angle owns**:
  missing timeouts, no retry/backoff, non-idempotent mutations, no graceful degradation,
  unbounded resource/concurrency, config & secret hygiene, missing health/readiness probes,
  failure isolation. **Scope-split** clauses defer signal-quality → `observability`, threats →
  `security`, correctness → `bugs`, so nothing double-reports.

**Audit angle set (on the synthetic diff):**

- **Always-on:** `simplify`, `production-readiness`, `bugs`, `security`.
- **Auto-detected, reused as-is:** `observability`, `types`, `deps`, `tests`, `conventions`
  (when `rules.md` present), + conditional `api`/`database`/`infra`/`react`/`i18n`/`docs`/
  `design`/`seo`/`aeo` on target-path match.
- **`architecture`:** skipped by default in audit — `simplify` owns the full simplification
  surface when `architecture` is absent (the scope-split above). On `woostack-review` diffs both
  run and `simplify` defers structural-shape to `architecture`.

**Reused unchanged:** `run-bounded-swarm.sh`, `verify-receipts.sh`, `merge-findings.sh`,
`validator-prosecutor.md`, `validator.md`, `intersect-findings.sh`, `chunk-diff.sh`,
`resolve-model.sh`, `resolve-outdir.sh`, `recall.sh`, the `_header.md` finding schema. Audit
reaches these by setting `WOO_REVIEW_ACTION_PATH` to the installed `woostack-review` skill dir
and calling its scripts — an **intra-collection dependency** (both skills ship together, like
`woostack-execute` → `woostack-tdd`), not an external one.

**New assets:** `skills/woostack-audit/SKILL.md`, `scripts/build-target-diff.sh`,
`scripts/render-report.sh`, a thin `audit` config loader, and the 2 angle prompts (home TBD —
§9 Q2).

**Bins:** audit `requires` `jq`, `node`, `git` — and **not `gh`** (it never touches GitHub), a
genuine simplification over review's required-bins set. `rg` is a `recommends`, not a require
(grep fallback per §6).

**Config:** a **sibling `audit` block** in `.woostack/config.json` (review's loader ignores
non-`review` keys → no collision). Keys mirror review: `angles.force`/`skip`, `ignore`,
`models`, `severity_floor`, `chunking.max_loc`, `report_dir`.

**Output:** report-only. `HIGH`/`MEDIUM`/`LOW` grouped, then by angle, with `file:line` anchors;
each finding ends with a suggested next step (`/woostack-fix` for small, `/woostack-build` for
large). Written to `.woostack/audits/YYYY-MM-DD-<slug>.md` plus a terminal summary. The report is
**git-tracked** — it joins `woostack-dream`'s decision corpus (specs/plans/fixes/overnight) and
`woostack-doctor` learns the `audits/` dir; `.woostack/.gitignore` must **not** exclude `audits/`.

**Angle lockstep (×2), now review-active.** Because the angles run for review too, the ×2
wiring per `[[review-add-angle-sites]]` spans both modes: `detect-angles.sh` (review-conditional
trigger **and** an audit-always-on path), `load-config.sh` `VALID_ANGLES`, `_header.md` (count
word + catalog row + footer whitelist + schema), the review `SKILL.md` Detect-Angles list, the
per-provider tier tables (`anthropic.md`/`openai.md`/`google.md`/`opencode.md` — both new angles
are `tier: standard`), and a committed gating test per angle.

**Command surface:** this is the **19th public skill** → lockstep bookkeeping (AGENTS.md count
line / public list / file-map / Mode B, README, `using-woostack` routing, CONTRIBUTING, bootstrap
`development.md`, site authored pages). **Resolved (harden):** this surface wiring lands as a
**stacked follow-up PR** per `[[woostack-review-is-not-stack-aware-224]]`, keeping the skill+angle
PRs reviewable.

## 6. Error handling

- **Target path missing/empty** → clear actionable error, non-zero exit; no `diff.txt` written
  (enforces the explicit-target requirement).
- **`git diff --no-index` exit code 1** means "files differ" (always true vs `/dev/null`) — must
  be treated as success, not failure.
- **Target with only binary / lockfile / generated / gitignored files** → no in-scope files →
  report "no auditable files" and exit **clean (0)**.
- **Huge target** → `build-target-diff.sh` applies the **same section-aware cap** review's
  `prefetch.sh` applies (`WOO_REVIEW_DIFF_CAP_BYTES`, default 300KB, whole-section ranking) and
  the same `chunk-diff.sh` chunking (`chunking.max_loc`, default 4000) — audit owns Stage-1 so it
  must replicate this, not inherit it. Dropped sections are listed and a token-budget warning is
  emitted (parity with review's `diff-dropped.txt`).
- **Swarm worker missing receipt** → reuse `verify-receipts.sh` hard-fail (no false-clean
  report).
- **Validator pass missing** → one retry, else defender-only + `degraded: true` surfaced in the
  report header (reuse review behavior).
- **No `.woostack/memory` or `recall.sh`** → skip memory context (no-op), proceed.
- **Cross-file reference scan** for `simplify` uses `rg` when present, else falls back to
  `git grep` / `grep -rn` (always available) — never a hard dependency; if every path fails it
  degrades to within-file simplify and notes the limitation in the report.
- **Secrets/PII in audited code.** The report may quote source lines that contain secrets or PII
  the audit found at rest. The report is a **local file only** — never auto-published, never sent
  to GitHub or any external service — so this is surfacing, not leaking. (The `security` angle
  still flags the hardcoded-secret itself as a finding.)

## 7. Acceptance criteria

> **Angle pre-flight.** Walked the spec lens of `skills/woostack-harden/references/angle-preflight.md`:
> security (no GitHub/secret exposure — audit is local, read-only), observability (degraded/no-receipt
> states surfaced, never silent), api/database (N/A — no service surface), edge/error (empty target,
> binary-only target, missing `rg`, validator degradation) captured below and in §6.

- **AC1 — Synthetic all-added diff from a target**
  - happy: given a dir of N text files, `build-target-diff.sh` writes `diff.txt` with one
    `new file` `diff --git` section per in-scope file (all `+` lines) and a `meta.json` listing
    those files; a sampled line resolves non-null via `resolve-diff-line.sh`.
  - error: target path does not exist → non-zero exit + actionable message; no `diff.txt`.
  - edge: target with only binary/lockfile/gitignored files → empty `diff.txt` → "no auditable
    files", exit 0.
- **AC2 — Explicit-target requirement**
  - happy: `/woostack-audit src/foo` audits that path.
  - error: `/woostack-audit` with no target → error asking for a path, non-zero exit, **runs no
    swarm**.
  - edge: `--all` (no target) → audits repo root (the sanctioned whole-repo opt-in).
- **AC3 — Audit angle catalog**
  - happy: `detect-angles` for audit yields at least `simplify`, `production-readiness`, `bugs`,
    `security`; conditional angles add on path match.
  - error: an angle worker emits invalid JSON → reset to `[]` after one retry (reuse swarm
    guard); run continues.
  - edge: `--simplify` → only `simplify` + the always-on safety floor (`bugs`, `security`);
    `--prod-only` → only `production-readiness` + the same safety floor (see §9 Q4).
- **AC4 — `simplify` finds over-engineering incl. cross-file dead export**
  - happy: an exported symbol referenced nowhere in the tree → flagged removable (delete-list)
    with `rg` zero-reference evidence.
  - error: an exported symbol that **is** referenced elsewhere → **not** flagged (no false
    delete).
  - edge: validation/error-handling/security/a11y code → **never** recommended for removal
    (lazy-not-negligent carve-out).
- **AC5 — `production-readiness` finds resilience gaps without double-reporting**
  - happy: an external call with no timeout/retry → flagged by `production-readiness`.
  - error: a swallowed-error / missing-log issue → owned by `observability`, **not**
    double-reported by `production-readiness` (scope-split).
  - edge: a target with no I/O or external calls → `production-readiness` yields `[]` cleanly.
- **AC6 — Report-only output, never a gate or post**
  - happy: run produces `.woostack/audits/<date>-<slug>.md` grouped by severity with `file:line`
    anchors + next-step suggestions; terminal summary printed.
  - error: **no** GitHub API call is ever made and **no** PR/labels mutated on any audit path.
  - edge: zero findings → report states "clean", exit 0, still report-only.
- **AC7 — Adversarial validation + severity reused**
  - happy: raw findings pass prosecutor + defender + intersect; final set is the intersection;
    `HIGH`/`MEDIUM`/`LOW` preserved.
  - error: a validator pass missing → one retry, else defender-only + `degraded: true` surfaced
    in the report header.
  - edge: `audit.severity_floor` orders/thresholds the report; nits are surfaced, not dropped
    (reuse).
- **AC8 — Config sibling-block isolation**
  - happy: an `audit` block tunes audit while a sibling `review` block in the same file is
    untouched, and vice-versa.
  - error: invalid `audit` JSON / unknown `audit` key → loud error (mirror review-loader
    strictness).
  - edge: no config → audit defaults (explicit target, default `severity_floor`,
    `simplify`+`production-readiness` on).
- **AC9 — Shared angles active on review diffs, scope-split with `architecture`**
  - happy: a `woostack-review` diff touching general-purpose source files makes `detect-angles`
    include `simplify` + `production-readiness`; a docs-only diff does not trigger them.
  - error: an over-engineering issue both `architecture` and `simplify` could claim on a review
    diff is reported **once** — `simplify` defers structural-shape to `architecture` (no
    double-report).
  - edge: in audit mode (`architecture` absent), `simplify` owns the full simplification surface
    including structural-shape.

## 8. Testing

> Strategy only — harness, test levels, fixtures, CI. Per-behavior cases live in §7.

Shell-level unit tests mirroring `skills/woostack-review/scripts/tests/`:

- `build-target-diff.sh` — synthetic-diff shape (one `new file` section/file, all `+`),
  ignore/binary/lockfile skip, empty-target clean exit, `git diff --no-index` exit-1 handling.
- `render-report.sh` — severity/angle grouping, anchors, **no-GitHub** assertion, clean-state
  report.
- `detect-angles` dual path — `simplify`+`production-readiness` always-on for audit **and**
  review-conditional (fire on a source-touching diff, silent on docs-only); lens-flag narrowing.
- audit config loader — isolation from the `review` block; strictness on bad keys.

Angle-prompt behavior (`simplify` cross-file delete-list; `simplify`↔`architecture` scope-split
on review diffs; `production-readiness` resilience scope-split) verified via small fixture
targets fed through the swarm with a pinned `fast` model, asserting the new angles fire and do
not double-report. Each new angle ships a **committed gating test**
per the `[[review-add-angle-sites]]` convention; the lockstep wiring is verified by the
doctor/test that enumerates angle sites. This repo has **no CI for its own push/PR events** (per
AGENTS.md) — tests are runnable shell scripts.

## 9. Open questions

1. **`architecture` in audit** — ✅ **Resolved (harden):** skip in v1 — `simplify` supersedes it
   for standing code; revisit only if structural-shape findings on audited-but-unchanged code
   prove valuable.
2. **New-angle home** — ✅ **Resolved (harden):** add `simplify`+`production-readiness` to
   review's **shared** `prompts/angles/`, **active for `woostack-review` too** (fire on
   source-touching diffs like `architecture`/`comments`), always-on for audit. Overlap with
   `architecture` handled by the §5 scope-split (`simplify` defers structural-shape to
   `architecture` when it is active).
3. **`.woostack/audits/` tracking** — ✅ **Resolved (harden):** git-tracked; joins
   `woostack-dream`'s decision corpus and `woostack-doctor`'s awareness; `.woostack/.gitignore`
   must not exclude `audits/`.
4. **Lens-flag semantics** — ✅ **Resolved (harden):** `--simplify`/`--prod-only` keep
   `bugs`+`security` always-on as a safety floor (cheap; matches review's non-skippable angles).
5. **Command-surface wiring** — ✅ **Resolved (harden):** stacked follow-up PR per
   `[[woostack-review-is-not-stack-aware-224]]`.
