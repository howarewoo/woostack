---
name: woostack-build
description: Use when building a feature with the full woostack development loop — brainstorm a design, harden it, plan it, and implement it. Chains superpowers (brainstorming, writing-plans, executing-plans) and grill-me in a fixed, gated order; writes HTML specs and markdown plans under .woostack/.
---

# woostack-build

## Overview

Drives one feature from idea to implementation through a fixed, gated chain. Thin
glue: it sequences proven sub-skills and **inherits their gates** — it adds none of
its own. The value is the order and the handoffs.

```
brainstorming → write spec (HTML) → grill-me → writing-plans → executing-plans → ask: open PR?
```

## Dependency preflight

This skill chains external skills. At the start, check that each is installed:

- `superpowers:brainstorming`, `superpowers:writing-plans`, `superpowers:executing-plans`
- `grill-me`

For any that are missing: name exactly what's missing and **offer to install it inline**
(`npx skills add obra/superpowers`, `npx skills add mattpocock/skills` for grill-me) and
continue. If the user declines, fall back to following the skill's principle manually and
**say so explicitly** — the run is degraded, not equivalent.

## Procedure

1. **Brainstorm.** Invoke `superpowers:brainstorming` to explore the problem and converge
   on a design. Let it run its own approval gate.
2. **Write the spec as HTML.** When the design is approved, do **not** write the default
   markdown to `docs/superpowers/specs/`. Instead author a self-contained HTML spec to
   `.woostack/specs/YYYY-MM-DD-<slug>.html`, populating
   [references/spec-template.html](references/spec-template.html). HTML is for
   visualization — richer than markdown.
3. **Harden it.** Invoke `grill-me` against the HTML spec. Amend the spec in place until
   grilling stops producing new questions.
4. **Plan.** Invoke `superpowers:writing-plans`, saving the plan as **markdown** to
   `.woostack/plans/YYYY-MM-DD-<slug>.md` (plans are working checklists, not visualization
   artifacts).
5. **Decompose to PR-sized increments.** Steer work toward well-scoped PRs of **preferably
   ≤500 lines of code** — a soft target, not a gate. When the spec implies more than one
   reviewable PR, structure the plan as a sequence of independently shippable increments and
   run **one increment per build cycle**. Flag any slice that can't reasonably stay under the
   target and propose a further split before executing. Genuinely atomic changes may exceed
   the target.
6. **Execute.** Invoke `superpowers:executing-plans` (or `superpowers:subagent-driven-development`)
   to work the plan with TDD and frequent commits.
7. **Offer the PR.** When the increment lands on the branch, **ask** whether to open a PR. If
   yes, open it (hands off to `woostack-review`). If no, stop on the branch.

## Hard constraints

- **Inherit gates, add none.** Do not insert extra approval stops between phases.
- **HTML specs, markdown plans, under `.woostack/`.** Never write specs to the superpowers
  default location or format.
- **Never merge.** build ends by offering a PR, nothing further.
- **One increment per cycle.** Do not let a single build cycle balloon past a reviewable PR.
