---
name: woostack-build
description: Use when building a feature with the full woostack development loop — ideate a design, harden it, plan it, harden the plan, ship the spec and plan as their own PR, then implement it. Chains woostack-ideate, woostack-harden, woostack-commit, woostack-execute, and superpowers writing-plans in a fixed, gated order; writes markdown specs and plans under .woostack/.
---

# woostack-build

## Overview

Drives one feature from idea to implementation through a fixed, gated chain. Thin
glue: it sequences proven sub-skills, **inherits their two gates** (design, spec) **and
adds exactly one of its own** — the execution handoff — because the plan→execute boundary
belongs to no sub-skill. The value is the order and the handoffs.

```
ideate → write spec (markdown) → harden spec → approve spec → writing-plans → decompose
  → harden plan → commit spec+plan as their own PR → stop before execute (handoff gate)
  → execute (per increment: implement → commit → review → distill) → reviewed PR stack
```

Three of those gates are hard stops where the user must say yes before the chain advances:
**design approval** (owned by `woostack-ideate`, step 1), **spec approval** (step 3), and the
**execution handoff** (step 8). The spec-approval gate is the "user reviews the written spec"
step that `superpowers:brainstorming` used to own; because woostack-build relocated the spec
write into its own step 2, the gate lives here now — relocating an inherited gate is not adding
one. The execution-handoff gate is build's own: no sub-skill owns the plan→execute boundary, so
build adds it to let you stop after planning and execute later or elsewhere.

Hardening runs **twice** — once on the spec (step 3) and once on the plan (step 6) — but only
the spec harden feeds a gate (the spec-approval gate, step 3). The plan harden amends the plan
in place and hands straight back, and committing the spec+plan PR (step 7) is a work step, not
an approval stop. The execution-handoff gate (step 8) is build-owned, not harden-owned, and
sits after that PR. So the chain has exactly the three hard gates above.

## Dependency preflight

The ideate, hardening (spec and plan), spec+plan-commit, and execution phases use
[`woostack-ideate`](../woostack-ideate/SKILL.md),
[`woostack-harden`](../woostack-harden/SKILL.md),
[`woostack-commit`](../woostack-commit/SKILL.md), and
[`woostack-execute`](../woostack-execute/SKILL.md), which ship in this collection — no install
needed. Only the plan phase chains an external skill. At the start, check that it is installed:

- `superpowers:writing-plans`

If it is missing: name exactly what's missing and **offer to install it inline**
(`pnpx skills add obra/superpowers`) and continue. If the user declines, fall back to
following the skill's principle manually and **say so explicitly** — the run is degraded, not
equivalent.

## Procedure

1. **Ideate.** Invoke [`woostack-ideate`](../woostack-ideate/SKILL.md) to explore
   the problem and converge on a design. Let it run its own approval gate. It hands back an
   approved design and stops there — it writes no spec and chains no plan, so the next steps
   are yours to drive.
2. **Write the spec as markdown.** When the design is approved, do **not** write to the
   superpowers default `docs/superpowers/specs/`. Instead author a markdown spec to
   `.woostack/specs/YYYY-MM-DD-<slug>.md`, populating
   [references/spec-template.md](references/spec-template.md). Markdown specs are the source
   of truth: they carry `type: spec` frontmatter, are Obsidian vault nodes that can `[[link]]`
   memory notes, and are excluded from memory recall routing by type. **Visualize on demand** —
   if a rich view is wanted, hand the markdown to
   [`woostack-visualize`](../woostack-visualize/SKILL.md) (audience `engineer` for specs; it
   uses [references/spec-template.html](references/spec-template.html) as a starting point).
   The HTML is a presentation target only, never the authored source.
3. **Harden the spec, then get spec approval.** Invoke
   [`woostack-harden`](../woostack-harden/SKILL.md) against the spec. Amend the spec
   in place until hardening stops producing new questions. Then **always present the written
   spec to the user and get explicit approval before planning** — this is a hard gate. Point
   the user at the file path (offer a `woostack-visualize` render if it helps), wait for a
   clear yes, and make any requested changes before advancing. Do **not** proceed to step 4
   on inferred or assumed approval; silence is not a yes.
4. **Plan.** Once the spec is approved, invoke `superpowers:writing-plans`, saving the plan as
   **markdown** to
   `.woostack/plans/YYYY-MM-DD-<slug>.md` (plans are working checklists, not visualization
   artifacts).
5. **Decompose to PR-sized increments.** Steer work toward well-scoped PRs of **preferably
   ≤500 lines of code** — a soft target, not a gate. When the spec implies more than one
   reviewable PR, structure the plan as a sequence of independently shippable increments and
   run **one increment per build cycle**. Flag any slice that can't reasonably stay under the
   target and propose a further split before executing. Genuinely atomic changes may exceed
   the target.
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
   memory" and "offer the PR" steps here.
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
  written spec and wait for the user's clear yes. Never advance to `writing-plans` on assumed
  or inferred approval.
- **Markdown specs and plans, under `.woostack/`.** Never write specs to the superpowers
  default location. HTML is a render-on-demand target only, not the authored format.
- **Spec+plan ship as their own PR before execution.** Commit the spec and plan as a docs-only
  PR (step 7) — the base of the stack — before any implementation begins. Never merge it.
- **Stop before execute.** Never auto-run execute; always halt at the execution-handoff gate
  (step 8) after the spec+plan PR. The plan PR is the artifact for executing here or in another
  tool. Ambiguous or no answer is not a "go."
- **Never merge.** build ends on the terminal state (handoff PR, or reviewed stack), nothing
  further.
- **One increment per cycle.** Do not let a single build cycle balloon past a reviewable PR.
- **Distill durable knowledge only.** `woostack-execute` writes scoped, deduplicated memory
  notes per increment — never feature-specific trivia, never a duplicate of an existing note. A
  small curated store beats a large noisy one.
