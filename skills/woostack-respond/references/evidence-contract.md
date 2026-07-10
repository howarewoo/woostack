# Provider-neutral evidence contract

All acquisition, investigation, sanitization, and rendering stages exchange provider-neutral JSON. Provider-native payloads remain transient and must not be copied into tracked reports.

## Result envelope

Every real source query writes one UTF-8 JSON result envelope before its receipt is created:

```json
{
  "schema_version": 1,
  "provider": "sentry",
  "role": "error-tracking",
  "target": {"project": "acme/api", "environment": "production"},
  "window": {"start": "2026-07-09T18:00:00Z", "end": "2026-07-10T18:00:00Z"},
  "query_summary": "unresolved error/fatal groups",
  "records": []
}
```

`schema_version` is the integer `1`. `provider`, `role`, `query_summary`, target values, and UTC window boundaries are non-empty strings. `records` is an array. The provider slug is descriptive, not a whitelist. The role is one of the selected coverage roles (for example `error-tracking`, `logs`, `traces`, `metrics`, or `deployment-metadata`).

## Acquisition receipt

After the envelope has been completely written, compute the digest from its exact bytes and create a separate receipt:

```json
{
  "provider": "sentry",
  "role": "error-tracking",
  "integration": "sentry-cli",
  "project": "acme/api",
  "environment": "production",
  "window_start": "2026-07-09T18:00:00Z",
  "window_end": "2026-07-10T18:00:00Z",
  "query_summary": "unresolved error/fatal groups",
  "status": "executed",
  "records_returned": 31,
  "output_path": ".woostack/respond/evidence/20260710T180000Z-recent-errors/error-tracking.json",
  "output_sha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
}
```

Receipt status accepts exactly `executed`; the JSON field is `status`. Blocked sources are represented in report input coverage and never receive a receipt. A receipt must never be pre-created or used as proof that a planned command ran.

A valid receipt satisfies all of these checks:

- `provider`, `role`, target, environment, window, and query summary equal the bound envelope and selected query;
- `output_path` resolves to a regular, non-symlink file inside the current run directory, including after canonical path resolution;
- `output_sha256` is the lowercase hexadecimal SHA-256 digest of the exact output file bytes;
- `records_returned` is a non-negative integer, not a boolean, and equals the envelope's `records` array length;
- the envelope has schema version 1 and valid required fields.

A missing, malformed, stale, path-escaping, symlink-bound, digest-mismatched, or count-mismatched receipt is invalid and therefore cannot prove a clean query.

## Hard false-clean and remediation invariants

These equations are exact:

```text
zero records + valid output-bound executed receipt = clean query
zero records + no valid output-bound receipt       = blocked
no verified root cause                             = no fix candidate
```

A failed role makes multi-source coverage partial and constrains every conclusion that depends on that role. It never contributes an implicit empty dataset.

## Normalized records

### Metadata group

The metadata pass emits bounded group records of this shape:

```json
{
  "record_type": "group-metadata",
  "provider": "sentry",
  "role": "error-tracking",
  "group_id": "API-142",
  "provider_ref": "sentry:acme/api:API-142",
  "title": "CheckoutError",
  "severity": "error",
  "state": "unresolved",
  "first_seen": "2026-07-09T19:03:00Z",
  "last_seen": "2026-07-10T17:54:00Z",
  "event_count": 31,
  "affected_estimate": 18,
  "regression": true,
  "release": "api@2026.07.09.2",
  "provider_url": "https://example.invalid/issues/API-142",
  "impact_evidence": ["checkout requests failed"],
  "uncertainty": ["affected-user count is estimated"]
}
```

`group_id` and `provider_ref` are stable technical identifiers. Human titles, URLs, stack text, and timestamps are not identifiers. Unknown optional facts are omitted rather than invented.

### Selected group detail

Only selected groups (at most the configured bound of five) receive detail records:

```json
{
  "record_type": "group-detail",
  "provider_ref": "sentry:acme/api:API-142",
  "representative_failure": {"error_class": "CheckoutError", "message": "payment authorization failed"},
  "stack_frames": [{"file": "src/checkout.py", "function": "authorize", "line": 84, "in_app": true}],
  "trace_ids": ["4c3f0000000000000000000000000000"],
  "span_ids": ["1a2b3c4d5e6f7890"],
  "source_candidates": ["src/checkout.py:authorize"],
  "release_context": {"release": "api@2026.07.09.2", "deploy_at": "2026-07-09T18:45:00Z"},
  "correlated_evidence": [{"role": "logs", "summary": "authorization timeout", "timestamp": "2026-07-10T17:54:00Z"}],
  "impact_evidence": ["18 estimated affected checkouts"],
  "uncertainty": ["upstream response unavailable"]
}
```

Retrieve only the minimum fields needed to distinguish hypotheses. Exclude request and response bodies, complete headers, authorization values, cookies, sessions, user profiles or user objects, emails, phone numbers, IP addresses, arbitrary tags, full breadcrumb histories, tokens, API keys, passwords, connection strings, and high-risk provider context. Sensitive expansion requires stopping for explicit user approval.

## Investigation result

Each selected independent group produces one result:

```json
{
  "provider_ref": "sentry:acme/api:API-142",
  "result": "verified",
  "root_cause": "authorization timeout is not translated to a retryable result",
  "trigger": "upstream authorization latency exceeded two seconds",
  "contributing_factors": ["release reduced the timeout"],
  "evidence": ["focused reproduction fails at src/checkout.py:84"],
  "rejected_hypotheses": ["invalid customer token"],
  "affected_symbols": ["src/checkout.py:authorize"],
  "minimal_remediation": "restore retry classification",
  "failing_test_description": "timeout is classified as retryable",
  "observability_gap": null
}
```

`result` accepts exactly `verified`, `rejected`, or `blocked`. A `verified` result requires a minimally tested repository root cause. Provider-generated explanations and correlations remain hypotheses. Duplicate groups sharing one verified root cause are reconciled into one finding and one fix candidate.

## Normalized report input

The renderer consumes a sanitized object, never provider-native payloads:

```json
{
  "schema_version": 1,
  "signal": "recent production errors",
  "scope": "acme/api",
  "environment": "production",
  "window": {"start": "2026-07-09T18:00:00Z", "end": "2026-07-10T18:00:00Z"},
  "generated_at": "2026-07-10T18:30:00Z",
  "outcome": "partial",
  "coverage": [
    {"provider": "sentry", "role": "error-tracking", "state": "executed", "receipt": "receipts/error-tracking.json", "records_returned": 31},
    {"provider": "datadog", "role": "logs", "state": "blocked", "reason": "authentication unavailable"}
  ],
  "ranked_groups": [],
  "impact_summary": [],
  "timeline": [],
  "investigations": [],
  "verified_root_causes": [],
  "external_incidents": [],
  "observability_gaps": [],
  "remediation": [],
  "blocked_evidence": []
}
```

`outcome` accepts `complete`, `partial`, or `blocked`. Coverage has one entry per selected provider-role source. Executed entries bind to a validated receipt; blocked entries contain a non-secret reason and no receipt. `complete` means all selected roles have valid receipts, `partial` means at least one selected role executed and at least one is blocked, and `blocked` means no selected role has a valid receipt.

Before persistence, sanitize every string and recursively reject excluded keys or sensitive patterns. Tracked output retains stable technical identifiers needed to reproduce findings, while credentials, personal identifiers, raw telemetry, local home-directory prefixes, and provider-specific unmapped fields remain excluded.
