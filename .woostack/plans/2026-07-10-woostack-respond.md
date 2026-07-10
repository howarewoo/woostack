---
type: plan
source: .woostack/specs/2026-07-10-woostack-respond.md
status: ready
branch: feature/woostack-respond
---

**Source:** [[specs/2026-07-10-woostack-respond]]

# woostack-respond — Production Error Response — Implementation Plan

**Goal:** Ship `woostack-respond`, a capability-driven, read-only production-error response
orchestrator that proves provider query execution, minimizes and sanitizes telemetry, investigates
at most five high-impact independent groups, writes a tracked response report, prepares only
verified defects through gated `woostack-fix` flows, and turns recurring incident evidence into
non-prunable dream input.

**Architecture:** Three linearly stacked increments preserve the approved delivery boundaries.
Increment 1 ships the complete provider-neutral response engine and deterministic evidence
pipeline without provider clients. Increment 2 adds optional init configuration and doctor health
checks. Increment 3 registers the public command and updates every knowledge, documentation, and
installation consumer in lockstep. The runtime remains orchestration-first: host-provided
integrations perform provider reads; small local shell/Python tools enforce configuration,
receipt, sanitization, storage, and rendering invariants.

**Tech Stack:** Markdown skill contracts, Bash 3-compatible test harnesses, Python 3 standard
library, JSON fixtures, existing woostack init/doctor scripts, Fumadocs/Next.js documentation,
Graphite stacked PRs.

**Wisdom constraints:** [[autonomy-needs-structural-proof]] requires executable receipts and
focused verification rather than prose-only success. [[lockstep-edit-sites]] requires the public
surface, config consumers, and knowledge readers to move together in their owning increments.
[[review-ci-local-asymmetry]] requires deterministic local tests that do not depend on a live
provider or CI-only host capability.

---

## Increment 1: Response core and deterministic evidence pipeline

> One independently shippable PR containing the complete provider-neutral skill, contracts,
> standard-library tools, synthetic fixtures, and focused tests. It does not ship a Sentry,
> Datadog, Axiom, or other provider API client. The skill carries explicit deferral markers for
> init/doctor integration (Increment 2) and public registration/knowledge docs (Increment 3).
> This slice may exceed the 500-LOC soft target because the receipt, sanitizer, renderer, and
> orchestrator form one safety boundary: shipping any subset would expose a callable skill with
> unproved false-clean or privacy behavior.

### Task 1: Define provider discovery and evidence contracts

**Files:**
- Create: `skills/woostack-respond/references/provider-discovery.md`
- Create: `skills/woostack-respond/references/evidence-contract.md`
- Create: `skills/woostack-respond/references/report-template.md`
- Create: `skills/woostack-respond/scripts/tests/assert.sh`
- Create: `skills/woostack-respond/scripts/tests/test-contracts.sh`

- [ ] **Step 1: Write the failing structural contract test**

  Create `test-contracts.sh` using the existing `woostack-init/scripts/tests/assert.sh` pattern.
  It must assert exact invariant markers rather than loose word presence:

  ```bash
  assert_contains "$providers" 'explicit request → config → repository evidence → host capability' \
    'provider precedence is singular'
  assert_contains "$providers" 'never auto-selects an uncorroborated host capability' \
    'installed capability alone is not queried'
  assert_contains "$evidence" 'status accepts exactly `executed`' \
    'receipt status is closed'
  assert_contains "$evidence" 'regular, non-symlink file inside the current run directory' \
    'receipt path is contained'
  assert_contains "$evidence" 'SHA-256' 'receipt binds output bytes'
  assert_contains "$evidence" 'records_returned' 'receipt binds record count'
  assert_contains "$template" 'outcome: {{OUTCOME}}' 'report uses outcome field'
  assert_not_contains "$template" 'status: {{' 'report does not borrow lifecycle status'
  assert_contains "$template" '## Query Coverage' 'report carries receipts'
  assert_contains "$template" '## Uncovered and Blocked Evidence' 'partial coverage is explicit'
  ```

- [ ] **Step 2: Run the test and confirm red**

  Run: `bash skills/woostack-respond/scripts/tests/test-contracts.sh`

  Expected: non-zero; the three reference files do not exist.

- [ ] **Step 3: Author `provider-discovery.md`**

  Define one ordered resolver:

  ```text
  explicit request → non-auto respond.provider → repository evidence → matching host capability
  ```

  Enumerate repository evidence (dependency manifests, SDK imports/initialization, provider config
  filenames, OpenTelemetry exporters, deployment configuration, environment-variable names only),
  host capability precedence (specialized MCP/tool → installed provider skill → authenticated
  official CLI → exported artifact), complementary role selection, same-target/window proof,
  ambiguous-role stop-and-ask, sole uncorroborated capability confirmation, auth/target blocking,
  and the prohibition on provider web-dashboard automation. Include examples for Sentry, Datadog,
  Axiom, Honeycomb, OpenTelemetry, and deployment metadata without treating the list as exhaustive.

- [ ] **Step 4: Author `evidence-contract.md`**

  Define the provider-neutral JSON envelopes used by all scripts:

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

  Define the receipt fields, output containment/digest/count checks, metadata and selected-detail
  group records, investigation results (`verified|rejected|blocked`), normalized report input,
  source-role coverage, stable technical identifiers, excluded fields, and these hard equations:

  ```text
  zero records + valid output-bound executed receipt = clean query
  zero records + no valid output-bound receipt       = blocked
  no verified root cause                             = no fix candidate
  ```

- [ ] **Step 5: Author `report-template.md`**

  Provide `type: response`, `outcome: complete|partial|blocked`, provider/environment/window/date,
  then fixed sections for Response & Scope, Query Coverage, Ranked Error Queue, Impact Summary,
  Incident Timeline, Investigated Groups, Verified Root Causes, External or Non-Code Incidents,
  Observability Gaps, Remediation, and Uncovered and Blocked Evidence. Include no raw-payload
  section and no lifecycle `status:` key.

- [ ] **Step 6: Run the contract test and confirm green**

  Run: `bash skills/woostack-respond/scripts/tests/test-contracts.sh`

  Expected: `PASS: response contracts`

- [ ] **Step 7: Commit the contract task**

  Run: `gt create -m "feat: define response evidence contracts"` for the increment's first commit.

### Task 2: Implement strict response configuration loading

**Files:**
- Create: `skills/woostack-respond/scripts/load-respond-config.sh`
- Create: `skills/woostack-respond/scripts/tests/test-load-respond-config.sh`

- [ ] **Step 1: Write failing config fixtures**

  The shell test creates temporary `.woostack/config.json` fixtures and invokes:

  ```bash
  bash skills/woostack-respond/scripts/load-respond-config.sh <config-path>
  ```

  Assert normalized compact JSON for absent/empty respond blocks:

  ```json
  {"provider":"auto","environment":"production","window":"24h","max_groups":5,"remediation":"prepare-fix"}
  ```

  Cover explicit overrides; arbitrary lowercase provider slugs; 5m, 24h, and 30d; group bounds 1
  and 5; sibling preservation; unknown key; wrong object/key types; empty provider/environment;
  0m/4m/31d; groups 0/6/non-integer/bool; invalid remediation; malformed JSON; and credential-like
  keys including `token`, `api_key`, `password`, `cookie`, `authorization`, and
  `mutation_authority`. Invalid fixtures must exit non-zero and name the exact offending key.

- [ ] **Step 2: Run the config test and confirm red**

  Run: `bash skills/woostack-respond/scripts/tests/test-load-respond-config.sh`

  Expected: non-zero; `load-respond-config.sh` is missing.

- [ ] **Step 3: Implement the loader with Bash plus Python standard library**

  The public shell interface accepts zero or one config path (default `.woostack/config.json`),
  runs an inline `python3` validator, treats a missing file/respond block as `{}`, rejects booleans
  as integers, parses `^([1-9][0-9]*)(m|h|d)$`, converts the duration to minutes for the inclusive
  5m–30d check, rejects unknown/credential-like keys before value validation, and emits only the
  normalized JSON object on stdout. Errors use:

  ```text
  ::error file=<path>::respond.<key>: <reason>
  ```

  No provider authentication or network request occurs here.

- [ ] **Step 4: Run config tests and syntax checks**

  Run: `bash skills/woostack-respond/scripts/tests/test-load-respond-config.sh`

  Expected: `PASS: respond config loader`

  Run: `bash -n skills/woostack-respond/scripts/load-respond-config.sh`

  Expected: exit 0.

- [ ] **Step 5: Commit the config task**

  Run: `gt modify -c -m "feat: validate response configuration"`.

### Task 3: Bind receipts to real current-run output

**Files:**
- Create: `skills/woostack-respond/scripts/validate-receipt.py`
- Create: `skills/woostack-respond/scripts/tests/test-validate-receipt.sh`

- [ ] **Step 1: Write failing receipt fixtures**

  Invoke:

  ```bash
  python3 skills/woostack-respond/scripts/validate-receipt.py \
    --receipt "$run/receipt.json" --run-dir "$run" \
    --expected-project acme/api --expected-environment production \
    --expected-window-start 2026-07-09T18:00:00Z \
    --expected-window-end 2026-07-10T18:00:00Z
  ```

  A valid fixture contains the evidence-contract result envelope, its computed SHA-256, exact
  record count, executed status, non-empty provider/role/integration/project/environment/query,
  and ordered UTC window. Assert success for non-zero and zero records. Assert failure for empty
  placeholder receipt, missing fields, non-executed status, negative/non-integer count, malformed
  timestamp/window, missing output, output outside run dir, direct symlink output, a regular file
  reached through a symlinked intermediate directory, digest mismatch, count mismatch,
  provider/role/target/window mismatch between receipt and envelope, an internally consistent
  stale receipt whose scope differs from the expected current request, and a blocked role
  represented as an executed receipt.

- [ ] **Step 2: Run receipt tests and confirm red**

  Run: `bash skills/woostack-respond/scripts/tests/test-validate-receipt.sh`

  Expected: non-zero; validator is missing.

- [ ] **Step 3: Implement the standard-library validator**

  Use `argparse`, `json`, `hashlib`, `pathlib`, and `datetime`. Resolve the run directory and every
  output-path component; reject a symlink anywhere below the run directory, require the fully
  resolved output to remain contained under the fully resolved run directory, and require the
  final target to be a regular file. Stream SHA-256; validate the envelope's top-level schema and
  `records` array; compare count and receipt/envelope scope; compare both against the required
  current-request project, environment, and UTC window arguments; and emit canonical receipt JSON
  on success. Every failure exits non-zero with one actionable stderr line and no normalized
  receipt on stdout.

- [ ] **Step 4: Run receipt tests and Python compilation**

  Run: `bash skills/woostack-respond/scripts/tests/test-validate-receipt.sh`

  Expected: `PASS: acquisition receipt validator`

  Run: `python3 -m py_compile skills/woostack-respond/scripts/validate-receipt.py`

  Expected: exit 0.

- [ ] **Step 5: Commit the receipt task**

  Run: `gt modify -c -m "feat: bind response receipts to evidence"`.

### Task 4: Implement deterministic telemetry sanitization

**Files:**
- Create: `skills/woostack-respond/scripts/sanitize-telemetry.py`
- Create: `skills/woostack-respond/scripts/tests/test-sanitize-telemetry.sh`
- Create: `skills/woostack-respond/scripts/tests/fixtures/sensitive-input.json`
- Create: `skills/woostack-respond/scripts/tests/fixtures/sanitized-expected.json`

- [ ] **Step 1: Write the failing sanitizer test and synthetic fixture**

  Invoke:

  ```bash
  python3 skills/woostack-respond/scripts/sanitize-telemetry.py \
    --input "$fixture" --output "$actual"
  ```

  The fixture contains synthetic bearer/basic auth, cookies, session IDs, API keys, passwords,
  database URLs, emails, phone numbers, IPv4/IPv6, user IDs/provider user objects, request and
  response bodies, nested provider context, and macOS/Linux/Windows home paths. It also contains
  issue `API-142`, trace ID, commit SHA, release ID, error class, source path/line, and service name.
  Assert byte-for-byte deterministic expected output, preserved technical identifiers, recursive
  stable placeholders (`[REDACTED_TOKEN]`, `[REDACTED_EMAIL]`, `[REDACTED_IP]`,
  `[REDACTED_USER]`, `[REDACTED_BODY]`, `[REDACTED_HOME]`), and no sensitive fixture value.
  Add residual-validation fixtures for credential-like keys and secret-shaped values the first
  pass intentionally cannot classify; they must fail without replacing an existing output.

- [ ] **Step 2: Run sanitizer tests and confirm red**

  Run: `bash skills/woostack-respond/scripts/tests/test-sanitize-telemetry.sh`

  Expected: non-zero; sanitizer is missing.

- [ ] **Step 3: Implement recursive redaction and atomic validation**

  Use Python standard-library JSON traversal. Redact by normalized key classes before value
  patterns; redact body/user objects wholesale; replace home prefixes without erasing source
  paths; preserve scalar types where possible; sort JSON keys for deterministic output. Serialize
  to a sibling temporary file, run the second-pass forbidden-key/value scan over the serialized
  structure, then `os.replace` only on success. On failure, remove the temporary file and leave the
  destination unchanged.

- [ ] **Step 4: Prove report and fix-handoff boundaries**

  Add a second invocation mode:

  ```bash
  python3 sanitize-telemetry.py --check <sanitized-json-or-rendered-markdown>
  ```

  It performs validation only, auto-detects JSON versus text, and applies one shared forbidden
  key/value pattern engine rather than sending Markdown through the JSON parser. It exits non-zero
  on any tracked-write candidate. The test runs it against synthetic response-report JSON, fully
  rendered report Markdown, and synthetic `woostack-fix` handoff packets, proving tracked and
  remote paths share the same boundary.

- [ ] **Step 5: Run sanitizer tests and Python compilation**

  Run: `bash skills/woostack-respond/scripts/tests/test-sanitize-telemetry.sh`

  Expected: `PASS: telemetry sanitizer`

  Run: `python3 -m py_compile skills/woostack-respond/scripts/sanitize-telemetry.py`

  Expected: exit 0.

- [ ] **Step 6: Commit the sanitizer task**

  Run: `gt modify -c -m "feat: sanitize response telemetry"`.

### Task 5: Render deterministic response reports

**Files:**
- Create: `skills/woostack-respond/scripts/render-report.py`
- Create: `skills/woostack-respond/scripts/tests/test-render-report.sh`
- Create: `skills/woostack-respond/scripts/tests/fixtures/report-complete.json`
- Create: `skills/woostack-respond/scripts/tests/fixtures/report-partial.json`
- Create: `skills/woostack-respond/scripts/tests/fixtures/report-blocked.json`

- [ ] **Step 1: Write failing renderer fixtures**

  Invoke:

  ```bash
  python3 skills/woostack-respond/scripts/render-report.py \
    --input "$fixture" --output-dir "$reports" --date 2026-07-10
  ```

  Cover complete, partial, blocked, valid zero-match, six-ranked/five-investigated with deferred
  queue, duplicate manifestations collapsed to one root cause, verified/rejected/blocked
  hypotheses, external incident, observability recommendation, and two fix-plan links. Assert the
  exact output path and stable section order; `type: response`; `outcome`, never lifecycle
  `status`; no raw-payload heading; no unsanitized field; normalized signal/scope slug; and
  collision suffixes `-2`, `-3` without overwrite. Add an unsanitized fixture containing a
  synthetic bearer token; rendering must exit non-zero and create no report.

- [ ] **Step 2: Run renderer tests and confirm red**

  Run: `bash skills/woostack-respond/scripts/tests/test-render-report.sh`

  Expected: non-zero; renderer is missing.

- [ ] **Step 3: Implement strict rendering**

  Validate `outcome` against `complete|partial|blocked`, require query coverage appropriate to the
  outcome, refuse `complete` when any expected provider role is blocked, sort provider receipts
  and groups deterministically, slugify normalized signal plus explicit scope to lowercase ASCII
  kebab case, allocate the first unused date/slug suffix, and render through the reference
  template. Before the atomic tracked write, invoke the sanitizer's validation-only scan against
  the fully rendered temporary Markdown; any forbidden key/value pattern removes the temporary
  file and leaves the destination absent or unchanged. Reject unknown top-level fields that could
  bypass named sections. Print only the resulting report path on stdout.

- [ ] **Step 4: Run renderer tests and Python compilation**

  Run: `bash skills/woostack-respond/scripts/tests/test-render-report.sh`

  Expected: `PASS: response report renderer`

  Run: `python3 -m py_compile skills/woostack-respond/scripts/render-report.py`

  Expected: exit 0.

- [ ] **Step 5: Commit the renderer task**

  Run: `gt modify -c -m "feat: render response reports"`.

### Task 6: Author the orchestration skill and provider-neutral end-to-end contract

**Files:**
- Create: `skills/woostack-respond/SKILL.md`
- Create: `skills/woostack-respond/scripts/tests/test-respond-e2e.sh`
- Create: `skills/woostack-respond/scripts/tests/fixtures/e2e-provider-output.json`
- Create: `skills/woostack-respond/scripts/tests/run-tests.sh`

- [ ] **Step 1: Write the failing end-to-end contract test**

  The fixture represents a fake host integration with one successful receipt and six candidate
  groups: two duplicate manifestations, one external provider outage, two verified independent
  repository defects, and one unverified group, plus synthetic sensitive values. The test runs
  receipt validation → sanitization → rendering and asserts:

  ```text
  6 groups considered.
  5 or fewer deeply investigated.
  deferred coverage is explicit.
  2 verified remediation candidates.
  1 external/non-code classification.
  1 blocked/unverified classification.
  no synthetic sensitive value survives.
  only verified candidates enter the fix-handoff array.
  ```

  Run the same fixture with each of `remediation: report-only`, `--read-only`, and
  `--stop-after report`; each variant must produce zero fix-handoff entries and no
  `woostack-fix` dispatch instruction.

  Add structural assertions that `SKILL.md` requires an output-bound receipt before a clean
  result, calls the existing `woostack-debug` doctrine rather than redefining it, blocks provider
  and production mutation requests, sanitizes both report and fix handoff, and stops fix flows at
  their existing approval gates.

- [ ] **Step 2: Run the aggregate tests and confirm red**

  Run: `bash skills/woostack-respond/scripts/tests/run-tests.sh`

  Expected: non-zero; `SKILL.md` and the e2e test contract are incomplete.

- [ ] **Step 3: Author `SKILL.md` command and scope resolution**

  Frontmatter:

  ```yaml
  ---
  name: woostack-respond
  description: Use to investigate bounded production errors from repository instrumentation and available authenticated observability integrations, prove query execution, sanitize and report evidence, and prepare verified repository defects through woostack-fix approval gates. Read-only toward providers and production; never mutates, deploys, merges, or guesses a clean result.
  ---
  ```

  Define `/woostack-respond <signal> [scope]`, `--since`, `--environment`, `--service`,
  `--provider`, `--limit`, `--read-only`, and sole `--stop-after report`; explicit invocation →
  config → detection → built-ins; exact scope/window preflight announcement; candidate count after
  metadata acquisition; and the 5m–30d/1–5 bounds.

- [ ] **Step 4: Author provider/evidence phases and hard gates**

  Link the provider and evidence references. Require provider role/target/window resolution,
  authentication/read preflight, ignored evidence-path proof via the repository ignore engine,
  mode-`0700` OS-temp fallback for legacy workspaces, progressive metadata/detail reads, one real
  output-bound receipt per role, explicit partial outcomes, and no browser-dashboard fallback.
  Prominently state:

  ```text
  NO VALID OUTPUT-BOUND RECEIPT → NO CLEAN RESULT
  NO VERIFIED ROOT CAUSE        → NO FIX PLAN
  NO PROVIDER OR PRODUCTION MUTATION
  NO RAW TELEMETRY IN TRACKED OR REMOTE WRITES
  ```

- [ ] **Step 5: Author ranking, investigation, report, and remediation phases**

  Rank by production/data-integrity impact, affected users/requests, severity,
  frequency/acceleration, regression/release evidence, recurrence, and local-code confidence.
  Dispatch at most five independent read-only investigators with only normalized selected-group
  evidence and the `woostack-debug` four-phase contract; reconcile duplicate causes; classify
  external/non-code outcomes; identify concrete observability gaps; sanitize/validate; render one
  response report; and under prepare-fix send only sanitized verified defect packets to separate
  `woostack-fix` flows. Report-only controls do not dispatch. Overlap consolidates/serializes.
  Material observability gaps become exact `/woostack-build` recommendations only.

- [ ] **Step 6: Author failure, cleanup, and terminal handback behavior**

  Cover absent workspace (conversation-only; no directories), no provider, unavailable
  integration, missing auth, target mismatch, partial provider failure, zero groups, >5 groups,
  unverified cause, sensitive-context expansion gate, sanitizer failure, provider death, fix
  preparation failure, overlap, and mutation requests. Delete evidence only after terminal
  report/fix-preparation handback; retain failures with path and manual deletion instruction.
  Terminal output names coverage, outcome, report path, fix PRs/gates, observability
  recommendations, and blocked/deferred groups.

- [ ] **Step 7: Add deferral markers**

  Place two literal markers after the overview:

  ```markdown
  <!-- woostack-defer(increment 2): init/doctor respond namespace and evidence hygiene land in increment 2 -->
  <!-- woostack-defer(increment 3): public routing, docs, and dream corpus integration land in increment 3 -->
  ```

  Neither marker defers a safety property: built-in defaults, evidence-path proof, sanitizer,
  receipts, and read-only authority are already complete in this increment.

- [ ] **Step 8: Run all focused core tests**

  `run-tests.sh` follows the repository's existing `for t in test-*.sh` discovery convention, so
  tests added by later increments run automatically without editing the runner.

  Run: `bash skills/woostack-respond/scripts/tests/run-tests.sh`

  Expected: each discovered test exits 0 and the runner exits 0.

  Run: `bash -n skills/woostack-respond/scripts/load-respond-config.sh`

  Expected: exit 0.

  Run: `python3 -m py_compile skills/woostack-respond/scripts/*.py`

  Expected: exit 0.

- [ ] **Step 9: Commit the orchestration task**

  Run: `gt modify -c -m "feat: add production error response skill"`.

---

## Increment 2: Init and doctor integration

> One independently shippable PR stacked on Increment 1. It adds the non-secret respond namespace,
> guided setup contract, tracked report directory, ignored evidence directory, and metadata-only
> doctor findings. It removes the Increment 2 deferral marker from the response skill.

### Task 1: Extend canonical workspace templates

**Files:**
- Modify: `skills/woostack-init/templates/config.json`
- Modify: `skills/woostack-init/templates/gitignore`
- Create: `skills/woostack-init/templates/respond/.gitkeep`
- Modify: `skills/woostack-init/scripts/tests/test-gitignore-template.sh`
- Create: `skills/woostack-init/scripts/tests/test-respond-template.sh`

- [ ] **Step 1: Write failing template assertions**

  Assert the canonical JSON parses, contains top-level `"respond": {}`, preserves `models`,
  `review`, and `status`, and contains no credential-like respond keys. Assert the exact ignore
  line `respond/evidence/`, assert `respond/` itself is not ignored, and assert the `.gitkeep`
  exists. Extend the existing gitignore test with the response evidence line.

- [ ] **Step 2: Run template tests and confirm red**

  Run: `bash skills/woostack-init/scripts/tests/test-respond-template.sh`

  Expected: non-zero; respond template assets are absent.

  Run: `bash skills/woostack-init/scripts/tests/test-gitignore-template.sh`

  Expected: non-zero; response evidence ignore assertion fails.

- [ ] **Step 3: Update templates**

  Add `"respond": {}` as a top-level sibling without reformatting existing namespaces; append
  `respond/evidence/` under the transient evidence group; add the empty `.gitkeep` template. Do not
  add provider credentials, fixed provider adapters, raw evidence content, or a top-level
  application lockfile.

- [ ] **Step 4: Run template tests and confirm green**

  Run both tests above.

  Expected: `PASS: respond workspace template` and the existing gitignore test final PASS line.

- [ ] **Step 5: Commit template integration**

  Run: `gt create -m "feat: scaffold response workspace settings"`.

### Task 2: Add optional guided response setup to init

**Files:**
- Modify: `skills/woostack-init/SKILL.md`
- Modify: `skills/woostack-init/references/memory.md`
- Create: `skills/woostack-init/scripts/tests/test-respond-setup-contract.sh`
- Modify: `skills/woostack-respond/SKILL.md`

- [ ] **Step 1: Write the failing init contract test**

  Assert the skill documents `--respond`, `--no-respond`, mutual exclusion, default-no prompt,
  repository-instrumentation and host-capability discovery, provider/environment/window/max groups/
  remediation questions, no credential collection, auth warning without init failure, sibling-key
  preservation, keep/reconfigure behavior, `--no-clobber` explicit-response exception, force
  semantics, and exact scaffold mapping from `templates/respond/.gitkeep` to
  `.woostack/respond/.gitkeep`. Assert the memory layout includes `respond/` reports and the ignored
  `respond/evidence/` child.

- [ ] **Step 2: Run the init contract test and confirm red**

  Run: `bash skills/woostack-init/scripts/tests/test-respond-setup-contract.sh`

  Expected: non-zero; init has no response setup contract.

- [ ] **Step 3: Amend init behavior**

  Add flags to Commands and argument conflict handling. After creating/preserving config, prompt
  `Set up production error response? [y/N]`; `--respond` skips that opt-in and `--no-respond`
  suppresses setup. Discovery is non-mutating and reads dependency/config filenames,
  initialization imports, environment-variable names, and available host integration names. It
  presents candidates and authentication prerequisites, then writes only accepted non-secret
  workflow values by semantic JSON merge. Existing siblings and unknown top-level namespaces
  survive; existing respond values can be kept; reconfigure changes only respond; no-clobber
  requires explicit `--respond`; both flags hard-fail.

- [ ] **Step 4: Update workspace layout documentation and remove the Increment 2 marker**

  Add `respond/.gitkeep`, tracked reports, and ignored evidence to `memory.md`'s init layout. Remove
  only `woostack-defer(increment 2)` from `woostack-respond/SKILL.md`; keep Increment 3's marker.

- [ ] **Step 5: Run init-focused tests**

  Run: `bash skills/woostack-init/scripts/tests/test-respond-setup-contract.sh`

  Expected: `PASS: init response setup contract`.

  Run: `bash skills/woostack-init/scripts/tests/run-tests.sh`

  Expected: exit 0 with all existing init tests passing.

- [ ] **Step 6: Commit guided setup**

  Run: `gt modify -c -m "feat: guide response setup during init"`.

### Task 3: Validate response health through doctor

**Files:**
- Create: `skills/woostack-doctor/scripts/checks/respond.sh`
- Create: `skills/woostack-doctor/scripts/tests/test-respond.sh`
- Modify: `skills/woostack-doctor/references/checks.md`

- [ ] **Step 1: Write failing doctor fixtures**

  Create temporary workspace fixtures and call `checks/respond.sh <root>`. Assert no finding for
  absent valid optional values; `respond-config` warnings for non-object namespace, unknown keys,
  invalid types, 4m/31d window, groups 0/6, and invalid remediation; `respond-credentials` for
  credential-like keys; and `respond-stale-evidence` for run-directory names older than 24 hours.
  Instrument fixture files so opening them would fail the test; the check may enumerate directory
  names/stat metadata only. Assert a fresh directory and OS-temp paths outside the workspace are
  ignored. Assert the check performs no network command and emits standard doctor TSV findings.

  Invoke the existing template-driven `config-keys.sh`/doctor repair path against a config missing
  only `respond`: assert `missing required config key: respond`, then run doctor repair and assert
  it restores `respond: {}` from the canonical template without changing sibling namespaces.

- [ ] **Step 2: Run the doctor test and confirm red**

  Run: `bash skills/woostack-doctor/scripts/tests/test-respond.sh`

  Expected: non-zero; respond check is missing.

- [ ] **Step 3: Implement the metadata-only check**

  Follow existing `checks/*.sh` output shape. Reuse the response loader for namespace validation
  without provider preflight, map loader errors to doctor findings, detect credential-like keys
  before values, and inspect only immediate child directory names/mtime under
  `.woostack/respond/evidence/`. Use a test-controlled current time and a 24-hour threshold. Emit a
  manual deletion recommendation; never open evidence files, print directory contents, prompt
  login, or call a provider.

- [ ] **Step 4: Document findings and prove automatic orchestration**

  Add `respond-config`, `respond-credentials`, and `respond-stale-evidence` to `checks.md` with
  severity, repairability, and manual cleanup. The existing `doctor.sh` wildcard
  `checks/*.sh` loop requires no dispatch edit; add an assertion in `test-respond.sh` that invoking
  `doctor.sh` surfaces the new check.

- [ ] **Step 5: Run doctor tests**

  Run: `bash skills/woostack-doctor/scripts/tests/test-respond.sh`

  Expected: `PASS: doctor response checks`.

  Run: `bash skills/woostack-doctor/scripts/tests/run-tests.sh`

  Expected: exit 0 with all existing doctor tests passing.

- [ ] **Step 6: Commit doctor integration**

  Run: `gt modify -c -m "feat: diagnose response workspace health"`.

---

## Increment 3: Knowledge and public-surface integration

> One independently shippable PR stacked on Increment 2. It moves all public command sites and
> all response-report knowledge readers together, adds structural lockstep tests, updates authored
> site pages, verifies generated pages, and removes the final deferral marker. Generated
> `site/content/docs/skills/*.mdx` files remain gitignored and are never hand-edited.

### Task 1: Add tracked response reports to the dream/wisdom contract

**Files:**
- Modify: `skills/woostack-dream/SKILL.md`
- Modify: `skills/woostack-init/references/wisdom.md`
- Modify: `site/content/docs/concepts/memory.mdx`
- Create: `skills/woostack-respond/scripts/tests/test-knowledge-contract.sh`

- [ ] **Step 1: Write the failing knowledge-contract test**

  Assert dream's description, overview, gather phase, consolidate input, source-ledger prose,
  prune constraints, degradation behavior, and hard constraints all include tracked
  `.woostack/respond/*.md` as decision corpus. Assert `respond/evidence/` is excluded; response
  reports are never pruned; one report alone cannot create wisdom; response paths are accepted in
  wisdom `source:`; and build-index still scans only `.woostack/memory/`. Assert the authored
  memory page distinguishes response decision evidence from scoped memory and raw telemetry.

- [ ] **Step 2: Run the knowledge test and confirm red**

  Run: `bash skills/woostack-respond/scripts/tests/test-knowledge-contract.sh`

  Expected: non-zero; dream and wisdom do not know response reports.

- [ ] **Step 3: Update dream without creating a second corpus convention**

  Extend the existing tracked decision corpus from `specs/plans/fixes` to
  `specs/plans/fixes/respond`; include response paths in incremental git-log enumeration and
  staleness/provenance resolution; include response evidence as corroboration for consolidate;
  explicitly exclude `respond/evidence/`; and state response/spec/plan/fix artifacts are
  provenance-only, never prune candidates. Preserve the existing gate, watermark, and memory-note
  writer ownership.

- [ ] **Step 4: Update the canonical wisdom ledger and authored memory page**

  Add `.woostack/respond/<file>.md` to valid ledger path forms, layout, decision-corpus prose,
  non-prunable list, and lifecycle diagram. State that a single incident never establishes
  generalized wisdom and that response reports never enter `MEMORY.md`. Mirror the reader-facing
  distinction in `site/content/docs/concepts/memory.mdx` without duplicating the schema.

- [ ] **Step 5: Run knowledge and recall tests**

  Run: `bash skills/woostack-respond/scripts/tests/test-knowledge-contract.sh`

  Expected: `PASS: response knowledge contract`.

  Run: `bash skills/woostack-init/scripts/tests/test-build-index.sh`

  Expected: exit 0; response/wisdom siblings remain outside scoped memory.

- [ ] **Step 6: Commit knowledge integration**

  Run: `gt create -m "feat: include response reports in dream corpus"`.

### Task 2: Register the twenty-first public command in lockstep

**Files:**
- Modify: `AGENTS.md`
- Modify: `README.md`
- Modify: `CONTRIBUTING.md`
- Modify: `skills/using-woostack/SKILL.md`
- Modify: `skills/woostack-bootstrap/references/development.md`
- Modify: `site/content/docs/concepts/utilities.mdx`
- Modify: `skills/woostack-respond/SKILL.md`
- Create: `skills/woostack-respond/scripts/tests/test-command-surface.sh`

- [ ] **Step 1: Write the failing command-surface lockstep test**

  Assert:

  ```text
  AGENTS.md says twenty-one registered public/adoption skills.
  AGENTS.md list, Mode B trigger list, and Quick file map each name woostack-respond.
  README installation/public workflow section links woostack-respond.
  CONTRIBUTING intro and pointer table name woostack-respond.
  using-woostack routing has exactly one /woostack-respond row.
  bootstrap development summary names production-error response.
  authored utilities page links /docs/skills/woostack-respond.
  exactly 24 physical skills/*/SKILL.md files exist: 21 registered public/adoption skills,
  2 internal build sub-skills, and the pre-existing unregistered woostack-ask skill.
  no woostack-defer(increment 3) marker remains.
  ```

  Count lines and normalized lists, not substring occurrences, following
  `[[grep-c-counts-lines-not-occurrences]]`.

- [ ] **Step 2: Run the lockstep test and confirm red**

  Run: `bash skills/woostack-respond/scripts/tests/test-command-surface.sh`

  Expected: non-zero; the new skill is not registered.

- [ ] **Step 3: Update root and routing surfaces**

  In `AGENTS.md`, move the registered public/adoption count twenty→twenty-one, reconcile the stale
  physical SKILL-file count twenty-two→twenty-four, list `woostack-respond`, and explicitly note
  the pre-existing unregistered `woostack-ask` file as outside this feature's command surface
  rather than misclassifying or silently registering it. Update the Mode B command, Quick file
  map, and no-move constraint together. Add the response workflow to README's install/examples
  and investigation/operations section. Add it to both CONTRIBUTING sites. Add exactly one routing
  row in `using-woostack`. Add the production-error response row to bootstrap development
  guidance. Do not rename or alias any existing command.

- [ ] **Step 4: Update authored utilities and remove the final marker**

  Add `woostack-respond` to the Investigate & present table with tracked report and gated-fix
  behavior. Remove only `woostack-defer(increment 3)` from the response skill. Do not edit the
  generated per-skill reference page.

- [ ] **Step 5: Run command-surface checks**

  Run: `bash skills/woostack-respond/scripts/tests/test-command-surface.sh`

  Expected: `PASS: response command surface`.

  Run: `bash skills/woostack-init/scripts/tests/test-omp-lockstep.sh`

  Expected: exit 0; adding a skill does not desynchronize omp host definitions.

- [ ] **Step 6: Commit command registration**

  Run: `gt modify -c -m "feat: register woostack-respond command"`.

### Task 3: Document configuration and guided setup

**Files:**
- Modify: `site/content/docs/configuration.mdx`
- Modify: `site/content/docs/getting-started.mdx`
- Create: `skills/woostack-respond/scripts/tests/test-authored-docs.sh`

- [ ] **Step 1: Write failing authored-doc assertions**

  Assert configuration says the init template ships four top-level keys and doctor checks all
  four; the top-level settings count includes respond; complete JSON has `"respond": {}`; a
  Response section lists provider/environment/window/max_groups/remediation with defaults and
  bounds; and credentials never belong in config. Assert getting-started documents optional
  default-no setup, `--respond`, `--no-respond`, provider-native auth, tracked reports, and ignored
  transient evidence.

- [ ] **Step 2: Run docs assertions and confirm red**

  Run: `bash skills/woostack-respond/scripts/tests/test-authored-docs.sh`

  Expected: non-zero; authored pages still describe the pre-response surface.

- [ ] **Step 3: Update authored pages**

  Add the respond namespace to the existing configuration table and complete example; document
  strict keys, 5m–30d, 1–5, provider slug behavior, prepare-fix/report-only, invocation precedence,
  no credentials, and host-integration prerequisite. Add a compact guided-init section to
  getting-started. Cross-link the generated response skill reference; do not duplicate its full
  workflow.

- [ ] **Step 4: Run authored-doc assertions**

  Run: `bash skills/woostack-respond/scripts/tests/test-authored-docs.sh`

  Expected: `PASS: response authored docs`.

- [ ] **Step 5: Commit authored documentation**

  Run: `gt modify -c -m "docs: document response configuration"`.

### Task 4: Verify installation and generated documentation

**Files:**
- Modify only if a failing generator contract proves necessary:
  `site/scripts/gen-skills.test.mjs`

- [ ] **Step 1: Run the site generator tests**

  Run: `pnpm -C site test`

  Expected: all Node tests pass and the generator discovers `woostack-respond/SKILL.md` without a
  hard-coded allowlist change. If discovery fails, first add a failing assertion to
  `gen-skills.test.mjs`, then make the smallest generator fix; never commit generated
  `site/content/docs/skills/*.mdx` output.

- [ ] **Step 2: Build the authored and generated site**

  Run: `pnpm -C site build`

  Expected: exit 0; the generated `/docs/skills/woostack-respond` page, configuration links,
  utilities link, and MDX all resolve.

- [ ] **Step 3: Smoke-install the collection into a temporary consumer**

  Run from a temporary directory outside the repository:

  ```bash
  pnpx skills add howarewoo/woostack --yes
  ```

  If the installer cannot target the unmerged local branch, use its documented local-path source
  against the current worktree instead of the remote default. Expected: `woostack-respond` is
  discoverable; the init templates contain `respond: {}` and `respond/.gitkeep`; evidence is
  ignored; all reference links resolve; and no application dependency/lockfile is created outside
  `site/`. Provider integrations remain optional recommendations, not install dependencies.

- [ ] **Step 4: Run the complete focused response suite**

  Run: `bash skills/woostack-respond/scripts/tests/run-tests.sh`

  Expected: all core, knowledge, command-surface, and authored-doc tests pass.

  Run: `bash skills/woostack-init/scripts/tests/run-tests.sh`

  Expected: all init tests pass.

  Run: `bash skills/woostack-doctor/scripts/tests/run-tests.sh`

  Expected: all doctor tests pass.

- [ ] **Step 5: Commit any test-only generator correction, if required**

  If Step 1 required a real generator fix, run:
  `gt modify -c -m "fix: generate response skill reference"`.

  If no file changed, make no empty commit.

---

## Plan Checks

### Spec and acceptance-criterion coverage

| Spec acceptance criterion | Plan task/test |
|---|---|
| AC1 invocation, precedence, report-only overrides | Increment 1 Task 2 config tests; Task 6 SKILL/e2e contract |
| AC2 capability-driven discovery and ambiguity | Increment 1 Task 1 provider contract; Task 6 orchestration assertions |
| AC3 output-bound receipts and false-clean prevention | Increment 1 Task 3 receipt fixtures; Task 6 e2e zero/blocked coverage |
| AC4 minimization and sanitization | Increment 1 Task 4 nested fixtures and tracked-write checks |
| AC5 bounded ranking, parallel investigation, dedupe/defer | Increment 1 Task 6 six-group e2e fixture |
| AC6 `woostack-debug` root-cause discipline | Increment 1 Task 6 structural contract and outcomes |
| AC7 deterministic complete/partial/blocked reports | Increment 1 Task 5 renderer fixtures; Task 6 e2e |
| AC8 gated verified remediation | Increment 1 Tasks 4 and 6 sanitized fix packet + verified-only assertions |
| AC9 observability-gap classification | Increment 1 Tasks 1, 5, and 6 report/skill contract |
| AC10 provider/production read-only boundary | Increment 1 Task 6 mutation-refusal assertions |
| AC11 config and guided init | Increment 1 Task 2; Increment 2 Tasks 1–2 |
| AC12 doctor and evidence hygiene | Increment 2 Tasks 1 and 3; Increment 1 Task 6 evidence preflight/cleanup |
| AC13 dream/wisdom self-improvement | Increment 3 Task 1 knowledge contract |
| AC14 public command/docs/install surface | Increment 3 Tasks 2–4 lockstep, docs, site, and install checks |

Every filled happy/error/edge case in spec §7 is represented above: zero and malformed receipts;
valid and invalid duration/group bounds; absent workspace; uncorroborated capability; provider
ambiguity/auth/target failure; partial multi-provider coverage; duplicate and overflow groups;
external and unverified causes; report-only remediation; sanitizer failure; overlapping fixes;
credential config; stale evidence; one-report wisdom rejection; and command-count drift.

### Placeholder scan

Self-review found no placeholder tokens, vague deferred implementation steps, or cross-task
references that require an undefined symbol. Every implementation step names its interface,
validation rule, fixture, exact focused command, and expected result.

### Type and contract consistency

- Config keys are exactly `provider`, `environment`, `window`, `max_groups`, `remediation`.
- Receipt status is exactly `executed`; blocked sources are coverage records, not receipts.
- Investigation status is exactly `verified|rejected|blocked`.
- Report outcome is exactly `complete|partial|blocked`; report frontmatter never uses lifecycle
  `status:`.
- Duration is 5 minutes through 30 days; max groups is 1 through 5.
- Evidence paths are ignored current-run directories or mode-`0700` OS temp; receipt output must be
  a regular non-symlink contained in that run directory.
- `prepare-fix` may dispatch sanitized verified packets; report-only controls never dispatch.

### Angle coverage

- **Architecture:** provider reads stay in host integrations; local scripts own deterministic
  invariants; existing debug/fix/build/dream owners are reused rather than duplicated.
- **Security/privacy:** progressive retrieval, ignored/temp storage proof, path containment,
  digest/count binding, recursive sanitizer, second-pass validation, forbidden credential config,
  and no provider/production mutation are tested.
- **Observability:** exact provider role/target/window/query coverage, receipts, partial/blocked
  outcomes, deferred queue, and observability-gap explanations are report requirements.
- **Testing:** every AC maps to a failing-first fixture or a concrete no-runner structural command;
  no live provider account is required.
- **Database/i18n/UI:** N/A; no persistent database schema, translated UI, or application interface
  is introduced.

### Decomposition verification

- Increment 1 is the minimum safe callable unit: it contains every privacy/receipt/report invariant
  before the skill can be registered. Its two deferral markers cover non-safety adoption gaps only.
- Increment 2 changes the shared config template and all health/setup consumers in one PR, honoring
  `[[lockstep-edit-sites]]`.
- Increment 3 changes the public count/routing/docs surface and the decision-corpus readers in one
  PR, then proves generated docs and installation. It removes the last deferral marker.
- Each increment has a distinct review question and leaves the stack behaviorally coherent.
