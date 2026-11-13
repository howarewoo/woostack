# AGENTS.md (docs site)

The root [AGENTS.md](../../AGENTS.md) takes precedence.

- For user-facing documentation, follow the shared
  [documentation guidance](../../shared/references/documentation.md).
- Keep the site's existing page roles: `getting-started.mdx` is a tutorial; task guides are how-to
  guides; configuration, harnesses, generated skills, and utilities are reference; other concept
  pages are explanation. Index pages provide navigation.
- Use sentence-case headings. Avoid em dashes and en dashes in authored prose; `—` may mark an
  empty table cell.
- `content/docs/skills/` is generated and gitignored. Edit `../../skills/*/SKILL.md`, and update
  affected authored guides when behavior changes.
- Use the root [validation policy](../../AGENTS.md#validation). Turbopack rejects `node_modules`
  links outside this repository's root.

<!-- BEGIN:nextjs-agent-rules -->

## This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` (resolved from this file's directory; in monorepos the `next` package may not be visible from the repo root) before writing any code. Heed deprecation notices.

This block is written and re-added by `next dev` — verify at `node_modules/next/dist/server/lib/generate-agent-files.js`. Removing it from a diff only re-creates the uncommitted change; committing it with your work keeps the tree clean.

<!-- END:nextjs-agent-rules -->
