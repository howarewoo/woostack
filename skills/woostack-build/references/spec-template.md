---
name: {{SLUG}}
type: spec
status: {{STATUS}}
date: {{DATE}}
branch: {{BRANCH}}
links:
---

# {{TITLE}} — Design Spec

> Artifact: {{ARTIFACT_REFERENCE}}. The selected backend artifact is the source of truth. Render with [spec-template.html](spec-template.html) for a rich presentation only.

> `status:` follows the selected backend's owning-artifact contract. In Markdown, this spec owns `draft`, `hardened`, or `approved` while it exists; abandon removes the worktree and branch and closes the PR, leaving no artifact or authored abandoned status. Its joined plan owns later implementation phases and uses `in-review`. In Linear, the managed spec document owns `designState`, the project mirrors the applicable feature lifecycle including terminal `abandoned`, and increment issues own their separate normalized lifecycle including `inReview`. The enum and joins are defined once in [conventions.md](../../woostack-status/references/conventions.md).

> **Plan:** [[plans/{{DATE}}-{{SLUG}}]]

## 1. Problem

> **Premise / evidence.** State the evidence the problem is real. A derived claim about current behavior must be *demonstrated* (a baseline/repro), not asserted — harden's premise lens will not stamp this spec `hardened` otherwise. A self-evident premise (visible bug, explicit request) just cites the repro/request.

{{PROBLEM}}

## 2. Goal

{{GOAL}}

## 3. Non-goals

{{NON_GOALS}}

## 4. Approach

{{APPROACH}}

## 5. Components & data flow

{{COMPONENTS}}

## 6. Error handling

{{ERRORS}}

## 7. Acceptance criteria

Each AC is a testable behavior → ≥1 plan task. Fill every class or mark `N/A — <reason>`; mark the whole section `N/A — <why no testable behavior>` only when the spec has no testable behavior.

> **Angle pre-flight.** Before finalizing ACs, walk the spec lens of `skills/woostack-harden/references/angle-preflight.md`: capture each implicated angle — security, observability, api, database, edge/error — as a §6 error path or a §7 error/edge case.

- **AC1 — {{behavior}}**
  - happy: {{expected}}
  - error: {{expected}}
  - edge: {{expected}}
- **AC2 — {{behavior}}**
  - happy: {{expected}}
  - error: {{expected}}
  - edge: {{expected}}

## 8. Testing

> Strategy only — harness, test levels, fixtures, CI. Per-behavior cases live in §7.

{{TESTING}}

## 9. Open questions

{{OPEN_QUESTIONS}}
