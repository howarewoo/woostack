---
name: review-final-findings-need-postable-anchors
type: gotcha
scope: skills/woostack-review/**
hook: Validator agreement does not prove GitHub-postable anchors; validate a finding's final start and optional endpoint together against the current diff.
updated: 2026-07-14
source: [[fixes/2026-07-14-multi-line-review-anchors]]
---
`intersect-findings.sh` preserves the defender object's location while prosecutor agreement only
folds selected verdict fields. A final validated issue can therefore still carry a stale path,
start line, or unvalidated range endpoint into GitHub's Review API.

Before posting or counting final findings, treat `findings.json` as untrusted payload data. Filter
it against the current PR file set, then validate `line` and optional `end_line` together through
`resolve-diff-line.sh`. A valid range requires both RIGHT-side endpoints in one hunk. Drop the
finding only when its start is unresolvable; strip an invalid endpoint and retain the single-line
finding.
