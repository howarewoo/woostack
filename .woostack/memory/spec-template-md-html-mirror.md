---
name: spec-template-md-html-mirror
type: gotcha
scope: skills/woostack-build/references/**
tags: spec-template, visualize, html-mirror, renumber, illustrative-tokens
hook: spec-template.html's {{tokens}} are illustrative, not a substitution engine — woostack-visualize composes bespoke HTML; edit the .md and .html together and keep sections 1:1.
updated: 2026-06-06
source: [[plans/2026-06-06-spec-acceptance-criteria]]
---
`woostack-build/references/spec-template.md` and `spec-template.html` are a
**hand-maintained 1:1 pair** — same ordered section headings and numbers. There
is **no template engine**: the `{{UPPER_SNAKE}}` tokens in the `.html` (and the
`.md`) are *illustrative cues only*. `woostack-visualize` **composes bespoke
HTML** per source/audience (`woostack-visualize/SKILL.md:32-38`) and reads none
of the tokens; `/woostack-status` reads only frontmatter. So **nothing parses the
section numbers** — renumbering is safe — but **nothing keeps the two files in
sync either**: editing one without mirroring the other silently desyncs the
render.

When you add/remove/renumber a section, change **both** files and verify parity,
e.g.:

```bash
diff <(grep -oE '<h2>[0-9]+\. [^<]+' spec-template.html | sed 's#<h2>##; s/&amp;/\&/g') \
     <(grep -oE '^## [0-9]+\. .+'   spec-template.md   | sed 's/^## //')
```

Note the `&amp;`→`&` normalization: §"Components & data flow" is `&` in markdown
but `&amp;` in HTML, so a naive diff false-positives. Same byte-vs-entity trap
applies to any heading with a special char.
