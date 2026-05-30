---
name: woo-stack
description: Use when bootstrapping a new web, mobile, or API project from scratch — scaffolding a fresh monorepo, choosing which frameworks/hosting/data layer to use, or setting up architecture, CI, and conventions for a new full-stack app at current framework versions.
---

# woo-stack

## Overview

A spec — not a template — for bootstrapping AI-built web + mobile + API projects. It holds the *decisions* (frameworks, architecture, infrastructure, patterns) so an agent scaffolds a fresh repo at the latest framework versions without re-litigating choices every time. Templates rot; decisions don't.

**Core principle:** resolve versions live at bootstrap, never from memory.

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

1. **Gather inputs** — project name, surfaces (`web`/`landing`/`mobile`/`api`), initial features, hosting target, repo host.
2. **Read the references in order** (below) — they are binding rules, not suggestions.
3. **Follow [references/bootstrap.md](references/bootstrap.md) step by step** — it is the authoritative procedure.
4. **Verify** before declaring done: `pnpm install && pnpm typecheck && pnpm build && pnpm test && pnpm dev` — every surface boots on its expected port.

## References (load on demand)

| File | What it defines |
|---|---|
| [references/bootstrap.md](references/bootstrap.md) | Step-by-step bootstrap procedure — the spine |
| [references/architecture.md](references/architecture.md) | Monorepo layout, package tiers, import boundaries, naming |
| [references/frameworks.md](references/frameworks.md) | Recommended frameworks per layer, catalog protocol, **known gotchas** |
| [references/infrastructure.md](references/infrastructure.md) | Hosting, CI/CD, env, observability, auth, data layer |
| [references/patterns.md](references/patterns.md) | oRPC contracts, TanStack Query, RSC, navigation, TDD, feature exposure |
| [references/development.md](references/development.md) | Dev loop (brainstorm → merge) and branching model |

## Hard constraints

These are non-negotiable. Violating them produces a broken or drift-prone project.

- **Resolve versions live.** For every catalog entry, run `npm view <pkg> version`. Never hard-code versions from memory or training data.
- **Cross-check the gotchas.** Reconcile every resolved version against [references/frameworks.md](references/frameworks.md#known-gotchas-to-respect-at-bootstrap) before writing it — some peers (notably `react` for RN) must match a pinned version.
- **Match the layout exactly.** Follow [references/architecture.md](references/architecture.md); omit only folders for surfaces not requested.
- **Don't ship unverified.** A bootstrap that fails `install / typecheck / build / test / dev` is not done. Fix every failure.
- **Project docs reference, don't duplicate.** The generated project's README points back at this spec; record deviations explicitly.

## SPEC_VERSION

`2.0.0` — first spec-only release. Bump on breaking changes so downstream projects can detect drift.
