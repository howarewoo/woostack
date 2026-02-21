# Supabase Integration Design

**Date:** 2026-02-21
**Status:** Approved

## Overview

Add Supabase as the authentication, database, and storage backend for the monorepo. This involves two new packages:

1. **`apps/supabase`** — Supabase CLI project (config, migrations, seed data). Local dev via Docker, deployed to hosted Supabase.
2. **`@infrastructure/supabase`** — Single infrastructure package providing typed clients, auth hooks/context, storage utilities, middleware, and auto-generated database types.

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Supabase environment | Local + hosted | Best DX and reproducibility |
| Auth flow | API validates JWTs | Centralizes authorization at the oRPC layer |
| DB access | Direct Supabase client | Simple, type-safe via generated types, no extra abstraction |
| Features | Auth + Database + Storage | Cover core needs, add Realtime later |
| Client auth | React hooks + context | Mirrors existing NavigationProvider pattern |
| Type generation | Gencode from Supabase CLI | Committed to git, same pattern as Router types |
| Package structure | Single @infrastructure/supabase | Simple, discoverable, follows existing patterns |
| CI type verification | Committed file, add hosted CI later | Pragmatic — no Supabase secrets needed in CI initially |
| SSR auth | Cookie-based via @supabase/ssr | Server components and middleware access session |

## Architecture

### `apps/supabase` — Supabase CLI Project

```
apps/supabase/
  package.json              → name: "supabase"
  config.toml               → Supabase CLI project config (ports, auth, storage)
  migrations/               → SQL migration files
  seed.sql                  → Seed data for local development
```

**Scripts:**
- `start` → `supabase start` (local Supabase via Docker)
- `stop` → `supabase stop`
- `reset` → `supabase db reset` (reapply migrations + seed)
- `migrate` → `supabase migration new`
- `gen-types` → generates DB types into `@infrastructure/supabase/src/generated/`

### `@infrastructure/supabase` — Infrastructure Package

```
packages/infrastructure/supabase/
  package.json              → name: "@infrastructure/supabase"
  tsconfig.json
  src/
    generated/
      database.ts           → auto-generated DB types from Supabase CLI
    clients/
      server.ts             → createServerClient() — for apps/api
      browser.ts            → createBrowserClient() — basic client-side
      server-ssr.ts         → createSSRServerClient(cookies) — Next.js server components
      browser-ssr.ts        → createSSRBrowserClient() — Next.js client (cookie-based)
    auth/
      AuthProvider.tsx       → React context provider
      useAuth.ts            → useAuth() — session, signIn, signOut, signUp
      useUser.ts            → useUser() — current user or null
      types.ts              → AuthState, AuthContextValue interfaces
    storage/
      storage.ts            → upload(), download(), getPublicUrl(), remove()
    middleware/
      hono.ts               → Hono middleware: JWT validation, user + supabase on context
      nextjs.ts             → Next.js middleware: session refresh, route protection
    types.ts                → Re-export Database, Tables, Enums helper types
    index.ts                → Barrel: named exports
```

**Package exports (subpaths):**
```json
{
  "exports": {
    ".": "./src/index.ts",
    "./server": "./src/clients/server.ts",
    "./server-ssr": "./src/clients/server-ssr.ts",
    "./browser-ssr": "./src/clients/browser-ssr.ts",
    "./auth": "./src/auth/index.ts",
    "./middleware/hono": "./src/middleware/hono.ts",
    "./middleware/nextjs": "./src/middleware/nextjs.ts",
    "./storage": "./src/storage/storage.ts"
  }
}
```

## Auth Flow

### Sign-in (client-side)

1. User interacts with sign-in UI
2. App calls `useAuth().signIn({ email, password })`
3. Supabase JS client handles auth, returns session with JWT
4. `AuthProvider` stores session, exposes via `useAuth()` / `useUser()`

### Authenticated API call

1. Client creates API client with dynamic token getter:
   ```typescript
   const client = createTypedApiClient(url, {
     getToken: () => supabase.auth.getSession()
       .then(({ data }) => data.session?.access_token),
   });
   ```
2. Request hits `apps/api` Hono server
3. `supabaseMiddleware` extracts + validates JWT
4. Middleware attaches user and RLS-scoped Supabase client to oRPC context
5. Feature procedures access `context.user` and `context.supabase`

### oRPC Context

```typescript
type Context = {
  requestId?: string;
  user?: { id: string; email: string; role: string };
  supabase: SupabaseClient; // server client scoped to user's JWT (RLS)
};
```

### Token Refresh

**Client-side:** Supabase JS handles auto-refresh via `onAuthStateChange`. `AuthProvider` subscribes to state changes and updates session.

**API calls:** Dynamic `getToken()` getter ensures each request uses the freshest token.

**Expired token recovery:**
1. Client sends request with stale JWT
2. API returns 401
3. Client interceptor catches 401, calls `supabase.auth.refreshSession()`
4. If refresh succeeds, retry original request with new token
5. If refresh fails, redirect to sign-in

### SSR Auth (Next.js)

Uses `@supabase/ssr` for cookie-based session management:

- `createSSRBrowserClient()` — stores session in cookies (not localStorage)
- `createSSRServerClient(cookies)` — reads session from cookies in server components
- `createSupabaseMiddleware()` — Next.js middleware for session refresh and route protection

**Server component usage:**
```typescript
import { createSSRServerClient } from "@infrastructure/supabase/server-ssr";
import { cookies } from "next/headers";

export default async function Dashboard() {
  const supabase = createSSRServerClient(await cookies());
  const { data: { user } } = await supabase.auth.getUser();
}
```

**Route protection:**
```typescript
// apps/web/middleware.ts
import { createSupabaseMiddleware } from "@infrastructure/supabase/middleware/nextjs";
export default createSupabaseMiddleware();
export const config = { matcher: ["/dashboard/:path*", "/settings/:path*"] };
```

## Storage

```typescript
export function createStorageClient(supabase: SupabaseClient) {
  return {
    upload(bucket: string, path: string, file: File | Blob): Promise<{ path: string }>,
    download(bucket: string, path: string): Promise<Blob>,
    getPublicUrl(bucket: string, path: string): string,
    remove(bucket: string, paths: string[]): Promise<void>,
  };
}
```

Buckets defined in `apps/supabase/config.toml` and created via migrations/seed.

## Type Generation

`pnpm gencode` runs both generators:
1. **Router types** (existing) → `@infrastructure/api-client/src/generated/router-types.d.ts`
2. **DB types** (new) → `@infrastructure/supabase/src/generated/database.ts`

Generation uses `supabase gen types --lang=typescript --local` (requires local Supabase running).

Generated files are committed to git. CI trusts the committed file initially; hosted CI verification added later when Supabase project + secrets are configured.

**Type usage:**
```typescript
import type { Database, Tables } from "@infrastructure/supabase";
type User = Tables<"users">;
```

## App Integration

### `apps/api`
- Add `@infrastructure/supabase` dependency
- Add `supabaseMiddleware` to Hono middleware chain
- Update oRPC context type to include `user` and `supabase`

### `apps/web`
- Add `@infrastructure/supabase` dependency
- Wrap app in `AuthProvider`
- Use SSR clients (`createSSRBrowserClient`, `createSSRServerClient`)
- Add Next.js middleware for route protection
- Update API client to use dynamic `getToken`

### `apps/mobile`
- Add `@infrastructure/supabase` dependency
- Wrap app in `AuthProvider`
- Update API client to use dynamic `getToken`
- Supabase JS works in React Native (uses `AsyncStorage` adapter)

### `apps/landing`
- No changes initially — public content only

### Environment Variables
```
NEXT_PUBLIC_SUPABASE_URL=http://localhost:54321
NEXT_PUBLIC_SUPABASE_ANON_KEY=<local-anon-key>
SUPABASE_SERVICE_ROLE_KEY=<service-role-key>    # server-side only
```

Each app gets a `.env.local.example` documenting required variables.

## Dependencies

New catalog entries in `pnpm-workspace.yaml`:
- `@supabase/supabase-js` — core Supabase client
- `@supabase/ssr` — SSR/cookie-based auth for Next.js
- `supabase` (devDependency) — CLI tool for local dev and type generation
