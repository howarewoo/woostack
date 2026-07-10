---
type: response
outcome: {{OUTCOME}}
provider: {{PROVIDER}}
environment: {{ENVIRONMENT}}
window_start: {{WINDOW_START}}
window_end: {{WINDOW_END}}
date: {{DATE}}
---

# Production Error Response — {{SIGNAL}}

## Response & Scope

- **Signal:** {{SIGNAL}}
- **Scope:** {{SCOPE}}
- **Environment:** {{ENVIRONMENT}}
- **UTC window:** {{WINDOW_START}} through {{WINDOW_END}}
- **Outcome:** {{OUTCOME}}
- **Deep-investigation bound:** {{MAX_GROUPS}}

{{SCOPE_SUMMARY}}

## Query Coverage

| Provider | Role | Target | Integration | Query | Receipt | Records | Coverage |
| --- | --- | --- | --- | --- | --- | ---: | --- |
{{QUERY_COVERAGE_ROWS}}

A clean query is reported only when zero records are bound to a validated executed receipt. Blocked sources have no receipt and appear under Uncovered and Blocked Evidence.

## Ranked Error Queue

| Rank | Stable group ID | Summary | Impact | Recency/frequency | Release correlation | Investigation result |
| ---: | --- | --- | --- | --- | --- | --- |
{{RANKED_ERROR_ROWS}}

## Impact Summary

{{IMPACT_SUMMARY}}

## Incident Timeline

| UTC time | Stable source reference | Event | Evidence or uncertainty |
| --- | --- | --- | --- |
{{TIMELINE_ROWS}}

## Investigated Groups

{{INVESTIGATED_GROUPS}}

For each group, record its stable provider reference, `verified`, `rejected`, or `blocked` investigation result, evidence, rejected hypotheses, affected symbols, and remaining uncertainty.

## Verified Root Causes

{{VERIFIED_ROOT_CAUSES}}

Only minimally tested repository root causes belong here. If there is no verified root cause, state “None” and create no fix candidate.

## External or Non-Code Incidents

{{EXTERNAL_INCIDENTS}}

Record third-party outages, configuration conditions, operational events, and other verified incidents that are not local repository defects. Do not convert them into speculative code fixes.

## Observability Gaps

{{OBSERVABILITY_GAPS}}

Record material missing signals and the exact `/woostack-build` recommendation when an architectural observability capability is required. Do not start a nested build flow.

## Remediation

{{REMEDIATION}}

List report-only recommendations and any separately gated `woostack-fix` preparation for verified repository defects. Do not imply that provider, production, code, or infrastructure mutation occurred.

## Uncovered and Blocked Evidence

| Provider | Role | Target/window dependency | Blocker | Conclusions constrained | Next safe action |
| --- | --- | --- | --- | --- | --- |
{{BLOCKED_EVIDENCE_ROWS}}

Explicitly state “None” only when every selected source role has a valid output-bound executed receipt. Never include raw provider payloads, request or response bodies, headers, cookies, user profiles, arbitrary tags, or full breadcrumb histories in this report.
