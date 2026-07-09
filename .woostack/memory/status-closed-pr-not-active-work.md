---
name: status-closed-pr-not-active-work
type: gotcha
scope: skills/woostack-status/scripts/**
tags: status, resolve_phase, done, collision, closed-pr, prcount, board
hook: In status.sh a CLOSED PR and a done/abandoned row are NOT active work — judge done against active_prcount=open+merged (raw prcount counts CLOSED and wrongly blocks done), and gate the branch-collision flag on eff!=done/abandoned.
updated: 2026-07-09
source: [[fixes/2026-07-09-status-phase-closed-pr-collision]]
---
`resolve_phase` gated `done` on `merged -eq prcount`, but `prcount` counts CLOSED
(unmerged) PRs — so a completed feature (frac=100, or a zero-checkbox plan authored
`done`) with a superseded/closed PR beside its merged one never reached `done` and
rotted in `executing`/`in-review`. Judge completeness against
`active_prcount=$((open+merged))` at BOTH done sites (the frac=100 check and the
zero-checkbox authored-done branch); keep the `prcount -eq 0` legacy paths keyed on
`prcount` — they mean "no PR discovered at all". A CLOSED PR is stacked-repo noise: it
must not block `done`, while an OPEN PR still forces `in-review` and
`done = merged-and-landed` still holds ([[execute-authors-terminal-plan-done]]). This
deliberately relaxes #456's "closed-blocks-done" for *completed* plans only (#463) —
don't re-reverse it.

Separately, the branch-collision flag recorded/compared `SEEN_BRANCHES` for EVERY row;
guard it with `[ "$eff" != done ] && [ "$eff" != abandoned ]` so only two in-flight rows
sharing a branch collide (conventions.md: "two in-flight rows"). A terminal branch is not
in-flight — a done/abandoned row must neither flag nor get recorded, else an active row
false-collides against it.
