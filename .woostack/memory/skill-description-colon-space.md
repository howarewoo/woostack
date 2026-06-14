---
name: skill-description-colon-space
type: gotcha
scope: skills/*/SKILL.md
tags: yaml, frontmatter, installer, skill-description
hook: A `word: ` colon-space in a SKILL.md description is a YAML mapping indicator; it throws a ScannerError and the installer silently skips the skill.
updated: 2026-06-05
source: [[plans/2026-06-04-woostack-status]]
---
The SKILL.md frontmatter `description:` value is a YAML plain scalar. A plain scalar must not
contain `": "` (colon followed by space) — YAML reads it as a nested mapping-value indicator
and the parser throws `ScannerError: mapping values are not allowed here`. The `pnpx skills add`
installer loads each `skills/*/SKILL.md` frontmatter and silently drops any skill whose
frontmatter fails to parse, so the skill never appears — even when the file is merged to `main`.

This bit woostack-status: its description said `...drift between the authored status: and the
artifacts...`. The `status: ` killed the parse and the skill vanished from the installer (fixed
in PR #207 by rephrasing to `authored status field`).

When a description must reference a frontmatter key, write it without the trailing colon-space
(`the status field`, not `status:`), or double-quote the whole scalar and escape internal `"`.
Guard cheaply: parse every `skills/*/SKILL.md` frontmatter through a YAML loader and assert 12 OK.
See [[woostack-command-surface-bookkeeping]].
