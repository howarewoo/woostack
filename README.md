<div align="center">

# monorepo-template

**Ship web, mobile, and API from a single codebase.**\
Type-safe from database to device, with shared packages that keep your team moving fast.

[![CI](https://github.com/howarewoo/monorepo-template/actions/workflows/ci.yml/badge.svg)](https://github.com/howarewoo/monorepo-template/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

<img src="docs/web-app.png" alt="Web app screenshot" width="680">

<details>
<summary>Landing page</summary>
<br>
<img src="docs/landing-page.png" alt="Landing page screenshot" width="680">
</details>

</div>

---

## Table of Contents

- [Why This Template?](#why-this-template)
- [Features](#features)
- [Tech Stack](#tech-stack)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Architecture](#architecture)
- [Scripts](#scripts)
- [Key Patterns](#key-patterns)
- [AI-First Documentation](#ai-first-documentation)
- [Contributing](#contributing)
- [Acknowledgments](#acknowledgments)
- [License](#license)

## Why This Template?

Starting a multi-platform project usually means stitching together separate repos, duplicating types, and fighting config drift. This template solves that:

- **One repo, three platforms** — Web, mobile, and API share code from day one with no copy-paste
- **Type safety everywhere** — oRPC contracts generate typed clients so API changes break at compile time, not in production
- **Production-ready CI** — GitHub Actions, Biome linting, Vitest tests, and Playwright E2E wired up out of the box
- **Modern defaults** — React 19, Next.js 16, Expo SDK 54, Tailwind v4, and Turborepo with zero legacy baggage

## Features

- **Shared by default** — Design tokens, navigation, UI components, and utilities live in shared packages consumed by every app
- **Type-safe end to end** — oRPC contracts generate typed clients; mismatches caught at compile time
- **Cross-platform** — Next.js 16 web + Expo SDK 54 mobile + Hono API, all in one repo
- **Modern tooling** — React 19, React Compiler, Tailwind v4, Turborepo, Biome, pnpm
- **Auth & database built in** — Supabase provides authentication, PostgreSQL with Row Level Security, and auto-generated TypeScript types
- **Production CI/CD** — GitHub Actions for linting, testing, and database migrations on every PR

## Tech Stack

| Layer | Technology | Role |
| --- | --- | --- |
| **Frontend (Web)** | Next.js 16, React 19, React Compiler | App Router with automatic memoization |
| **Frontend (Mobile)** | Expo SDK 54, React Native 0.81, Expo Router | iOS, Android, and mobile web with file-based routing |
| **API** | Hono, oRPC | Lightweight server with end-to-end typed RPC |
| **Database & Auth** | Supabase, PostgreSQL | Auth, Row Level Security, type-safe database client |
| **Styling** | Tailwind v4, shadcn/ui, UniWind | CSS-first config; shared design tokens across platforms |
| **Language** | TypeScript | Strict types everywhere, no `any` |
| **Monorepo** | Turborepo, pnpm | Cached builds, workspace dependency catalog |
| **Quality** | Biome, Vitest, Playwright | Lint + format, unit tests, E2E tests |

## Prerequisites

- **Node.js 22** — [download](https://nodejs.org/) or use a version manager like `fnm` / `nvm`
- **pnpm 10.29.3** — install via `corepack enable && corepack prepare pnpm@10.29.3 --activate`
- **Docker** — required for local Supabase (database and auth)

## Quick Start

```bash
git clone https://github.com/howarewoo/monorepo-template.git
cd monorepo-template
pnpm install

# Optional: start local Supabase (requires Docker)
pnpm --filter supabase-db start
cp apps/api/.env.example apps/api/.env
cp apps/web/.env.local.example apps/web/.env.local
# Fill in values from the Supabase start output

pnpm dev
```

| App | Port |
| --- | --- |
| Web | [localhost:3000](http://localhost:3000) |
| API | [localhost:3001](http://localhost:3001) |
| Landing | [localhost:3002](http://localhost:3002) |
| Mobile | [localhost:8081](http://localhost:8081) |

## Architecture

```
monorepo-template/
├── apps/
│   ├── web/           Next.js 16 — App Router, React Compiler, shadcn/ui
│   ├── landing/       Next.js 16 — Marketing page
│   ├── mobile/        Expo SDK 54 — iOS, Android, Web
│   ├── api/           Hono + oRPC — Type-safe API server
│   └── supabase/      Supabase CLI — Config, migrations, seed data
├── packages/
│   ├── features/      Business logic — contracts, routers, procedures
│   └── infrastructure/
│       ├── api-client        oRPC client utilities, shared schemas
│       ├── navigation        Platform-agnostic Link + useNavigation
│       ├── supabase          Auth hooks, typed clients, middleware
│       ├── ui                Design tokens, cn(), theme CSS
│       ├── ui-web            Shared shadcn/ui components
│       ├── utils             Cross-platform helpers
│       └── typescript-config Shared tsconfig presets
```

Three-tier dependency flow:

```
  Apps  →  Features  →  Infrastructure
  (web, mobile, api)    (business logic)    (shared utilities)
```

- **Infrastructure** — shared utilities, used by everything
- **Features** — standalone business logic, imports only infrastructure
- **Apps** — compose infrastructure + features into deployable units

## Scripts

| Command | Description |
| --- | --- |
| `pnpm dev` | Start all apps in development |
| `pnpm build` | Build all packages via Turborepo |
| `pnpm test` | Run Vitest tests |
| `pnpm test:changed` | Test only packages changed since last commit |
| `pnpm test:e2e` | Run Playwright E2E tests |
| `pnpm typecheck` | Type check all packages |
| `pnpm lint` | Lint with Biome |
| `pnpm format` | Format with Biome |
| `pnpm clean` | Remove build artifacts and node_modules |
| `pnpm --filter supabase-db start` | Start local Supabase (requires Docker) |
| `pnpm --filter supabase-db stop` | Stop local Supabase |
| `pnpm --filter supabase-db reset` | Reset database (reapply migrations + seed) |
| `pnpm gencode` | Generate Router types + Supabase DB types |
| `pnpm --filter <app> dev` | Run a single app (e.g. `pnpm --filter web dev`) |

## Key Patterns

**Type-safe API** — features own contracts, the API app composes routers, and every client is fully typed:

```typescript
// 1. Feature defines contract (packages/features/users/src/contracts/usersContract.ts)
export const UserSchema = z.object({ id: z.string(), name: z.string() });
```
```typescript
// 2. API app composes feature routers (apps/api/src/router.ts)
import { usersRouter } from "@features/users/src/routers/usersORPCRouter";
export const router = { users: usersRouter };
export type Router = typeof router;
```
```typescript
// 3. Use anywhere with full type safety
const { data } = useQuery(orpc.users.list.queryOptions());
```

**Cross-platform navigation** — works on web (Next.js) and mobile (Expo) identically:

```typescript
import { Link, useNavigation } from "@infrastructure/navigation";
```

**Shared components** — shadcn/ui components shared across web apps:

```typescript
import { Button, Card } from "@infrastructure/ui-web";
```

**Authentication & database** — Supabase provides auth, PostgreSQL with Row Level Security, and typed clients:

```typescript
// Auth context in client apps
import { AuthProvider, useAuth, useUser } from "@infrastructure/supabase";

// Typed database access in API procedures (via oRPC context)
const user = context.user;        // authenticated user or undefined
const db = context.supabase;      // RLS-scoped Supabase client
```

**Dependency catalog** — single source of truth for shared versions:

```yaml
# pnpm-workspace.yaml
catalog:
  react: "19.1.0"
  next: "^16.0.0"
```

## AI-First Documentation

This repo uses documentation that serves as executable context for AI coding agents, so the AI follows the same rules as human contributors.

| File | Purpose | When to update |
| --- | --- | --- |
| `eng-constitution.md` | Binding engineering principles — architecture, code style, TDD, API stability. The AI agent treats these as non-negotiable rules. | When adding new architectural decisions or changing existing principles |
| `.claude/CLAUDE.md` | Operational instructions for Claude Code — commands, gotchas, key patterns, conventions. Loaded into every AI session. | When discovering new gotchas, adding packages, or changing workflows |
| `.claude/skills/*` | Automated workflows (PR review, commit, worktree). Define multi-step procedures the AI executes. | When adding or modifying automated development workflows |
| `.claude/commands/*` | Slash commands that invoke skills (e.g., `/commit`, `/pr-review`). | When exposing new skills as user-invocable commands |

The constitution sets the rules, CLAUDE.md provides operational details, and skills automate recurring tasks. When the AI agent works on this codebase, it reads these files and follows them as constraints — enforcing TDD, import boundaries, naming conventions, etc. without being told each time.

## Contributing

Contributions are welcome! Whether it's a bug fix, new feature, or documentation improvement — we'd love your help.

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup and workflow. Architectural decisions are documented in the [engineering constitution](eng-constitution.md).

## Acknowledgments

Built with [Next.js](https://nextjs.org/), [Expo](https://expo.dev/), [Hono](https://hono.dev/), [oRPC](https://orpc.unnoq.com/), [Supabase](https://supabase.com/), [Tailwind CSS](https://tailwindcss.com/), [shadcn/ui](https://ui.shadcn.com/), [Turborepo](https://turbo.build/), and [Biome](https://biomejs.dev/).

## License

[MIT](LICENSE) &copy; Adam Woo
