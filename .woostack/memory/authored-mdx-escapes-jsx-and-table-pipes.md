---
name: authored-mdx-escapes-jsx-and-table-pipes
type: gotcha
scope: site/content/docs/**
tags: mdx, fumadocs, turbopack, jsx, gfm, table, escaping, authored-docs
hook: In a hand-authored site/content/docs/*.mdx page, bare `{…}` and `<word>` parse as JSX and a literal `|` splits a GFM table cell — backtick placeholders/values and escape table pipes as `\|`, or `next build` fails.
updated: 2026-06-15
source: [[fixes/2026-06-15-site-config-page]]
---
The Turbopack MDX compiler treats an authored `.mdx` page as MDX, not plain Markdown, so prose is
parsed for JSX:

- A bare `{…}` is read as a JS expression — e.g. a tier set written `{fast, standard, deep}` in prose
  throws a compile error.
- A bare `<word>` is read as a JSX open tag — e.g. a placeholder `<provider>` or `<ref>` throws
  "expected a closing tag".
- A GFM **table cell** splits on every literal `|`, even inside a code span — a default value like a
  regex `^(staging|release)` silently breaks the column layout.

Inline code (backticks) makes `{`/`}`/`<`/`>` literal, but does **not** protect a table-cell `|` —
GFM still splits there, so the pipe must additionally be escaped `\|`. Fenced code blocks (```json
…```) are fully safe: their contents are never parsed, so an example `config.json` with braces is
fine.

This only bites **authored** pages. The generated per-skill pages under `content/docs/skills/`
(built by `gen-skills.mjs`) are escaped by the generator.

How to apply:

- Backtick every type/key placeholder (`` `<provider>` ``, `` `models.<tier>` ``) and every value
  containing `{` `}` `<` `>`.
- Inside a table cell, also escape any literal `|` as `\|` (still inside backticks).
- Put multi-line / brace-heavy examples in a fenced block, not inline prose.
- Verify with `pnpm -C site build` — a Turbopack MDX panic with no clear line is almost always one of
  these. See [[site-build-in-worktree-needs-real-node-modules]] for running that build in a worktree.
