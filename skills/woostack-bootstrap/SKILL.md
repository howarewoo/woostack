---
name: woostack-bootstrap
description: Use when bootstrapping a new web, mobile, or API project from scratch — scaffolding a fresh monorepo, gathering requirements, dynamically researching industry-standard frameworks/services and their latest versions, and setting up the app/feature/infrastructure package slice architecture.
---

# woostack-bootstrap

## Overview

A spec — not a template — for bootstrapping AI-built full-stack projects. Instead of prescribing a hardcoded stack, this skill guides the agent to dynamically gather the project's requirements, look up the latest industry-standard solutions and versions, compare 2-3 options with pros/cons, and then bootstrap the chosen services using the app, feature, and infrastructure package slice architecture.

**Core principle:** resolve technologies and versions live based on project requirements, never from memory.

## Invocation

Invoke with `/woostack-bootstrap <goal>`, where the goal is a plain-language description of what to build:

```
/woostack-bootstrap create a new mobile app for cataloging recipes
/woostack-bootstrap a SaaS dashboard with a marketing site and a billing API
```

The goal seeds the initial requirements-gathering and recommendation phase.

## When to use

- Standing up a new full-stack project (any combination of web / mobile / desktop / api / daemon).
- Determining the stack: cloud hosting, data layer, auth, libraries, CI/CD, linting, and testing tooling.
- Laying out a monorepo with custom packages and import boundaries.

**Not for:** adding features to an already-bootstrapped project (use that project's own conventions), or single-surface throwaway scripts.

## Procedure

1. **Gather requirements** — Upon invocation, ask the user targeted questions about their goals to capture technical and business constraints (e.g. expected scale, deployment/cloud provider restrictions, compliance/security, external API integrations, budget).
2. **Perform live industry research** — Use web search and registry lookup commands (e.g. `npm view`) to identify current industry-standard frameworks, libraries, databases, and services that satisfy the requirements, ensuring you ground your choices in the latest stable versions.
3. **Present stack options** — Compile and present 2-3 cohesive stack options (e.g., Option A: Serverless Edge, Option B: Containerized VPS, Option C: Managed PaaS/BaaS) with a clear Pros/Cons breakdown, production-readiness evaluation, and cost implications for each. Get an explicit choice from the user before proceeding.
4. **Walk through reference files** — Study and follow the generalized reference documents before writing code:
   - [references/decisions.md](references/decisions.md)
   - [references/bootstrap.md](references/bootstrap.md)
   - [references/architecture.md](references/architecture.md)
   - [references/frameworks.md](references/frameworks.md)
   - [references/infrastructure.md](references/infrastructure.md)
5. **Scaffold skeleton & run CLIs** — Create the monorepo structure. Run the appropriate CLI scaffolding tools for the chosen frameworks and clean up their generated boilerplates.
6. **Verify** — Run the build, test, lint, and format pipelines defined for the stack to ensure every surface compiles and boots correctly.

## References (load on demand)

| File | What it defines |
|---|---|
| [references/decisions.md](references/decisions.md) | Questionnaire guide + confirmation protocol — the pre-scaffold gate |
| [references/bootstrap.md](references/bootstrap.md) | Step-by-step bootstrap procedure — the spine |
| [references/architecture.md](references/architecture.md) | Monorepo layout, package tiers, import boundaries, naming |
| [references/frameworks.md](references/frameworks.md) | Version-resolution rules, workspace catalogs, and Gotchas |
| [references/infrastructure.md](references/infrastructure.md) | Production-readiness patterns: hosting, CI/CD, env vars, migrations, observability |
| [references/patterns.md](references/patterns.md) | Standard implementation and TDD guidelines |
| [references/development.md](references/development.md) | Dev loop (ideate → approve spec → merge) and branching model |

## Hard constraints

These are non-negotiable. Violating them produces a broken or drift-prone project.

- **Confirm stack before scaffolding.** Present the pros/cons of the options and get explicit sign-off from the user before touching the filesystem. Never silently choose or scaffold a stack.
- **Always resolve latest versions live.** Never use hardcoded versions from memory. Query the registry live (`npm view <pkg> version` or equivalent commands) during the research phase.
- **Maintain package slice architecture.** Strictly follow [references/architecture.md](references/architecture.md) for package layering (`Apps -> Features -> Infrastructure`), regardless of the chosen technology stack.
- **Don't ship unverified.** Running build, lint, and test scripts must succeed before declaring the bootstrap complete.
- **Record decisions.** Write the finalized stack choices, versions, and rationale into the project's root `README.md` at hand-off.
- **Initial scaffold is the one worktree exemption.** A fresh repo has no base branch to `git worktree` from, so the initial scaffold + first commit land in the primary tree. All *subsequent* feature/fix work goes through `woostack-build` / `woostack-fix`, which author each PR inside its own worktree per the [worktree contract](../woostack-init/references/worktrees.md). Bootstrap itself adds no worktree create/teardown step.

## SPEC_VERSION

`3.0.0` — Major breaking release moving to dynamic stack selection and dynamic lookup.

