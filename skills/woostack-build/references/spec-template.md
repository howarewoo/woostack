# `specHardened` project-update body template

Use this structure for the readable body of the current `specHardened` project update. The
managed event envelope supplies the stable event `clientId`, revision, predecessor,
supersession, related IDs, repository identity, and project identity. Append or revise the
update only through official host-exposed Linear MCP capabilities, then independently read the complete event and one-head lifecycle chain back before advancing.

# {{TITLE}} — Specification

## 1. Problem

> **Premise / evidence.** State the evidence the problem is real. A derived claim about current
> behavior must be demonstrated with a baseline or reproduction. A self-evident premise cites
> the visible defect or explicit request.

{{PROBLEM}}

## 2. Goal

{{GOAL}}

## 3. Non-goals

{{NON_GOALS}}

## 4. Approach

{{APPROACH}}

## 5. Components and data flow

{{COMPONENTS}}

## 6. Error handling

{{ERRORS}}

## 7. Acceptance criteria

Each acceptance criterion is a testable behavior mapped to at least one increment issue. Fill
every class or use `N/A — <reason>`; use `N/A — <why no testable behavior>` for the entire
section only when the specification has no testable behavior.

> **Angle pre-flight.** Before finalizing acceptance criteria, walk the specification lens in
> [`angle-preflight.md`](../../woostack-harden/references/angle-preflight.md). Capture each
> implicated security, observability, API, database, and edge/error angle as a section 6 error
> path or section 7 error/edge case.

- **AC1 — {{behavior}}**
  - happy: {{expected}}
  - error: {{expected}}
  - edge: {{expected}}
- **AC2 — {{behavior}}**
  - happy: {{expected}}
  - error: {{expected}}
  - edge: {{expected}}

## 8. Testing

> Strategy only: harness, test levels, fixtures, and CI. Per-behavior cases live in section 7.

{{TESTING}}

## 9. Open questions

{{OPEN_QUESTIONS}}
