---
name: woostack-respond
type: spec
status: approved
date: 2026-07-10
branch: feature/woostack-respond
links:
---

# woostack-respond — Production Error Response — Design Spec

> Visualize on demand: render this file with [spec-template.html](../../../skills/woostack-build/references/spec-template.html) for a rich view. Markdown is the source of truth; the HTML is a presentation target only.

> `status:` is the build-loop phase enum: `draft → hardened → approved → planning → ready → executing → in-review → done` (plus the terminal `abandoned`). The build loop authors each transition and `/woostack-status` reads it; the enum and join contracts are defined once in [conventions.md](../../../skills/woostack-status/references/conventions.md).

> **Plan:** [[plans/2026-07-10-woostack-respond]]

## 1. Problem

woostack can root-cause a supplied technical failure (`woostack-debug`), drive a bounded code
correction through approval and implementation (`woostack-fix`), audit standing code
(`woostack-audit`), review diffs (`woostack-review`), and explore a running web app
(`woostack-qa`). It has no command that starts from **live production telemetry** and performs
the operational response work before a repository fix is well-defined.

A user cannot currently ask woostack to inspect a repository's configured error tracker, rank
recent production errors, correlate representative events with traces/logs/releases/deploys,
assess impact, verify root causes against current source, and safely prepare the resulting fixes.
Provider dashboards and ad-hoc prompts leave provider selection, authentication failure, query
coverage, privacy, duplicate grouping, and remediation authority implicit. The dangerous failure
mode is a false-clean or speculative fix: an unavailable integration appears as “no errors,” or a
correlation becomes a patch before the root cause is established.

The current init scaffold also cannot help a consumer establish safe, non-secret defaults for
this workflow. `.woostack/config.json` has no `respond` namespace, provider discovery guidance,
or explicit recent-error window and response bound.

## 2. Goal

Add a public command skill, **`woostack-respond`**, with this default experience:

```text
/woostack-respond to recent errors
```

The command discovers repository observability instrumentation and host-provided provider
integrations; runs bounded, read-only production queries with proof of execution; minimizes,
normalizes, and sanitizes evidence; ranks a broad queue; investigates up to five high-impact
independent error groups using `woostack-debug`'s root-cause discipline; writes one tracked,
sanitary response report under `.woostack/respond/`; and prepares every verified independent
repository defect through a separate `woostack-fix` run up to its existing committed-plan
approval gate.

Material observability capabilities are recorded as exact `/woostack-build` recommendations
rather than silently starting nested feature builds. Provider and production state remain
read-only. `woostack-init` optionally detects available instrumentation/integrations and helps
write only non-secret workflow settings; `woostack-doctor` validates and repairs the namespace.
Tracked response reports become non-prunable decision-corpus inputs for `woostack-dream`, while
verified implementation learning continues to enter scoped memory through `woostack-execute`.

## 3. Non-goals

- **No shipped provider API clients.** The first release does not implement or maintain Sentry,
  Datadog, Axiom, Honeycomb, or other REST clients. It uses a specialized provider MCP/tool,
  installed provider skill, authenticated official CLI, or a user-supplied exported artifact.
- **No provider mutation.** Never resolve, archive, mute, assign, merge, or delete provider
  issues; never edit alerts, dashboards, sampling, or retention.
- **No production operation.** Never deploy, roll back, restart, scale, shift traffic, change
  flags, or mutate infrastructure.
- **No duplicate debugger or executor.** Root-cause method stays in `woostack-debug`; code,
  tests, worktrees, commits, PRs, and approval gates stay in `woostack-fix`, `woostack-execute`,
  `woostack-build`, and `woostack-commit`.
- **No speculative fix.** A correlation, provider-generated explanation, or suspected frame is
  a hypothesis. Only a minimally tested `verified` root cause may enter a fix plan.
- **No raw telemetry corpus.** Raw provider payloads and evidence are transient and gitignored;
  tracked reports contain normalized, sanitized evidence only.
- **No automatic nested feature build.** Architectural observability gaps receive an exact
  `/woostack-build` recommendation; respond does not start another design loop.
- **No browser-dashboard fallback.** The first release does not automate provider web UIs.
- **No rename work.** The separately filed `woostack-tdd` and `woostack-qa` rename proposals are
  outside this feature.

## 4. Approach

### 4.1 Command contract and defaults

```text
/woostack-respond <signal> [scope]
```

Examples:

```text
/woostack-respond to recent errors
/woostack-respond to production errors from the last 6 hours
/woostack-respond to Sentry issue API-142
/woostack-respond to checkout latency since the latest deploy
/woostack-respond to trace 4c3f...
/woostack-respond to this exported incident artifact
```

Optional controls:

```text
--since <duration>
--environment <name>
--service <name>
--provider <name>
--limit <1-5>
--read-only
--stop-after report
```

Safe built-in defaults:

```text
provider: auto
environment: production
window: 24h
max_groups: 5
remediation: prepare-fix
```

`--read-only` and `--stop-after report` both override remediation to report-only for the run;
`report` is the only valid `--stop-after` value. At preflight the skill prints provider, target,
environment, exact UTC window, query scope, and deep-investigation bound. After the metadata pass
it prints the candidate count before ranking.

### 4.2 Capability-driven provider discovery

Provider resolution precedence is:

1. explicit command provider/target;
2. non-`auto` `respond.provider` config;
3. repository evidence (dependencies, SDK imports/initialization, provider config names,
   OpenTelemetry exporters, deployment config, environment-variable **names**, never values);
4. matching host capabilities, in order: specialized provider MCP/tool → installed provider
   skill → authenticated official CLI → supplied exported artifact.

Known signatures accelerate discovery but do not form a provider whitelist. When several
providers contribute complementary roles, respond may use each for error tracking, logs,
traces, metrics, or deployment metadata if they resolve to the same service/environment/window.
Two ambiguous providers claiming the same role cause a stop-and-ask rather than a guess.
Host capabilities never auto-select a provider without corroborating repository evidence or an
explicit user/config choice. With no repository evidence, one available host provider capability
may be offered for explicit confirmation; it is never queried merely because it is installed.

No available integration, missing authentication, unresolved target, or environment mismatch is
**blocked**, never an empty result. Init may report provider-native authentication setup but never
collect or persist credentials.

### 4.3 Bounded evidence acquisition and receipts

Acquisition is progressive:

1. **Metadata pass** for a bounded queue: issue/group ID, title/error class, severity, status,
   first/last seen, event count, affected-user estimate, regression/release state, provider link.
2. **Detail pass** only for the selected maximum five groups: representative event, sanitized
   stack frames, trace/span tree, selected correlated logs, release/deploy context, and the
   minimum additional fields required to distinguish hypotheses.

Request/response bodies, complete headers, cookies, user profiles, arbitrary tags, and full
breadcrumb histories are excluded by default. If sensitive context is essential, respond stops
and asks before broadening retrieval.

Every selected provider role produces an acquisition receipt **after** its real query output has
been written to the current evidence directory. The orchestrator wraps that output in a
provider-neutral result envelope, computes its SHA-256 digest, then writes the receipt:

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
  "output_sha256": "<sha256>"
}
```

`status` accepts exactly `executed`; a blocked source is represented separately and is not a
valid acquisition receipt. The validator requires a regular, non-symlink output file inside the
current run directory, verifies its digest, and verifies `records_returned` against the result
envelope. A receipt is never pre-created. The invariant is:

```text
zero records + valid output-bound executed receipt = clean query
zero records + no valid output-bound receipt       = blocked
```

For multiple providers, a failed source makes the report partial and constrains conclusions that
require it. It never silently contributes an empty dataset.

### 4.4 Normalization, minimization, and sanitization

Provider results normalize to a common evidence contract covering:

- group metadata and stable provider references;
- release/deployment context;
- representative failure, trace/span IDs, and source candidates;
- impact evidence and uncertainty.

Provider-specific fields remain transient unless mapped into this contract. A deterministic
sanitizer is the tracked-write boundary. It recursively redacts authorization/cookie/session
values, tokens/keys/passwords/connection strings, personal identifiers, emails/phones/IPs,
user objects, raw bodies, home-directory prefixes, and high-risk provider context fields.
Stable placeholders preserve report structure. A second validation pass rejects any report that
still contains credential-like keys or sensitive-value patterns.

Host tool results may enter active agent context before sanitization; progressive field selection
is therefore the first privacy defense, and deterministic sanitization is the persisted-artifact
defense. The skill must state this limitation honestly.

Transient evidence normally lives under:

```text
.woostack/respond/evidence/<run-id>/
```

`<run-id>` is the UTC basic timestamp plus the normalized signal/scope slug, with `-2`, `-3`, …
appended on collision. Before any provider query, respond verifies with the repository ignore
engine that the exact evidence path is excluded. If an older workspace lacks that exclusion,
respond uses a mode-`0700` operating-system temporary directory outside the repository instead;
it never writes raw telemetry into a trackable repository path and never edits ignore rules
implicitly. The chosen path is disclosed before acquisition.

Evidence is never mined by dream. It is deleted only after the terminal summary, once report-only
processing or all requested fix preparations have reached their terminal gates. An aborted run,
sanitization failure, or fix-preparation failure retains it with an explicit path and manual
deletion instruction. Doctor warns about retained response evidence older than 24 hours.

### 4.5 Ranking and parallel root-cause investigation

Rank independent groups by production/data-integrity impact, affected users/requests, severity,
frequency/acceleration, regression/release correlation, recurrence, and confidence that local
repository code is implicated. Duplicate manifestations collapse under one candidate. A
third-party outage is not converted into a local defect because it generated many events.

Deeply investigate up to `max_groups` (1–5; default 5), in parallel when the groups are
independent. Each read-only investigator receives only its normalized evidence, relevant source
and release context, applicable memory/wisdom, and the `woostack-debug` four-phase contract. It
returns:

```text
status: verified | rejected | blocked
root cause
trigger
contributing factors
evidence
rejected hypotheses
affected files/symbols
minimal remediation
failing-test description
observability gap
```

The parent reconciles duplicates before remediation. Two groups with one root cause become one
report finding and one fix plan. Only `verified` repository root causes may proceed.

### 4.6 Response report and outcomes

Write one tracked-intended report per run:

```text
.woostack/respond/YYYY-MM-DD-<slug>.md
```
The slug is deterministically derived from the normalized signal and explicit scope. If that
same-day report path already exists, append `-2`, `-3`, …; never overwrite a prior run.

Frontmatter uses `outcome`, not the load-bearing spec/plan/fix `status:` field:

```yaml
---
type: response
outcome: complete
provider: sentry
environment: production
window: 2026-07-09T18:00:00Z/2026-07-10T18:00:00Z
updated: 2026-07-10
---
```

Valid outcomes are `complete`, `partial`, and `blocked`. Complete means the bounded response
contract executed honestly, not that every production error was fixed.

The report contains query coverage/receipts, ranked queue, impact, incident timeline,
investigated groups, verified/rejected/blocked hypotheses, external/non-code incidents,
observability gaps, remediation, uncovered evidence, and fix artifact/branch/PR links. It never
contains raw payload dumps. It is written to the working tree but not committed automatically,
matching the audit/QA report pattern; the handback names it as a tracked-intended change.

### 4.7 Remediation

After the sanitized report is safely written, `prepare-fix` remediation sends every verified
independent repository defect through a separate `woostack-fix` flow. The handoff contains only
the sanitizer-validated report and a sanitizer-validated defect packet; no pre-sanitization
evidence may enter a fix artifact, commit, PR title/body, or other tracked/remote write. Respond
may prepare independent fix plans in parallel; overlapping files or shared invariants force
consolidation or serialization. Each fix flow owns its worktree, branch, committed fix artifact,
PR, and explicit execution gate. Respond never infers approval and never begins implementation
merely because it was invoked. `report-only`, `--read-only`, and `--stop-after report` do not
dispatch `woostack-fix`.

A provider outage, expected error, data-quality anomaly, or unverified correlation remains
report-only. A small instrumentation defect directly serving the verified correction may join the
same fix. A material observability capability becomes an exact `/woostack-build` recommendation.

### 4.8 Self-improvement

Tracked response reports become non-prunable decision-corpus input to `woostack-dream` alongside
specs/plans/fixes. Dream may use response paths as permanent wisdom provenance, but one incident
does not establish generalized wisdom; recurring, corroborated inputs are required. Response
reports never directly create memory notes and are never pruned. Evidence directories are
excluded.

Verified fix implementation still distills scoped implementation learning through
`woostack-execute`. The channels remain distinct:

```text
respond report → what happened and what evidence was missing
fix execution  → durable implementation lesson
dream          → recurring cross-cutting wisdom
```

## 5. Components & data flow

### 5.1 New skill assets

```text
skills/woostack-respond/
├── SKILL.md
├── references/
│   ├── provider-discovery.md
│   ├── evidence-contract.md
│   └── report-template.md
└── scripts/
    ├── load-respond-config.sh
    ├── validate-receipt.py
    ├── sanitize-telemetry.py
    ├── render-report.py
    └── tests/
        ├── test-load-respond-config.sh
        ├── test-validate-receipt.sh
        ├── test-sanitize-telemetry.sh
        └── test-render-report.sh
```

`SKILL.md` owns orchestration. Provider discovery and evidence normalization remain documented
contracts because host integration APIs vary. The small scripts own deterministic config,
receipt, redaction, and rendering invariants. No provider API client ships.

### 5.2 Init and doctor integration

The canonical init template becomes:

```json
{
  "models": {},
  "review": {},
  "respond": {},
  "status": { "staleDays": 14 }
}
```

Supported `respond` keys:

| Key | Type | Default | Rule |
|---|---|---|---|
| `provider` | string | `"auto"` | `auto` or a non-empty lowercase provider slug; no fixed provider whitelist. |
| `environment` | string | `"production"` | Non-empty; explicit invocation wins. |
| `window` | duration string | `"24h"` | `m`/`h`/`d` duration from 5 minutes through 30 days inclusive. |
| `max_groups` | integer | `5` | 1–5 inclusive. |
| `remediation` | enum | `"prepare-fix"` | `prepare-fix` or `report-only`. |

Unknown keys, wrong types, malformed durations, out-of-range bounds, invalid remediation, and
credential-like keys hard-fail the respond loader. Unknown provider slugs pass syntax validation
but block at runtime without a matching integration. Sibling config namespaces are untouched.

Interactive init offers `Set up production error response? [y/N]`. Accepted setup discovers
repository instrumentation and host capabilities, presents candidates/gaps, and guides provider,
environment, window, max groups, and remediation. New flags:

```text
--respond
--no-respond
```

`--respond` skips the initial opt-in; `--no-respond` skips discovery/setup; both is a usage error.
Existing config is merged only with explicit setup approval and never clobbered. `--no-clobber`
skips prompts unless `--respond` is explicit. Init reports authentication prerequisites but does
not collect credentials or fail merely because auth is not yet available.

The init scaffold adds `.woostack/respond/.gitkeep` and `respond/evidence/` to its `.gitignore`.
Doctor's template-based missing-key repair gains `respond` automatically; response-specific checks
validate its namespace and forbidden credential keys without making live provider requests.
Doctor also warns about retained evidence directories older than 24 hours and recommends manual
deletion; it never reads or prints their contents.

### 5.3 Knowledge and command-surface integration

Update the public command/adoption surface in lockstep: root project instructions, README,
`using-woostack` routing, CONTRIBUTING, bootstrap development summary where applicable, authored
site pages, install/discovery checks, counts, and quick-file maps. Generated per-skill site pages
remain generator-owned.

Update `woostack-dream`, the wisdom contract, and authored memory/concepts docs so tracked
`.woostack/respond/*.md` files are decision corpus/provenance, `respond/evidence/` is excluded,
and response reports are never pruned or indexed as scoped memory.

### 5.4 End-to-end flow

```text
/woostack-respond <signal> [scope]
  → resolve config + exact target/window
  → detect instrumentation + host capabilities
  → preflight target/auth/read capability                     — blocked on ambiguity/failure
  → verify evidence storage is ignored or select secured OS temp   — before provider access
  → bounded metadata query + executed receipt
  → rank queue
  → selected detail queries + receipts
  → normalize + minimize
  → parallel read-only root-cause investigations (≤5)
  → reconcile duplicates and classifications
  → sanitize + validate
  → write .woostack/respond/<date>-<slug>.md                  — tracked-intended report
  → verified independent repository defects → woostack-fix   — separate plan PRs
  → stop at each existing fix execution-approval gate
  → terminal summary: coverage, outcomes, report, PRs, gaps
```

## 6. Error handling

- **No provider detected:** blocked discovery result with checked surfaces and exact next actions;
  no fabricated query or clean report.
- **Provider detected, host integration missing:** blocked with the missing CLI/MCP/skill/artifact
  prerequisite.
- **Authentication missing/expired:** blocked with provider-native login/setup instruction; no
  credential collection.
- **Wrong target/environment:** stop before reading incident data and name the mismatch.
- **One of several providers fails:** partial report; conclusions depending on the missing source
  remain blocked or explicitly lower-confidence.
- **Zero groups:** clean only with a valid executed receipt; state “zero matching groups in this
  query,” never “production has no errors.”
- **More than five groups:** rank the bounded queue, investigate the configured maximum, and list
  deferred coverage explicitly.
- **Root cause unverified:** record tested/rejected hypotheses and missing evidence; no fix plan.
- **Sensitive context required:** ask before broadening retrieval.
- **Sanitization validation fails:** do not write/update the tracked report; retain gitignored
  evidence, block, and name only its path.
- **Provider tool dies mid-query:** no receipt, therefore blocked/partial; never reuse stale data.
- **Fix-plan preparation fails:** preserve the verified report, record worktree/branch state and
  safe resume action; do not relabel the diagnosis.
- **Fixes overlap:** consolidate or serialize before dispatch; never race on shared files/config.
- **Mutation request:** refuse provider/production mutation and state it was not executed.
- **Absent `.woostack/`:** report-only investigation may proceed in conversation, but tracked
  report/config/fix preparation requires `/woostack-init`; never scaffold implicitly.

## 7. Acceptance criteria

Each AC is a testable behavior → at least one plan task.

> **Angle pre-flight.** Security: progressive retrieval, deterministic redaction, forbidden config
> secrets, no provider/production mutation (AC4, AC7, AC10). Observability: receipts, explicit
> partial/blocked coverage, no false-clean (AC3, AC5). API: host integration outputs normalize
> through a stable evidence/receipt contract without shipping provider clients (AC2, AC3).
> Database/i18n: N/A — no data model or UI. Infra/deps: optional host integrations only; shipped
> scripts use existing Python/bash/jq-style repository conventions and add no application lockfile.
> Edge/error: ambiguity, missing auth, zero results, partial providers, overflow queue, sanitizer
> failure, and overlapping fixes are covered below.

- **AC1 — Invocation and precedence**
  - happy: `/woostack-respond to recent errors` resolves configured/default production, 24h,
    max five, and prepare-fix; explicit provider/environment/window/limit override config.
  - error: invalid flags, malformed duration, or limit outside 1–5 stops before provider access.
  - edge: `--read-only` or `--stop-after report` overrides configured prepare-fix for that run.
- **AC2 — Capability-driven provider discovery**
  - happy: explicit provider wins; otherwise config wins; otherwise repository evidence matches an
    available specialized tool/skill/official CLI/artifact and records the selection source.
  - error: detected provider with no host integration blocks with exact prerequisite.
  - edge: with no repository evidence, a sole host capability requires explicit confirmation;
    complementary providers are role-classified, and two ambiguous providers for one role ask
    rather than guess.
- **AC3 — Acquisition receipt and false-clean prevention**
  - happy: a successful provider query produces a valid post-execution receipt bound by path and
    SHA-256 digest to a regular current-run result envelope; provider, integration, target,
    environment/window, query summary, executed status, and count agree with that envelope.
  - error: empty/missing/placeholder/malformed, path-escaping, symlinked, digest-mismatched, or
    count-mismatched receipt blocks and cannot produce “no errors.”
  - edge: zero records plus a valid output-bound executed receipt produces an explicit zero-match
    coverage report; a missing expected provider role makes a multi-provider run partial.
- **AC4 — Evidence minimization and sanitization**
  - happy: metadata-first acquisition and selected detail normalize into the common contract;
    the tracked report preserves issue/trace/release/source evidence while redacting secrets/PII.
  - error: post-sanitization validation finds a sensitive pattern → no tracked report write.
  - edge: nested provider objects and home paths redact; stable issue IDs, trace IDs, commit SHAs,
    error classes, source paths, and lines remain useful.
- **AC5 — Bounded ranking and investigation**
  - happy: broad results are ranked by impact/regression evidence and up to configured max groups
    are investigated, in parallel when independent.
  - error: an investigator cannot verify a hypothesis → blocked/rejected result with evidence and
    no remediation candidate.
  - edge: duplicate groups with one root cause collapse to one report finding/fix; groups beyond
    the bound remain listed as deferred coverage.
- **AC6 — Root-cause discipline**
  - happy: each selected group follows the `woostack-debug` phases and returns trigger, root cause,
    contributing factors, evidence, rejected hypotheses, minimal remediation, failing-test
    description, and observability gap.
  - error: provider AI explanation or release correlation alone remains a candidate hypothesis.
  - edge: verified external-provider outage is classified non-code and creates no speculative fix.
- **AC7 — Response report**
  - happy: one deterministic, sanitized `.woostack/respond/<date>-<slug>.md` contains receipts,
    ranked queue, impact/timeline, group outcomes, gaps, remediation, and blocked coverage with
    `type: response` and `outcome: complete|partial|blocked` frontmatter.
  - error: abort after useful acquisition writes an explicitly partial/blocked report only when
    it passes sanitization; otherwise no tracked write.
  - edge: zero-match query still writes an explicit coverage report; report frontmatter never uses
    lifecycle `status:`; raw payloads never appear. With no `.woostack/` workspace, respond stays
    report-only in conversation, names `/woostack-init` as the tracked-artifact prerequisite, and
    creates no directories.
- **AC8 — Verified remediation preparation**
  - happy: under `prepare-fix` remediation, every verified independent bounded repository defect
    enters a separate `woostack-fix` flow and reaches its committed-plan approval gate using only
    sanitizer-validated report evidence and handoff content.
  - error: fix preparation failure records worktree/branch/resume state without losing diagnosis;
    sanitizer failure in any respond-derived handoff blocks commit/push and dispatch.
  - edge: independent fixes may prepare in parallel; overlapping files/invariants consolidate or
    serialize; no implementation starts without each explicit fix approval. Report-only controls
    prepare no fix.
- **AC9 — Observability improvement classification**
  - happy: each gap names the diagnostic delay, missing/misleading signal, exact boundary,
    smallest improvement, privacy/cardinality implications, and test strategy.
  - error: vague “add more logs” or one-incident global tuning is rejected.
  - edge: a small directly related instrumentation defect may join the fix; a material capability
    becomes an exact `/woostack-build` recommendation without starting it.
- **AC10 — Read-only production/provider boundary**
  - happy: all provider acquisition is read-only and repository implementation stays delegated.
  - error: requests to resolve/mute issues, edit alerts, deploy, roll back, restart, scale, shift
    traffic, or change flags are refused and reported unexecuted.
  - edge: no hidden config flag can expand authority; `respond` schema contains no mutation key.
- **AC11 — Config and guided init**
  - happy: init scaffolds `respond: {}`, optionally detects candidates and writes only selected
    non-secret workflow values; existing sibling config is preserved.
  - error: unknown/wrong/credential-like respond keys fail validation; `--respond` plus
    `--no-respond` is a usage error.
  - edge: `--no-clobber` preserves existing config unless response setup was explicit; auth
    unavailable yields a setup warning, not init failure.
- **AC12 — Doctor and evidence hygiene**
  - happy: doctor warns/repairs a missing top-level respond block and validates settings without
    live provider access; init gitignore excludes `respond/evidence/` while reports remain tracked.
    Before acquisition, respond proves its evidence path is ignored or selects secured OS temp.
  - error: credential-like config keys are surfaced; doctor never prompts provider login or reads
    retained evidence.
  - edge: successful terminal handback deletes evidence; aborted runs retain it ignored with a
    manual deletion instruction, and doctor warns when it is older than 24 hours.
- **AC13 — Self-improvement contract**
  - happy: dream includes tracked response reports as non-prunable decision-corpus/provenance and
    can consolidate only corroborated recurring patterns.
  - error: evidence directories/raw telemetry never enter dream, wisdom, or memory.
  - edge: one response alone does not automatically establish wisdom; response reports are never
    memory-indexed or pruned.
- **AC14 — Command surface and docs**
  - happy: every public command/adoption site, count, route, quick map, contributor pointer, and
    authored docs page includes respond; generated per-skill docs and install discovery succeed.
  - error: focused lockstep test fails on any missing site or mismatched count.
  - edge: the separate tdd/qa rename issues remain unchanged by this feature.

## 8. Testing

Deterministic focused tests, using synthetic data only:

- **Config loader:** defaults, precedence-ready normalized values, strict types/keys/durations,
  5m/30d window boundaries, 1–5 group boundaries, remediation enum, forbidden credential keys,
  sibling isolation, arbitrary provider slug syntax.
- **Init guided setup:** new/declined/accepted flows, merge preservation, existing respond keep or
  reconfigure, flag conflict, no-clobber/force semantics, no credential writes, auth warning.
- **Doctor:** missing-key warning/repair, namespace validation, forbidden-key finding, stale
  retained-evidence warning, no evidence reads, network calls, or auth prompts.
- **Receipt validator:** executed/zero-result/malformed/placeholder/missing-target/missing-role,
  path escape, symlink, missing output, digest mismatch, count mismatch, and explicit blocked-source
  fixtures.
- **Sanitizer:** nested synthetic bearer/cookie/key/password/URL/email/phone/IP/user/body/home-path
  fixtures; technical identifiers survive; the same boundary rejects unsafe fix handoff content.
- **Renderer:** complete/partial/blocked/zero-result/deferred/deduplicated/fix-linked outputs,
  stable ordering, deterministic signal/scope slug, same-day collision suffix, no lifecycle
  `status:`, and no raw payload section.
- **Provider-neutral end-to-end fixture:** fake host output with a valid receipt, six groups, two
  duplicates, one external outage, two verified repository defects, one unverified group, and
  synthetic sensitive values → one sanitized report, ≤5 investigations, two remediation
  candidates, explicit deferred coverage, and no leaked values.
- **Safety contract:** only verified results become fix candidates; skill contract contains no
  provider/production mutation path.
- **Workspace/evidence preflight:** current ignored evidence path, legacy workspace fallback to
  mode-`0700` OS temp, and absent `.woostack/` report-only flow with no filesystem creation.
- **Dream/wisdom:** respond corpus inclusion, evidence exclusion, non-prunability, provenance
  acceptance, no memory indexing, no one-report auto-wisdom.
- **Command lockstep:** all registration/count/docs sites agree.
- **Verification:** focused shell/Python tests; install collection in a temporary consumer; run
  `pnpm -C site build`.

No test requires a live provider account. Manual PR verification uses an available authenticated
host integration, if present, only for a read-only bounded smoke run; absence is reported rather
than weakening deterministic test evidence.

## 9. Open questions

Settled during design approval:

1. **Provider scope:** host-provided integrations, not fixed live adapters. Exported artifacts are
   the provider-neutral fallback.
2. **Remediation authority:** verified defects automatically prepare `woostack-fix` plan PRs but
   stop at each existing execution approval gate.
3. **Init behavior:** optional guided setup with `--respond` / `--no-respond`; config stores only
   non-secret workflow values.
4. **Retention:** tracked sanitized reports; raw evidence gitignored and transient.
5. **Broad-run bound:** investigate up to five high-impact independent groups and prepare every
   verified independent fix, deduplicating or serializing overlap.
6. **Production/provider authority:** strictly read-only in the first release; no hidden mutation
   configuration.
7. **Report lifecycle field:** `outcome`, not the feature-state `status:` field.
8. **Dream integration:** response reports are non-prunable decision corpus; one report alone does
   not establish wisdom.
