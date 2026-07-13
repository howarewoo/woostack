---
type: plan
source: .woostack/specs/2026-07-11-linear-artifact-backend.md
status: executing
branch: feature/linear-artifact-backend
---

**Source:** [[specs/2026-07-11-linear-artifact-backend]]

# Linear Spec and Plan Backend Implementation Plan

**Goal:** Make Linear a configurable, authoritative spec/plan backend across woostack while preserving the existing Markdown backend as the default.

**Architecture:** A shared artifact-backend resolver and normalized JSON contract sit under every spec/plan reader and author. The Markdown adapter preserves current filesystem behavior; one dependency-free Linear GraphQL adapter owns authentication, transport, metadata, identity, lifecycle mutations, receipts, and reconciliation. Workflow skills consume these contracts instead of directly assuming `.woostack/specs/` and `.woostack/plans/`.

**Tech Stack:** POSIX-oriented Bash, `curl`, `jq`, Python 3 standard library for deterministic JSON/Markdown transforms, Linear GraphQL API, existing shell test harness, Graphite/GitHub CLI, Fumadocs/Next.js docs site.

## File structure

- Create `skills/woostack-init/scripts/artifacts/resolve-backend.sh` — validate config and emit the selected backend plus non-secret repository identity.
- Create `skills/woostack-init/scripts/artifacts/markdown.sh` — normalize existing spec/plan files into the shared feature JSON model.
- Create `skills/woostack-init/scripts/artifacts/linear.sh` — sole public shell entry point for Linear operations.
- Create `skills/woostack-init/scripts/artifacts/linear-request.sh` — authenticated GraphQL transport, pagination, retry classification, secret redaction, and response validation.
- Create `skills/woostack-init/scripts/artifacts/linear-metadata.py` — canonical collapsed-section metadata parse/replace and normalized model validation.
- Create `skills/woostack-init/scripts/artifacts/graphql/*.graphql` — named, reviewable queries/mutations for preflight, projects, documents, issues, relations, and status reconciliation.
- Create `skills/woostack-init/scripts/tests/fixtures/linear/*.json` — deterministic API response fixtures.
- Create `skills/woostack-init/scripts/tests/test-artifact-backends.sh` — selector, config, identity, and Markdown compatibility tests.
- Create `skills/woostack-init/scripts/tests/test-linear-transport.sh` — HTTP/GraphQL/error/retry/redaction contract tests.
- Create `skills/woostack-init/scripts/tests/test-linear-metadata.sh` — metadata ownership, canonicalization, revision, and normalized-model tests.
- Create `skills/woostack-init/scripts/tests/test-linear-resources.sh` — project/document/issue identity, idempotency, relation, and receipt tests.
- Modify `skills/woostack-init/scripts/tests/run-tests.sh` — include the new focused suites.
- Modify `skills/woostack-init/templates/config.json` — add the backward-compatible artifact selector shape without secrets.
- Modify workflow `SKILL.md` files and their focused tests/references — route every spec/plan read/write through the backend contract.
- Modify authored `site/content/docs/*.mdx` pages that state artifact, lifecycle, status, config, or getting-started behavior.

## Increment 1: Backend resolver and Markdown compatibility

> Independently shippable base PR: introduces the backend contract while all workflows still use Markdown. Later Linear wiring is intentionally deferred.

### Task 1: Pin backend selection and repository identity

**Files:**
- Create: `skills/woostack-init/scripts/artifacts/resolve-backend.sh`
- Create: `skills/woostack-init/scripts/tests/test-artifact-backends.sh`
- Modify: `skills/woostack-init/templates/config.json`
- Modify: `skills/woostack-init/scripts/tests/run-tests.sh`

- [x] **Step 1: Add failing selector tests**
  Add cases to `test-artifact-backends.sh` that invoke `resolve-backend.sh` against temporary repositories and assert exact JSON output for: missing selector → `markdown`; explicit `markdown`; complete `linear`; unsupported selector; missing `linear.workspace`, `linear.team`, lifecycle mappings, or repository override when no GitHub remote; and rejection of credential-shaped config keys such as `apiKey`, `token`, or `credentialFile`.

- [x] **Step 2: Run the selector suite and confirm red**
  Run: `bash skills/woostack-init/scripts/tests/test-artifact-backends.sh`
  Expected: FAIL because `scripts/artifacts/resolve-backend.sh` does not exist.

- [x] **Step 3: Implement the resolver**
  Implement `resolve-backend.sh <repo-root>` with `set -euo pipefail`. Read `.woostack/config.json` with `jq`; emit one canonical JSON object with keys `backend`, `repository`, and `linear` (the last is `null` for Markdown). Resolve repository identity from an explicit `linear.repository` override, otherwise from the canonical GitHub `owner/repo` remote. Validate `artifacts.specPlan` against `markdown|linear`, require every configured semantic project/issue state in Linear mode, and reject secret-bearing Linear config keys. Diagnostics name only non-secret config paths.

- [x] **Step 4: Update the config template**
  Add `"artifacts": { "specPlan": "markdown" }` to `skills/woostack-init/templates/config.json`. Do not add a populated `linear` block or secret placeholder to the default template; document the conditional Linear object in the relevant reference increment.

- [x] **Step 5: Run selector tests green**
  Run: `bash skills/woostack-init/scripts/tests/test-artifact-backends.sh`
  Expected: PASS for default compatibility, complete Linear config, repository identity, invalid shape, and secret-key rejection.

### Task 2: Normalize the existing Markdown backend

**Files:**
- Create: `skills/woostack-init/scripts/artifacts/markdown.sh`
- Modify: `skills/woostack-init/scripts/tests/test-artifact-backends.sh`

- [x] **Step 1: Add failing Markdown normalization tests**
  Create temporary canonical spec/plan pairs and assert `markdown.sh feature <spec-path>` emits the normalized fields `backend`, `feature`, `spec`, and ordered `increments`. Cover the wikilink and legacy source-line forms, statuses, branch, checkbox progress, missing/duplicate plans, and filenames containing valid slug punctuation.

- [x] **Step 2: Run and confirm the missing adapter fails**
  Run: `bash skills/woostack-init/scripts/tests/test-artifact-backends.sh`
  Expected: FAIL at the first Markdown normalization case because `markdown.sh` does not exist.

- [x] **Step 3: Implement Markdown normalization without changing semantics**
  Implement `markdown.sh` as a read-only adapter over existing frontmatter and source-line contracts. Preserve current basename/source resolution and emit canonical JSON; fail on ambiguous 1:1 joins. Do not rewrite files. Add `# woostack-defer(increment 5): workflow skills begin consuming the backend adapter in increment 5` beside the adapter entry point.

- [x] **Step 4: Run focused and existing init tests**
  Run: `bash skills/woostack-init/scripts/tests/test-artifact-backends.sh && bash skills/woostack-init/scripts/tests/run-tests.sh`
  Expected: PASS; existing Markdown init behavior remains unchanged.

- [x] **Step 5: Commit Increment 1**
  Run: `gt create -m "feat(artifacts): add backend resolver and Markdown adapter"`
  Expected: one reviewable PR containing only config selection and Markdown normalization.

## Increment 2: Linear transport and metadata safety

> Stacks on Increment 1. Provides a tested API/metadata foundation without yet mutating feature resources.

### Task 1: Implement fail-closed GraphQL transport

**Files:**
- Create: `skills/woostack-init/scripts/artifacts/linear-request.sh`
- Create: `skills/woostack-init/scripts/artifacts/graphql/preflight.graphql`
- Create: `skills/woostack-init/scripts/tests/test-linear-transport.sh`
- Create: `skills/woostack-init/scripts/tests/fixtures/linear/http-*.json`
- Modify: `skills/woostack-init/scripts/tests/run-tests.sh`

- [x] **Step 1: Add transport fixtures and failing tests**
  Test exact behavior for: successful data; HTTP 401/403/429/5xx; HTTP 200 with top-level `errors`; partial `data` plus `errors`; malformed JSON; missing `LINEAR_API_KEY`; bounded retry for explicitly transient read queries; no blind mutation retry; retry timing extraction; and redaction of authorization values from stdout/stderr/receipt output. Use a fake `curl` executable prepended to `PATH` so the suite is offline.

- [x] **Step 2: Run transport tests red**
  Run: `bash skills/woostack-init/scripts/tests/test-linear-transport.sh`
  Expected: FAIL because `linear-request.sh` does not exist.

- [x] **Step 3: Implement request classification**
  Implement `linear-request.sh --operation <query|mutation> --document <path> --variables <json>`. Require `LINEAR_API_KEY`; POST to `https://api.linear.app/graphql`; separate headers/body/status; reject any GraphQL `errors` array; classify auth, rate-limit, retryable transport/server, and terminal client failures; retry only read queries with a fixed bounded attempt count; emit canonical response JSON on stdout and non-secret diagnostics on stderr.

- [x] **Step 4: Add schema preflight query**
  Add a named GraphQL document that resolves viewer/workspace, teams, project statuses, team workflow states, and required project/document/issue/relation mutation capabilities. Tests assert missing or ambiguous configured names are reported before a write operation.

- [x] **Step 5: Run transport tests green**
  Run: `bash skills/woostack-init/scripts/tests/test-linear-transport.sh`
  Expected: PASS with no network access and no secret material in captured output.

### Task 2: Implement canonical Linear metadata transforms

**Files:**
- Create: `skills/woostack-init/scripts/artifacts/linear-metadata.py`
- Create: `skills/woostack-init/scripts/tests/test-linear-metadata.sh`
- Create: `skills/woostack-init/scripts/tests/fixtures/linear/metadata-*.md`
- Modify: `skills/woostack-init/scripts/tests/run-tests.sh`

- [x] **Step 1: Add failing metadata tests**
  Assert parse and replace behavior for exactly one `+++ Woostack metadata — managed, do not edit` section containing canonical JSON. Cover round-trip preservation outside the section, sorted compact keys, unsupported schema, absent/duplicate/malformed blocks, foreign repository/project IDs, changed `updatedAt` or content hash, and Unicode human content.

- [x] **Step 2: Run metadata tests red**
  Run: `bash skills/woostack-init/scripts/tests/test-linear-metadata.sh`
  Expected: FAIL because `linear-metadata.py` does not exist.

- [x] **Step 3: Implement parser and narrow replacement**
  Implement Python subcommands `parse`, `replace`, `revision`, and `validate-feature`. Read UTF-8 from stdin, use only the standard library, require schema version `1`, canonicalize JSON with sorted keys and compact separators, preserve all bytes outside the managed section, and return nonzero with path-free diagnostics for invalid ownership or concurrency.

- [x] **Step 4: Run metadata and full init suites**
  Run: `bash skills/woostack-init/scripts/tests/test-linear-metadata.sh && bash skills/woostack-init/scripts/tests/run-tests.sh`
  Expected: PASS.

- [x] **Step 5: Commit Increment 2**
  Run: `gt create -m "feat(linear): add fail-closed GraphQL transport"`
  Expected: one PR containing transport, metadata transforms, fixtures, and focused tests.

## Increment 3: Linear projects and spec documents

> Stacks on Increment 2. Delivers idempotent feature/spec creation, discovery, lifecycle transitions, and read-back receipts.

### Task 1: Add project/document GraphQL operations

**Files:**
- Create: `skills/woostack-init/scripts/artifacts/linear.sh`
- Create: `skills/woostack-init/scripts/artifacts/graphql/project-list.graphql`
- Create: `skills/woostack-init/scripts/artifacts/graphql/project-create.graphql`
- Create: `skills/woostack-init/scripts/artifacts/graphql/project-update.graphql`
- Create: `skills/woostack-init/scripts/artifacts/graphql/document-list.graphql`
- Create: `skills/woostack-init/scripts/artifacts/graphql/document-create.graphql`
- Create: `skills/woostack-init/scripts/artifacts/graphql/document-update.graphql`
- Create: `skills/woostack-init/scripts/tests/test-linear-resources.sh`
- Create: `skills/woostack-init/scripts/tests/fixtures/linear/project-*.json`
- Create: `skills/woostack-init/scripts/tests/fixtures/linear/document-*.json`

- [x] **Step 1: Add failing feature discovery tests**
  Test explicit UUID, Linear URL, and repository/status discovery. Exactly one eligible managed project succeeds; zero returns not-found; multiple returns a deterministic candidate list containing UUID/title/status/URL; same titles and foreign repository markers never resolve implicitly.

- [x] **Step 2: Add failing create/resume tests**
  Simulate project create, unknown mutation outcome, discovery of the created project, spec document create, document read-back, duplicate managed resources, and retry after partial completion. Assert no duplicate create mutation occurs and each successful mutation emits a receipt with observed, attempted, returned, verified, and pending fields.

- [x] **Step 3: Run resource tests red**
  Run: `bash skills/woostack-init/scripts/tests/test-linear-resources.sh`
  Expected: FAIL because `linear.sh` and operation documents do not exist.

- [x] **Step 4: Implement project/spec commands**
  Implement `linear.sh preflight`, `feature-resolve`, `feature-create`, `feature-transition`, `spec-read`, and `spec-write`. Call only `linear-request.sh`; use discovery-before-create; verify repository/schema markers; compare revisions before update; use canonical metadata replacement; and read back every mutation. Never accept title-only adoption.

- [x] **Step 5: Implement required lifecycle enforcement**
  Resolve every semantic project status uniquely and require `abandoned`. `feature-transition` permits only workflow-valid forward transitions plus explicit abandon, rejects archive/delete behavior, and includes current/target status in its receipt.

- [x] **Step 6: Run resource and transport suites**
  Run: `bash skills/woostack-init/scripts/tests/test-linear-resources.sh && bash skills/woostack-init/scripts/tests/test-linear-transport.sh && bash skills/woostack-init/scripts/tests/test-linear-metadata.sh`
  Expected: PASS.

- [x] **Step 7: Commit Increment 3**
  Run: `gt create -m "feat(linear): manage feature projects and specs"`
  Expected: one PR that can preflight, create, resume, harden, approve, and abandon a Linear feature/spec without plan issues.

## Increment 4: Increment issues, dependencies, and reconciliation

> Stacks on Increment 3. Completes the Linear artifact backend normalized model and executable plan operations.

### Task 1: Manage ordered increment issues and relations

**Files:**
- Create: `skills/woostack-init/scripts/artifacts/graphql/issue-list.graphql`
- Create: `skills/woostack-init/scripts/artifacts/graphql/issue-create.graphql`
- Create: `skills/woostack-init/scripts/artifacts/graphql/issue-update.graphql`
- Create: `skills/woostack-init/scripts/artifacts/graphql/relation-create.graphql`
- Create: `skills/woostack-init/scripts/artifacts/graphql/relation-delete.graphql`
- Modify: `skills/woostack-init/scripts/artifacts/linear.sh`
- Modify: `skills/woostack-init/scripts/artifacts/linear-metadata.py`
- Modify: `skills/woostack-init/scripts/tests/test-linear-resources.sh`
- Create: `skills/woostack-init/scripts/tests/fixtures/linear/issue-*.json`

- [x] **Step 1: Add failing issue normalization tests**
  Assert stable integer ordinals, unique managed issue IDs, native `blocked by` relations, mirrored dependency UUIDs, same-project ownership, DAG acyclicity, one Git parent per issue, and representable multi-dependency ancestry. Include independent roots/tracks and deterministic presentation order.

- [x] **Step 2: Add failing reconciliation tests**
  Cover retained issue update, new issue creation, safe reorder, relation rewiring, removed issue without evidence, and refusal to remove/cancel any issue with branch or PR evidence. Unknown mutation outcomes must discover before retry.

- [x] **Step 3: Run resource tests red**
  Run: `bash skills/woostack-init/scripts/tests/test-linear-resources.sh`
  Expected: FAIL at issue/relationship cases.

- [x] **Step 4: Implement plan commands**
  Add `plan-read`, `plan-reconcile`, `issue-transition`, and `feature-read` to `linear.sh`. `feature-read` emits the normalized feature JSON model. Reconciliation preserves stable issue UUIDs, applies issue changes before relation changes, verifies the final DAG, and emits a compound receipt with completed/pending operations.

- [x] **Step 5: Implement PR attribution and terminal reconciliation inputs**
  Store `branch` and `pullRequest` only in the issue's managed metadata. Validate `Linear-Project` UUID and `Linear-Issue` identifier pairs. Add read-only computation that marks an issue eligible for `done` only when its unique attributed PR is merged, and a status-reconcile mutation that moves only eligible `inReview → done` states and then the all-done project.

- [x] **Step 6: Run all artifact suites**
  Run: `bash skills/woostack-init/scripts/tests/test-artifact-backends.sh && bash skills/woostack-init/scripts/tests/test-linear-transport.sh && bash skills/woostack-init/scripts/tests/test-linear-metadata.sh && bash skills/woostack-init/scripts/tests/test-linear-resources.sh`
  Expected: PASS.

- [x] **Step 7: Commit Increment 4**
  Run: `gt create -m "feat(linear): manage executable increment issues"`
  Expected: one PR delivering the complete Linear project/spec/plan data model.

## Increment 5: Build and plan workflow integration

> Stacks on Increment 4. Makes Linear usable through design, spec approval, planning, hardening, and the execution-handoff gate.

### Task 1: Route build and planning through the selected backend

**Files:**
- Modify: `skills/woostack-build/SKILL.md`
- Modify: `skills/woostack-build/references/spec-template.md`
- Modify: `skills/woostack-build/references/spec-template.html`
- Modify: `skills/woostack-plan/SKILL.md`
- Modify: `skills/woostack-plan/references/plan-template.md`
- Modify: `skills/woostack-harden/SKILL.md`
- Modify: `skills/woostack-ideate/SKILL.md`
- Create: `skills/woostack-build/tests/test-linear-build-contract.sh`
- Modify: `skills/woostack-init/scripts/tests/run-tests.sh`
- Modify: `skills/woostack-init/scripts/artifacts/markdown.sh`

- [x] **Step 1: Add a failing structural gate test**
  Assert both backend branches preserve exactly the design, spec, and handoff hard gates. Assert Linear mode calls preflight before its first mutation, creates no spec/plan worktree or docs-only PR, requires read-back at every transition, uses one project/document/issue set, freezes the base branch+SHA immediately before handoff, and creates no implementation Git artifact before explicit handoff approval.

- [x] **Step 2: Run the contract test red**
  Run: `bash skills/woostack-build/tests/test-linear-build-contract.sh`
  Expected: FAIL because the skills describe only Markdown artifacts.

- [x] **Step 3: Update build backend branches**
  Preserve the existing Markdown procedure verbatim behind `markdown`. Add the Linear procedure from the spec, including unique cross-session discovery, revise/abandon behavior, native transitions, no spec/plan PR, base freeze, and the currently supported Hand off terminal choice; Increment 6 adds Go and Run overnight when execution accepts Linear artifacts. Link shared backend commands rather than embedding GraphQL.

- [x] **Step 4: Update plan and harden targets**
  Make `woostack-plan` accept a required Markdown spec path in Markdown mode or a Linear project UUID/URL in Linear mode. Define issue-per-increment output, native relations, ordinals, Git parents, AC coverage, reconciliation safety, and `planning → ready`. Make harden amend the selected artifact in place and retain its no-gate contract.

- [x] **Step 5: Remove the Increment 1 deferral marker**
  Remove `woostack-defer(increment 5)` from `markdown.sh` when build and plan begin using the resolver.

- [x] **Step 6: Keep template pair synchronized**
  Update Markdown/HTML spec templates only where backend-neutral language changed, preserving their 1:1 section contract. Update plan template with the normalized backend input contract without weakening Markdown frontmatter/source joins.

- [x] **Step 7: Run build and artifact tests**
  Run: `bash skills/woostack-build/tests/test-linear-build-contract.sh && bash skills/woostack-init/scripts/tests/run-tests.sh`
  Expected: PASS for both backend branches and all three gates.

- [x] **Step 8: Commit Increment 5**
  Run: `gt create -m "feat(build): support Linear-backed specs and plans"`
  Expected: one PR enabling the pre-execution build loop with no implementation behavior changes.

## Increment 6: Execution, worktrees, and PR attribution

> Stacks on Increment 5. Executes Linear increment issues through supervised and overnight Graphite flows.

### Task 1: Execute issue-backed increments

**Files:**
- Modify: `skills/woostack-execute/SKILL.md`
- Modify: `skills/woostack-execute/references/controller.md`
- Modify: `skills/woostack-execute/references/inline-driver.md`
- Modify: `skills/woostack-execute/references/subagent-driver.md`
- Modify: `skills/woostack-execute-overnight/SKILL.md`
- Modify: `skills/woostack-init/references/worktrees.md`
- Modify: `skills/woostack-tdd/SKILL.md`
- Create: `skills/woostack-execute/tests/test-linear-execute-contract.sh`

- [x] **Step 1: Add failing execution-state tests**
  Assert: execution input resolves ordered ready issues; issue moves to `executing` before code; root worktrees start at frozen SHA; dependent worktrees start at declared parent branches; overnight processes one ready independent track at a time under the existing sequential fault-isolation policy; blocked/test/submit/API failures never advance to `inReview`; successful `gt submit` plus read-back writes branch/PR metadata and then `inReview`; build never sets `done`.

- [x] **Step 2: Run execution contract red**
  Run: `bash skills/woostack-execute/tests/test-linear-execute-contract.sh`
  Expected: FAIL because execution accepts only Markdown plan paths.

- [x] **Step 3: Update supervised execution**
  Add backend resolution at entry. Preserve Markdown checkbox/status behavior. In Linear mode, use issue content as the live task record, update only the managed progress representation owned by woostack, enforce native dependency/Git-parent readiness, and require verified API receipts around state transitions.

- [x] **Step 4: Update overnight tracks**
  Make Linear native dependency roots/tracks drive fault isolation while preserving the current sequential policy: select one ready track deterministically, complete or block it, then advance to the next. A blocker ends only the affected track and writes the issue `blocked` state plus morning-report evidence. Never infer track order from Linear UI sort, and do not introduce Linear-only concurrency.

- [x] **Step 5: Update TDD and worktree contracts**
  Allow Linear issue targets wherever a plan increment is accepted. Document that spec/plan authoring worktrees and docs-only base branches are Markdown-only; Linear implementation worktrees use the frozen root SHA or declared issue parent branch.

- [x] **Step 6: Run execution tests**
  Run: `bash skills/woostack-execute/tests/test-linear-execute-contract.sh && bash skills/woostack-execute/tests/run-tests.sh && bash skills/woostack-execute-overnight/tests/run-tests.sh`
  Expected: PASS for Markdown and Linear execution paths.

### Task 2: Attribute commits and PRs to Linear

**Files:**
- Modify: `skills/woostack-commit/SKILL.md`
- Modify: `skills/woostack-status/references/conventions.md`
- Create: `skills/woostack-commit/tests/test-linear-attribution.sh`

- [x] **Step 1: Add failing attribution tests**
  Assert Markdown PRs retain the exact `Spec:` trailer. Linear PRs require exactly one `Linear-Project: <uuid>` and one `Linear-Issue: <TEAM-NUMBER>` trailer; mismatches, duplicates, foreign project issues, and missing API verification block submission/update.

- [x] **Step 2: Run attribution tests red**
  Run: `bash skills/woostack-commit/tests/test-linear-attribution.sh`
  Expected: FAIL because commit supports only file trailers.

- [x] **Step 3: Implement backend-specific PR bodies**
  Resolve backend before invariant checks and PR drafting. Preserve Markdown logic. For Linear, fetch the issue/project relationship, include both trailers, and record the submitted branch/PR URL back to the issue only after `gt submit` success and read-back.

- [x] **Step 4: Run attribution and execution suites**
  Run: `bash skills/woostack-commit/tests/test-linear-attribution.sh && bash skills/woostack-execute/tests/test-linear-execute-contract.sh`
  Expected: PASS.

- [x] **Step 5: Commit Increment 6**
  Run: `gt create -m "feat(execute): run Linear increment issues"`
  Expected: one PR enabling end-to-end implementation and PR attribution without merge behavior.

## Increment 7: Status reconciliation

> Stacks on Increment 6. Delivers terminal merge reconciliation and backend-aware board rendering as one reviewable status change.

### Task 1: Render and reconcile Linear feature status

**Files:**
- Modify: `skills/woostack-status/SKILL.md`
- Modify: `skills/woostack-status/scripts/status.sh`
- Modify: `skills/woostack-status/scripts/lib.sh`
- Modify: `skills/woostack-status/scripts/tests/test-status.sh`
- Modify: `skills/woostack-status/scripts/tests/test-html-board.sh`
- Modify: `skills/woostack-status/scripts/board-template.html`

- [x] **Step 1: Add failing Linear board/reconciliation tests**
  Mock normalized Linear projects and GitHub PR states. Assert every Linear-backed status run authenticates, previews exact eligible `inReview → done` transitions, applies only merge-backed transitions, verifies read-back, transitions the project only after all issues are done, then renders. Missing credentials, ambiguous trailers, API failure, or mismatch must fail closed. Markdown status remains read-only and unchanged.

- [x] **Step 2: Run status tests red**
  Run: `bash skills/woostack-status/scripts/tests/run-tests.sh`
  Expected: FAIL at new Linear cases.

- [x] **Step 3: Implement backend-aware board input**
  Route Markdown enumeration through `markdown.sh`; query managed repository projects through `linear.sh`. Reconcile only terminal transitions before rendering and never reopen/downgrade or change non-terminal states. Preserve HTML escaping and stale-age behavior.

- [x] **Step 4: Run status tests green**
  Run: `bash skills/woostack-status/scripts/tests/run-tests.sh`
  Expected: PASS for Markdown rendering and Linear reconciliation/rendering.

- [x] **Step 5: Commit Increment 7**
  Run: `gt create -m "feat(status): reconcile Linear feature lifecycle"`
  Expected: one PR limited to status reconciliation and board rendering.

## Increment 8: Doctor and provenance

> Stacks on Increment 7. Makes static/live workspace diagnostics and memory provenance backend-aware without changing unrelated readers.

### Task 1: Make doctor and provenance backend-aware

**Files:**
- Modify: `skills/woostack-doctor/SKILL.md`
- Modify: `skills/woostack-doctor/references/checks.md`
- Modify: `skills/woostack-doctor/scripts/checks/config-keys.sh`
- Modify: `skills/woostack-doctor/scripts/checks/doc-type.sh`
- Modify: `skills/woostack-doctor/scripts/checks/status-enum.sh`
- Modify: `skills/woostack-doctor/scripts/checks/status-band.sh`
- Modify: `skills/woostack-doctor/scripts/checks/plan-source.sh`
- Modify: `skills/woostack-doctor/scripts/checks/spec-plan-backlink.sh`
- Modify: `skills/woostack-doctor/scripts/checks/memory.sh`
- Modify: `skills/woostack-doctor/scripts/tests/run-tests.sh`
- Modify: `skills/woostack-init/references/memory.md`
- Modify: `skills/woostack-doctor/scripts/doctor.sh`
- Add: `skills/woostack-doctor/scripts/tests/test-linear-backend.sh`
- Modify: `skills/woostack-init/scripts/artifacts/graphql/preflight.graphql`
- Add: `skills/woostack-init/scripts/artifacts/graphql/provenance-document.graphql`
- Add: `skills/woostack-init/scripts/artifacts/graphql/provenance-issue.graphql`
- Modify: `skills/woostack-init/scripts/artifacts/linear-preflight.sh`
- Modify: `skills/woostack-init/scripts/artifacts/linear.sh`
- Modify: `skills/woostack-init/scripts/tests/fixtures/linear/http-preflight-ambiguous.json`
- Modify: `skills/woostack-init/scripts/tests/fixtures/linear/http-preflight-missing-capability.json`
- Modify: `skills/woostack-init/scripts/tests/fixtures/linear/http-preflight-missing.json`
- Modify: `skills/woostack-init/scripts/tests/fixtures/linear/http-preflight-partial-page.json`
- Modify: `skills/woostack-init/scripts/tests/fixtures/linear/http-preflight-success.json`
- Modify: `skills/woostack-init/scripts/tests/fixtures/linear/http-preflight-wrong-team.json`
- Add: `skills/woostack-init/scripts/tests/fixtures/linear/provenance-document.json`
- Add: `skills/woostack-init/scripts/tests/fixtures/linear/provenance-issue.json`
- Modify: `skills/woostack-init/scripts/tests/test-linear-resources.sh`

- [x] **Step 1: Add failing static/live doctor tests**
  Assert static Linear checks validate selector/config/URI shapes without credentials, skip local spec/plan document checks, and report inactive legacy files. Assert opt-in live checks validate auth, schema, workspace/team/mappings, mutation-field capabilities, resource existence, and relation/metadata drift, while explicitly reporting that effective write authorization cannot be proven without mutation. Add `linear://project/`, `linear://document/`, and `linear://issue/` provenance cases.

- [x] **Step 2: Run doctor tests red**
  Run: `bash skills/woostack-doctor/scripts/tests/run-tests.sh`
  Expected: FAIL at new backend/provenance cases.

- [x] **Step 3: Implement backend gating and live diagnostics**
  Keep existing Markdown checks exact. In Linear mode, replace filesystem spec/plan checks with config/static URI checks; make live validation explicit and authenticated; never auto-repair remote content during ordinary doctor repair. Update memory provenance parsing and resolution through the adapter.

- [x] **Step 4: Run doctor tests green**
  Run: `bash skills/woostack-doctor/scripts/tests/run-tests.sh`
  Expected: PASS.

- [x] **Step 5: Commit Increment 8**
  Run: `gt create -m "feat(doctor): validate Linear artifact state"`
  Expected: one PR limited to doctor checks and provenance.

## Increment 9: Read-only artifact consumers

> Stacks on Increment 8. Completes the remaining multi-reader cutover behind one structural contract.

### Task 1: Route remaining consumers

**Files:**
- Modify: `.github/workflows/reusable-review.yml`
- Modify: `action.yml`
- Modify: `skills/woostack-review/SKILL.md`
- Modify: `skills/woostack-address-comments/SKILL.md`
- Modify: `skills/woostack-ask/SKILL.md`
- Modify: `skills/woostack-visualize/SKILL.md`
- Modify: `skills/woostack-debug/SKILL.md`
- Modify: `skills/woostack-audit/SKILL.md`
- Modify: `skills/woostack-dream/SKILL.md`
- Modify: `skills/woostack-review/scripts/resolve-artifact-context.sh`
- Modify: `skills/woostack-review/scripts/tests/test-action-artifact-context.sh`
- Modify: `skills/woostack-review/scripts/tests/test-resolve-artifact-context.sh`
- Modify: `skills/woostack-init/scripts/artifacts/linear.sh`
- Create: `skills/woostack-init/scripts/artifacts/graphql/identity-project.graphql`
- Create: `skills/woostack-init/scripts/artifacts/graphql/identity-project-slug.graphql`
- Create: `skills/woostack-init/scripts/artifacts/graphql/identity-document.graphql`
- Create: `skills/woostack-init/scripts/artifacts/graphql/identity-document-slug.graphql`
- Create: `skills/woostack-init/scripts/artifacts/graphql/identity-issue.graphql`
- Create: `skills/woostack-init/scripts/artifacts/graphql/identity-issue-key.graphql`
- Modify: `skills/woostack-init/scripts/tests/test-linear-resources.sh`
- Create: `skills/using-woostack/tests/test-artifact-reader-contract.sh`

- [x] **Step 1: Add a failing multi-reader structural test**
  Enumerate approved backend adapters and explicit Markdown compatibility sites. Fail when a spec/plan consumer directly scans `.woostack/specs/` or `.woostack/plans/` without first resolving the backend. Assert read-only consumers never issue Linear mutations.

- [x] **Step 2: Run the structural test red**
  Run: `bash skills/using-woostack/tests/test-artifact-reader-contract.sh`
  Expected: FAIL with the current direct-reader site list.

- [x] **Step 3: Update reader contracts**
  Resolve PR context from backend-specific trailers; let ask/debug/audit/review fetch normalized feature/spec/issue content; let visualize accept Linear URLs/UUIDs; preserve each command's existing read-only or mutation boundary. Update dream only where it enumerates the artifact corpus; it must not curate Linear specs/plans as memory.

- [x] **Step 4: Run reader and subsystem suites**
  Run: `bash skills/using-woostack/tests/test-artifact-reader-contract.sh && bash skills/woostack-status/scripts/tests/run-tests.sh && bash skills/woostack-doctor/scripts/tests/run-tests.sh`
  Expected: PASS with no unapproved direct readers.

- [x] **Step 5: Commit Increment 9**
  Run: `gt create -m "feat(artifacts): route remaining feature readers"`
  Expected: one PR completing backend-aware review, ask, visualize, debug, audit, and dream reads.

## Increment 10: Adoption docs and lockstep contract verification

> Stacks on Increment 9. Completes consumer-facing documentation and proves all mirrored contracts stay synchronized.

### Task 1: Update repository and bootstrap guidance

**Files:**
- Modify: `AGENTS.md`
- Modify: `README.md`
- Modify: `CONTRIBUTING.md`
- Modify: `skills/using-woostack/SKILL.md`
- Modify: `skills/woostack-bootstrap/references/development.md`
- Modify: `skills/woostack-init/SKILL.md`
- Modify: `skills/woostack-init/references/worktrees.md`
- Modify: `skills/woostack-status/references/conventions.md`

- [x] **Step 1: Add failing documentation contract assertions**
  Extend the structural artifact-reader test to assert: Markdown is described as the default, not universal; Linear auth is environment-only; project/document/issues and native states are canonical in Linear mode; three gates remain; no docs-only base PR exists in Linear mode; status always reconciles terminal states; no public command count/routing row is added.

- [x] **Step 2: Run docs contract red**
  Run: `bash skills/using-woostack/tests/test-artifact-reader-contract.sh`
  Expected: FAIL on stale Markdown-only statements.

- [x] **Step 3: Update authored skill/repository references**
  Cross-link the backend and lifecycle authorities instead of duplicating query details. Keep the twenty-one-skill public/adoption surface and twenty-four fixed `SKILL.md` locations unchanged. Document `LINEAR_API_KEY` without showing a real value or suggesting checked-in env files.

- [x] **Step 4: Run docs contract green**
  Run: `bash skills/using-woostack/tests/test-artifact-reader-contract.sh`
  Expected: PASS.

### Task 2: Synchronize authored docs-site pages

**Files:**
- Modify: `site/content/docs/index.mdx`
- Modify: `site/content/docs/getting-started.mdx`
- Modify: `site/content/docs/concepts.mdx`
- Modify: `site/content/docs/configuration.mdx`
- Modify: `site/content/docs/concepts/building-rules.mdx`
- Modify: `site/content/docs/concepts/status-tracking.mdx`

- [x] **Step 1: Update the authored framing pages**
  Explain backend selection, environment authentication, Linear artifact mapping, native lifecycle behavior, gate differences, status reconciliation, migration boundary, and Markdown compatibility. Do not manually edit generated per-skill pages.

- [x] **Step 2: Run all focused shell suites**
  Run: `bash skills/woostack-init/scripts/tests/run-tests.sh && bash skills/woostack-build/tests/test-linear-build-contract.sh && bash skills/woostack-execute/tests/test-linear-execute-contract.sh && bash skills/woostack-commit/tests/test-linear-attribution.sh && bash skills/woostack-status/scripts/tests/run-tests.sh && bash skills/woostack-doctor/scripts/tests/run-tests.sh && bash skills/using-woostack/tests/test-artifact-reader-contract.sh`
  Expected: PASS.

- [x] **Step 3: Build the documentation site**
  Run: `pnpm -C site build`
  Expected: PASS; authored pages compile and generated skill references remain valid.

- [x] **Step 4: Run the opt-in Linear sandbox smoke test**
  With `LINEAR_API_KEY` and an explicitly configured disposable sandbox team, run the documented smoke operation to preflight, create/read/update/abandon a managed project, spec document, two related increment issues, and read-back receipts.
  Expected: PASS and the disposable project ends in configured `abandoned`; if no sandbox credentials are available, record this manual check as not run rather than substituting mocks.
  Result: **NOT RUN** — `LINEAR_API_KEY` and an explicitly configured disposable sandbox team were unavailable; no mocks were substituted.

- [x] **Step 5: Commit Increment 10**
  Run: `gt create -m "docs: document Linear artifact backend"`
  Expected: final reviewable PR containing authored documentation and lockstep verification only.

## Plan checks

- **Spec coverage:** AC1–AC12 map across Increments 1–10; backend/config (1), API safety (2), identity/specs (3), plan issues (4), gates/planning (5), execution/attribution (6), status reconciliation (7), doctor/provenance (8), remaining readers (9), and documentation/compatibility (10).
- **AC coverage:** every happy/error/edge case has a named failing-test step. Security cases cover secret storage/logging, foreign identity, authorization, and unsafe adoption; observability cases cover classified diagnostics and receipts; API cases cover HTTP/GraphQL partial failure and schema preflight.
- **No placeholders:** every task names exact files, commands, expected red/green behavior, and mutation invariants. The optional live smoke check has an explicit not-run rule when credentials are unavailable; it is not substituted for deterministic tests.
- **Type consistency:** normalized fields remain `backend`, `feature`, `spec`, and `increments`; Linear identities use project/document/issue UUIDs plus issue identifier; lifecycle semantics use the config keys from the spec.
- **Architecture:** transport, metadata, resource operations, workflow policy, and presentation remain separate. Only the shared adapter calls Linear. Markdown parsing remains isolated in its adapter.
- **Increment boundaries:** each increment is independently reviewable and leaves the Markdown default working. Increment 1's temporary adapter deferral marker is removed in Increment 5 when workflow consumption lands.
- **Security:** credentials remain environment-only, logs/receipts are redacted, title-only adoption is forbidden, repository ownership is verified, and mutations fail closed.
- **Observability:** every mutation has a read-back receipt; failures include operation and non-secret resource identifiers; empty/partial success cannot masquerade as completion.
- **Dependencies:** no application package or lockfile is introduced outside `site/`; runtime uses existing shell tools plus Python standard library.
- **Hardened decision:** Linear preserves the dependency DAG and independent overnight tracks, but both supervised and overnight execution remain sequential under the existing policy; concurrency is outside this feature.
