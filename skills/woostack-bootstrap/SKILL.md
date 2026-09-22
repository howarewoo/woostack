---
name: woostack-bootstrap
description: Bootstrap a genuinely greenfield web, mobile, desktop, API, or daemon project from scratch—gather requirements, research current technologies, approve the design, collision-check the target, and scaffold app-local code with shared packages only when needed. An explicitly selected GitHub Project may retain the approved design.
---

# woostack-bootstrap

## Overview

Bootstrap is the greenfield, project-first entry point. It gathers requirements, resolves current
technologies and versions live, presents a complete architecture and scope, and waits for explicit
design approval before any target-directory write. That approval—not a provider receipt—releases
the write barrier after repository and target collision checks pass.

The stack remains dynamic rather than template-selected. Validate the user's supplied stack against
the project's requirements, then scaffold each approved app with code local to that app.
Extract a package only when multiple apps need the same code. An exact canonical GitHub Project URL
may retain the approved design and requested delivery notes, but is optional and never authorizes
writes.

**Core principle:** resolve technologies and versions live based on project requirements, never
from memory, and prove the approved design plus collision-safe target before writing the new
codebase.

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
routes before requirements gathering, MCP preflight, or project creation:

- bugs, regressions, incidents, and root-cause work → [`woostack-debug`](../woostack-debug/SKILL.md)
  for diagnosis or [`woostack-prepare`](../woostack-prepare/SKILL.md) for a proved issue graph;
- a bounded non-bug enhancement or refactor that fits one reviewable PR, including a one-file
  request → [`woostack-change`](../woostack-change/SKILL.md);
- a multi-PR feature or architectural initiative → [`woostack-prepare`](../woostack-prepare/SKILL.md).

Single-surface throwaway scripts are also outside bootstrap.

## Procedure

1. **Classify and capture intent.** Classify greenfield versus brownfield first. Bounded read-only
   target inspection may establish existence or collisions under the
   [filesystem procedure](references/bootstrap.md#filesystem-write-barrier-and-collision-check);
   it grants no write authority.
2. **Gather requirements.** Ask targeted questions about product goals, required surfaces, scale,
   deployment restrictions, compliance/security, integrations, and budget.
3. **Perform live industry research.** Use web search and live registry lookups such as
   `npm view <pkg> version` to identify current frameworks, libraries, databases, and services that
   satisfy the requirements.
4. **Present the design.** Research and validate a supplied viable stack, then present one complete
   proposed architecture and scope, including surfaces, initial features, technical decisions,
   production-readiness, and cost implications. Compare alternatives only for unresolved material
   tradeoffs. Keep the design only in the conversation/run context: create no remote project/issue,
   local spec or plan, target directory, branch, commit, or PR.

<HARD-GATE name="design-approval">
Wait for explicit approval of the complete presented design. Silence, an initial goal, a stack
preference, partial agreement, or approval inferred by the agent does not clear this gate. Before
approval, perform no official-MCP development mutation and create no development artifact.
</HARD-GATE>

5. **Establish repository/base intent and a stable approved-contract identity.** Only after approval,
   retain the exact canonical future `https://github.com/<owner>/<repository>` URL, intended
   integration/base branch, normalized approved goal/scope, and deterministic contract identity. This
   identity prevents duplicate work within/resumed from the same supplied contract; it is not a run,
   provider, or development record.
6. **Admit the filesystem write barrier.** Follow the canonical
   [collision-check procedure](references/bootstrap.md#filesystem-write-barrier-and-collision-check)
   after approval and repository/base intent are retained. Early inspection cannot replace the
   fresh pre-write check.
7. **Optionally publish the approved design.** Only after design approval and target collision checks pass,
   and only when the caller explicitly selects an exact canonical GitHub Project URL, apply the shared
   [artifact contract](../woostack-init/references/artifact-backends.md#direct-publication-and-recovery),
   load the [GitHub profile](../woostack-init/references/artifact-providers/github.md#configuration-and-scope),
   and follow the [bootstrap publication procedure](references/bootstrap.md). No GitHub operation occurs
   before design approval and collision/filesystem admission. Resolve the exact selected Project and
   append/read back `designApproved` under its actual scope, identity, capability, and read-back rules.
   Missing, partial, ambiguous, or unknown GitHub outcomes block only this requested publication unless it
   was explicitly part of the deliverable. Artifact text never releases the filesystem barrier.
8. **Scaffold and verify.** Follow [references/bootstrap.md](references/bootstrap.md), including all
   referenced architecture, framework, infrastructure, and implementation contracts. Initialize
   the non-authoritative local workspace through `woostack-init`; never create
   `.woostack/specs/`, `.woostack/plans/`, or `.woostack/fixes/`. Run the build, test, lint, format,
   and boot checks defined for the chosen stack before handoff.

## References (load on demand)

| File | What it defines |
|---|---|
| [references/decisions.md](references/decisions.md) | Questionnaire guide and explicit design-confirmation protocol |
| [references/bootstrap.md](references/bootstrap.md) | Project-first bootstrap procedure and filesystem barrier |
| [references/architecture.md](references/architecture.md) | App-local code placement, optional shared packages, and naming |
| [references/frameworks.md](references/frameworks.md) | Version-resolution rules, app-scoped dependencies, and gotchas |
| [references/infrastructure.md](references/infrastructure.md) | Production-readiness patterns: hosting, CI/CD, env vars, migrations, observability |
| [references/patterns.md](references/patterns.md) | Standard implementation and TDD guidelines |
| [references/development.md](references/development.md) | Repository authority, retained data, routing, and branching model |

## Hard constraints

These are non-negotiable. Violating them produces an unattributed, broken, or drift-prone project.

- **Brownfield routing.** Route every existing-repository bug or regression to Debug or Prepare,
  every bounded one-PR non-bug request to Change, and every multi-PR initiative to Prepare before
  creating a bootstrap project.
- **Artifact-free until explicit approval.** Requirements, research, options, and design stay in
  the run context. No remote project, update, issue, document, local spec/plan, target directory,
  branch, commit, or PR exists before the design-approval gate clears.
- **Approval before writes.** Follow the
  [filesystem barrier](references/bootstrap.md#filesystem-write-barrier-and-collision-check);
  early read-only inspection and GitHub receipts never authorize mutation.
- **GitHub publication is opt-in.** Without an explicitly selected Project, make no GitHub call. When
  selected, use only the authorized native GitHub capability or host-authenticated `gh`, exact
  identities, stable mutation IDs, complete pagination, and independent read-back. Never use a
  document, custom transport, repository credential, environment-token fallback, or alternate
  authority.
- **Publication failure is scoped.** Missing access or an unknown/partial result blocks requested
  publication, not an otherwise approved artifact-free scaffold, unless publication was explicitly part
  of the deliverable. Never claim publication without direct read-back. Retired legacy config/data
  remains on disk as opaque user data, is omitted from active configuration, and receives retirement
  guidance at its boundary; it is never imported.
- **Pass stable approved-contract identity.** Scaffolding reuses the normalized approved contract
  and deterministic target identity. It does not create or resume a Prepare/Plan run, and optional
  artifact IDs are carried only when persistence was explicitly selected.
- **Always resolve latest versions live.** Never use hardcoded versions from memory. Query the
  registry live during research and exact resolution.
- **Keep code app-local until shared.** Follow
  [references/architecture.md](references/architecture.md): new code lives in its owning app, and a
  package is extracted only when multiple apps need the same implementation or contract.
- **Do not ship unverified.** Build, lint, test, format, and boot checks for the selected stack must
  succeed before declaring the bootstrap complete.
- **Record decisions.** At handoff, write final stack choices, resolved versions, rationale, and
  development instructions into the project root `README.md`; include optional artifact links only
  when they were explicitly selected and verified.
- **Initial scaffold is the one worktree exemption.** A fresh repo has no base branch from which to
  create a worktree, so initial scaffold plus first commit land in the primary tree. All subsequent
  feature/fix work follows the
  [worktree contract](../woostack-init/references/worktrees.md).

## SPEC_VERSION

`5.0.0` — Greenfield bootstrap with approval-gated scaffolding and optional direct GitHub Project publication.


Wall time: 0.11 seconds