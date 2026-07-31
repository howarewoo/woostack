---
name: woostack-bootstrap
description: Use when bootstrapping a genuinely greenfield web, mobile, desktop, API, or daemon project from scratch — gathering requirements, researching current technologies, approving an artifact-free design, creating its managed Linear feature project through official MCP before any target-directory write, and scaffolding the app/feature/infrastructure package slice architecture.
---

# woostack-bootstrap

## Overview

Bootstrap is the greenfield, project-first entry point. It gathers requirements, resolves current
technologies and versions live, and presents a complete architecture and scope without creating a
development artifact. Explicit design approval authorizes exactly one managed Linear `feature`
project and its verified `designApproved` update. Only that verified project receipt releases the
target-directory write barrier.

The stack remains dynamic rather than template-selected. Compare current production-ready options
against the project's requirements, then scaffold the approved app, feature, and infrastructure
package slices under the retained Linear project identity.

**Core principle:** resolve technologies and versions live based on project requirements, never
from memory, and establish the remote development authority before writing the new codebase.

## Invocation

Invoke with `/woostack-bootstrap <goal>`, where the goal is a plain-language description of the
new codebase:

```text
/woostack-bootstrap create a new mobile app for cataloging recipes
/woostack-bootstrap a SaaS dashboard with a marketing site and a billing API
```

The goal seeds the requirements-gathering and recommendation phase; it is not approval and is not a
stored development record.

## Routing

Use bootstrap only when there is no existing codebase whose conventions or history own the work.
An empty remote repository may be the intended destination, but an existing repository request
routes before requirements gathering, MCP preflight, project creation, or target access:

- bugs, regressions, incidents, and root-cause work → [`woostack-fix`](../woostack-fix/SKILL.md);
- a bounded non-bug enhancement or refactor that fits one reviewable PR, including a one-file
  request → [`woostack-change`](../woostack-change/SKILL.md);
- a multi-PR feature or architectural initiative → [`woostack-build`](../woostack-build/SKILL.md).

Single-surface throwaway scripts are also outside bootstrap.

## Procedure

1. **Classify and capture intent without target access.** Classify greenfield versus brownfield
   first. Retain the requested target path as an opaque string; do not stat, list, read,
   canonicalize, create, or write it, and do not invoke Git.
2. **Gather requirements.** Ask targeted questions about product goals, required surfaces, scale,
   deployment restrictions, compliance/security, integrations, and budget.
3. **Perform live industry research.** Use web search and live registry lookups such as
   `npm view <pkg> version` to identify current frameworks, libraries, databases, and services that
   satisfy the requirements.
4. **Present the design.** Compare 2–3 cohesive stack options with pros/cons, production-readiness,
   and cost implications. Present one complete proposed architecture and scope, including surfaces
   and initial features. Keep the design only in the conversation/run context: create no Linear
   resource, local spec or plan, target directory, branch, commit, or PR.

<HARD-GATE name="design-approval">
Wait for explicit approval of the complete presented design. Silence, an initial goal, a stack
preference, partial agreement, or approval inferred by the agent does not clear this gate. Before
approval, perform no official-MCP development mutation and create no development artifact.
</HARD-GATE>

5. **Establish repository/base intent and preflight official MCP.** Only after approval, retain the
   exact canonical future `https://github.com/<owner>/<repository>` URL and intended initial
   integration/base branch. Build the proposed non-secret `linear` policy in memory and apply
   [`woostack-init`'s capability and config contract](../woostack-init/SKILL.md): resolve one
   workspace/team, all required native project-status and issue-state mappings, and every required
   project/issue/update/comment/relation/owner read, mutation, pagination, and independent
   read-back capability through the host-exposed official Linear MCP. Tool names are
   capability-discovered. Authentication stays in the host MCP/OAuth secret store. A missing,
   read-only, partial, ambiguous, unauthenticated, foreign, or conflicting result stops with no
   target filesystem or Git access.
6. **Derive restart-safe identity, then create/read exactly one feature project.** Canonicalize the
   repository plus approved goal/scope using [the bootstrap identity algorithm](references/bootstrap.md)
   and derive its approved-design key and deterministic feature client UUID before mutation.
   Paginate the complete repository-owned `feature` project set and search by that managed UUID and
   full tuple. A fresh invocation recomputes the same identity even when a prior run lost all
   in-memory state. Reuse one complete verified match or create once only when complete discovery
   proves absence. Duplicate, foreign, partially managed, or conflicting candidates block.
   Independently read the project back before any update. Unknown outcomes rediscover by the same
   key/UUID; titles, timestamps, and local files never select identity.
7. **Reconcile and verify `designApproved`.** Deterministically derive and retain its stable event
   UUID from the feature UUID. Before append, paginate and read the complete project-update set.
   Reuse and independently read back exactly one matching valid event identity only when its
   repository, normalized design/key, approval evidence, and exact initial base intent match the
   current approved context; changed or conflicting base intent blocks. Also block a malformed
   match, duplicate revision/current head, conflicting phase head, or incomplete listing. Append
   revision 1 only when complete pagination proves the event and every conflicting phase head
   absent, using `predecessorId: null`, `supersedesId: null`, and the approved architecture, scope,
   repository/base intent, and approval evidence in the readable body. Then independently verify
   those exact fields, the event envelope/project identity, configured `backlog` category, and
   single valid lifecycle chain. An MCP mutation response alone authorizes nothing.
8. **Release the authority barrier, then collision-check the target.** Only after the normalized
   preflight receipt, exact repository/base intent, verified project receipt, and verified
   `designApproved` receipt all exist may the first target-filesystem action occur. That first
   action must be a read-only collision check with no Git invocation. Proceed only when it proves
   the target is absent or an empty non-Git directory. A populated path, existing Git checkout,
   non-directory/symlink, unreadable state, partial result, or ambiguity blocks before mkdir,
   write, scaffold, or Git while preserving and reporting the verified project/event receipts.
   Retain the approved-design key, feature client UUID, native project ID, canonical Linear project
   URL, repository, OAuth-scoped workspace slug, native team ID/key, base intent, and native
   `designApproved` update ID in memory.
   Pass that exact identity into the scaffold procedure and any later build/planning continuation;
   callees refresh mutable state but never rediscover by title or select another project.
9. **Scaffold and verify.** Follow [references/bootstrap.md](references/bootstrap.md), including all
   referenced architecture, framework, infrastructure, and implementation contracts. Initialize
   the non-authoritative local workspace through `woostack-init` using the verified policy/receipt;
   never create `.woostack/specs/`, `.woostack/plans/`, or `.woostack/fixes/`. Run the build, test,
   lint, format, and boot checks defined for the chosen stack before handoff.

## References (load on demand)

| File | What it defines |
|---|---|
| [references/decisions.md](references/decisions.md) | Questionnaire guide and explicit design-confirmation protocol |
| [references/bootstrap.md](references/bootstrap.md) | Project-first bootstrap procedure and filesystem barrier |
| [references/architecture.md](references/architecture.md) | Monorepo layout, package tiers, import boundaries, naming |
| [references/frameworks.md](references/frameworks.md) | Version-resolution rules, workspace catalogs, and gotchas |
| [references/infrastructure.md](references/infrastructure.md) | Production-readiness patterns: hosting, CI/CD, env vars, migrations, observability |
| [references/patterns.md](references/patterns.md) | Standard implementation and TDD guidelines |
| [references/development.md](references/development.md) | Linear development authority, routing, and branching model |

## Hard constraints

These are non-negotiable. Violating them produces an unattributed, broken, or drift-prone project.

- **Greenfield only.** Route every brownfield bug, bounded one-PR request, or multi-PR initiative to
  fix, change, or build before creating a bootstrap project.
- **Artifact-free until explicit approval.** Requirements, research, options, and design stay in
  the run context. No project, update, issue, document, local spec/plan, or Git artifact exists
  before the design-approval gate clears.
- **Project before filesystem.** Missing official MCP or config capability, repository/base intent,
  project read-back, or `designApproved` read-back means no stat, list, read, canonicalization,
  creation, write, scaffolding CLI, or Git operation against the target.
- **Official Linear MCP only.** There is no backend selection, local development-record mode,
  Linear document, custom provider call, custom Linear HTTP/GraphQL transport, repository
  credential, environment-token fallback, or alternate authority.
- **Restart-safe stable identity.** Derive the feature client UUID deterministically from the
  canonical repository plus normalized approved goal/scope before complete remote discovery. Fresh
  invocations recompute it; duplicates or partial managed matches block instead of allocating a
  replacement.
- **Complete event reconciliation and verified receipts.** Derive the stable `designApproved`
  event UUID, completely paginate updates before append, reuse/read back one exact existing event,
  and block conflicting or duplicate heads. Independently read every mutation and retry unknown
  outcomes only by the same key/UUID.
- **Collision-safe first access.** After the remote authority barrier clears, the first
  target-filesystem action is a read-only collision check. Only an absent target or empty non-Git
  directory permits creation/scaffolding; any populated, Git-owned, unreadable, or ambiguous state
  blocks before a local or Git mutation while the verified remote receipts remain reportable.
- **Pass exact project identity.** Scaffolding and lifecycle continuation use the retained feature
  client UUID, native project ID/URL, repository, and verified event context. Planning writes only
  managed Linear project updates/issues/relations and never a local spec or plan.
- **Confirm the stack before scaffolding.** Present options and receive explicit approval; never
  silently choose or scaffold a stack.
- **Always resolve latest versions live.** Never use hardcoded versions from memory. Query the
  registry live during research and exact resolution.
- **Maintain package slice architecture.** Strictly follow
  [references/architecture.md](references/architecture.md) for package layering
  (`Apps -> Features -> Infrastructure`) regardless of the chosen technology stack.
- **Do not ship unverified.** Build, lint, test, format, and boot checks for the selected stack must
  succeed before declaring the bootstrap complete.
- **Record decisions.** At handoff, write final stack choices, resolved versions, rationale,
  project identity, and development instructions into the project root `README.md`; the verified
  Linear project/update remains lifecycle authority.
- **Initial scaffold is the one worktree exemption.** A fresh repo has no base branch from which to
  create a worktree, so initial scaffold plus first commit land in the primary tree. All subsequent
  feature/fix work follows the
  [worktree contract](../woostack-init/references/worktrees.md).

## SPEC_VERSION

`4.0.0` — Project-first greenfield bootstrap through mandatory official Linear MCP.
