---
type: response
outcome: <complete|partial|blocked>
provider: <single provider slug, or "multiple" when coverage spans providers>
environment: <environment>
window_start: <ISO-8601 UTC start>
window_end: <ISO-8601 UTC end>
date: <YYYY-MM-DD>
---

# Production Error Response — <signal>

<!-- Canonical section and field-order reference. `scripts/render-report.py` is the sole
producer of reports from sanitized normalized input (see `evidence-contract.md`). Placeholder
list items below show emitted Markdown; explanatory paragraphs are reference annotations and
are not emitted. The renderer does not consume this file as a template. Keep both in sync. -->

## Response & Scope

- Signal: <signal>
- Scope: <scope>
- Environment: <environment>
- UTC window: <window_start> through <window_end>
- Outcome: <outcome>
- Deep-investigation bound: <investigation_bound — the resolved `respond.max_groups`, an integer from 1 to 5>

## Query Coverage

- <provider> / <role>: executed — <records> records; receipt `<receipt path>`
- <provider> / <role>: blocked — <non-secret reason>

A clean query is reported only when zero records are bound to a validated executed receipt. Blocked sources have no receipt and also appear under Uncovered and Blocked Evidence.

## Ranked Error Queue

1. <group id> — <summary> (impact <n>, frequency <n>; <verified|rejected|blocked|Deferred>)

Every ranked group appears here in impact, then frequency, then recency, then id order. When no group matched the executed queries, this section reads `No error groups matched the executed queries.`

## Impact Summary

- <impact statement>

## Incident Timeline

- <UTC time: event, with evidence or uncertainty>

## Investigated Groups

- <group id>: <verified|rejected|blocked> — <hypothesis>; evidence: <evidence; …>

At most `investigation_bound` groups are investigated; the remainder are marked `Deferred` in the Ranked Error Queue and listed under Uncovered and Blocked Evidence.

## Verified Root Causes

### <cause id> — <summary>

- <evidence>

Only minimally tested repository root causes belong here. If there is no verified root cause, this section reads `None.` and no fix candidate is created.

## External or Non-Code Incidents

### <incident id> — <summary>

- <evidence>

Third-party outages, configuration conditions, operational events, and other verified incidents that are not local repository defects. They are never converted into speculative code fixes.

## Observability Gaps

- <material missing signal, with the exact `/woostack-build` recommendation when an architectural observability capability is required>

## Remediation

- <report-only recommendation, or separately gated `woostack-fix` preparation for a verified repository defect>

## Uncovered and Blocked Evidence

- <blocked source, or a group deferred below the deep-investigation bound, and the conclusions it constrains>

Reads `None.` only when every selected source role has a valid output-bound executed receipt and no group was deferred. Never include raw provider payloads, request or response bodies, headers, cookies, user profiles, arbitrary tags, or full breadcrumb histories in this report.
