---
type: plan
source: .woostack/specs/2026-06-04-woostack-execute.md
status: done
branch: feature/woostack-execute
---

**Source:** .woostack/specs/2026-06-04-woostack-execute.md


# woostack-execute Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. (woostack-execute does not exist yet — it is what this plan ships — so this plan is executed via the current build step 6, i.e. superpowers:executing-plans, as a single PR.)

**Goal:** Ship a woostack-native `woostack-execute` skill (public command #9) that executes an approved plan as PR-sized, stacked increments — each implemented with TDD, checkboxes ticked in place, committed via `woostack-commit` on its own Graphite branch, reviewed with `woostack-review --fast`, then distilled — pausing only on a blocking review and never merging. Rewire `woostack-build` step 6 + preflight to use it, fold build's distill step (7) into execute, and update the documentation surface (eight → nine public commands).

**Architecture:** One new self-contained skill file (`skills/woostack-execute/SKILL.md`) — no references dir. It keeps `superpowers:executing-plans`' load-bearing core (load plan, critical review, follow steps exactly, run verifications, stop-when-blocked) and adds the woostack PR cadence: PR-sized increments, per-increment implement → tick → commit → review → gate → distill, terminal "reviewed stack," and an explicit gate boundary (owns no approval gate). Seven existing docs are edited to rewire and document it as the ninth public command. Source: [.woostack/specs/2026-06-04-woostack-execute.md](../specs/2026-06-04-woostack-execute.md).

**Tech Stack:** Markdown skill files only. No code, no app build, no CI for this repo. No app test harness — verification is by inspection/grep.

**Decomposition (build step 5):** This is a single PR-sized increment (~well under 500 LOC). The skill, its build rewire, and the doc/count updates are coupled — shipping any subset leaves the docs or wiring inconsistent (README claims nine skills before the skill exists, or build still points at `executing-plans`). Executed as sequential tasks/commits on one branch (`feature/woostack-execute`) → one PR. (Once `woostack-execute` itself exists, future plans get its multiple-stacked-PRs cadence; this bootstrap plan cannot apply that to itself.)

**Out of scope (explicit):** Do NOT internalize `superpowers:writing-plans` (planning stays external). Do NOT make `woostack-execute` merge or auto-address findings. Do NOT rewrite historical `.woostack/specs|plans/*` `executing-plans` references. Do NOT move/rename any existing `SKILL.md`. Do NOT add app code, lockfiles, or CI. Do NOT touch `woostack-status` (out of this change's surface).

---

## File Structure

- **Create** `skills/woostack-execute/SKILL.md` — scoped discovery frontmatter, required `<plan-path>` command, load/critical-review, PR-sized increments, per-increment cadence (implement → tick → commit → review → gate → distill), terminal state, stop-and-ask, gate boundary, hard constraints.
- **Modify** `skills/woostack-build/SKILL.md` — frontmatter `description`, Overview chain diagram, dependency preflight, step 6 (delegate to execute), remove step 7 (distill folded into execute), reword step 8 → "ends on reviewed stack," hard-constraints touch-ups.
- **Modify** `skills/using-woostack/SKILL.md` — add a Command Routing row for `/woostack-execute <plan-path>`.
- **Modify** `.claude/CLAUDE.md` (= `AGENTS.md`, symlinked) — eight → nine public commands; ten → eleven `SKILL.md` files; add to public list + Quick file map; delete-protect.
- **Modify** `README.md` — line 29 eight → nine + fix stale internal-sub-skill mention (ideate **and** harden); line 62 build-loop prose (`executing-plans` → `execute`, PR cadence → multiple stacked PRs / reviewed stack).
- **Modify** `CONTRIBUTING.md` — add "Change the execute phase" pointer row.
- **Modify** `skills/woostack-bootstrap/references/development.md` — verify loop summary (already `…plan → execute`); expected no-op.
- **Modify** `skills/woostack-ideate/SKILL.md` — minor: add `woostack-execute` to the "do not chain" example list.

---

## Task 1: Create `skills/woostack-execute/SKILL.md`

**Files:** Create `skills/woostack-execute/SKILL.md`

- [x] **Step 1: Write the full skill file.** Author the file with exactly this content:

```markdown
---
name: woostack-execute
description: Use to execute an approved woostack plan as a sequence of PR-sized, stacked increments — implement each increment with TDD, tick the plan's checkboxes in place, commit via woostack-commit on its own Graphite branch, review it with woostack-review --fast, distill durable learnings, then continue. This is the execute phase of the woostack build loop (woostack-build step 6); also usable standalone via /woostack-execute <plan-path>. One plan per spec, multiple PRs per plan. Never merges.
---

# woostack-execute

Execute an approved plan by driving it to implementation as a sequence of PR-sized, stacked
increments. This is woostack's own execution phase — [`woostack-build`](../woostack-build/SKILL.md)
step 6. It keeps the discipline that makes plan execution reliable (load the plan, review it
critically, follow steps exactly, run verifications, stop when blocked) and adds the woostack PR
cadence: **one plan per spec, multiple stacked PRs per plan**, each increment committed,
reviewed, and distilled before the next. It never merges and owns no approval gate.

## Commands

- `/woostack-execute <plan-path>` — execute the named markdown plan under `.woostack/plans/`.
  **The plan path is required.**
- `/woostack-execute` (no argument) — do **not** guess "the current plan." Ask which plan to
  execute (optionally list `.woostack/plans/` candidates) and stop until one is named.

When `woostack-build` reaches step 6 it invokes this skill with the plan path it wrote in step 4.

## Load and review the plan

1. Read the plan file.
2. Review it critically — surface any questions or concerns about the plan, the spec it traces
   to, or the increment breakdown.
3. If there are concerns: raise them with the user before starting.
4. If none: proceed.

Never start implementation on a protected branch (`main`/`staging`/`beta`/`alpha`);
`woostack-commit` enforces this when it creates each increment's branch.

## PR-sized increments

Implement the plan as a sequence of independently shippable increments — preferably ≤500 LOC
each (a soft target, not a gate). When `woostack-build` invoked this skill, its step 5 already
decomposed the plan into increments. When run standalone, perform the same decomposition:
structure the work as increments, flag any slice that can't reasonably stay under the target,
and propose a split before executing it. Genuinely atomic changes may exceed the target.

Run **one increment per cycle**, in order.

## Per-increment cadence

For each increment:

1. **Implement** its tasks with TDD. Where the host supports subagents, prefer
   `superpowers:subagent-driven-development`; otherwise `superpowers:test-driven-development`
   (recommended enhancements, not hard dependencies — follow the principle if either is absent).
   Follow each plan step exactly and run the verifications the plan specifies.
2. **Tick the plan's checkboxes in place.** Edit the markdown plan, `[ ]` → `[x]`, as each step
   or task completes, so the plan file is the live progress record.
3. **Commit** via [`woostack-commit`](../woostack-commit/SKILL.md) on a fresh Graphite-stacked
   feature branch (`gt create`) — one branch + PR per increment. This is the "multiple PRs per
   plan" shape.
4. **Review** the resulting PR with [`woostack-review`](../woostack-review/SKILL.md)` --fast`.
5. **Gate on the review:** if it returns REQUEST_CHANGES (a blocking finding), **stop** and
   surface the findings — the user decides (typically via
   [`woostack-address-comments`](../woostack-address-comments/SKILL.md)). If it is clean or
   non-blocking, continue.
6. **Distill** the increment's durable, reusable learnings into `.woostack/memory/` per the
   [memory contract](../woostack-init/references/memory.md): one fact per file, `type` one of
   `pattern|decision|gotcha|convention`, the narrowest `scope` glob covering the touched files,
   `source` the spec/plan path. Apply the **reject-by-default distillation gate**
   ([memory contract §7](../woostack-init/references/memory.md#7-distillation-write-path)) —
   dedupe against `.woostack/memory/MEMORY.md` first, reject trivia / source-less /
   near-duplicate notes, and stamp `updated:` on every note you write. Then run `woostack-init`'s
   `build-index.sh` and `doctor.sh`; fix any error. When the store does not exist, skip (or offer
   `/woostack-init` first). Distill only cross-feature knowledge, never feature-specific trivia.

Then advance to the next increment.

## Terminal state: a reviewed stack

Stop when every increment is implemented, checked off, committed, reviewed, and distilled —
leaving a Graphite stack of reviewed PRs. Report the branches/PRs and their review verdicts.
**Never merge.**

## When to stop and ask

Stop immediately and ask — never guess — when:

- A blocker hits (missing dependency, failing verification, unclear instruction).
- The plan has critical gaps preventing a start.
- A verification fails repeatedly.
- A review returns REQUEST_CHANGES — handle the findings before continuing.

Return to the plan-review step if the plan is updated or the approach needs rethinking.

## Gate boundary

This skill owns **no approval gate**. `woostack-build` keeps the design-approval and
spec-approval HARD GATES upstream; execute inherits gates and adds none. Per-increment commit,
review, and distill are work steps; the pause on REQUEST_CHANGES is a blocker stop, not an
approval gate. The skill never merges and never auto-addresses review findings.

## Hard constraints

- **Plan path required.** Never guess "the current plan"; ask when no argument is given.
- **One increment per cycle.** Don't let a cycle balloon past a reviewable PR.
- **Multiple stacked PRs per plan.** Each increment is its own `gt`-stacked branch + PR via
  `woostack-commit`.
- **Tick checkboxes in place.** The plan file is the live progress record.
- **Commit + review every increment.** `woostack-commit`, then `woostack-review --fast`; pause on
  REQUEST_CHANGES.
- **Distill durable knowledge only.** Reject-by-default; dedupe; never feature-specific trivia.
- **Never merge, never force-push, never start on a protected branch.**
- **Own no gate; never auto-address findings.**
```

- [x] **Step 2: Verify frontmatter parses.** Run: `head -4 skills/woostack-execute/SKILL.md` — expect `---` / `name: woostack-execute` / `description: ...` / `---`.
- [x] **Step 3: Verify key sections present.** Run: `grep -n "Per-increment cadence\|Gate boundary\|Terminal state\|Plan path required\|Never merge" skills/woostack-execute/SKILL.md` — expect cadence, gate boundary, terminal, and the required-arg / never-merge constraints.

## Task 2: Rewire `skills/woostack-build/SKILL.md`

**Files:** Modify `skills/woostack-build/SKILL.md`

- [x] **Step 1: Frontmatter `description`.** Change `Chains woostack-ideate, woostack-harden, and superpowers writing-plans/executing-plans in a fixed, gated order;` to `Chains woostack-ideate, woostack-harden, woostack-execute, and superpowers writing-plans in a fixed, gated order;`.
- [x] **Step 2: Overview chain diagram (line ~15).** Change `ideate → write spec (markdown) → harden → approve spec → writing-plans → executing-plans → distill memory → ask: open PR?` to `ideate → write spec (markdown) → harden → approve spec → writing-plans → execute (per increment: implement → commit → review → distill) → reviewed PR stack`.
- [x] **Step 3: Dependency preflight.** Update the section so the execution phase is in-collection: change the intro to name the ideate, hardening, **and execution** phases as `woostack-ideate`, `woostack-harden`, and `woostack-execute` (ship in this collection — no install needed), and state that only the **plan** phase chains an external skill. In the check list, change `- superpowers:writing-plans, superpowers:executing-plans` to `- superpowers:writing-plans`. The "offer to install … `pnpx skills add obra/superpowers`" fallback stays (writing-plans still ships there).
- [x] **Step 4: Procedure step 6 (Execute).** Change `Invoke superpowers:executing-plans (or superpowers:subagent-driven-development) to work the plan with TDD and frequent commits.` to: invoke [`woostack-execute`](../woostack-execute/SKILL.md) to work the plan as PR-sized stacked increments — each implemented with TDD, the plan's checkboxes ticked in place, committed via `woostack-commit`, reviewed with `woostack-review --fast`, and distilled — pausing only on a blocking review. Execute owns the per-increment commit/review/distill cadence.
- [x] **Step 5: Remove old step 7 (Distill memory).** Delete the standalone "**Distill memory.**" procedure step (the whole numbered item that describes extracting durable learnings, the reject-by-default gate, `build-index.sh`/`doctor.sh`) — this is now folded into `woostack-execute`'s per-increment cadence (referenced from step 6). Renumber the following step accordingly.
- [x] **Step 6: Reword final step (was step 8, "Offer the PR").** Replace it with an "**End on the reviewed stack.**" step: `woostack-execute` opens a PR per increment via `woostack-commit` as part of execution, so build does not separately ask to open a PR; build ends on the reviewed Graphite stack and never merges.
- [x] **Step 7: Hard-constraints touch-ups.** (a) Change `Never merge. build ends by offering a PR, nothing further.` to `Never merge. build ends on the reviewed PR stack, nothing further.` (b) Change the "Distill durable knowledge only." bullet so it credits execute: e.g. `woostack-execute writes scoped, deduplicated memory notes per increment — never feature-specific trivia, never a duplicate of an existing note.` Leave the two HARD GATE constraints (design approval step 1, spec approval step 3) and "One increment per cycle" unchanged.
- [x] **Step 8: Verify gate text + new wiring survive.** Run: `grep -n "explicit approval before planning\|woostack-execute\|executing-plans\|distill" skills/woostack-build/SKILL.md` — expect the spec-approval gate language intact, `woostack-execute` named in preflight + step 6, and **no** remaining `executing-plans`.

## Task 3: Add the `using-woostack` routing row

**Files:** Modify `skills/using-woostack/SKILL.md`

- [x] **Step 1: Command Routing row.** In the Command Routing table, add a row (after the `/woostack-build` row, before `/woostack-commit`, or grouped logically): `| `/woostack-execute <plan-path>`, execute an approved plan as PR-sized stacked increments | `woostack-execute` |`.
- [x] **Step 2: Verify.** Run: `grep -n "woostack-execute" skills/using-woostack/SKILL.md` — expect the new routing row.

## Task 4: Document the ninth public command in `AGENTS.md`

**Files:** Modify `.claude/CLAUDE.md` (canonical via the symlink note; edit the `AGENTS.md` content)

- [x] **Step 1: Public-skill count + list (line ~16).** Change "The public command/adoption surface has eight skills:" to "nine skills:" and add a bullet `- [`woostack-execute`](skills/woostack-execute/SKILL.md)` to the list (logical spot: after `woostack-build`).
- [x] **Step 2: Internal-sub-skill paragraph (line ~31).** Where it says the two internal sub-skills "are bundled building blocks, not `/woostack-*` commands … absent from the eight-skill command surface above" — change "eight-skill" to "nine-skill". (The internal list stays two: ideate + harden.)
- [x] **Step 3: Hard-constraint count (line ~75).** Change "Do not move or rename any of the ten `SKILL.md` files (the eight public command/adoption skills plus the internal `woostack-ideate` and `woostack-harden`)." to "eleven `SKILL.md` files (the nine public command/adoption skills plus the internal `woostack-ideate` and `woostack-harden`)".
- [x] **Step 4: Quick file map.** Add an entry parallel to the build-loop entries: `- Plan-execution engine for the build loop: [`skills/woostack-execute/SKILL.md`](skills/woostack-execute/SKILL.md)`.
- [x] **Step 5: Verify.** Run: `grep -n "woostack-execute\|nine\|eleven\|eight\|ten " .claude/CLAUDE.md` — expect execute named, counts updated to nine/eleven, no stray "eight-skill"/"ten `SKILL.md`".
- [x] **Step 6: Confirm symlink integrity.** Run: `ls -l .claude/CLAUDE.md` (symlink → `../AGENTS.md`) and `diff .claude/CLAUDE.md AGENTS.md` — expect identical content (one edit, both paths reflect it).

## Task 5: Update `README.md`

**Files:** Modify `README.md`

- [x] **Step 1: Public list + count (line ~29).** Change "The public command/adoption surface is eight skills: …, and woostack-visualize." to nine, adding `woostack-execute` to the list. **Fix the stale internal-sub-skill mention:** change "The collection also installs `woostack-ideate`, an internal sub-skill used by `woostack-build`; it is not a `/woostack-*` command." to name **both** internal sub-skills — `woostack-ideate` and `woostack-harden` — used by `woostack-build`; neither is a `/woostack-*` command.
- [x] **Step 2: Build-loop prose (line ~62).** Change "with proven superpowers sub-skills (writing-plans/executing-plans)" to credit execute as woostack's own — e.g. "with woostack's own execute phase (`woostack-execute`) and the superpowers `writing-plans` sub-skill". Change the cadence wording "Work is steered toward reviewable PRs (soft target ≤500 LOC), one increment per cycle. It ends by *offering* a PR. It never merges." to reflect the new shape: "Work ships as PR-sized stacked increments (soft target ≤500 LOC) — one plan per spec, multiple PRs per plan — each committed, reviewed (`woostack-review --fast`), and distilled. It ends on the reviewed PR stack. It never merges."
- [x] **Step 3: Verify.** Run: `grep -n "woostack-execute\|woostack-harden\|executing-plans\|eight\|nine" README.md` — expect nine public, execute + harden named, no live `executing-plans` credit, no stray "eight".

## Task 6: Update `CONTRIBUTING.md` + verify `development.md`

**Files:** Modify `CONTRIBUTING.md`; verify `skills/woostack-bootstrap/references/development.md`

- [x] **Step 1: CONTRIBUTING execute pointer row.** Add a row immediately after the "Change the harden phase" row (line ~23): `| Change the execute phase (the build loop's implementation step) | `skills/woostack-execute/SKILL.md` |`. (The loop summary on line ~21 already reads `…→ plan → execute` — no change there.)
- [x] **Step 2: development.md check.** (No-op confirmed: loop summary already `…plan → execute`; no stale `executing-plans`/cadence ref.) Run: `grep -n "executing-plans\|execute\|offer" skills/woostack-bootstrap/references/development.md`. The loop summary already reads `Ideate → markdown spec → harden → approve spec → plan → execute`. Edit **only** if a stale `executing-plans` or "offer PR" cadence reference appears; otherwise no-op.
- [x] **Step 3: Verify.** Run: `grep -n "execute phase\|woostack-execute" CONTRIBUTING.md` — expect the new pointer row.

## Task 7: Minor consistency touch in `woostack-ideate`

**Files:** Modify `skills/woostack-ideate/SKILL.md`

- [x] **Step 1: Don't-chain example list.** On the "Chain nothing" line (~34), change `Do not invoke `writing-plans`, `executing-plans`, or any implementation skill` to `Do not invoke `writing-plans`, `woostack-execute`, or any implementation skill` (execute is now woostack's implementation command; this is illustrative, so the swap keeps it current without over-listing).
- [x] **Step 2: Verify.** Run: `grep -n "Chain nothing\|woostack-execute" skills/woostack-ideate/SKILL.md`.

## Task 8: Final verification

- [x] **Step 1: No live `executing-plans` outside history.** (Confirmed: shipped docs + skills SKILL.md = 0; all matches are `.woostack/` history + this feature's spec/plan "borrows-from" framing.) Run: `grep -rn "executing-plans" --include='*.md' --include='*.yml' . | grep -v '^./.woostack/'` — expect results limited to historical refs and the deliberate `superpowers:executing-plans` mentions in the new `woostack-execute`/`woostack-build` prose where they describe what was borrowed (audit each: build preflight + step 6 must NOT credit executing-plans as the execution engine; only `woostack-execute`/`README` "borrows from" framing or the ideate list — confirm none re-introduce it as the active execute phase).
- [x] **Step 2: SKILL.md count.** (11 = 9 public + 2 internal; `woostack-status` has no SKILL.md; execute present.) Run: `ls skills/*/SKILL.md | wc -l` — note the count (10 existing public/internal + woostack-status if it has a SKILL.md; the new file makes +1). Confirm `woostack-execute/SKILL.md` is present.
- [x] **Step 3: Counts consistent.** Confirm `AGENTS.md` (nine public, eleven SKILL.md), `README.md` (nine public, both internal sub-skills named), `using-woostack` (execute routing row), `CONTRIBUTING.md` (execute pointer row) all agree.
- [x] **Step 4: Cross-links resolve.** Confirm `woostack-build` ↔ `woostack-execute`, and `woostack-execute` → `woostack-commit`/`woostack-review`/`woostack-address-comments`/`woostack-init` all target existing files.
- [x] **Step 5: Loop summaries.** Run: `grep -rn "execute" README.md CONTRIBUTING.md skills/woostack-bootstrap/references/development.md skills/woostack-build/SKILL.md` — expect each loop summary shows the execute phase and still shows `approve spec` before planning.

---

## Self-Review

**Spec coverage:** §4 approach (commands, load/review, PR-sized increments, per-increment cadence incl. distill, terminal, gate boundary) → Task 1. §4 wiring `woostack-build` → Task 2. §5 edit table (using-woostack, AGENTS, README, CONTRIBUTING, development.md, ideate) → Tasks 3–7. §7 testing → Task 8. All spec sections map to a task.

**Placeholder scan:** Task 1 contains the complete SKILL.md content; doc edits give exact before/after strings. No TBD/TODO.

**Type consistency:** Skill name `woostack-execute`, phase label `execute`, link path `../woostack-execute/SKILL.md`, command `/woostack-execute <plan-path>` used consistently across all tasks.

**Increment shape:** One PR (this bootstrap plan), sequential commits per task on `feature/woostack-execute`. Once shipped, `woostack-execute`'s own cadence (multiple stacked PRs per plan) applies to future plans.
