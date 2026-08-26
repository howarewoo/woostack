# AGENTS.md (docs site)

Scope: the `site/` subtree. This file extends the root [`AGENTS.md`](../AGENTS.md). The root
file wins if the two conflict.

## Keep documentation types separate

Before writing or restructuring a page, identify its reader need and assign it one primary type:
tutorial, how-to guide, reference, or explanation. Keep those types separate. If a draft tries to
serve more than one need, split it and link the pages instead of blending their jobs.

| Type | Reader need | The page must do |
| --- | --- | --- |
| Tutorial | Learn by doing | Lead a beginner through a complete, reliable lesson with visible results. |
| How-to guide | Achieve a goal | Give an experienced user the steps for one practical task. |
| Reference | Look up facts | Describe the product accurately, completely, and consistently. |
| Explanation | Understand a topic | Supply context, reasons, tradeoffs, and connections. |

Index and landing pages may route readers across types. Keep their copy short and make each link's
destination and purpose clear.

### Classify by the reader's immediate need

Use these questions before choosing a page type:

- Is the reader new and relying on the author to choose what to learn? Write a tutorial.
- Does the reader already have a specific outcome in mind? Write a how-to guide.
- Does the reader need an exact fact about the machinery? Write reference.
- Does the reader want context or a reason for a design? Write explanation.

The boundaries matter:

- Tutorials and how-to guides both contain steps, but a tutorial is author-led learning while a
  how-to guide answers a user-led problem.
- How-to guides and reference both support active work, but a how-to guide leads to an outcome
  while reference supplies facts for lookup.
- Reference and explanation both deal with knowledge, but reference describes what exists while
  explanation discusses why it exists and how ideas connect.
- Tutorials and explanation both support study, but a tutorial teaches through action while
  explanation develops understanding through discussion.

Do not add procedural steps to reference or explanation. Do not add broad discussion or complete
option inventories to tutorials or how-to guides. A short prerequisite, warning, or cross-link is
fine when the reader needs it to use the page safely.

### Tutorials

- Take responsibility for the beginner's path and outcome. State what the reader will make or do.
- Start with the smallest concrete action, then build toward a meaningful result.
- Make every command and step work as written. Show the expected result soon after the action.
- Keep the route deterministic and repeatable across the supported environment.
- Choose an achievable result that gives the beginner confidence and enough practical context to
  use the rest of the documentation. Use a friendly, consistent tone.
- Test tutorials regularly. An unexpected error or result breaks the lesson even when the product,
  platform, or dependency caused it.
- Include only the explanation needed to finish the lesson. Link to explanation and reference
  pages for deeper material.
- Do not turn the tutorial into an option catalog or best-practices survey.

### How-to guides

- Solve one real problem for a reader who already knows the basics.
- Use a task-specific title that works as "How to ...".
- Provide an ordered procedure from a reasonable starting point to the stated result.
- Keep the guide practical and focused. Link to concepts and reference details instead of
  interrupting the procedure.
- Allow enough variation for the reader to adapt the steps, but omit unrelated cases and exhaustive
  option lists.
- Start and stop where the task requires. A how-to guide does not need tutorial-level
  completeness, and practical usefulness matters more than covering every related feature.

### Reference

- Describe the current machinery: commands, configuration, fields, accepted values, defaults,
  constraints, and observable behavior.
- Follow the structure and terminology of the source material. Use the same shape for comparable
  entries.
- Mirror the source's hierarchy where possible so readers can navigate the implementation and its
  reference together. Keep headings, field order, tone, and formatting consistent across entries.
- Describe correct basic usage and required precautions, but do not expand them into a procedure
  for accomplishing a separate goal.
- Prefer precise, compact descriptions. Examples may illustrate usage, but must not become lessons
  or task guides.
- Verify every claim against the canonical skill or source. Update reference text whenever that
  source changes.
- Keep opinions, rationale, broad discussion, and procedural walkthroughs elsewhere.

### Explanation

- Clarify why the system works as it does. Cover context, design decisions, constraints,
  alternatives, and consequences.
- Organize the page around a topic, not a sequence of commands or an inventory of fields.
- Discuss tradeoffs when the source supports them. Do not invent rationale.
- Use explanation for background, history, reasons, alternatives, and supported opinions. It may
  broaden the reader's understanding without producing an immediate practical result.
- Do not use explanation to instruct the reader or to catalog technical behavior.
- Link to tutorials, how-to guides, and reference pages for action or lookup material.

## Apply the types to this site

Use the existing information architecture rather than adding a second naming scheme:

- `content/docs/getting-started.mdx` is the primary tutorial.
- Task procedures, including the Hermes workflow, are how-to guides.
- `content/docs/configuration.mdx`, `content/docs/harnesses/`, generated `content/docs/skills/`,
  and the `review-angles.mdx`, `status-tracking.mdx`, and `utilities.mdx` catalog pages are
  reference.
- `content/docs/concepts.mdx` and the remaining topic pages under `content/docs/concepts/` are
  explanation.
- `content/docs/index.mdx` and section index pages are navigation surfaces.

When existing content crosses these boundaries, improve the separation in the smallest safe edit.
Do not duplicate canonical facts to make a page self-contained. Link to the owning page.

## Copy must read as human-written

Run the `humanizer` skill, or apply its rules by hand, to prose you add or change:

- Use plain, direct language. Remove filler, sales language, unsupported claims, and repetitive
  framing.
- Do not use em dashes or en dashes in prose. A table cell may use `—` only as a "none"
  placeholder.
- Do not use the `**Label** — description` bullet shape. Write `**Label:** description`.
- Do not use a false "from X to Y" range for a list.
- Avoid tailing negations, hollow superlatives, forced groups of three, and generic conclusions.
- Use sentence-case headings.

This rule covers authored pages and landing-page copy. Pages under `content/docs/skills/` are
generated from `../skills/*/SKILL.md` at build time and are gitignored. Edit and humanize the source
`SKILL.md`, never the generated MDX.

## Editing workflow

1. Read the canonical skill or source before changing a factual claim.
2. Name the page's documentation type and reader goal.
3. Reuse the existing page, section, component, and navigation patterns.
4. Write only the material that belongs to that type. Link across types.
5. Check commands, links, expected results, and terminology against the source.
6. Humanize the changed prose.

Keep authored pages in sync with the skills they describe, as required by the root
[`AGENTS.md`](../AGENTS.md).

## Before you finish

- Confirm the page still has one primary reader need and that misplaced material was linked or
  moved rather than duplicated.
- In an isolated worktree without `site/node_modules`, run
  `pnpm -C site install --frozen-lockfile` from the repository root before building. Never symlink
  `node_modules` from another checkout because Turbopack rejects dependency links that point
  outside the current project root.
- Run `pnpm -C site build` from the repository root.
