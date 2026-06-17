# Visual primitives palette

A reusable set of section types for a `woostack-visualize` render. This is an **opt-in
palette, not a template**: pick only the primitives the source evidence supports, omit (or
mark unknown) any whose evidence is missing, and keep composing bespoke layout for whatever the
palette does not cover. Every primitive is bound by the skill's no-fabrication rule — show only
what the real source contains.

Each entry below states **when to use**, the **source evidence required** to render it
honestly, and **what to omit or mark unknown** when that evidence is absent.

## source summary

- **When:** almost always, as the opening orientation — what this is, what it covers, who it is
  for, and what was read versus sampled.
- **Evidence required:** the resolved source itself (file/dir/subject) and the audience framing.
- **Omit/unknown:** if you only sampled a large directory, say so here rather than implying full
  coverage; never summarize a source you could not read.

## file map

- **When:** the source is a directory or a multi-file change and the reader needs to see how the
  pieces fit — entry points, key modules, ownership.
- **Evidence required:** the real directory tree and the files you actually opened; mark which
  nodes were read in full versus listed only.
- **Omit/unknown:** drop it for a single-file source; do not invent files or folders you did not
  observe.

## annotated code

- **When:** an engineer audience needs to see a specific function, type, or config with inline
  callouts explaining the mechanism.
- **Evidence required:** the verbatim code excerpt, copied from source with its real path and
  identifiers; annotations must describe what the code actually does.
- **Omit/unknown:** never paraphrase code into a fictional snippet; if you cannot quote it, link
  the location in prose instead.

## before/after

- **When:** the source describes a change, migration, or refactor and the value is in the delta.
- **Evidence required:** both the prior and the resulting state, each traceable to source (a
  diff, two revisions, or a clearly described old/new pair).
- **Omit/unknown:** if only one side is known, present that side plainly and label the other
  side unknown rather than fabricating a contrast.

## API/data contract

- **When:** the reader needs the shape of an interface, endpoint, schema, or payload —
  parameters, fields, types, returns.
- **Evidence required:** the real signature, schema, or type definition from source; use the
  actual field names and types.
- **Omit/unknown:** mark fields whose type or nullability you could not confirm as unknown; do
  not guess a contract the source does not pin down.

## state matrix

- **When:** behavior varies across states/conditions (status values, flags, roles) and the
  reader needs the full grid of state × outcome.
- **Evidence required:** the enumerated states and their documented transitions/outcomes from
  source.
- **Omit/unknown:** leave a cell blank or marked unknown when the source does not define that
  combination; never fill the grid for symmetry.

## flow diagram

- **When:** the source has a sequence or control/data flow — a request path, a pipeline, a
  decision sequence — best seen as nodes and edges.
- **Evidence required:** the real steps and their ordering from source; render as inline SVG or
  CSS so it stays offline.
- **Omit/unknown:** do not insert plausible-but-unstated steps; show only the path the source
  describes and note where it goes dark.

## decision table

- **When:** the source records choices with rationale and tradeoffs (a spec's approach section,
  an architecture decision).
- **Evidence required:** the actual options considered, the choice made, and the stated reasons.
- **Omit/unknown:** if rationale is absent, list the decision without inventing a justification.

## risk register

- **When:** the reader (often an investor or reviewer) needs the failure modes, open risks, and
  their severity or mitigation.
- **Evidence required:** risks the source actually raises (error-handling sections, security
  surface, stated assumptions).
- **Omit/unknown:** do not manufacture risks for effect, and do not assert a mitigation the
  source does not describe.

## open questions

- **When:** the source still has unresolved decisions, TODOs, or gaps the reader should know
  about before acting.
- **Evidence required:** the genuinely unresolved items in the source — open questions, deferral
  markers, explicit unknowns.
- **Omit/unknown:** if everything is settled, drop the section rather than padding it; never
  recast a resolved point as still-open.
