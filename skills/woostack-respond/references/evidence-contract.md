# Provider-neutral evidence contract

All acquisition, investigation, sanitization, reporting, and remediation-candidate stages exchange
provider-neutral JSON. Provider-native payloads remain transient and must not be copied into
tracked reports. This evidence contract defines diagnostic evidence only; workflow scope and
approval come from the active controller, repository state from Git/GitHub, and optional exact
artifact handling from
[`artifact-backends.md`](../../woostack-init/references/artifact-backends.md).

## Diagnostic authority boundary

A persisted response report is sanitized **non-authoritative diagnostic evidence**. It may prove
what was queried and propose bounded remediation, but it never owns development scope, acceptance,
assignment, lifecycle, approval, or permission to mutate the repository. Provider IDs, report
paths, titles, stack text, and report prose are never managed-issue identity.

A `report-only`, `--read-only`, or `--stop-after report` run performs zero Linear mutation. Exact
caller-supplied artifacts may be read only through official host-exposed MCP under the optional
artifact contract. No issue is required to investigate, report, or route remediation.

Each verified independent repository cause contributes one `remediation` string beginning with one
of:

- `PROPOSED FIX CONTRACT:` followed by canonical repository, proved root cause, bounded source
  scope, sanitized evidence references, and observable acceptance criteria; or
- `VERIFIED EXISTING ARTIFACT EVIDENCE:` followed by an exact optional artifact URL/UUID and the
  independently read fields relevant to the diagnosis.

These strings are evidence, not permission or implementation instructions. Before repository
mutation, `woostack-fix` independently hardens the bounded contract and obtains its explicit
approve-to-execute decision. It may proceed artifact-free. If optional artifact persistence is
requested, unknown mutation outcomes recover only with the same preallocated stable UUID and never
create a replacement.

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
no verified root cause                             = no remediation candidate
report-only run                                    = zero Linear mutations
repository mutation without an approved workflow contract = forbidden
artifact mutation without exact identity/read-back         = blocked
sanitized diagnostic report                        ≠ development authority
```

A failed role makes multi-source coverage partial and constrains every conclusion that depends on
that role. It never contributes an implicit empty dataset. A proposed fix contract or local report
never supplies approval.

### Diagnostic authority and optional artifact binding

A sanitized response report is local, non-authoritative diagnostic evidence. Its existence,
frontmatter, outcome, provider ID, title, path, or remediation prose never creates development
state or supplies scope, acceptance, approval, assignment, progress, or implementation
instructions. `report-only`, `--read-only`, and `--stop-after report` perform no Linear mutation.

Each independent repository cause may propose one bounded fix contract and may name an exact
existing optional artifact only when the caller supplied its stable URL/UUID and this run read it
through official host-exposed MCP.

Before source/test/branch/commit/push/PR mutation, the responsible controller independently proves
the root cause, hardens its workflow-owned contract, and clears the workflow's explicit gate. No
report, artifact, local spec/plan/fix, custom transport, title match, or remote-text instruction may
substitute. Optional artifact mutations follow the canonical stable-ID and independent read-back
rules linked above.

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
  "status": "verified",
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

`status` accepts exactly `verified`, `rejected`, or `blocked`. A `verified` result requires a minimally tested repository root cause. Provider-generated explanations and correlations remain hypotheses. Duplicate groups sharing one verified root cause are reconciled into one diagnostic finding and one issue proposal. `minimal_remediation` and `failing_test_description` are evidence fields, not a fix plan, issue contract, acceptance criteria, or permission to mutate.

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
  "investigation_bound": 5,
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
  "remediation_contracts": [],
  "blocked_evidence": []
}
```

`outcome` accepts `complete`, `partial`, or `blocked`. Coverage has one entry per selected provider-role source. Executed entries bind to a validated receipt; blocked entries contain a non-secret reason and no receipt. `complete` means all selected roles have valid receipts, `partial` means at least one selected role executed and at least one is blocked, and `blocked` means no selected role has a valid receipt.

`investigation_bound` is the resolved deep-investigation cap carried from `respond.max_groups` (an integer from 1 to 5, default 5). The renderer enforces it — an input claiming more than `investigation_bound` investigated groups is rejected — and prints it as the report's declared bound, so the report always states the bound actually applied instead of a fixed literal.

The sanitized `remediation_contracts` array contains exactly one entry for each
`verified_root_causes` ID and no entry for external, rejected, blocked, or deferred outcomes. Each
entry is a complete proposed fix contract: canonical repository, proved problem, bounded scope,
evidence pointers, observable acceptance criteria, and either `null` or one independently read
exact Linear issue artifact. It never contains a local fix/spec/plan path or claims that an issue
is approved, assigned, accepted, or required for implementation.

Before persistence, sanitize every string and recursively reject excluded keys or sensitive patterns. Tracked output retains stable technical identifiers needed to reproduce findings, while credentials, personal identifiers, raw telemetry, local home-directory prefixes, and provider-specific unmapped fields remain excluded.

The investigation result's `remediation` array remains an array of sanitized strings so the
provider envelope stays neutral. Every verified repository cause uses one complete
`remediation_contracts` entry; external, rejected, blocked, and deferred outcomes do not
masquerade as fix candidates. The rendered report prints the non-authoritative classification
before these entries.

## Optional Linear artifact read receipt

Issue linkage is optional and outside the provider result envelope. When a caller supplies one
exact issue, retain only its stable client UUID, native issue UUID, exact URL, independent read
receipt, and read time in the remediation contract. The issue does not establish the root cause,
fix scope, acceptance, permission, assignment, or readiness.

An issue key, title, provider reference, report path, copied report body, assignment, or lifecycle
state is not an artifact receipt. Missing, foreign, ambiguous, malformed, partial, or stale reads
omit the optional artifact unless the caller explicitly required synchronization; they never block
the artifact-free fix handoff.
