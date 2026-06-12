<!-- woostack-execute-overnight morning report. Per-run artifact, gitignored. Written incrementally. -->

# Overnight run — {{PLAN_BASENAME}}

> Outcome: {{clean / done-with-findings / partial+blockers / refused-to-start}} · Driver: {{inline / subagent}} · Started: {{START}} · Ended: {{END}}

## ⚠ Needs you

{{Blockers requiring a human, plus outstanding nits from done-with-findings PRs. For a blocked sweep PR, include the branch and PR URL here. Use "None — clean stack." only when there are no blockers or outstanding nits.}}

### Morning test checklist

- [ ] {{What to manually verify, and where (branch / PR / track HEAD).}}

## Run summary

- **Plan:** `.woostack/plans/{{PLAN_BASENAME}}.md`
- **Spec:** `.woostack/specs/{{SPEC_BASENAME}}.md`
- **Base:** {{spec+plan PR # / branch the tracks stack on}}
- **Driver:** {{inline / subagent}}
- **Tracks:** {{N tracks, or "1 (implicit / linear)"}}

## Per-increment

| Track | Increment | Status | Branch / PR | Review | Auto-address rounds | Sweep |
|---|---|---|---|---|---|---|
| {{A}} | {{1}} | {{done / done-with-findings / blocked / not-attempted}} | {{branch / PR URL}} | {{verdict}} | {{0–2}} | {{clean / done-with-findings / blocked / not-attempted-review}} |

## Review sweep

> Post-implementation drive-to-clean over each track's stack, bottom-up. One row per swept
> increment PR. "Clean" = no blocking findings (`STATUS_LINE`) + zero unresolved threads; never a
> merge.

| Track | PR | Rounds (of {{max_rounds}}) | Final verdict | No-progress? | Blocker |
|---|---|---|---|---|---|
| {{A}} | {{#}} | {{r}} | {{clean / done-with-findings / blocked}} | {{yes / no}} | {{— / nits-at-cap / cap-blocking / no-progress / review-error / restack-conflict / unsafe}} |

## Decision log

<!-- Appended live, one line per autonomous decision. -->

- {{stamp}} — {{decision (debug fix / auto-address round / sweep review round / sweep PR clean / sweep PR done-with-findings: nits-at-cap / sweep blocked: cap-blocking | no-progress | review-error | restack-conflict | unsafe / BLOCKED / blocker recorded / track ended / increment not-attempted) + rationale}}
