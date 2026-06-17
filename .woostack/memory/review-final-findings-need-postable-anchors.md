---
name: review-final-findings-need-postable-anchors
type: gotcha
scope: skills/woostack-review/scripts/**
hook: Review validator agreement does not prove GitHub-postable anchors; final `findings.json` must be filtered against the current PR file set and `resolve-diff-line.sh` after intersection/classification.
updated: 2026-06-17
source: [[fixes/2026-06-17-final-finding-anchors]]
---
`intersect-findings.sh` can preserve a defender finding's `file`/`line` while using prosecutor
agreement only to merge severity/blocking. A final validator/intersection pass may therefore
confirm a real issue but still carry a stale path or line into the GitHub Review API payload.

Before posting or counting final review findings, treat `findings.json` as untrusted payload data:
filter it against the current PR file set and re-run `resolve-diff-line.sh` against the final
`file`/`line`. Drop non-PR files and unresolvable lines; rewrite numeric resolver output back to
`.line`.
