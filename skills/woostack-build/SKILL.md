---
name: woostack-build
description: Use when building a feature with the full woostack development loop — brainstorm a design, harden it, plan it, and implement it. Chains superpowers (brainstorming, writing-plans, executing-plans) and grill-me in a fixed, gated order; writes markdown specs and plans under .woostack/.
---

# woostack-build

## Overview

Drives one feature from idea to implementation through a fixed, gated chain. Thin
glue: it sequences proven sub-skills and **inherits their gates** — it adds none of
its own. The value is the order and the handoffs.

```
brainstorming → write spec (markdown) → grill-me → writing-plans → executing-plans → distill memory → ask: open PR?
```

## Dependency preflight

This skill chains external skills. At the start, check that each is installed:

- `superpowers:brainstorming`, `superpowers:writing-plans`, `superpowers:executing-plans`
- `grill-me`

For any that are missing: name exactly what's missing and **offer to install it inline**
(`pnpx skills add obra/superpowers`, `pnpx skills add mattpocock/skills` for grill-me) and
continue. If the user declines, fall back to following the skill's principle manually and
**say so explicitly** — the run is degraded, not equivalent.

## Procedure

1. **Brainstorm.** Invoke `superpowers:brainstorming` to explore the problem and converge
   on a design. Let it run its own approval gate.
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
3. **Harden it.** Invoke `grill-me` against the spec. Amend the spec in place until
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

- **Inherit gates, add none.** Do not insert extra approval stops between phases.
- **Markdown specs and plans, under `.woostack/`.** Never write specs to the superpowers
  default location. HTML is a render-on-demand target only, not the authored format.
- **Never merge.** build ends by offering a PR, nothing further.
- **One increment per cycle.** Do not let a single build cycle balloon past a reviewable PR.
- **Distill durable knowledge only.** The distill step writes scoped, deduplicated memory
  notes — never feature-specific trivia, never a duplicate of an existing note. A small
  curated store beats a large noisy one.
