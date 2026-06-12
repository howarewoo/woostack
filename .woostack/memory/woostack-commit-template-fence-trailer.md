---
name: woostack-commit-template-fence-trailer
type: convention
scope: skills/woostack-commit/SKILL.md
updated: 2026-06-08
source: address-comments
---
woostack-commit PR-body template must keep ONLY the clean Spec: .woostack/specs/<file>.md line inside the fenced block; document the fixes/ trailer variant in prose outside the fence — agents emit the fence literally, so any parenthetical/annotation inside it breaks the status exact-match. Do not re-flag the template-vs-rules 'inconsistency'.
