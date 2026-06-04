# Audience profiles

Each visualization targets one reader. A preset below is a shortcut; any free-form audience
("a designer", "a security auditor") is valid and is interpreted against the **dimension
rubric** at the end. Default audience is `engineer`.

## Dimensions

Every profile answers these five questions. Free-form audiences answer them by inference.

- **Surface** — what to show and what to hide.
- **Depth** — how far down to go (mechanism vs. outcome).
- **Vocabulary** — technical, plain, or business language.
- **Visual density** — dense reference vs. spacious headline-driven.
- **Cares about** — what this reader is actually trying to learn.

## engineer

- **Surface:** data flow, interfaces, components, key decisions, tradeoffs, edge cases,
  failure modes. Hide marketing framing.
- **Depth:** full technical depth, down to mechanism and contracts.
- **Vocabulary:** precise technical terms; name the real types, files, and functions.
- **Visual density:** dense — diagrams, tables, code/identifier callouts welcome.
- **Cares about:** how it works, how to build it, how to maintain and extend it safely.

## non-technical

- **Surface:** what it does and why it matters; the user-facing shape. Hide implementation.
- **Depth:** shallow on mechanism; concrete on outcomes and examples.
- **Vocabulary:** plain language and analogies; expand or avoid jargon.
- **Visual density:** moderate, with generous whitespace and clear signposting.
- **Cares about:** what changes for people, the benefit, the "so what".

## investor

- **Surface:** the problem, the opportunity, scope, milestones, and risk. No code.
- **Depth:** outcome-level; tie everything to value and feasibility.
- **Vocabulary:** business language; crisp and confident, never hand-wavy.
- **Visual density:** low — high-signal, headline-driven, a few strong visuals.
- **Cares about:** what this is worth, what it costs, what could go wrong.
- **Guard:** never fabricate numbers, timelines, or traction. Absent data is omitted or
  labelled unknown — not invented.

## Free-form audiences

When the audience is not a preset, infer the five dimensions from who they are. A "security
auditor" wants threat surface, trust boundaries, and failure modes at high depth in technical
vocabulary; a "designer" wants flows, states, and UI surface at moderate depth. State the
inferred framing briefly at the top of the visual so the reader knows the lens.
