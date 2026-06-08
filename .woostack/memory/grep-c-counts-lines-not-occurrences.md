---
name: grep-c-counts-lines-not-occurrences
type: gotcha
scope: .woostack/plans/**
tags: plans, verification, grep, counts
hook: A plan's `grep -c` verification counts matching LINES, not occurrences — a phrase that line-wraps or two patterns sharing a line undercount.
updated: 2026-06-06
source: .woostack/plans/2026-06-06-woostack-execute-overnight.md
recall_count: 13
last_recalled: 2026-06-08
---
When a woostack plan asserts an exact count with `grep -c -E "..."`, remember it counts
matching **lines**, not matches. Two traps that made plan expectations wrong (twice in one
plan):

- **A phrase wraps across a newline.** Markdown reflows long sentences, so `"thirteen-skill
  command surface"` may sit as `…thirteen-skill command` / `surface…` on two lines and never
  match. Anchor the pattern on an unwrapped fragment (`"thirteen-skill command"`).
- **Two alternatives share one line.** `"fifteen \`SKILL.md\`|thirteen public command"` both
  match the same constraint line → counted **once**, not twice.

Either inflates your expected number. Author the expected value against the actually-wrapped
file (or use `grep -o … | wc -l` for true occurrence counts). Same caution applies when the
verification's target wording later changes — update the pattern, e.g. make it tolerant:
`^## Optional: (parallel|independent) tracks`. See [[woostack-command-surface-bookkeeping]].
