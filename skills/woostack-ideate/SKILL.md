---
name: woostack-ideate
description: Shape a feature idea into a complete design candidate. Inside woostack-build, material decisions are synchronized to its canonical Linear project and approval waits for the complete project specification; standalone use ends at explicit design approval.
---

# woostack-ideate

Turn a feature idea into a fully formed design candidate through natural collaborative dialogue.
This is the first phase of [`woostack-build`](../woostack-build/SKILL.md), where the caller writes
every material decision into the same canonical Linear project and owns the later exact
project-specification approval gate. Ideate itself owns no build gate and performs no provider
mutation.

Standalone use retains one explicit design-approval gate and ends at the approved design. In either
mode, ideate writes no implementation source, invokes no planner/executor, and never begins
implementation.

## Scope boundary

Every build feature goes through ideation, but approval occurs only after the complete project
specification is hardened and independently read from Linear. Do not manufacture a separate design
approval inside build. Scale the design work to the request while resolving assumptions before
planning.

## Terminal state

Inside `woostack-build`, hand the complete design candidate and all material decisions back to
build. Build synchronizes those decisions to its exact project throughout the dialogue, proceeds to
specification hardening, and later presents the complete exact project revision for approval.

Standalone, present the complete design and obtain a clear explicit approval. Then:

- write no specification, plan, or implementation artifact;
- invoke no downstream skill; and
- tell the user the approved design is ready for `woostack-build`.

The caller owns persistence, specification hardening, planning, and execution.

## Process

Work the steps in order. Ask **one question per message** so you never overwhelm.

1. **Explore project context.** Read the relevant files, docs, and recent commits before
   asking anything. In an existing codebase, learn the current structure and follow its
   patterns rather than proposing greenfield shapes.
   For front-end work, also read impeccable's `DESIGN.md` if present (at the repo root, where
   `/impeccable init` writes it) and treat it as the design-system source of truth. An absent
   `DESIGN.md` is a no-op.
2. **Check scope first.** If the request bundles multiple independent subsystems ("a platform
   with chat, billing, and analytics"), flag it immediately. Don't refine details of
   something that needs decomposing first — help split it into independent pieces, note how
   they relate and in what order to build them, then ideate on the first piece through the
   normal flow. Each piece gets its own design → spec → plan → implementation cycle.
3. **Ask clarifying questions.** One at a time. Multiple-choice when you can; open-ended is
   fine. Aim at purpose, constraints, and success criteria — not implementation trivia.
4. **Propose 2-3 approaches.** Present them conversationally with trade-offs. Lead with your
   recommendation and say why.
5. **Present the design in sections.** Scale each section to its complexity. Cover architecture,
   components, data flow, error handling, and verification as warranted. Confirm decisions and
   revise when something does not fit. Within build, the caller synchronizes every material
   decision to the canonical project; those confirmations are not approval gates.
6. **Hand back or approve.** Inside build, hand the complete candidate back without an approval
   request. Standalone, obtain explicit design approval, then stop under the terminal-state rules.

## Design for isolation and clarity

- Break the system into small units that each have one clear purpose, communicate through
  well-defined interfaces, and can be understood and tested on their own.
- For each unit, be able to answer: what does it do, how do you use it, what does it depend
  on? If a consumer can't understand a unit without reading its internals, or you can't
  change the internals without breaking consumers, the boundaries need work.
- Smaller, well-bounded units are also easier to implement reliably. A file that's growing
  large is usually a signal it's doing too much.

## Working in existing codebases

- Explore the current structure before proposing changes; follow existing patterns.
- Where existing code in the path of the work has real problems (a too-large file, tangled
  responsibilities, unclear boundaries), fold targeted improvements into the design — the way
  a good developer improves code they're already touching.
- Don't propose unrelated refactoring. Stay focused on what serves this goal.

## Visual treatment, on demand

This skill does not run a browser companion. When a question is genuinely visual — a layout,
wireframe, side-by-side comparison, or architecture diagram the user would grasp faster by
seeing than reading — offer to render it with
[`woostack-visualize`](../woostack-visualize/SKILL.md) (pick the audience that fits) and
continue. Keep conceptual and requirements questions in the terminal; a UI topic is not
automatically a visual question.

For genuine front-end **craft** — typography, color, spacing, motion, component polish — rather
than a view to *show*, defer to [impeccable](https://github.com/pbakaus/impeccable) when it is
installed (its discipline commands, e.g. `/typeset`, `/colorize`, `/animate`). The split:
`woostack-visualize` renders a view **to show the user**; impeccable **crafts the UI itself**.
This is optional and host-dependent — if impeccable is not installed, proceed with built-in
judgment. Its browser-based Live Mode stays out of this phase; the no-browser-companion rule
above is unchanged.

## Key principles

- **One question at a time.** Don't stack questions in a single message.
- **Multiple choice preferred.** Easier to answer than open-ended when the options are clear.
- **YAGNI ruthlessly.** Cut unnecessary features from every design.
- **Least code wins.** Prefer the smallest solution that already exists — stdlib, a native
  feature, an installed dependency — before proposing a new abstraction or dependency. Understand
  the problem before choosing the smallest shape; YAGNI cuts speculative features, never
  validation, error handling, security, accessibility, or safety redundancy. Apply the full
  standard in [`patterns.md §10`](../woostack-bootstrap/references/patterns.md).
- **Explore alternatives.** Always weigh 2-3 approaches before settling.
- **Incremental validation.** Confirm decisions as the design evolves; do not relabel confirmations
  as build approval.
- **Be flexible.** Go back and clarify whenever something stops making sense.

## Hard constraints

- **No build gate.** Build approval waits for the complete exact Linear project specification.
- **Standalone stops at approval.** Write no specification/plan artifact and chain no downstream
  skill; the caller owns subsequent work.
- **No implementation.** Ideate never writes implementation source or runs an executor.
- **No bespoke visual server.** Defer visual treatment to `woostack-visualize`.
