---
name: tui-design
description: Use when designing, reviewing, or improving a terminal user interface (TUI), interactive menu, or terminal dashboard, especially confusing navigation, labels, grouping, focus, or density. Not for general web design or noninteractive command output.
---

# tui-design

Make terminal interfaces understandable and deliberate within their character grid. A user should
recognize the available controls, current focus, and effect of the next keypress without trial
and error. This is an optional, standalone utility; no other skill or external design collection
is required.

## Scope

Follow the requested operation: reviews and audits return findings; design requests return a
layout and interaction specification; implementation requests authorize the scoped edits and
checks. Keep review and design work read-only unless the user also requests changes. Refinement
preserves the established design and required behavior; it does not silently become a redesign.
Do not create project guidance, install tools, commit, publish, or start another workflow implicitly.

## 1. Establish the design direction

Inspect the target screens, source, bindings, and relevant existing product/design guidance.
For a new interface, use the supplied task and constraints. Ask only about unresolved decisions
that materially change the design or scope; state routine assumptions and proceed.

Before editing, describe briefly:

- The user's main task and what should attract attention first.
- Which controls belong together, what information supports each choice, and what stays separate.
- The appropriate density for a short decision menu, repeated operational work, or reading logs.
- The smallest supported terminal and what collapses, wraps, scrolls, or moves into details.

Map visible content to navigation, action, input, choice, description, status, or readable content.
Map each control to an outcome and each description to its owner. Inspect the complete affected
path from arrival through activation, result, and recovery, not just a pleasing initial frame.

## 2. Diagnose and improve

Read the applicable sections of [design rules](references/design-rules.md). Use
[patterns](references/tui-patterns.md) when menu grouping, choice states, or compact layouts need a
concrete example. Consult [sources](references/sources.md) for research or toolkit details only.

Assess usability and terminal behavior separately: a clear-looking screen can have broken keys,
and correct key handling can still present an incomprehensible menu. Prioritize blocked tasks,
misleading state, and accidental activation; then labels and grouping; then size/content resilience;
then cosmetic consistency.

Prefer removing redundant text, decorative containers, repeated hints, and unnecessary steps
before adding more UI. Preserve necessary choices, consequences, recovery, and access to hidden
detail. Keep meaningful hierarchy after simplification. Reuse the existing toolkit and owning
components; fix the narrowest cause rather than introducing a new design framework.

For review, report concrete findings and stop before edits. For design, specify representative
frames, focus order, key effects, state transitions, and compact behavior. For implementation,
make the requested changes while preserving unrelated behavior and established conventions.

## 3. Verify the affected journey

- **Recognition:** inspect a monochrome frame. Identify all actionable items, focus, checked/current
  state, and each description's owner; compare that reading with the actual focus sequence.
- **Keyboard:** exercise movement, activation, text entry, back/cancel, and exit where changed.
  Check that hints match bindings, passive labels are skipped, and navigation has no unintended
  side effects. Include focus restoration and relevant background updates.
- **Size and content:** inspect normal and smallest supported dimensions, live resize, long names,
  wrapping, and relevant empty/error states. If dimensions are unspecified, use 80x24 as a starting
  assumption and 60x16 as a compact stress case, not universal terminal requirements.
- **Evidence:** use existing render and interaction tools where available. Snapshots establish
  appearance, not key handling or usability. Add regression tests only for meaningful changed risks.
  If the interface cannot be run, give source-backed findings or a proposal and identify unrun checks.

Return the important design decisions or prioritized findings with their user impact, location,
evidence, and smallest correction. For changes, summarize what was simplified and verified.
Keep observed runtime behavior, source inspection, and untested mockups distinct; a clean automated
check or monochrome frame alone does not establish accessibility or design quality.
