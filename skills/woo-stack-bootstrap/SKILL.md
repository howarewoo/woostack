---
name: woo-stack-bootstrap
description: Use when bootstrapping a new web, mobile, or API project from scratch — scaffolding a fresh monorepo, choosing which frameworks/hosting/data layer to use, or setting up architecture, CI, and conventions for a new full-stack app at current framework versions.
---

# woo-stack-bootstrap

## Overview

A spec — not a template — for bootstrapping AI-built web + mobile + API projects. It holds the *decisions* (frameworks, architecture, infrastructure, patterns) so an agent scaffolds a fresh repo at the latest framework versions without re-litigating choices every time. Templates rot; decisions don't.

**Core principle:** resolve versions live at bootstrap, never from memory.

## Invocation

Invoke with `/woo-stack-bootstrap <goal>`, where the goal is a plain-language description of what to build:

```
/woo-stack-bootstrap create a new mobile app for cataloging recipes
/woo-stack-bootstrap a SaaS dashboard with a marketing site and a billing API
```

From the goal, infer a *recommended* shape — surfaces, features, and provider choices — then walk the user through it (see Procedure). The goal seeds the recommendations; the user confirms or overrides every one.

## When to use

- Standing up a new full-stack project (any subset of web / landing / mobile / api).
- Deciding the stack: frameworks, hosting, data layer, CI, lint/test tooling.
- Laying out a monorepo with shared packages and import boundaries.

**Not for:** adding features to an already-bootstrapped project (use that project's own conventions), or single-surface throwaway scripts.

## Default stack

| Layer | Default |
|---|---|
| Web / Landing | Next.js (App Router) + React Compiler + shadcn/ui |
| Mobile | Expo + React Native + react-native-reusables + UniWind |
| API | Hono + oRPC |
| Data | TanStack Query + Zod + Supabase (Postgres, Auth, Storage) |
| Styling | Tailwind CSS (CSS-first) + shared theme |
| Build | Turborepo + pnpm catalog |
| Lint/format | Biome |
| Testing | Vitest, Jest (RN), Playwright |
| Hosting | Vercel (web + api) + Expo EAS (mobile) |

Defaults are overridable per project — record any deviation in the project's own README.

## Procedure

1. **Interpret the goal** — from the plain-language goal, infer a recommended shape: a project name, the surfaces it implies, candidate features, and which capabilities it likely needs. (E.g. "mobile app for cataloging recipes" → `mobile` surface, probably an `api` for sync, a `recipes` feature, Supabase Postgres + Storage for images + Auth for accounts; no billing unless monetized.) These are *recommendations*, not decisions — they seed step 2.
2. **Walk the user through every decision** — work through [references/decisions.md](references/decisions.md) before touching the filesystem. Present each relevant choice as a goal-aware recommendation with its default and alternatives, get an explicit answer (silence is not consent), resolve the genuine forks (e.g. API host), and treat capabilities (billing, email, flags, observability, …) as opt-in. **Do not scaffold any decision the user has not confirmed.**
3. **Read the references in order** (below) — they are binding rules, not suggestions.
4. **Follow [references/bootstrap.md](references/bootstrap.md) step by step** — it is the authoritative procedure.
5. **Verify** before declaring done: `pnpm install && pnpm typecheck && pnpm build && pnpm test && pnpm dev` — every surface boots on its expected port.

## References (load on demand)

| File | What it defines |
|---|---|
| [references/decisions.md](references/decisions.md) | Decision catalog + confirmation protocol — the pre-scaffold gate |
| [references/bootstrap.md](references/bootstrap.md) | Step-by-step bootstrap procedure — the spine |
| [references/architecture.md](references/architecture.md) | Monorepo layout, package tiers, import boundaries, naming |
| [references/frameworks.md](references/frameworks.md) | Recommended frameworks per layer, catalog protocol, **known gotchas** |
| [references/infrastructure.md](references/infrastructure.md) | Hosting, CI/CD, env, observability, auth, data layer |
| [references/patterns.md](references/patterns.md) | oRPC contracts, TanStack Query, RSC, navigation, TDD, feature exposure |
| [references/development.md](references/development.md) | Dev loop (brainstorm → merge) and branching model |

## Hard constraints

These are non-negotiable. Violating them produces a broken or drift-prone project.

- **Confirm before scaffolding.** Walk the user through [references/decisions.md](references/decisions.md) and get explicit sign-off on every relevant decision first. Never scaffold a choice the user hasn't confirmed; never silently apply a default.
- **Always resolve the latest versions before building.** Your training memory is stale — treat every version you "remember" as wrong. For every dependency, query the registry at bootstrap time (`npm view <pkg> version`, or `npm view <pkg> dist-tags` for channels) and write the resolved value. Never hard-code a version from memory.
- **Cross-check the gotchas.** Reconcile every resolved version against [references/frameworks.md](references/frameworks.md#known-gotchas-to-respect-at-bootstrap) before writing it — some peers (notably `react` for RN) must match a pinned version.
- **Match the layout exactly.** Follow [references/architecture.md](references/architecture.md); omit only folders for surfaces not requested.
- **Don't ship unverified.** A bootstrap that fails `install / typecheck / build / test / dev` is not done. Fix every failure.
- **Project docs reference, don't duplicate.** The generated project's README points back at this spec; record deviations explicitly.

## SPEC_VERSION

`2.0.0` — first spec-only release. Bump on breaking changes so downstream projects can detect drift.
