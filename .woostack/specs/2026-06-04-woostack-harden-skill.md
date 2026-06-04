---
name: woostack-harden-skill
type: spec
status: ready
date: 2026-06-04
branch: worktree-tender-exploring-swing
links:
  - "[[2026-06-03-woostack-ideate-skill]]"
---

# woostack-harden: a woostack-native hardening skill — Design Spec

> Visualize on demand: render this file with [spec-template.html](../../skills/woostack-build/references/spec-template.html) for a rich view, or hand it to `woostack-visualize` (audience `engineer`). Markdown is the source of truth; the HTML is a presentation target only.

## 1. Problem

`woostack-build` step 3 invokes the external `grill-me` skill to harden a written spec —
interview the user until grilling stops producing new questions. That dependency is a poor
fit for the woostack loop in the same ways `superpowers:brainstorming` was before
[`woostack-ideate`](../../skills/woostack-ideate/SKILL.md) replaced it:

1. **External dependency for a core loop step.** The harden phase of the flagship build loop
   is delegated to a third-party skill (`mattpocock/skills`) the consumer must install
   separately. The preflight has to detect it, offer to install it, and degrade gracefully
   when absent — friction for what should be a first-party phase.
2. **Off-the-shelf, not woostack-shaped.** `grill-me` is 9 lines with no awareness of the
   build loop: it does not know about the written markdown spec under `.woostack/`, does not
   amend an artifact in place, and has no defined terminal state or hand-back contract. The
   loop-specific behavior (amend-in-place, stop at "no new questions," hand back to the
   spec-approval gate) lives in `woostack-build`'s prose rather than the skill.
3. **Asymmetry with the rest of the loop.** ideate, spec-writing, planning, and execution are
   all woostack-owned or woostack-conventioned; only the harden phase reaches outside the
   collection. Owning it makes the loop self-contained and consistent.

We want to own the hardening behavior so the build loop's harden phase fits woostack
conventions and carries no external dependency. This is the same move `woostack-ideate` made
one rung up the loop.

## 2. Goal

Ship `skills/woostack-harden/SKILL.md`: a woostack-native hardening skill that grills a plan,
spec, or design until no new questions remain, **amends the artifact in place** when one
exists, and **hands back** to its caller. Rewire `woostack-build` step 3 (and its dependency
preflight) to use it instead of `grill-me`. Keep the parts of `grill-me` that earn their
place — relentless interview, walk the decision tree resolving dependencies, one question at
a time, a recommended answer per question, explore-the-codebase-instead-of-asking — and add
the woostack-loop behavior `grill-me` lacks.

## 3. Non-goals

- **Not a new command.** `woostack-harden` is an internal building block bundled in the
  collection, like [`woostack-ideate`](../../skills/woostack-ideate/SKILL.md) and
  [`action.yml`](../../action.yml) — not a `/woostack-*` command. No `using-woostack` routing
  row; the shipped command surface stays at eight.
- **Owns no approval gate.** The skill hardens, then hands back. It does not present-for-
  approval, does not merge, and does not chain the next phase. `woostack-build` step 3 keeps
  the spec-approval HARD GATE. "Inherit gates, add none" still holds.
- **No replacement of `writing-plans` / `executing-plans`.** This change touches only the
  harden phase. Those superpowers skills remain `woostack-build` dependencies.
- **No behavior change to the other skills** beyond the small doc edits listed in §5.
- **No rewrite of history.** Historical `.woostack/specs/` and `.woostack/plans/` references
  to `grill-me` are records of past work and are left as-is.

## 4. Approach

Author one self-contained `SKILL.md`. It mirrors `grill-me`'s proven core and adds the
loop-specific behavior, parallel to how `woostack-ideate` mirrored superpowers brainstorming
but truncated at "approved design":

- **Frontmatter `description`** scoped so it is recognized as `woostack-build`'s harden phase
  and as a standalone "stress-test / grill / harden my plan" trigger — broad enough to be
  invocable by name and usable standalone, narrow enough not to shadow unrelated skills.
- **Core grill loop** (kept from `grill-me`): interview relentlessly; walk every branch of
  the decision tree, resolving dependencies between decisions; one question per message;
  recommend an answer for each question; if a question is answerable by exploring the
  codebase, explore instead of asking.
- **Amend-in-place** (new): when hardening a written artifact — a `.woostack/` spec or any
  plan/design file the caller names — edit the artifact in place as questions resolve, so it
  strengthens with each answer. When there is no file (pure standalone grilling), converge
  conversationally and write nothing.
- **Terminal state = hardened, handed back** (new): stop when a full pass produces no new
  questions. Then hand back to the caller and name the next step — inside `woostack-build`,
  step 3's spec-approval gate; standalone, tell the user the artifact is hardened.
- **Gate boundary** (new): an explicit statement that the skill owns no approval gate, does
  not present-for-approval, and does not merge — preserving "inherit gates, add none."

### Wiring `woostack-build`

- **Dependency preflight**: drop `grill-me` (and its `pnpx skills add mattpocock/skills`
  install line) from the external-skill list. `woostack-harden` ships in the same collection,
  so it is a bundled internal sub-skill, not an external install. Keep
  `superpowers:writing-plans` and `superpowers:executing-plans` in the preflight.
- **Step 3**: invoke `woostack-harden` instead of `grill-me`. The step is otherwise
  unchanged — harden the spec until no new questions, then the existing spec-approval HARD
  GATE (present the written spec, wait for explicit yes) still fires. The skill hands back;
  the gate stays in `woostack-build`.
- **Overview diagram + `description`**: replace `grill-me` with `harden`; the harden phase is
  now woostack's own (writing-plans/executing-plans still superpowers).

## 5. Components & data flow

Edit set (one PR-sized increment):

| File | Change |
|---|---|
| `skills/woostack-harden/SKILL.md` | **NEW** — the skill (≈80–120 lines): scoped `description`, core grill loop, amend-in-place, terminal/hand-back, gate boundary. |
| `skills/woostack-build/SKILL.md` | Preflight: drop `grill-me` bullet + its install line. Overview diagram: `grill-me` → `harden`. Step 3: invoke `woostack-harden`. `description` frontmatter: harden is now woostack's own (writing-plans/executing-plans still superpowers). |
| `.claude/CLAUDE.md` (= `AGENTS.md`) | "The collection also installs a ninth, internal sub-skill" → two internal sub-skills (`woostack-ideate` + `woostack-harden`); update the "nine `SKILL.md` files" hard constraint to ten; add `woostack-harden` to the Quick file map; protect it from deletion the way `action.yml`/`woostack-ideate` are. |
| `README.md` | Build-loop prose + diagram: `grill` → `harden`; credit `woostack-harden` (in-collection) for the harden phase, superpowers for writing-plans/executing-plans, grill-me removed. Install list (command surface) stays eight. |
| `CONTRIBUTING.md` | Build-loop table row: `grill` → `harden` (the `ideate→spec→grill→…` summary on the "Change the build loop" row). Add a "Change the harden phase" pointer row → `skills/woostack-harden/SKILL.md`, parallel to the existing "Change the ideate phase" row. |
| `skills/woostack-bootstrap/references/development.md` | Update the shipped development-loop summary (table row) to `Ideate → markdown spec → harden → approve spec → plan → execute`. |

Verified during the harden pass — **no edit needed**: `skills/using-woostack/SKILL.md` makes no
mention of internal sub-skills, `woostack-ideate`, or `action.yml` (grep clean), so there is no
"lone internal sub-skill" claim to update there.

Data flow at runtime: `woostack-build` step 3 → loads `woostack-harden` → interactive grill
loop with the user, amending the markdown spec in place → "no new questions" → hand back to
`woostack-build` → step 3's spec-approval gate fires. The skill produces no file of its own;
it only amends the artifact the caller names.

## 6. Error handling

- **Skill missing at runtime.** Because it ships in the collection, absence means a broken
  install. `woostack-build`'s preflight no longer lists it as installable; if the file is
  genuinely missing, `woostack-build` falls back to following the hardening principle
  manually and says so (same degraded-run contract the preflight already states).
- **Description over-trigger.** Risk: a hardening `description` broad enough to hijack
  unrelated requests. Mitigation: scope it to "stress-test / grill / harden a plan, spec, or
  design" plus the build harden phase — not a generic trigger.
- **Gate creep.** Risk: the skill drifts into owning the spec-approval gate (presenting the
  spec for a yes), duplicating `woostack-build` step 3's gate. Mitigation: an explicit gate-
  boundary statement that the skill hands back and owns no gate.
- **Runaway grilling.** Risk: never reaching a terminal state. Mitigation: the terminal-state
  rule — stop when a full pass yields no new questions — is stated explicitly.

## 7. Testing

No app/test harness in this repo (it is a skills collection). Verification is by inspection:

- `woostack-build` no longer references `grill-me`; preflight + step 3 name `woostack-harden`.
- Repo-wide grep: no remaining `grill-me` / `grill me` reference in shipped docs (`AGENTS.md`,
  `README.md`, `CONTRIBUTING.md`, skill files, references); `.woostack/plans/` and
  `.woostack/specs/` history entries are left as-is (only this new spec and historical ones
  may mention it).
- New `SKILL.md` has valid frontmatter (`name`, `description`) and the gate-boundary +
  terminal-state statements.
- Cross-links resolve (`woostack-build` ↔ `woostack-harden`).
- Skill count is consistent everywhere: `AGENTS.md` reflects ten `SKILL.md` files / two
  internal sub-skills; README command surface stays eight.

## 8. Open questions

Resolved during ideate (and to be re-confirmed during the harden pass):

- **Naming** → `woostack-harden` (verb-family, matches build/commit/review/init/visualize/
  ideate; the build loop already calls this phase "harden it").
- **Depth** → richer, woostack-native (not a faithful 9-line port): core grill loop +
  amend-in-place + terminal/hand-back + gate boundary.
- **Scope** → general (any plan/spec/design) and usable standalone, mirroring `woostack-ideate`
  and `grill-me`'s broad trigger; `woostack-build` step 3 points it at the markdown spec.
- **Internal sub-skill description** → scoped so it is invocable by name and usable standalone
  but does not auto-trigger on unrelated work or shadow other skills. Deliberately absent from
  the `using-woostack` routing table and the README command list.
- **`using-woostack` edit?** → resolved: **none needed**. Grep shows `using-woostack/SKILL.md`
  never names `woostack-ideate` or any internal sub-skill, so there is no parallel mention to
  add. The earlier "verify" item is closed.
- **woostack-build `description` frontmatter** → "Chains woostack-ideate, **woostack-harden**,
  superpowers writing-plans/executing-plans, in a fixed, gated order" (drop `grill-me`).
