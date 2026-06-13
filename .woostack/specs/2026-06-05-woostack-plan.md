---
name: 2026-06-05-woostack-plan
type: spec
status: approved
date: 2026-06-05
branch: feature/woostack-plan
links:
  - "[[2026-06-03-woostack-ideate]]"
  - "[[2026-06-04-woostack-harden]]"
  - "[[2026-06-04-woostack-execute]]"
---

# woostack-plan: a woostack-native plan-writing command — Design Spec

> **Plan:** [[plans/2026-06-05-woostack-plan]]

> Visualize on demand: render this file with [spec-template.html](../../skills/woostack-build/references/spec-template.html) for a rich view, or hand it to `woostack-visualize` (audience `engineer`). Markdown is the source of truth; the HTML is a presentation target only.

> `status:` is the build-loop phase enum: `draft → hardened → approved → planning → executing → in-review → done` (plus the terminal `abandoned`). The build loop authors each transition and `/woostack-status` reads it; the enum and join contracts are defined once in [conventions.md](../../skills/woostack-status/references/conventions.md).

## 1. Problem

`woostack-build` step 4 delegates plan authoring to the external `superpowers:writing-plans`
skill. That skill is the **last remaining external dependency** in the flagship build loop,
after [`woostack-ideate`](../../skills/woostack-ideate/SKILL.md) replaced
`superpowers:brainstorming`, [`woostack-harden`](../../skills/woostack-harden/SKILL.md)
replaced `grill-me`, and [`woostack-execute`](../../skills/woostack-execute/SKILL.md) replaced
`superpowers:executing-plans`. It is a poor fit for the woostack loop in three ways:

1. **External dependency for a core loop step.** The plan phase is the sole survivor in
   `woostack-build`'s dependency preflight — it must be detected, offered for inline install,
   and degraded when absent. That whole preflight section exists only for this one skill. Once
   plan is first-party, the preflight disappears and every build phase is owned in-collection.
2. **Off-the-shelf, not woostack-shaped.** `superpowers:writing-plans` saves to
   `docs/superpowers/plans/`, prescribes a plan header with a `REQUIRED SUB-SKILL:
   subagent-driven-development / executing-plans` banner, and ends with an "Execution Handoff"
   that offers subagent-vs-inline execution. None of that matches woostack: plans live under
   `.woostack/plans/`, are frontmatter-free, open with a `**Source:**` line that joins them
   1:1 to their spec, and hand the execution choice to `woostack-build`'s execution-handoff
   gate (step 8) and `woostack-execute`. Today all of that lives as narration in
   `woostack-build`'s prose around the delegation rather than in the plan engine itself.
3. **No board-join awareness.** woostack plans must carry the `**Source:** .woostack/specs/<file>.md`
   line, stay frontmatter-free, structure work as PR-sized increments, and advance the spec's
   `status:` to `planning`. `superpowers:writing-plans` knows none of these conventions, so the
   build loop has to bolt them on after the fact.

We want to own the plan-writing behavior so the build loop's plan phase fits woostack
conventions, the board join is part of the engine, and the build loop has **zero external
skill dependencies**.

## 2. Goal

Ship `skills/woostack-plan/SKILL.md`: a woostack command that takes one approved markdown
spec (**supplied as a required argument**) and writes a comprehensive implementation plan to
`.woostack/plans/<spec-basename>.md`, structured as **PR-sized increments**. The plan opens
with the `**Source:** .woostack/specs/<file>.md` line in its first ~5 lines (the 1:1 board
join), stays frontmatter-free, decomposes work into bite-sized TDD tasks with no placeholders,
runs a self-review pass, and sets the spec's `status: planning`. It writes the plan and hands
back; it owns no approval gate and chains no execution.

Rewire `woostack-build` step 4 (and **remove** its dependency-preflight section) to use it, and
fold build step 5's decomposition into the plan engine. Keep the parts of
`superpowers:writing-plans` that earn their place — file-structure-first decomposition,
bite-sized one-action TDD steps, the no-placeholders discipline, the self-review checklist, the
scope check, DRY/YAGNI/TDD/frequent-commits — and add the woostack conventions it lacks.

This is the same internalization move `woostack-ideate`, `woostack-harden`, and
`woostack-execute` made on the phases around it. Settled in ideate: **`woostack-plan` ships as
a public command** (the eleventh), pairing with `woostack-execute` as produce-plan /
consume-plan (`/woostack-plan <spec>` then `/woostack-execute <plan>`), and directly useful to
invoke by name on an approved spec.

## 3. Non-goals

- **Adds no approval gate.** `woostack-build` keeps its two HARD GATES (design approval, spec
  approval) upstream and the execution-handoff gate (step 8) downstream. `woostack-plan`
  inherits gates and adds none. It writes the plan and hands back.
- **Does not author specs.** It consumes an approved spec under `.woostack/specs/`; it does not
  write or rewrite specs. (It does set the spec's `status: planning` frontmatter field — a
  one-line phase transition, not authoring spec content.)
- **Does not execute.** No implementation, no TDD-in-the-loop, no commits, no PRs. Those are
  `woostack-execute`. The plan is the deliverable; the execution choice is `woostack-build`
  step 8's and `woostack-execute`'s.
- **Does not write a second plan for a spec.** The `spec : plan : PRs = 1 : 1 : N` invariant
  holds: exactly one plan per spec. If a plan already resolves to the spec, `woostack-plan`
  amends it in place rather than creating a duplicate (a second plan breaks the board join).
- **No rewrite of history.** Historical `.woostack/specs/` and `.woostack/plans/` references to
  `superpowers:writing-plans` are records of past work and are left as-is.

## 4. Approach

Author `SKILL.md` plus a `references/plan-template.md` fill-in skeleton (symmetric with the
spec's [spec-template.md](../../skills/woostack-build/references/spec-template.md)). The SKILL.md
holds the plan-writing *logic*; the template holds the *output shape* the plan fills in — the
two are different concerns, so this is an output-artifact template, not a logic split. It mirrors
`superpowers:writing-plans`' proven core and adds the woostack conventions, parallel to how
`woostack-execute` mirrored `executing-plans` but added the PR cadence.

- **Frontmatter `description`** scoped so it is recognized as `woostack-build`'s plan phase and
  as a standalone "write the plan / plan this spec" trigger, and routed by `using-woostack` —
  broad enough to be invocable by name, narrow enough not to shadow unrelated skills or hijack
  generic "make a plan" requests.
- **Commands**:
  - `/woostack-plan <spec-path>` — write the plan for the named spec file. **The spec path is a
    required argument.**
  - `/woostack-plan` with no argument — do **not** guess "the current spec." Ask the user which
    spec to plan (optionally list `.woostack/specs/` candidates) and stop until one is named.
    When `woostack-build` invokes plan it always passes the spec path from step 2/3, so this
    no-arg path is the standalone-misuse guard, not a routine resolution.
- **Core plan-writing loop** (kept from `superpowers:writing-plans`):
  - **Scope check** — if the spec covers multiple independent subsystems, suggest splitting into
    separate plans (one per subsystem), each producing working, testable software on its own.
  - **File-structure-first** — map which files are created/modified and each one's single
    responsibility before defining tasks; this locks in decomposition. Prefer small, focused
    files; follow existing-codebase patterns.
  - **Bite-sized tasks** — each step is one action (~2-5 min): write the failing test → run it
    to confirm it fails → minimal implementation → run to confirm it passes → commit. Checkbox
    (`- [ ]`) syntax so `woostack-execute` ticks them in place.
  - **No placeholders** — every step carries the actual content: exact file paths, complete code
    in every code step, exact commands with expected output. No TBD/TODO/"handle edge cases"/
    "similar to Task N".
  - **Self-review** — after writing, check the plan against the spec: spec coverage (every
    requirement maps to a task), placeholder scan, type/signature consistency across tasks. Fix
    inline.
  - DRY / YAGNI / TDD / frequent commits throughout.
- **PR-sized increments** (woostack): structure the plan as a sequence of independently
  shippable increments (≤500 LOC soft target, not a gate) so a standalone plan is
  execute-ready. Flag any slice that can't reasonably stay under the target and propose a
  further split; genuinely atomic changes may exceed it. This **folds build step 5's
  decomposition into the plan engine** — exactly as `woostack-execute` absorbed decomposition
  for standalone runs.
- **Board join + frontmatter-free** (woostack): the plan **opens with**
  `**Source:** .woostack/specs/<file>.md` in its first ~5 lines (the spec→plan join). Plans
  carry **no** YAML frontmatter. Header is Goal / Architecture / Tech-stack plus the `**Source:**`
  line — **not** the superpowers `REQUIRED SUB-SKILL` banner. This shape is captured in
  `references/plan-template.md`, which the skill populates (the way build step 2 populates
  spec-template.md).
- **Filename mirrors the spec basename** (woostack): the plan is named
  `.woostack/plans/<spec-basename>.md` — the **same** `YYYY-MM-DD-<slug>` basename as its spec
  (the spec's creation date, reused — *not* today's date). Every existing pair shares a basename,
  which is what makes the slug-match fallback join work alongside the `**Source:**` line. If the
  derived basename is already taken, that plan resolves to this spec → amend it, never write a
  second (see Error handling).
- **Status authoring** (woostack): on writing the plan, set the spec's `status: planning` (the
  conventions.md enum value for "plan exists, 0 boxes done"). Doing this in the plan engine means
  a standalone `/woostack-plan` also advances the board correctly, mirroring how
  `woostack-execute` owns the executing/review band. The enum and join contracts live in
  [conventions.md](../../skills/woostack-status/references/conventions.md) — link, never restate.
- **Drop from superpowers** (woostack): the `docs/superpowers/plans/` default location, the
  `REQUIRED SUB-SKILL` plan-header banner, and the entire "Execution Handoff" section (the
  subagent-vs-inline offer) — that boundary is `woostack-build` step 8's gate and
  `woostack-execute`'s, not the plan engine's.
- **Hand back** (woostack): after writing the plan and setting `status: planning`, state the
  plan path and hand back — to `woostack-build` step 6 (harden the plan) when invoked by build,
  or to the user (offer `/woostack-execute <plan>`) when standalone. Chain nothing.
- **Gate boundary**: an explicit statement that the skill owns no approval gate, does not
  execute, and does not merge — preserving `woostack-build`'s "inherit gates, add none."

### Wiring `woostack-build`

- **Dependency preflight**: `superpowers:writing-plans` was the **only** external skill listed.
  Remove the entire `## Dependency preflight` section — every build phase is now first-party
  (`woostack-ideate`, `woostack-harden`, `woostack-plan`, `woostack-commit`, `woostack-execute`),
  so there is nothing to preflight, install inline, or degrade.
- **Step 4 (Plan)**: invoke `woostack-plan` (passing the approved spec path) instead of
  `superpowers:writing-plans`. `woostack-plan` now owns saving the markdown plan under
  `.woostack/plans/`, the `**Source:**` line, frontmatter-free shape, and the `status: planning`
  transition — so build step 4's prose collapses into the delegation.
- **Step 5 (Decompose)**: `woostack-plan` now structures the plan as PR-sized increments, so
  step 5's decomposition is folded into the plan engine. Reword step 5 to "the plan already
  decomposes into PR-sized increments; verify the boundaries feed `woostack-execute`" — parallel
  to how the execute rewire treated decomposition.
- **Overview diagram + `description`**: replace `writing-plans` with `plan` in the step chain;
  drop "and superpowers writing-plans" from the build `description`. The plan phase is now
  woostack's own — **the build loop has no external skill dependencies.**

## 5. Components & data flow

Edit set (decomposed into PR-sized increments in the plan):

| File | Change |
|---|---|
| `skills/woostack-plan/SKILL.md` | **NEW** — the skill (the status step *references* conventions.md rather than duplicating it): scoped `description`, required `/woostack-plan <spec-path>` command, core plan-writing loop (scope check, file-structure-first, bite-sized TDD tasks, no-placeholders, self-review), PR-sized increments, board join (`**Source:**` line, frontmatter-free), `status: planning` authoring, hand-back, gate boundary, hard constraints. Points at `references/plan-template.md` for the output shape. |
| `skills/woostack-plan/references/plan-template.md` | **NEW** — fill-in plan skeleton, symmetric with `skills/woostack-build/references/spec-template.md`: the `**Source:**` line, Goal / Architecture / Tech-stack header (no frontmatter, no `REQUIRED SUB-SKILL` banner), and the bite-sized TDD task structure (`### Task N`, `**Files:**`, checkbox `- [ ]` steps with code/commands/expected-output). The canonical "what a woostack plan looks like" reference for woostack-execute/woostack-status. |
| `skills/woostack-build/SKILL.md` | **Remove the entire `## Dependency preflight` section** (writing-plans was the only external dep). Overview diagram: `writing-plans` → `plan`. Step 4: invoke `woostack-plan`. Step 5: reword — plan owns decomposition, step 5 verifies boundaries feed execute. `description` frontmatter: drop "and superpowers writing-plans"; plan is now woostack's own (build loop fully first-party). Hard-constraints/prose mentions of `writing-plans` updated to `woostack-plan`. |
| `skills/using-woostack/SKILL.md` | **Add a routing row** to the Command Routing table for `/woostack-plan <spec-path>` → `woostack-plan` (public command, like execute). |
| `.claude/CLAUDE.md` (= `AGENTS.md`) | "ten skills" public surface → **eleven**, add `woostack-plan` to the public list and Quick file map. "ten-skill command surface" → eleven. "twelve `SKILL.md` files (ten public + two internal)" → **thirteen (eleven public + two internal)**. Internal sub-skill list stays two (`woostack-ideate`, `woostack-harden`). Protect `woostack-plan` from deletion like the other shipped skills. |
| `README.md` | Public-skill count "ten" → **eleven**, add `woostack-plan`. Build-loop prose: `writing-plans` → `plan` (woostack's own); note the build loop now has **no external skill dependencies** / superpowers fully internalized. |
| `CONTRIBUTING.md` | Loop summary already reads `…→ plan → execute` — verify. **Add a "Change the plan phase" pointer row** → `skills/woostack-plan/SKILL.md`, parallel to the existing ideate/harden/execute rows. |
| `skills/woostack-status/scripts/status.sh` | The `approved` next-action string `"write the plan (writing-plans)"` → `"write the plan (woostack-plan)"`; the no-plan flag `"... (writing-plans)"` → `"... (woostack-plan)"`. Keeps the board's guidance pointing at the woostack command. |
| `skills/woostack-status/scripts/tests/test-status.sh` | The assertion `assert_contains "$OUT" "writing-plans"` → `"woostack-plan"` to match the updated next-action string. |
| `skills/woostack-ideate/SKILL.md` | Minor consistency touch: the "do not chain `writing-plans`, `woostack-execute`, …" example list updates `writing-plans` → `woostack-plan` now that plan is woostack's own command. |

Data flow at runtime: `woostack-build` step 4 (or a direct `/woostack-plan <spec-path>`) → read
the approved markdown spec from `.woostack/specs/` → scope check → map file structure → write
the plan to `.woostack/plans/<spec-basename>.md` (opening `**Source:**` line, frontmatter-free,
PR-sized increments, bite-sized TDD tasks, no placeholders) → self-review against the spec → set
spec `status: planning` → hand back (to build step 6 harden, or to the user with an
`/woostack-execute` offer). No execution, no commits, no merge.

## 6. Error handling

- **Skill missing at runtime.** Because it ships in the collection, absence means a broken
  install. Build's preflight no longer exists (it was removed), so there is nothing to install
  inline; if the file is genuinely missing, `woostack-build` falls back to following the
  plan-writing principle manually and says so (degraded, not equivalent).
- **No spec argument.** The spec path is required. `/woostack-plan` with no argument → ask which
  spec to plan (optionally list `.woostack/specs/` candidates) and stop until one is named;
  never guess "the current spec."
- **Plan already exists for the spec.** A plan already resolves to the spec (via `**Source:**`
  line or slug) → **amend the existing plan**, do not write a second (a second plan breaks the
  `1:1` board join). Surface that the plan exists and that it is being amended.
- **Spec not approved.** `woostack-plan` consumes a spec; the design/spec approval gates are
  build's upstream. If invoked standalone on an unhardened/unapproved spec, proceed (the user
  asked to plan it) but note that the upstream gates were not observed.
- **Spec covers multiple subsystems.** Scope check → suggest splitting into separate plans (one
  per subsystem), each independently testable, before writing a monolithic plan.
- **Slice too large.** An increment that can't stay near the ≤500 LOC target → propose a further
  split before finalizing; genuinely atomic changes may exceed the target.
- **Memory/store missing.** `woostack-plan` does not distill memory (that is execute's job), so a
  missing `.woostack/memory/` is irrelevant here. It only needs `.woostack/specs/` (to read) and
  `.woostack/plans/` (to write); if `.woostack/plans/` is absent, create it (or offer
  `/woostack-init`).
- **Description over-trigger.** Risk: a `description` broad enough to hijack generic "make a
  plan" requests. Mitigation: scope it to "write the implementation plan for an approved
  woostack spec" plus the build plan phase — not a generic planning trigger.

## 7. Testing

No app/test harness in this repo (it is a skills collection). Verification is by inspection,
plus the existing status-script test:

- New `SKILL.md` has valid frontmatter (`name`, `description`), a required `<spec-path>`
  argument, the core plan-writing loop (scope check, file-structure-first, bite-sized TDD tasks,
  no-placeholders, self-review), PR-sized increments, the `**Source:**`/frontmatter-free board
  join, the `status: planning` authoring, hand-back, the gate-boundary statement, and a link to
  `references/plan-template.md`.
- `references/plan-template.md` exists, is frontmatter-free, opens with the `**Source:**` line,
  carries no `REQUIRED SUB-SKILL` banner, shows the bite-sized TDD task structure, and is
  cross-linked from `SKILL.md` (link resolves).
- `woostack-build` no longer has a `## Dependency preflight` section; step 4 names
  `woostack-plan`; the overview diagram and `description` say `plan`, not `writing-plans`.
- Repo-wide grep: **no remaining `writing-plans` reference in shipped docs/skills/scripts**
  (`AGENTS.md`, `README.md`, `CONTRIBUTING.md`, skill files, status scripts) except the
  `.woostack/` history (this new spec and historical specs/plans may mention it). No remaining
  `superpowers:` runtime dependency anywhere in the build loop.
- `using-woostack` has a `/woostack-plan` routing row.
- `skills/woostack-status/scripts/tests/test-status.sh` passes with the updated assertion
  (`woostack-plan` in the approved next-action), and `status.sh` emits the woostack-plan
  guidance string.
- Cross-links resolve (`woostack-build` ↔ `woostack-plan`; `woostack-plan` → `woostack-execute`,
  conventions.md).
- Command-surface count is consistent everywhere: `AGENTS.md`, `README.md`, `using-woostack`,
  CONTRIBUTING all reflect **eleven** public commands; the "do not rename" hard constraint
  reflects **thirteen** `SKILL.md` files (eleven public + two internal).

## 8. Open questions

All resolved. Settled during ideate:

- **Shape** → **public command** (the eleventh), pairing with `woostack-execute` as
  produce-plan / consume-plan. Adds `/woostack-plan <spec-path>`, a routing row, and bumps the
  surface counts.
- **Argument** → the spec path is a **required argument**. No no-arg "current spec" guessing; no
  argument → ask and stop. `woostack-build` always passes the path from step 2/3.
- **Plan output template** → **ship `references/plan-template.md`**: a fill-in plan skeleton
  symmetric with the spec's `spec-template.md`. The SKILL.md holds the plan-writing logic and
  references the template for the output shape (the status step likewise references conventions.md
  rather than duplicating it). This is an output-artifact template, not a logic split — the skill
  is still one `SKILL.md`.
- **Status ownership** → **`woostack-plan` sets `status: planning`** itself (so standalone plan
  also advances the board), mirroring execute owning the executing/review band.
- **Decomposition ownership** → **plan owns PR-sized decomposition** (folds build step 5 into the
  plan engine; step 5 rewords to "verify boundaries feed execute"), parallel to the execute
  rewire.
- **Build rewire** → **now**: step 4 delegates to `woostack-plan`, **the dependency-preflight
  section is removed entirely** (writing-plans was the only external dep), counts updated across
  README/CONTRIBUTING/AGENTS.md/using-woostack. The build loop becomes fully first-party.
- **Naming** → `woostack-plan` (user-specified; verb-family, matches
  build/execute/commit/review/init/visualize/ideate/harden).
</content>
</invoke>
