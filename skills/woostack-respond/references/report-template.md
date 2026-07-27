Non-authoritative diagnostic evidence — report only.

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
producer of reports from sanitized normalized input (see `evidence-contract.md`). The renderer
does not consume this file as a template. Keep both in sync. -->

## Response & Scope

- Signal: <signal>
- Scope: <scope>
- Environment: <environment>
- UTC window: <window_start> through <window_end>
- Outcome: <outcome>
- Deep-investigation bound: <investigation_bound — the resolved `respond.max_groups`, 1 to 5>

## Query Coverage

- <provider> / <role>: executed — <records> records; receipt `<receipt path>`
- <provider> / <role>: blocked — <non-secret reason>

## Ranked Error Queue

1. <group id> — <summary> (impact <n>, frequency <n>; <verified|rejected|blocked|Deferred>)

## Impact Summary

- <impact statement>

## Incident Timeline

- <UTC time: event, with evidence or uncertainty>

## Investigated Groups

- <group id>: <verified|rejected|blocked> — <hypothesis>; evidence: <evidence; …>

## Verified Root Causes

### <cause id> — <summary>

- <minimum sanitized evidence>

## External or Non-Code Incidents

### <incident id> — <summary>

- <minimum sanitized evidence>

## Observability Gaps

- <material missing signal>

## Remediation

Authority: non-authoritative diagnostic evidence

Exactly one disposition is emitted for each verified repository cause. External/non-code incidents
receive no repository issue disposition.

### <cause id> — proposed-managed-issue-contract

- Canonical repository: <repository>
- Proved problem: <verified problem/root cause>
- Bounded scope: <source scope>
- Evidence: <sanitized evidence pointer>
- Observable acceptance criterion: <observable behavior>

**OR**, when an exact supplied issue passed complete official-MCP verification:

### <cause id> — verified-existing-issue-evidence

- Issue: <stable UUID> / <native ID> / <URL>
- Role/project: <role> / <project stable/native IDs | explicitly projectless>
- Owner: <human|app> / <native principal ID>
- Assignment: <current receipt | independently verified absent>
- Independent read: <receipt ID> at <timestamp>

## Uncovered and Blocked Evidence

- <blocked source or deferred group, and the conclusions it constrains>

Never include raw provider payloads, request/response bodies, headers, cookies, user profiles,
arbitrary tags, full breadcrumb histories, local fix/spec/plan paths, branch names, or PR links.
