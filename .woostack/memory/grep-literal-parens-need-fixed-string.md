---
name: grep-literal-parens-need-fixed-string
type: gotcha
scope: .woostack/plans/**
tags: plans, verification, grep, regex
hook: A plan's `grep`/`grep -c` verification whose pattern contains literal `()` under-reports — the embedded `pi-uu-grep` treats `(...)` as a group by default, unlike POSIX BRE, so a pattern like `"Read first (delta A)"` matches `Read first delta A` (no parens) and counts `0` though the text is present. Use `grep -F` for literal-paren strings.
updated: 2026-07-14
source: [[plans/2026-07-14-least-code-tenet]]
---
A no-runner woostack plan substitutes a concrete `grep`/`grep -c` for a test. When the asserted
phrase contains literal parentheses, the check silently fails green — it returns `0` even though
the exact text is in the file. The embedded `pi-uu-grep` treats unescaped `(` `)` as regex
grouping metacharacters by default, unlike POSIX BRE. Thus `grep -c "Read first (delta A)"`
looks for `Read first ` followed by the group `delta A` (no literal parens) and never matches
the parenthesized text on disk.

- **Author the verification with `grep -F`** (fixed string) whenever the pattern carries `(`, `)`,
  `|`, `.`, `*`, `[`, `]`, `$`, or `^` as literal characters — e.g. `grep -c -F "Read first (delta A)"`.
- **Or escape** the metacharacters (`\(delta A\)`), but `-F` is less error-prone.
- **Distinct from the other grep traps:** [[grep-c-counts-lines-not-occurrences]] (counts lines,
  not matches) and [[grep-assertion-single-physical-line]] (a match must sit on one physical
  line). This one is about metacharacter interpretation, not counting or wrapping.

Caught live executing least-code-tenet Increment 1: the §10 `Read first (delta A)` check read `0`
while `grep -F` and a direct read confirmed the line was present exactly once.
