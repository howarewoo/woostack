---
type: plan
source: .woostack/specs/2026-07-26-linear-only-collaboration.md
status: ready
branch: feature/linear-only-collaboration
---

**Source:** [[specs/2026-07-26-linear-only-collaboration]]

> **Normalized backend input:** the approved Markdown spec at `.woostack/specs/2026-07-26-linear-only-collaboration.md`. This build run remains on its already-resolved Markdown backend through the execution handoff; the implementation removes backend selection only for future woostack runs.

# Linear-only Collaboration Implementation Plan

**Goal:** Replace woostack's local and custom-GraphQL development-record model with mandatory official Linear MCP projects, updates, issues, comments, assignments, relations, and verified receipts, then document and enforce a decision-making engineer-agent contract with Hermes + OMP as the first concrete setup.

**Architecture:** A single canonical Linear MCP contract defines resource identity, capability discovery, typed project/issue events, ownership, lifecycle, trust, migration, and read-back receipts. Workflow skills call host-exposed MCP tools directly and keep only non-authoritative local knowledge, diagnostics, and disposable worktree administration; no runtime adapter or backend resolver survives. Project work and standalone issue work then share one attribution/ownership controller, while the generic engineer-agent boundary keeps decision/review authority outside the paired coding agent.

**Tech Stack:** Markdown Agent Skills, official hosted Linear MCP (`https://mcp.linear.app/mcp`), OAuth 2.1 / Linear app identities, Bash structural contract tests, JSON behavior eval fixtures, Git/Graphite, GitHub CLI and GitHub Actions, Hermes Agent, OMP, Fumadocs/Next.js.

## Stack and execution order

Create one linear Graphite stack above the existing spec+plan base branch. Each increment has one branch and one PR; each Git parent is the immediately preceding increment. The clean cutover is complete only after increment 8 removes the dormant compatibility implementation, but every intermediate PR must keep the existing suites green and must not invent a second authority.

| Increment | Branch | Git parent | Acceptance coverage |
| --- | --- | --- | --- |
| 1 | `feature/linear-mcp-authority` | `feature/linear-only-collaboration` | AC1–AC5 foundations, AC9 prerequisite |
| 2 | `feature/linear-project-lifecycle` | increment 1 | AC2, AC3, AC6 multi-PR path |
| 3 | `feature/linear-issue-workflows` | increment 2 | AC2, AC3, AC6 single-PR/bootstrap path |
| 4 | `feature/linear-execution-tracking` | increment 3 | AC3, AC4, AC7, AC8 |
| 5 | `feature/linear-context-consumers` | increment 4 | AC1, AC3, AC4, AC8, AC9 read-only/CI boundary |
| 6 | `feature/engineer-agent-contract` | increment 5 | AC7, AC10 |
| 7 | `feature/linear-only-documentation` | increment 6 | AC10, AC11 |
| 8 | `feature/remove-local-linear-transport` | increment 7 | AC4, AC5, AC9, AC12 and full cutover proof |

Every implementation branch follows Red → Green → Refactor. Run only the named bounded suites while developing; increment 8 runs all affected suites once. Do not run the live provider acceptance until every deterministic contract and migration fixture passes.

## Increment 1: Canonical Linear MCP authority, initialization, and migration

> **Branch:** `feature/linear-mcp-authority`  
> **Depends on:** Spec+plan base PR  
> **Git parent:** `feature/linear-only-collaboration`

> Establish one authority before changing callers. Existing adapters may remain physically present until increment 8, but this increment marks them legacy-only and no newly edited workflow may call them.

### Task 1: Pin the Linear-only configuration and resource contracts

**Files:**
- Modify: `skills/woostack-init/references/artifact-backends.md`
- Modify: `skills/woostack-bootstrap/references/development.md`
- Modify: `skills/woostack-status/references/conventions.md`
- Modify: `skills/woostack-init/templates/config.json`
- Modify: `.woostack/config.json`
- Modify: `skills/woostack-init/templates/gitignore`
- Modify: `.woostack/.gitignore`
- Create: `skills/woostack-init/scripts/config/resolve-config.sh`
- Create: `skills/woostack-init/scripts/tests/test-config-precedence.sh`
- Create: `skills/woostack-init/scripts/tests/test-linear-only-contract.sh`
- Modify: `skills/woostack-init/scripts/tests/run-tests.sh`

- [ ] **Step 1 — Red: reject backend and credential configuration**

Create structural tests that fail while any active config/template/reference still accepts `artifacts.specPlan`, calls `resolve-backend.sh`, requires `LINEAR_API_KEY`, treats a Linear document as development state, or defines Markdown as a development backend. Pin the config layering contract separately: `.woostack/config.local.json` is ignored, resolves from the primary checkout when a command runs in a worktree, may override only `linear.team`, wins over the committed value, and rejects credential-like or unknown keys. The tests must separately allow GitHub GraphQL and the words Markdown/GraphQL inside migration history and explicit rejection prose.

```bash
bash skills/woostack-init/scripts/tests/test-linear-only-contract.sh
```

Expected: FAIL with exact active-path findings for `artifacts.specPlan`, `LINEAR_API_KEY`, backend resolution, document-backed specs, local spec/plan authority, and the missing local-team override contract.

- [ ] **Step 2 — Green: define one versioned managed schema**

Make `artifact-backends.md` the canonical contract for:

```text
resource roles: feature | increment | work-item
project event kinds: designApproved | specHardened | specApproved | planning | ready |
  executionApproved | executing | inReview | done | abandoned | decision | progress |
  blockerOpened | blockerResolved | handoff
issue event kinds: assignmentAccepted | implementationEvidence | decisionRequest |
  reviewResult | verification | acceptance | handoff | blocked | unblocked | failure
identity: client UUID + repository URL + woostack label + role
receipt: identity + workspace/team + repository + role + revision/event + native state +
  resolved work owner + required relations
```

Specify canonical single-line JSON after `+++ Woostack metadata — managed, do not edit`, append-only revisions/supersession, untrusted remote text, unknown-outcome retry by UUID, project phase-chain validation, coarse native project categories, semantic issue-state mappings, type-aware assignee/delegate ownership, and exact PR trailers. Remove the backend selector from both committed config files; keep only non-secret Linear policy (`repository`, `workspace`, optional default `team`, category/state mappings), models/review/respond/status, and existing unrelated settings. Add an ignored `.woostack/config.local.json`, resolved from the primary checkout through the Git common directory, whose only supported override is `linear.team`; the local team wins over a committed default so separate clones can bind the same repository to different Linear teams without changing tracked policy. Reject unknown or credential-like local keys and require the effective merged config to contain exactly one validated team.

- [ ] **Step 3 — Verify the contract**

```bash
bash skills/woostack-init/scripts/tests/test-linear-only-contract.sh
bash skills/woostack-init/scripts/tests/test-config-precedence.sh
python3 -m json.tool skills/woostack-init/templates/config.json >/dev/null
python3 -m json.tool .woostack/config.json >/dev/null
git check-ignore -q .woostack/config.local.json
```

Expected: PASS; config has no backend selector or credential key, the local team override is ignored and wins deterministically from both primary and linked worktrees, and the canonical reference names no Linear document as an owned resource.

### Task 2: Make init and doctor capability-driven

**Files:**
- Modify: `skills/woostack-init/SKILL.md`
- Modify: `skills/woostack-doctor/SKILL.md`
- Modify: `skills/woostack-doctor/references/checks.md`
- Modify: `skills/woostack-doctor/scripts/doctor.sh`
- Modify: `skills/woostack-doctor/scripts/checks/config-keys.sh`
- Modify: `skills/woostack-doctor/scripts/checks/doc-type.sh`
- Modify: `skills/woostack-doctor/scripts/checks/plan-source.sh`
- Modify: `skills/woostack-doctor/scripts/checks/spec-plan-backlink.sh`
- Modify: `skills/woostack-doctor/scripts/checks/status-band.sh`
- Modify: `skills/woostack-doctor/scripts/checks/status-enum.sh`
- Replace: `skills/woostack-doctor/scripts/tests/test-linear-backend.sh`
- Modify: `skills/woostack-doctor/scripts/tests/test-doctor.sh`
- Modify: `skills/woostack-doctor/scripts/tests/run-tests.sh`
- Modify: `skills/woostack-init/evals/evals.json`
- Modify: `skills/woostack-doctor/evals/evals.json`
- Modify: `skills/woostack-init/evals/fixtures/project/.woostack/config.json`
- Modify: `skills/woostack-doctor/evals/fixtures/project/.woostack/config.json`
- Modify: `skills/woostack-doctor/evals/fixtures/ci-project/.woostack/config.json`

- [ ] **Step 1 — Red: add static and live-preflight cases**

Pin these outcomes in shell tests and eval fixtures:

```text
static success: valid non-secret committed policy plus a valid effective team from committed or local config; no provider call
static failure: backend selector, credential-like key, incomplete category/state mapping, unsupported local override, or missing effective team
local precedence: primary-root `.woostack/config.local.json` overrides only `linear.team` from both the primary checkout and linked worktrees
live success: host MCP exposes required read/write/update/comment/relation/owner/read-back capabilities
live read-only: report exact missing mutation capabilities and block mutating commands
legacy records: one blocking migration finding per active/ambiguous set, no normal spec/plan lint
missing MCP/auth/team/state: actionable fail-closed result before artifact or Git access
```

The shell doctor accepts a normalized, non-secret live receipt supplied by the skill controller for testability; it never invokes HTTP, GraphQL, an API-key adapter, or a hard-coded MCP tool name.

```bash
bash skills/woostack-doctor/scripts/tests/run-tests.sh
```

Expected: FAIL because init still creates local development directories and doctor still resolves two backends.

- [ ] **Step 2 — Green: change initialization and live validation**

`/woostack-init` must discover the host's MCP tools, authenticate to `https://mcp.linear.app/mcp`, resolve exactly one workspace and selected team, validate native categories and issue states, prove the capability set by reversible/non-destructive reads where possible, and persist only non-secret policy. Repository-wide policy stays in committed `.woostack/config.json`; the selected `linear.team` is written to ignored primary-root `.woostack/config.local.json` and overrides any committed default. Stop before writing project files when setup is incomplete. Stop creating `.woostack/specs/`, `.woostack/plans/`, and `.woostack/fixes/`; retain memory, wisdom, respond, ignored worktrees, and non-authoritative diagnostics.

`/woostack-doctor` resolves and validates the same effective layered config in the primary checkout and linked worktrees, runs static filesystem/config checks in its script, and performs provider discovery/read-back in the skill controller only for `--live`. No shell script may pretend to call a host MCP tool. Remove normal local spec/plan lifecycle checks; legacy directories become migration blockers.

- [ ] **Step 3 — Verify init/doctor behavior**

```bash
bash skills/woostack-init/scripts/tests/run-tests.sh
bash skills/woostack-doctor/scripts/tests/run-tests.sh
```

Expected: PASS for committed/local config precedence, worktree-stable team resolution, normalized live receipts, missing-capability failures, and legacy blockers; no test requires network credentials.

### Task 3: Specify and fixture the loss-safe one-way migration

**Files:**
- Create: `skills/woostack-init/references/migration.md`
- Modify: `skills/woostack-init/SKILL.md`
- Modify: `skills/woostack-doctor/SKILL.md`
- Create: `skills/woostack-init/scripts/tests/test-linear-migration-contract.sh`
- Create: `skills/woostack-init/evals/fixtures/migration-active.json`
- Create: `skills/woostack-init/evals/fixtures/migration-historical.json`
- Create: `skills/woostack-init/evals/fixtures/migration-ambiguous.json`
- Create: `skills/woostack-init/evals/fixtures/migration-partial.json`
- Create: `skills/woostack-init/evals/fixtures/migration-foreign.json`
- Modify: `skills/woostack-init/evals/evals.json`

- [ ] **Step 1 — Red: pin no-deletion-on-uncertainty**

Add fixture assertions for active, completed-with-merge-evidence, closed-without-acceptance, malformed, partially migrated, and foreign resources. Every unknown/partial case must return `localDeletions: []`, preserve original knowledge provenance, and expose stable remote IDs already created.

```bash
bash skills/woostack-init/scripts/tests/test-linear-migration-contract.sh
```

Expected: FAIL because no canonical migration contract exists.

- [ ] **Step 2 — Green: author the resumable migration procedure**

Define exact classification inputs, Git blob/PR recovery proof, active-resource mapping, stable UUID creation/resume, MCP receipt aggregation, memory/wisdom provenance rewrite, all-or-nothing local deletion, and post-delete verification. Historical records stay in Git and are not imported. Ambiguity requires explicit classification. A partial run resumes only by verified embedded IDs and never by title.

- [ ] **Step 3 — Verify migration safety**

```bash
bash skills/woostack-init/scripts/tests/test-linear-migration-contract.sh
bash skills/woostack-init/scripts/tests/run-tests.sh
```

Expected: PASS; incomplete remote receipts and unresolved provenance produce zero deletions.

**Increment verification:**

```bash
bash skills/woostack-init/scripts/tests/run-tests.sh
bash skills/woostack-doctor/scripts/tests/run-tests.sh
```

Manual: inspect the canonical contract and a simulated partial migration handback; confirm it names exact remote identities and leaves every local record untouched.

## Increment 2: Multi-PR project lifecycle through Linear projects, updates, and issues

> **Branch:** `feature/linear-project-lifecycle`
> **Depends on:** Increment 1  
> **Git parent:** `feature/linear-mcp-authority`

> Replaces document-backed build/planning with typed project updates and dependency-aware issue contracts while preserving exactly three build gates.

### Task 1: Convert build to project-update lifecycle authority

**Files:**
- Modify: `skills/woostack-build/SKILL.md`
- Remove: `skills/woostack-build/references/markdown-procedure.md`
- Replace: `skills/woostack-build/references/linear-procedure.md`
- Modify: `skills/woostack-build/references/spec-template.md`
- Modify: `skills/woostack-ideate/SKILL.md`
- Modify: `skills/woostack-harden/SKILL.md`
- Replace: `skills/woostack-build/tests/test-linear-build-contract.sh`
- Modify: `skills/woostack-build/evals/evals.json`
- Modify: `skills/woostack-build/evals/fixtures/build-state.json`

- [ ] **Step 1 — Red: pin the three gates and one-project invariant**

The contract test must assert:

```text
before design approval: no Linear artifact
one-PR classification: route to woostack-change; create no project
after design approval: one repository-owned project + verified designApproved update
spec hardening: append/revise specHardened update; no Linear document
spec gate: explicit approval only; append specApproved then planning
handoff: ready exists before Go/Run overnight/Hand off
Go/overnight: executionApproved read-back before Git artifact
abandon: append abandoned + coarse canceled; preserve audit history
```

Also fail on a fourth gate, silence-as-approval, title adoption, in-place update rewrites, or backend branching.

```bash
bash skills/woostack-build/tests/test-linear-build-contract.sh
```

Expected: FAIL because build resolves a backend and owns a document lifecycle.

- [ ] **Step 2 — Green: rewrite the build chain**

Make the main skill call one direct procedure. The procedure discovers required MCP capabilities once, captures repository/workspace/team/identity context, validates lead authority, and follows:

```text
ideate → classify shape → design approval → project/create + designApproved →
specHardened revision(s) → explicit spec approval → specApproved → planning → plan →
verify decomposition → harden → ready → execution handoff → executionApproved on Go/overnight
```

Every event uses stable ID/revision/predecessor/supersession and verified read-back. Hardening adds no gates. Hand off leaves only ready Linear resources. Build creates no branch, worktree, commit, docs-only PR, spec file, plan file, or document.

- [ ] **Step 3 — Verify build behavior**

```bash
bash skills/woostack-build/tests/test-linear-build-contract.sh
bash skills/woostack-build/scripts/tests/test-progressive-disclosure.sh
```

Expected: PASS; exactly three hard gates and no local/backend/document authoring path.

### Task 2: Convert planning to issue reconciliation

**Files:**
- Modify: `skills/woostack-plan/SKILL.md`
- Modify: `skills/woostack-plan/references/plan-template.md`
- Modify: `skills/woostack-tdd/SKILL.md`
- Create: `skills/woostack-build/tests/test-linear-plan-contract.sh`
- Modify: `skills/woostack-build/evals/evals.json`

- [ ] **Step 1 — Red: define normalized issue reconciliation cases**

Cover unique stable increment IDs/ordinals, exact issue descriptions, AC mapping, native `blocked by` relations, one representable Git parent, independent roots, replan identity preservation, evidence-bearing issue removal refusal, cycle/cross-project/ownership drift, and read-back after each mutation. Include a case where ordinals differ from dependency order and must not imply ancestry.

```bash
bash skills/woostack-build/tests/test-linear-plan-contract.sh
```

Expected: FAIL while plan emits Markdown or calls `linear.sh`.

- [ ] **Step 2 — Green: make plan a direct MCP reconciliation procedure**

Accept one verified project ID/URL from build or standalone invocation. Read the valid typed phase chain and existing issues through host MCP. Reconcile exact issue contracts and relations by embedded stable ID; write typed decision/progress updates as needed; verify all mutations; never persist transport input. `planning → ready` is an append-only project event plus coarse native-status reconciliation. Update TDD to accept exact project+issue inputs only; no Markdown spec/plan target remains.

- [ ] **Step 3 — Verify decomposition behavior**

```bash
bash skills/woostack-build/tests/test-linear-plan-contract.sh
bash skills/woostack-build/tests/test-linear-build-contract.sh
```

Expected: PASS for acyclic dependency graphs, stable replan, and fail-closed ambiguity.

### Task 3: Add behavior corpora for project gates and receipts

**Files:**
- Create: `skills/woostack-build/evals/fixtures/project-gates.json`
- Create: `skills/woostack-build/evals/fixtures/project-update-conflict.json`
- Create: `skills/woostack-build/evals/fixtures/project-replan.json`
- Modify: `skills/woostack-build/evals/evals.json`
- Create: `skills/woostack-plan/evals/evals.json`
- Create: `skills/woostack-plan/evals/trigger-evals.json`

- [ ] **Step 1 — Add deterministic fixture assertions**

Assert that a missing predecessor, duplicate revision, multiple phase heads, stale update, unsupported schema, or failed read-back yields `advance: false` and no repository effects. Assert that one bounded issue routes away before project creation.

- [ ] **Step 2 — Run package/eval validation**

```bash
node skills/woostack-eval/scripts/validate.mjs --package skills/woostack-build --repository-root . --json
node skills/woostack-eval/scripts/validate.mjs --package skills/woostack-plan --repository-root . --json
```

Expected: both JSON results have `errors: []`.

**Increment verification:**

```bash
bash skills/woostack-build/tests/test-linear-build-contract.sh
bash skills/woostack-build/tests/test-linear-plan-contract.sh
bash skills/woostack-build/scripts/tests/test-progressive-disclosure.sh
```

Manual: walk Design approval, Spec approval, Hand off, and Go against fixtures; count exactly three user barriers and confirm Go is the first point where implementation Git work is permitted.

## Increment 3: Standalone issue workflows and source-control attribution

> **Branch:** `feature/linear-issue-workflows`
> **Depends on:** Increment 2  
> **Git parent:** `feature/linear-project-lifecycle`

> Makes every one-PR repository mutation attributable to a standalone Linear issue without manufacturing a project.

### Task 1: Convert fix and change to standalone issues

**Files:**
- Modify: `skills/woostack-fix/SKILL.md`
- Modify: `skills/woostack-change/SKILL.md`
- Modify: `skills/woostack-debug/SKILL.md`
- Modify: `skills/woostack-fix/scripts/tests/test-closeout-invariant.sh`
- Modify: `skills/woostack-change/scripts/tests/test-command-surface.sh`
- Modify: `skills/woostack-fix/evals/evals.json`
- Modify: `skills/woostack-fix/evals/fixtures/approved-fix.json`
- Modify: `skills/woostack-change/evals/trigger-evals.json`

- [ ] **Step 1 — Red: pin standalone issue binding**

Test explicit issue reuse, safe create by stable UUID, repository/role verification, no wrapper project, root-cause/approval records for fix, bounded contract before edit for change, owner verification before repository mutation, and terminal evidence. A supplied foreign/project-increment/document identity or incomplete receipt must stop without branch creation.

```bash
bash skills/woostack-fix/scripts/tests/test-closeout-invariant.sh
bash skills/woostack-change/scripts/tests/test-command-surface.sh
```

Expected: FAIL because local fix files and backend-specific references remain.

- [ ] **Step 2 — Green: rewrite issue-first procedures**

Fix records diagnosis, proposed contract, explicit approval, implementation evidence, review, acceptance, and failure/handoff as typed issue comments. Change records its bounded goal/scope/AC before editing and has no extra approval gate. Debug stays read-only until it hands a proven defect to fix; any remediation requires an issue. Both workflows verify type-aware ownership and exact repository attribution before creating a worktree.

- [ ] **Step 3 — Verify standalone behavior**

```bash
bash skills/woostack-fix/scripts/tests/test-closeout-invariant.sh
bash skills/woostack-change/scripts/tests/test-command-surface.sh
```

Expected: PASS; no `.woostack/fixes/` author/read path remains.

### Task 2: Convert bootstrap to project-first greenfield work

**Files:**
- Modify: `skills/woostack-bootstrap/SKILL.md`
- Modify: `skills/woostack-bootstrap/references/bootstrap.md`
- Modify: `skills/woostack-bootstrap/references/development.md`
- Modify: `skills/woostack-bootstrap/evals/trigger-evals.json`
- Create: `skills/woostack-bootstrap/evals/evals.json`

- [ ] **Step 1 — Red: add greenfield authority fixtures**

Pin: design remains artifact-free; approval creates one project and verified `designApproved`; scaffolding starts only after repository attribution/base intent and project receipt exist; a one-file brownfield request is not bootstrap; missing MCP blocks before target-directory creation.

- [ ] **Step 2 — Green: bind bootstrap to the project lifecycle**

Reuse init's capability/config contract, create the managed project after design approval, append the approved architecture/scope event, and pass exact project identity into scaffolding/planning. Keep framework research and version resolution unchanged. Do not create local specs/plans.

- [ ] **Step 3 — Validate bootstrap package**

```bash
node skills/woostack-eval/scripts/validate.mjs --package skills/woostack-bootstrap --repository-root . --json
```

Expected: `errors: []` and behavior corpus includes the no-MCP-before-filesystem guard.

### Task 3: Make commit and PR bodies Linear-only

**Files:**
- Modify: `skills/woostack-commit/SKILL.md`
- Modify: `skills/woostack-commit/references/pr-body.md`
- Modify: `skills/woostack-commit/references/linear-attribution.md`
- Remove: `skills/woostack-commit/references/markdown-attribution.md`
- Remove: `skills/woostack-commit/tests/test-markdown-attribution.sh`
- Replace: `skills/woostack-commit/tests/test-linear-attribution.sh`
- Modify: `skills/woostack-commit/evals/evals.json`

- [ ] **Step 1 — Red: reject non-Linear development commits**

Require exactly one verified `Linear-Issue: TEAM-NUMBER`; require exactly one preceding `Linear-Project: UUID` only for project increments; reject `Spec:`, duplicate/reordered trailers, foreign repository resources, owner drift, wrong branch/base ancestry, and issue/project mismatch before commit/status/comment mutation. Standalone issues must not gain a synthetic project trailer.

```bash
bash skills/woostack-commit/tests/test-linear-attribution.sh
```

Expected: FAIL on current backend-aware attribution.

- [ ] **Step 2 — Green: resolve exact Linear attribution through MCP**

Commit reads the explicit issue/project identities supplied by its caller, verifies them and work ownership through MCP, verifies Git ancestry from relations, writes/updates the PR, independently reads the canonical PR, attaches branch/PR evidence to the issue, and posts a typed implementation evidence comment with read-back. Keep Graphite and GitHub behavior; remove Markdown attribution and backend resolution.

- [ ] **Step 3 — Verify PR contracts**

```bash
bash skills/woostack-commit/tests/test-linear-attribution.sh
bash skills/woostack-commit/tests/test-progressive-disclosure.sh
```

Expected: PASS for standalone and project increment cases; malformed trailers have no subsequent mutation receipt.

**Increment verification:**

```bash
bash skills/woostack-fix/scripts/tests/test-closeout-invariant.sh
bash skills/woostack-change/scripts/tests/test-command-surface.sh
bash skills/woostack-commit/tests/test-linear-attribution.sh
```

Manual: inspect one standalone issue fixture from create/bind through PR evidence; confirm there is no project or local fix record.

## Increment 4: Issue-owned execution, worktrees, overnight reporting, and status

> **Branch:** `feature/linear-execution-tracking`  
> **Depends on:** Increment 3  
> **Git parent:** `feature/linear-issue-workflows`

> Moves execution progress, unattended reports, handoff, and terminal reconciliation into typed Linear comments/updates while Git remains implementation truth.

### Task 1: Rewrite the issue execution controller and worktree contract

**Files:**
- Modify: `skills/woostack-execute/SKILL.md`
- Modify: `skills/woostack-execute/references/controller.md`
- Modify: `skills/woostack-execute/references/inline-driver.md`
- Modify: `skills/woostack-execute/references/subagent-driver.md`
- Modify: `skills/woostack-init/references/worktrees.md`
- Replace: `skills/woostack-execute/tests/test-linear-execute-contract.sh`
- Modify: `skills/woostack-execute/scripts/tests/test-subagent-brief-skill-scope.sh`
- Modify: `skills/woostack-execute/scripts/tests/test-subagent-tier-selection.sh`
- Modify: `skills/woostack-execute/evals/evals.json`
- Modify: `skills/woostack-execute/evals/fixtures/execution-record.json`

- [ ] **Step 1 — Red: pin claim, ownership, relation, and ancestry checks**

Cover lead assignment, type-aware owner resolution, `assignmentAccepted`, `planned → executing → inReview → done`, blocked/unblocked restoration, ownership recheck before edit/push/PR, independent roots, dependency parent ancestry, merge-before-nonparent requirements, handoff, collision, and unknown mutation outcome. A coding worker must receive one issue and must not alter issue contract, allocation, gates, project updates, or terminal acceptance.

```bash
bash skills/woostack-execute/tests/test-linear-execute-contract.sh
bash skills/woostack-execute/scripts/tests/run-tests.sh
```

Expected: FAIL because controller still consumes Markdown plans/adapter-normalized documents.

- [ ] **Step 2 — Green: make issue state the only execution record**

Consume one verified project and its issue DAG, or one standalone issue. Create worktrees from verified base/parent ancestry, using a disposable registry keyed by exact Linear IDs. Post implementation evidence, verification, decision requests, failures, blocks, and handoffs as typed issue comments with read-back. Request `inReview` after PR evidence; never mark `done` without verified merge and acceptance authority. Preserve Red→Green→Refactor and existing inline/subagent mode behavior.

- [ ] **Step 3 — Verify execution controller**

```bash
bash skills/woostack-execute/tests/run-tests.sh
bash skills/woostack-execute/scripts/tests/run-tests.sh
```

Expected: PASS; no local plan/progress write appears in receipts.

### Task 2: Move overnight and sweep records to Linear

**Files:**
- Modify: `skills/woostack-execute-overnight/SKILL.md`
- Remove: `skills/woostack-execute-overnight/references/report-template.md`
- Modify: `skills/woostack-execute-overnight/tests/run-tests.sh`
- Modify: `skills/woostack-execute-overnight/scripts/tests/test-sweep-integrity-contract.sh`
- Modify: `skills/woostack-execute-overnight/evals/evals.json`
- Modify: `skills/woostack-execute-overnight/evals/fixtures/overnight-state.json`
- Modify: `skills/woostack-sweep/SKILL.md`
- Modify: `skills/woostack-sweep/scripts/tests/test-review-receipt-contract.sh`
- Modify: `skills/woostack-sweep/scripts/tests/test-round-verdict-contract.sh`
- Modify: `skills/woostack-sweep/evals/evals.json`

- [ ] **Step 1 — Red: reject local morning/status authority**

Assert unattended results are typed issue comments plus project progress/handoff/blocker updates; a local `.woostack/overnight/` file is neither authored nor accepted as a receipt. Missing worker/review receipt remains blocked. Independent tracks follow Linear relations and stable issue IDs.

- [ ] **Step 2 — Green: post unattended evidence remotely**

Reuse execute's issue cadence. Morning handback is rendered from verified Linear records, not written locally. Sweep appends review results and blockers to the exact issue, preserves bounded rounds/no-progress behavior, and never changes issue contract or lead-owned decisions.

- [ ] **Step 3 — Verify unattended contracts**

```bash
bash skills/woostack-execute-overnight/tests/run-tests.sh
bash skills/woostack-execute-overnight/scripts/tests/run-tests.sh
bash skills/woostack-sweep/scripts/tests/run-tests.sh
```

Expected: PASS; missing receipts cannot produce acceptance or a local authoritative report.

### Task 3: Replace the backend board with MCP-derived status

**Files:**
- Modify: `skills/woostack-status/SKILL.md`
- Modify: `skills/woostack-status/references/conventions.md`
- Remove: `skills/woostack-status/scripts/status.sh`
- Remove: `skills/woostack-status/scripts/lib.sh`
- Remove: `skills/woostack-status/scripts/board-template.html`
- Replace: `skills/woostack-status/scripts/tests/test-status.sh`
- Remove: `skills/woostack-status/scripts/tests/test-html-board.sh`
- Modify: `skills/woostack-status/scripts/tests/run-tests.sh`
- Modify: `skills/woostack-status/evals/evals.json`
- Remove: `skills/woostack-status/evals/fixtures/markdown-state.json`
- Remove: `skills/woostack-status/evals/fixtures/repo/.woostack/specs/cache.md`
- Remove: `skills/woostack-status/evals/fixtures/repo/.woostack/plans/cache.md`
- Modify: `skills/woostack-status/evals/fixtures/linear-state.json`

- [ ] **Step 1 — Red: pin typed-event phase derivation and terminal reconciliation**

Fixture the project phase chain, standalone issues, ownership, dependencies, PR attribution, progress, stale work, blockers, handoff, and next action. Only verified merged PR evidence plus acceptance may move an issue to `done`; only all-done may complete a project. Read-only rendering performs no unrelated mutation. Ambiguous phase chains and Git/Linear mismatch fail closed.

- [ ] **Step 2 — Green: make status a host-MCP workflow**

The skill queries repository-owned projects and standalone issues through discovered MCP tools, parses only managed envelopes, independently queries GitHub PR truth, performs narrowly eligible terminal reconciliation with read-back, and prints a text board. Remove the shell/HTML backend board rather than building a new transport wrapper. Exact Linear IDs and PR trailers join the models.

- [ ] **Step 3 — Verify status behavior**

```bash
bash skills/woostack-status/scripts/tests/run-tests.sh
node skills/woostack-eval/scripts/validate.mjs --package skills/woostack-status --repository-root . --json
```

Expected: fixture contract passes and package validation reports `errors: []`.

**Increment verification:**

```bash
bash skills/woostack-execute/tests/run-tests.sh
bash skills/woostack-execute/scripts/tests/run-tests.sh
bash skills/woostack-execute-overnight/tests/run-tests.sh
bash skills/woostack-sweep/scripts/tests/run-tests.sh
bash skills/woostack-status/scripts/tests/run-tests.sh
```

Manual: render one project with two independent roots and one dependent issue; verify owners, blockers, PRs, phase, and next action come only from Linear+Git evidence.

## Increment 5: Explicit Linear context for review, diagnostics, and read-only utilities

> **Branch:** `feature/linear-context-consumers`  
> **Depends on:** Increment 4  
> **Git parent:** `feature/linear-execution-tracking`

> Converts every context consumer without allowing diagnostic files, GitHub Action payloads, or remote text to become development authority.

### Task 1: Convert explicit read-only utilities

**Files:**
- Modify: `skills/woostack-ask/SKILL.md`
- Modify: `skills/woostack-debug/SKILL.md`
- Modify: `skills/woostack-tdd/SKILL.md`
- Modify: `skills/woostack-visualize/SKILL.md`
- Modify: `skills/woostack-dream/SKILL.md`
- Modify: `skills/woostack-ask/evals/evals.json`
- Modify: `skills/woostack-debug/evals/evals.json`
- Create: `skills/woostack-visualize/evals/evals.json`
- Modify: `skills/woostack-dream/evals/trigger-evals.json`
- Modify: `skills/using-woostack/tests/test-artifact-reader-contract.sh`

- [ ] **Step 1 — Red: reject local discovery and mutation through helpers**

Require an explicit Linear project/issue URL/ID or exact PR attribution; reject local spec/plan/fix discovery and title matching. Query through host MCP only, parse managed fields only, and never mutate from ask/debug/visualize/dream. TDD may edit repository tests only after exact issue+project validation and owner checks.

```bash
bash skills/using-woostack/tests/test-artifact-reader-contract.sh
```

Expected: FAIL on current backend readers and local artifact inputs.

- [ ] **Step 2 — Green: rewrite context resolution**

Cross-link the canonical MCP trust/identity contract. Keep visualization output disposable and memory/wisdom curation local, but make provenance use `linear://project/<uuid>` and `linear://issue/<uuid>` or immutable Git blob/PR sources. No utility invokes a local development adapter.

- [ ] **Step 3 — Verify utility packages**

```bash
bash skills/using-woostack/tests/test-artifact-reader-contract.sh
node skills/woostack-eval/scripts/validate.mjs --package skills/woostack-ask --repository-root . --json
node skills/woostack-eval/scripts/validate.mjs --package skills/woostack-debug --repository-root . --json
node skills/woostack-eval/scripts/validate.mjs --package skills/woostack-visualize --repository-root . --json
```

Expected: all pass with no local development-source lookup.

### Task 2: Bind diagnostic/remediation commands to issues

**Files:**
- Modify: `skills/woostack-audit/SKILL.md`
- Modify: `skills/woostack-qa/SKILL.md`
- Modify: `skills/woostack-respond/SKILL.md`
- Modify: `skills/woostack-respond/references/evidence-contract.md`
- Modify: `skills/woostack-address-comments/SKILL.md`
- Modify: `skills/woostack-audit/evals/evals.json`
- Modify: `skills/woostack-qa/evals/trigger-evals.json`
- Create: `skills/woostack-respond/evals/evals.json`
- Modify: `skills/woostack-address-comments/evals/evals.json`
- Modify: `skills/woostack-address-comments/scripts/tests/test-address-comments-ownership.sh`

- [ ] **Step 1 — Red: distinguish diagnostic evidence from development state**

Pin that audit/QA/respond may write sanitized local reports labeled non-authoritative, but any remediation must bind/create an issue before tracked repository mutation. Address-comments resolves the exact issue from PR trailers, checks work ownership, records findings/resolutions in typed comments, and blocks on attribution drift.

- [ ] **Step 2 — Green: update command boundaries**

Remove local spec/fix handoffs. Reports return evidence plus a proposed issue contract or exact existing issue; they never silently become scope/acceptance authority. Address-comments and any worker handoff carry project/issue IDs and verified owner state.

- [ ] **Step 3 — Verify diagnostic contracts**

```bash
bash skills/woostack-address-comments/scripts/tests/test-address-comments-ownership.sh
bash skills/woostack-respond/scripts/tests/run-tests.sh
bash skills/woostack-audit/scripts/tests/test-audit-smoke.sh
```

Expected: PASS; a report-only run has no Linear mutation, while remediation without an issue is rejected.

### Task 3: Remove custom Linear artifact context from review and CI

**Files:**
- Modify: `skills/woostack-review/SKILL.md`
- Modify: `skills/woostack-review/references/ci.md`
- Modify: `skills/woostack-review/references/commands.md`
- Modify: `skills/woostack-review/prompts/_orchestrator-header.md`
- Modify: `skills/woostack-review/prompts/_worker-header.md`
- Remove: `skills/woostack-review/scripts/resolve-artifact-context.sh`
- Remove: `skills/woostack-review/scripts/tests/test-resolve-artifact-context.sh`
- Remove: `skills/woostack-review/scripts/tests/test-action-artifact-context.sh`
- Modify: `skills/woostack-review/scripts/prefetch.sh`
- Modify: `skills/woostack-review/scripts/tests/test-prefetch-intent.sh`
- Modify: `skills/woostack-review/evals/evals.json`
- Modify: `action.yml`
- Modify: `.github/workflows/reusable-review.yml`

- [ ] **Step 1 — Red: pin local-versus-CI trust behavior**

Local/Hermes review with MCP must resolve exact issue/project attribution, read the current contract, and keep remote text untrusted. The GitHub Action has no host MCP tool channel: remove the `linear-api-key` input and encrypted adapter context path; CI review remains diff-only advisory evidence and must never claim issue acceptance or Linear read-back. Missing local MCP blocks contract-aware acceptance rather than silently equating CI findings with acceptance.

- [ ] **Step 2 — Green: simplify review delivery**

Delete the custom context fetch/decrypt/encrypt path. Local review reads Linear through host MCP before prompt assembly. CI prefetch includes exact trailer strings and labels absent authoritative issue context explicitly; Hermes or a human decision-maker later reconciles CI receipts against Linear. Keep GitHub GraphQL review-thread behavior intact.

- [ ] **Step 3 — Verify review paths independently**

```bash
bash skills/woostack-review/scripts/tests/test-prefetch-intent.sh
bash skills/woostack-review/scripts/tests/test-prefetch-skill-package-ci.sh
bash skills/woostack-review/scripts/tests/test-skills-angle-rubric.sh
```

Expected: local fixture path requires verified Linear context; CI fixture contains no API key/context adapter and is explicitly non-accepting.

**Increment verification:**

```bash
bash skills/using-woostack/tests/test-artifact-reader-contract.sh
bash skills/woostack-respond/scripts/tests/run-tests.sh
bash skills/woostack-address-comments/scripts/tests/test-address-comments-ownership.sh
bash skills/woostack-review/scripts/tests/test-prefetch-intent.sh
bash skills/woostack-review/scripts/tests/test-prefetch-skill-package-ci.sh
```

Manual: compare local MCP-backed review and GitHub Action review receipts; confirm only the former can supply current issue-contract context and neither can self-accept implementation.

## Increment 6: Generic engineer-agent contract and Hermes + OMP adapter

> **Branch:** `feature/engineer-agent-contract`  
> **Depends on:** Increment 5  
> **Git parent:** `feature/linear-context-consumers`

> Adds the reusable authority/identity protocol and its first concrete orchestrator/coder pairing without making Hermes or OMP mandatory.

### Task 1: Author the generic engineer-agent authority contract

**Files:**
- Create: `skills/using-woostack/references/engineer-agents.md`
- Modify: `skills/using-woostack/SKILL.md`
- Modify: `skills/woostack-execute/references/controller.md`
- Modify: `skills/woostack-review/SKILL.md`
- Create: `skills/using-woostack/tests/test-engineer-agent-contract.sh`

- [ ] **Step 1 — Red: pin role and identity invariants**

The structural contract must require one stable `ENGINEER_NAME`, one Linear principal, one decision-maker profile, one isolated coding profile, type-aware assignee/delegate ownership, lead assignment before acceptance, ownership rechecks, relation-aware parallelism, typed handoff, and human escalation. It must reject self-claim, shared concurrent identity/profile/token/session, coding by the decision-maker, default review by the paired coding agent, self-acceptance, and out-of-scope issue/project mutation.

```bash
bash skills/using-woostack/tests/test-engineer-agent-contract.sh
```

Expected: FAIL because no generic authority reference exists.

- [ ] **Step 2 — Green: define lead, issue engineer, and coder boundaries**

Cross-link the canonical lifecycle and receipt contracts. Specify standing authority envelope, deliberate gate events, project-lead/dispatcher allocation, app delegate versus human assignee, assignment acceptance, pre-side-effect rechecks, handoff, collision stop, independent PR review, explicit `/woostack-review` exception, and acceptance ownership. Repeat load-bearing coder prohibitions in execute/review worker contracts.

- [ ] **Step 3 — Verify the generic contract**

```bash
bash skills/using-woostack/tests/test-engineer-agent-contract.sh
bash skills/woostack-execute/tests/test-linear-execute-contract.sh
```

Expected: PASS; another orchestrator/coder pair can satisfy the contract without Hermes/OMP names.

### Task 2: Specialize the contract for isolated Hermes and OMP profiles

**Files:**
- Create: `skills/using-woostack/references/hosts/hermes.md`
- Modify: `skills/using-woostack/references/hosts/omp.md`
- Modify: `skills/woostack-doctor/scripts/checks/omp-agents.sh`
- Modify: `skills/woostack-doctor/scripts/tests/test-omp-agents.sh`
- Modify: `skills/woostack-init/scripts/gen-omp-agents.sh`
- Modify: `skills/woostack-init/scripts/tests/test-gen-omp-agents.sh`
- Modify: `skills/woostack-init/scripts/tests/test-host-references.sh`

- [ ] **Step 1 — Red: assert pair isolation and command shape**

Pin one Hermes profile and one OMP `--profile` per engineer unit, distinct Linear app identity per concurrently active unit, same unit identity shared only across that pair through separate host secret stores, read-only repo/GitHub review credentials in Hermes, implementation Git credentials in OMP, and dispatch via:

```text
omp --profile <engineer> -p --cwd <repo> <prompt>
```

Use `omp --help` as the executable command authority; Hermes setup claims must cite official Hermes MCP/tool/PTY documentation.

- [ ] **Step 2 — Green: document host mechanics and generation**

Add Hermes host setup, capability discovery, OAuth-app/personal-OAuth distinction, PTY dispatch, evidence return, independent review, and fail-closed behavior. Extend OMP scaffold guidance so each generated profile is isolated and never silently falls back to another profile/model role.

- [ ] **Step 3 — Verify host contracts**

```bash
bash skills/woostack-init/scripts/tests/test-host-references.sh
bash skills/woostack-init/scripts/tests/test-gen-omp-agents.sh
bash skills/woostack-doctor/scripts/tests/test-omp-agents.sh
omp --help
```

Expected: tests pass and help output contains `--profile`, `-p`, and `--cwd`.

### Task 3: Add deterministic multi-agent behavior corpora

**Files:**
- Create: `skills/woostack-execute/evals/fixtures/multi-agent-allocation.json`
- Create: `skills/woostack-execute/evals/fixtures/assignment-collision.json`
- Create: `skills/woostack-execute/evals/fixtures/project-lead-escalation.json`
- Create: `skills/woostack-execute/evals/fixtures/engineer-handoff.json`
- Create: `skills/woostack-review/evals/fixtures/hermes-direct-review.json`
- Create: `skills/woostack-review/evals/fixtures/explicit-woostack-review.json`
- Modify: `skills/woostack-execute/evals/evals.json`
- Modify: `skills/woostack-review/evals/evals.json`

- [ ] **Step 1 — Encode observable decisions**

Assert two independent assigned issues may proceed under distinct identities; shared identity, self-claim, ownership change, dependency block, or contract-changing question stops and produces a typed escalation/collision/handoff event. Assert Hermes directly reviews and comments by default; only an explicit `/woostack-review` permits configured reviewer delegation, and Hermes still decides acceptance.

- [ ] **Step 2 — Validate corpora**

```bash
node skills/woostack-eval/scripts/validate.mjs --package skills/woostack-execute --repository-root . --json
node skills/woostack-eval/scripts/validate.mjs --package skills/woostack-review --repository-root . --json
```

Expected: both report `errors: []`.

**Increment verification:**

```bash
bash skills/using-woostack/tests/test-engineer-agent-contract.sh
bash skills/woostack-init/scripts/tests/test-host-references.sh
bash skills/woostack-init/scripts/tests/test-gen-omp-agents.sh
bash skills/woostack-doctor/scripts/tests/test-omp-agents.sh
bash skills/woostack-execute/tests/test-linear-execute-contract.sh
```

Manual: run the prompt contract with two named disposable engineer units; confirm assignment, identity collision, direct review, explicit delegated review, and handoff decisions are unambiguous without running implementation.

## Increment 7: Product positioning, getting started, and authored documentation

> **Branch:** `feature/linear-only-documentation`  
> **Depends on:** Increment 6  
> **Git parent:** `feature/engineer-agent-contract`

> Reframes the public product around Linear-backed multiperson collaboration and publishes the copyable Hermes decision-maker prompt.

### Task 1: Rewrite README and authored site framing

**Files:**
- Modify: `README.md`
- Modify: `AGENTS.md`
- Modify: `site/content/docs/index.mdx`
- Modify: `site/content/docs/getting-started.mdx`
- Modify: `site/content/docs/configuration.mdx`
- Modify: `site/content/docs/concepts.mdx`
- Modify: `site/content/docs/concepts/index.mdx`
- Modify: `site/content/docs/concepts/building-rules.mdx`
- Modify: `site/content/docs/concepts/status-tracking.mdx`
- Modify: `site/content/docs/concepts/workflows.mdx`
- Modify: `site/content/docs/concepts/worktrees.mdx`
- Modify: `site/content/docs/concepts/context-management.mdx`
- Modify: `site/content/docs/concepts/memory.mdx`
- Modify: `site/content/docs/concepts/utilities.mdx`
- Modify: `site/content/docs/harnesses/index.mdx`
- Modify: `site/content/docs/harnesses/omp.mdx`
- Create: `site/content/docs/harnesses/hermes.mdx`
- Create: `site/content/docs/concepts/engineer-agents.mdx`
- Create: `site/scripts/linear-only-docs.test.mjs`

- [ ] **Step 1 — Red: add authored-page consistency checks**

The test scans authored docs (not generated per-skill pages) and fails on: Markdown-default/optional-Linear positioning, backend choice, `artifacts.specPlan`, `LINEAR_API_KEY`, local spec/plan/fix/overnight source-of-truth claims, Linear document lifecycle, or Hermes-as-coder language. It requires the mandatory MCP endpoint, multiperson/project-tracking positioning, standalone issue model, multi-issue project model, memory/diagnostic boundary, generic engineer contract, Hermes page, OMP command, independent Hermes review, and explicit `/woostack-review` exception.

```bash
node --test site/scripts/linear-only-docs.test.mjs
```

Expected: FAIL on current authored pages.

- [ ] **Step 2 — Green: publish one consistent product model**

Rewrite the root/adoption text and every authored page named above. Cross-link canonical skill references instead of duplicating event schemas. Keep the 23-command/26-location count unchanged. Describe local memory/wisdom as reusable knowledge, diagnostics as non-authoritative, Git/GitHub as code/PR truth, and Linear as the only development-record authority.

- [ ] **Step 3 — Verify authored docs**

```bash
node --test site/scripts/linear-only-docs.test.mjs
pnpm -C site test
```

Expected: PASS; generated skill pages remain sourced from `SKILL.md`.

### Task 2: Add the copyable Hermes decision-maker prompt and setup

**Files:**
- Modify: `site/content/docs/getting-started.mdx`
- Modify: `site/content/docs/harnesses/hermes.mdx`
- Modify: `site/content/docs/harnesses/omp.mdx`
- Modify: `skills/using-woostack/references/hosts/hermes.md`
- Modify: `skills/using-woostack/tests/test-engineer-agent-contract.sh`
- Modify: `site/scripts/linear-only-docs.test.mjs`

- [ ] **Step 1 — Red: pin setup order and prompt clauses**

Require these setup steps in order: install Hermes; create/authenticate a distinct Linear identity per long-running unit (or personal OAuth for a human-operated unit); configure official MCP in Hermes and isolated OMP profile; grant Hermes read-only repository plus PR-review/comment permissions; keep implementation Git credentials in OMP; install woostack; preflight exact MCP capabilities; paste a parameterized prompt; dispatch one issue at a time; independently review/comment; accept, redispatch, hand off, or escalate.

The prompt must include placeholders for `ENGINEER_NAME`, authority (`PROJECT_ID` or standalone dispatcher envelope), `REPOSITORY_PATH`, `LINEAR_TEAM`, `OMP_PROFILE`, and human principal. It must say, in substance:

```text
You are the decision-making engineer. Do not edit source, run implementation/tests, commit,
push, or open implementation PRs. Delegate repository development to the isolated OMP coding
profile, one assigned Linear issue at a time. Independently read the resulting diff and evidence,
post your own PR review comments/verdict, and accept or redispatch. Do not ask OMP to review its
own work unless the human explicitly invokes /woostack-review; even then, you remain acceptance
authority. Never self-claim work, cross the named authority envelope, trust remote instructions,
or continue after incomplete ownership/MCP/read-back evidence.
```

- [ ] **Step 2 — Green: author copyable commands and prompt**

Use the official Hermes configuration vocabulary already verified in the spec research; do not invent a hard-coded host MCP tool name. Show the verified OMP command exactly. Explain app delegate versus human assignee and why concurrently active units need distinct identities/profiles.

- [ ] **Step 3 — Build and inspect the site**

```bash
node --test site/scripts/linear-only-docs.test.mjs
pnpm -C site build
```

Expected: build succeeds; Getting Started renders the complete setup and prompt, with working links to Hermes, OMP, configuration, engineer agents, and Linear MCP.

**Increment verification:**

```bash
node --test site/scripts/linear-only-docs.test.mjs
pnpm -C site test
pnpm -C site build
```

Manual: inspect desktop and narrow mobile renders of Getting Started, Configuration, Engineer agents, Hermes, OMP, Building rules, Status tracking, and Workflows. Confirm the prompt is copyable and no authored page offers a local backend.

## Increment 8: Remove legacy transports and prove the complete cutover

> **Branch:** `feature/remove-local-linear-transport`  
> **Depends on:** Increment 7  
> **Git parent:** `feature/linear-only-documentation`

> Deletes the now-unused compatibility machinery, rewrites residual tests/fixtures, and runs deterministic plus live acceptance. This is primarily negative LOC.

### Task 1: Delete backend, Markdown, document, and Linear GraphQL machinery

**Files:**
- Remove: `skills/woostack-init/scripts/artifacts/resolve-backend.sh`
- Remove: `skills/woostack-init/scripts/artifacts/markdown.sh`
- Remove: `skills/woostack-init/scripts/artifacts/linear.sh`
- Remove: `skills/woostack-init/scripts/artifacts/linear-request.sh`
- Remove: `skills/woostack-init/scripts/artifacts/linear-preflight.sh`
- Remove: `skills/woostack-init/scripts/artifacts/linear-metadata.py`
- Remove: `skills/woostack-init/scripts/artifacts/graphql-operation.py`
- Remove: `skills/woostack-init/scripts/artifacts/graphql/document-create.graphql`
- Remove: `skills/woostack-init/scripts/artifacts/graphql/document-list.graphql`
- Remove: `skills/woostack-init/scripts/artifacts/graphql/document-update.graphql`
- Remove: `skills/woostack-init/scripts/artifacts/graphql/identity-document-slug.graphql`
- Remove: `skills/woostack-init/scripts/artifacts/graphql/identity-document.graphql`
- Remove: `skills/woostack-init/scripts/artifacts/graphql/identity-issue-key.graphql`
- Remove: `skills/woostack-init/scripts/artifacts/graphql/identity-issue.graphql`
- Remove: `skills/woostack-init/scripts/artifacts/graphql/identity-project-slug.graphql`
- Remove: `skills/woostack-init/scripts/artifacts/graphql/identity-project.graphql`
- Remove: `skills/woostack-init/scripts/artifacts/graphql/issue-create.graphql`
- Remove: `skills/woostack-init/scripts/artifacts/graphql/issue-list.graphql`
- Remove: `skills/woostack-init/scripts/artifacts/graphql/issue-relations.graphql`
- Remove: `skills/woostack-init/scripts/artifacts/graphql/issue-update.graphql`
- Remove: `skills/woostack-init/scripts/artifacts/graphql/preflight.graphql`
- Remove: `skills/woostack-init/scripts/artifacts/graphql/project-create.graphql`
- Remove: `skills/woostack-init/scripts/artifacts/graphql/project-list.graphql`
- Remove: `skills/woostack-init/scripts/artifacts/graphql/project-update.graphql`
- Remove: `skills/woostack-init/scripts/artifacts/graphql/provenance-document.graphql`
- Remove: `skills/woostack-init/scripts/artifacts/graphql/provenance-issue.graphql`
- Remove: `skills/woostack-init/scripts/artifacts/graphql/relation-create.graphql`
- Remove: `skills/woostack-init/scripts/artifacts/graphql/relation-delete.graphql`
- Remove: `skills/woostack-init/scripts/tests/test-artifact-backends.sh`
- Remove: `skills/woostack-init/scripts/tests/test-linear-transport.sh`
- Remove: `skills/woostack-init/scripts/tests/test-linear-resources.sh`
- Remove: `skills/woostack-init/scripts/tests/test-linear-metadata.sh`

- [ ] **Step 1 — Red: enumerate every legacy caller before deletion**

Extend `test-linear-only-contract.sh` to scan shipped active skill/reference/script/action/site paths and fail on references to removed adapter/resolver paths, local development-record read/write verbs, Linear GraphQL operation files, `LINEAR_API_KEY`, Linear documents, `Spec:` trailers, or backend selection. Maintain an explicit allowlist only for migration/release-history prose and GitHub GraphQL.

```bash
bash skills/woostack-init/scripts/tests/test-linear-only-contract.sh
```

Expected: FAIL with every residual active caller; fix each caller before deleting files.

- [ ] **Step 2 — Green: remove dead machinery and fixtures**

Delete the listed runtime/scripts/documents/tests only after all callers are gone. Update test runners, package links, generated-skill inputs, action inputs, and stale references. Do not delete `action.yml`, `.github/workflows/reusable-review.yml`, memory/wisdom, sanitized respond/audit/QA reports, or GitHub GraphQL review-thread code.

- [ ] **Step 3 — Verify absence without false positives**

```bash
bash skills/woostack-init/scripts/tests/test-linear-only-contract.sh
bash skills/woostack-init/scripts/tests/run-tests.sh
```

Expected: PASS; the allowlisted GitHub GraphQL path remains and every Linear GraphQL/API-key/backend/local-development path is absent.

### Task 2: Reconcile all skill descriptions, evals, and generated pages

**Files:**
- Modify: `skills/using-woostack/SKILL.md`
- Modify: every affected `skills/woostack-*/SKILL.md` named in increments 1–6
- Modify: every affected `skills/woostack-*/evals/evals.json` and `trigger-evals.json`
- Remove: stale Markdown/backend fixtures under affected `skills/*/evals/fixtures/`
- Modify: `skills/woostack-eval/scripts/tests/test-critical-corpora.sh`
- Modify: `skills/woostack-eval/scripts/tests/test-command-surface.sh`
- Modify: `site/scripts/gen-skills.test.mjs`

- [ ] **Step 1 — Red: make the corpus prove the product contract**

Add critical behavior checks for MCP capability preflight, ownership/identity resolution, verified mutation receipts, idempotent retry, standalone lifecycle, project/increment lifecycle, three build gates, migration classifications/partial failure, multi-agent allocation/collision/escalation/handoff, direct Hermes review, explicit `/woostack-review`, relation-aware ancestry, PR attribution, and status reconciliation. Remove backend-comparison and Markdown artifact expectations.

- [ ] **Step 2 — Green: update descriptions and corpora in lockstep**

Keep descriptions concise and discovery-oriented. Preserve all 26 fixed `SKILL.md` paths and the 23-command adoption count. Generated per-skill pages remain uncommitted outputs from those sources.

- [ ] **Step 3 — Validate every changed package and command surface**

```bash
bash skills/woostack-eval/scripts/tests/run-tests.sh
bash skills/woostack-review/scripts/tests/test-skills-angle-rubric.sh
node --test site/scripts/gen-skills.test.mjs
```

Expected: PASS with Linear-only critical corpora and unchanged public command count.

### Task 3: Run deterministic full-story verification

**Files:**
- Modify only if a verified failure exposes a real contract defect in files already owned by this plan.

- [ ] **Step 1 — Run all affected shell suites once**

```bash
bash skills/woostack-init/scripts/tests/run-tests.sh
bash skills/woostack-doctor/scripts/tests/run-tests.sh
bash skills/woostack-build/tests/test-linear-build-contract.sh
bash skills/woostack-build/tests/test-linear-plan-contract.sh
bash skills/woostack-execute/tests/run-tests.sh
bash skills/woostack-execute/scripts/tests/run-tests.sh
bash skills/woostack-execute-overnight/tests/run-tests.sh
bash skills/woostack-execute-overnight/scripts/tests/run-tests.sh
bash skills/woostack-commit/tests/test-linear-attribution.sh
bash skills/woostack-status/scripts/tests/run-tests.sh
bash skills/woostack-review/scripts/tests/test-prefetch-intent.sh
bash skills/woostack-review/scripts/tests/test-prefetch-skill-package-ci.sh
bash skills/woostack-address-comments/scripts/tests/test-address-comments-ownership.sh
bash skills/woostack-respond/scripts/tests/run-tests.sh
bash skills/woostack-sweep/scripts/tests/run-tests.sh
bash skills/using-woostack/tests/test-artifact-reader-contract.sh
bash skills/using-woostack/tests/test-engineer-agent-contract.sh
```

Expected: every suite exits 0; failure output identifies a real remaining dual-authority, receipt, lifecycle, ownership, or attribution defect.

- [ ] **Step 2 — Validate and build documentation**

```bash
pnpm -C site test
pnpm -C site build
```

Expected: generated skill pages and authored Linear-only pages build successfully.

- [ ] **Step 3 — Inspect the final shipped surface**

Run the structural contract after generation and confirm these result classes are empty: backend selector/resolver, active local spec/plan/fix/overnight authority, `LINEAR_API_KEY`, Linear GraphQL transport, Linear documents, `Spec:` PR trailers, and stale adapter references. Confirm the allowlisted GitHub GraphQL review-thread operations, reusable memory/wisdom, non-authoritative diagnostics, `action.yml`, and reusable review workflow remain.

### Task 4: Perform the live single-identity Linear MCP acceptance run

**Files:**
- No repository fixture or credential file is created; record only sanitized issue/project URLs and receipt summaries in the implementation PR test plan and the disposable Linear resources themselves.

- [ ] **Step 1 — Preflight official MCP**

In an authenticated host session, discover exact tools and verify workspace/team/repository, project/issue read-create-update, project updates, issue comments, native states, relations, assignment/delegation fields available to that identity, and independent reads. Stop truthfully at the first missing capability.

- [ ] **Step 2 — Exercise disposable standalone and project flows**

Using unique stable UUID markers, create one standalone work item and one project with two related increment issues. Exercise typed updates/comments, state changes, relation creation/read-back, assignment or delegation supported by the authenticated identity, unknown-outcome discovery/idempotent retry, and explicit final read-back. Never use a local fallback.

- [ ] **Step 3 — Verify cleanup**

Cancel/archive the disposable project and issues using supported MCP operations, then independently read them back and record the sanitized receipts. If cleanup outcome is unknown, report the exact resource URLs and do not claim cleanup.

Expected: AC12 happy path is observed with one identity. Multi-identity delegate/assignee and collision behavior remains deterministic fixture evidence, not a fabricated live claim.

**Increment verification:** all deterministic suites, site build, structural absence scan, and the truthful live acceptance receipt above.

## Acceptance coverage matrix

| Spec AC | Primary increment(s) | Proof |
| --- | --- | --- |
| AC1 mandatory MCP | 1, 2, 3, 5, 8 | committed/local config precedence tests, doctor structural tests, workflow capability fixtures, live preflight |
| AC2 only projects/updates/issues/comments | 1–4, 8 | canonical schema, build/plan/standalone fixtures, absence scan |
| AC3 verified receipts | 1–6, 8 | receipt fixtures per mutating workflow and live read-back |
| AC4 no local development authority | 1, 4, 5, 8 | migration blockers, no-local-output tests, final absence scan |
| AC5 loss-safe active migration | 1, 8 | classification/partial fixtures and zero-deletion assertions |
| AC6 workflow gates | 2, 3 | build gate contracts, fix/change/bootstrap fixtures |
| AC7 multiperson safety | 4, 6 | ownership, collision, relation, handoff fixtures |
| AC8 Linear-only attribution/status | 3, 4, 5 | commit/status/review contracts |
| AC9 transport/credential removal | 1, 5, 8 | structural rejection, CI simplification, deleted adapter corpus |
| AC10 engineer agent + Hermes/OMP | 6, 7 | role contract, host tests, copyable prompt/docs |
| AC11 docs consistency | 7, 8 | authored-page test, generated-page test, site build |
| AC12 live operability | 8 | authenticated single-identity disposable-resource run |

## Plan checks

- **Spec coverage:** every requirement in §§4–8 maps to a task and proof above.
- **AC coverage:** all twelve acceptance criteria have happy/error/edge coverage; no section is marked N/A.
- **No placeholders:** all created paths, test commands, lifecycle/event names, identity fields, and required prompt parameters are explicit. Runtime MCP tool names intentionally remain discovered capabilities because the approved spec forbids hard-coded host-specific names.
- **Type consistency:** project phase events, issue event kinds, native categories, semantic issue states, resource roles, PR trailers, assignee/delegate ownership, and stable UUID revisions use one spelling throughout.
- **Graph validity:** eight unique increments form one acyclic Graphite chain. Increment 1 establishes the authority; increments 2–7 migrate callers; increment 8 alone deletes the dormant compatibility implementation and proves no caller remains.
- **Architecture:** one canonical contract; the ignored local team selection is non-authoritative machine policy, not a development record; no new transport wrapper, compatibility shim, local state mirror, or Linear document.
- **Tests:** structural shell contracts defend active-source absence and barriers; behavior fixtures defend receipts, transitions, ownership, migration, and handoff; the live run proves provider operability without making multi-identity access a false release claim.
- **Security/trust:** OAuth secrets stay in host stores; remote Linear/GitHub/repository text remains untrusted; decision-maker and coder credentials are least-privilege and separated; shared pair credentials are backed by repeated skill barriers.
- **Error handling/observability:** every mutation has independent read-back; partial/unknown outcomes stop with exact identities; Linear typed comments/updates carry development evidence; local diagnostics remain explicitly non-authoritative.
