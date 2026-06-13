---
type: plan
source: .woostack/specs/2026-06-03-woostack-ideate.md
status: done
branch: feature/woostack-ideate
---

**Source:** .woostack/specs/2026-06-03-woostack-ideate.md


# woostack-ideate Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a woostack-native `woostack-ideate` skill that drives idea → approved design and stops there, then rewire `woostack-build` step 1 + preflight to use it instead of `superpowers:brainstorming`.

**Architecture:** One new self-contained skill file (`skills/woostack-ideate/SKILL.md`) — no references dir needed. It keeps superpowers' load-bearing parts (HARD GATE, one-question-at-a-time, 2-3 approaches, design-for-isolation, scope decomposition) and truncates the tail: no spec write, no `writing-plans` chain. Visual treatment defers to `woostack-visualize` instead of a bespoke browser companion. Four existing docs are edited to rewire and document it as an internal building block (not a ninth command). Source: [.woostack/specs/2026-06-03-woostack-ideate.md](../specs/2026-06-03-woostack-ideate.md).

**Tech Stack:** Markdown skill files only. No code, no app build, no CI for this repo.

**Out of scope (explicit):** Do NOT touch `superpowers:writing-plans` / `superpowers:executing-plans` wiring. Do NOT add a `using-woostack` routing row or grow the eight-skill public command/adoption surface. Do NOT port the superpowers browser companion. Do NOT move/rename any existing `SKILL.md`. Do NOT add app code, lockfiles, or CI.

---

## File Structure

- **Create** `skills/woostack-ideate/SKILL.md` — scoped discovery frontmatter, HARD GATE, process (explore → visualize-on-demand → clarify → approaches → present design), pure-design terminal state, hard constraints.
- **Modify** `skills/woostack-build/SKILL.md` — frontmatter `description`, Overview, dependency preflight, step 1.
- **Modify** `AGENTS.md` — internal-sub-skill note after the public skill list; Quick file map entry; protect it from deletion (action.yml-style); keep the public command/adoption surface at eight skills.
- **Modify** `README.md` — build-loop prose names `woostack-ideate` for the ideate phase (superpowers for plans/execution). Install command list stays eight.
- **Modify** `CONTRIBUTING.md` — add a "where to edit the ideate phase" row.

---

## Task 1: Create `skills/woostack-ideate/SKILL.md`

**Files:** Create `skills/woostack-ideate/SKILL.md`

- [x] **Step 1: Frontmatter.** `name: woostack-ideate`. `description` scoped to the woostack build loop's design phase — recognizable as woostack-build's ideate step and usable standalone, but NOT a generic "before any creative work" trigger that would shadow other skills. Mention it stops at an approved design and writes nothing.
- [x] **Step 2: HARD GATE block.** State as an explicit block element: no implementation action — no code, no scaffold, no downstream skill, no spec write — until a design is presented and the user approves. Include the "too simple to need a design" anti-pattern note.
- [x] **Step 3: Process section.** Explore project context → offer `woostack-visualize` only for genuinely visual questions (one-line pointer, not a consent server) → clarifying questions one at a time, multiple-choice preferred → propose 2-3 approaches with a recommendation → present design in sections scaled to complexity, approval per section. Include scope-decomposition guidance (flag multi-subsystem asks; decompose before refining) and design-for-isolation guidance (small units, clear interfaces).
- [x] **Step 4: Terminal state.** Explicit: the skill ends at an approved design and hands it back to the caller. It does NOT write a spec file and does NOT invoke `writing-plans`. Name the caller's next step (woostack-build step 2 writes the markdown spec); when run standalone, tell the user the design is ready to capture as a spec.
- [x] **Step 5: Hard constraints + key principles.** YAGNI, one-question-at-a-time, 2-3 approaches, incremental validation; the "writes no files / chains no skill" rule; visual treatment via woostack-visualize.

## Task 2: Rewire `skills/woostack-build/SKILL.md`

**Files:** Modify `skills/woostack-build/SKILL.md`

- [x] **Step 1: Frontmatter `description`.** Change "Chains superpowers (brainstorming, writing-plans, executing-plans) and grill-me" so brainstorming is no longer attributed to superpowers (e.g. "Chains woostack-ideate, superpowers writing-plans/executing-plans, and grill-me").
- [x] **Step 2: Overview chain + prose.** Rename the chain diagram's first node to `ideate` (the phase label is now "ideate"); ensure no prose claims the ideate phase is superpowers'.
- [x] **Step 3: Dependency preflight.** Remove `superpowers:brainstorming` from the external-skill bullet. Keep `superpowers:writing-plans`, `superpowers:executing-plans`, `grill-me`. Optionally note `woostack-ideate` ships in the collection (internal, no install).
- [x] **Step 4: Procedure step 1.** "Invoke `superpowers:brainstorming`" → "Invoke `woostack-ideate`", linking `../woostack-ideate/SKILL.md`. Preserve "let it run its own approval gate"; note it hands back an approved design (no spec write, no plan chain).
- [x] **Step 5: Spec-approval gate.** Preserve the required gate after hardening: present the written spec, get explicit user approval, then proceed to planning. Reflect `approve spec` in the overview chain and hard constraints.

## Task 3: Document the internal sub-skill in `AGENTS.md`

**Files:** Modify `AGENTS.md`

- [x] **Step 1: Sub-skill note.** After the eight-skill public surface list, add a sentence: woostack-build delegates its ideate phase to the bundled internal `woostack-ideate` sub-skill — a building block, not a ninth `/woostack-*` command. Keep the public command/adoption surface at eight skills.
- [x] **Step 2: Protect from deletion.** In the constraints/notes, treat `skills/woostack-ideate/SKILL.md` like `action.yml`: a shipped internal asset, not a stray to be deleted.
- [x] **Step 3: Quick file map.** Add an entry pointing to `skills/woostack-ideate/SKILL.md` (ideate phase engine for the build loop).

## Task 4: Update `README.md` + `CONTRIBUTING.md`

**Files:** Modify `README.md`, `CONTRIBUTING.md`

- [x] **Step 1: README build-loop prose.** Change "sequences proven sub-skills (superpowers brainstorming/writing-plans/executing-plans + grill-me)" to credit `woostack-ideate` for the ideate phase and superpowers for writing-plans/executing-plans. Include `approve spec` between `grill` and `plan`. Make the Install section distinguish the eight public command/adoption skills from the installed internal sub-skill.
- [x] **Step 2: CONTRIBUTING row.** Add a table row: "Change the ideate phase → `skills/woostack-ideate/SKILL.md`" near the existing build-loop row.
- [x] **Step 3: Bootstrap development reference.** Update `skills/woostack-bootstrap/references/development.md` so the shipped loop summary says `ideate → markdown spec → grill → approve spec → plan → execute`.

## Task 5: Verify

- [x] **Step 1: Grep.** No `superpowers:brainstorming` / "superpowers brainstorming" reference remains in shipped docs (`AGENTS.md`, `README.md`, `CONTRIBUTING.md`, `skills/**/SKILL.md`). `.woostack/` history files left as-is.
- [x] **Step 2: Frontmatter + gate.** New `SKILL.md` has valid `name`/`description` and the HARD GATE block.
- [x] **Step 3: Cross-links.** woostack-build ↔ woostack-ideate links resolve; woostack-visualize pointer resolves; AGENTS file-map link resolves.
- [x] **Step 4: Count.** `AGENTS.md` still presents an eight-skill public command/adoption surface, and documents `woostack-ideate` as an installed internal sub-skill.
- [x] **Step 5: Build-flow summaries.** Shipped summaries (`README.md`, `CONTRIBUTING.md`, `skills/woostack-bootstrap/references/development.md`, and `skills/woostack-build/SKILL.md`) all include the required `approve spec` gate before planning.
