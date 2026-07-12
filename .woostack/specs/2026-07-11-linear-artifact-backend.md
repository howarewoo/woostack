---
name: linear-artifact-backend
type: spec
status: hardened
date: 2026-07-11
branch: feature/linear-artifact-backend
links:
---

# Linear Spec and Plan Backend — Design Spec

> Visualize on demand: render this file with [spec-template.html](../../../skills/woostack-build/references/spec-template.html) for a rich view. Markdown is the source of truth for this feature's design; the HTML is a presentation target only.

> `status:` is the build-loop phase enum. The build loop authors each transition and `/woostack-status` reads it; the enum and join contracts are defined once in [conventions.md](../../../skills/woostack-status/references/conventions.md).

> **Plan:** [[plans/2026-07-11-linear-artifact-backend]]

## 1. Problem

Woostack currently requires repository-local Markdown files under `.woostack/specs/` and `.woostack/plans/` as the source of truth for feature design and execution. Teams that manage product work in Linear must duplicate specs, plans, lifecycle state, and links between Linear and the repository. A partial Linear integration would be worse: commands that still scan local folders would silently disagree with commands writing Linear.

Woostack needs a configurable spec/plan artifact backend. When Linear is selected, Linear must be the sole spec/plan source of truth across every reader, author, validator, and workflow, while existing repositories continue to use Markdown by default.

## 2. Goal

Add a complete Linear-backed spec/plan workflow using Linear's GraphQL API directly:

- one Linear project represents one woostack feature;
- one project document contains the authoritative spec;
- ordered project issues form the executable plan, one independently shippable issue per increment;
- native Linear project statuses and team issue states represent lifecycle state;
- all current spec/plan consumers resolve the configured backend before reading or writing artifacts;
- the existing design approval, spec approval, and execution-handoff gates retain their meaning;
- Linear mode never creates local spec/plan source files or silently falls back to them;
- Markdown remains the compatible default for existing repositories.

## 3. Non-goals

- Replacing local fixes, QA reports, audits, overnight reports, visuals, memory notes, or other `.woostack/` stores that are not spec/plan artifacts.
- Removing the Markdown backend.
- Automatically importing existing Markdown specs/plans into Linear.
- Bidirectional synchronization between Linear and local Markdown.
- Adding a hosted OAuth application or storing Linear credentials in repository files.
- Adding a public `woostack-*` command or changing the twenty-skill public command surface.
- Deleting existing local spec/plan files when Linear mode is enabled.
- Treating Linear as a Git or Graphite replacement; implementation remains branch/PR based.

## 4. Approach

### 4.1 Backend configuration

Extend `.woostack/config.json` with an explicit backend selector and non-secret Linear settings:

```json
{
  "artifacts": {
    "specPlan": "linear"
  },
  "linear": {
    "workspace": "acme",
    "team": "ENG",
    "projectStatuses": {
      "draft": "Draft",
      "hardened": "Hardened",
      "approved": "Approved",
      "planning": "Planning",
      "ready": "Ready",
      "executing": "In Progress",
      "inReview": "In Review",
      "done": "Completed",
      "abandoned": "Canceled"
    },
    "issueStates": {
      "planned": "Backlog",
      "executing": "In Progress",
      "inReview": "In Review",
      "done": "Done",
      "blocked": "Blocked"
    }
  }
}
```

Missing `artifacts.specPlan` means `markdown`. The selector accepts only `markdown` or `linear`. Every lifecycle mapping shown for the selected backend, including `projectStatuses.abandoned`, is required. Linear status/state names are resolved to UUIDs during authenticated preflight; missing or ambiguous matches block before mutation. The API credential comes only from `LINEAR_API_KEY`. Config must never contain a token or a configurable credential-file path.

The repository identity is the canonical GitHub `owner/repository` when available, with a stable non-secret config override for repositories without a GitHub remote. Managed resources include that identity so projects in the same Linear workspace cannot be adopted across repositories.

### 4.2 Linear artifact model

A managed Linear project is the feature root. It contains exactly one managed spec document and zero or more managed increment issues.

The spec document uses the current spec template's conceptual sections and includes a collapsed `+++ Woostack metadata — managed, do not edit` section containing canonical, versioned JSON with artifact type, schema version, repository identity, project UUID, design state, and the resolved base branch and commit once frozen. This uses Linear's documented collapsible-section Markdown rather than relying on undocumented HTML-comment preservation. Human-authored Markdown outside that section is preserved.

Each plan increment is one project issue. Its description contains the objective, dependencies, exact change steps, TDD sequence, acceptance criteria, automated verification, and manual verification. The same collapsed metadata section records schema version, project UUID, stable increment identity, explicit integer ordinal, and the expected dependency issue UUIDs as canonical JSON. Ordering is derived from the ordinal, never Linear UI order, priority, creation time, or lexical title order. Linear's native `blocked by` issue relations are authoritative for dependency truth; metadata mirrors their UUIDs as a drift check. Preflight rejects cycles, dependencies outside the managed project, missing or duplicate ordinals, and any disagreement between native relations and metadata.

The issue set may form a dependency DAG with independent tracks; the ordinal is presentation order, not an implicit dependency. Independent roots may execute concurrently in overnight mode. Each issue metadata block also declares exactly one Git parent reference for Graphite ancestry (the resolved base branch for a root, or one dependency issue for a stacked increment). For an issue with multiple `blocked by` relations, planning must prove that every non-parent dependency will already be merged or reachable from the declared parent before execution; otherwise the shape is unrepresentable and cannot become `ready`.

The join becomes:

`Linear project : spec document : increment issues : implementation PRs = 1 : 1 : N : N`.

Implementation PR bodies use stable trailers:

```text
Linear-Project: <project UUID>
Linear-Issue: ENG-123
```

One increment issue maps to at most one active implementation PR.

### 4.3 Workflow

The existing three hard gates remain: design approval, written spec approval, and execution handoff. Linear storage adds no gate and removes none.

After design approval, `woostack-build` runs authenticated preflight, creates the project in `draft`, creates its spec document, and reads both back. It creates no feature worktree, branch, commit, or docs-only PR because there is no repository artifact.

Spec hardening updates the same Linear document. When hardening stops, the project becomes `hardened` and the user reviews the Linear document URL at the spec-approval gate. Revise updates the same document; Go moves the project to `approved`; Abandon moves it to the required configured `abandoned` status and preserves the project, spec, and audit history. It never deletes or automatically archives the project; archival is a separate explicit administrative action.

`woostack-plan` accepts a Linear project UUID, URL, or unambiguous managed reference. It moves the project to `planning`, reads the canonical spec, creates ordered project issues, wires their native `blocked by` relations, and records one valid Git parent per issue. Decomposition verification requires every issue to be independently reviewable and shippable, every spec acceptance criterion to map to at least one increment, and the dependency DAG to have a representable Graphite ancestry. Plan hardening updates the issues and relations in place and adds no approval gate. A clean read-back moves the project to `ready`.

Immediately before presenting the execution-handoff gate, woostack resolves the current Git base through the existing base resolver and writes both the branch name and exact commit SHA into managed project metadata. The handoff presents the project, spec document, ordered issues, frozen base, and intended Graphite stack. Before explicit Go or Run overnight, no implementation branch, worktree, commit, or PR is created. Handoff approval makes the frozen base immutable; if it later becomes unusable, explicit replanning must update it before any affected implementation branch exists, never a silent rebase.

Execution processes issues in dependency order; supervised mode may remain sequential, while overnight mode may run independent ready roots/tracks concurrently. It transitions an issue to `executing`, creates the implementation worktree/branch from its declared Git parent, performs TDD, submits the PR, writes branch/PR evidence back to the issue, and transitions to `inReview` only after read-back verification. Build never merges, so execution ends with reviewed increment issues and the project in `inReview`. An issue may transition to native `done` only after its attributed PR has merge evidence; the project may transition to native `done` only after every increment issue is `done` and every attributed PR is merged. Failures retain `executing` or move to `blocked`; an attempted mutation never counts as completion.

Linear mode has no spec/plan docs-only base PR. Root execution PRs branch from the frozen base commit; dependent PRs use their declared parent issue branch. This is an intentional backend-specific workflow difference that avoids duplicating Linear content in Git.

### 4.4 Compatibility and migration boundary

Markdown remains the default and preserves existing behavior. Linear mode does not read, merge, synthesize, or update local spec/plan files. If such files coexist, doctor reports inactive legacy artifacts; commands do not combine feature lists.

Automatic migration and two-way synchronization are out of scope. A future explicit one-way migration may create and verify Linear resources, update open PR attribution, and leave source files untouched for deliberate archival.

## 5. Components & data flow

### 5.1 Backend resolver and normalized feature model

A shared backend resolver reads `artifacts.specPlan` before any spec/plan access. Both backends expose the same normalized JSON feature model:

```json
{
  "backend": "linear",
  "feature": {
    "id": "project-uuid",
    "url": "https://linear.app/acme/project/...",
    "title": "Linear spec and plan backend",
    "status": "ready",
    "branch": null
  },
  "spec": {
    "id": "document-uuid",
    "url": "https://linear.app/acme/document/...",
    "content": "...",
    "revision": "updated-at-or-content-hash"
  },
  "increments": [
    {
      "id": "issue-uuid",
      "identifier": "ENG-123",
      "ordinal": 1,
      "status": "planned",
      "dependencies": [],
      "branch": null,
      "pullRequest": null,
      "content": "..."
    }
  ]
}
```

The Markdown adapter parses existing files into the same model. Workflow logic consumes the normalized model instead of embedding storage assumptions.

Across sessions, commands resolve a feature by querying managed Linear projects whose repository marker matches the current repository and whose native status is valid for the requested operation. An explicit project UUID or Linear URL always overrides discovery. Automatic continuation is permitted only when exactly one project matches; zero matches produce a not-found error, and multiple matches present the non-secret project identifiers, titles, statuses, and URLs for explicit selection. Woostack persists no local active-project pointer.

### 5.2 Linear GraphQL adapter

Ship one internal, dependency-free shell adapter using `curl`, `jq`, and `https://api.linear.app/graphql`. It is not a new public skill. It solely owns:

- authentication headers and secret handling;
- request encoding;
- queries, mutations, pagination, and schema preflight;
- HTTP, GraphQL, partial-response, and rate-limit handling;
- workspace, team, project-status, and issue-state resolution;
- managed-resource discovery;
- metadata parsing and version enforcement;
- optimistic revision checks;
- semantic idempotency and mutation read-back receipts;
- normalized feature output.

No command embeds its own Linear GraphQL query or calls the endpoint directly.

### 5.3 Concurrency and ownership

Before a read-modify-write, the adapter re-fetches the resource and compares `updatedAt` plus a content hash with the revision used to generate the change. A mismatch stops and reports the resource URL. When Linear does not expose compare-and-set mutation semantics, this is best-effort optimistic concurrency followed by mandatory immediate read-back.

The adapter modifies only the single collapsed `Woostack metadata — managed, do not edit` section and specifically owned Linear fields. It rejects missing, malformed, duplicated, foreign-repository, or unsupported-version metadata; requires the JSON to round-trip canonically; and preserves all content outside the section. It never adopts by title alone or overwrites unrelated human content.

### 5.4 Idempotency and receipts

Creates use discovery-before-create with repository and parent identity. Retries reconcile observed state rather than blindly repeating mutations. Multiple managed matches are corruption and block.

Every mutation returns a receipt describing intended operation, resources observed, mutation response, returned UUID, read-back result, and remaining substeps. Temporary receipts are gitignored operational evidence, not an alternate source of truth.

### 5.5 Command integration

All current spec/plan readers and authors move behind backend resolution, including build, plan, execute, overnight execute, status, commit/PR attribution, review, address-comments, ask, visualize, debug context, TDD targets, doctor, and memory provenance.

Memory provenance accepts stable `linear://project/<uuid>`, `linear://document/<uuid>`, and `linear://issue/<uuid>` references. Static doctor checks validate shape; authenticated live checks validate existence.

When the Linear backend is configured, every `woostack-status` invocation is an authenticated reconciliation run before rendering the board: it fetches attributed PR state, previews the exact eligible `inReview → done` issue transitions and final project transition in its output, applies only transitions backed by unambiguous merge evidence, reads them back, and then renders. This is intentionally different from Markdown mode's read-only status behavior. Missing credentials, API failures, ambiguous attribution, or read-back mismatch fail closed rather than rendering a knowingly stale success board. Status never changes any other lifecycle state and never reopens or downgrades resources.

Worktree creation for spec/plan authoring and the docs-only base PR remain Markdown-only. Linear mode creates worktrees only for implementation increments.

A structural test enumerates forbidden direct `.woostack/specs/` and `.woostack/plans/` assumptions outside the Markdown adapter and explicitly documented compatibility code.

## 6. Error handling

The Linear backend fails closed. It never falls back to Markdown or reports absent local folders as an empty feature set.

- Missing `LINEAR_API_KEY`: block before the first API request without printing the token or environment contents.
- Invalid backend/config: report the exact non-secret key and accepted shape.
- Authentication/authorization failure: do not retry; report operation and affected resource when known.
- HTTP failure: classify transport, retryable server, and non-retryable client failures.
- GraphQL HTTP `200` with `errors`: treat as failure even when `data` exists.
- Partial mutation response: discover/read back before deciding whether the mutation succeeded.
- Rate limit: stop with server retry timing; do not silently sleep through an interactive gate.
- Unknown mutation outcome: discover state before retry; never blind-retry a create.
- Missing/ambiguous team, status, state, project, document, or issue: block before mutation and report identifiers/URLs without secrets.
- Duplicate managed metadata: block as corruption; never select arbitrarily.
- Concurrent human edit: block before overwrite and surface the conflicting Linear URL.
- Unsafe increment removal: block if the increment has a branch or PR; require an explicit replanning decision.
- Dependency cycle or duplicate ordinal: reject the plan before execution.
- Failed code/test/submit step: leave the issue `executing` or move it to configured `blocked`; never transition to `inReview` or `done` without evidence.
- Logging: include operation, non-secret resource identifiers, HTTP/GraphQL classification, and retry state; never log authorization headers, API keys, full environment data, or unnecessary document contents.

Queries may use bounded retries for explicitly transient failures. Mutations are never blindly retried.

## 7. Acceptance criteria

- **AC1 — Backend selection is compatible and explicit**
  - happy: a repository with no selector behaves exactly as Markdown today; `markdown` and `linear` select their respective adapters.
  - error: unsupported values or incomplete Linear config fail with actionable non-secret diagnostics.
  - edge: existing local spec/plan files in Linear mode are reported as inactive legacy artifacts and are never merged into Linear results.

- **AC2 — Authentication and preflight are secure and complete**
  - happy: `LINEAR_API_KEY` authenticates direct GraphQL calls and all configured workspace/team/status/state mappings resolve uniquely before mutation.
  - error: absent/invalid credentials, insufficient permissions, schema incompatibility, or missing/ambiguous mappings block before writes.
  - edge: logs and receipts never contain the API key, authorization header, environment dump, or unnecessary spec content.

- **AC3 — Linear artifact identity preserves the feature join**
  - happy: one managed project resolves to exactly one managed spec document and ordered increment issues with stable UUIDs and repository ownership.
  - error: missing, malformed, duplicate, foreign, or unsupported metadata blocks stop rather than guess.
  - edge: same-titled projects in one workspace remain isolated by UUID, repository identity, and managed marker.

- **AC4 — Build preserves all three gates without Git duplication**
  - happy: design approval creates the project/spec, spec approval permits planning, and handoff approval permits execution.
  - error: silence, ambiguity, or failed read-back never advances a gate.
  - edge: before handoff approval Linear mode creates no implementation branch/worktree/commit/PR and never creates a spec/plan docs-only PR.

- **AC5 — Planning produces an executable ordered issue set**
  - happy: each independently shippable increment is one issue with explicit ordinal, native `blocked by` relations, mirrored dependency UUIDs, one valid Git parent, steps, TDD sequence, acceptance coverage, and verification; independent tracks remain executable by overnight mode.
  - error: dependency cycles, cross-project relations, relation/metadata disagreement, duplicate ordinals, unrepresentable multi-parent ancestry, unreviewable increments, or uncovered spec criteria prevent `ready`.
  - edge: replanning retains stable issue UUIDs, safely adds/reorders issues and rewires relations, preserves valid parallel tracks, and refuses to remove an issue with implementation evidence.

- **AC6 — Execution state is evidence-backed**
  - happy: implementation/test/Graphite evidence moves an issue to `inReview`; merge evidence moves that issue to `done`; the project reaches `done` only after every increment PR is merged.
  - error: implementation, test, API, submission, or merge-evidence failure leaves truthful `executing`, `blocked`, or `inReview` state.
  - edge: retries resume from observed project/issue/PR state without creating duplicate issues or PR attribution; every Linear-backed status run idempotently reconciles merge-backed terminal transitions before rendering and fails closed on ambiguity.

- **AC7 — API failures fail closed and remain retry-safe**
  - happy: successful queries/mutations return normalized data and verified receipts.
  - error: HTTP errors, GraphQL errors, partial responses, rate limits, and authorization failures stop with actionable classifications.
  - edge: an unknown mutation outcome performs discovery before any retry and does not duplicate resources.

- **AC8 — Concurrent Linear edits are not overwritten**
  - happy: unchanged revisions permit narrow owned-field updates followed by read-back.
  - error: changed revisions stop and surface the resource URL.
  - edge: human content outside the machine block remains intact across an update.

- **AC9 — Complete command surface uses one backend contract**
  - happy: build, plan, execution modes, status, commit, review context, ask, visualize, debug context, TDD, doctor, and memory provenance consume the normalized feature model.
  - error: Linear API unavailability never degrades to local file reads or an empty-success result.
  - edge: a structural test catches new direct spec/plan folder assumptions outside the Markdown adapter or explicit compatibility code.

- **AC10 — PR and memory attribution use stable Linear references**
  - happy: implementation PRs carry valid `Linear-Project` and `Linear-Issue` trailers and memory provenance can resolve `linear://` references.
  - error: missing, mismatched, or foreign attribution blocks commit/review association rather than attaching to the wrong feature.
  - edge: renamed Linear titles do not break UUID-based joins.

- **AC11 — Existing Markdown behavior remains covered**
  - happy: current Markdown workflows, status joins, doctor checks, worktrees, and docs-only base PR behavior remain unchanged under the default backend.
  - error: backend abstraction cannot silently reinterpret or rewrite legacy Markdown artifacts.
  - edge: switching the config selector does not synthesize, delete, or synchronize artifacts across backends.

- **AC12 — Documentation and config contracts stay synchronized**
  - happy: init templates, command skills, conventions, references, root guidance, and authored docs-site pages describe both backends consistently.
  - error: tests fail when required config keys, public contracts, or backend-specific workflow statements drift.
  - edge: per-skill generated pages continue deriving from `SKILL.md`; the public command count and routing surface do not change.

## 8. Testing

Use deterministic shell tests with a fake HTTP endpoint or mocked `curl`; the normal suite must not require a Linear account or network access.

Adapter fixtures cover successful query/mutation responses, HTTP failures, GraphQL errors with HTTP `200`, partial data plus errors, pagination, missing/ambiguous mappings, authentication/authorization failures, rate limits, unknown mutation outcomes, duplicate markers, concurrent edits, create retries, increment reconciliation, repository isolation, metadata versions, secret redaction, and post-mutation read-back mismatches.

Workflow tests cover every acceptance criterion and especially the three hard barriers: no Linear mutation before design approval, no planning before explicit spec approval, and no implementation Git artifact before explicit handoff. Add compatibility tests that run representative existing Markdown workflows unchanged, plus a structural guard against unapproved direct spec/plan folder access.

Doctor tests separate static config diagnostics from opt-in authenticated live validation. An optional manual smoke test may target a user-provided sandbox team to verify the current introspected Linear schema and create/read/update/archive lifecycle; it must clean up or archive its test project and must never run in the default suite.

The docs-site build is run after authored pages are synchronized. No application dependency or lockfile is added outside the sanctioned `site/` subtree.

## 9. Open questions

- Settled: Linear is accessed through its GraphQL API directly; there is no CLI dependency.
- Settled: one project + one spec document + ordered increment issues is the canonical model.
- Settled: native project statuses and team issue states carry lifecycle state through explicit config mappings.
- Settled: authentication uses only `LINEAR_API_KEY`.
- Settled: the first release covers the complete spec/plan command surface.
- Settled: API failures fail closed with no Markdown fallback or local cache authority.
- Settled: one shared dependency-free shell adapter owns transport and normalization.
- Settled: machine metadata uses one collapsed `Woostack metadata — managed, do not edit` section with canonical versioned JSON, relying only on Linear's documented collapsible Markdown behavior.
- Settled: Abandon requires a configured native `abandoned` project status and preserves the project; automatic archival or deletion is prohibited.
- Settled: resumed commands discover managed projects by repository identity and command-valid lifecycle state, continue automatically only on one match, and accept an explicit project UUID/URL override; no local active-project pointer is stored.
- Settled: native `done` requires merge evidence for every attributed increment PR; build ends at `inReview`, and every Linear-backed `woostack-status` run automatically reconciles eligible merge-backed terminal transitions before rendering.
- Settled: Linear native `blocked by` relations are authoritative for increment dependencies; canonical metadata mirrors dependency UUIDs for drift detection, while the explicit ordinal provides deterministic presentation order.
- Settled: the Linear plan preserves dependency DAGs and overnight parallel tracks; ordinals provide display order, while each issue declares one Git parent and multi-dependency increments must prove the remaining dependencies are merged or reachable.
- Settled: the Git base branch and exact commit SHA are resolved and stored in managed project metadata immediately before the handoff gate, become immutable on execution approval, and may change only through explicit replanning before affected branches exist.
