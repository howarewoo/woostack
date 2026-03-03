# External Integrations

**Analysis Date:** 2026-03-02

## APIs & External Services

**Supabase (Primary Backend):**
- Service: Open-source Firebase alternative with PostgreSQL, Auth, Storage, and Realtime
- What it's used for: User authentication, database (RLS-protected), file storage, session management
- SDK/Client: @supabase/supabase-js 2.97.0, @supabase/ssr 0.8.0
- Auth: `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` environment variables
  - Publishable key is safe to embed in client bundles (web/mobile)
  - Server auth uses JWT from Supabase session
- Location: `packages/infrastructure/supabase/` (clients, auth context, middleware, storage utilities)

**Hono RPC (Internal Type-Safe API):**
- Service: Lightweight HTTP framework used in `apps/api`
- What it's used for: RESTful API server for web/mobile clients
- SDK/Client: hono 4.11.9, @hono/node-server 1.19.9
- oRPC Integration: @orpc/server 1.13.5 wraps feature routers for type-safe RPC
- Base URL: `http://localhost:3100/api` (dev), configurable via `NEXT_PUBLIC_API_URL` in web
- CORS: Configured in `apps/api/src/app.ts` to allow `http://localhost:3000` (landing) and `http://localhost:3001` (web) by default; override via `CORS_ALLOWED_ORIGINS` env var
- Location: `apps/api/src/router.ts` (master router), feature routers in `packages/features/*/router.ts`

## Data Storage

**Databases:**
- Type/Provider: PostgreSQL (via Supabase managed service)
  - Connection: `SUPABASE_URL` environment variable
  - Client: @supabase/supabase-js (SQL queries via `.from()`, `.select()`, etc.)
  - ORM: None (direct SQL via Supabase JS client)
  - RLS: Row-level security enforced at database level (unauthenticated = publishable-key scoped, authenticated = user-scoped)
  - Migrations: `apps/supabase/supabase/migrations/` (SQL files, applied via Supabase CLI)
  - Seed data: `apps/supabase/supabase/seed.sql` (applied on `pnpm --filter supabase-db reset`)
  - Types: Generated auto-typed interfaces in `packages/infrastructure/supabase/src/generated/database.ts`

**File Storage:**
- Provider: Supabase Storage (S3-compatible object storage)
  - Utility: `createStorageClient()` in `packages/infrastructure/supabase/src/storage/storage.ts`
  - Buckets: Configured in Supabase dashboard (RLS policies for public/authenticated access)
  - Public URLs: `createStorageClient().getPublicUrl(bucket, path)` returns signed URL

**Caching:**
- Provider: None (client-side only)
  - @tanstack/react-query handles browser cache and sync (no Redis/Memcached)

## Authentication & Identity

**Auth Provider:**
- Service: Supabase Auth (managed authentication)
- Implementation: Email/password (via `signUp`, `signIn` Supabase methods)
- Clients:
  - Server-side: `createServerClient()` in `packages/infrastructure/supabase/src/clients/server.ts`
  - Browser: `createBrowserClient()` in `packages/infrastructure/supabase/src/clients/browser.ts`
  - SSR (Next.js): `createSSRServerClient()` and `createSSRBrowserClient()` in `packages/infrastructure/supabase/src/clients/server-ssr.ts` + middleware in `packages/infrastructure/supabase/src/middleware/nextjs.ts`
- Context/Hooks:
  - `AuthProvider` + `useAuth()` + `useUser()` in `packages/infrastructure/supabase/src/auth/index.ts`
  - React context pattern mirroring NavigationProvider (platform-agnostic)
- Session Storage: Browser localStorage (via `@supabase/ssr` for Next.js SSR safety)
- Token Injection: API client supports dynamic token via `getToken` option in `createTypedApiClient()`
- Validation: Zod schemas in `packages/features/auth/src/contracts/authSchemas.ts` (SignInSchema, SignUpSchema, etc.)

## Monitoring & Observability

**Error Tracking:**
- Provider: None detected
- Standard: Errors are logged to console in development; production error handling TBD

**Logs:**
- Approach: Console-based
  - API: Hono logger middleware in `apps/api/src/app.ts` (`app.use("*", logger())`)
  - Request tracing: Optional `x-request-id` header passed through oRPC context

**Analytics:**
- Provider: None (no Sentry, LogRocket, etc. configured)

## CI/CD & Deployment

**Hosting:**
- Infrastructure: Not specified in codebase (apps are deployable but no production config checked in)
  - API: Node.js server (can run on any Node.js hosting or containerized)
  - Web: Next.js (Vercel-ready)
  - Landing: Next.js (Vercel-ready)
  - Mobile: Expo (EAS or local builds)

**CI Pipeline:**
- Service: GitHub Actions (`.github/workflows/ci.yml`)
- Trigger: Pull requests (opened, synchronize)
- Jobs:
  1. Tests - Biome lint + Turbo build + Vitest for changed packages
  2. React Doctor - Separate job for React best practices (via millionco/react-doctor)
- Node.js: 22 (setup-node@v6)
- pnpm: v10 (action-setup@v3)
- Environments: Staging (default) or Production (if base_ref == main)

**Dependency Updates:**
- Service: Dependabot (`.github/dependabot.yml`)
- Frequency: Weekly scans
- Target branch: staging (PRs target staging, not main)
- Grouped updates: React, Expo/React Native, Next.js, oRPC, Supabase, TanStack, styling, UI, testing, linting, Hono, Zod

**React Doctor (Code Quality):**
- Provider: millionco/react-doctor@main
- Trigger: Every PR
- Checks: React anti-patterns, warns on violations
- Comments: Posts review comments on PR

## Environment Configuration

**Required env vars:**

| App | Variable | Purpose | Default |
|-----|----------|---------|---------|
| API | `SUPABASE_URL` | Supabase API endpoint | `http://127.0.0.1:54321` |
| API | `SUPABASE_PUBLISHABLE_KEY` | Publishable key for RLS-scoped requests | Required |
| API | `PORT` | Server listen port | 3100 |
| API | `CORS_ALLOWED_ORIGINS` | Comma-separated CORS origins | `http://localhost:3000,http://localhost:3001` |
| Web | `NEXT_PUBLIC_SUPABASE_URL` | Supabase API (embedded in client) | Required |
| Web | `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | Publishable key (embedded in client) | Required |
| Web | `NEXT_PUBLIC_API_URL` | oRPC API base URL (optional) | `http://localhost:3100/api` |
| Mobile | `EXPO_PUBLIC_SUPABASE_URL` | Supabase API (embedded in app) | Required |
| Mobile | `EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | Publishable key (embedded in app) | Required |

**Secrets location:**
- Local dev: `.env` files (`.env.example` provided as templates)
- CI/GitHub: Repository secrets (environment-specific via GitHub Environments)
- Production: Environment variables in deployment platform (Vercel, Heroku, etc.)

## Webhooks & Callbacks

**Incoming:**
- API webhooks: None implemented
- Supabase webhooks: Configurable but not used in codebase (would be in edge functions)

**Outgoing:**
- Email webhooks: None (Supabase Auth handles emails natively)
- External callbacks: None

## API Client Integration

**oRPC (Type-Safe RPC):**
- Location: `packages/infrastructure/api-client/` (exported utilities)
- Utilities:
  - `createApiClient(baseUrl, options?)` - Base oRPC client
  - `createTypedApiClient(baseUrl, options?)` - Pre-typed client using generated Router type
  - `createTypedOrpcUtils(client)` - Helper for TanStack Query integration
- Usage in web/mobile:
  ```typescript
  import { createTypedApiClient } from "@infrastructure/api-client";
  const client = createTypedApiClient("http://localhost:3100/api", {
    getToken: async () => {
      const { data } = await supabase.auth.getSession();
      return data.session?.access_token;
    },
  });
  ```
- TanStack Query Integration: `@orpc/tanstack-query` provides `queryOptions()` and `mutationOptions()` helpers

**Router Type Generation:**
- Location: `packages/infrastructure/api-client/src/generated/router-types.d.ts`
- Generated from: `apps/api/src/router.ts` (master router type)
- Trigger: `pnpm gencode` (runs `api/scripts/generate-router-types.ts`)
- Must be committed (regenerated on API router changes)

## Local Development Setup

**Supabase Local Instance:**
- Start: `pnpm --filter supabase-db start` (Docker-based)
- Stop: `pnpm --filter supabase-db stop`
- Reset: `pnpm --filter supabase-db reset` (reapply migrations + seed)
- Generate types: `pnpm gencode` (requires Supabase running)
- Default URL: `http://127.0.0.1:54321`
- Publishes anon key and service role key in CLI output

**All Apps (Dev Servers):**
- Landing: `pnpm --filter landing dev` (port 3000)
- Web: `pnpm --filter web dev` (port 3001)
- API: `pnpm --filter api dev` (port 3100)
- Mobile: `pnpm --filter mobile dev` or `.ios`/`.android` for platform-specific
- All: `pnpm dev` (runs install + all dev servers in parallel via Turbo)

---

*Integration audit: 2026-03-02*
