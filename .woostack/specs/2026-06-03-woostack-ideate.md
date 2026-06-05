---
name: woostack-ideate
type: spec
status: done
date: 2026-06-03
branch: feature/woostack-ideate
links:
---

# woostack-ideate: a woostack-native ideation skill — Design Spec

> Visualize on demand: render this file with [spec-template.html](../../skills/woostack-build/references/spec-template.html) for a rich view, or hand it to `woostack-visualize` (audience `engineer`). Markdown is the source of truth; the HTML is a presentation target only.

## 1. Problem

`woostack-build` step 1 invokes `superpowers:brainstorming` to converge on a design.
That dependency is a poor fit for the woostack loop in three concrete ways:

1. **Wrong terminal state.** superpowers brainstorming does not stop at an approved
   design — it *also* writes the spec doc to its own default `docs/superpowers/specs/`
   and then chains `writing-plans`. woostack-build already owns spec-writing (its step 2,
   to `.woostack/specs/`) and plan-writing (its step 4). The superpowers brainstorming
   skill's tail fights woostack-build for ownership: wrong path, premature plan, double-write.
2. **Wrong visual companion.** superpowers ships a bespoke browser companion server for
   visual brainstorming. woostack already has a first-class visualization skill,
   `woostack-visualize`, that produces self-contained offline HTML. Carrying a second,
   redundant visual mechanism is waste.
3. **External dependency for a core loop step.** The first phase of the flagship build
   loop is delegated to a third-party skill the consumer must install separately. The
   preflight has to detect it, offer to install it, and degrade gracefully when absent.

We want to own the ideation behavior so the build loop's first phase fits woostack
conventions and carries no external dependency.

## 2. Goal

Ship `skills/woostack-ideate/SKILL.md`: a woostack-native ideation skill that
drives idea → approved design and **stops there**, handing the approved design back to its
caller. Rewire `woostack-build` step 1 (and its dependency preflight) to use it instead of
`superpowers:brainstorming`. Keep the superpowers parts that earn their place — the HARD
GATE, one-question-at-a-time, propose-2-3-approaches, design-for-isolation, scope
decomposition — and drop the parts that conflict with woostack-build's ownership.

## 3. Non-goals

- **Not a new command.** `woostack-ideate` is an internal building block bundled in the
  collection, like [`action.yml`](../../action.yml) — not a ninth `/woostack-*` command. No
  `using-woostack` routing row; the shipped command surface stays at eight.
- **No spec writing, no plan chaining.** The skill writes no files and invokes no downstream
  skill. woostack-build keeps owning the `.woostack/specs/` write (step 2) and the
  `writing-plans` chain (step 4).
- **No replacement of `writing-plans` / `executing-plans`.** This change touches only the
  ideate phase. Those superpowers skills remain woostack-build dependencies.
- **No bespoke browser companion.** Visual treatment defers to `woostack-visualize`. We do
  not port or reinvent the superpowers companion server.
- **No behavior change to the other seven skills** beyond the small doc edits listed in §5.

## 4. Approach

Author one self-contained `SKILL.md`. It mirrors the proven superpowers structure but
truncates the tail at "approved design":

- **Frontmatter `description`** scoped so it is recognized as woostack-build's ideate
  phase, not a general-purpose creative-work trigger that would shadow other skills.
- **HARD GATE** preserved verbatim in spirit: no implementation action — no code, no
  scaffold, no downstream skill — until a design is presented and the user approves.
- **Process**: explore project context → (optional) offer `woostack-visualize` for
  genuinely visual questions → clarifying questions one at a time → propose 2-3 approaches
  with a recommendation → present design in sections scaled to complexity, approval per
  section → scope-decomposition guidance for oversized requests → design-for-isolation
  guidance.
- **Terminal state = approved design, handed back.** Explicitly: the skill does NOT write a
  spec file and does NOT invoke `writing-plans`. It names its caller's next step
  (woostack-build step 2) so the handoff is legible, and when run standalone it tells the
  user the design is ready to capture as a spec.
- **Visual companion** section replaced by a short pointer to `woostack-visualize` (audience
  chosen to fit the question), replacing the superpowers browser-server consent flow.

### Wiring `woostack-build`

- **Dependency preflight**: drop `superpowers:brainstorming` from the external-skill list.
  `woostack-ideate` ships in the same collection, so it is a bundled internal sub-skill,
  not an external install. Keep `superpowers:writing-plans`, `superpowers:executing-plans`,
  and `grill-me` in the preflight.
- **Step 1**: invoke `woostack-ideate` instead of `superpowers:brainstorming`. The step
  still "lets it run its own approval gate"; the difference is the skill now hands back an
  approved design rather than writing a spec and chaining a plan.
- **Restore the spec-approval gate (step 3).** `superpowers:brainstorming` owned a "user
  reviews the written spec" gate. Pulling spec-writing into woostack-build step 2 — and making
  `woostack-ideate` stop at *design* approval — orphans that gate. woostack-build must host
  it: after hardening (step 3), **always present the written spec and get explicit user
  approval before planning**. Two distinct hard gates now exist: design approval
  (`woostack-ideate`) and spec approval (woostack-build). Relocating an inherited gate is
  not adding one, so "inherit gates, add none" still holds.

## 5. Components & data flow

Edit set (one PR-sized increment):

| File | Change |
|---|---|
| `skills/woostack-ideate/SKILL.md` | **NEW** — the skill (≈120-160 lines). |
| `skills/woostack-build/SKILL.md` | Preflight: drop `superpowers:brainstorming`. Step 1: invoke `woostack-ideate`. Overview line + `description` frontmatter: ideation is now woostack's own (writing-plans/executing-plans still superpowers). **Step 3: restore the spec-approval hard gate** (present spec, get explicit approval before planning); reflect both gates in the Overview + Hard constraints. |
| `AGENTS.md` | Note that woostack-build delegates its ideate phase to the bundled internal `woostack-ideate` sub-skill (not a ninth command); add to the Quick file map; protect it from deletion the way `action.yml` is protected ("shipped asset, not a stray"). Keep "eight shipped skills". |
| `README.md` | Build-loop prose: "sequences proven sub-skills (superpowers brainstorming/writing-plans/executing-plans + grill-me)" → name `woostack-ideate` for the ideate phase, superpowers for the other two, and show `approve spec` before planning. Install list (command surface) stays eight. |
| `CONTRIBUTING.md` | Add a "where to edit the ideate phase" row → `skills/woostack-ideate/SKILL.md`; keep the build-loop summary's `approve spec` gate visible. |
| `skills/woostack-bootstrap/references/development.md` | Update the shipped development-loop summary to `ideate → markdown spec → grill → approve spec → plan → execute`. |

Data flow at runtime: woostack-build → loads `woostack-ideate` → interactive
design loop with the user → approved design returned to woostack-build → woostack-build
step 2 writes the markdown spec. No file is produced by the ideate skill itself.

## 6. Error handling

- **Skill missing at runtime.** Because it ships in the collection, absence means a broken
  install. woostack-build's preflight no longer lists it as installable; if the file is
  genuinely missing, woostack-build falls back to following the ideation principle
  manually and says so (same degraded-run contract the preflight already states for other
  deps).
- **Description over-trigger.** Risk: an ideation `description` broad enough to hijack
  unrelated creative-work requests. Mitigation: scope the description to the woostack build
  loop's design phase, not generic "before any creative work".
- **Gate bypass.** The HARD GATE is the load-bearing safety property; it is stated as an
  explicit block element so it is not lost to summarization.

## 7. Testing

No app/test harness in this repo (it is a skills collection). Verification is by inspection:

- `woostack-build` no longer references `superpowers:brainstorming`; preflight + step 1 name
  `woostack-ideate`.
- Repo-wide grep: no remaining `superpowers:brainstorming` / "superpowers brainstorming"
  reference in shipped docs (`AGENTS.md`, `README.md`, `CONTRIBUTING.md`, skill files);
  `.woostack/plans/` and `.woostack/specs/` history entries are left as-is.
- New `SKILL.md` has valid frontmatter (`name`, `description`) and the HARD GATE.
- Cross-links resolve (woostack-build ↔ woostack-ideate, woostack-visualize pointer).
- `eight shipped skills` count in `AGENTS.md` remains accurate (woostack-ideate is internal).

## 8. Open questions

Resolved during the grill pass:

- **Naming** → `woostack-ideate` (verb-family, matches build/commit/review/init/visualize).
- **Internal sub-skill description** → keep a *scoped* `description` so the skill is
  invocable by name (woostack-build calls it directly) and usable standalone, but narrow
  enough that it does not auto-trigger on generic creative work or shadow other skills. It is
  deliberately absent from the `using-woostack` routing table and the README command list.
- **README Install list** → stays at the eight command skills; woostack-ideate is
  documented as an internal building block in `AGENTS.md`, not advertised as a command.
