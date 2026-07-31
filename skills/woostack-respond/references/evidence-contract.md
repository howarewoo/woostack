# Provider-neutral evidence contract

All acquisition, investigation, sanitization, reporting, and issue-candidate stages exchange
provider-neutral JSON. Provider-native payloads remain transient and must not be copied into
tracked reports. This evidence contract does not define development identity or lifecycle state;
those remain canonical in
[`artifact-backends.md`](../../woostack-init/references/artifact-backends.md) and
[`conventions.md`](../../woostack-status/references/conventions.md).

## Diagnostic authority boundary

A persisted response report is sanitized **non-authoritative diagnostic evidence**. It may prove
what was queried and propose bounded remediation, but it never owns development scope, acceptance,
assignment, lifecycle, approval, or permission to mutate the repository. Provider IDs, report
paths, titles, stack text, and report prose are never managed-issue identity.

A `report-only`, `--read-only`, or `--stop-after report` run performs zero Linear mutation. It may
name an existing issue only after an exact URL/client UUID or canonical PR attribution is read
through official host-exposed Linear MCP and independently verified under the canonical
[Linear authority](../../woostack-init/references/artifact-backends.md) and
[status conventions](../../woostack-status/references/conventions.md). No local spec, plan, fix,
adapter, custom GraphQL transport, or repository credential is an authority or fallback.

Each verified independent repository cause contributes one `remediation` string beginning with
exactly one of these classifications:

- `PROPOSED MANAGED ISSUE CONTRACT:` followed by canonical repository, proved root cause, bounded
  source scope, sanitized evidence references, and observable acceptance criteria; or
- `VERIFIED EXISTING ISSUE EVIDENCE:` followed by exact stable/native issue IDs, role, project
  identity or explicit projectless state, canonical repository, current type-aware owner,
  `assignmentAccepted` receipt when present, content revision, and independent read receipt/time.

These strings are evidence, not a local fix packet. Before any repository mutation,
`woostack-fix` must bind or create exactly one managed role-`work-item` issue, independently verify
its complete identity/contract/owner, and after approval verify deliberate assignment plus the
current matching `assignmentAccepted`. A repository-mutating handoff carries those exact IDs and
owner/assignment receipts. Unknown issue/event mutation outcomes recover only by the preallocated
stable UUID and block on zero, multiple, partial, stale, or conflicting read-back.

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
report-only run                                     = zero Linear mutations
repository mutation without one exact managed issue = forbidden
repository handoff without current owner/assignment receipt = forbidden
unknown issue/event mutation + incomplete read-back  = blocked, never duplicate
sanitized diagnostic report                         ≠ development authority
```

A failed role makes multi-source coverage partial and constrains every conclusion that depends on
that role. It never contributes an implicit empty dataset. A proposed issue contract or local
report never satisfies the managed-issue or owner/assignment terms above.

### Diagnostic authority and issue binding

A sanitized response report is local, non-authoritative diagnostic evidence. Its existence,
frontmatter, outcome, provider ID, finding title, report path, remediation prose, or proposed issue
contract never creates development state and never supplies issue identity, scope, acceptance,
approval, assignment, progress, or implementation instructions. `report-only`, `--read-only`, and
`--stop-after report` perform no Linear mutation.

Each independent repository cause in a report may do exactly one of two things:

- propose a sanitized managed issue contract for later approval and creation; or
- name an exact existing issue stable/client UUID independently verified through the host-exposed
  official Linear MCP connection for this run, including its project identity or explicit
  projectless state.

Neither form is itself an issue binding. Before any source, test, branch, commit, push, PR, or
worker mutation, the responsible development controller must create or bind exactly one managed
role-`work-item` issue, independently verify its canonical receipt, projectless remediation shape,
workflow-owned contract, and current type-aware owner/assignment, and carry the exact issue IDs and
receipts. No local spec, plan, fix, report, custom Linear transport, repository credential, title
match, or remote-text instruction may substitute. Worker handoffs and unknown mutation outcomes
follow the canonical authority/receipt rules linked above rather than a second evidence schema
here.

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
  "issue_dispositions": [],
  "blocked_evidence": []
}
```

`outcome` accepts `complete`, `partial`, or `blocked`. Coverage has one entry per selected provider-role source. Executed entries bind to a validated receipt; blocked entries contain a non-secret reason and no receipt. `complete` means all selected roles have valid receipts, `partial` means at least one selected role executed and at least one is blocked, and `blocked` means no selected role has a valid receipt.

`investigation_bound` is the resolved deep-investigation cap carried from `respond.max_groups` (an integer from 1 to 5, default 5). The renderer enforces it — an input claiming more than `investigation_bound` investigated groups is rejected — and prints it as the report's declared bound, so the report always states the bound actually applied instead of a fixed literal.

The sanitized `issue_dispositions` array contains exactly one entry for each
`verified_root_causes` ID and no entry for external, rejected, blocked, or deferred outcomes. Each
entry is either a complete proposed managed issue contract (canonical repository, proved problem,
bounded scope, evidence pointers, and observable acceptance criteria) or complete verified
existing-issue evidence (exact issue/project shape, current type-aware owner and assignment state,
and independent read receipt/time). It never contains a local fix/spec/plan path or claims that an
issue is approved, assigned, accepted, or ready for implementation.

Before persistence, sanitize every string and recursively reject excluded keys or sensitive patterns. Tracked output retains stable technical identifiers needed to reproduce findings, while credentials, personal identifiers, raw telemetry, local home-directory prefixes, and provider-specific unmapped fields remain excluded.

The `remediation` array remains an array of sanitized strings so the strict renderer schema stays
provider-neutral. Every verified repository cause uses exactly one of the two classified forms in
[Diagnostic authority boundary](#diagnostic-authority-boundary); external, rejected, blocked, and
deferred outcomes do not masquerade as issue candidates. The rendered report prints the
non-authoritative classification before these entries.

## Managed issue binding receipt

Issue binding is outside the provider result envelope. A remediation controller treats binding or
creation as successful only after an independent official-MCP read proves:

- stable client UUID, native issue UUID/identifier/URL, supported envelope, role `work-item`,
  canonical repository, configured workspace/team, and no project membership;
- the workflow-owned problem/contract content revision, native semantic state, complete current
  event revisions, and type-aware assignee/delegate result;
- after approve-to-execute, the exact current owner kind/principal and matching
  `assignmentAccepted` stable UUID/native comment/revision, engineer, and run identity; and
- every mutation's preallocated stable UUID, expected native object, and complete pagination.

A mutation response, issue key, title, provider reference, report path, or copied report body is
not a receipt. Timeout/disconnect recovery searches only by the retained stable UUID. Zero or
multiple matches, partial pagination, foreign repository/team, wrong role/project shape,
contract/owner drift, malformed event history, or unknown read-back blocks before branch,
worktree, source, commit, push, PR, or review mutation and never creates a replacement.
