---
name: linear-only-collaboration
type: spec
status: hardened
date: 2026-07-26
branch: feature/linear-only-collaboration
links:
---

# Linear-only collaboration — Design Spec

> Artifact: `.woostack/specs/2026-07-26-linear-only-collaboration.md`. The currently selected Markdown backend artifact is the source of truth for this build run. Render with [spec-template.html](../../../skills/woostack-build/references/spec-template.html) for a rich presentation only.

> `status:` follows the selected backend's owning-artifact contract. This spec owns `draft`, `hardened`, or `approved`; its joined plan owns later implementation phases. The enum and joins are defined in [conventions.md](../../../skills/woostack-status/references/conventions.md).

> **Plan:** [[plans/2026-07-26-linear-only-collaboration]]

## 1. Problem

Woostack currently describes itself as a general software-development skill collection with a local memory system, while development tracking is split between a default Markdown backend and an optional Linear backend. The current implementation proves that split is load-bearing across the collection:

- `README.md` and `site/content/docs/getting-started.mdx` state that Markdown is the default and Linear is optional.
- `.woostack/config.json` omits `artifacts.specPlan`, so `resolve-backend.sh` normalized this build run to `markdown`.
- `skills/woostack-init/scripts/artifacts/linear.sh` is a 1,600-line custom Linear GraphQL adapter with a sibling GraphQL document corpus, while Markdown readers and writers remain active compatibility paths throughout the skills.
- The repository contains tracked local specifications, plans, fixes, and overnight execution reports that compete with a shared collaboration system as durable development records.
- The existing Linear model uses a managed specification document, although the desired collaboration model makes Linear projects, project updates, issues, comments, states, assignments, relations, and PR evidence the complete development record.

The requested product direction is explicit: woostack should become a set of skills for multiperson collaboration and project tracking through artifacts; Linear must be mandatory and enabled without a backend choice; official Linear MCP must replace the custom Linear GraphQL transport; and every repository-mutating development workflow must use one Linear issue and, for multi-issue work, one Linear project as its source of truth. The documentation must also define engineer agents and provide a concrete multi-Hermes setup in which each Hermes instance makes decisions but delegates all repository development to a separate OMP coding-agent session.

Official Linear documentation confirms that the hosted read-write MCP endpoint is `https://mcp.linear.app/mcp`, uses OAuth 2.1 or bearer authentication, and exposes tools for finding, creating, and updating Linear objects. Its agent identity model uses OAuth `actor=app` plus `app:assignable`/`app:mentionable`; an assigned app is an issue delegate rather than the human assignee. Official Hermes documentation confirms a reviewed Linear MCP catalog entry, OAuth-authenticated remote MCP support, terminal PTY execution, and per-server tool selection. The installed OMP CLI confirms isolated profiles and non-interactive delegation through `omp --profile <name> -p --cwd <repo> <message>`.

## 2. Goal

Make Linear the mandatory shared coordination and project-tracking plane for all development performed through woostack.

After the cutover:

1. Every repository-mutating development workflow is attributable to one exact Linear issue.
2. Multi-PR work uses one dedicated Linear project, project updates for approved decisions and progress, and one dependency-aware issue per independently shippable increment.
3. Single-PR fixes and bounded changes use standalone Linear issues without creating one-issue projects.
4. Skills use the host's authenticated official Linear MCP tools directly and require verified read-back after every mutation.
5. No local specification, plan, fix, progress, or overnight execution record can become authoritative.
6. Multiple human or agent engineers can receive verified assignments, execute, hand off, and review independent issues without hidden local state.
7. A generic engineer-agent contract separates decision ownership from coding, with Hermes + OMP documented as the first concrete adapter.

## 3. Non-goals

- Building or shipping a custom woostack MCP server or proxy.
- Retaining Markdown or custom GraphQL as a fallback, compatibility backend, or migration-time transport.
- Importing completed historical development records into Linear; Git history remains their archive.
- Removing reusable local `.woostack/memory/` or `.woostack/wisdom/` knowledge.
- Removing transient or non-authoritative diagnostic outputs such as audit, QA, or production-response evidence when those commands still need them.
- Replacing GitHub/Graphite as the source of truth for commits, branches, pull requests, reviews, or merge evidence.
- Removing GitHub GraphQL used for GitHub review-thread operations; the transport removal is Linear-specific.
- Turning Hermes into a coding agent or coupling the generic engineer-agent contract to Hermes alone.
- Auto-migrating or deleting legacy records without explicit migration and complete Linear read-back receipts.

## 4. Approach

### 4.1 Clean Linear MCP cutover

Remove `artifacts.specPlan`, the backend resolver, both backend branches, the Markdown development-record adapter, the custom Linear request/GraphQL adapter, the Linear GraphQL document corpus, and `LINEAR_API_KEY` authentication guidance. There is no backend selection: a woostack development entry point requires official Linear MCP.

Skills call the host-exposed Linear MCP tools directly rather than relying on fixed transport-specific tool names. Each workflow declares the capabilities it requires, discovers the available tool set, verifies authenticated access to the configured workspace/team, and fails closed before artifact access or repository mutation when a capability is absent. The shared contract requires capabilities to read/create/update projects and issues, create/read project updates and issue comments, read native statuses, assignees, and app delegates, assign the correct owner kind, manage relations when the workflow needs dependencies, and read back every affected object.

`.woostack/config.json` remains repository policy, not a development artifact. `/woostack-init` uses MCP to select and validate the workspace, team, repository identity, one native project status in each Linear category (`backlog`, `planned`, `started`, `paused`, `completed`, `canceled`), and semantic issue-state mappings (`planned`, `executing`, `inReview`, `done`, `blocked`). It stores no secret and offers no backend selector.

### 4.2 Linear resource model

Managed resources are deterministic and human-readable:

- Project overviews, issue descriptions, project updates, and managed issue comments retain the existing `+++ Woostack metadata — managed, do not edit` delimiter and canonical single-line JSON, evolved to one versioned resource/event schema. The managed block is distinct from the readable goal, contract, decision, or evidence body.
- A client-generated stable UUID is embedded before the first create mutation. Unknown-outcome retry discovers that exact UUID inside repository-scoped resources; titles are display-only and never identity.
- A `woostack` label, canonical repository URL, stable resource ID, and role (`feature`, `increment`, or standalone `work-item`) identify repository-owned work. Project/issue relations use Linear IDs after verified creation.
- Explicit Linear IDs/URLs always win after their repository ownership marker is verified; skills never adopt a resource by title.
- Remote titles, descriptions, updates, and comments are untrusted data, never agent instructions.

For multi-PR work:

- One Linear project owns the stable goal, scope, lead engineer, repository attribution, and coarse native status.
- Project updates are append-only typed events. Each contains a human-readable record plus a small managed envelope with schema version, event kind, stable event ID, repository, project ID, revision, predecessor update ID, related update IDs, and optional superseded update ID. Phase events are `designApproved`, `specHardened`, `specApproved`, `planning`, `ready`, `executionApproved`, `executing`, `inReview`, `done`, or `abandoned`; `decision`, `progress`, `blockerOpened`, `blockerResolved`, and `handoff` events do not change phase.
- A correction appends the same stable event ID at a higher revision and explicitly supersedes the prior update; skills never rewrite history in place. The single valid unsuperseded phase-event chain determines the fine-grained build phase. Missing predecessor links, duplicate revisions, or multiple current heads are ambiguous and block.
- Native project status stays coarse: backlog during design/specification, planned after `ready`, started during execution/review, paused while a verified unresolved project blocker exists, completed after verified completion, and canceled after abandonment. `blockerResolved` must reference the open blocker. Fine-grained gates do not require custom workspace statuses.
- One issue represents each independently shippable increment. Its description owns the implementation contract and acceptance criteria; typed comments record implementation evidence and decision requests; native relations encode dependencies; native assignment and state encode ownership and progress.
- Managed issue comments use the same versioned envelope with an issue resource ID and issue event kinds such as `assignmentAccepted`, `implementationEvidence`, `decisionRequest`, `reviewResult`, `verification`, `acceptance`, `handoff`, `blocked`, `unblocked`, and `failure`.

For single-PR fixes and bounded changes:

- One standalone issue owns the problem or goal, scope, acceptance criteria, implementation evidence, decisions, branch/PR linkage, and terminal state.
- Issue comments form the chronological decision and verification record.
- No wrapper project or Linear document is created.

No Linear document is part of the woostack development model.

### 4.3 Workflow lifecycle

`woostack-build` retains exactly three hard gates and is only for work expected to require multiple independently shippable increments. Ideation classifies the shape before any Linear artifact exists; bounded one-PR work routes to `woostack-change` instead of creating a wrapper project.

1. Ideate without a stored artifact. Explicit design approval permits project creation and a verified `designApproved` project-update event.
2. Harden the written specification into a verified `specHardened` revision. Explicit specification approval appends `specApproved`, then `planning`, and permits issue planning.
3. Reconcile and harden dependency-aware increment issues, append `ready`, and stop for explicit `Go`, `Run overnight`, or `Hand off`; Go/overnight appends `executionApproved` before implementation.

The valid project phase path is `designApproved → specHardened → specApproved → planning → ready → executionApproved → executing → inReview → done`. A deliberate evidence-free replan may move `ready → planning`; any active phase may explicitly become `abandoned`; `done` and `abandoned` are terminal. Retry discovers the existing stable event instead of appending a same-phase duplicate. Increment issue state follows `planned → executing → inReview → done`, with explicit blocked/unblocked transitions that restore the immediately preceding non-terminal state.

`woostack-fix` binds or creates a standalone issue before repository mutation. Root cause, fix contract, approval, verification, and review evidence are written to the issue. `woostack-change` binds or creates a standalone issue and records its bounded contract before editing. `woostack-bootstrap` creates a project after design approval and before scaffolding. `woostack-plan` reconciles issues and relations rather than writing a local plan. Execute drivers consume Linear project/issue identities, update issue/project state and comments, and write unattended reports back to Linear instead of `.woostack/overnight/`.

All implementation PRs end with exactly one `Linear-Issue:` trailer. Project increments also include `Linear-Project:`. `Spec:` trailers and docs-only spec/plan PRs are removed. `/woostack-status` reads Linear MCP only, derives the fine-grained phase from the verified typed-event chain plus issue/PR truth, and reconciles coarse project and terminal issue states only from verified repository PR evidence.

Read-only and diagnostic commands may keep scoped non-authoritative local reports, and Git worktree administration may keep a disposable registry derived from Git plus exact Linear IDs. Those files never determine scope, assignment, dependencies, phase, approval, or acceptance. Every handoff that will mutate tracked repository content must bind or create a Linear issue first; artifact consumers must not discover or read local development records outside the explicit one-time migration path.

### 4.4 Verified mutations and errors

Every MCP mutation is followed by an independent read of the affected object. A valid receipt verifies the expected identity, workspace/team, repository attribution, role, managed event envelope or content revision, native state, resolved work owner, and relevant relations. Missing, partial, ambiguous, foreign, stale, or conflicting results stop the workflow. There is no empty-success interpretation and no filesystem, GraphQL, or alternate-backend fallback.

### 4.5 Multiperson and multi-agent ownership

An engineer unit is exactly one decision-making Hermes profile, one isolated OMP coding profile, one stable `ENGINEER_NAME`, and one Linear principal:

- A long-running unit has its own Linear OAuth app identity (`actor=app`, `app:assignable`, and `app:mentionable`) exposed through official Linear MCP. Its Hermes and OMP profiles intentionally share that unit credential through separate host secret stores. Two engineer units may not share or clone an app identity, Hermes profile, OMP profile, token, or active session.
- A human-operated unit may instead use the human's personal OAuth identity. Linear ownership is type-aware: an app unit is the verified issue delegate while a human remains assignee of record; a human unit is the verified assignee. The contract calls the applicable field the work owner and never compares an app identity to the assignee field.

Authority is explicit and hierarchical:

| Role | Owns | Cannot do |
|---|---|---|
| Project-lead Hermes (or human lead) | Project scope, all three build gates, project updates, issue contracts and relations, priority, allocation/reassignment, cross-issue decisions, final project acceptance, and independent read-only PR/code review inside its delegation envelope | Modify source, run implementation, tests, commits, pushes, or create implementation PRs |
| Assigned issue-engineer Hermes | Implementation decisions inside the assigned issue's existing contract; directing its paired OMP; independently reading code and PR diffs, verification evidence, and relevant repository context; posting PR review comments/verdicts; and accepting or rejecting evidence for review | Change project scope/updates/gates, issue acceptance criteria or dependencies, allocation, or another issue; cross-boundary decisions go to the lead |
| Paired OMP coding agent | Repository analysis, edits, verification, commit, push, and PR creation for exactly one assigned issue; posting implementation evidence and requesting `inReview` | Make product/scope decisions, edit project updates or issue contracts, assign/reassign work, clear gates, act as the default code reviewer, accept its own work, or mark terminal success |

The project records exactly one lead; a repository dispatcher has the equivalent allocation role for standalone issues. Standing authority exists only when the setup prompt names the repository/project envelope. Every gate or consequential decision still requires a deliberate typed Linear event; silence is never a decision. Anything outside the envelope escalates to the human principal.

Allocation and concurrency use one protocol:

- Engineers never self-claim unassigned work. The lead/dispatcher deliberately assigns an unblocked issue to the correct assignee or delegate field; an issue engineer accepts by verifying the resolved work owner, moving it to `executing`, posting `assignmentAccepted` with stable engineer/run identity, and reading it back. A lead may allocate an issue to its own engineer unit, but it follows the same visible assign-then-accept sequence.
- Work ownership is rechecked before repository mutation, push, and PR submission. Missing, changed, or conflicting ownership stops work and records the collision.
- Parallel work is limited to dependency-independent assigned issues and isolated worktrees. Linear relations, not ordinal adjacency, define allowed concurrency and Git ancestry.
- Handoff posts current evidence and next action, changes the assignee/delegate through the lead/dispatcher, and verifies the new work owner before another unit resumes.

### 4.6 Engineer-agent boundary and Hermes adapter

The reusable engineer-agent reference encodes the table and protocol above. The issue-engineer Hermes may decide any implementation question that stays inside the issue contract; it records the decision in a typed issue comment before redispatch. Cross-issue or contract-changing questions go to the project lead, and out-of-envelope questions go to the human principal.

OMP receives one exact Linear issue, one repository/worktree, explicit acceptance criteria, one woostack command, and the invoking unit's Linear MCP identity. It may read that issue, post implementation evidence, attach its branch/PR, and request `inReview`; it returns either evidence or an explicit decision request. The coding-mode skill barriers and contract tests repeat these restrictions because the shared pair credential cannot enforce them by OAuth scope.

Code review has a separate default path:

- Hermes reviews independently. It reads the Linear contract, PR metadata and diff, relevant source context, and returned verification evidence using its own read-only repository/GitHub access, then posts its own GitHub review comments or verdict and mirrors a typed `reviewResult` summary to Linear with verified read-back.
- OMP's implementation verification and self-check are evidence, not independent review. Hermes does not ask its paired OMP coding session to review that session's work and does not treat an OMP self-review as acceptance.
- Only an explicit `/woostack-review` invocation may delegate review execution to the reviewers selected by that skill. Hermes remains the decision-maker: it verifies the review receipts, resolves findings against the issue contract, comments on the PR, and decides acceptance or redispatch.

The authored getting-started documentation adds a concrete Hermes + OMP path:

1. Install/configure one isolated Hermes profile per engineer unit.
2. For a long-running autonomous unit, create and admin-install a distinct Linear OAuth app with `actor=app`, `app:assignable`, and `app:mentionable`; a human-operated unit may use Hermes' reviewed Linear MCP catalog entry with personal OAuth.
3. Configure `https://mcp.linear.app/mcp` in Hermes and an isolated OMP `--profile` with the same unit identity. Keep the OAuth/app token only in each host's secret store or environment; never in repository config, prompts, logs, or generated files.
4. Configure Hermes with read-only repository access plus GitHub PR-read and review-comment permissions. Keep push/source-write credentials out of the Hermes profile; OMP owns implementation Git credentials.
5. Install woostack in the coding environment and verify the exact Linear read/write, project-update, comment, status, relation, assignee/delegate, and read-back capabilities before delegation.
6. Apply a copyable prompt parameterized by engineer name, project authority, repository path, Linear team, and explicit delegation envelope. It grants independent code/PR review, forbids repository modification, forbids default review delegation to OMP, permits delegated review only for explicit `/woostack-review`, and names decisions that require human escalation.
7. Have Hermes dispatch one issue at a time to OMP through PTY or `omp --profile <engineer> -p --cwd <repo> <prompt>`, independently review the returned PR, post comments/decisions, and dispatch fixes or the next unblocked issue.

### 4.7 Active-only migration

The new initialization/doctor path detects legacy `.woostack/specs/`, `.woostack/plans/`, `.woostack/fixes/`, and `.woostack/overnight/` development records and blocks new development until migration is resolved.

An explicit one-way migration:

1. Classifies each record from canonical authored lifecycle plus verified PR merge/close evidence: non-terminal work is active; terminal work with matching evidence is historical; malformed, contradictory, or evidence-incomplete work is ambiguous and blocks for explicit classification.
2. Presents the exact active set, historical set, ambiguities, and proposed project/issue/update mapping.
3. Creates or resumes repository-owned Linear resources through MCP using stable identities recorded in verified migration events, never title matching.
4. Verifies every project, issue, update, comment, state, and relation.
5. Rewrites preserved memory/wisdom provenance that points at development files: active sources become stable Linear resource URIs; historical sources become immutable Git blob/PR provenance. Body links, hooks, and scopes that name removed development paths are either rewritten to the new authority or explicitly curated as obsolete.
6. Verifies that every historical file is recoverable from the recorded Git object and that every preserved knowledge link resolves.
7. Deletes all local development records only after the entire migration—including remote receipts and knowledge-provenance repair—passes. No per-file early deletion is allowed.

Historical records are not imported into Linear; Git remains their archive. The migration is resumable after partial MCP success and never treats partial remote success as permission to delete or rewrite local data. The current build run remains on its already-resolved Markdown backend until its execution handoff; cutover migration occurs after the feature lands, never by mixing artifact backends mid-run.

## 5. Components & data flow

### 5.1 Shared policy and lifecycle authorities

Canonical references define one Linear-only resource schema, trust boundary, capability preflight, verified receipt, project/issue lifecycle, PR attribution, worktree ancestry, ownership, and migration contract. Related skills cross-link these authorities rather than restating transport or lifecycle details.

### 5.2 Initialization and doctor

`woostack-init` discovers the official Linear MCP connection, workspace/team, native states, and non-secret repository policy. `woostack-doctor` performs static config checks by default and an explicit live MCP check when requested. Legacy development records produce a blocking migration diagnosis, not compatibility behavior.

### 5.3 Development controllers

Build, fix, change, bootstrap, plan, execute, execute-overnight, commit, status, sweep, address-comments, debug, ask, review, audit, QA, respond, dream, and TDD are updated according to whether they create, mutate, or only consume development context. Mutating skills use verified MCP receipts. Read-only skills query only an explicit or deterministically attributed Linear identity and never mutate through a helper.

### 5.4 Source control

Linear identifies the work; Git/Graphite implements it. Root branches begin at verified repository base state; dependent branches follow declared issue relations. PR trailers join each implementation PR to its exact Linear issue and optional project. GitHub merge evidence is independently read before terminal reconciliation.

### 5.5 Engineer agents

The generic contract governs identity, authority, allocation, coding delegation, independent decision-maker review, explicit `/woostack-review` delegation, assignment conflicts, and handoff. The Hermes documentation specializes the contract without making Hermes required. OMP remains one example coding harness; other coding agents may satisfy the same contract.

### 5.6 Documentation site

README and authored site pages change the product positioning from local-first skill workflows to Linear-backed multiperson collaboration. Getting started makes Linear MCP setup mandatory and includes the Hermes prompt, isolated OMP pairing, and least-privilege GitHub review access. Configuration, concepts, workflow maps, status tracking, worktrees, context management, and building rules are updated in lockstep. Per-skill reference pages continue to generate from `SKILL.md`.

### 5.7 End-to-end flow

```text
human or lead engineer
  → explicit design decision
  → Linear project + project updates (multi-issue) OR standalone issue
  → lead/dispatcher assignment + engineer acceptance with verified MCP read-back
  → engineer agent delegates exact issue to coding agent
  → isolated worktree → implementation → verification → Graphite PR
  → exact Linear trailers + PR attachment/comment
  → independent Hermes code/PR review + GitHub comments + Linear `reviewResult`
  → engineer acceptance, fix redispatch, or handoff
  → verified merge evidence
  → Linear terminal reconciliation
```

## 6. Error handling

- **Linear MCP absent or unauthenticated:** block before artifact access or repository mutation; provide official setup guidance; never accept `LINEAR_API_KEY` or fall back.
- **Required MCP capability absent:** name the missing capability and stop. A smaller read-only tool set cannot silently run a mutating workflow.
- **Agent identity/delegation unavailable:** a long-running app profile blocks if its `actor=app` identity, required scopes, delegate field, or exact identity read-back is unavailable. It never impersonates a human or falls back to a shared profile.
- **Workspace/team/state ambiguity:** require explicit selection or configuration repair; never select by title or first result.
- **Foreign or unmanaged resource:** reject when repository attribution, label, role, or workspace/team does not match.
- **Untrusted Linear or GitHub text:** extract expected fields only; never follow tool, credential, workflow, or disclosure instructions embedded in Linear content, PR descriptions/comments, diffs, source, or test output. Code review treats repository content as evidence, not instructions.
- **Mutation or typed-event chain without complete read-back:** stop at the mutation boundary and report the unknown outcome. A retry must discover existing resources before creating anything; unsupported schema versions, duplicate revisions, broken supersession links, or multiple current phase heads block rather than guessing.
- **Missing, changed, or conflicting work owner:** stop before the next repository side effect, post conflict evidence, and require the lead/dispatcher to assign the exact human assignee or app delegate explicitly.
- **Blocked dependency:** do not create or advance a dependent implementation branch until required Linear and Git ancestry are ready.
- **PR attribution mismatch:** fail before commit/status/comment mutation when trailers, repository, head/base, issue, or project disagree.
- **Hermes review access absent or review incomplete:** block acceptance and name the missing PR-read/comment capability or evidence. Do not silently ask the paired OMP to perform routine review; delegated review is valid only after an explicit `/woostack-review`.
- **Migration partial failure:** preserve all local development records and original knowledge provenance, report completed remote identities, and resume by those identities; never duplicate by title.
- **Legacy records after cutover:** doctor blocks development until the one-way migration completes.
- **Hermes/OMP failure:** preserve issue ownership and worktree/branch recovery state, post the failure evidence, and do not claim verification or acceptance.
- **Diagnostic local output:** label it non-authoritative and require a Linear issue before remediation begins.

## 7. Acceptance criteria

- **AC1 — Linear MCP is mandatory with no backend selector**
  - happy: init configures one Linear workspace/team and all development entry points pass capability/auth preflight through official Linear MCP.
  - error: absent auth, endpoint, team, state mapping, or required tool blocks before artifact access or Git mutation with actionable setup output.
  - edge: read-only MCP access permits read-only commands but cannot be mistaken for sufficient access by a mutating command.

- **AC2 — Projects, updates, issues, and comments are the only development artifacts**
  - happy: multi-PR work creates one project, decision/progress updates, and dependency-aware increment issues; single-PR work creates one standalone issue.
  - error: duplicate, foreign, ambiguous, or document-backed resources fail closed.
  - edge: ideation routes a bounded one-PR request to `woostack-change` before design approval or any project creation; build never creates a one-issue wrapper project.

- **AC3 — Every development mutation has a verified MCP receipt**
  - happy: create/update/transition/assign-or-delegate/relation operations independently read back all required identity, resolved work owner, content, state, and relation fields.
  - error: missing, partial, stale, conflicting, or malformed typed-event read-back stops the next step and reports an unknown outcome.
  - edge: retry discovers the prior successful mutation by its embedded stable UUID and remains idempotent rather than duplicating it.

- **AC4 — No local development-record authority remains**
  - happy: no active skill authors or consumes local specs, plans, fixes, progress, or overnight execution reports after migration.
  - error: doctor blocks when legacy records remain and no migration receipt authorizes deletion.
  - edge: reusable memory/wisdom and explicitly non-authoritative diagnostic outputs continue to work without being treated as development state.

- **AC5 — Active-only migration is loss-safe**
  - happy: active local features/fixes migrate to verified Linear resources; historical records remain in Git; knowledge provenance is repaired; local development records are deleted only after the whole migration passes.
  - error: any MCP, Git-recovery, evidence, or knowledge-link failure leaves every local record and original provenance intact and reports resumable remote identities.
  - edge: interrupted reruns resume exact resources by embedded stable UUID and never import completed history or duplicate by title.

- **AC6 — Build, fix, change, and bootstrap preserve their workflow gates while using Linear**
  - happy: build keeps design, written-spec, and execution-handoff gates; fix keeps diagnosis/approval discipline; change remains bounded; bootstrap records its approved project before code.
  - error: silence, ambiguous authority or approval, an out-of-scope agent decision, failed update receipt, or unsupported lifecycle transition cannot advance work.
  - edge: an authorized Hermes lead may explicitly clear all three build gates through typed events; `Hand off` leaves ready Linear artifacts with no implementation branch or PR.

- **AC7 — Multiple engineers coordinate safely**
  - happy: a lead/dispatcher assigns dependency-independent issues to distinct Linear work owners; app engineers verify their delegate field, human engineers verify their assignee field, and both work in isolated worktrees and hand off through verified reassignment.
  - error: shared app/profile/token identity, unassigned work, changed ownership, assignment collision, or blocked dependency stops repository mutation.
  - edge: concurrent independent roots may create parallel Graphite tracks, while dependent issues follow declared relation ancestry rather than ordinal order.

- **AC8 — PR and status attribution are Linear-only**
  - happy: every implementation PR has one exact `Linear-Issue:` trailer and project increments also have one exact `Linear-Project:` trailer; status renders and reconciles from Linear plus verified PR evidence.
  - error: `Spec:` trailers, missing/duplicate/reordered identifiers, foreign PRs, or issue/project mismatches fail closed.
  - edge: standalone issue PRs carry no synthetic project trailer.

- **AC9 — The custom Linear transport and credentials are gone**
  - happy: the Linear GraphQL adapter, request scripts, GraphQL documents, `LINEAR_API_KEY` path, backend resolver, and Markdown backend code are absent from the shipped active surface.
  - error: tests fail on any active Linear GraphQL/API-key/fallback path.
  - edge: GitHub GraphQL review-thread scripts remain allowed and are not falsely classified as Linear transport.

- **AC10 — Engineer-agent and Hermes + OMP setup is actionable**
  - happy: a generic contract defines lead/issue/coder authority, multiple Hermes engineer units have distinct OAuth app identities and project authority, paired isolated OMP profiles share only their unit identity, Hermes independently reviews and comments on PRs, and getting started includes verified Linear MCP, GitHub review access, Hermes, OMP, woostack, and copyable prompt steps.
  - error: setup blocks when `actor=app`, delegate capabilities, or exact identity read-back is unavailable; the prompt forbids Hermes from coding or self-claiming work, forbids routine review delegation or self-acceptance by OMP, and fails closed on incomplete evidence or ownership conflict.
  - edge: explicit `/woostack-review` may use its configured reviewers while Hermes remains the acceptance authority; another orchestrator or coding harness can implement the generic contract without Hermes- or OMP-specific assumptions leaking into lifecycle authorities.

- **AC11 — Authored and generated documentation stays in sync**
  - happy: README, configuration, getting started, concepts, workflows, status, worktrees, building rules, agent/harness guidance, and generated skill pages describe one Linear-only system.
  - error: structural tests fail on optional/default Markdown wording, local-development source-of-truth claims, or API-key guidance.
  - edge: retained local memory/wisdom and diagnostic reports are described precisely rather than being accidentally removed or promoted to authority.

- **AC12 — The complete provider flow is demonstrably operable**
  - happy: a live single-identity workspace run preflights official Linear MCP, creates disposable standalone and project resources, exercises typed updates/comments, state, relations, and independent read-back, then cancels/archives the fixtures with verified receipts.
  - error: the run stops truthfully at the first unavailable capability or incomplete receipt without local fallback or fixture deletion that would hide an unknown outcome.
  - edge: multi-engineer allocation, delegate-vs-assignee handling, identity collision, partial migration, and interrupted execution remain required deterministic behavior fixtures but are not a multi-identity live release gate.

## 8. Testing

- Replace backend-selection and adapter unit tests with structural contracts that reject active Markdown development branches, local development-record authors/readers, `LINEAR_API_KEY`, Linear GraphQL operations, Linear document dependencies, and `Spec:` attribution while allowing GitHub GraphQL.
- Add behavior eval fixtures for MCP capability preflight, ownership/identity resolution, verified mutation receipts, idempotent retry, standalone issue lifecycle, project/increment lifecycle, three build gates, migration classification, migration partial failure, multi-agent allocation and assignment collision, project-lead escalation, handoff, direct Hermes PR review, explicit `/woostack-review` delegation, relation-aware Git ancestry, PR attribution, and status reconciliation.
- Add migration fixtures with active, completed, ambiguous, partially migrated, and foreign records. Assert that incomplete receipts produce zero local deletions.
- Run the existing relevant skill contract suites after rewriting their expectations around the one Linear model.
- Build the Fumadocs site and inspect authored pages for one consistent product model.
- Validate Hermes setup commands against official Hermes MCP documentation and OMP invocation against `omp --help`.
- Perform a live end-to-end acceptance run in an authenticated Linear MCP workspace with one identity. Use uniquely marked disposable resources, exercise every required mutation/read-back capability, and verify cleanup. Multi-identity behavior remains fixture-covered rather than release-blocking.

## 9. Open questions

None. The approved design resolves artifact scope, direct official MCP architecture, project-update decision history, standalone issue handling, active-only migration, generic engineer-agent scope, multi-Hermes identity and ownership, and the Hermes/OMP delegation boundary. Implementation must discover exact host-exposed MCP tool names at runtime and validate capabilities rather than hardcoding transport-specific names.
