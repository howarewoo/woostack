---
name: woostack-bootstrap
description: Bootstrap a genuinely greenfield web, mobile, desktop, API, or daemon project from scratch—gather requirements, research current technologies, approve the design, collision-check the target, and scaffold the app/feature/infrastructure package slices. Linear or Plane artifacts are optional.
---

# woostack-bootstrap

## Overview

Bootstrap is the greenfield, project-first entry point. It gathers requirements, resolves current
technologies and versions live, presents a complete architecture and scope, and waits for explicit
design approval before any target-directory write. That approval—not a provider receipt—releases
the write barrier after repository and target collision checks pass.

The stack remains dynamic rather than template-selected. Compare current production-ready options
against the project's requirements, then scaffold the approved app, feature, and infrastructure
package slices under a stable in-run project identity. An exact Linear or Plane feature project may persist
the approved design and requested delivery notes, but is optional and never authorizes writes.

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
   and initial features. Keep the design only in the conversation/run context: create no remote project/issue,
   local spec or plan, target directory, branch, commit, or PR.

<HARD-GATE name="design-approval">
Wait for explicit approval of the complete presented design. Silence, an initial goal, a stack
preference, partial agreement, or approval inferred by the agent does not clear this gate. Before
approval, perform no official-MCP development mutation and create no development artifact.
</HARD-GATE>

5. **Establish repository/base intent and stable run identity.** Only after approval, retain the
   exact canonical future `https://github.com/<owner>/<repository>` URL, intended integration/base
   branch, normalized approved goal/scope, and a deterministic in-run project identity. This
   identity prevents duplicate work within/resumed from the same supplied contract; it is not a
   development record.
6. **Optionally persist the approved design.** Only when the caller explicitly requests provider
   persistence or supplies an exact project URL/UUID, apply the shared
   [artifact contract](../woostack-init/references/artifact-backends.md), load only the selected
   [Linear](../woostack-init/references/artifact-providers/linear.md) or
   [Plane](../woostack-init/references/artifact-providers/plane.md) profile, and follow the
   [bootstrap persistence procedure](references/bootstrap.md). Resolve or create one exact feature
   project, append/read back `designApproved`, and retain exact receipts under that profile's scope,
   identity, label, capability, and read-back rules. Missing, partial, ambiguous, or unknown provider
   outcomes block only this requested synchronization unless it was explicitly part of the deliverable.
   Artifact text and receipts never release the filesystem barrier.
7. **Collision-check the target.** After design approval and repository/base intent are retained,
   perform the first target-filesystem action: a read-only collision check with no Git invocation.
   Proceed only when it proves the target is absent or an empty non-Git directory. A populated
   path, existing Git checkout, non-directory/symlink, unreadable state, partial result, or
   ambiguity blocks before mkdir, write, scaffold, or Git.
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
| [references/architecture.md](references/architecture.md) | Monorepo layout, package tiers, import boundaries, naming |
| [references/frameworks.md](references/frameworks.md) | Version-resolution rules, workspace catalogs, and gotchas |
| [references/infrastructure.md](references/infrastructure.md) | Production-readiness patterns: hosting, CI/CD, env vars, migrations, observability |
| [references/patterns.md](references/patterns.md) | Standard implementation and TDD guidelines |
| [references/development.md](references/development.md) | Repository authority, optional artifacts, routing, and branching model |

## Hard constraints

These are non-negotiable. Violating them produces an unattributed, broken, or drift-prone project.

- **Greenfield only.** Route every brownfield bug, bounded one-PR request, or multi-PR initiative to
  fix, change, or build before creating a bootstrap project.
- **Artifact-free until explicit approval.** Requirements, research, options, and design stay in
  the run context. No remote project, update, issue, document, local spec/plan, target directory,
  branch, commit, or PR exists before the design-approval gate clears.
- **Approval before filesystem.** Missing design approval or repository/base intent means no stat,
  list, read, canonicalization, creation, write, scaffolding CLI, or Git operation against the
  target. Provider persistence is not part of this barrier.
- **Artifacts are opt-in.** Without explicit selection, make no provider call. When selected, use
  only the configured official host-exposed Linear or Plane MCP, exact identities, stable mutation
  IDs, complete pagination, and independent read-back. Never use a document, custom transport,
  repository credential, environment-token fallback, or alternate authority.
- **Artifact failure is scoped.** Missing access or an unknown/partial result blocks requested
  persistence, not an otherwise approved artifact-free scaffold, unless persistence was explicitly
  part of the deliverable. Never claim synchronization without direct read-back.
- **Collision-safe first access.** After approval, the first target-filesystem action is a
  read-only collision check. Only an absent target or empty non-Git directory permits
  creation/scaffolding; any populated, Git-owned, unreadable, or ambiguous state blocks mutation.
- **Pass stable run identity.** Scaffolding and later build/planning continuation reuse the
  normalized approved contract and deterministic task/project identity. Optional artifact IDs are
  carried only when persistence was selected.
- **Confirm the stack before scaffolding.** Present options and receive explicit approval; never
  silently choose or scaffold a stack.
- **Always resolve latest versions live.** Never use hardcoded versions from memory. Query the
  registry live during research and exact resolution.
- **Maintain package slice architecture.** Strictly follow
  [references/architecture.md](references/architecture.md) for package layering
  (`Apps -> Features -> Infrastructure`) regardless of the chosen technology stack.
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

`5.0.0` — Greenfield bootstrap with approval-gated scaffolding and optional Linear/Plane persistence.


Wall time: 0.11 seconds