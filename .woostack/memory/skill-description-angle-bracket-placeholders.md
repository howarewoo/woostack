---
name: skill-description-angle-bracket-placeholders
type: convention
scope: skills/**/SKILL.md
tags: skill-description, frontmatter, review, skills-angle, false-positive, placeholders
hook: Angle-bracket placeholders like `<plan-path>` in a SKILL.md `description:` are an accepted, shipped convention here — not an XML/HTML defect; the review `skills` angle must not flag them.
updated: 2026-06-06
source: pr-232
recall_count: 6
last_recalled: 2026-06-08
---
Angle-bracket usage placeholders in a `SKILL.md` `description:` field — e.g.
`/woostack-execute-overnight <plan-path> [--inline|--subagent]` — are an
established, shipped convention in this collection, not a defect. Multiple
public skills already ship them and the collection installs cleanly via
`npx skills add howarewoo/woostack`:

- `skills/woostack-execute/SKILL.md` — `<plan-path>`
- `skills/woostack-plan/SKILL.md` — `<spec-path>`, `<spec-basename>`
- `skills/woostack-debug/SKILL.md` — `<target>`
- `skills/woostack-execute-overnight/SKILL.md` — `<plan-path>`

The woostack-review `skills` angle carries a generic skill-authoring rubric rule
that classes any XML-like tag in a description as a HIGH/blocking defect (installers
might render the description as HTML and strip `<...>`). That rule does **not** apply
to this repo: the installer demonstrably handles angle brackets, so the blocking
claim does not reproduce. Do **not** flag `<…>` placeholders in SKILL.md descriptions
— both adversarial validator passes already dropped it once (PR #232), but the raw
angle keeps re-raising it each run.

This is distinct from [[skill-description-colon-space]], which IS a real installer
hazard (a `word: ` colon-space is a YAML mapping indicator that throws a ScannerError
and makes the installer silently skip the skill). Angle brackets are safe; colon-space
is not.
