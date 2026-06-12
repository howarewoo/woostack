---
name: plan-artifact-quotes-target-relative-links
type: convention
scope: .woostack/fixes/**,.woostack/plans/**
tags: review, markdown, links, fixes, plans, false-positive
hook: A plan/fix artifact quoting another file's relative link renders 'broken' from its own dir but is correct for the target — don't flag it.
updated: 2026-06-10
source: pr-284
---
A `.woostack/fixes/` or `.woostack/plans/` artifact often quotes the relative Markdown link that
belongs in *another* file (e.g. label `woostack-execute` with target
`../woostack-execute/SKILL.md`, destined for `skills/woostack-fix/SKILL.md`). That link resolves correctly from the **target**
file's directory but renders as a broken link from the **artifact's** own directory.

Do not flag it as a broken link. The quote's accuracy for its target file beats the artifact's
render — rewriting the path to be artifact-relative would corrupt the quoted instruction. These
artifacts are historical records of intent, not navigational docs. Mirrors the delegation note's
"quote what belongs in the target, don't localize it" stance (see [[fix-delegates-to-execute]]).
