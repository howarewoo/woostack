# Architecture

**Analysis Date:** 2026-03-02

## Pattern Overview

**Overall:** Layered monorepo with feature-driven API architecture and cross-platform consumption (web, mobile)

**Key Characteristics:**
- Feature packages own their contracts, routers, and procedures — infrastructure packages are shared utilities
- oRPC for type-safe API (routers are plain object literals, composed in `apps/api/src/router.ts`)
- Supabase for auth, database, and storage with RLS (row-level security) enforcement
- Feature packages have zero knowledge of how they're consumed (web vs mobile)
- Infrastructure packages provide platform abstractions (Navigation, API Client, Supabase clients)
- Apps (web, landing, mobile) import from infrastructure and feature packages; never from each other

## Layers

**Presentation Layer (Apps):**
- Purpose: Render UI and handle user interaction; orchestrate providers and routing
- Location: `apps/web`, `apps/landing`, `apps/mobile`
- Contains: Page components, app-specific hooks, layout, providers setup
- Depends on: Infrastructure packages (`@infrastructure/navigation`, `@infrastructure/supabase`, `@infrastructure/api-client`, `@infrastructure/ui-web`), feature package schemas (`@features/auth`)
- Used by: End users via browser/mobile app

**Feature Layer:**
- Purpose: Define domain-specific contracts, routers, and business logic; portable across platforms
- Location: `packages/features/*` (e.g., `packages/features/auth`, `packages/features/users`)
- Contains: Zod schemas (`contracts/`), oRPC routers (`routers/`), procedures with context access
- Depends on: Infrastructure packages only (not on apps)
- Used by: API app (to compose routers), consuming apps (to import schemas)

**API Server Layer:**
- Purpose: Serve oRPC router via Hono; handle Supabase auth context, CORS, and request routing
- Location: `apps/api/src`
- Contains: Hono middleware stack, oRPC RPC handler, router composition
- Depends on: Feature routers, Supabase middleware, Hono
- Used by: Web/mobile/landing apps via HTTP

**Infrastructure Layer:**
- Purpose: Provide cross-platform utilities and abstractions for auth, routing, API, storage, UI
- Location: `packages/infrastructure/*`
- Contains: Supabase clients (browser/server/SSR variants), auth context/hooks, API client factory, navigation abstraction, shared UI components, design tokens
- Depends on: External SDKs (Supabase, Hono, oRPC, TanStack Query/Form)
- Used by: Apps and features

**Configuration/Database Layer:**
- Purpose: Manage Supabase migrations, seed data, and auto-generated types
- Location: `apps/supabase` (CLI project), `packages/infrastructure/supabase/src/generated` (types)
- Contains: `migrations/`, `seed.sql`, `config.toml`, generated `database.d.ts`
- Depends on: Supabase CLI
- Used by: API and consuming apps via `@infrastructure/supabase` types

## Data Flow

**Type-Safe API Call (e.g., User List):**

1. Feature package defines contract: `packages/features/users/src/contracts/usersContract.ts` exports `UserSchema`
2. Feature package defines router: `packages/features/users/src/routers/usersORPCRouter.ts` exports `usersRouter` with typed procedures
3. API app composes: `apps/api/src/router.ts` imports `usersRouter` and exports master `router` object and `type Router`
4. Type generation: `pnpm gencode` runs oRPC codegen, writes `packages/infrastructure/api-client/src/generated/router-types.d.ts`
5. App creates client: `createTypedApiClient("http://localhost:3100/api")` from `@infrastructure/api-client`
6. App queries: `useQuery(orpc.users.list.queryOptions())` via TanStack Query utilities
7. Response: Typed return value matching `UserSchema` from feature contract

**Authentication Flow:**

1. User submits form on sign-in page (`apps/web/app/(auth)/sign-in/sign-in-form.tsx`)
2. Form handler calls `useAuth().signIn()` (from `@infrastructure/supabase/auth` context)
3. `signIn()` calls Supabase `auth.signInWithPassword()` via browser client created in `apps/web/lib/supabase.ts`
4. Supabase returns session with access token
5. `AuthProvider` updates context state; consuming components react via `useAuth()` and `useUser()` hooks
6. App redirects to `/dashboard` via `useNavigation().replace()` (platform-agnostic abstraction)
7. Subsequent API calls include token via `getToken` callback in client options

**Page Rendering (Server vs Client in Next.js):**

1. Root layout: `apps/web/app/layout.tsx` (server component) wraps with `<Providers>` (client component)
2. `Providers` initializes QueryClient, Supabase browser client, and NavigationProvider
3. Protected routes: `apps/web/app/(protected)/dashboard/page.tsx` (server component) calls `createServerSupabase()` to check auth server-side
4. Auth forms: Client components in `(auth)` group use `useAuth()` and `useForm()` for interactive submission
5. Navigation: All navigation via `@infrastructure/navigation` abstraction; no direct `next/navigation` imports

**State Management:**

- **Server State**: TanStack Query (via oRPC) for API-sourced data
- **Auth State**: Supabase session in browser localStorage; `AuthProvider` context for React consumption
- **Form State**: TanStack Form v1 per form instance (one-off initialization, no shared wrapper)
- **Navigation State**: Managed by Next.js (web) or Expo Router (mobile) via NavigationProvider adapter
- **UI State**: React component state (useState); no global Redux/Zustand

## Key Abstractions

**Navigation (Cross-Platform Router):**
- Purpose: Decouple feature code from routing framework (Next.js, Expo Router)
- Implementation: `packages/infrastructure/navigation/src`
- Examples: `apps/web/lib/navigation.tsx`, `apps/mobile/lib/navigation.tsx`
- Pattern: Each app implements a `useNavigation()` hook that returns `NavigationContextValue` (router methods + Link component); apps wrap tree with `<NavigationProvider>`. Features import only `useNavigation()` and `Link` from `@infrastructure/navigation`, never from framework directly.

**API Client (Type-Safe Fetching):**
- Purpose: Provide pre-typed client matching server Router type
- Implementation: `packages/infrastructure/api-client/src/typed-client.ts`
- Examples: `createTypedApiClient(baseUrl, options)`, `createTypedOrpcUtils(client)`
- Pattern: Apps create client once at startup; pass through query options to TanStack Query. Supports dynamic token injection via `getToken` callback.

**Supabase Clients (Multi-Context):**
- Purpose: Provide context-appropriate clients (browser, server, SSR variants) with RLS enforcement
- Implementation: `packages/infrastructure/supabase/src/clients/`
- Examples: `createBrowserClient()`, `createServerClient()`, `createSSRBrowserClient()`, `createSSRServerClient()`
- Pattern: Web app uses `createSSRBrowserClient()` in browser context (session persists) and `createSSRServerClient()` in server context (reads cookies). Mobile uses browser variant. Unauthenticated requests use publishable key (respects RLS, no elevated privileges).

**oRPC Router (Feature Procedures):**
- Purpose: Define type-safe, context-aware procedures with built-in validation
- Implementation: Feature routers are plain objects with procedures chained via `.input()`, `.output()`, `.handler()`
- Examples: `packages/features/users/src/routers/usersORPCRouter.ts`
- Pattern: Procedures access `context.user` (from Supabase middleware), `context.supabase` (RLS-scoped client), `context.requestId`. No `.router()` wrapper — oRPC v1 uses object literals.

**Zod Schemas (Contracts):**
- Purpose: Define and enforce data shape across API boundary
- Implementation: Feature packages own contracts; imported by routers and consumers
- Examples: `@features/auth` exports `SignInSchema`, `SignUpSchema`; `@features/users` exports `UserSchema`, `CreateUserSchema`
- Pattern: Schemas are portable — usable in mobile auth forms, server validation, and client-side type inference.

## Entry Points

**Web App:**
- Location: `apps/web/app/layout.tsx`
- Triggers: Next.js server startup (`pnpm dev`, `pnpm build`)
- Responsibilities: Wrap app tree with auth/query/navigation providers; establish Supabase browser client; render page hierarchy

**API Server:**
- Location: `apps/api/src/index.ts`
- Triggers: Node.js HTTP server startup (via `apps/api/package.json` bin script)
- Responsibilities: Compose oRPC router with Supabase middleware; listen on port (default 3100)

**Mobile App:**
- Location: `apps/mobile/app/_layout.tsx`
- Triggers: Expo app startup
- Responsibilities: Same as web (providers, client setup) but with Expo Router navigation adapter

**Landing Page:**
- Location: `apps/landing/app/layout.tsx`
- Triggers: Next.js server startup
- Responsibilities: Simpler than web app; no auth provider (public-only pages)

## Error Handling

**Strategy:** Try-catch at boundaries (form submission, API calls); propagate to UI via error state or toast

**Patterns:**
- **API Errors**: oRPC serializes errors; client catches via `.catch()` on Promise or TanStack Query error handler
- **Form Errors**: Field-level validation errors from Zod via TanStack Form; server errors stored in component `useState` and displayed as `<p role="alert">`
- **Auth Errors**: `signIn()`, `signUp()` methods throw on failure; form handler catches and sets `serverError` state
- **Env Errors**: API startup fails with `throw new Error()` if required env vars missing (e.g., `SUPABASE_PUBLISHABLE_KEY`)
- **Supabase Middleware**: If RLS policy denies request, client returns error; app displays via error UI

## Cross-Cutting Concerns

**Logging:** No centralized logger; uses `console.log/error` in development. Production logging via Supabase audit logs (request_id traced via header).

**Validation:** Zod schemas at two points:
  - Client: Form submission validation (TanStack Form + Zod)
  - Server: Procedure input validation (oRPC + Zod)

**Authentication:** Supabase JWT in session; browser client auto-refreshes token via `@supabase/ssr`. API middleware extracts `user` from request context. RLS policies in Supabase enforce data access.

**CORS:** Hono middleware allows `http://localhost:3000` (landing), `http://localhost:3001` (web), overridable via `CORS_ALLOWED_ORIGINS` env var.

---

*Architecture analysis: 2026-03-02*
