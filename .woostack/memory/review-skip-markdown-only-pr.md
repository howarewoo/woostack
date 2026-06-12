---
name: review-skip-markdown-only-pr
type: gotcha
scope: skills/woostack-review/scripts/**
tags: prefetch, skip, code-files, markdown, skills-repo, fast
hook: prefetch.sh emits skip=true "no code files changed" on a markdown-only PR — a false-negative in this all-markdown skills repo; force the swarm on docs/skills angles instead of trusting the skip.
updated: 2026-06-06
source: .woostack/plans/2026-06-06-spec-acceptance-criteria.md
---
`prefetch.sh` counts "code files" in the diff and emits `skip=true` with reason
**`no code files changed`** when the diff is entirely `.md` (and other non-code).
In a normal app repo that is a sane low-risk skip. In **this** repo — a skills
collection where every change is markdown and `SKILL.md` prose *is* the product —
it is a false-negative: a real `woostack-plan/SKILL.md` semantic change reports
"nothing to review."

`detect-angles.sh` still resolves the right angles for markdown (`docs`, `skills`,
plus always-on `bugs`/`security`), and the artifact tree (`diff.txt`, `meta.json`,
`angles.txt`) is still written — so the skip is advisory, not fatal. When an
execute increment is markdown-only, **don't lean on the skip**: run the bounded
swarm on the resolved angles anyway (the `skills` angle is the one that actually
reads SKILL.md against authoring best-practices) so the increment gets a real
reviewed verdict. The Inc-1 sibling change reviewed normally only because its
`.html` counted as a code file.
