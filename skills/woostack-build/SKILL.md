---
name: woostack-build
description: Use when building a feature with the full woostack development loop — ideate a design, harden it, plan it, and implement it. Chains woostack-ideate, superpowers writing-plans/executing-plans, and grill-me in a fixed, gated order; writes markdown specs and plans under .woostack/.
---

# woostack-build

## Overview

Drives one feature from idea to implementation through a fixed, gated chain. Thin
glue: it sequences proven sub-skills and **inherits their gates** — it adds none of
its own. The value is the order and the handoffs.

```
ideate → write spec (markdown) → grill-me → approve spec → writing-plans → executing-plans → distill memory → ask: open PR?
```

Two of those gates are hard stops where the user must say yes before the chain advances:
**design approval** (owned by `woostack-ideate`, step 1) and **spec approval** (step 3).
The spec-approval gate is the "user reviews the written spec" step that
`superpowers:brainstorming` used to own; because woostack-build relocated the spec write into
its own step 2, the gate lives here now. Relocating an inherited gate is not adding one.

## Dependency preflight

The ideate phase uses [`woostack-ideate`](../woostack-ideate/SKILL.md), which
ships in this collection — no install needed. The plan, execution, and hardening phases chain
external skills. At the start, check that each is installed:

- `superpowers:writing-plans`, `superpowers:executing-plans`
- `grill-me`

For any that are missing: name exactly what's missing and **offer to install it inline**
(`pnpx skills add obra/superpowers`, `pnpx skills add mattpocock/skills` for grill-me) and
continue. If the user declines, fall back to following the skill's principle manually and
**say so explicitly** — the run is degraded, not equivalent.

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
3. **Harden it, then get spec approval.** Invoke `grill-me` against the spec. Amend the spec
   in place until grilling stops producing new questions. Then **always present the written
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
6. **Execute.** Invoke `superpowers:executing-plans` (or `superpowers:subagent-driven-development`)
   to work the plan with TDD and frequent commits.
7. **Distill memory.** When the increment lands, extract the **durable, reusable** learnings
   from the spec/plan/implementation into scoped notes under `.woostack/memory/` — one fact
   per file, `type` one of `pattern|decision|gotcha|convention`, `scope` the narrowest glob
   covering the feature's touched files, `source` the spec or plan path. **Dedupe first**:
   check `.woostack/memory/MEMORY.md` and update an existing note rather than adding a
   duplicate. Apply the **reject-by-default distillation gate** (see the
   [memory contract](../woostack-init/references/memory.md#7-distillation-write-path) §7) — it
   rejects trivia, source-less, and near-duplicate notes, and requires stamping `updated:` on
   every note you write. Then run `woostack-init`'s `build-index.sh` and `doctor.sh`; fix any
   error.
   Distill only cross-feature knowledge — not feature-specific trivia. See the
   [memory contract](../woostack-init/references/memory.md). When the store does not exist,
   skip (or offer to run `/woostack-init` first). This is a work step, not an approval gate.
8. **Offer the PR.** When the increment lands on the branch, **ask** whether to open a PR. If
   yes, open it (hands off to `woostack-review`). If no, stop on the branch.

## Hard constraints

- **Inherit gates, add none.** Do not insert *extra* approval stops between phases. The two
  inherited hard gates are non-negotiable: **design approval** (step 1) and **spec approval**
  (step 3).
- **Always get explicit spec approval before planning.** After hardening, present the written
  spec and wait for the user's clear yes. Never advance to `writing-plans` on assumed or
  inferred approval.
- **Markdown specs and plans, under `.woostack/`.** Never write specs to the superpowers
  default location. HTML is a render-on-demand target only, not the authored format.
- **Never merge.** build ends by offering a PR, nothing further.
- **One increment per cycle.** Do not let a single build cycle balloon past a reviewable PR.
- **Distill durable knowledge only.** The distill step writes scoped, deduplicated memory
  notes — never feature-specific trivia, never a duplicate of an existing note. A small
  curated store beats a large noisy one.
