---
name: woostack-bootstrap
description: Bootstrap a genuinely greenfield web, mobile, desktop, API, or daemon project from scratch—gather requirements, research current technologies, approve the design, collision-check the target, and scaffold app-local code with shared packages only when needed. An explicitly selected GitHub Project may retain the approved design.
---

# woostack-bootstrap

## Overview

Bootstrap is the greenfield, project-first entry point. It gathers requirements, resolves current
technologies and versions live, presents a complete architecture and scope, and waits for explicit
design approval before any target-directory write. That approval—not a provider receipt—releases
the write barrier once the target collision check passes. A local scaffold needs no GitHub
repository, account, remote URL, or Project.

The stack remains dynamic rather than template-selected. Validate the user's supplied stack against
the project's requirements, then scaffold each approved app with code local to that app.
Extract a package only when multiple apps need the same code. An explicitly selected GitHub Project
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

- unresolved bugs, regressions, incidents, and root-cause work → [`woostack-debug`](../woostack-debug/SKILL.md)
  for diagnosis; a proved defect needing an issue plan → [`woostack-plan`](../woostack-plan/SKILL.md);
- a bounded enhancement, refactor, or test task that fits one reviewable PR (including a one-file
  request), or an authorized defect correction with causal proof that fits one reviewable PR →
  [`woostack-execute`](../woostack-execute/SKILL.md);
- a multi-PR feature or architectural initiative → [`woostack-plan`](../woostack-plan/SKILL.md).

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

5. **Admit the filesystem write barrier.** Follow the canonical
   [collision-check procedure](references/bootstrap.md#filesystem-write-barrier-and-collision-check)
   after design approval. The approved scope and the actual selected target stay in conversation
   context; create no run record, hash, or manifest to stand in for them. Early inspection cannot
   replace the fresh pre-write check.
6. **Optionally set up a remote or publish the approved design.** Only after design approval and
   target collision checks pass, and only when the caller explicitly requests remote setup or selects
   an exact GitHub Project, apply the shared
   [artifact contract](../woostack-init/references/artifact-backends.md#direct-publication-and-recovery),
   load the [Project content contract](../woostack-init/references/artifact-providers/github.md#selected-project-content),
   and follow the [bootstrap publication procedure](references/bootstrap.md). No GitHub operation occurs
   before design approval and collision/filesystem admission. Resolve the exact selected destination and
   append/read back `designApproved` under its actual scope, identity, capability, and read-back rules.
   Missing, partial, ambiguous, or unknown GitHub outcomes block only that requested operation unless it
   was explicitly part of the deliverable. Artifact text never releases the filesystem barrier.
7. **Scaffold and verify.** Follow [references/bootstrap.md](references/bootstrap.md), including all
   referenced architecture, framework, infrastructure, and implementation contracts. Invoke
   [`woostack-init`](../woostack-init/SKILL.md) only when the user selects Woostack adoption for the
   project or the generated project actually needs its support. Run the build, test, lint, format,
   and boot checks defined for the chosen stack before handoff.

## References (load on demand)

| File | What it defines |
|---|---|
| [references/decisions.md](references/decisions.md) | Questionnaire guide and explicit design-confirmation protocol |
| [references/bootstrap.md](references/bootstrap.md) | Collision-safe bootstrap and optional GitHub publication |
| [references/architecture.md](references/architecture.md) | App-local code placement, optional shared packages, and naming |
| [references/frameworks.md](references/frameworks.md) | Version-resolution rules, app-scoped dependencies, and gotchas |
| [references/infrastructure.md](references/infrastructure.md) | Production-readiness patterns: hosting, CI/CD, env vars, migrations, observability |
| [references/patterns.md](references/patterns.md) | Standard implementation patterns; canonical testing guidance is in [Execute](../woostack-execute/references/tdd.md) |
| [references/development.md](references/development.md) | Repository authority, retained data, routing, and branching model |

## Hard constraints

These are non-negotiable. Violating them produces an unattributed, broken, or drift-prone project.

- **Brownfield routing.** Route a request solely for diagnosis to read-only Debug, issue planning
  to Plan, and authorized bounded enhancements, refactors, tests, and corrections to Execute.
  Execute establishes a defect's cause before repair, inline when evidence suffices.
- **Artifact-free until explicit approval.** Requirements, research, options, and design stay in
  the run context. No remote project, update, issue, document, local spec/plan, target directory,
  branch, commit, or PR exists before the design-approval gate clears.
- **Approval before writes.** Follow the
  [filesystem barrier](references/bootstrap.md#filesystem-write-barrier-and-collision-check);
  early read-only inspection and GitHub receipts never authorize mutation.
- **Remote work is opt-in.** A local-only scaffold makes no GitHub call and needs no account,
  Project, remote URL, push, or PR; never infer a repository name or create a remote resource to
  satisfy a local deliverable. When remote setup or publication is requested, use only the authorized
  native GitHub capability or host-authenticated `gh`, exact identities, stable mutation IDs,
  complete pagination, and independent read-back. Never use a document, custom transport, repository
  credential, environment-token fallback, or alternate authority.
- **Publication failure is scoped.** Missing access or an unknown/partial result blocks requested
  publication, not an otherwise approved artifact-free scaffold, unless publication was explicitly part
  of the deliverable. Never claim publication without direct read-back. Retired legacy config/data
  remains on disk as opaque user data, is omitted from active configuration, and receives retirement
  guidance at its boundary; it is never imported.
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

## SPEC_VERSION

`6.0.0` — Local-first greenfield bootstrap: approval-gated scaffolding with no mandatory remote, and optional direct GitHub Project publication.
