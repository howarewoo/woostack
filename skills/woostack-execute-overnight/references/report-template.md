<!-- woostack-execute-overnight morning report. Per-run artifact, gitignored. Written incrementally. -->

# Overnight run — {{PLAN_BASENAME}}

> Outcome: {{clean / partial+blockers / refused-to-start}} · Driver: {{inline / subagent}} · Started: {{START}} · Ended: {{END}}

## ⚠ Needs you

{{Blockers requiring a human, most important first. "None — clean stack." if there are none.}}

### Morning test checklist

- [ ] {{What to manually verify, and where (branch / PR / track HEAD).}}

## Run summary

- **Plan:** `.woostack/plans/{{PLAN_BASENAME}}.md`
- **Spec:** `.woostack/specs/{{SPEC_BASENAME}}.md`
- **Base:** {{spec+plan PR # / branch the tracks stack on}}
- **Driver:** {{inline / subagent}}
- **Tracks:** {{N tracks, or "1 (implicit / linear)"}}

## Per-increment

| Track | Increment | Status | Branch / PR | Review | Auto-address rounds |
|---|---|---|---|---|---|
| {{A}} | {{1}} | {{done / done-with-findings / blocked / not-attempted}} | {{branch / PR URL}} | {{verdict}} | {{0–2}} |

## Decision log

<!-- Appended live, one line per autonomous decision. -->

- {{stamp}} — {{decision (debug fix / auto-address round / BLOCKED / blocker recorded / track ended / increment not-attempted) + rationale}}
