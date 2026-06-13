---
name: commit-memory-changes
type: spec
status: planning
date: 2026-06-06
branch: feature/commit-memory-changes
links:
---

# Commit memory changes unless gitignored — Design Spec

> **Plan:** [[plans/2026-06-06-commit-memory-changes]]

> Visualize on demand: render this file with [spec-template.html](spec-template.html) for a rich view. Markdown is the source of truth; the HTML is a presentation target only.

> `status:` is the build-loop phase enum: `draft → hardened → approved → planning → executing → in-review → done` (plus the terminal `abandoned`). The build loop authors each transition and `/woostack-status` reads it; the enum and join contracts are defined once in [conventions.md](../../woostack-status/references/conventions.md).

## 1. Problem

`woostack-commit` consistently leaves out `.woostack/memory/` changes. Its step 4
("Stage only session-relevant changes") uses targeted staging plus the agent's judgment
of relevance, and explicitly excludes "unrelated dirty files." Distilled memory notes get
swept into that exclusion: the agent treats `.woostack/memory/*.md` edits as out-of-scope
dirty work and never stages them. Result — durable knowledge distilled during a session
never reaches the PR.

`woostack-execute` compounds the symptom. Its per-increment cadence runs **commit at step 4
but distill at step 7**, so the memory a given increment distills is written to the working
tree *after* that increment's commit. With the relevance filter dropping memory, those
changes then accumulate uncommitted: intermediate increments' memory could be picked up by
the next increment's commit, but the **final** increment's distilled memory has no
subsequent commit and is simply left behind when the stack finishes.

## 2. Goal

`/woostack-commit` always commits non-gitignored `.woostack/memory/` changes as part of the
session, and `woostack-execute` never ends with the final increment's distilled memory left
uncommitted.

## 3. Non-goals

- Not changing how memory is *distilled* (the reject-by-default distillation gate in the
  [memory contract](../../woostack-init/references/memory.md) is untouched).
- Not changing spec/plan staging: `.woostack/specs/` and `.woostack/plans/` are already
  handled by the spec+plan PR and `woostack-commit`'s step 4.5 invariant check.
- Not reordering `woostack-execute`'s per-increment cadence (distill stays at step 7, after
  review — distilling before review would be premature). The fix is a terminal sweep, not a
  reorder.
- Not adding a per-increment dedicated memory commit; memory folds into the normal commit.
- No `git add -f`, no force-staging of gitignored paths.

## 4. Approach

Two coordinated skill-markdown edits. No application code; this repo has no test harness.

**Fix 1 — `woostack-commit` step 4 carve-out.** Add an explicit rule that changes under
`.woostack/memory/` are session work by definition in the woostack loop and are **always
staged unconditionally**, folded into the same commit as the code. They are never classified
as "unrelated dirty files," and there is no relevance check or stop-and-ask for them
(resolved Open Q1: no foreign-session guard — any guard would re-introduce the over-caution
that caused the bug, and committing memory is the desired direction). Mechanism: a
directory-guarded, path-scoped `git add .woostack/memory/`, e.g.
`[ -d .woostack/memory ] && git add .woostack/memory/`. Two properties make this exactly
right:

- Plain (non-`-f`) `git add` honors `.gitignore`, so ignored paths such as
  `.woostack/memory/metrics.json` and `*.local.*` are excluded automatically —
  **"unless gitignored" is satisfied for free**, with no `git check-ignore` step and no `-f`.
- `git add <dir>` stages modifications, additions, **and deletions** within the path (git
  2.0+), so the note removals that distill's dedupe performs are committed too, not just
  additions.

The directory-existence guard is required: a bare `git add .woostack/memory/` against an
absent directory exits non-zero with `fatal: pathspec '.woostack/memory/' did not match any
files`. Guarding makes it a silent no-op in a non-woostack repo.

**Fix 2 — `woostack-execute` memory sweep on handback.** Before `woostack-execute` yields
control back **for any reason** — the clean terminal state *or* a blocking stop
(REQUEST_CHANGES, a blocker, or woostack-debug's architectural stop) — if `.woostack/memory/`
has pending non-ignored changes, run one final `/woostack-commit` on the current increment's
branch to sweep them into that branch's PR (resolved Open Q2: any handback, not only the
clean terminal — a mid-run woostack-debug detour can distill a gotcha before an early stop,
and that memory must not be stranded). Intermediate increments need nothing extra: once Fix 1
lands, increment N's distilled memory is swept by increment N+1's commit; the sweep covers
the *last* committed point, which has no following commit.

Two accepted consequences, both following from folding (Fix 1) without reordering execute:

- **One-increment lag.** Because distill (execute step 7) runs after commit (step 4),
  distilled memory lands in the *next* increment's commit; the final increment's memory lands
  in the Fix 2 sweep. The user chose this over a larger reorder (distilling before review
  would be premature).
- **Sweep is a memory-only commit.** At handback the increment's code is already committed
  (and, inline, reviewed), so the sweep necessarily produces a memory-only commit via
  `/woostack-commit`. This does not contradict the "fold into the same commit" rule — folding
  applies when code and memory are committed together in one invocation; the sweep is the
  trailing case where only memory remains dirty.

## 5. Components & data flow

- **`skills/woostack-commit/SKILL.md` — §4 "Stage only session-relevant changes."** Add the
  `.woostack/memory/` always-stage rule and the `git add .woostack/memory/` mechanism; keep
  the existing exclusions (`.env*`, secrets, generated app files, unrelated dirty hunks)
  intact. The new rule is an exception carved out of "unrelated dirty files," scoped strictly
  to `.woostack/memory/`.
- **`skills/woostack-execute/SKILL.md` — handback points.** Add the memory sweep at every
  point execute yields control: the terminal "reviewed stack" state **and** the "When to stop
  and ask" blocking stops. Phrase it as a single rule ("before handing control back, sweep
  pending non-ignored `.woostack/memory/` via `/woostack-commit`") referenced from both
  places, rather than duplicating mechanism. Cross-reference `woostack-commit`; do not restate
  the staging mechanism.
- **Data flow.** distill (execute §7) writes `.woostack/memory/*.md` + regenerates
  `MEMORY.md` via `build-index.sh` → `git add .woostack/memory/` stages tracked notes +
  index, skips gitignored `metrics.json` → commit folds them into the increment PR; the final
  increment's memory rides the Fix 2 sweep commit.

## 6. Error handling

- **No `.woostack/memory/` directory** (non-woostack repo): the directory-existence guard
  (`[ -d .woostack/memory ] && …`) makes the stage a silent no-op; commit proceeds normally.
  An unguarded `git add` would instead exit non-zero with `fatal: pathspec … did not match`.
- **Only gitignored memory changes dirty** (e.g. just `metrics.json`): `git add` stages
  nothing, no empty memory commit is forced.
- **Nothing to sweep at execute terminal** (memory clean after final distill): skip the
  sweep commit; do not create an empty commit.
- **Gitignored paths**: never force-added; `.gitignore` is the single source of the
  "unless gitignored" boundary.

## 7. Testing

No automated test harness in this repo (skill-markdown change). Manual verification:

- **Commit carve-out**: on a feature branch, dirty a `.woostack/memory/*.md` note and a
  gitignored `metrics.json`; run `/woostack-commit`; confirm the note is staged and committed
  and `metrics.json` is not.
- **No-op safety**: run `/woostack-commit` in a repo with no `.woostack/memory/`; confirm it
  proceeds with no error and no spurious staging.
- **Execute sweep**: run `woostack-execute` to terminal state on a multi-increment plan;
  confirm the final increment's distilled memory lands in a commit on the last branch rather
  than being left dirty.

## 8. Open questions

Resolved during the harden phase (step 3):

- **Foreign-session memory** → *No guard; stage all.* The always-stage rule is unconditional
  (modulo `.gitignore`): every non-ignored `.woostack/memory/` change is staged, no relevance
  check or stop-and-ask. A guard would re-introduce the over-caution that caused the bug, and
  committing memory is the desired direction (it is shared knowledge). Folded into §4 Fix 1.
- **Sweep on non-clean exit** → *Any handback.* The execute sweep fires whenever execute
  yields control — clean terminal **and** blocking stops (REQUEST_CHANGES, blocker,
  woostack-debug architectural stop) — so a mid-run distill is never stranded by an early
  stop. Folded into §4 Fix 2 and §5.

No open questions remain.
