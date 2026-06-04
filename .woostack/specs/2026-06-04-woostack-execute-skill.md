---
name: woostack-execute-skill
type: spec
status: ready
date: 2026-06-04
branch: feature/woostack-execute
links:
  - "[[2026-06-03-woostack-ideate-skill]]"
  - "[[2026-06-04-woostack-harden-skill]]"
---

# woostack-execute: a woostack-native plan-execution command — Design Spec

> Visualize on demand: render this file with [spec-template.html](../../skills/woostack-build/references/spec-template.html) for a rich view, or hand it to `woostack-visualize` (audience `engineer`). Markdown is the source of truth; the HTML is a presentation target only.

## 1. Problem

`woostack-build` step 6 delegates execution to the external `superpowers:executing-plans`
skill. That skill is the last remaining external dependency in the flagship build loop after
[`woostack-ideate`](../../skills/woostack-ideate/SKILL.md) replaced `superpowers:brainstorming`
and [`woostack-harden`](../../skills/woostack-harden/SKILL.md) replaced `grill-me`. It is a poor
fit for the woostack loop in three ways:

1. **External dependency for a core loop step.** The execute phase must be detected in the
   preflight, offered for inline install, and degraded when absent — friction for what should
   be a first-party phase.
2. **Off-the-shelf, not woostack-shaped.** `superpowers:executing-plans` loads a plan, reviews
   it, runs every task, then hands to `finishing-a-development-branch`. It knows nothing about
   woostack's conventions: markdown plans under `.woostack/plans/`, PR-sized increments,
   committing through `woostack-commit`, reviewing through `woostack-review`, Graphite stacks,
   or "never merge." All of that lives in `woostack-build`'s prose around the delegation rather
   than in the execution engine itself.
3. **No PR cadence.** The woostack principle is **one plan per spec, multiple PRs per plan** —
   each PR-sized increment committed and reviewed before the next. `superpowers:executing-plans`
   runs the whole plan as one development branch and finishes once; it has no notion of
   per-increment commit + review.

We want to own the execution behavior so the build loop's execute phase fits woostack
conventions and the PR cadence is part of the engine, not narration around it.

## 2. Goal

Ship `skills/woostack-execute/SKILL.md`: a woostack command that takes one approved plan
(**supplied as a required argument**) and drives it to implementation as a sequence of
**PR-sized, stacked increments**. For each increment it implements the tasks (TDD), **ticks the
plan's checkboxes in place**, commits via
[`woostack-commit`](../../skills/woostack-commit/SKILL.md) on a fresh Graphite-stacked feature
branch, runs [`woostack-review`](../../skills/woostack-review/SKILL.md)` --fast` on the
resulting PR, **distills the increment's durable learnings** into `.woostack/memory/` per the
[memory contract](../../skills/woostack-init/references/memory.md), and **pauses only when the
review requests changes** — otherwise it continues to the next increment. It never merges.
Rewire `woostack-build` step 6 (and its preflight) to use it, **folding build's distill step
(step 7) into execute**. Keep the parts of `superpowers:executing-plans` that earn their
place — load the plan, review it critically, follow steps exactly, run verifications, stop when
blocked — and add the woostack PR cadence it lacks.

This is the same internalization move `woostack-ideate` and `woostack-harden` made on the
phases above it, with one deliberate difference settled in ideate: **`woostack-execute` ships
as a public command** (the ninth), not an internal sub-skill, because it is directly useful to
invoke by name on an existing plan and it actively mutates git/PR state rather than being a
pure conversational phase engine.

## 3. Non-goals

- **Does not merge.** Execution ends with reviewed PRs on stacked branches. Merging is always
  a separate human action. No force-push.
- **Adds no approval gate.** `woostack-build` keeps its two HARD GATES (design approval, spec
  approval) upstream. `woostack-execute` inherits gates, adds none. The per-increment
  "pause on REQUEST_CHANGES" is a blocker stop, not an approval gate — it halts on a failing
  review, it does not solicit a yes to proceed when the review is clean.
- **Does not replace `superpowers:writing-plans`.** Planning stays external for now; only the
  execute phase is internalized. The preflight keeps `writing-plans`.
- **Does not own spec/plan authoring.** It consumes a plan that already exists under
  `.woostack/plans/`; it does not write specs or (re)write plans, beyond ticking checkboxes and
  the standard amend-while-implementing a plan invites.
- **No auto-address of review findings.** When `woostack-review --fast` requests changes,
  execute surfaces the findings and stops; it does not silently chain `woostack-address-comments`.
- **No rewrite of history.** Historical `.woostack/specs/` and `.woostack/plans/` references to
  `superpowers:executing-plans` are records of past work and are left as-is.

## 4. Approach

Author one self-contained `SKILL.md` (plus a `references/` doc only if the loop body grows past
what fits cleanly inline). It mirrors `superpowers:executing-plans`' proven core and adds the
woostack PR cadence, parallel to how `woostack-harden` mirrored `grill-me` but added
amend-in-place + hand-back.

- **Frontmatter `description`** scoped so it is recognized as `woostack-build`'s execute phase
  and as a standalone "execute / implement this plan" trigger, and routed by `using-woostack` —
  broad enough to be invocable by name, narrow enough not to shadow unrelated skills.
- **Commands**:
  - `/woostack-execute <plan-path>` — execute the named plan file. **The plan path is a
    required argument.**
  - `/woostack-execute` with no argument — do **not** guess "the current plan." Ask the user
    which plan to execute (or list `.woostack/plans/` candidates) and stop until one is named.
    When `woostack-build` invokes execute it always passes the plan path it wrote in step 4, so
    this no-arg path is the standalone-misuse guard, not a routine resolution.
- **Core execution loop** (kept from `superpowers:executing-plans`): load the plan; review it
  critically and raise concerns before starting; follow each step exactly; run the verifications
  the plan specifies; stop and ask when blocked (missing dep, repeated verification failure,
  unclear instruction) rather than guessing. Never start implementation on `main`/`staging`/etc.
- **PR-sized increments** (new): the plan is decomposed into independently shippable increments
  (≤500 LOC soft target). When invoked by `woostack-build`, decomposition was already done in
  build step 5; when invoked standalone, `woostack-execute` performs the same decomposition,
  flagging any slice that can't reasonably stay under the target and proposing a split.
- **Per-increment cadence** (new), run for each increment in order:
  1. Implement the increment's tasks with TDD (recommend `superpowers:test-driven-development`
     and, where the host supports subagents, `superpowers:subagent-driven-development` — as
     enhancements, not hard dependencies).
  2. **Tick the plan checkboxes in place** — edit the markdown plan, `[ ]` → `[x]`, as each
     task/increment completes, so the plan file is the live progress record.
  3. **Commit** via `woostack-commit` on a fresh Graphite-stacked feature branch (`gt create`),
     one branch + PR per increment — this is the "multiple PRs per plan" shape.
  4. **Review** via `woostack-review --fast` on the resulting PR.
  5. **Gate on the result:** if the review is REQUEST_CHANGES (a blocking finding), stop and
     surface the findings — the user decides (typically via `woostack-address-comments`). If the
     review is clean / non-blocking, continue.
  6. **Distill** the increment's durable, reusable learnings into `.woostack/memory/` per the
     [memory contract](../../skills/woostack-init/references/memory.md) — one fact per file,
     `type` one of `pattern|decision|gotcha|convention`, narrowest `scope` glob, `source` the
     spec/plan path. Apply the **reject-by-default distillation gate** (memory contract §7):
     dedupe against `.woostack/memory/MEMORY.md` first, reject trivia/source-less/near-duplicate
     notes, stamp `updated:`. Then run `woostack-init`'s `build-index.sh` and `doctor.sh`; fix
     any error. When the store does not exist, skip (or offer `/woostack-init` first). This is a
     work step, not a gate. Then continue to the next increment.
- **Terminal state** (new): stop when every increment is implemented, checked off, committed,
  reviewed, and distilled — leaving a Graphite stack of reviewed PRs. Report the branches/PRs
  and their review verdicts. Never merge.
- **Gate boundary** (new): an explicit statement that the skill owns no approval gate, does not
  merge, and does not auto-address findings — preserving `woostack-build`'s "inherit gates, add
  none." (Per-increment commit, review, and distill are work steps; the pause on
  REQUEST_CHANGES is a blocker stop, not an approval gate.)

### Wiring `woostack-build`

- **Dependency preflight**: drop `superpowers:executing-plans` (and its place in the
  `pnpx skills add obra/superpowers` install offer) from the external-skill list.
  `woostack-execute` ships in the same collection, so it is a first-party command, not an
  external install. Keep `superpowers:writing-plans` in the preflight.
- **Step 6 (Execute)**: invoke `woostack-execute` instead of `superpowers:executing-plans` /
  `superpowers:subagent-driven-development`. Because `woostack-execute` now owns the
  per-increment commit + review + distill cadence, reconcile the surrounding steps:
  - **Step 5 (Decompose)** still produces the increment breakdown in the plan; it feeds
    `woostack-execute`.
  - **Step 7 (Distill memory)** is **removed from build** and folded into `woostack-execute`'s
    per-increment loop. Execute now owns distillation (so a standalone `/woostack-execute` also
    distills), and build's step 7 prose collapses into the step 6 delegation.
  - **Step 8 (Offer the PR)** is superseded for the execute path: `woostack-execute` opens a PR
    per increment via `woostack-commit` as part of the loop, so build no longer "asks whether to
    open a PR" after a single increment. Build ends on the reviewed stack. Re-word step 8 to
    reflect that execute owns PR creation and distill, and that build still never merges.
- **Overview diagram + `description`**: replace `executing-plans` with `execute`; the execute
  phase is now woostack's own (writing-plans still superpowers).

## 5. Components & data flow

Edit set (decomposed into PR-sized increments in the plan):

| File | Change |
|---|---|
| `skills/woostack-execute/SKILL.md` | **NEW** — the skill (single file, no `references/` split; the distill step *references* the memory contract rather than duplicating it, keeping size in line with ideate/harden): scoped `description`, required `/woostack-execute <plan-path>` command, core execution loop, PR-sized increments, per-increment implement→tick→commit→review→gate→distill cadence, terminal state, gate boundary, hard constraints. |
| `skills/woostack-build/SKILL.md` | Preflight: drop `executing-plans` bullet from the external list. Overview diagram: `executing-plans` → `execute`. Step 6: invoke `woostack-execute`. Step 5: unchanged (feeds execute). **Step 7 (distill): removed — folded into execute.** Step 8: reword to "build ends on the reviewed stack" (execute owns PR creation + distill; build never merges). `description` frontmatter: execute is now woostack's own (writing-plans still superpowers). |
| `skills/using-woostack/SKILL.md` | **Add a routing row** to the Command Routing table for `/woostack-execute <plan-path>` → `woostack-execute` (public command, unlike ideate/harden). |
| `.claude/CLAUDE.md` (= `AGENTS.md`) | Line 16 "eight skills" → **nine**, add `woostack-execute` to the public-skill list. Line 31 "eight-skill command surface" → nine. Line 75 "ten `SKILL.md` files (eight public + two internal)" → **eleven (nine public + two internal)**. Add `woostack-execute` to the Quick file map. Internal sub-skill list stays two (`woostack-ideate`, `woostack-harden`). Protect `woostack-execute` from deletion like the other shipped skills. |
| `README.md` | Line 29: "eight skills" → **nine**, add `woostack-execute` to the public list; **fix the stale internal-sub-skill mention** ("also installs `woostack-ideate`" → installs `woostack-ideate` **and** `woostack-harden`, two internal sub-skills). Line 62 (build-loop prose): `executing-plans` → `execute` (woostack's own; superpowers credited for `writing-plans` only), and update the PR cadence wording — "one increment per cycle … ends by *offering* a PR" → **multiple stacked PRs per plan; ends on the reviewed stack** (still never merges). |
| `CONTRIBUTING.md` | Loop summary (line 21) already reads `…→ plan → execute` — no change. **Add a "Change the execute phase" pointer row** → `skills/woostack-execute/SKILL.md`, parallel to the existing ideate (line 22) / harden (line 23) rows. |
| `skills/woostack-bootstrap/references/development.md` | Loop summary (line 12) already reads `Ideate → markdown spec → harden → approve spec → plan → execute` — **verify; expected no-op.** Edit only if a stale `executing-plans`/cadence reference is found on a closer pass. |
| `skills/woostack-ideate/SKILL.md` | Minor consistency touch (line 34): the "do not chain `writing-plans`, `executing-plans`, or any implementation skill" example list also names `woostack-execute` now that execute is woostack's implementation command. |

Data flow at runtime: `woostack-build` step 6 (or a direct `/woostack-execute`) → load the
markdown plan from `.woostack/plans/` → critical review → for each PR-sized increment:
implement (TDD) → tick checkboxes in the plan file → `woostack-commit` (new `gt`-stacked branch
+ PR) → `woostack-review --fast` on that PR → continue if clean, stop if REQUEST_CHANGES → next
increment → terminal: a Graphite stack of reviewed PRs, never merged.

## 6. Error handling

- **Skill missing at runtime.** Because it ships in the collection, absence means a broken
  install. `woostack-build`'s preflight no longer lists it as installable; if the file is
  genuinely missing, `woostack-build` falls back to following the execution principle manually
  and says so (same degraded-run contract the preflight already states).
- **No plan argument.** The plan path is required. `/woostack-execute` with no argument → ask
  which plan to execute (optionally list `.woostack/plans/` candidates) and stop until one is
  named; never guess "the current plan."
- **Memory store missing at distill.** If `.woostack/memory/` does not exist when the distill
  step runs, skip distillation (or offer to run `/woostack-init` first) — same contract build's
  old step 7 used. Distill never blocks the increment.
- **Plan not approved.** `woostack-execute` consumes a plan; the design/spec approval gates are
  build's upstream. If invoked standalone on an unhardened/unapproved plan, proceed (the user
  asked to execute it) but note that the upstream gates were not observed.
- **Blocked mid-increment.** Missing dependency, repeated verification failure, unclear
  instruction → stop and ask, never guess (kept from `superpowers:executing-plans`).
- **Review requests changes.** `woostack-review --fast` returns a blocking verdict → stop,
  surface findings, do not advance to the next increment and do not auto-address.
- **Increment too large.** A slice that can't stay near the ≤500 LOC target → propose a further
  split before executing it; genuinely atomic changes may exceed the target (kept from build
  step 5).
- **Description over-trigger.** Risk: a `description` broad enough to hijack unrelated coding
  requests. Mitigation: scope it to "execute / implement an existing plan" plus the build
  execute phase — not a generic "write code" trigger.
- **Branch safety.** Never commit to `main`/`staging`/`beta`/`alpha`; `woostack-commit` already
  enforces this and creates the stacked feature branch. Never merge, never force-push.

## 7. Testing

No app/test harness in this repo (it is a skills collection). Verification is by inspection:

- `woostack-build` no longer references `superpowers:executing-plans`; preflight + step 6 name
  `woostack-execute`.
- Repo-wide grep: no remaining `executing-plans` reference in shipped docs (`AGENTS.md`,
  `README.md`, `CONTRIBUTING.md`, skill files, references) except the `.woostack/` history
  (this new spec and historical specs/plans may mention it); `superpowers:writing-plans`
  references remain.
- New `SKILL.md` has valid frontmatter (`name`, `description`), a required `<plan-path>`
  argument, the per-increment cadence (implement → tick → commit → review → gate → distill), and
  the gate-boundary + terminal-state + never-merge statements.
- `woostack-build` no longer carries a standalone step 7 (distill); step 6 names `woostack-execute`,
  which owns distillation.
- `using-woostack` has a `/woostack-execute` routing row.
- Cross-links resolve (`woostack-build` ↔ `woostack-execute`; `woostack-execute` → `woostack-commit`,
  `woostack-review`).
- Command-surface count is consistent everywhere: `AGENTS.md`, `README.md`, `using-woostack`,
  CONTRIBUTING all reflect **nine** public commands; the "do not rename" hard constraint reflects
  eleven `SKILL.md` files (nine public + two internal).

## 8. Open questions

All resolved. Settled during ideate:

- **Shape** → **public command** (the ninth), not an internal sub-skill. Diverges from the
  ideate/harden internalization pattern by explicit user choice, because execute is invocable by
  name on a plan and mutates git/PR state.
- **PR model** → **stacked PR per increment** via Graphite (`gt`), one branch + PR each —
  literal "multiple PRs per plan."
- **Per-increment loop** → `woostack-commit` → `woostack-review --fast` → **pause only on
  REQUEST_CHANGES**, else continue. Never merge. No auto-address.
- **Build rewire** → **now**: step 6 delegates to `woostack-execute`, preflight drops
  `executing-plans`, counts updated across README/CONTRIBUTING/development.md/AGENTS.md.

Settled during the harden pass:

- **Build steps 5/8** → step 5 (decompose) stays and feeds execute; step 8 rewords to "build
  ends on the reviewed stack" (execute owns PR creation; build never merges). No one-increment
  fallback / dual-mode.
- **Distill ownership** → **execute owns per-increment distill** (memory contract §7
  reject-by-default gate); **build's step 7 is removed** and folded into execute. Standalone
  `/woostack-execute` also distills.
- **Plan resolution** → the plan path is a **required argument**. No no-arg "current plan"
  guessing; no argument → ask and stop. `woostack-build` always passes the path from step 4.
- **`references/` split** → **no**: a single `SKILL.md`. The distill step references the memory
  contract rather than duplicating it, keeping the file in line with ideate/harden.
- **First branch / spec+plan commit** → out of execute's scope to special-case: each increment
  is a fresh `gt`-stacked branch and `woostack-commit` stages only session-relevant changes;
  the spec/plan files ride along with the increment whose work they belong to (build/commit's
  existing relevance logic), not a bespoke setup commit in execute.
- **Naming** → `woostack-execute` (verb-family, matches build/commit/review/init/visualize/
  ideate/harden).
