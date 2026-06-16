# AGENTS.md (docs site)

Scope: the `site/` subtree. Extends the root [`AGENTS.md`](../AGENTS.md); the root file wins on
conflict.

## Copy must be humanized

All prose you author or edit in this site should read as human-written, not machine-generated.
Run the `humanizer` skill (or apply its rules by hand) on any copy you add or change, and drop
the common AI tells:

- No em dashes or en dashes in prose. Use periods, commas, colons, or parentheses instead. (The
  one carve-out is `—` used as a "none" data placeholder inside a table cell.)
- No `**Label** — desc` bullet shape. Write `**Label:** desc`.
- No false "from X to Y" range when you mean a plain list.
- No tailing negations, hollow superlatives, or rule-of-three filler. Say the thing plainly.

This rule covers the **authored** pages only: `content/docs/index.mdx`, `getting-started.mdx`,
`concepts.mdx`, `configuration.mdx`, and the landing page. The per-skill reference pages under
`content/docs/skills/` are generated from each `../skills/*/SKILL.md` at build time and are
gitignored, so humanize the source `SKILL.md`, never the generated MDX.

## Before you finish

- Keep authored pages in sync with the skills they describe (see the root `AGENTS.md` hard
  constraints).
- Run `pnpm build` to confirm the site still builds.
