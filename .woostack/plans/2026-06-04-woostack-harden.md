---
type: plan
source: .woostack/specs/2026-06-04-woostack-harden.md
status: done
branch: worktree-tender-exploring-swing
---

**Source:** [[specs/2026-06-04-woostack-harden]]


# woostack-harden Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a woostack-native `woostack-harden` skill that grills a plan/spec/design until no new questions remain and hands back, then rewire `woostack-build` step 3 + preflight to use it instead of the external `grill-me`.

**Architecture:** One new self-contained skill file (`skills/woostack-harden/SKILL.md`) — no references dir needed. It keeps `grill-me`'s load-bearing core (relentless interview, walk the decision tree resolving dependencies, one question at a time, a recommended answer per question, explore-the-codebase-instead-of-asking) and adds the loop behavior `grill-me` lacks: amend-the-artifact-in-place, a terminal "no new questions → hand back" state, and an explicit gate boundary (owns no approval gate). Six existing docs are edited to rewire it and document it as an internal building block (the 10th skill, second internal sub-skill — not a `/woostack-*` command). Source: [.woostack/specs/2026-06-04-woostack-harden.md](../specs/2026-06-04-woostack-harden.md).

**Tech Stack:** Markdown skill files only. No code, no app build, no CI for this repo.

**Out of scope (explicit):** Do NOT touch `superpowers:writing-plans` / `superpowers:executing-plans` wiring. Do NOT add a `using-woostack` routing row or grow the eight-skill public command/adoption surface. Do NOT edit `using-woostack/SKILL.md` (grep-verified: no internal-sub-skill mention to update). Do NOT rewrite historical `.woostack/specs|plans/*` grill-me references. Do NOT move/rename any existing `SKILL.md`. Do NOT add app code, lockfiles, or CI.

---

## File Structure

- **Create** `skills/woostack-harden/SKILL.md` — scoped discovery frontmatter, core grill loop, amend-in-place, terminal/hand-back state, gate boundary, hard constraints.
- **Modify** `skills/woostack-build/SKILL.md` — frontmatter `description`, Overview chain diagram, dependency preflight, step 3.
- **Modify** `.claude/CLAUDE.md` (= `AGENTS.md`, symlinked) — second internal-sub-skill note; "nine → ten" `SKILL.md` constraint; Quick file map entry; protect from deletion (action.yml/ideate-style).
- **Modify** `README.md` — build-loop prose + diagram (`grill` → `harden`); credit `woostack-harden` (in-collection), grill-me removed. Install command surface stays eight.
- **Modify** `CONTRIBUTING.md` — build-loop summary row (`grill` → `harden`) + new "Change the harden phase" pointer row.
- **Modify** `skills/woostack-bootstrap/references/development.md` — loop-summary table row (`grill` → `harden`).

---

## Task 1: Create `skills/woostack-harden/SKILL.md`

**Files:** Create `skills/woostack-harden/SKILL.md`

- [x] **Step 1: Write the full skill file.** Author the file with exactly this content:

```markdown
---
name: woostack-harden
description: Use to harden a plan, spec, or design by relentless interview — walk every branch of the decision tree, resolve each open question one at a time with a recommended answer, and amend the artifact in place until no new questions remain. This is the harden phase of the woostack build loop (woostack-build step 3); also usable standalone to stress-test or "grill me" on a design before committing to it.
---

# woostack-harden

Harden a plan, spec, or design by interviewing the user relentlessly until you reach shared
understanding and the artifact stops producing new questions. This is woostack's own hardening
phase — [`woostack-build`](../woostack-build/SKILL.md) step 3. It keeps the discipline that
makes grilling worth doing, **amends the target artifact in place** as answers land, and
**stops when no new questions remain**, handing back to its caller. It owns no approval gate.

## The grill loop

Interview relentlessly about every aspect of the plan or design until you reach a shared
understanding. Walk down each branch of the decision tree, resolving dependencies between
decisions one by one.

- **One question per message.** Never stack questions; never overwhelm.
- **Recommend an answer.** For every question, give your recommended answer and say why.
- **Explore, don't ask.** If a question can be answered by exploring the codebase, explore
  the codebase instead of asking the user.
- **Resolve dependencies in order.** When one decision gates another, settle the upstream one
  first so downstream questions are well-posed.

## Amend the artifact in place

When the thing being hardened is a written artifact — a `.woostack/` spec, or any plan/design
file the caller names — **edit that file in place as each question resolves**, so it
strengthens with every answer. Fold the resolution into the relevant section; record settled
decisions (e.g. under the spec's "Open questions") so the artifact, not the chat log, is the
record. When there is no file (pure standalone grilling), converge conversationally and write
nothing.

## Terminal state: hardened, handed back

Stop when a full pass over the decision tree produces **no new questions** — the artifact is
hardened. Then hand back to the caller and name the next step:

- Inside `woostack-build`: hand back to its **step 3**, which owns the spec-approval HARD GATE
  (present the written spec, wait for explicit user approval before planning). Do not run that
  gate yourself.
- Standalone: tell the user the artifact is hardened and ready to take to approval, and stop.

## Gate boundary

This skill owns **no approval gate**. It does not present-the-artifact-for-approval, does not
merge, and does not chain the next phase. It hardens, then hands back. Keeping the gate with
the caller is what preserves woostack-build's "inherit gates, add none."

## Hard constraints

- **One question at a time.** Multiple choice when the options are clear.
- **Always recommend an answer** for every question you ask.
- **Explore the codebase** to answer a question before asking the user.
- **Amend in place; write nothing new.** Strengthen the named artifact; do not create a new
  file, a spec, or a plan.
- **Own no gate.** Hand back at "no new questions"; never solicit final approval or merge.
```

- [x] **Step 2: Verify frontmatter parses.** Run: `head -4 skills/woostack-harden/SKILL.md` — expect a `---` / `name: woostack-harden` / `description: ...` / `---` block.
- [x] **Step 3: Commit.**

```bash
git add skills/woostack-harden/SKILL.md
git commit -m "feat: add woostack-harden skill"
```

## Task 2: Rewire `skills/woostack-build/SKILL.md`

**Files:** Modify `skills/woostack-build/SKILL.md`

- [x] **Step 1: Frontmatter `description`.** Change `Chains woostack-ideate, superpowers writing-plans/executing-plans, and grill-me in a fixed, gated order;` to `Chains woostack-ideate, woostack-harden, and superpowers writing-plans/executing-plans in a fixed, gated order;`.
- [x] **Step 2: Overview chain diagram.** In the chain on line ~15, change `grill-me` to `harden`:
  `ideate → write spec (markdown) → harden → approve spec → writing-plans → executing-plans → distill memory → ask: open PR?`
- [x] **Step 3: Dependency preflight.** In the "Dependency preflight" section: (a) drop `- `grill-me`` from the bullet list of chained external skills, leaving `superpowers:writing-plans`, `superpowers:executing-plans`; (b) remove `grill-me` from the prose that names the hardening phase as an external chain — state that the harden phase uses the in-collection `woostack-harden` (no install needed), mirroring the existing `woostack-ideate` note; (c) in the "offer to install" line, remove `pnpx skills add mattpocock/skills for grill-me`, keeping `pnpx skills add obra/superpowers`.
- [x] **Step 4: Procedure step 3 ("Harden it…").** Change `Invoke `grill-me` against the spec.` to `Invoke [`woostack-harden`](../woostack-harden/SKILL.md) against the spec.` and `until grilling stops producing new questions` to `until hardening stops producing new questions`. Leave the spec-approval HARD GATE that follows ("always present the written spec to the user and get explicit approval before planning") unchanged.
- [x] **Step 5: Verify the gate text survives.** Run: `grep -n "explicit approval before planning\|hard gate" skills/woostack-build/SKILL.md` — expect the spec-approval gate language still present.
- [x] **Step 6: Commit.**

```bash
git add skills/woostack-build/SKILL.md
git commit -m "feat: rewire woostack-build harden phase to woostack-harden"
```

## Task 3: Document the second internal sub-skill in `AGENTS.md`

**Files:** Modify `.claude/CLAUDE.md` (canonical; `.claude/CLAUDE.md` is the symlinked source-of-truth per the file's own note — edit the real file `AGENTS.md` content)

- [x] **Step 1: Sub-skill note.** Update the paragraph that begins "The collection also installs a ninth, internal sub-skill: `woostack-ideate`." to describe **two** internal sub-skills: `woostack-ideate` (build's ideate phase) and `woostack-harden` (build's harden phase). Keep the framing: building blocks, not `/woostack-*` commands; no routing row; absent from the eight-skill command surface; shipped assets like `action.yml`, not strays to delete.
- [x] **Step 2: Hard-constraint count.** Update the constraint "Do not move or rename any of the nine `SKILL.md` files (the eight public command/adoption skills plus the internal `woostack-ideate`)." to **ten** files — "the eight public command/adoption skills plus the internal `woostack-ideate` and `woostack-harden`".
- [x] **Step 3: Quick file map.** Add an entry under "Quick file map", parallel to the ideate entry:
  `- Hardening engine for the build loop (internal sub-skill): [`skills/woostack-harden/SKILL.md`](skills/woostack-harden/SKILL.md)`.
- [x] **Step 4: Verify.** Run: `grep -n "woostack-harden\|ten\|nine" .claude/CLAUDE.md` — expect the new sub-skill named, count updated to ten, no stray "nine".
- [x] **Step 5: Commit.**

```bash
git add .claude/CLAUDE.md AGENTS.md
git commit -m "docs: document woostack-harden as second internal sub-skill"
```

## Task 4: Update `README.md`, `CONTRIBUTING.md`, `development.md`

**Files:** Modify `README.md`, `CONTRIBUTING.md`, `skills/woostack-bootstrap/references/development.md`

- [x] **Step 1: README chain diagram.** Change the build-loop code block `ideate → markdown spec → grill → approve spec → plan → execute (TDD) → offer PR` to `ideate → markdown spec → harden → approve spec → plan → execute (TDD) → offer PR`.
- [x] **Step 2: README prose.** Change `with proven sub-skills (superpowers writing-plans/executing-plans + grill-me)` to credit the in-collection harden phase, e.g. `with woostack's own harden phase (`woostack-harden`) and proven superpowers sub-skills (writing-plans/executing-plans)`. Keep the Install/command surface at eight; `woostack-harden` is internal, not advertised as a command.
- [x] **Step 3: CONTRIBUTING build-loop row.** Change the row `Change the build loop (ideate→spec→grill→approve spec→plan→execute)` to `(ideate→spec→harden→approve spec→plan→execute)`.
- [x] **Step 4: CONTRIBUTING harden pointer row.** Add a row immediately after the "Change the ideate phase" row: `| Change the harden phase (the build loop's stress-test step) | `skills/woostack-harden/SKILL.md` |`.
- [x] **Step 5: development.md loop row.** Change the table row `| Ideate → markdown spec → grill → approve spec → plan → execute | `woostack-build` |` to `| Ideate → markdown spec → harden → approve spec → plan → execute | `woostack-build` |`.
- [x] **Step 6: Commit.**

```bash
git add README.md CONTRIBUTING.md skills/woostack-bootstrap/references/development.md
git commit -m "docs: update build-loop summaries for woostack-harden"
```

## Task 5: Verify

- [x] **Step 1: Grep for live grill-me.** Run: `grep -rn "grill-me\|grill me\|grilling" --include='*.md' --include='*.yml' --include='*.json' . | grep -v '.woostack/specs/' | grep -v '.woostack/plans/'` — expect **no** results outside historical `.woostack/specs|plans/` artifacts (the new harden spec/plan may reference grill-me descriptively; that is allowed).
- [x] **Step 2: Frontmatter + sections.** Run: `head -4 skills/woostack-harden/SKILL.md` (valid `name`/`description`) and `grep -n "Gate boundary\|Terminal state\|no new questions" skills/woostack-harden/SKILL.md` (terminal-state + gate-boundary statements present).
- [x] **Step 3: Cross-links.** Confirm `skills/woostack-build/SKILL.md` links `../woostack-harden/SKILL.md` and `.claude/CLAUDE.md` file-map links `skills/woostack-harden/SKILL.md`; both target files exist.
- [x] **Step 4: Counts.** Run: `ls skills/*/SKILL.md | wc -l` — expect 10. Confirm `AGENTS.md`/`README.md` still present an eight-skill public command/adoption surface and document two internal sub-skills.
- [x] **Step 5: Build-flow summaries.** Run: `grep -rn "harden" README.md CONTRIBUTING.md skills/woostack-bootstrap/references/development.md skills/woostack-build/SKILL.md` — expect every shipped loop summary now shows `harden` (and still `approve spec` before planning).

---

## Self-Review

**Spec coverage:** §4 approach (core loop, amend-in-place, terminal/hand-back, gate boundary) → Task 1. §4 wiring + §5 edit table → Tasks 2–4. §7 testing → Task 5. All spec sections map to a task.

**Placeholder scan:** Task 1 contains the complete SKILL.md content; doc edits give exact before/after strings. No TBD/TODO.

**Type consistency:** Skill name `woostack-harden`, phase label `harden`, link path `../woostack-harden/SKILL.md` used consistently across all tasks.
