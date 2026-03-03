# Codebase Structure

**Analysis Date:** 2026-03-02

## Directory Layout

```
monorepo-template/
├── apps/                           # Deployable applications
│   ├── web/                        # Next.js 16 web app (port 3001)
│   │   ├── app/                    # App Router directory (Next.js)
│   │   │   ├── (auth)/             # Auth page group (sign-in, sign-up, reset-password, forgot-password)
│   │   │   ├── (protected)/        # Protected page group (dashboard, settings)
│   │   │   ├── layout.tsx          # Root layout with metadata
│   │   │   ├── providers.tsx       # Client-side providers (Auth, Query, Navigation)
│   │   │   ├── page.tsx            # Home page (redirects based on auth)
│   │   │   └── globals.css         # Global styles and Tailwind imports
│   │   ├── components/             # App-specific components
│   │   ├── lib/                    # App-specific utilities (supabase.ts, navigation.tsx)
│   │   ├── hooks/                  # App-specific React hooks
│   │   ├── e2e/                    # Playwright E2E tests
│   │   └── package.json            # Web app dependencies
│   ├── landing/                    # Next.js 16 landing page (port 3000)
│   │   ├── app/                    # App Router directory
│   │   │   ├── layout.tsx          # Root layout
│   │   │   └── page.tsx            # Landing page
│   │   ├── components/             # Landing-specific components
│   │   └── package.json            # Landing dependencies
│   ├── api/                        # Hono API server (port 3100)
│   │   ├── src/
│   │   │   ├── app.ts              # Hono app with middleware (CORS, Supabase)
│   │   │   ├── router.ts           # oRPC router composition (imports feature routers)
│   │   │   └── index.ts            # Server entry point
│   │   └── package.json            # API dependencies
│   ├── mobile/                     # Expo SDK 54 + React Native app
│   │   ├── app/                    # Expo Router directory
│   │   │   ├── _layout.tsx         # Root layout with providers
│   │   │   └── index.tsx           # Home screen
│   │   ├── components/             # Mobile components
│   │   ├── lib/                    # Mobile utilities (supabase.ts, navigation.tsx)
│   │   ├── global.css              # UniWind theme tokens (hardcoded HSL)
│   │   └── package.json            # Mobile dependencies
│   └── supabase/                   # Supabase CLI project
│       ├── config.toml             # Supabase local config
│       ├── migrations/             # SQL migration files
│       └── seed.sql                # Database seed data
├── packages/
│   ├── features/                   # Feature packages (business logic)
│   │   ├── auth/                   # Auth schemas
│   │   │   ├── src/
│   │   │   │   ├── contracts/      # Zod schemas (SignInSchema, SignUpSchema, etc.)
│   │   │   │   └── index.ts        # Named exports of schemas
│   │   │   └── package.json
│   │   └── users/                  # User feature
│   │       ├── src/
│   │       │   ├── contracts/      # Zod schemas (UserSchema, CreateUserSchema, etc.)
│   │       │   ├── routers/        # oRPC routers (usersORPCRouter)
│   │       │   └── index.ts        # Default export of router
│   │       └── package.json
│   └── infrastructure/             # Shared infrastructure packages (scoped @infrastructure/*)
│       ├── api-client/             # oRPC client utilities
│       │   ├── src/
│       │   │   ├── client.ts       # Generic createApiClient, createOrpcUtils
│       │   │   ├── typed-client.ts # Pre-typed wrappers (createTypedApiClient)
│       │   │   ├── contract.ts     # Shared schemas (MessageSchema)
│       │   │   ├── generated/      # Auto-generated (router-types.d.ts)
│       │   │   └── index.ts        # Main exports
│       │   └── package.json
│       ├── supabase/                # Supabase client utilities
│       │   ├── src/
│       │   │   ├── clients/        # Multi-context clients (browser, server, SSR variants)
│       │   │   ├── auth/           # AuthProvider, useAuth(), useUser() hooks
│       │   │   ├── storage/        # Storage client factory
│       │   │   ├── middleware/     # Hono and Next.js middleware
│       │   │   ├── types/          # TypeScript type helpers (SupabaseUser, TypedSupabaseClient)
│       │   │   ├── generated/      # Auto-generated database.d.ts
│       │   │   └── index.ts        # Main exports
│       │   └── package.json
│       ├── navigation/              # Platform-agnostic navigation abstraction
│       │   ├── src/
│       │   │   ├── types.ts        # LinkProps, NavigationContextValue, Router type
│       │   │   ├── Link.tsx        # Base Link component interface
│       │   │   ├── NavigationProvider.tsx # Context provider
│       │   │   ├── useNavigation.ts # Hook to consume navigation context
│       │   │   └── index.ts        # Exports
│       │   └── package.json
│       ├── ui/                      # Shared design tokens and utilities
│       │   ├── src/
│       │   │   ├── globals.css     # Theme tokens (Tailwind v4 CSS-first)
│       │   │   ├── tokens.ts       # TypeScript theme token exports
│       │   │   ├── cn.ts           # Tailwind class merger utility
│       │   │   └── index.ts        # Exports
│       │   └── package.json
│       ├── ui-web/                  # Web-specific UI components (shadcn/ui)
│       │   ├── src/
│       │   │   ├── components/     # Shared components (Button, Card, Field, Input, etc.)
│       │   │   └── index.ts        # Named exports of components
│       │   └── package.json
│       ├── utils/                   # Cross-platform utility functions
│       │   ├── src/
│       │   │   └── index.ts        # Utility exports
│       │   └── package.json
│       └── typescript-config/       # Shared TypeScript configurations
│           └── package.json        # Re-exports tsconfig files
├── .github/
│   └── workflows/
│       └── ci.yml                  # GitHub Actions CI (lint, build, test)
├── .claude/                         # Claude Code configuration
│   ├── CLAUDE.md                   # Project instructions
│   ├── agents/                      # Custom agent definitions
│   └── commands/gsd/               # Get-Shit-Done command definitions
├── pnpm-workspace.yaml              # Workspace config and dependency catalog
├── turbo.json                       # Turborepo build orchestration
├── package.json                     # Root scripts and shared devDependencies
├── tsconfig.json                    # Root TypeScript base config
├── biome.json                       # Biome linter/formatter config
└── eng-constitution.md              # Project principles and rules
```

## Directory Purposes

**`apps/`:**
- Purpose: Standalone deployable applications with their own entry points and routing
- Each app is independently startable and buildable
- Apps define page hierarchy, layout, and middleware specific to their platform

**`apps/web`:**
- Purpose: Customer-facing web application built with Next.js 16 App Router
- Port 3001 (in development)
- Uses shadcn/ui components and Tailwind CSS
- Supports server-side rendering (SSR) and static generation
- App-specific authentication and protected route groups

**`apps/landing`:**
- Purpose: Marketing/landing page (public)
- Port 3000 (in development)
- Consumes shared UI components from `@infrastructure/ui-web`
- No auth provider (public-only content)

**`apps/api`:**
- Purpose: Type-safe REST-like API server
- Port 3100 (in development)
- oRPC router composition layer; Hono request handler
- Integrates Supabase auth middleware for JWT extraction and RLS context setup
- No database direct access — all data queries go through Supabase client with user context

**`apps/mobile`:**
- Purpose: React Native mobile application via Expo
- Shares navigation abstraction and auth with web app
- Uses UniWind for Tailwind-like styling on React Native
- Supports iOS, Android, and web via Expo

**`apps/supabase`:**
- Purpose: Supabase CLI project configuration and migration management
- `migrations/` contains numbered SQL files applied in order
- `config.toml` defines local Supabase settings (API port, database config)
- `seed.sql` populates initial data for local development
- Run `pnpm --filter supabase-db start` to spin up Docker-based local Supabase
- Run `pnpm gencode` after migrations to regenerate TypeScript types

**`packages/features/`:**
- Purpose: Feature-driven business logic with zero platform coupling
- Each feature owns:
  - `contracts/` — Zod schemas (input/output validation, type inference)
  - `routers/` — oRPC router definitions (procedures with handlers)
  - `index.ts` — Default export of router (for API composition) or named exports of schemas (for client consumption)
- Feature packages **never import from apps**; they only depend on infrastructure packages
- Feature schemas are portable — same schema used in mobile forms, server validation, and API responses

**`packages/features/auth`:**
- Purpose: Authentication schemas (sign-in, sign-up, password reset)
- Exports: `SignInSchema`, `SignUpSchema`, `ForgotPasswordSchema`, `ResetPasswordSchema`
- No procedures/routers — schemas only (auth logic is Supabase responsibility)

**`packages/features/users`:**
- Purpose: User data feature with example CRUD procedures
- Exports: `usersRouter` (default export) for API composition
- Procedures: `list`, `get(id)`, `create(name, email)`
- Demonstrates oRPC pattern with Zod input/output validation

**`packages/infrastructure/`:**
- Purpose: Shared utilities usable by any app or feature
- Scoped namespace `@infrastructure/*` to distinguish from features
- Infrastructure packages **can be used anywhere** but never depend on features or apps
- Types, clients, hooks, components, and utilities all live here

**`packages/infrastructure/api-client`:**
- Purpose: Factory functions for creating oRPC clients
- Exports: `createApiClient()`, `createOrpcUtils()`, pre-typed wrappers
- `generated/router-types.d.ts` — Auto-generated Router type (via `pnpm gencode`)
- Used by: Web/mobile apps to fetch from API

**`packages/infrastructure/supabase`:**
- Purpose: Supabase client factories, auth context, and middleware
- Clients: Variants for browser, server, and SSR contexts with appropriate session/cookie handling
- Auth: `AuthProvider` (context), `useAuth()` (sign in/up/out methods), `useUser()` (current user hook)
- Middleware: Hono middleware for JWT validation; Next.js middleware for session refresh
- Types: Auto-generated `Database` type; helpers like `SupabaseUser`, `TypedSupabaseClient`
- Used by: Apps for authentication and data access

**`packages/infrastructure/navigation`:**
- Purpose: Platform-agnostic navigation (decouple from Next.js, Expo Router)
- Exports: `Link` component interface, `useNavigation()` hook, `NavigationProvider`
- Each app implements navigation via provider (see `apps/web/lib/navigation.tsx`, `apps/mobile/lib/navigation.tsx`)
- Features import only from `@infrastructure/navigation`; never from framework directly

**`packages/infrastructure/ui`:**
- Purpose: Shared design tokens and utilities (Tailwind CSS in v4 format)
- `globals.css` — Single source of truth for theme (HSL color variables, spacing, typography)
- `tokens.ts` — TypeScript exports of theme for runtime use (mobile)
- `cn.ts` — Class name merger utility (tailwind-merge wrapper)
- Consumed by: Web via `@source` directive in CSS; mobile via TypeScript tokens

**`packages/infrastructure/ui-web`:**
- Purpose: Reusable shadcn/ui components for web apps
- Components: Button, Card, Field, Input, Label, Separator (and future additions)
- Style: `base-vega` shadcn style from `components.json`
- Icon library: Lucide React
- Consumed by: `apps/web`, `apps/landing`

**`packages/infrastructure/utils`:**
- Purpose: Cross-platform utility functions (shared between web and mobile)
- Examples: string formatting, date utilities, validation helpers

**`packages/infrastructure/typescript-config`:**
- Purpose: Shared TypeScript compiler configurations
- Provides: Base, library, Next.js, and React Native configs
- Used by: All packages via `extends` in `tsconfig.json`

## Key File Locations

**Entry Points:**
- `apps/web/app/layout.tsx` — Web root; wraps tree with providers
- `apps/api/src/index.ts` — API server startup
- `apps/mobile/app/_layout.tsx` — Mobile root; wraps tree with providers
- `apps/landing/app/layout.tsx` — Landing page root

**Configuration:**
- `pnpm-workspace.yaml` — Monorepo workspace definition and dependency catalog
- `turbo.json` — Turborepo task orchestration (build, dev, test, lint)
- `package.json` — Root scripts and shared devDependencies
- `biome.json` — Linter and formatter rules (100-char line width, double quotes)
- `tsconfig.json` — Root TypeScript base config
- `.claude/CLAUDE.md` — Project conventions and patterns

**Core Logic:**
- `apps/api/src/router.ts` — Master oRPC router (composes feature routers)
- `apps/api/src/app.ts` — Hono app with middleware setup
- `packages/features/users/src/routers/usersORPCRouter.ts` — Example feature router
- `apps/web/app/providers.tsx` — Client-side provider composition (Auth, Query, Navigation)
- `apps/web/lib/supabase.ts` — Supabase client factory with env config
- `apps/web/lib/navigation.tsx` — Navigation context implementation for Next.js

**Testing:**
- `apps/web/e2e/` — Playwright E2E tests
- `**/__tests__/` — Co-located unit/integration tests (vitest, jest-expo)

## Naming Conventions

**Files:**
- Pages: `page.tsx` (Next.js/Expo Router convention)
- Layout: `layout.tsx`, `_layout.tsx` (app-level structure)
- Components: PascalCase (e.g., `SignInForm.tsx`, `Button.tsx`)
- Utilities: camelCase (e.g., `cn.ts`, `tokens.ts`, `navigation.tsx`)
- Hooks: `use` prefix, camelCase (e.g., `useNavigation.ts`, `useAuth.ts`)
- Tests: `*.test.ts` or `*.spec.ts` in `__tests__/` sibling directories
- Routers: `*ORPCRouter.ts` (e.g., `usersORPCRouter.ts`)
- Schemas/Contracts: `*Schema.ts` or `*Contract.ts` (e.g., `usersContract.ts`, `SignInSchema`)

**Directories:**
- Feature packages: lowercase, plural (e.g., `auth`, `users`, `products`)
- Infrastructure packages: scoped `@infrastructure/*` with kebab-case (e.g., `@infrastructure/api-client`)
- Page groups (Next.js): parentheses for non-URL (e.g., `(auth)`, `(protected)`)
- Page directories: kebab-case (e.g., `sign-in`, `forgot-password`, `reset-password`)
- Feature subdirs: `contracts`, `routers` (plural; own all code in feature)

**TypeScript:**
- Types: PascalCase (e.g., `User`, `SupabaseUser`, `NavigationContextValue`)
- Zod inferred types: `Type` suffix (e.g., `User = z.infer<typeof UserSchema>`)
- Enums: PascalCase (from Zod discriminated unions)
- Functions: camelCase (e.g., `createApiClient`, `useNavigation`)
- Constants: UPPER_SNAKE_CASE for truly constant values; camelCase for functions/objects

## Where to Add New Code

**New Feature:**
- Primary code: `packages/features/<feature-name>/src/{contracts,routers}`
- Feature contracts: `packages/features/<feature-name>/src/contracts/<name>Contract.ts` — Zod schemas
- Feature routers: `packages/features/<feature-name>/src/routers/<name>ORPCRouter.ts` — oRPC procedures
- Export router in feature `index.ts` (default export) for API composition
- Export schemas as named exports for client consumption
- Tests: `packages/features/<feature-name>/src/{contracts,routers}/__tests__/`

**New Web Page:**
- Page component: `apps/web/app/<route>/page.tsx` (Server component by default)
- Layout (if scoped): `apps/web/app/<route>/layout.tsx`
- Page-specific components: `apps/web/components/<feature>/` or co-locate if only used by one page
- Tests: `apps/web/app/<route>/__tests__/page.test.tsx`

**New Mobile Screen:**
- Screen component: `apps/mobile/app/<route>/index.tsx` (Expo Router)
- Layout: `apps/mobile/app/<route>/_layout.tsx`
- Components: `apps/mobile/components/` (same structure as web)

**New Shared Component:**
- For web: Add to `packages/infrastructure/ui-web/src/components/`, then `pnpx shadcn@latest add <component>` from `apps/web/`, copy result to infrastructure
- For mobile: Add to `packages/infrastructure/ui-mobile/src/components/` (if created) using UniWind classes
- Export from barrel index (`index.ts`)

**Utilities/Helpers:**
- Cross-platform: `packages/infrastructure/utils/src/`
- Web-only: `apps/web/lib/` or `apps/web/utils/`
- Mobile-only: `apps/mobile/lib/` or `apps/mobile/utils/`

**Infrastructure Middleware/Clients:**
- Supabase: `packages/infrastructure/supabase/src/{clients,middleware}/`
- API: `packages/infrastructure/api-client/src/`

## Special Directories

**`generated/`:**
- Purpose: Auto-generated code (never hand-edit)
- Created by: `pnpm gencode` (oRPC router types, Supabase DB types)
- Committed: Yes — types must be in repo so CI and local builds match
- Locations: `packages/infrastructure/api-client/src/generated/`, `packages/infrastructure/supabase/src/generated/`
- Regenerate after: Changing feature routers (`pnpm gencode` after router edits); running `pnpm --filter supabase-db reset` (after migrations)

**`.next/`:**
- Purpose: Next.js build cache and compiled output
- Generated: Yes (during `pnpm build`, `pnpm dev`)
- Committed: No (listed in .gitignore)

**`.expo/`:**
- Purpose: Expo cached types and metadata
- Generated: Yes (during `pnpm --filter mobile dev`)
- Committed: No

**`node_modules/`:**
- Purpose: Installed dependencies
- Generated: Yes (during `pnpm install`)
- Committed: No

**`__tests__/`:**
- Purpose: Test files (unit, integration)
- Pattern: Sibling directory to source files, mirrors file structure
- Example: Source `src/auth/useAuth.ts` → Test `src/auth/__tests__/useAuth.test.ts`

---

*Structure analysis: 2026-03-02*
