---
name: authored-prose-uses-em-dash-house-style
type: convention
scope: site/content/docs/**,AGENTS.md,README.md,CONTRIBUTING.md
tags: prose, em-dash, house-style, review, conventions, humanizer, false-positive, authored-docs
hook: Em dashes are pervasive house prose style across authored markdown (AGENTS.md itself, README, CONTRIBUTING, site/content/docs/**); the review conventions/humanizer angle must NOT flag an em dash in authored prose as a style defect.
updated: 2026-07-12
source: pr-482
---
The repo's authored markdown uses the em dash (—) as ordinary house prose style, not an accident
to be linted away. `AGENTS.md` itself uses it ("shipped assets — do not delete", "application
subtree — the docs site"), and it recurs across `site/content/docs/**` (`concepts.mdx`,
`concepts/memory.mdx`, `concepts/context-management.mdx`, ...). None of these pages pair it with a
spaced-hyphen (` - `) alternative, so the em dash is the established convention.

Consequence for review: a conventions / `humanizer`-style finding that flags an em dash in
**authored** `.md` / `.mdx` prose as an "AI-writing signal" or style defect is a **false positive**
here — accept it, do not reword. Rewording only the lines a single PR happens to touch would make
them inconsistent with every surrounding page.

This is distinct from [[skill-test-assert-ascii-token]]: there the rule is to keep the readable
unicode glyph in the prose but never make it a grep **assertion token**. Prose em dashes stay; test
assertions still target an ASCII substring.
