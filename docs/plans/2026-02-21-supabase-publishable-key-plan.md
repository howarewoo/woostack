# Supabase Publishable/Secret Key Rename — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rename all Supabase "anon key" references to "publishable key" and "service role key" to "secret key" across the entire codebase.

**Architecture:** Pure rename/refactor — no logic changes. Update env vars, internal variable names, type fields, test fixtures, JSDoc comments, and documentation to match Supabase's new API key terminology.

**Tech Stack:** TypeScript, Vitest, Hono, Next.js, Expo

**Design doc:** `docs/plans/2026-02-21-supabase-publishable-key-design.md`

---

### Task 1: Rename infrastructure client factories

**Files:**
- Modify: `packages/infrastructure/supabase/src/clients/browser.ts`
- Modify: `packages/infrastructure/supabase/src/clients/browser-ssr.ts`
- Modify: `packages/infrastructure/supabase/src/clients/server-ssr.ts`
- Test: `packages/infrastructure/supabase/src/clients/__tests__/browser.test.ts`
- Test: `packages/infrastructure/supabase/src/clients/__tests__/browser-ssr.test.ts`
- Test: `packages/infrastructure/supabase/src/clients/__tests__/server-ssr.test.ts`

**Step 1: Update `browser.ts` — rename param and JSDoc**

Replace the full file content with:

```typescript
import { createClient, type SupabaseClientOptions } from "@supabase/supabase-js";
import type { Database } from "../generated/database";
import type { TypedSupabaseClient } from "../types";

/**
 * Creates a Supabase browser client for use in client-side React code.
 * Uses the publishable key. Session is managed automatically via localStorage.
 */
export function createBrowserClient(
  supabaseUrl: string,
  supabasePublishableKey: string,
  options?: SupabaseClientOptions<"public">
): TypedSupabaseClient {
  return createClient<Database>(supabaseUrl, supabasePublishableKey, options);
}
```

**Step 2: Update `browser-ssr.ts` — rename param**

Replace the full file content with:

```typescript
import { createBrowserClient } from "@supabase/ssr";
import type { Database } from "../generated/database";
import type { TypedSupabaseClient } from "../types";

/**
 * Creates a Supabase browser client for Next.js client components.
 * Uses cookies (not localStorage) for session management, ensuring
 * the session is accessible in both server and client rendering.
 */
export function createSSRBrowserClient(
  supabaseUrl: string,
  supabasePublishableKey: string
): TypedSupabaseClient {
  return createBrowserClient<Database>(supabaseUrl, supabasePublishableKey);
}
```

**Step 3: Update `server-ssr.ts` — rename param and JSDoc**

Replace the full file content with:

```typescript
import { createServerClient } from "@supabase/ssr";
import type { Database } from "../generated/database";
import type { TypedSupabaseClient } from "../types";

interface CookieStore {
  getAll(): Array<{ name: string; value: string }>;
  set(name: string, value: string, options?: Record<string, unknown>): void;
}

/**
 * Creates a Supabase server client for Next.js server components and route handlers.
 * Uses cookies for session management (not localStorage).
 *
 * Usage:
 * ```typescript
 * import { cookies } from "next/headers";
 * const supabase = createSSRServerClient(url, key, await cookies());
 * ```
 */
export function createSSRServerClient(
  supabaseUrl: string,
  supabasePublishableKey: string,
  cookieStore: CookieStore
): TypedSupabaseClient {
  return createServerClient<Database>(supabaseUrl, supabasePublishableKey, {
    cookies: {
      getAll() {
        return cookieStore.getAll();
      },
      setAll(cookiesToSet) {
        try {
          for (const { name, value, options } of cookiesToSet) {
            cookieStore.set(name, value, options);
          }
        } catch {
          // Called from a Server Component where cookies can't be set.
          // The middleware proxy handles token refresh in this case.
        }
      },
    },
  });
}
```

**Step 4: Update `browser.test.ts` — rename test descriptions and fixtures**

Replace the full file content with:

```typescript
import { describe, expect, it, vi } from "vitest";

vi.mock("@supabase/supabase-js", () => ({
  createClient: vi.fn(() => ({ auth: {}, from: vi.fn() })),
}));

import { createClient } from "@supabase/supabase-js";
import { createBrowserClient } from "../browser";

describe("createBrowserClient", () => {
  it("creates a Supabase client with the provided URL and publishable key", () => {
    const client = createBrowserClient("http://localhost:54321", "test-publishable-key");

    expect(createClient).toHaveBeenCalledWith("http://localhost:54321", "test-publishable-key", undefined);
    expect(client).toBeDefined();
  });

  it("passes through custom options", () => {
    createBrowserClient("http://localhost:54321", "test-publishable-key", {
      auth: { flowType: "pkce" },
    });

    expect(createClient).toHaveBeenCalledWith(
      "http://localhost:54321",
      "test-publishable-key",
      expect.objectContaining({
        auth: expect.objectContaining({ flowType: "pkce" }),
      })
    );
  });
});
```

**Step 5: Update `browser-ssr.test.ts` — rename fixtures**

Replace the full file content with:

```typescript
import { describe, expect, it, vi } from "vitest";

const { mockCreateBrowserClient } = vi.hoisted(() => ({
  mockCreateBrowserClient: vi.fn(() => ({ auth: {}, from: vi.fn() })),
}));

vi.mock("@supabase/ssr", () => ({
  createBrowserClient: mockCreateBrowserClient,
}));

import { createSSRBrowserClient } from "../browser-ssr";

describe("createSSRBrowserClient", () => {
  it("calls @supabase/ssr createBrowserClient with URL and key", () => {
    const client = createSSRBrowserClient("http://localhost:54321", "test-publishable-key");

    expect(mockCreateBrowserClient).toHaveBeenCalledWith("http://localhost:54321", "test-publishable-key");
    expect(client).toBeDefined();
  });
});
```

**Step 6: Update `server-ssr.test.ts` — rename fixtures**

Replace the full file content with:

```typescript
import { beforeEach, describe, expect, it, vi } from "vitest";

const { mockCreateServerClient } = vi.hoisted(() => ({
  mockCreateServerClient: vi.fn(() => ({ auth: {}, from: vi.fn() })),
}));

vi.mock("@supabase/ssr", () => ({
  createServerClient: mockCreateServerClient,
}));

import { createSSRServerClient } from "../server-ssr";

describe("createSSRServerClient", () => {
  beforeEach(() => {
    mockCreateServerClient.mockClear();
  });

  it("calls @supabase/ssr createServerClient with cookie handlers", () => {
    const mockCookieStore = {
      getAll: vi.fn(() => [{ name: "sb-token", value: "abc" }]),
      set: vi.fn(),
    };

    const client = createSSRServerClient(
      "http://localhost:54321",
      "test-publishable-key",
      mockCookieStore as unknown as Parameters<typeof createSSRServerClient>[2]
    );

    expect(mockCreateServerClient).toHaveBeenCalledWith(
      "http://localhost:54321",
      "test-publishable-key",
      expect.objectContaining({
        cookies: expect.objectContaining({
          getAll: expect.any(Function),
          setAll: expect.any(Function),
        }),
      })
    );
    expect(client).toBeDefined();
  });

  it("delegates getAll to the cookie store", () => {
    const mockCookies = [{ name: "sb-token", value: "xyz" }];
    const mockCookieStore = {
      getAll: vi.fn(() => mockCookies),
      set: vi.fn(),
    };

    createSSRServerClient(
      "http://localhost:54321",
      "key",
      mockCookieStore as unknown as Parameters<typeof createSSRServerClient>[2]
    );

    const lastCall = mockCreateServerClient.mock.calls[0] as unknown as [
      string,
      string,
      { cookies: { getAll: () => Array<{ name: string; value: string }> } },
    ];
    const result = lastCall[2].cookies.getAll();
    expect(mockCookieStore.getAll).toHaveBeenCalled();
    expect(result).toEqual(mockCookies);
  });
});
```

**Step 7: Run tests to verify**

Run: `pnpm --filter @infrastructure/supabase test`
Expected: All client tests pass

**Step 8: Commit**

```bash
gt create -m "refactor(supabase): rename anon key to publishable key in client factories"
```

---

### Task 2: Rename Hono middleware

**Files:**
- Modify: `packages/infrastructure/supabase/src/middleware/hono.ts`
- Test: `packages/infrastructure/supabase/src/middleware/__tests__/hono.test.ts`

**Step 1: Update `hono.ts` — rename interface, variables, JSDoc**

Replace the full file content with:

```typescript
import { createClient, type SupabaseClient, type User } from "@supabase/supabase-js";
import type { MiddlewareHandler } from "hono";
import type { Database } from "../generated/database";

declare module "hono" {
  interface ContextVariableMap {
    user: User | undefined;
    supabase: SupabaseClient<Database>;
  }
}

interface SupabaseMiddlewareOptions {
  supabaseUrl: string;
  supabaseSecretKey: string;
  supabasePublishableKey: string;
}

/**
 * Hono middleware that validates Supabase JWTs and attaches the user
 * and an RLS-scoped Supabase client to the request context.
 *
 * - If a valid Bearer token is present, `c.get("user")` returns the authenticated user
 *   and `c.get("supabase")` returns a client scoped to that user's JWT (respects RLS).
 * - If no token or invalid token, `c.get("user")` is undefined and `c.get("supabase")`
 *   is a publishable-key client (respects RLS, no elevated privileges).
 */
export function supabaseMiddleware(options: SupabaseMiddlewareOptions): MiddlewareHandler {
  const { supabaseUrl, supabaseSecretKey, supabasePublishableKey } = options;

  // Cache the publishable client — same config for all unauthenticated requests
  let publishableClient: ReturnType<typeof createClient<Database>> | null = null;
  function getPublishableClient() {
    if (!publishableClient) {
      publishableClient = createClient<Database>(supabaseUrl, supabasePublishableKey, {
        auth: { autoRefreshToken: false, persistSession: false },
      });
    }
    return publishableClient;
  }

  return async (c, next) => {
    const authHeader = c.req.header("Authorization");
    const token = authHeader?.startsWith("Bearer ") ? authHeader.slice(7) : undefined;

    if (token) {
      const supabase = createClient<Database>(supabaseUrl, supabaseSecretKey, {
        global: { headers: { Authorization: `Bearer ${token}` } },
        auth: { autoRefreshToken: false, persistSession: false },
      });

      const {
        data: { user },
        error,
      } = await supabase.auth.getUser(token);

      if (!error && user) {
        c.set("user", user);
        c.set("supabase", supabase);
        return next();
      }
    }

    c.set("user", undefined);
    c.set("supabase", getPublishableClient());

    return next();
  };
}
```

**Step 2: Update `hono.test.ts` — rename fixtures**

Replace the full file content with:

```typescript
import { createClient } from "@supabase/supabase-js";
import { Hono } from "hono";
import { describe, expect, it, vi } from "vitest";
import { supabaseMiddleware } from "../hono";

vi.mock("@supabase/supabase-js", () => ({
  createClient: vi.fn(() => ({
    auth: {
      getUser: vi.fn(() =>
        Promise.resolve({
          data: {
            user: {
              id: "user-123",
              email: "test@example.com",
              role: "authenticated",
            },
          },
          error: null,
        })
      ),
    },
    from: vi.fn(),
  })),
}));

describe("supabaseMiddleware", () => {
  it("attaches user and supabase to context when valid token is provided", async () => {
    const app = new Hono();
    const middleware = supabaseMiddleware({
      supabaseUrl: "http://localhost:54321",
      supabaseSecretKey: "test-secret-key",
      supabasePublishableKey: "test-publishable-key",
    });

    app.use("*", middleware);
    app.get("/test", (c) => {
      const user = c.get("user");
      return c.json({ userId: user?.id });
    });

    const res = await app.request("/test", {
      headers: { Authorization: "Bearer valid-token" },
    });

    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.userId).toBe("user-123");
  });

  it("continues without user when no token is provided", async () => {
    const app = new Hono();
    const middleware = supabaseMiddleware({
      supabaseUrl: "http://localhost:54321",
      supabaseSecretKey: "test-secret-key",
      supabasePublishableKey: "test-publishable-key",
    });

    app.use("*", middleware);
    app.get("/test", (c) => {
      const user = c.get("user");
      return c.json({ hasUser: !!user });
    });

    const res = await app.request("/test");

    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.hasUser).toBe(false);
  });

  it("continues without user when token is invalid", async () => {
    vi.mocked(createClient).mockReturnValueOnce({
      auth: {
        getUser: vi.fn(() =>
          Promise.resolve({
            data: { user: null },
            error: { message: "Invalid token", status: 401 },
          })
        ),
      },
      from: vi.fn(),
    } as unknown as ReturnType<typeof createClient>);

    const app = new Hono();
    const middleware = supabaseMiddleware({
      supabaseUrl: "http://localhost:54321",
      supabaseSecretKey: "test-secret-key",
      supabasePublishableKey: "test-publishable-key",
    });

    app.use("*", middleware);
    app.get("/test", (c) => {
      const user = c.get("user");
      return c.json({ hasUser: !!user });
    });

    const res = await app.request("/test", {
      headers: { Authorization: "Bearer invalid-token" },
    });

    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.hasUser).toBe(false);
  });
});
```

**Step 3: Run tests to verify**

Run: `pnpm --filter @infrastructure/supabase test`
Expected: All middleware tests pass

**Step 4: Commit**

```bash
gt modify -m "refactor(supabase): rename anon/service-role to publishable/secret key"
```

---

### Task 3: Rename Next.js middleware

**Files:**
- Modify: `packages/infrastructure/supabase/src/middleware/nextjs.ts`
- Test: `packages/infrastructure/supabase/src/middleware/__tests__/nextjs.test.ts`

**Step 1: Update `nextjs.ts` — rename interface field and variable**

Replace the full file content with:

```typescript
import { createServerClient } from "@supabase/ssr";
import { type NextRequest, NextResponse } from "next/server";
import type { Database } from "../generated/database";

interface SupabaseMiddlewareOptions {
  supabaseUrl: string;
  supabasePublishableKey: string;
  /** Route prefixes that require authentication. E.g., ["/dashboard", "/settings"]. */
  protectedRoutes?: string[];
  /** Path to redirect unauthenticated users to. Defaults to "/login". */
  loginPath?: string;
}

/**
 * Creates a Next.js middleware that refreshes the Supabase auth session
 * on every request and optionally redirects unauthenticated users from
 * protected routes to the login page.
 */
export function createSupabaseMiddleware(options: SupabaseMiddlewareOptions) {
  const { supabaseUrl, supabasePublishableKey, protectedRoutes = [], loginPath = "/login" } = options;

  return async function middleware(request: NextRequest) {
    let supabaseResponse = NextResponse.next({ request });

    const supabase = createServerClient<Database>(supabaseUrl, supabasePublishableKey, {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          for (const { name, value } of cookiesToSet) {
            request.cookies.set(name, value);
          }
          supabaseResponse = NextResponse.next({ request });
          for (const { name, value, options } of cookiesToSet) {
            supabaseResponse.cookies.set(name, value, options);
          }
        },
      },
    });

    const {
      data: { user },
    } = await supabase.auth.getUser();

    const isProtected = protectedRoutes.some((route) => request.nextUrl.pathname.startsWith(route));

    if (isProtected && !user) {
      const url = request.nextUrl.clone();
      url.pathname = loginPath;
      return NextResponse.redirect(url);
    }

    return supabaseResponse;
  };
}
```

**Step 2: Update `nextjs.test.ts` — rename all `supabaseAnonKey` to `supabasePublishableKey`**

Replace every occurrence of `supabaseAnonKey: "test-anon-key"` with `supabasePublishableKey: "test-publishable-key"` in the file. There are 5 occurrences at lines 57, 70, 91, 108, 125.

**Step 3: Run tests to verify**

Run: `pnpm --filter @infrastructure/supabase test`
Expected: All tests pass

**Step 4: Commit**

```bash
gt modify -m "refactor(supabase): rename anon/service-role to publishable/secret key"
```

---

### Task 4: Rename API app (`apps/api`)

**Files:**
- Modify: `apps/api/src/app.ts`
- Modify: `apps/api/src/__tests__/index.test.ts`
- Modify: `apps/api/.env.example`

**Step 1: Update `app.ts` — rename env vars and variables**

In `apps/api/src/app.ts`, make these replacements:
- Line 14: `requireEnv("SUPABASE_SERVICE_ROLE_KEY")` → `requireEnv("SUPABASE_SECRET_KEY")`
- Line 14: `supabaseServiceKey` → `supabaseSecretKey`
- Line 15: `requireEnv("SUPABASE_ANON_KEY")` → `requireEnv("SUPABASE_PUBLISHABLE_KEY")`
- Line 15: `supabaseAnonKey` → `supabasePublishableKey`
- Line 36: `supabaseServiceKey` → `supabaseSecretKey`
- Line 37: `supabaseAnonKey` → `supabasePublishableKey`

**Step 2: Update `index.test.ts` — rename env var setup**

In `apps/api/src/__tests__/index.test.ts`, lines 5-6:
- `process.env.SUPABASE_SERVICE_ROLE_KEY = "test-service-key"` → `process.env.SUPABASE_SECRET_KEY = "test-secret-key"`
- `process.env.SUPABASE_ANON_KEY = "test-anon-key"` → `process.env.SUPABASE_PUBLISHABLE_KEY = "test-publishable-key"`

**Step 3: Update `.env.example`**

Replace with:
```
SUPABASE_URL=http://127.0.0.1:54321
SUPABASE_SECRET_KEY=your-secret-key-from-supabase-start
SUPABASE_PUBLISHABLE_KEY=your-publishable-key-from-supabase-start
```

**Step 4: Run tests to verify**

Run: `pnpm --filter api test`
Expected: All API tests pass

**Step 5: Commit**

```bash
gt modify -m "refactor(supabase): rename anon/service-role to publishable/secret key"
```

---

### Task 5: Rename web app (`apps/web`)

**Files:**
- Modify: `apps/web/lib/supabase.ts`
- Modify: `apps/web/middleware.ts`
- Modify: `apps/web/.env.local.example`

**Step 1: Update `apps/web/lib/supabase.ts`**

Replace the full file content with:

```typescript
import type { TypedSupabaseClient } from "@infrastructure/supabase";
import { createSSRBrowserClient } from "@infrastructure/supabase/browser-ssr";
import { createSSRServerClient } from "@infrastructure/supabase/server-ssr";

if (!process.env.NEXT_PUBLIC_SUPABASE_URL) throw new Error("NEXT_PUBLIC_SUPABASE_URL is required");
if (!process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY)
  throw new Error("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY is required");

const supabaseUrl: string = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabasePublishableKey: string = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;

/** Creates a Supabase client for use in client components. */
export function createBrowserSupabase(): TypedSupabaseClient {
  return createSSRBrowserClient(supabaseUrl, supabasePublishableKey);
}

/** Creates a Supabase client for use in server components. */
export async function createServerSupabase(): Promise<TypedSupabaseClient> {
  const { cookies } = await import("next/headers");
  return createSSRServerClient(supabaseUrl, supabasePublishableKey, await cookies());
}
```

**Step 2: Update `apps/web/middleware.ts`**

Replace the full file content with:

```typescript
import { createSupabaseMiddleware } from "@infrastructure/supabase/middleware/nextjs";

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabasePublishableKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!;

export default createSupabaseMiddleware({
  supabaseUrl,
  supabasePublishableKey,
  protectedRoutes: ["/dashboard", "/settings"],
  loginPath: "/login",
});

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)"],
};
```

**Step 3: Update `.env.local.example`**

Replace with:
```
NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=your-publishable-key-from-supabase-start
```

**Step 4: Commit**

```bash
gt modify -m "refactor(supabase): rename anon/service-role to publishable/secret key"
```

---

### Task 6: Rename mobile app (`apps/mobile`)

**Files:**
- Modify: `apps/mobile/lib/supabase.ts`
- Modify: `apps/mobile/.env.example`

**Step 1: Update `apps/mobile/lib/supabase.ts`**

Replace the full file content with:

```typescript
import { createBrowserClient } from "@infrastructure/supabase";

/** Creates a Supabase client for React Native. */
export function createMobileSupabase() {
  const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL;
  const supabasePublishableKey = process.env.EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY;

  if (!supabaseUrl) throw new Error("EXPO_PUBLIC_SUPABASE_URL is required");
  if (!supabasePublishableKey) throw new Error("EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY is required");

  return createBrowserClient(supabaseUrl, supabasePublishableKey);
}
```

**Step 2: Update `.env.example`**

Replace with:
```
EXPO_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321
EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY=your-publishable-key-from-supabase-start
```

**Step 3: Commit**

```bash
gt modify -m "refactor(supabase): rename anon/service-role to publishable/secret key"
```

---

### Task 7: Update documentation

**Files:**
- Modify: `.claude/CLAUDE.md`
- Modify: `eng-constitution.md`

**Step 1: Update `eng-constitution.md` line 161**

Replace:
```
- Unauthenticated API requests receive an anon-key client that respects RLS — never the service role key
```
With:
```
- Unauthenticated API requests receive a publishable-key client that respects RLS — never the secret key
```

**Step 2: Update `.claude/CLAUDE.md`**

Apply these replacements throughout the file:

1. In the middleware description (around line 119):
   - `supabaseUrl`+`supabaseServiceKey`+`supabaseAnonKey` → `supabaseUrl`+`supabaseSecretKey`+`supabasePublishableKey`

2. In the feature procedures description (around line 122):
   - `anon-key client` → `publishable-key client`

3. In the env var table (lines 190-195):
   - `SUPABASE_SERVICE_ROLE_KEY` → `SUPABASE_SECRET_KEY` with description `Secret key for JWT validation`
   - `SUPABASE_ANON_KEY` → `SUPABASE_PUBLISHABLE_KEY` with description `Publishable key for unauthenticated RLS-scoped requests`
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY` → `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` with description `Publishable key (public, embedded in client bundle)`
   - `EXPO_PUBLIC_SUPABASE_ANON_KEY` → `EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY` with description `Publishable key (public, embedded in app bundle)`

**Step 3: Commit**

```bash
gt modify -m "refactor(supabase): rename anon/service-role to publishable/secret key"
```

---

### Task 8: Update existing design/plan docs

**Files:**
- Modify: `docs/plans/2026-02-21-supabase-integration-design.md`
- Modify: `docs/plans/2026-02-21-supabase-integration-plan.md`

**Step 1: Update `supabase-integration-design.md`**

Search and replace all occurrences of:
- `SUPABASE_ANON_KEY` → `SUPABASE_PUBLISHABLE_KEY`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY` → `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`
- `SUPABASE_SERVICE_ROLE_KEY` → `SUPABASE_SECRET_KEY`
- `anon-key` → `publishable-key` (in descriptions)
- `service-role-key` → `secret-key` (in descriptions)

**Step 2: Update `supabase-integration-plan.md`**

Search and replace all occurrences (this file has ~30+ references):
- `supabaseAnonKey` → `supabasePublishableKey`
- `supabaseServiceKey` → `supabaseSecretKey`
- `"test-anon-key"` → `"test-publishable-key"`
- `"test-service-key"` → `"test-secret-key"`
- `SUPABASE_ANON_KEY` → `SUPABASE_PUBLISHABLE_KEY`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY` → `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`
- `EXPO_PUBLIC_SUPABASE_ANON_KEY` → `EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY`
- `SUPABASE_SERVICE_ROLE_KEY` → `SUPABASE_SECRET_KEY`
- `anon key` → `publishable key` (in descriptions/JSDoc)
- `anon/publishable key` → `publishable key`
- `service role key` → `secret key` (in descriptions)
- `anonClient` → `publishableClient`
- `getAnonClient` → `getPublishableClient`

**Step 3: Commit**

```bash
gt modify -m "refactor(supabase): rename anon/service-role to publishable/secret key"
```

---

### Task 9: Run full test suite and typecheck

**Step 1: Run all tests**

Run: `pnpm test`
Expected: All tests pass

**Step 2: Run typecheck**

Run: `pnpm typecheck`
Expected: No type errors

**Step 3: Run lint**

Run: `pnpm lint`
Expected: No lint errors (or fix with `pnpm lint:fix` if formatting-only issues)

**Step 4: Verify no remaining old references in source code**

Run: `grep -r "anon.key\|ANON_KEY\|anonKey\|SERVICE_ROLE_KEY\|supabaseServiceKey" --include="*.ts" --include="*.tsx" --include="*.md" --include="*.example" packages/ apps/ .claude/ eng-constitution.md`
Expected: No matches (the old design/plan docs in `docs/plans/` may still have historical references, which is fine)

**Step 5: Final commit if any fixes needed**

```bash
gt modify -m "refactor(supabase): rename anon/service-role to publishable/secret key"
```
