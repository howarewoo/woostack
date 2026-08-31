---
name: woostack-design
description: "Organize user flows, screen sequences, and multi-step UI designs into a standardized horizontal layout with aligned branch rows and vertical flow separation."
---

# woostack-design

Organize multi-step user flows, screen sequences, and UI journeys into a clear, standardized
spatial layout. Spatial arrangement and consistent relative rhythm communicate progression and
branching without altering frame content or visual styling. Caller-supplied tool context owns
execution; this skill contributes only the layout standard.

## Command

- `/woostack-design [target]`
  - Standardizes spatial flow layout for multi-step UI sequences, screen flows, or user journeys.

## Layout standard

Apply this spatial standard to all arranged flows:

### 1. Flow grouping and title hierarchy

- **One group per flow.** Enclose each distinct flow—including its title, description, main step
  sequence, and all associated forks—in a single dedicated parent group.
- **Title and description.** Place the flow title above the step sequence. Place the flow
  description directly below the title.

### 2. Primary sequence

- **Left-to-right progression.** Arrange primary sequence step frames horizontally from left to
  right in sequential order.
- **Consistent horizontal rhythm.** Maintain a uniform relative horizontal gap between adjacent
  step frames across the sequence.
- **Preserve frame design.** Preserve supplied frame dimensions, aspect ratios, and visual styling.
  Do not resize, restyle, or alter the internal content of any frame.
- **Screen-frame backgrounds only.** Give each actual screen frame a background that makes its outer
  edge unambiguous. Do not add backgrounds to flow groups, sequence or fork rows, titles,
  descriptions, labels, or surrounding canvas regions.
- **Preserve clear frame backgrounds.** Keep an existing screen-frame background unchanged when it
  already defines the screen edge; otherwise add only the frame-level background needed to make
  that edge clear.

### 3. Branches and forks

- **Dedicated rows beneath source.** Place alternative paths, error branches, and forks in their own
  horizontal rows positioned beneath the exact source sequence from which they branch.
- **Column alignment.** Align the first frame of a fork directly beneath the column of the step
  frame from which it branches.
- **Matching rhythm.** Subsequent frames in a fork proceed left-to-right following the same
  horizontal spacing rhythm as the primary sequence.
- **Clear vertical separation.** Maintain a distinct relative vertical gap between the source
  sequence and each fork row.
- **Optional branch label.** Include a concise fork label above the branch sequence only when the
  branch condition or trigger is not evident from the frame content.
- **Contained in flow group.** All fork rows and labels remain inside the parent flow group.

### 4. Multi-flow arrangement

- **Vertical stacking.** When organizing multiple distinct flows on the same canvas, stack flow
  groups vertically with clear separation that accounts for every fork row so that flows never overlap.

## Hard constraints

- **Relative layout only.** Define spatial placement through relative positioning, uniform spacing,
  and column alignment. Do not rely on fixed numeric dimensions or pixel coordinates.
- **Preserve visual design.** Except for a screen-frame background required above when the screen
  edge is unclear, do not alter colors, typography, frame sizing, or existing visual appearance.
- **No connectors.** Do not create arrows, connecting lines, or link vectors between frames.
  Spatial alignment and horizontal reading order establish sequence and relationships.
- **Tool agnostic.** Do not include tool-specific APIs, MCP bindings, platform plugins, scripts,
  templates, or external assets.
