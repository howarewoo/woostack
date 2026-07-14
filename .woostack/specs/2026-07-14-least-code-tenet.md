---
name: least-code-tenet
type: spec
status: approved
date: 2026-07-14
branch: feature/least-code-tenet
links:
---

# Least code, still safe — Design Spec

> Visualize on demand: render this file with [spec-template.html](../../../skills/woostack-build/references/spec-template.html) for a rich view. Markdown is the source of truth; the HTML is a presentation target only.

> `status:` is the build-loop phase enum: `draft → hardened → approved → planning → ready → executing → in-review → done` (plus the terminal `abandoned`). The build loop authors each transition and `/woostack-status` reads it; the enum and join contracts are defined once in [conventions.md](../../../skills/woostack-status/references/conventions.md).

> **Plan:** [[plans/2026-07-14-least-code-tenet]]

## 1. Problem

The repo has no single, canonical statement that skills — and the code they generate — should
write as little code as necessary while still covering edge cases and risks. The principle is
real and already lived, but it is **scattered and one-sided**:

- **Design phase** carries it: `woostack-ideate` has `YAGNI ruthlessly` + `Least code wins`.
- **Generated-code size** carries part of it: `patterns.md §10` ("Code size & comments") covers
  ≤500-line files, why-not-what comments, no magic literals — but not the YAGNI/reuse ladder, the
  read-first discipline, or the safety guard.
- **Enforcement** carries it best: the review `simplify` angle states the full 7-rung ladder and
  the "lazy, not negligent" guard verbatim; the `comments` angle polices comment rot.

The gap: **no canonical tenet**, and the *authoring* skills that actually write code
(`woostack-execute`, `woostack-fix`) don't carry the principle at all — only the reviewer that
grades them afterward does.

**Evidence (three independent past-session corpora, unanimous Strong Support):**

| Corpus | Sessions | FOR | COUNTER |
|---|---|---|---|
| Codex | 873 | 137 | 210 |
| omp | 77 (13,041 msgs) | 48 | 56 |
| Claude | 174 + 897 subagent | strong | strong |

FOR: repeated requests to shrink `AGENTS.md`, keep skills thin, cross-link not duplicate, inline
single-use vars, delete dead logic, reject a complex regex for a substring. COUNTER (why the guard
clause is load-bearing): every corpus recorded a simplify impulse that **removed a real safety
mechanism** and had to be reverted — concurrency guard, gitignore fallback, diff-anchor scoping,
base-aware branch gate, PII scrub, YAML-injection validation, config failover. The recurring
nuance across all three: minimal comments means **why-not-what**, and **deliberate multi-layer
safety redundancy is not DRY-removable**.

## 2. Goal

Codify **one** canonical engineering tenet — "Least code, still safe" — as the repo's named
source of truth, with the full generated-code doctrine in `patterns.md §10`, cross-linked (never
restated) from the authoring skills. Fold in the genuinely additive improvements from
[`DietrichGebert/ponytail`](https://github.com/DietrichGebert/ponytail) (deltas A–F below) that
sharpen how our skills generate code, while keeping woostack's leaner single-source + cross-link
architecture.
A user-facing docs-site concepts page also surfaces the tenet to consumers of the collection.

## 3. Non-goals

- **No always-on hook/plugin injection system.** ponytail injects its ruleset every turn via
  Node lifecycle hooks; we rely on skills reading their own instructions. Out of scope.
- **No multi-agent rule-copy files or a sync checker.** ponytail ships N per-agent copies kept in
  step by `scripts/check-rule-copies.js`. Our "cross-link, do not duplicate" hard constraint is
  deliberately leaner (one source + links); we do not adopt copies.
- **No new commands.** No `/…-debt` ledger or `/…-gain` scoreboard; our memory `gotcha` store
  already captures deferred corners.
- **No weakening of `woostack-tdd`.** ponytail's "one runnable check behind" is weaker than our
  full TDD kernel; we keep ours.
- **No edits to skills that already carry the tenet** (`woostack-tdd`, the `simplify`/`comments`
  review angles, `woostack-audit`) or to the ~18 skills that write no code. Editing them would
  restate the doctrine and violate the very tenet being codified.
- **No blanket rewrite of all 24 skills.** "Update all skills *as necessary*" = only where the
  authoring / generated-code tenet actually lands.

## 4. Approach

A **targeted 6-artifact** change: one canonical statement, one detailed doctrine home, three skill
cross-links, and one user-facing docs-site concepts page. Exact anchors confirmed by read.

**File 1 — `.claude/CLAUDE.md` / `AGENTS.md` (symlinked; edit the real file), Hard constraints.**
Add the canonical tenet as a new hard-constraint bullet — the tight, authoritative statement that
points to `patterns.md §10` for the full ladder and to the `simplify`/`comments` angles for
enforcement. Governs this repo's own authoring + scripts. Draft:

> **Least code, still safe.** Skills — and the code they generate — write as little code as
> necessary. Understand first (read the code the change touches, trace the real flow), *then* take
> the first rung that holds: in-tree reuse → stdlib → native feature → installed dep → one line →
> minimum that works. Deletion over addition, boring over clever — small because it's necessary,
> not golfed. Comments are minimal and explain *why* (hidden constraint, workaround, surprising
> invariant), never *what*. Lazy about the solution, never about reading: the smallest change in
> the wrong place is a second bug. Never shrink code by cutting edge cases or risks — validation,
> error handling, security, accessibility, and data-loss handling stay; keep deliberate
> multi-layer safety redundancy; at equal size pick the edge-case-correct option; behavior-changing
> simplification keeps its regression test; a knowingly-cut corner leaves a `why` comment naming
> its ceiling and upgrade path. Full standard:
> [`patterns.md §10`](skills/woostack-bootstrap/references/patterns.md); enforced by the
> `simplify`/`comments` review angles.

**File 2 — `skills/woostack-bootstrap/references/patterns.md §10` (lines 158–163).** Rename the
§10 heading "Code size & comments" → "Least code & comments" and expand it into the full
generated-code doctrine (the detailed home the tenet points to). Keep the existing four bullets; add:
- **The ladder** (rungs 1–7: YAGNI → in-tree reuse → stdlib → native → installed dep → one line →
  minimum that works), cross-linking the `simplify` angle as the enforcement side rather than
  restating its prose.
- **Delta A — read first.** The ladder runs *after* understanding the problem: read the code the
  change touches and trace the real flow end to end before picking a rung. "Lazy about the
  solution, never about reading; the smallest change in the wrong place is a second bug."
- **Delta B — equal-size tie-breaker.** When two approaches are the same size, pick the
  edge-case-correct one; lazy means less code, not the flimsier algorithm.
- **Delta C — never-cut list** widened to validation, error handling, security, **accessibility**,
  **data-loss handling**; deliberate multi-layer safety redundancy stays; scoped parsing over
  greedy regex; behavior-changing simplification keeps its regression test.
- **Delta D — boring over clever.** Deletion over addition; small because necessary, not golfed.
- **Delta E — deliberate-corner marker.** A knowingly-cut corner with a known ceiling (global
  lock, O(n²) scan, naive heuristic) leaves a `why` comment naming the ceiling + upgrade path, and
  is distilled as a memory `gotcha`.

**File 3 — `skills/woostack-execute/SKILL.md`.** In the **Implement** step (step 2, ~line 103–107)
add one sentence: implement the least code that satisfies the task per `patterns.md §10`
(understand-first, smallest existing solution, why-not-what comments) without dropping edge-case,
error-path, security, or accessibility coverage — the TDD coverage classes already require them.
Add one **Hard constraints** bullet (~after line 240) naming the tenet and cross-linking §10.

**File 4 — `skills/woostack-ideate/SKILL.md`, "Least code wins" (line 117–118).** Extend with the
guard half: YAGNI cuts speculative features, not validation, error handling, security,
accessibility, or safety redundancy; understand the problem before choosing the smallest shape.

**File 5 — `skills/woostack-fix/SKILL.md`, "Proposed Fix" template (line 134) + step 2/Hard
constraints.** Sharpen "minimal, targeted code changes" to include **delta F**: fix the shared
root once (grep callers; one guard at the shared function beats one-per-caller — smaller diff and
correct), without dropping edge-case or safety coverage.

**File 6 — `site/content/docs/concepts/least-code.mdx` (new) + nav wiring.** Add a user-facing
"Core concepts" page presenting the tenet to consumers (Fumadocs MDX: `title` + `description`
frontmatter, `##` sections, links to `/docs/skills/…` and `/docs/concepts/…`). Wire it into the
nav two ways: append `"least-code"` to `site/content/docs/concepts/meta.json`'s `pages` array, and
add a `<Card>` for it to `site/content/docs/concepts/index.mdx`. The page frames the tenet for
readers (what "least code, still safe" means, the ladder, the guard) and links the skills; it does
not restate the full `patterns.md §10` prose. Per-`SKILL.md` reference pages still regenerate at
build; only these authored pages are hand-edited. Confirm the whole site builds with
`pnpm -C site build`.

## 5. Components & data flow

Two audiences, one doctrine, wired by cross-link:

```
AGENTS.md  "Least code, still safe"  (canonical, tight)   ← repo authors + the collection's scripts
    │  points to
    ▼
patterns.md §10  (full ladder + read-first + tie-breaker + never-cut + marker + anti-golf)   ← generated code
    ▲  cross-linked by (authoring side)              │  cross-links (enforcement side)
    │                                                ▼
woostack-execute (Implement)                   review angles: simplify + comments
woostack-ideate ("Least code wins")            woostack-audit (already aligned — untouched)
woostack-fix    (Proposed Fix)                 woostack-tdd (already aligned — untouched)
```

The canonical statement lives **once** (AGENTS.md); the detailed standard lives **once**
(patterns.md §10); every other touchpoint is a one-line pointer. No prose is duplicated.

## 6. Error handling

Failure modes for a docs/skills change and how each is prevented or caught:

- **Restating instead of linking** (would violate the tenet + the "cross-link, do not duplicate"
  hard constraint). Prevention: canonical text appears in exactly two homes (AGENTS.md tight +
  §10 full); the other three files carry pointers only. Verified in §7 AC5.
- **Broken cross-links** (wrong relative depth from AGENTS.md at repo root vs. skills). Verified in
  §7 AC6 by resolving each new link target on disk.
- **Docs-site drift.** File 6 adds one authored page plus two nav wirings; no existing authored
  page is rewritten. `pnpm -C site build` must pass and the new page must be nav-wired. Verified in §7 AC7.
- **Over-editing** (touching already-aligned skills). Prevention: non-goals list them explicitly;
  AC scans confirm they are unchanged.
- **Angle pre-flight (spec lens).** security → the tenet *protects* security/validation checks
  (the guard is the point); edge/error → the guard clause is entirely about edge/error coverage,
  captured as ACs; observability / api / database → N/A for a documentation tenet.

## 7. Acceptance criteria

Each AC is a testable behavior → ≥1 plan task. This is a docs/skills repo with no test runner, so
each "test" is a concrete **verification command** with exact expected output (per the
`woostack-tdd` no-runner substitution).

- **AC1 — Canonical tenet exists in AGENTS.md.**
  - happy: `grep -c "Least code, still safe" AGENTS.md` → `≥1`; the bullet names the never-cut
    list (validation, error handling, security, accessibility, data-loss) and links `patterns.md §10`.
  - error: the bullet without the `patterns.md §10` link fails review (no canonical→detail path).
  - edge: `.claude/CLAUDE.md` resolves to the same content (symlink) — edit the real file, not a copy.
- **AC2 — patterns.md §10 carries the full doctrine.**
  - happy: §10 contains the 7-rung ladder, the read-first discipline (delta A), the equal-size
    tie-breaker (delta B), the widened never-cut list (delta C), boring-over-clever/anti-golf
    (delta D), and the deliberate-corner marker (delta E), and cross-links the `simplify` angle.
  - error: a rung list that omits "understand first" (delta A) is incomplete — read-first is the
    load-bearing anti-regression piece.
  - edge: existing four bullets (≤500 lines, JSDoc, why-not-what, no magic literals) preserved, not
    replaced.
- **AC3 — Authoring skills cross-link the doctrine.**
  - happy: `woostack-execute` Implement step + a Hard-constraints bullet reference `patterns.md §10`;
    `woostack-ideate` "Least code wins" carries the guard half; `woostack-fix` Proposed Fix carries
    delta F (shared-root fix).
  - error: a reference that restates the ladder instead of linking fails (duplication).
  - edge: each link uses the correct relative path from its file's location.
- **AC4 — Already-aligned skills untouched.**
  - happy: `git diff --name-only` against base lists only the 6 target files plus the two docs-site
    nav wirings (`concepts/meta.json`, `concepts/index.mdx`) and the spec/plan under `.woostack/`.
  - error: any diff to `woostack-tdd`, the review angles, or `woostack-audit` is out of scope.
  - edge: N/A.
- **AC5 — No prose duplication.**
  - happy: the full tenet paragraph appears in ≤2 files (AGENTS.md tight, §10 full); the ladder
    prose is not copied into execute/ideate/fix.
  - error: the same multi-sentence block in ≥3 files.
  - edge: short shared phrases (e.g. "least code") recurring is fine; whole-paragraph copies are not.
- **AC6 — All new cross-links resolve.**
  - happy: every new link target path exists on disk (checked from the linking file's directory).
  - error: a 404 relative path.
  - edge: links from repo-root AGENTS.md vs. from `skills/*/SKILL.md` use different depths.
- **AC7 — Docs-site concepts page added and builds.**
  - happy: `site/content/docs/concepts/least-code.mdx` exists with `title`/`description`
    frontmatter; `"least-code"` is in `concepts/meta.json` `pages`; `concepts/index.mdx` has its
    `<Card>`; `pnpm -C site build` exits 0.
  - error: page present but unwired in `meta.json` (missing from nav) → fails.
  - edge: the page links `/docs/skills/…` and `/docs/concepts/…`, not repo-relative paths.

## 8. Testing

Strategy: no test runner in this repo — verification is by `grep`/link-resolution/`git diff` scans
plus a required `pnpm -C site build` (File 6 adds an authored page). Per-behavior checks live in §7. The plan will make
each AC a checkbox with its exact command and expected output. Manual read-through of each anchor
confirms wording matches the approved design.

## 9. Resolved decisions (harden)

- **patterns.md §10 is the generated-code home** — confirmed. `woostack-tdd` already cross-links
  `patterns.md §7` from outside bootstrap and its description codifies "link, don't restate," so
  §10 is the de-facto cross-skill code standard; a new shared reference would violate least-code.
- **§10 heading broadens** "Code size & comments" → "Least code & comments" to match the expanded
  content (folded into §4 File 2).
- **Docs-site concepts page ADDED** — at the spec-approval gate the user chose to add a user-facing
  "Least code, still safe" page (File 6). It joins the existing concept pages
  (`concepts/meta.json` + an `index.mdx` card) and links the skills; it does not restate
  `patterns.md §10`. The scan still holds: no *existing* authored page contradicted the tenet, so
  none is rewritten — only the new page and its two nav wirings are added.
- **Angle pre-flight (spec lens) walks clean:** security (tenet protects checks; no new threat
  surface), bugs/edge-error (guard clause = the ACs), tests (AC1–7 each carry a verification
  command), deps (none — non-goal), infra (only the AC7 `pnpm -C site build` guard).
  observability, api, database, i18n → N/A for a documentation tenet.
