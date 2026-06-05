---
name: woostack-build
description: Use when building a feature with the full woostack development loop — ideate a design, harden it, plan it, harden the plan, ship the spec and plan as their own PR, then implement it. Chains woostack-ideate, woostack-harden, woostack-plan, woostack-commit, and woostack-execute in a fixed, gated order; writes markdown specs and plans under .woostack/.
---

# woostack-build

## Overview

Drives one feature from idea to implementation through a fixed, gated chain. Thin
glue: it sequences proven sub-skills, **inherits their two gates** (design, spec) **and
adds exactly one of its own** — the execution handoff — because the plan→execute boundary
belongs to no sub-skill. The value is the order and the handoffs.

```
ideate → write spec (markdown) → harden spec → approve spec → plan → verify decomposition
  → harden plan → commit spec+plan as their own PR → stop before execute (handoff gate)
  → execute (per increment: implement → commit → review → distill) → reviewed PR stack
```

Three of those gates are hard stops where the user must say yes before the chain advances:
**design approval** (owned by `woostack-ideate`, step 1), **spec approval** (step 3), and the
**execution handoff** (step 8). The spec-approval gate is the "user reviews the written spec"
step that the ideate phase historically owned; because woostack-build relocated the spec
write into its own step 2, the gate lives here now — relocating an inherited gate is not adding
one. The execution-handoff gate is build's own: no sub-skill owns the plan→execute boundary, so
build adds it to let you stop after planning and execute later or elsewhere.

Hardening runs **twice** — once on the spec (step 3) and once on the plan (step 6) — but only
the spec harden feeds a gate (the spec-approval gate, step 3). The plan harden amends the plan
in place and hands straight back, and committing the spec+plan PR (step 7) is a work step, not
an approval stop. The execution-handoff gate (step 8) is build-owned, not harden-owned, and
sits after that PR. So the chain has exactly the three hard gates above.

## Procedure

1. **Ideate.** Invoke [`woostack-ideate`](../woostack-ideate/SKILL.md) to explore
   the problem and converge on a design. Let it run its own approval gate. It hands back an
   approved design and stops there — it writes no spec and chains no plan, so the next steps
   are yours to drive.
2. **Write the spec as markdown.** When the design is approved, do **not** write to a generic
   `docs/specs/` location. Instead author a markdown spec to
   `.woostack/specs/YYYY-MM-DD-<slug>.md`, populating
   [references/spec-template.md](references/spec-template.md). Markdown specs are the source
   of truth: they carry `type: spec` frontmatter, are Obsidian vault nodes that can `[[link]]`
   memory notes, and are excluded from memory recall routing by type. **Visualize on demand** —
   if a rich view is wanted, hand the markdown to
   [`woostack-visualize`](../woostack-visualize/SKILL.md) (audience `engineer` for specs; it
   uses [references/spec-template.html](references/spec-template.html) as a starting point).
   The HTML is a presentation target only, never the authored source. Set the spec's
   `status: draft` in frontmatter — the build loop owns the `status:` enum and authors a
   transition at each step so `/woostack-status` can read it (the enum and join contracts live
   in [`../woostack-status/references/conventions.md`](../woostack-status/references/conventions.md);
   link it, do not restate it).
3. **Harden the spec, then get spec approval.** Invoke
   [`woostack-harden`](../woostack-harden/SKILL.md) against the spec. Amend the spec
   in place until hardening stops producing new questions, then set `status: hardened`. Then
   **always present the written spec to the user and get explicit approval before planning** —
   this is a hard gate. Point the user at the file path (offer a `woostack-visualize` render if
   it helps), wait for a clear yes, and make any requested changes before advancing. When the
   gate clears, set `status: approved`. Do **not** proceed to step 4 on inferred or assumed
   approval; silence is not a yes.
4. **Plan.** Once the spec is approved, invoke
   [`woostack-plan`](../woostack-plan/SKILL.md) with the approved spec path. It writes the
   plan to `.woostack/plans/<spec-basename>.md` (same basename as the spec), opens with the
   `**Source:** .woostack/specs/<file>.md` line so the board joins it 1:1, stays
   frontmatter-free, structures it as PR-sized increments, and sets the spec's
   `status: planning`. It writes the plan and hands back, owning no gate. `woostack-plan`
   ships in this collection, so the build loop has no external skill dependencies.
5. **Verify the increment decomposition.** `woostack-plan` already structures the plan as
   PR-sized increments; build confirms the increment boundaries are reviewable, independently
   shippable, and feed cleanly into `woostack-execute`. Flag any slice that is not reviewable
   or independently shippable and propose a further split before executing. The
   `spec : plan : PRs = 1 : 1 : N` invariant holds throughout: exactly one plan per spec, and
   that one plan owns the N increment PRs.
6. **Harden the plan.** Invoke [`woostack-harden`](../woostack-harden/SKILL.md) again, this
   time against the plan and its increment breakdown — stress-test the sequencing, the
   increment boundaries, and the verifications until hardening stops producing new questions.
   Amend the plan markdown in place as answers land. This adds **no approval gate**: harden
   owns none and hands straight back. The chain's last hard stop is the **execution-handoff
   gate (step 8)**, after the spec+plan PR — not a plan-*quality* gate here. Do not turn this
   harden into a plan-approval gate.
7. **Commit the spec and plan as their own PR.** Before any implementation, commit the
   `.woostack/` spec and plan via [`woostack-commit`](../woostack-commit/SKILL.md) on a fresh
   Graphite branch and open a PR. This docs-only PR is the **base of the stack** — execution
   increments (step 9) stack on top of it via `gt create`. It carries no code and is **never
   merged** by build. This is a work step, not an approval stop.
8. **Stop before execute (execution-handoff gate).** After the spec+plan PR is open, **halt** —
   this is a hard gate. Surface the handoff artifacts: the plan path (`.woostack/plans/…`), the
   spec+plan PR URL, and — on request — a
   [`woostack-visualize`](../woostack-visualize/SKILL.md) render of the plan (audience
   `engineer`). Then ask the user to choose:
   - **Go** → proceed to step 9 and run `woostack-execute` in this session.
   - **Hand off** → stop here. The user takes the plan PR and executes later or elsewhere (e.g.
     Codex, or a fresh session via `/woostack-execute <plan-path>`).
   Ambiguous or no answer is **not** a "go": never auto-run execute without an explicit
   go-ahead. This is the chain's last hard gate.
9. **Execute.** Invoke [`woostack-execute`](../woostack-execute/SKILL.md) with the plan path to
   work the plan as PR-sized stacked increments on top of the spec+plan PR — each implemented
   with TDD, the plan's checkboxes ticked in place, committed via `woostack-commit`, reviewed per
   the execution mode `woostack-execute` selects (`woostack-review --fast` in inline mode, or the
   per-task spec+quality subagent loops in the default subagent mode), and distilled into
   `.woostack/memory/` — pausing only on a blocking stop. `woostack-execute` owns the
   per-increment commit/review/distill cadence and the inline-vs-subagent mode choice (one plan
   per spec, multiple stacked PRs per plan), so it absorbs what used to be separate "distill
   memory" and "offer the PR" steps here. As branches, commits, and increment PRs appear the
   spec advances into the `executing` → `in-review` band (and `done` post-merge); the board
   **computes** that band from the artifacts via its truth table, so a lagging authored
   `status:` is reconciled rather than trusted blindly.
10. **End on the chosen terminal state.** Build ends in one of two shapes, never merging either:
    - **Hand off** → only the spec+plan PR is open (no increment PRs), ready for external or
      later execute.
    - **Go** → a Graphite stack with the spec+plan PR at the base and a reviewed increment PR
      above each step.
    Build does not separately ask to open a PR (step 7 and `woostack-execute` open them as work
    steps) and **never merges**.

## Hard constraints

- **Inherit two gates, add one.** Do not insert *extra* approval stops beyond the three hard
  gates: **design approval** (step 1) and **spec approval** (step 3), both inherited, plus the
  **execution handoff** (step 8), which build owns because the plan→execute boundary belongs to
  no sub-skill. The plan harden (step 6) and the spec+plan PR (step 7) are work steps, not gates.
- **Harden twice, neither harden gates.** Harden the spec (step 3, feeds the spec-approval gate)
  and the plan (step 6, amends in place, no gate). The execution-handoff gate (step 8) is
  separate and build-owned, not a plan-*quality* gate; never turn the plan harden into a
  plan-approval gate.
- **Always get explicit spec approval before planning.** After the spec harden, present the
  written spec and wait for the user's clear yes. Never advance to `woostack-plan` on assumed
  or inferred approval.
- **Markdown specs and plans, under `.woostack/`.** Never write specs to a generic location
  outside `.woostack/`. HTML is a render-on-demand target only, not the authored format.
- **Spec+plan ship as their own PR before execution.** Commit the spec and plan as a docs-only
  PR (step 7) — the base of the stack — before any implementation begins. Never merge it.
- **Stop before execute.** Never auto-run execute; always halt at the execution-handoff gate
  (step 8) after the spec+plan PR. The plan PR is the artifact for executing here or in another
  tool. Ambiguous or no answer is not a "go."
- **Never merge.** build ends on the terminal state (handoff PR, or reviewed stack), nothing
  further.
- **Author `status:` through the loop.** Set the spec's `status:` at each step — `draft` (step
  2), `hardened` then `approved` (step 3), `planning` (step 4, authored by woostack-plan); the
  execute phase advances the `executing`/`in-review` band, which the board also computes from
  artifacts. The phase enum and the `spec : plan : PRs = 1 : 1 : N` join contracts are defined once in
  [`../woostack-status/references/conventions.md`](../woostack-status/references/conventions.md) —
  link it, never restate it.
- **One increment per cycle.** Do not let a single build cycle balloon past a reviewable PR.
- **Distill durable knowledge only.** `woostack-execute` writes scoped, deduplicated memory
  notes per increment — never feature-specific trivia, never a duplicate of an existing note. A
  small curated store beats a large noisy one.
