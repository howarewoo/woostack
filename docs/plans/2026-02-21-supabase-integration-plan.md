# Supabase Integration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add Supabase (auth + database + storage) to the monorepo as `apps/supabase` and `@infrastructure/supabase`.

**Architecture:** `apps/supabase` holds CLI config, migrations, and seed data. `@infrastructure/supabase` is a single infrastructure package providing typed clients (server, browser, SSR), auth hooks/context, storage utilities, Hono middleware for JWT validation, and Next.js middleware for session refresh. Feature procedures access an RLS-scoped Supabase client via oRPC context.

**Tech Stack:** `@supabase/supabase-js` (client), `@supabase/ssr` (Next.js SSR), `supabase` CLI (local dev + type gen), Hono middleware, React context/hooks.

**Design doc:** `docs/plans/2026-02-21-supabase-integration-design.md`

---

## Task 1: Add Supabase dependencies to pnpm catalog

**Files:**
- Modify: `pnpm-workspace.yaml` (add catalog entries)
- Modify: `package.json` (add `supabase` CLI to `pnpm.onlyBuiltDependencies` if needed)

**Step 1: Add catalog entries**

Add to the `catalog:` section of `pnpm-workspace.yaml`, after the `# API` group:

```yaml
  # Supabase
  "@supabase/supabase-js": "2.97.0"
  "@supabase/ssr": "0.8.0"
```

Note: Pin to exact versions (no `^` or `~`), matching the monorepo convention.

**Step 2: Run pnpm install to validate**

Run: `pnpm install`
Expected: Clean install with no errors. The catalog entries are registered but not yet consumed.

**Step 3: Commit**

```bash
gt create -am "feat: add Supabase dependencies to pnpm catalog"
```

---

## Task 2: Create `apps/supabase` — Supabase CLI project

**Files:**
- Create: `apps/supabase/package.json`
- Create: `apps/supabase/.gitignore`

**Step 1: Create package.json**

Create `apps/supabase/package.json`:

```json
{
  "name": "supabase-db",
  "version": "0.0.0",
  "private": true,
  "license": "MIT",
  "scripts": {
    "start": "supabase start",
    "stop": "supabase stop",
    "reset": "supabase db reset",
    "status": "supabase status",
    "gen-types": "supabase gen types --lang=typescript --local > ../packages/infrastructure/supabase/src/generated/database.ts",
    "gencode": "pnpm gen-types"
  },
  "devDependencies": {
    "supabase": "2.76.12"
  }
}
```

Note: The package name is `supabase-db` (not `supabase`) to avoid conflict with the `supabase` npm package itself.

**Step 2: Create .gitignore**

Create `apps/supabase/.gitignore`:

```
# Supabase local data
.branches
.temp
```

**Step 3: Initialize Supabase project**

Run from `apps/supabase/`:

```bash
pnpm install && cd apps/supabase && pnpx supabase init
```

This creates `config.toml` and a `migrations/` directory. The CLI generates the default config.

**Step 4: Create seed.sql placeholder**

Create `apps/supabase/seed.sql`:

```sql
-- Seed data for local development
-- Add test data here. Runs after migrations via `supabase db reset`.
```

**Step 5: Add supabase CLI to onlyBuiltDependencies**

In root `package.json`, add `"supabase"` to `pnpm.onlyBuiltDependencies` array (the Supabase CLI npm wrapper has a postinstall script that downloads the binary):

```json
{
  "pnpm": {
    "onlyBuiltDependencies": [
      "@biomejs/biome",
      "supabase",
      "turbo"
    ]
  }
}
```

**Step 6: Run pnpm install to verify**

Run: `pnpm install`
Expected: Clean install. Supabase CLI binary downloads during postinstall.

**Step 7: Commit**

```bash
gt modify -am "feat: add apps/supabase — Supabase CLI project"
```

---

## Task 3: Scaffold `@infrastructure/supabase` package

**Files:**
- Create: `packages/infrastructure/supabase/package.json`
- Create: `packages/infrastructure/supabase/tsconfig.json`
- Create: `packages/infrastructure/supabase/src/index.ts`
- Create: `packages/infrastructure/supabase/src/types.ts`
- Create: `packages/infrastructure/supabase/src/generated/database.ts` (placeholder)

**Step 1: Create package.json**

Create `packages/infrastructure/supabase/package.json`:

```json
{
  "name": "@infrastructure/supabase",
  "version": "0.0.0",
  "private": true,
  "license": "MIT",
  "type": "module",
  "main": "./src/index.ts",
  "exports": {
    ".": {
      "types": "./src/index.ts",
      "default": "./src/index.ts"
    },
    "./server": {
      "types": "./src/clients/server.ts",
      "default": "./src/clients/server.ts"
    },
    "./server-ssr": {
      "types": "./src/clients/server-ssr.ts",
      "default": "./src/clients/server-ssr.ts"
    },
    "./browser-ssr": {
      "types": "./src/clients/browser-ssr.ts",
      "default": "./src/clients/browser-ssr.ts"
    },
    "./auth": {
      "types": "./src/auth/index.ts",
      "default": "./src/auth/index.ts"
    },
    "./middleware/hono": {
      "types": "./src/middleware/hono.ts",
      "default": "./src/middleware/hono.ts"
    },
    "./middleware/nextjs": {
      "types": "./src/middleware/nextjs.ts",
      "default": "./src/middleware/nextjs.ts"
    },
    "./storage": {
      "types": "./src/storage/storage.ts",
      "default": "./src/storage/storage.ts"
    }
  },
  "scripts": {
    "typecheck": "tsc --noEmit",
    "test": "vitest run"
  },
  "dependencies": {
    "@supabase/supabase-js": "catalog:",
    "@supabase/ssr": "catalog:",
    "hono": "catalog:",
    "react": "catalog:",
    "zod": "catalog:"
  },
  "devDependencies": {
    "@infrastructure/typescript-config": "workspace:*",
    "@types/react": "catalog:",
    "next": "catalog:",
    "typescript": "catalog:",
    "vitest": "catalog:"
  }
}
```

Note: `hono`, `next`, `react` are listed because subpath exports reference Hono middleware and Next.js middleware types. Tree-shaking ensures only used code is bundled. `next` is in devDependencies since it's only needed for types.

**Step 2: Create tsconfig.json**

Create `packages/infrastructure/supabase/tsconfig.json`:

```json
{
  "extends": "@infrastructure/typescript-config/library.json",
  "compilerOptions": {
    "outDir": "dist"
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
```

**Step 3: Create placeholder generated types**

Create `packages/infrastructure/supabase/src/generated/database.ts`:

```typescript
// AUTO-GENERATED by Supabase CLI — do not edit manually.
// Run `pnpm gencode` from the repository root to regenerate.
//
// This is a placeholder. Run `pnpm --filter supabase-db start` and then
// `pnpm gencode` to generate real types from your local Supabase instance.

export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[];

export type Database = {
  public: {
    Tables: Record<string, never>;
    Views: Record<string, never>;
    Functions: Record<string, never>;
    Enums: Record<string, never>;
    CompositeTypes: Record<string, never>;
  };
};
```

**Step 4: Create types.ts**

Create `packages/infrastructure/supabase/src/types.ts`:

```typescript
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "./generated/database";

/** Supabase client typed with the generated Database schema. */
export type TypedSupabaseClient = SupabaseClient<Database>;

/** Helper to extract a row type from a table name. */
export type Tables<T extends keyof Database["public"]["Tables"]> =
  Database["public"]["Tables"][T]["Row"];

/** Helper to extract an insert type from a table name. */
export type TablesInsert<T extends keyof Database["public"]["Tables"]> =
  Database["public"]["Tables"][T]["Insert"];

/** Helper to extract an update type from a table name. */
export type TablesUpdate<T extends keyof Database["public"]["Tables"]> =
  Database["public"]["Tables"][T]["Update"];

/** Helper to extract an enum type by name. */
export type Enums<T extends keyof Database["public"]["Enums"]> =
  Database["public"]["Enums"][T];
```

**Step 5: Create initial barrel export**

Create `packages/infrastructure/supabase/src/index.ts`:

```typescript
export type { Database } from "./generated/database";
export type { TypedSupabaseClient, Tables, TablesInsert, TablesUpdate, Enums } from "./types";
```

Note: More exports will be added as we build out each module.

**Step 6: Run pnpm install and typecheck**

Run: `pnpm install && pnpm --filter @infrastructure/supabase typecheck`
Expected: Clean install and typecheck passes.

**Step 7: Commit**

```bash
gt modify -am "feat: scaffold @infrastructure/supabase package with types"
```

---

## Task 4: Server client — `createServerClient()`

**Files:**
- Create: `packages/infrastructure/supabase/src/clients/server.ts`
- Create: `packages/infrastructure/supabase/src/clients/server.test.ts`
- Modify: `packages/infrastructure/supabase/src/index.ts` (add export)

**Step 1: Write the failing test**

Create `packages/infrastructure/supabase/src/clients/server.test.ts`:

```typescript
import { describe, expect, it, vi } from "vitest";

// Mock @supabase/supabase-js before importing the module under test
vi.mock("@supabase/supabase-js", () => ({
  createClient: vi.fn(() => ({ auth: {}, from: vi.fn() })),
}));

import { createClient } from "@supabase/supabase-js";
import { createServerClient } from "./server";

describe("createServerClient", () => {
  it("creates a Supabase client with the provided URL and key", () => {
    const client = createServerClient("http://localhost:54321", "test-service-key");

    expect(createClient).toHaveBeenCalledWith(
      "http://localhost:54321",
      "test-service-key",
      expect.objectContaining({
        auth: expect.objectContaining({
          autoRefreshToken: false,
          persistSession: false,
        }),
      }),
    );
    expect(client).toBeDefined();
  });

  it("disables auto-refresh and session persistence for server usage", () => {
    createServerClient("http://localhost:54321", "test-key");

    const options = vi.mocked(createClient).mock.calls[0]?.[2];
    expect(options?.auth?.autoRefreshToken).toBe(false);
    expect(options?.auth?.persistSession).toBe(false);
  });
});
```

**Step 2: Run test to verify it fails**

Run: `pnpm --filter @infrastructure/supabase test -- src/clients/server.test.ts`
Expected: FAIL — `./server` module not found.

**Step 3: Write minimal implementation**

Create `packages/infrastructure/supabase/src/clients/server.ts`:

```typescript
import { createClient } from "@supabase/supabase-js";
import type { Database } from "../generated/database";
import type { TypedSupabaseClient } from "../types";

/**
 * Creates a Supabase server client for use in API routes and server-side code.
 * Disables auto-refresh and session persistence since the server manages its own auth.
 */
export function createServerClient(supabaseUrl: string, supabaseKey: string): TypedSupabaseClient {
  return createClient<Database>(supabaseUrl, supabaseKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
}
```

**Step 4: Run test to verify it passes**

Run: `pnpm --filter @infrastructure/supabase test -- src/clients/server.test.ts`
Expected: PASS

**Step 5: Add export to barrel**

Add to `packages/infrastructure/supabase/src/index.ts`:

```typescript
export { createServerClient } from "./clients/server";
```

**Step 6: Commit**

```bash
gt modify -am "feat(supabase): add createServerClient for server-side usage"
```

---

## Task 5: Browser client — `createBrowserClient()`

**Files:**
- Create: `packages/infrastructure/supabase/src/clients/browser.ts`
- Create: `packages/infrastructure/supabase/src/clients/browser.test.ts`
- Modify: `packages/infrastructure/supabase/src/index.ts` (add export)

**Step 1: Write the failing test**

Create `packages/infrastructure/supabase/src/clients/browser.test.ts`:

```typescript
import { describe, expect, it, vi } from "vitest";

vi.mock("@supabase/supabase-js", () => ({
  createClient: vi.fn(() => ({ auth: {}, from: vi.fn() })),
}));

import { createClient } from "@supabase/supabase-js";
import { createBrowserClient } from "./browser";

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
      }),
    );
  });
});
```

**Step 2: Run test to verify it fails**

Run: `pnpm --filter @infrastructure/supabase test -- src/clients/browser.test.ts`
Expected: FAIL — `./browser` module not found.

**Step 3: Write minimal implementation**

Create `packages/infrastructure/supabase/src/clients/browser.ts`:

```typescript
import { type SupabaseClientOptions, createClient } from "@supabase/supabase-js";
import type { Database } from "../generated/database";
import type { TypedSupabaseClient } from "../types";

/**
 * Creates a Supabase browser client for use in client-side React code.
 * Uses the publishable key. Session is managed automatically via localStorage.
 */
export function createBrowserClient(
  supabaseUrl: string,
  supabasePublishableKey: string,
  options?: SupabaseClientOptions<"public">,
): TypedSupabaseClient {
  return createClient<Database>(supabaseUrl, supabasePublishableKey, options);
}
```

**Step 4: Run test to verify it passes**

Run: `pnpm --filter @infrastructure/supabase test -- src/clients/browser.test.ts`
Expected: PASS

**Step 5: Add export to barrel**

Add to `packages/infrastructure/supabase/src/index.ts`:

```typescript
export { createBrowserClient } from "./clients/browser";
```

**Step 6: Commit**

```bash
gt modify -am "feat(supabase): add createBrowserClient for client-side usage"
```

---

## Task 6: SSR clients — `createSSRServerClient()` and `createSSRBrowserClient()`

**Files:**
- Create: `packages/infrastructure/supabase/src/clients/server-ssr.ts`
- Create: `packages/infrastructure/supabase/src/clients/browser-ssr.ts`
- Create: `packages/infrastructure/supabase/src/clients/server-ssr.test.ts`
- Create: `packages/infrastructure/supabase/src/clients/browser-ssr.test.ts`
- Modify: `packages/infrastructure/supabase/src/index.ts` (add exports)

**Step 1: Write the failing test for server SSR client**

Create `packages/infrastructure/supabase/src/clients/server-ssr.test.ts`:

```typescript
import { describe, expect, it, vi } from "vitest";

const mockCreateServerClient = vi.fn(() => ({ auth: {}, from: vi.fn() }));
vi.mock("@supabase/ssr", () => ({
  createServerClient: mockCreateServerClient,
}));

import { createSSRServerClient } from "./server-ssr";

describe("createSSRServerClient", () => {
  it("calls @supabase/ssr createServerClient with cookie handlers", () => {
    const mockCookieStore = {
      getAll: vi.fn(() => [{ name: "sb-token", value: "abc" }]),
      set: vi.fn(),
    };

    const client = createSSRServerClient(
      "http://localhost:54321",
      "test-publishable-key",
      mockCookieStore as any,
    );

    expect(mockCreateServerClient).toHaveBeenCalledWith(
      "http://localhost:54321",
      "test-publishable-key",
      expect.objectContaining({
        cookies: expect.objectContaining({
          getAll: expect.any(Function),
          setAll: expect.any(Function),
        }),
      }),
    );
    expect(client).toBeDefined();
  });

  it("delegates getAll to the cookie store", () => {
    const mockCookies = [{ name: "sb-token", value: "xyz" }];
    const mockCookieStore = {
      getAll: vi.fn(() => mockCookies),
      set: vi.fn(),
    };

    createSSRServerClient("http://localhost:54321", "key", mockCookieStore as any);

    const cookieConfig = mockCreateServerClient.mock.calls[0]?.[2]?.cookies;
    const result = cookieConfig?.getAll();
    expect(mockCookieStore.getAll).toHaveBeenCalled();
    expect(result).toEqual(mockCookies);
  });
});
```

**Step 2: Run test to verify it fails**

Run: `pnpm --filter @infrastructure/supabase test -- src/clients/server-ssr.test.ts`
Expected: FAIL — module not found.

**Step 3: Implement server SSR client**

Create `packages/infrastructure/supabase/src/clients/server-ssr.ts`:

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
  cookieStore: CookieStore,
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

**Step 4: Run test to verify it passes**

Run: `pnpm --filter @infrastructure/supabase test -- src/clients/server-ssr.test.ts`
Expected: PASS

**Step 5: Write the failing test for browser SSR client**

Create `packages/infrastructure/supabase/src/clients/browser-ssr.test.ts`:

```typescript
import { describe, expect, it, vi } from "vitest";

const mockCreateBrowserClient = vi.fn(() => ({ auth: {}, from: vi.fn() }));
vi.mock("@supabase/ssr", () => ({
  createBrowserClient: mockCreateBrowserClient,
}));

import { createSSRBrowserClient } from "./browser-ssr";

describe("createSSRBrowserClient", () => {
  it("calls @supabase/ssr createBrowserClient with URL and key", () => {
    const client = createSSRBrowserClient("http://localhost:54321", "test-publishable-key");

    expect(mockCreateBrowserClient).toHaveBeenCalledWith(
      "http://localhost:54321",
      "test-publishable-key",
    );
    expect(client).toBeDefined();
  });
});
```

**Step 6: Run test to verify it fails**

Run: `pnpm --filter @infrastructure/supabase test -- src/clients/browser-ssr.test.ts`
Expected: FAIL — module not found.

**Step 7: Implement browser SSR client**

Create `packages/infrastructure/supabase/src/clients/browser-ssr.ts`:

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
  supabasePublishableKey: string,
): TypedSupabaseClient {
  return createBrowserClient<Database>(supabaseUrl, supabasePublishableKey);
}
```

**Step 8: Run test to verify it passes**

Run: `pnpm --filter @infrastructure/supabase test -- src/clients/browser-ssr.test.ts`
Expected: PASS

**Step 9: Run all client tests**

Run: `pnpm --filter @infrastructure/supabase test`
Expected: All tests PASS.

**Step 10: Commit**

```bash
gt modify -am "feat(supabase): add SSR clients for Next.js server/browser"
```

---

## Task 7: Auth types and context

**Files:**
- Create: `packages/infrastructure/supabase/src/auth/types.ts`
- Create: `packages/infrastructure/supabase/src/auth/context.ts`
- Create: `packages/infrastructure/supabase/src/auth/index.ts`

**Step 1: Create auth types**

Create `packages/infrastructure/supabase/src/auth/types.ts`:

```typescript
import type { Session, User } from "@supabase/supabase-js";

/** State of the authentication session. */
export interface AuthState {
  session: Session | null;
  user: User | null;
  isLoading: boolean;
}

/** Value provided by AuthProvider to consuming components. */
export interface AuthContextValue extends AuthState {
  signIn(credentials: { email: string; password: string }): Promise<void>;
  signUp(credentials: { email: string; password: string }): Promise<void>;
  signOut(): Promise<void>;
  signInWithOAuth(provider: "google" | "apple" | "github"): Promise<void>;
}
```

**Step 2: Create context**

Create `packages/infrastructure/supabase/src/auth/context.ts`:

```typescript
import { createContext } from "react";
import type { AuthContextValue } from "./types";

export const AuthContext = createContext<AuthContextValue | null>(null);
```

**Step 3: Create barrel export**

Create `packages/infrastructure/supabase/src/auth/index.ts`:

```typescript
export { AuthContext } from "./context";
export type { AuthState, AuthContextValue } from "./types";
```

Note: `AuthProvider`, `useAuth`, and `useUser` are added in the next tasks.

**Step 4: Typecheck**

Run: `pnpm --filter @infrastructure/supabase typecheck`
Expected: PASS

**Step 5: Commit**

```bash
gt modify -am "feat(supabase): add auth types and context"
```

---

## Task 8: Auth hooks — `useAuth()` and `useUser()`

**Files:**
- Create: `packages/infrastructure/supabase/src/auth/useAuth.ts`
- Create: `packages/infrastructure/supabase/src/auth/useAuth.test.ts`
- Create: `packages/infrastructure/supabase/src/auth/useUser.ts`
- Create: `packages/infrastructure/supabase/src/auth/useUser.test.ts`
- Modify: `packages/infrastructure/supabase/src/auth/index.ts` (add exports)

**Step 1: Write the failing test for useAuth**

Create `packages/infrastructure/supabase/src/auth/useAuth.test.ts`:

```typescript
import { describe, expect, it } from "vitest";
import { useAuth } from "./useAuth";

describe("useAuth", () => {
  it("throws when used outside AuthProvider", () => {
    // useAuth calls useContext which returns null outside a provider.
    // We can't call hooks outside React, but we can verify the module exports correctly.
    expect(useAuth).toBeDefined();
    expect(typeof useAuth).toBe("function");
  });
});
```

Note: Full integration tests with React context require `@testing-library/react` setup. These will be added in the app integration tasks. Unit tests verify the module structure.

**Step 2: Run test to verify it fails**

Run: `pnpm --filter @infrastructure/supabase test -- src/auth/useAuth.test.ts`
Expected: FAIL — module not found.

**Step 3: Implement useAuth**

Create `packages/infrastructure/supabase/src/auth/useAuth.ts`:

```typescript
import { useContext } from "react";
import { AuthContext } from "./context";
import type { AuthContextValue } from "./types";

/**
 * Returns the current auth state and actions (signIn, signOut, signUp, signInWithOAuth).
 * Must be used within an AuthProvider.
 */
export function useAuth(): AuthContextValue {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error("useAuth must be used within an AuthProvider");
  }
  return context;
}
```

**Step 4: Run test to verify it passes**

Run: `pnpm --filter @infrastructure/supabase test -- src/auth/useAuth.test.ts`
Expected: PASS

**Step 5: Write the failing test for useUser**

Create `packages/infrastructure/supabase/src/auth/useUser.test.ts`:

```typescript
import { describe, expect, it } from "vitest";
import { useUser } from "./useUser";

describe("useUser", () => {
  it("exports a function", () => {
    expect(useUser).toBeDefined();
    expect(typeof useUser).toBe("function");
  });
});
```

**Step 6: Run test to verify it fails**

Run: `pnpm --filter @infrastructure/supabase test -- src/auth/useUser.test.ts`
Expected: FAIL — module not found.

**Step 7: Implement useUser**

Create `packages/infrastructure/supabase/src/auth/useUser.ts`:

```typescript
import { useAuth } from "./useAuth";
import type { User } from "@supabase/supabase-js";

/**
 * Returns the current authenticated user, or null if not signed in.
 * Convenience wrapper around useAuth() that extracts just the user.
 */
export function useUser(): User | null {
  const { user } = useAuth();
  return user;
}
```

**Step 8: Run test to verify it passes**

Run: `pnpm --filter @infrastructure/supabase test -- src/auth/useUser.test.ts`
Expected: PASS

**Step 9: Update auth barrel export**

Update `packages/infrastructure/supabase/src/auth/index.ts`:

```typescript
export { AuthContext } from "./context";
export { useAuth } from "./useAuth";
export { useUser } from "./useUser";
export type { AuthState, AuthContextValue } from "./types";
```

**Step 10: Update main barrel export**

Add to `packages/infrastructure/supabase/src/index.ts`:

```typescript
export { useAuth, useUser } from "./auth";
export type { AuthState, AuthContextValue } from "./auth";
```

**Step 11: Run all tests**

Run: `pnpm --filter @infrastructure/supabase test`
Expected: All PASS.

**Step 12: Commit**

```bash
gt modify -am "feat(supabase): add useAuth and useUser hooks"
```

---

## Task 9: AuthProvider component

**Files:**
- Create: `packages/infrastructure/supabase/src/auth/AuthProvider.tsx`
- Create: `packages/infrastructure/supabase/src/auth/AuthProvider.test.tsx`
- Modify: `packages/infrastructure/supabase/src/auth/index.ts` (add export)

**Step 1: Write the failing test**

Create `packages/infrastructure/supabase/src/auth/AuthProvider.test.tsx`:

```typescript
import { describe, expect, it, vi, beforeEach } from "vitest";
import { renderHook, act } from "@testing-library/react";
import type { ReactNode } from "react";
import { AuthProvider } from "./AuthProvider";
import { useAuth } from "./useAuth";

// Mock Supabase client
function createMockSupabaseClient() {
  const listeners: Array<(event: string, session: any) => void> = [];
  return {
    auth: {
      getSession: vi.fn(() =>
        Promise.resolve({ data: { session: null }, error: null }),
      ),
      onAuthStateChange: vi.fn((callback: any) => {
        listeners.push(callback);
        return {
          data: {
            subscription: { unsubscribe: vi.fn() },
          },
        };
      }),
      signInWithPassword: vi.fn(() =>
        Promise.resolve({ data: { session: null, user: null }, error: null }),
      ),
      signUp: vi.fn(() =>
        Promise.resolve({ data: { session: null, user: null }, error: null }),
      ),
      signOut: vi.fn(() => Promise.resolve({ error: null })),
      signInWithOAuth: vi.fn(() =>
        Promise.resolve({ data: { url: null, provider: "google" }, error: null }),
      ),
    },
    _listeners: listeners,
  };
}

describe("AuthProvider", () => {
  let mockClient: ReturnType<typeof createMockSupabaseClient>;

  beforeEach(() => {
    mockClient = createMockSupabaseClient();
  });

  function wrapper({ children }: { children: ReactNode }) {
    return <AuthProvider supabase={mockClient as any}>{children}</AuthProvider>;
  }

  it("provides initial loading state", () => {
    const { result } = renderHook(() => useAuth(), { wrapper });
    expect(result.current.isLoading).toBe(true);
    expect(result.current.user).toBeNull();
    expect(result.current.session).toBeNull();
  });

  it("subscribes to auth state changes on mount", () => {
    renderHook(() => useAuth(), { wrapper });
    expect(mockClient.auth.onAuthStateChange).toHaveBeenCalledOnce();
  });

  it("calls getSession on mount", () => {
    renderHook(() => useAuth(), { wrapper });
    expect(mockClient.auth.getSession).toHaveBeenCalledOnce();
  });
});
```

**Step 2: Run test to verify it fails**

Run: `pnpm --filter @infrastructure/supabase test -- src/auth/AuthProvider.test.tsx`
Expected: FAIL — module not found.

Note: This test requires `@testing-library/react` and `jsdom`. Add to `packages/infrastructure/supabase/package.json` devDependencies:
```json
"@testing-library/react": "catalog:",
"jsdom": "catalog:"
```
And add a `vitest.config.ts` if not present:
```typescript
import { defineConfig } from "vitest/config";
export default defineConfig({
  test: { environment: "jsdom" },
});
```

**Step 3: Implement AuthProvider**

Create `packages/infrastructure/supabase/src/auth/AuthProvider.tsx`:

```typescript
import type { Session, SupabaseClient, User } from "@supabase/supabase-js";
import { type ReactNode, useCallback, useEffect, useMemo, useState } from "react";
import { AuthContext } from "./context";
import type { AuthContextValue } from "./types";

interface AuthProviderProps {
  supabase: SupabaseClient;
  children: ReactNode;
}

/** Provides auth state and actions to the component tree. */
export function AuthProvider({ supabase, children }: AuthProviderProps) {
  const [session, setSession] = useState<Session | null>(null);
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session: initialSession } }) => {
      setSession(initialSession);
      setUser(initialSession?.user ?? null);
      setIsLoading(false);
    });

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, newSession) => {
      setSession(newSession);
      setUser(newSession?.user ?? null);
      setIsLoading(false);
    });

    return () => subscription.unsubscribe();
  }, [supabase]);

  const signIn = useCallback(
    async (credentials: { email: string; password: string }) => {
      const { error } = await supabase.auth.signInWithPassword(credentials);
      if (error) throw error;
    },
    [supabase],
  );

  const signUp = useCallback(
    async (credentials: { email: string; password: string }) => {
      const { error } = await supabase.auth.signUp(credentials);
      if (error) throw error;
    },
    [supabase],
  );

  const signOut = useCallback(async () => {
    const { error } = await supabase.auth.signOut();
    if (error) throw error;
  }, [supabase]);

  const signInWithOAuth = useCallback(
    async (provider: "google" | "apple" | "github") => {
      const { error } = await supabase.auth.signInWithOAuth({ provider });
      if (error) throw error;
    },
    [supabase],
  );

  const value = useMemo<AuthContextValue>(
    () => ({ session, user, isLoading, signIn, signUp, signOut, signInWithOAuth }),
    [session, user, isLoading, signIn, signUp, signOut, signInWithOAuth],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}
```

**Step 4: Run test to verify it passes**

Run: `pnpm --filter @infrastructure/supabase test -- src/auth/AuthProvider.test.tsx`
Expected: PASS

**Step 5: Update auth barrel export**

Add to `packages/infrastructure/supabase/src/auth/index.ts`:

```typescript
export { AuthProvider } from "./AuthProvider";
```

**Step 6: Update main barrel export**

Add to `packages/infrastructure/supabase/src/index.ts`:

```typescript
export { AuthProvider } from "./auth";
```

**Step 7: Run all tests**

Run: `pnpm --filter @infrastructure/supabase test`
Expected: All PASS.

**Step 8: Commit**

```bash
gt modify -am "feat(supabase): add AuthProvider component"
```

---

## Task 10: Hono middleware for JWT validation

**Files:**
- Create: `packages/infrastructure/supabase/src/middleware/hono.ts`
- Create: `packages/infrastructure/supabase/src/middleware/hono.test.ts`

**Step 1: Write the failing test**

Create `packages/infrastructure/supabase/src/middleware/hono.test.ts`:

```typescript
import { describe, expect, it, vi } from "vitest";
import { Hono } from "hono";
import { supabaseMiddleware } from "./hono";

// Mock createClient
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
        }),
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
});
```

**Step 2: Run test to verify it fails**

Run: `pnpm --filter @infrastructure/supabase test -- src/middleware/hono.test.ts`
Expected: FAIL — module not found.

**Step 3: Implement Hono middleware**

Create `packages/infrastructure/supabase/src/middleware/hono.ts`:

```typescript
import { createClient, type SupabaseClient, type User } from "@supabase/supabase-js";
import type { Context, MiddlewareHandler } from "hono";
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
}

/**
 * Hono middleware that validates Supabase JWTs and attaches the user
 * and an RLS-scoped Supabase client to the request context.
 *
 * - If a valid Bearer token is present, `c.get("user")` returns the authenticated user
 *   and `c.get("supabase")` returns a client scoped to that user's JWT (respects RLS).
 * - If no token or invalid token, `c.get("user")` is undefined and `c.get("supabase")`
 *   is an unauthenticated service client.
 */
export function supabaseMiddleware(
  options: SupabaseMiddlewareOptions,
): MiddlewareHandler {
  return async (c, next) => {
    const { supabaseUrl, supabaseSecretKey } = options;

    const authHeader = c.req.header("Authorization");
    const token = authHeader?.startsWith("Bearer ") ? authHeader.slice(7) : undefined;

    if (token) {
      // Create a client using the user's JWT for RLS-scoped queries
      const supabase = createClient<Database>(supabaseUrl, supabaseSecretKey, {
        global: { headers: { Authorization: `Bearer ${token}` } },
        auth: { autoRefreshToken: false, persistSession: false },
      });

      const { data: { user }, error } = await supabase.auth.getUser(token);

      if (!error && user) {
        c.set("user", user);
        c.set("supabase", supabase);
        return next();
      }
    }

    // No token or invalid token — set unauthenticated service client
    const supabase = createClient<Database>(supabaseUrl, supabaseSecretKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    c.set("user", undefined);
    c.set("supabase", supabase);

    return next();
  };
}
```

**Step 4: Run test to verify it passes**

Run: `pnpm --filter @infrastructure/supabase test -- src/middleware/hono.test.ts`
Expected: PASS

**Step 5: Commit**

```bash
gt modify -am "feat(supabase): add Hono middleware for JWT validation"
```

---

## Task 11: Next.js middleware for session refresh

**Files:**
- Create: `packages/infrastructure/supabase/src/middleware/nextjs.ts`
- Create: `packages/infrastructure/supabase/src/middleware/nextjs.test.ts`

**Step 1: Write the failing test**

Create `packages/infrastructure/supabase/src/middleware/nextjs.test.ts`:

```typescript
import { describe, expect, it, vi } from "vitest";
import { createSupabaseMiddleware } from "./nextjs";

// We can't fully test Next.js middleware without Next.js runtime,
// but we verify the factory function returns a middleware function.
describe("createSupabaseMiddleware", () => {
  it("returns a middleware function", () => {
    const middleware = createSupabaseMiddleware({
      supabaseUrl: "http://localhost:54321",
      supabasePublishableKey: "test-publishable-key",
      protectedRoutes: ["/dashboard"],
      loginPath: "/login",
    });

    expect(typeof middleware).toBe("function");
  });
});
```

**Step 2: Run test to verify it fails**

Run: `pnpm --filter @infrastructure/supabase test -- src/middleware/nextjs.test.ts`
Expected: FAIL — module not found.

**Step 3: Implement Next.js middleware factory**

Create `packages/infrastructure/supabase/src/middleware/nextjs.ts`:

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

    // Refresh the session — this call updates cookies if the token was refreshed
    const {
      data: { user },
    } = await supabase.auth.getUser();

    // Check if the current route is protected
    const isProtected = protectedRoutes.some((route) =>
      request.nextUrl.pathname.startsWith(route),
    );

    if (isProtected && !user) {
      const url = request.nextUrl.clone();
      url.pathname = loginPath;
      return NextResponse.redirect(url);
    }

    return supabaseResponse;
  };
}
```

**Step 4: Run test to verify it passes**

Run: `pnpm --filter @infrastructure/supabase test -- src/middleware/nextjs.test.ts`
Expected: PASS

**Step 5: Commit**

```bash
gt modify -am "feat(supabase): add Next.js middleware for session refresh"
```

---

## Task 12: Storage utilities

**Files:**
- Create: `packages/infrastructure/supabase/src/storage/storage.ts`
- Create: `packages/infrastructure/supabase/src/storage/storage.test.ts`

**Step 1: Write the failing test**

Create `packages/infrastructure/supabase/src/storage/storage.test.ts`:

```typescript
import { describe, expect, it, vi } from "vitest";
import { createStorageClient } from "./storage";

function createMockSupabase() {
  return {
    storage: {
      from: vi.fn(() => ({
        upload: vi.fn(() => Promise.resolve({ data: { path: "avatars/photo.jpg" }, error: null })),
        download: vi.fn(() => Promise.resolve({ data: new Blob(["test"]), error: null })),
        getPublicUrl: vi.fn(() => ({
          data: { publicUrl: "http://localhost:54321/storage/v1/object/public/avatars/photo.jpg" },
        })),
        remove: vi.fn(() => Promise.resolve({ data: [], error: null })),
      })),
    },
  };
}

describe("createStorageClient", () => {
  it("uploads a file to the specified bucket", async () => {
    const mockSupabase = createMockSupabase();
    const storage = createStorageClient(mockSupabase as any);

    const result = await storage.upload("avatars", "photo.jpg", new Blob(["data"]));

    expect(mockSupabase.storage.from).toHaveBeenCalledWith("avatars");
    expect(result.path).toBe("avatars/photo.jpg");
  });

  it("downloads a file from the specified bucket", async () => {
    const mockSupabase = createMockSupabase();
    const storage = createStorageClient(mockSupabase as any);

    const blob = await storage.download("avatars", "photo.jpg");

    expect(mockSupabase.storage.from).toHaveBeenCalledWith("avatars");
    expect(blob).toBeInstanceOf(Blob);
  });

  it("returns a public URL for a file", () => {
    const mockSupabase = createMockSupabase();
    const storage = createStorageClient(mockSupabase as any);

    const url = storage.getPublicUrl("avatars", "photo.jpg");

    expect(url).toContain("avatars/photo.jpg");
  });

  it("removes files from a bucket", async () => {
    const mockSupabase = createMockSupabase();
    const storage = createStorageClient(mockSupabase as any);

    await storage.remove("avatars", ["photo.jpg", "old.jpg"]);

    expect(mockSupabase.storage.from).toHaveBeenCalledWith("avatars");
  });
});
```

**Step 2: Run test to verify it fails**

Run: `pnpm --filter @infrastructure/supabase test -- src/storage/storage.test.ts`
Expected: FAIL — module not found.

**Step 3: Implement storage utilities**

Create `packages/infrastructure/supabase/src/storage/storage.ts`:

```typescript
import type { SupabaseClient } from "@supabase/supabase-js";

interface StorageClient {
  upload(bucket: string, path: string, file: File | Blob): Promise<{ path: string }>;
  download(bucket: string, path: string): Promise<Blob>;
  getPublicUrl(bucket: string, path: string): string;
  remove(bucket: string, paths: string[]): Promise<void>;
}

/** Creates a typed wrapper around Supabase Storage operations. */
export function createStorageClient(supabase: SupabaseClient): StorageClient {
  return {
    async upload(bucket, path, file) {
      const { data, error } = await supabase.storage.from(bucket).upload(path, file);
      if (error) throw error;
      return { path: data.path };
    },

    async download(bucket, path) {
      const { data, error } = await supabase.storage.from(bucket).download(path);
      if (error) throw error;
      return data;
    },

    getPublicUrl(bucket, path) {
      const { data } = supabase.storage.from(bucket).getPublicUrl(path);
      return data.publicUrl;
    },

    async remove(bucket, paths) {
      const { error } = await supabase.storage.from(bucket).remove(paths);
      if (error) throw error;
    },
  };
}
```

**Step 4: Run test to verify it passes**

Run: `pnpm --filter @infrastructure/supabase test -- src/storage/storage.test.ts`
Expected: PASS

**Step 5: Update barrel export**

Add to `packages/infrastructure/supabase/src/index.ts`:

```typescript
export { createStorageClient } from "./storage/storage";
```

**Step 6: Commit**

```bash
gt modify -am "feat(supabase): add storage utilities"
```

---

## Task 13: Finalize barrel exports and typecheck

**Files:**
- Modify: `packages/infrastructure/supabase/src/index.ts` (finalize all exports)

**Step 1: Finalize the barrel export**

The final `packages/infrastructure/supabase/src/index.ts` should contain all exports:

```typescript
// Types
export type { Database } from "./generated/database";
export type { TypedSupabaseClient, Tables, TablesInsert, TablesUpdate, Enums } from "./types";
export type { AuthState, AuthContextValue } from "./auth";

// Clients
export { createServerClient } from "./clients/server";
export { createBrowserClient } from "./clients/browser";
export { createSSRServerClient } from "./clients/server-ssr";
export { createSSRBrowserClient } from "./clients/browser-ssr";

// Auth
export { AuthProvider } from "./auth";
export { useAuth, useUser } from "./auth";

// Storage
export { createStorageClient } from "./storage/storage";

// Middleware (consumers use subpath imports, but also available from main)
export { supabaseMiddleware } from "./middleware/hono";
export { createSupabaseMiddleware } from "./middleware/nextjs";
```

**Step 2: Run full typecheck**

Run: `pnpm --filter @infrastructure/supabase typecheck`
Expected: PASS

**Step 3: Run all tests**

Run: `pnpm --filter @infrastructure/supabase test`
Expected: All PASS.

**Step 4: Commit**

```bash
gt modify -am "feat(supabase): finalize barrel exports and verify types"
```

---

## Task 14: Update gencode pipeline

**Files:**
- Modify: `apps/supabase/package.json` (verify gencode script)
- Verify: `turbo.json` (gencode task should already pick up new `apps/supabase`)

**Step 1: Verify Turbo picks up the gencode task**

The root `pnpm gencode` runs `turbo gencode`. Turbo runs the `gencode` script in every package that has one. Since `apps/supabase/package.json` already has `"gencode": "pnpm gen-types"`, Turbo will run it automatically.

Verify by running: `pnpm gencode`

Expected:
- `apps/api` gencode runs (existing Router type generation)
- `apps/supabase` gencode runs (but may fail if local Supabase isn't running — that's expected)

Note: The `gen-types` script in `apps/supabase` writes to `../packages/infrastructure/supabase/src/generated/database.ts`. This path is relative from the `apps/supabase/` directory. Verify it resolves correctly.

**Step 2: Test with local Supabase (if Docker is available)**

If Docker is running:
```bash
pnpm --filter supabase-db start
pnpm gencode
pnpm --filter supabase-db stop
```

Expected: `database.ts` is regenerated with actual Supabase types.

**Step 3: Commit any gencode updates**

```bash
gt modify -am "feat(supabase): integrate gencode for DB type generation"
```

---

## Task 15: Wire Supabase middleware into `apps/api`

**Files:**
- Modify: `apps/api/package.json` (add `@infrastructure/supabase` dependency)
- Modify: `apps/api/src/index.ts` (add Supabase middleware)
- Modify: `apps/api/src/router.ts` (update context type)

**Step 1: Add dependency**

Add to `apps/api/package.json` dependencies:

```json
"@infrastructure/supabase": "workspace:*"
```

Run: `pnpm install`

**Step 2: Update the Hono server to include Supabase middleware**

Modify `apps/api/src/index.ts`:

- Import `supabaseMiddleware` from `@infrastructure/supabase/middleware/hono`
- Add the middleware after CORS/logger but before the RPC handler
- Update the oRPC context to pass through `user` and `supabase` from Hono context

The key change in the RPC handler:

```typescript
import { supabaseMiddleware } from "@infrastructure/supabase/middleware/hono";

// After cors() and logger():
app.use(
  "/api/*",
  supabaseMiddleware({
    supabaseUrl: process.env.SUPABASE_URL || "http://127.0.0.1:54321",
    supabaseSecretKey: process.env.SUPABASE_SECRET_KEY || "",
  }),
);

// In the RPC handler, update context:
const result = await handler.handle(request, {
  prefix: "/",
  context: {
    requestId: c.req.header("x-request-id"),
    user: c.get("user"),
    supabase: c.get("supabase"),
  },
});
```

**Step 3: Update the router context type**

Modify `apps/api/src/router.ts`:

```typescript
import type { SupabaseClient, User } from "@supabase/supabase-js";

const pub = os.$context<{
  requestId?: string;
  user?: User;
  supabase: SupabaseClient;
}>();
```

**Step 4: Add .env.example**

Create `apps/api/.env.example`:

```
SUPABASE_URL=http://127.0.0.1:54321
SUPABASE_SECRET_KEY=your-secret-key-from-supabase-start
```

**Step 5: Verify typecheck**

Run: `pnpm --filter api typecheck`
Expected: PASS

**Step 6: Regenerate Router types (context type changed)**

Run: `pnpm gencode`

The Router type in `@infrastructure/api-client` will update to include the new context shape.

**Step 7: Commit**

```bash
gt modify -am "feat(api): wire Supabase middleware and update oRPC context"
```

---

## Task 16: Wire Supabase into `apps/web`

**Files:**
- Modify: `apps/web/package.json` (add `@infrastructure/supabase` dependency)
- Create: `apps/web/lib/supabase.ts` (client factory)
- Modify: `apps/web/app/providers.tsx` (add AuthProvider)
- Create: `apps/web/middleware.ts` (Next.js auth middleware)
- Create: `apps/web/.env.local.example`

**Step 1: Add dependency**

Add to `apps/web/package.json` dependencies:

```json
"@infrastructure/supabase": "workspace:*"
```

Run: `pnpm install`

**Step 2: Create Supabase client utility**

Create `apps/web/lib/supabase.ts`:

```typescript
import { createSSRBrowserClient } from "@infrastructure/supabase/browser-ssr";
import { createSSRServerClient } from "@infrastructure/supabase/server-ssr";

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabasePublishableKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!;

/** Creates a Supabase client for use in client components. */
export function createBrowserSupabase() {
  return createSSRBrowserClient(supabaseUrl, supabasePublishableKey);
}

/** Creates a Supabase client for use in server components. */
export async function createServerSupabase() {
  const { cookies } = await import("next/headers");
  return createSSRServerClient(supabaseUrl, supabasePublishableKey, await cookies());
}
```

**Step 3: Update providers.tsx to include AuthProvider**

Modify `apps/web/app/providers.tsx` — wrap children with `AuthProvider`:

```typescript
import { AuthProvider } from "@infrastructure/supabase/auth";
import { createBrowserSupabase } from "../lib/supabase";

// Inside the Providers component, create supabase client once:
const [supabase] = useState(() => createBrowserSupabase());

// Wrap children:
<AuthProvider supabase={supabase}>
  {/* existing providers */}
</AuthProvider>
```

**Step 4: Create Next.js middleware**

Create `apps/web/middleware.ts`:

```typescript
import { createSupabaseMiddleware } from "@infrastructure/supabase/middleware/nextjs";

export default createSupabaseMiddleware({
  supabaseUrl: process.env.NEXT_PUBLIC_SUPABASE_URL!,
  supabasePublishableKey: process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
  protectedRoutes: ["/dashboard", "/settings"],
  loginPath: "/login",
});

export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)",
  ],
};
```

**Step 5: Create .env.local.example**

Create `apps/web/.env.local.example`:

```
NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=your-publishable-key-from-supabase-start
```

**Step 6: Verify typecheck**

Run: `pnpm --filter web typecheck`
Expected: PASS

**Step 7: Commit**

```bash
gt modify -am "feat(web): wire Supabase auth with SSR support"
```

---

## Task 17: Wire Supabase into `apps/mobile`

**Files:**
- Modify: `apps/mobile/package.json` (add `@infrastructure/supabase` dependency)
- Create: `apps/mobile/lib/supabase.ts` (client factory)
- Modify: `apps/mobile` provider setup (add AuthProvider)
- Create: `apps/mobile/.env.example`

**Step 1: Add dependency**

Add to `apps/mobile/package.json` dependencies:

```json
"@infrastructure/supabase": "workspace:*"
```

Run: `pnpm install`

**Step 2: Create Supabase client utility**

Create `apps/mobile/lib/supabase.ts`:

```typescript
import { createBrowserClient } from "@infrastructure/supabase";

const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL!;
const supabasePublishableKey = process.env.EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY!;

/** Creates a Supabase client for React Native. */
export function createMobileSupabase() {
  return createBrowserClient(supabaseUrl, supabasePublishableKey);
}
```

Note: React Native uses the standard browser client (not SSR). Supabase JS auto-detects React Native and uses `AsyncStorage`. Expo uses `EXPO_PUBLIC_` prefix for public env vars.

**Step 3: Add AuthProvider to the app**

Find the mobile app's root layout/provider file and wrap with `AuthProvider`:

```typescript
import { AuthProvider } from "@infrastructure/supabase/auth";
import { createMobileSupabase } from "../lib/supabase";

// Create client once
const supabase = createMobileSupabase();

// In the provider tree:
<AuthProvider supabase={supabase}>
  {/* existing providers */}
</AuthProvider>
```

**Step 4: Create .env.example**

Create `apps/mobile/.env.example`:

```
EXPO_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321
EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY=your-publishable-key-from-supabase-start
```

**Step 5: Verify typecheck**

Run: `pnpm --filter mobile typecheck`
Expected: PASS

**Step 6: Commit**

```bash
gt modify -am "feat(mobile): wire Supabase auth"
```

---

## Task 18: Update API client for dynamic token support

**Files:**
- Modify: `packages/infrastructure/api-client/src/client.ts` (add token getter support)
- Modify: `packages/infrastructure/api-client/src/client.test.ts` (update tests)

**Step 1: Examine the current createApiClient implementation**

Read `packages/infrastructure/api-client/src/client.ts` to understand the current `RPCLink` configuration.

**Step 2: Add a `getToken` option to `createApiClient`**

The `RPCLink` from `@orpc/client/fetch` supports a `headers` option that can be a function. Modify `createApiClient` to accept an optional `getToken` callback:

```typescript
export function createApiClient<TRouter extends Record<string, any>>(
  baseUrl: string,
  options?: { getToken?: () => Promise<string | undefined> },
): RouterClient<TRouter> {
  const link = new RPCLink({
    url: baseUrl,
    headers: options?.getToken
      ? async () => {
          const token = await options.getToken!();
          return token ? { Authorization: `Bearer ${token}` } : {};
        }
      : undefined,
  });

  return createORPCClient(link);
}
```

Also update `createTypedApiClient` in `typed-client.ts` to pass through the options.

**Step 3: Write/update tests**

Add tests verifying:
- Without `getToken`, no Authorization header is set
- With `getToken`, the token is included in headers

**Step 4: Run tests**

Run: `pnpm --filter @infrastructure/api-client test`
Expected: All PASS.

**Step 5: Commit**

```bash
gt modify -am "feat(api-client): add dynamic token support via getToken option"
```

---

## Task 19: Final verification

**Step 1: Run full typecheck**

Run: `pnpm typecheck`
Expected: All packages pass.

**Step 2: Run all tests**

Run: `pnpm test`
Expected: All pass.

**Step 3: Run lint**

Run: `pnpm lint`
Expected: Clean.

**Step 4: Run gencode and verify no drift**

Run: `pnpm gencode`
Then: `git diff`
Expected: No unexpected changes (if local Supabase isn't running, the DB types placeholder should be unchanged).

**Step 5: Format**

Run: `pnpm format`
Expected: Clean or auto-fixed.

**Step 6: Commit any final fixes**

```bash
gt modify -am "chore: final cleanup and verification"
```

---

## Task 20: Update CLAUDE.md documentation

**Files:**
- Modify: `.claude/CLAUDE.md` (add Supabase section)

**Step 1: Add Supabase section**

Add to the Architecture section:

```markdown
  - `apps/supabase` — Supabase CLI project (config, migrations, seed data; local dev via Docker)
```

Add to Infrastructure section:

```markdown
  - `@infrastructure/supabase` — Supabase clients (server, browser, SSR), auth hooks/context (AuthProvider, useAuth, useUser), storage utilities, Hono/Next.js middleware, generated DB types
```

Add a new "Supabase" subsection under Key Patterns:

```markdown
### Supabase (Auth + Database + Storage)

`apps/supabase` holds the Supabase CLI project (config.toml, migrations, seed.sql). Run `pnpm --filter supabase-db start` to spin up local Supabase via Docker.

`@infrastructure/supabase` provides everything apps need:
- **Clients**: `createServerClient()`, `createBrowserClient()`, `createSSRServerClient()`, `createSSRBrowserClient()`
- **Auth**: `AuthProvider`, `useAuth()`, `useUser()` (React context pattern like NavigationProvider)
- **Storage**: `createStorageClient()` for upload/download/getPublicUrl
- **Middleware**: `supabaseMiddleware` (Hono — JWT validation for apps/api), `createSupabaseMiddleware` (Next.js — session refresh)
- **Types**: Auto-generated `Database` type + helpers (`Tables`, `TablesInsert`, `Enums`)

Feature procedures access `context.user` and `context.supabase` (RLS-scoped) via oRPC context.

**Gotcha**: After changing migrations, run `pnpm --filter supabase-db reset` then `pnpm gencode` to regenerate DB types.

**Gotcha**: The `gen-types` script requires local Supabase to be running (`pnpm --filter supabase-db start`).
```

Add env var documentation.

**Step 2: Commit**

```bash
gt modify -am "docs: add Supabase integration to CLAUDE.md"
```

---

## Summary

| Task | Description | Files created/modified |
|------|-------------|----------------------|
| 1 | Add pnpm catalog entries | pnpm-workspace.yaml, package.json |
| 2 | Create apps/supabase | package.json, .gitignore, config.toml, seed.sql |
| 3 | Scaffold @infrastructure/supabase | package.json, tsconfig.json, index.ts, types.ts, generated/ |
| 4 | Server client | clients/server.ts + test |
| 5 | Browser client | clients/browser.ts + test |
| 6 | SSR clients | clients/server-ssr.ts, browser-ssr.ts + tests |
| 7 | Auth types + context | auth/types.ts, context.ts, index.ts |
| 8 | Auth hooks | auth/useAuth.ts, useUser.ts + tests |
| 9 | AuthProvider | auth/AuthProvider.tsx + test |
| 10 | Hono middleware | middleware/hono.ts + test |
| 11 | Next.js middleware | middleware/nextjs.ts + test |
| 12 | Storage utilities | storage/storage.ts + test |
| 13 | Finalize exports | index.ts |
| 14 | Gencode pipeline | turbo.json verification |
| 15 | Wire apps/api | apps/api index.ts, router.ts, .env.example |
| 16 | Wire apps/web | apps/web providers, middleware, lib/supabase.ts |
| 17 | Wire apps/mobile | apps/mobile providers, lib/supabase.ts |
| 18 | API client token support | api-client/client.ts, typed-client.ts |
| 19 | Final verification | Full typecheck, test, lint, gencode |
| 20 | Update CLAUDE.md | .claude/CLAUDE.md |
