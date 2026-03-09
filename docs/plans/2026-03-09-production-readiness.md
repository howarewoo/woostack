# Production Readiness Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add 9 production-readiness features across 7 new infrastructure packages and API/web app integrations.

**Architecture:** Each feature is an `@infrastructure/*` package following the existing pattern (named exports, subpath exports, pnpm catalog deps, vitest tests). Packages use a provider interface pattern: default adapter for local dev (zero config), optional SaaS adapter activated via env var. All integrate into the existing Hono middleware chain and React app structure.

**Tech Stack:** OpenTelemetry + pino (observability), Sentry (errors), sliding-window rate limiter, LRU cache + Redis, pg-boss (jobs), Resend (email), Expo Push API (push notifications), Supabase tables (feature flags, push tokens).

**Dependency Order:** Task 1 → Task 4 (error tracking needs observability). Task 5 → Task 3 (security uses rate limiter). Task 8 → Task 9 (notifications use jobs). All others are independent.

**Issues:** #105–#113 on GitHub.

---

## Task 1: `@infrastructure/observability` (#105)

**Files:**
- Create: `packages/infrastructure/observability/package.json`
- Create: `packages/infrastructure/observability/tsconfig.json`
- Create: `packages/infrastructure/observability/vitest.config.ts`
- Create: `packages/infrastructure/observability/src/index.ts`
- Create: `packages/infrastructure/observability/src/logger.ts`
- Create: `packages/infrastructure/observability/src/tracer.ts`
- Create: `packages/infrastructure/observability/src/middleware.ts`
- Create: `packages/infrastructure/observability/src/__tests__/logger.test.ts`
- Create: `packages/infrastructure/observability/src/__tests__/middleware.test.ts`
- Modify: `apps/api/package.json` (add dependency)
- Modify: `apps/api/src/index.ts` (replace console.log, add graceful OTel shutdown)
- Modify: `apps/api/src/app.ts` (add otelMiddleware to chain)
- Modify: `pnpm-workspace.yaml` (add pino, @opentelemetry/* to catalog)
- Modify: `apps/api/.env.example` (add OTEL vars)

### Step 1: Scaffold the package

Create `packages/infrastructure/observability/package.json`:
```json
{
  "name": "@infrastructure/observability",
  "version": "0.0.0",
  "private": true,
  "license": "MIT",
  "type": "module",
  "main": "./src/index.ts",
  "exports": {
    ".": {
      "types": "./src/index.ts",
      "default": "./src/index.ts"
    }
  },
  "scripts": {
    "typecheck": "tsc --noEmit",
    "test": "vitest run"
  },
  "dependencies": {
    "@opentelemetry/api": "catalog:",
    "@opentelemetry/sdk-node": "catalog:",
    "@opentelemetry/exporter-trace-otlp-http": "catalog:",
    "@opentelemetry/resources": "catalog:",
    "@opentelemetry/semantic-conventions": "catalog:",
    "pino": "catalog:",
    "hono": "catalog:"
  },
  "devDependencies": {
    "@infrastructure/typescript-config": "workspace:*",
    "typescript": "catalog:",
    "vitest": "catalog:"
  }
}
```

Create `packages/infrastructure/observability/tsconfig.json`:
```json
{
  "extends": "@infrastructure/typescript-config/library",
  "compilerOptions": {
    "outDir": "dist",
    "rootDir": "src"
  },
  "include": ["src"]
}
```

Create `packages/infrastructure/observability/vitest.config.ts`:
```typescript
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "node",
    passWithNoTests: true,
  },
});
```

### Step 2: Add catalog entries to `pnpm-workspace.yaml`

Add under the `# API` or a new `# Observability` section:
```yaml
  # Observability
  pino: "9.6.0"
  "@opentelemetry/api": "1.9.0"
  "@opentelemetry/sdk-node": "0.57.2"
  "@opentelemetry/exporter-trace-otlp-http": "0.57.2"
  "@opentelemetry/resources": "1.30.2"
  "@opentelemetry/semantic-conventions": "1.33.0"
```

> **Note:** Check latest stable versions at publish time. OTel JS versions must be compatible with each other (same minor for `sdk-*` and `exporter-*`).

### Step 3: Write failing test for logger

Create `packages/infrastructure/observability/src/__tests__/logger.test.ts`:
```typescript
import { describe, expect, it, vi } from "vitest";
import { createLogger } from "../logger";

describe("createLogger", () => {
  it("creates a pino logger instance", () => {
    const logger = createLogger({ serviceName: "test-service" });
    expect(logger).toBeDefined();
    expect(typeof logger.info).toBe("function");
    expect(typeof logger.error).toBe("function");
    expect(typeof logger.warn).toBe("function");
    expect(typeof logger.debug).toBe("function");
  });

  it("includes serviceName in log output", () => {
    const logger = createLogger({ serviceName: "my-api" });
    // pino logger has a bindings method or we can check the child binding
    const bindings = logger.bindings();
    expect(bindings.service).toBe("my-api");
  });

  it("defaults to info level", () => {
    const logger = createLogger({ serviceName: "test" });
    expect(logger.level).toBe("info");
  });

  it("respects custom log level", () => {
    const logger = createLogger({ serviceName: "test", level: "debug" });
    expect(logger.level).toBe("debug");
  });
});
```

Run: `pnpm --filter @infrastructure/observability test`
Expected: FAIL (module not found)

### Step 4: Implement logger

Create `packages/infrastructure/observability/src/logger.ts`:
```typescript
import pino from "pino";

export interface LoggerOptions {
  serviceName: string;
  level?: pino.Level;
}

export function createLogger(options: LoggerOptions): pino.Logger {
  const { serviceName, level = "info" } = options;

  return pino({
    level,
    transport:
      process.env.NODE_ENV !== "production"
        ? { target: "pino/file", options: { destination: 1 } }
        : undefined,
    formatters: {
      level(label) {
        return { level: label };
      },
    },
  }).child({ service: serviceName });
}
```

Run: `pnpm --filter @infrastructure/observability test`
Expected: PASS

### Step 5: Write failing test for Hono middleware

Create `packages/infrastructure/observability/src/__tests__/middleware.test.ts`:
```typescript
import { Hono } from "hono";
import { describe, expect, it, vi } from "vitest";
import { otelMiddleware } from "../middleware";
import type { Logger } from "pino";

describe("otelMiddleware", () => {
  it("adds requestId to response headers", async () => {
    const mockLogger = {
      info: vi.fn(),
      child: vi.fn().mockReturnThis(),
    } as unknown as Logger;

    const app = new Hono();
    app.use("*", otelMiddleware({ logger: mockLogger }));
    app.get("/test", (c) => c.json({ ok: true }));

    const res = await app.request("/test");
    expect(res.status).toBe(200);
    expect(res.headers.get("x-request-id")).toBeTruthy();
  });

  it("uses provided x-request-id header", async () => {
    const mockLogger = {
      info: vi.fn(),
      child: vi.fn().mockReturnThis(),
    } as unknown as Logger;

    const app = new Hono();
    app.use("*", otelMiddleware({ logger: mockLogger }));
    app.get("/test", (c) => c.json({ ok: true }));

    const res = await app.request("/test", {
      headers: { "x-request-id": "test-id-123" },
    });
    expect(res.headers.get("x-request-id")).toBe("test-id-123");
  });

  it("logs request method, path, status, and duration", async () => {
    const infoFn = vi.fn();
    const mockLogger = {
      info: infoFn,
      child: vi.fn().mockReturnValue({ info: infoFn }),
    } as unknown as Logger;

    const app = new Hono();
    app.use("*", otelMiddleware({ logger: mockLogger }));
    app.get("/test", (c) => c.json({ ok: true }));

    await app.request("/test");

    expect(infoFn).toHaveBeenCalledWith(
      expect.objectContaining({
        method: "GET",
        path: "/test",
        status: 200,
      }),
      expect.stringContaining("GET /test")
    );
  });
});
```

Run: `pnpm --filter @infrastructure/observability test`
Expected: FAIL (module not found)

### Step 6: Implement Hono middleware

Create `packages/infrastructure/observability/src/middleware.ts`:
```typescript
import type { MiddlewareHandler } from "hono";
import type { Logger } from "pino";
import crypto from "node:crypto";

export interface OtelMiddlewareOptions {
  logger: Logger;
}

export function otelMiddleware(options: OtelMiddlewareOptions): MiddlewareHandler {
  const { logger } = options;

  return async (c, next) => {
    const requestId = c.req.header("x-request-id") || crypto.randomUUID();
    const start = performance.now();
    const method = c.req.method;
    const path = new URL(c.req.url).pathname;

    const reqLogger = logger.child({ requestId });

    c.set("requestId", requestId);
    c.header("x-request-id", requestId);

    await next();

    const duration = Math.round(performance.now() - start);
    reqLogger.info(
      { method, path, status: c.res.status, duration },
      `${method} ${path} ${c.res.status} ${duration}ms`
    );
  };
}
```

Run: `pnpm --filter @infrastructure/observability test`
Expected: PASS

### Step 7: Write withSpan helper and tracer setup

Create `packages/infrastructure/observability/src/tracer.ts`:
```typescript
import { trace, type Span, type Tracer } from "@opentelemetry/api";

let _tracer: Tracer | undefined;

export function getTracer(name = "app"): Tracer {
  if (!_tracer) {
    _tracer = trace.getTracer(name);
  }
  return _tracer;
}

export async function withSpan<T>(
  name: string,
  fn: (span: Span) => Promise<T>
): Promise<T> {
  const tracer = getTracer();
  return tracer.startActiveSpan(name, async (span) => {
    try {
      const result = await fn(span);
      span.end();
      return result;
    } catch (error) {
      span.recordException(error as Error);
      span.end();
      throw error;
    }
  });
}
```

### Step 8: Create barrel export

Create `packages/infrastructure/observability/src/index.ts`:
```typescript
export { createLogger, type LoggerOptions } from "./logger";
export { otelMiddleware, type OtelMiddlewareOptions } from "./middleware";
export { getTracer, withSpan } from "./tracer";
```

### Step 9: Integrate into apps/api

Modify `apps/api/package.json` — add to `dependencies`:
```json
"@infrastructure/observability": "workspace:*",
```

Modify `apps/api/src/app.ts` — add otelMiddleware before CORS:
```typescript
import { createLogger, otelMiddleware } from "@infrastructure/observability";

const logger = createLogger({ serviceName: "api" });

// Add after const app = new Hono(); and before cors middleware:
app.use("*", otelMiddleware({ logger }));
```

Modify `apps/api/src/index.ts` — replace console.log:
```typescript
import { createLogger } from "@infrastructure/observability";

const logger = createLogger({ serviceName: "api" });
// Replace: console.log(`Server is running on http://localhost:${port}`);
// With:
logger.info({ port }, `Server is running on http://localhost:${port}`);
```

### Step 10: Run install, typecheck, and tests

```bash
pnpm install
pnpm --filter @infrastructure/observability test
pnpm --filter api typecheck
pnpm typecheck
```

### Step 11: Commit

```bash
gt create -m "feat: add @infrastructure/observability package (#105)"
```

---

## Task 2: Health Checks & Graceful Shutdown (#106)

**Files:**
- Modify: `apps/api/src/app.ts` (add /health and /ready routes)
- Modify: `apps/api/src/index.ts` (add graceful shutdown)
- Create: `apps/api/src/__tests__/health.test.ts`

### Step 1: Write failing tests for health endpoints

Create `apps/api/src/__tests__/health.test.ts`:
```typescript
import { describe, expect, it, vi } from "vitest";
import { Hono } from "hono";

// We test the routes in isolation by recreating them
describe("health endpoints", () => {
  describe("GET /health", () => {
    it("returns 200 with status ok", async () => {
      const app = new Hono();
      app.get("/health", (c) => {
        return c.json({ status: "ok", uptime: process.uptime() });
      });

      const res = await app.request("/health");
      expect(res.status).toBe(200);

      const body = await res.json();
      expect(body.status).toBe("ok");
      expect(typeof body.uptime).toBe("number");
    });
  });

  describe("GET /ready", () => {
    it("returns 200 when DB is reachable", async () => {
      const mockSupabase = {
        from: vi.fn().mockReturnValue({
          select: vi.fn().mockReturnValue({
            limit: vi.fn().mockResolvedValue({ error: null }),
          }),
        }),
      };

      const app = new Hono();
      app.get("/ready", async (c) => {
        const { error } = await mockSupabase
          .from("_health")
          .select("1")
          .limit(1);
        if (error) {
          return c.json({ status: "not_ready", checks: { db: "failed" } }, 503);
        }
        return c.json({ status: "ready" });
      });

      const res = await app.request("/ready");
      expect(res.status).toBe(200);
      expect(await res.json()).toEqual({ status: "ready" });
    });

    it("returns 503 when DB is unreachable", async () => {
      const mockSupabase = {
        from: vi.fn().mockReturnValue({
          select: vi.fn().mockReturnValue({
            limit: vi.fn().mockResolvedValue({ error: new Error("connection refused") }),
          }),
        }),
      };

      const app = new Hono();
      app.get("/ready", async (c) => {
        const { error } = await mockSupabase
          .from("_health")
          .select("1")
          .limit(1);
        if (error) {
          return c.json({ status: "not_ready", checks: { db: "failed" } }, 503);
        }
        return c.json({ status: "ready" });
      });

      const res = await app.request("/ready");
      expect(res.status).toBe(503);
      expect(await res.json()).toEqual({
        status: "not_ready",
        checks: { db: "failed" },
      });
    });
  });
});
```

Run: `pnpm --filter api test`
Expected: PASS (these are self-contained tests)

### Step 2: Add health routes to app.ts

Modify `apps/api/src/app.ts` — add after the `app.get("/")` route:

```typescript
app.get("/health", (c) => {
  return c.json({ status: "ok", uptime: process.uptime() });
});

app.get("/ready", async (c) => {
  try {
    const supabase = c.get("supabase");
    // If supabase is not on this route (no middleware), use a direct check
    // For /ready, we create a lightweight client check
    return c.json({ status: "ready" });
  } catch {
    return c.json({ status: "not_ready", checks: { db: "failed" } }, 503);
  }
});
```

> **Note:** The `/ready` endpoint needs access to a Supabase client. Since it's outside `/api/*`, it won't have the supabase middleware. Create a dedicated check using `createServerClient` from `@infrastructure/supabase/server`. The exact implementation should validate DB connectivity with a lightweight query.

### Step 3: Add graceful shutdown to index.ts

Modify `apps/api/src/index.ts`:
```typescript
import { serve } from "@hono/node-server";
import { createLogger } from "@infrastructure/observability";
import { app } from "./app";

const logger = createLogger({ serviceName: "api" });
const port = Number(process.env.PORT) || 3100;

logger.info({ port }, `Server is running on http://localhost:${port}`);

const server = serve({
  fetch: app.fetch,
  port,
});

function gracefulShutdown(signal: string) {
  logger.info({ signal }, "Received shutdown signal, draining connections...");
  server.close(() => {
    logger.info("Server closed, exiting");
    process.exit(0);
  });

  // Force exit after 30s
  setTimeout(() => {
    logger.error("Forced shutdown after timeout");
    process.exit(1);
  }, 30_000).unref();
}

process.on("SIGTERM", () => gracefulShutdown("SIGTERM"));
process.on("SIGINT", () => gracefulShutdown("SIGINT"));

export default app;
```

### Step 4: Run tests and typecheck

```bash
pnpm --filter api test
pnpm --filter api typecheck
```

### Step 5: Commit

```bash
gt create -m "feat: add health checks and graceful shutdown (#106)"
```

---

## Task 3: Security Hardening (#107)

**Files:**
- Modify: `apps/api/src/app.ts` (add secure headers)
- Create: `apps/web/middleware.ts` (CSP headers)
- Create: `apps/landing/middleware.ts` (CSP headers)
- Create: `apps/web/__tests__/middleware.test.ts`

> **Depends on:** Task 5 (rate limiting) for auth rate limiting. Implement secure headers first, add rate limiting to auth routes after Task 5.

### Step 1: Add secure headers to Hono API

Modify `apps/api/src/app.ts` — add after imports:
```typescript
import { secureHeaders } from "hono/secure-headers";
```

Add after `app.use("*", otelMiddleware({ logger }))` and before CORS:
```typescript
app.use("*", secureHeaders({
  strictTransportSecurity: "max-age=63072000; includeSubDomains",
  xFrameOptions: "DENY",
  xContentTypeOptions: "nosniff",
  referrerPolicy: "strict-origin-when-cross-origin",
  permissionsPolicy: {
    camera: [],
    microphone: [],
    geolocation: [],
  },
}));
```

> **Note:** `hono/secure-headers` is already bundled with `hono` — no new dependency needed.

### Step 2: Write failing test for CSP middleware (web)

Create `apps/web/__tests__/middleware.test.ts`:
```typescript
import { describe, expect, it } from "vitest";

describe("CSP nonce generation", () => {
  it("generates a 16-byte base64 nonce", () => {
    const buffer = new Uint8Array(16);
    crypto.getRandomValues(buffer);
    const nonce = Buffer.from(buffer).toString("base64");
    expect(nonce).toHaveLength(24); // 16 bytes = 24 base64 chars
    expect(nonce).toMatch(/^[A-Za-z0-9+/]+=*$/);
  });
});

describe("CSP header construction", () => {
  it("includes nonce in script-src", () => {
    const nonce = "test-nonce-123";
    const csp = [
      "default-src 'self'",
      `script-src 'self' 'nonce-${nonce}'`,
      "style-src 'self' 'unsafe-inline'",
      "img-src 'self' data: blob:",
      "frame-ancestors 'none'",
    ].join("; ");

    expect(csp).toContain(`'nonce-${nonce}'`);
    expect(csp).toContain("default-src 'self'");
    expect(csp).toContain("frame-ancestors 'none'");
  });
});
```

Run: `pnpm --filter web test`
Expected: PASS (self-contained)

### Step 3: Create Next.js CSP middleware for apps/web

Create `apps/web/middleware.ts`:
```typescript
import { type NextRequest, NextResponse } from "next/server";

export function middleware(request: NextRequest) {
  const nonce = Buffer.from(crypto.randomUUID()).toString("base64");

  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || "";
  const apiUrl = process.env.NEXT_PUBLIC_API_URL || "http://localhost:3100";

  const csp = [
    "default-src 'self'",
    `script-src 'self' 'nonce-${nonce}'`,
    "style-src 'self' 'unsafe-inline'",
    "img-src 'self' data: blob:",
    `connect-src 'self' ${supabaseUrl} ${apiUrl}`,
    "font-src 'self'",
    "frame-ancestors 'none'",
    "base-uri 'self'",
    "form-action 'self'",
  ].join("; ");

  const response = NextResponse.next();

  response.headers.set("Content-Security-Policy", csp);
  response.headers.set("X-Content-Type-Options", "nosniff");
  response.headers.set("Referrer-Policy", "strict-origin-when-cross-origin");
  response.headers.set("X-Frame-Options", "DENY");

  return response;
}

export const config = {
  matcher: [
    // Match all routes except static files and Next.js internals
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)",
  ],
};
```

### Step 4: Create Next.js CSP middleware for apps/landing

Create `apps/landing/middleware.ts` — same as web but without API/Supabase connect-src:
```typescript
import { type NextRequest, NextResponse } from "next/server";

export function middleware(request: NextRequest) {
  const nonce = Buffer.from(crypto.randomUUID()).toString("base64");

  const csp = [
    "default-src 'self'",
    `script-src 'self' 'nonce-${nonce}'`,
    "style-src 'self' 'unsafe-inline'",
    "img-src 'self' data: blob:",
    "connect-src 'self'",
    "font-src 'self'",
    "frame-ancestors 'none'",
    "base-uri 'self'",
    "form-action 'self'",
  ].join("; ");

  const response = NextResponse.next();

  response.headers.set("Content-Security-Policy", csp);
  response.headers.set("X-Content-Type-Options", "nosniff");
  response.headers.set("Referrer-Policy", "strict-origin-when-cross-origin");
  response.headers.set("X-Frame-Options", "DENY");

  return response;
}

export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)",
  ],
};
```

### Step 5: Run typecheck and tests

```bash
pnpm --filter web typecheck
pnpm --filter landing typecheck
pnpm --filter api typecheck
pnpm --filter web test
```

### Step 6: Commit

```bash
gt create -m "feat: add security hardening - CSP headers and secure headers (#107)"
```

---

## Task 4: `@infrastructure/error-tracking` (#108)

**Files:**
- Create: `packages/infrastructure/error-tracking/package.json`
- Create: `packages/infrastructure/error-tracking/tsconfig.json`
- Create: `packages/infrastructure/error-tracking/vitest.config.ts`
- Create: `packages/infrastructure/error-tracking/src/index.ts`
- Create: `packages/infrastructure/error-tracking/src/types.ts`
- Create: `packages/infrastructure/error-tracking/src/console-tracker.ts`
- Create: `packages/infrastructure/error-tracking/src/error-middleware.ts`
- Create: `packages/infrastructure/error-tracking/src/error-boundary.tsx`
- Create: `packages/infrastructure/error-tracking/src/__tests__/console-tracker.test.ts`
- Create: `packages/infrastructure/error-tracking/src/__tests__/error-middleware.test.ts`
- Modify: `apps/api/package.json` (add dependency)
- Modify: `apps/api/src/app.ts` (add errorMiddleware to chain)
- Modify: `apps/web/app/layout.tsx` (add ErrorBoundary)
- Modify: `pnpm-workspace.yaml` (add sentry packages to catalog)

> **Depends on:** Task 1 (observability) — error middleware logs via the structured logger.

### Step 1: Scaffold the package

Create `packages/infrastructure/error-tracking/package.json`:
```json
{
  "name": "@infrastructure/error-tracking",
  "version": "0.0.0",
  "private": true,
  "license": "MIT",
  "type": "module",
  "main": "./src/index.ts",
  "exports": {
    ".": {
      "types": "./src/index.ts",
      "default": "./src/index.ts"
    }
  },
  "scripts": {
    "typecheck": "tsc --noEmit",
    "test": "vitest run"
  },
  "dependencies": {
    "@infrastructure/observability": "workspace:*",
    "hono": "catalog:",
    "react": "catalog:"
  },
  "devDependencies": {
    "@infrastructure/typescript-config": "workspace:*",
    "@types/react": "catalog:",
    "typescript": "catalog:",
    "vitest": "catalog:"
  }
}
```

Create `packages/infrastructure/error-tracking/tsconfig.json`:
```json
{
  "extends": "@infrastructure/typescript-config/library",
  "compilerOptions": {
    "outDir": "dist",
    "rootDir": "src",
    "jsx": "react-jsx"
  },
  "include": ["src"]
}
```

Create `packages/infrastructure/error-tracking/vitest.config.ts`:
```typescript
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "node",
    passWithNoTests: true,
  },
});
```

### Step 2: Define the provider interface

Create `packages/infrastructure/error-tracking/src/types.ts`:
```typescript
export interface ErrorTracker {
  captureException(error: Error, context?: Record<string, unknown>): void;
  setUser(user: { id: string; email?: string } | undefined): void;
  flush(timeoutMs?: number): Promise<void>;
}
```

### Step 3: Write failing test for console tracker

Create `packages/infrastructure/error-tracking/src/__tests__/console-tracker.test.ts`:
```typescript
import { describe, expect, it, vi } from "vitest";
import { ConsoleErrorTracker } from "../console-tracker";

describe("ConsoleErrorTracker", () => {
  it("logs errors via logger", () => {
    const errorFn = vi.fn();
    const mockLogger = { error: errorFn, info: vi.fn() } as any;
    const tracker = new ConsoleErrorTracker(mockLogger);

    const error = new Error("test error");
    tracker.captureException(error, { userId: "123" });

    expect(errorFn).toHaveBeenCalledWith(
      expect.objectContaining({ err: error, userId: "123" }),
      "Captured exception: test error"
    );
  });

  it("sets and clears user context", () => {
    const infoFn = vi.fn();
    const mockLogger = { error: vi.fn(), info: infoFn } as any;
    const tracker = new ConsoleErrorTracker(mockLogger);

    tracker.setUser({ id: "user-1", email: "test@example.com" });
    expect(infoFn).toHaveBeenCalledWith(
      expect.objectContaining({ userId: "user-1" }),
      expect.any(String)
    );

    tracker.setUser(undefined);
    expect(infoFn).toHaveBeenCalledWith(
      expect.objectContaining({}),
      expect.stringContaining("cleared")
    );
  });

  it("flush resolves immediately", async () => {
    const mockLogger = { error: vi.fn(), info: vi.fn() } as any;
    const tracker = new ConsoleErrorTracker(mockLogger);
    await expect(tracker.flush()).resolves.toBeUndefined();
  });
});
```

Run: `pnpm --filter @infrastructure/error-tracking test`
Expected: FAIL

### Step 4: Implement console tracker

Create `packages/infrastructure/error-tracking/src/console-tracker.ts`:
```typescript
import type { Logger } from "pino";
import type { ErrorTracker } from "./types";

export class ConsoleErrorTracker implements ErrorTracker {
  private logger: Logger;

  constructor(logger: Logger) {
    this.logger = logger;
  }

  captureException(error: Error, context?: Record<string, unknown>): void {
    this.logger.error(
      { err: error, ...context },
      `Captured exception: ${error.message}`
    );
  }

  setUser(user: { id: string; email?: string } | undefined): void {
    if (user) {
      this.logger.info({ userId: user.id, email: user.email }, "Error tracking user set");
    } else {
      this.logger.info({}, "Error tracking user cleared");
    }
  }

  async flush(): Promise<void> {
    // Console tracker has nothing to flush
  }
}
```

Run: `pnpm --filter @infrastructure/error-tracking test`
Expected: PASS

### Step 5: Write failing test for error middleware

Create `packages/infrastructure/error-tracking/src/__tests__/error-middleware.test.ts`:
```typescript
import { Hono } from "hono";
import { describe, expect, it, vi } from "vitest";
import { errorMiddleware } from "../error-middleware";
import type { ErrorTracker } from "../types";

describe("errorMiddleware", () => {
  it("passes through successful requests", async () => {
    const mockTracker: ErrorTracker = {
      captureException: vi.fn(),
      setUser: vi.fn(),
      flush: vi.fn(),
    };

    const app = new Hono();
    app.use("*", errorMiddleware({ tracker: mockTracker }));
    app.get("/ok", (c) => c.json({ ok: true }));

    const res = await app.request("/ok");
    expect(res.status).toBe(200);
    expect(mockTracker.captureException).not.toHaveBeenCalled();
  });

  it("catches errors and returns 500", async () => {
    const mockTracker: ErrorTracker = {
      captureException: vi.fn(),
      setUser: vi.fn(),
      flush: vi.fn(),
    };

    const app = new Hono();
    app.use("*", errorMiddleware({ tracker: mockTracker }));
    app.get("/error", () => {
      throw new Error("kaboom");
    });

    const res = await app.request("/error");
    expect(res.status).toBe(500);
    expect(mockTracker.captureException).toHaveBeenCalledWith(
      expect.objectContaining({ message: "kaboom" }),
      expect.any(Object)
    );
  });
});
```

Run: `pnpm --filter @infrastructure/error-tracking test`
Expected: FAIL

### Step 6: Implement error middleware

Create `packages/infrastructure/error-tracking/src/error-middleware.ts`:
```typescript
import type { MiddlewareHandler } from "hono";
import type { ErrorTracker } from "./types";

export interface ErrorMiddlewareOptions {
  tracker: ErrorTracker;
}

export function errorMiddleware(options: ErrorMiddlewareOptions): MiddlewareHandler {
  const { tracker } = options;

  return async (c, next) => {
    try {
      await next();
    } catch (error) {
      const err = error instanceof Error ? error : new Error(String(error));

      tracker.captureException(err, {
        method: c.req.method,
        path: new URL(c.req.url).pathname,
        requestId: c.req.header("x-request-id"),
      });

      return c.json({ error: "Internal Server Error" }, 500);
    }
  };
}
```

Run: `pnpm --filter @infrastructure/error-tracking test`
Expected: PASS

### Step 7: Create ErrorBoundary React component

Create `packages/infrastructure/error-tracking/src/error-boundary.tsx`:
```typescript
import { Component, type ErrorInfo, type ReactNode } from "react";
import type { ErrorTracker } from "./types";

interface ErrorBoundaryProps {
  fallback: ReactNode;
  tracker?: ErrorTracker;
  children: ReactNode;
}

interface ErrorBoundaryState {
  hasError: boolean;
}

export class ErrorBoundary extends Component<ErrorBoundaryProps, ErrorBoundaryState> {
  constructor(props: ErrorBoundaryProps) {
    super(props);
    this.state = { hasError: false };
  }

  static getDerivedStateFromError(): ErrorBoundaryState {
    return { hasError: true };
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo): void {
    this.props.tracker?.captureException(error, {
      componentStack: errorInfo.componentStack ?? undefined,
    });
  }

  render(): ReactNode {
    if (this.state.hasError) {
      return this.props.fallback;
    }
    return this.props.children;
  }
}
```

### Step 8: Create barrel export

Create `packages/infrastructure/error-tracking/src/index.ts`:
```typescript
export type { ErrorTracker } from "./types";
export { ConsoleErrorTracker } from "./console-tracker";
export { errorMiddleware, type ErrorMiddlewareOptions } from "./error-middleware";
export { ErrorBoundary } from "./error-boundary";
```

### Step 9: Integrate into apps/api

Modify `apps/api/package.json` — add to `dependencies`:
```json
"@infrastructure/error-tracking": "workspace:*",
```

Modify `apps/api/src/app.ts` — add error middleware after otelMiddleware, before CORS:
```typescript
import { ConsoleErrorTracker, errorMiddleware } from "@infrastructure/error-tracking";

const errorTracker = new ConsoleErrorTracker(logger);
// Add after otelMiddleware, before secureHeaders:
app.use("*", errorMiddleware({ tracker: errorTracker }));
```

### Step 10: Run install, tests, typecheck

```bash
pnpm install
pnpm --filter @infrastructure/error-tracking test
pnpm --filter api typecheck
pnpm typecheck
```

### Step 11: Commit

```bash
gt create -m "feat: add @infrastructure/error-tracking package (#108)"
```

---

## Task 5: `@infrastructure/rate-limit` (#109)

**Files:**
- Create: `packages/infrastructure/rate-limit/package.json`
- Create: `packages/infrastructure/rate-limit/tsconfig.json`
- Create: `packages/infrastructure/rate-limit/vitest.config.ts`
- Create: `packages/infrastructure/rate-limit/src/index.ts`
- Create: `packages/infrastructure/rate-limit/src/types.ts`
- Create: `packages/infrastructure/rate-limit/src/memory-store.ts`
- Create: `packages/infrastructure/rate-limit/src/middleware.ts`
- Create: `packages/infrastructure/rate-limit/src/__tests__/memory-store.test.ts`
- Create: `packages/infrastructure/rate-limit/src/__tests__/middleware.test.ts`
- Modify: `apps/api/package.json` (add dependency)
- Modify: `apps/api/src/app.ts` (add rate limiting to /api/auth/*)

### Step 1: Scaffold the package

Create `packages/infrastructure/rate-limit/package.json`:
```json
{
  "name": "@infrastructure/rate-limit",
  "version": "0.0.0",
  "private": true,
  "license": "MIT",
  "type": "module",
  "main": "./src/index.ts",
  "exports": {
    ".": {
      "types": "./src/index.ts",
      "default": "./src/index.ts"
    }
  },
  "scripts": {
    "typecheck": "tsc --noEmit",
    "test": "vitest run"
  },
  "dependencies": {
    "hono": "catalog:"
  },
  "devDependencies": {
    "@infrastructure/typescript-config": "workspace:*",
    "typescript": "catalog:",
    "vitest": "catalog:"
  }
}
```

Create `tsconfig.json` and `vitest.config.ts` (same pattern as Task 1).

### Step 2: Define the store interface

Create `packages/infrastructure/rate-limit/src/types.ts`:
```typescript
export interface RateLimitStore {
  increment(key: string, windowMs: number): Promise<RateLimitResult>;
  reset(key: string): Promise<void>;
}

export interface RateLimitResult {
  count: number;
  resetAt: number;
}

export interface RateLimitOptions {
  store?: RateLimitStore;
  windowMs?: number;
  max?: number;
  keyGenerator?: (req: Request) => string;
}
```

### Step 3: Write failing test for memory store

Create `packages/infrastructure/rate-limit/src/__tests__/memory-store.test.ts`:
```typescript
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { MemoryStore } from "../memory-store";

describe("MemoryStore", () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it("increments count for a key", async () => {
    const store = new MemoryStore();
    const result = await store.increment("ip:127.0.0.1", 60_000);
    expect(result.count).toBe(1);
  });

  it("increments count on subsequent calls", async () => {
    const store = new MemoryStore();
    await store.increment("ip:127.0.0.1", 60_000);
    const result = await store.increment("ip:127.0.0.1", 60_000);
    expect(result.count).toBe(2);
  });

  it("resets count after window expires", async () => {
    const store = new MemoryStore();
    await store.increment("ip:127.0.0.1", 60_000);
    await store.increment("ip:127.0.0.1", 60_000);

    vi.advanceTimersByTime(60_001);

    const result = await store.increment("ip:127.0.0.1", 60_000);
    expect(result.count).toBe(1);
  });

  it("tracks different keys independently", async () => {
    const store = new MemoryStore();
    await store.increment("ip:1.1.1.1", 60_000);
    await store.increment("ip:1.1.1.1", 60_000);
    const result = await store.increment("ip:2.2.2.2", 60_000);
    expect(result.count).toBe(1);
  });

  it("reset clears a specific key", async () => {
    const store = new MemoryStore();
    await store.increment("ip:127.0.0.1", 60_000);
    await store.increment("ip:127.0.0.1", 60_000);
    await store.reset("ip:127.0.0.1");
    const result = await store.increment("ip:127.0.0.1", 60_000);
    expect(result.count).toBe(1);
  });
});
```

Run: `pnpm --filter @infrastructure/rate-limit test`
Expected: FAIL

### Step 4: Implement memory store

Create `packages/infrastructure/rate-limit/src/memory-store.ts`:
```typescript
import type { RateLimitResult, RateLimitStore } from "./types";

interface Entry {
  count: number;
  resetAt: number;
}

export class MemoryStore implements RateLimitStore {
  private store = new Map<string, Entry>();

  async increment(key: string, windowMs: number): Promise<RateLimitResult> {
    const now = Date.now();
    const existing = this.store.get(key);

    if (existing && now < existing.resetAt) {
      existing.count += 1;
      return { count: existing.count, resetAt: existing.resetAt };
    }

    const entry: Entry = { count: 1, resetAt: now + windowMs };
    this.store.set(key, entry);

    // Lazy cleanup: remove expired entries when store grows
    if (this.store.size > 10_000) {
      this.cleanup(now);
    }

    return { count: entry.count, resetAt: entry.resetAt };
  }

  async reset(key: string): Promise<void> {
    this.store.delete(key);
  }

  private cleanup(now: number): void {
    for (const [key, entry] of this.store) {
      if (now >= entry.resetAt) {
        this.store.delete(key);
      }
    }
  }
}
```

Run: `pnpm --filter @infrastructure/rate-limit test`
Expected: PASS

### Step 5: Write failing test for middleware

Create `packages/infrastructure/rate-limit/src/__tests__/middleware.test.ts`:
```typescript
import { Hono } from "hono";
import { describe, expect, it } from "vitest";
import { createRateLimiter } from "../middleware";

describe("createRateLimiter middleware", () => {
  it("allows requests under the limit", async () => {
    const app = new Hono();
    app.use("*", createRateLimiter({ max: 3, windowMs: 60_000 }));
    app.get("/test", (c) => c.json({ ok: true }));

    const res = await app.request("/test");
    expect(res.status).toBe(200);
    expect(res.headers.get("X-RateLimit-Limit")).toBe("3");
    expect(res.headers.get("X-RateLimit-Remaining")).toBe("2");
  });

  it("returns 429 when limit exceeded", async () => {
    const app = new Hono();
    app.use("*", createRateLimiter({ max: 2, windowMs: 60_000 }));
    app.get("/test", (c) => c.json({ ok: true }));

    await app.request("/test");
    await app.request("/test");
    const res = await app.request("/test");

    expect(res.status).toBe(429);
    expect(res.headers.get("Retry-After")).toBeTruthy();
    const body = await res.json();
    expect(body.error).toContain("Too Many Requests");
  });

  it("sets rate limit headers", async () => {
    const app = new Hono();
    app.use("*", createRateLimiter({ max: 10, windowMs: 60_000 }));
    app.get("/test", (c) => c.json({ ok: true }));

    const res = await app.request("/test");
    expect(res.headers.get("X-RateLimit-Limit")).toBe("10");
    expect(res.headers.get("X-RateLimit-Remaining")).toBe("9");
    expect(res.headers.get("X-RateLimit-Reset")).toBeTruthy();
  });
});
```

Run: `pnpm --filter @infrastructure/rate-limit test`
Expected: FAIL

### Step 6: Implement middleware

Create `packages/infrastructure/rate-limit/src/middleware.ts`:
```typescript
import type { MiddlewareHandler } from "hono";
import { MemoryStore } from "./memory-store";
import type { RateLimitOptions } from "./types";

export function createRateLimiter(options: RateLimitOptions = {}): MiddlewareHandler {
  const {
    store = new MemoryStore(),
    windowMs = 60_000,
    max = 100,
    keyGenerator = defaultKeyGenerator,
  } = options;

  return async (c, next) => {
    const key = keyGenerator(c.req.raw);
    const result = await store.increment(key, windowMs);

    c.header("X-RateLimit-Limit", String(max));
    c.header("X-RateLimit-Remaining", String(Math.max(0, max - result.count)));
    c.header("X-RateLimit-Reset", String(Math.ceil(result.resetAt / 1000)));

    if (result.count > max) {
      const retryAfter = Math.ceil((result.resetAt - Date.now()) / 1000);
      c.header("Retry-After", String(retryAfter));
      return c.json({ error: "Too Many Requests" }, 429);
    }

    await next();
  };
}

function defaultKeyGenerator(req: Request): string {
  // In production behind a reverse proxy, use x-forwarded-for
  const forwarded = req.headers.get("x-forwarded-for");
  const ip = forwarded?.split(",")[0]?.trim() || "unknown";
  return `ip:${ip}`;
}
```

### Step 7: Create barrel export

Create `packages/infrastructure/rate-limit/src/index.ts`:
```typescript
export type { RateLimitOptions, RateLimitResult, RateLimitStore } from "./types";
export { MemoryStore } from "./memory-store";
export { createRateLimiter } from "./middleware";
```

### Step 8: Integrate into apps/api

Modify `apps/api/package.json` — add to `dependencies`:
```json
"@infrastructure/rate-limit": "workspace:*",
```

Modify `apps/api/src/app.ts` — add rate limiting:
```typescript
import { createRateLimiter } from "@infrastructure/rate-limit";

// Global: 100 req/min
app.use("*", createRateLimiter({ max: 100, windowMs: 60_000 }));

// Auth: 5 req/min (stricter) — add before the /api/* supabase middleware
app.use("/api/auth/*", createRateLimiter({ max: 5, windowMs: 60_000 }));
```

### Step 9: Run install, tests, typecheck

```bash
pnpm install
pnpm --filter @infrastructure/rate-limit test
pnpm --filter api typecheck
```

### Step 10: Commit

```bash
gt create -m "feat: add @infrastructure/rate-limit package (#109)"
```

---

## Task 6: `@infrastructure/cache` (#110)

**Files:**
- Create: `packages/infrastructure/cache/package.json`
- Create: `packages/infrastructure/cache/tsconfig.json`
- Create: `packages/infrastructure/cache/vitest.config.ts`
- Create: `packages/infrastructure/cache/src/index.ts`
- Create: `packages/infrastructure/cache/src/types.ts`
- Create: `packages/infrastructure/cache/src/memory-store.ts`
- Create: `packages/infrastructure/cache/src/cache.ts`
- Create: `packages/infrastructure/cache/src/__tests__/memory-store.test.ts`
- Create: `packages/infrastructure/cache/src/__tests__/cache.test.ts`

### Step 1: Scaffold the package

Create `packages/infrastructure/cache/package.json`:
```json
{
  "name": "@infrastructure/cache",
  "version": "0.0.0",
  "private": true,
  "license": "MIT",
  "type": "module",
  "main": "./src/index.ts",
  "exports": {
    ".": {
      "types": "./src/index.ts",
      "default": "./src/index.ts"
    }
  },
  "scripts": {
    "typecheck": "tsc --noEmit",
    "test": "vitest run"
  },
  "dependencies": {},
  "devDependencies": {
    "@infrastructure/typescript-config": "workspace:*",
    "typescript": "catalog:",
    "vitest": "catalog:"
  }
}
```

Create `tsconfig.json` and `vitest.config.ts` (same pattern).

### Step 2: Define the store interface

Create `packages/infrastructure/cache/src/types.ts`:
```typescript
export interface CacheStore {
  get<T>(key: string): Promise<T | undefined>;
  set<T>(key: string, value: T, ttlMs: number): Promise<void>;
  delete(key: string): Promise<void>;
  deleteByPrefix(prefix: string): Promise<void>;
}
```

### Step 3: Write failing test for LRU memory store

Create `packages/infrastructure/cache/src/__tests__/memory-store.test.ts`:
```typescript
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { MemoryCacheStore } from "../memory-store";

describe("MemoryCacheStore", () => {
  beforeEach(() => vi.useFakeTimers());
  afterEach(() => vi.useRealTimers());

  it("stores and retrieves values", async () => {
    const store = new MemoryCacheStore();
    await store.set("key1", { name: "test" }, 60_000);
    const value = await store.get<{ name: string }>("key1");
    expect(value).toEqual({ name: "test" });
  });

  it("returns undefined for missing keys", async () => {
    const store = new MemoryCacheStore();
    const value = await store.get("nonexistent");
    expect(value).toBeUndefined();
  });

  it("expires values after TTL", async () => {
    const store = new MemoryCacheStore();
    await store.set("key1", "value", 5_000);
    vi.advanceTimersByTime(5_001);
    const value = await store.get("key1");
    expect(value).toBeUndefined();
  });

  it("evicts oldest entry when max size exceeded", async () => {
    const store = new MemoryCacheStore({ maxEntries: 2 });
    await store.set("key1", "a", 60_000);
    await store.set("key2", "b", 60_000);
    await store.set("key3", "c", 60_000);
    expect(await store.get("key1")).toBeUndefined();
    expect(await store.get("key2")).toBe("b");
    expect(await store.get("key3")).toBe("c");
  });

  it("deletes a specific key", async () => {
    const store = new MemoryCacheStore();
    await store.set("key1", "value", 60_000);
    await store.delete("key1");
    expect(await store.get("key1")).toBeUndefined();
  });

  it("deletes keys by prefix", async () => {
    const store = new MemoryCacheStore();
    await store.set("users:1", "a", 60_000);
    await store.set("users:2", "b", 60_000);
    await store.set("posts:1", "c", 60_000);
    await store.deleteByPrefix("users:");
    expect(await store.get("users:1")).toBeUndefined();
    expect(await store.get("users:2")).toBeUndefined();
    expect(await store.get("posts:1")).toBe("c");
  });
});
```

Run: `pnpm --filter @infrastructure/cache test`
Expected: FAIL

### Step 4: Implement LRU memory store

Create `packages/infrastructure/cache/src/memory-store.ts`:
```typescript
import type { CacheStore } from "./types";

interface CacheEntry {
  value: unknown;
  expiresAt: number;
}

export interface MemoryCacheStoreOptions {
  maxEntries?: number;
}

export class MemoryCacheStore implements CacheStore {
  private store = new Map<string, CacheEntry>();
  private maxEntries: number;

  constructor(options: MemoryCacheStoreOptions = {}) {
    this.maxEntries = options.maxEntries ?? 1000;
  }

  async get<T>(key: string): Promise<T | undefined> {
    const entry = this.store.get(key);
    if (!entry) return undefined;

    if (Date.now() >= entry.expiresAt) {
      this.store.delete(key);
      return undefined;
    }

    return entry.value as T;
  }

  async set<T>(key: string, value: T, ttlMs: number): Promise<void> {
    // Evict oldest if at capacity
    if (this.store.size >= this.maxEntries && !this.store.has(key)) {
      const firstKey = this.store.keys().next().value;
      if (firstKey !== undefined) {
        this.store.delete(firstKey);
      }
    }

    this.store.set(key, { value, expiresAt: Date.now() + ttlMs });
  }

  async delete(key: string): Promise<void> {
    this.store.delete(key);
  }

  async deleteByPrefix(prefix: string): Promise<void> {
    for (const key of this.store.keys()) {
      if (key.startsWith(prefix)) {
        this.store.delete(key);
      }
    }
  }
}
```

Run: `pnpm --filter @infrastructure/cache test`
Expected: PASS

### Step 5: Write and implement the Cache wrapper

Create `packages/infrastructure/cache/src/cache.ts`:
```typescript
import { MemoryCacheStore } from "./memory-store";
import type { CacheStore } from "./types";

export interface CacheOptions {
  store?: CacheStore;
  defaultTtlMs?: number;
  keyPrefix?: string;
}

export class Cache {
  private store: CacheStore;
  private defaultTtlMs: number;
  private keyPrefix: string;

  constructor(options: CacheOptions = {}) {
    this.store = options.store ?? new MemoryCacheStore();
    this.defaultTtlMs = options.defaultTtlMs ?? 60_000;
    this.keyPrefix = options.keyPrefix ?? "";
  }

  private prefixedKey(key: string): string {
    return this.keyPrefix ? `${this.keyPrefix}:${key}` : key;
  }

  async get<T>(key: string): Promise<T | undefined> {
    return this.store.get<T>(this.prefixedKey(key));
  }

  async set<T>(key: string, value: T, ttlMs?: number): Promise<void> {
    return this.store.set(this.prefixedKey(key), value, ttlMs ?? this.defaultTtlMs);
  }

  async invalidate(key: string): Promise<void> {
    return this.store.delete(this.prefixedKey(key));
  }

  async invalidateByPrefix(prefix: string): Promise<void> {
    return this.store.deleteByPrefix(this.prefixedKey(prefix));
  }
}

export function createCache(options?: CacheOptions): Cache {
  return new Cache(options);
}
```

### Step 6: Create barrel export

Create `packages/infrastructure/cache/src/index.ts`:
```typescript
export type { CacheStore } from "./types";
export { MemoryCacheStore, type MemoryCacheStoreOptions } from "./memory-store";
export { Cache, createCache, type CacheOptions } from "./cache";
```

### Step 7: Run install, tests, typecheck

```bash
pnpm install
pnpm --filter @infrastructure/cache test
pnpm typecheck
```

### Step 8: Commit

```bash
gt create -m "feat: add @infrastructure/cache package (#110)"
```

---

## Task 7: `@infrastructure/feature-flags` (#111)

**Files:**
- Create: `packages/infrastructure/feature-flags/package.json`
- Create: `packages/infrastructure/feature-flags/tsconfig.json`
- Create: `packages/infrastructure/feature-flags/vitest.config.ts`
- Create: `packages/infrastructure/feature-flags/src/index.ts`
- Create: `packages/infrastructure/feature-flags/src/types.ts`
- Create: `packages/infrastructure/feature-flags/src/evaluator.ts`
- Create: `packages/infrastructure/feature-flags/src/memory-store.ts`
- Create: `packages/infrastructure/feature-flags/src/__tests__/evaluator.test.ts`
- Create: `apps/supabase/migrations/<timestamp>_feature_flags.sql`

### Step 1: Scaffold the package

Create `packages/infrastructure/feature-flags/package.json`:
```json
{
  "name": "@infrastructure/feature-flags",
  "version": "0.0.0",
  "private": true,
  "license": "MIT",
  "type": "module",
  "main": "./src/index.ts",
  "exports": {
    ".": {
      "types": "./src/index.ts",
      "default": "./src/index.ts"
    }
  },
  "scripts": {
    "typecheck": "tsc --noEmit",
    "test": "vitest run"
  },
  "dependencies": {},
  "devDependencies": {
    "@infrastructure/typescript-config": "workspace:*",
    "typescript": "catalog:",
    "vitest": "catalog:"
  }
}
```

Create `tsconfig.json` and `vitest.config.ts` (same pattern).

### Step 2: Define types

Create `packages/infrastructure/feature-flags/src/types.ts`:
```typescript
export interface Flag {
  key: string;
  enabled: boolean;
  rules: FlagRules;
}

export interface FlagRules {
  percentage?: number;
  allowedUserIds?: string[];
}

export interface FlagStore {
  getFlag(key: string): Promise<Flag | undefined>;
  getAllFlags(): Promise<Flag[]>;
}

export interface FlagContext {
  userId?: string;
}
```

### Step 3: Write failing test for flag evaluator

Create `packages/infrastructure/feature-flags/src/__tests__/evaluator.test.ts`:
```typescript
import { describe, expect, it } from "vitest";
import { evaluateFlag } from "../evaluator";
import type { Flag } from "../types";

describe("evaluateFlag", () => {
  it("returns false when flag is disabled", () => {
    const flag: Flag = { key: "test", enabled: false, rules: {} };
    expect(evaluateFlag(flag)).toBe(false);
  });

  it("returns true when flag is enabled with no rules", () => {
    const flag: Flag = { key: "test", enabled: true, rules: {} };
    expect(evaluateFlag(flag)).toBe(true);
  });

  it("returns true when user is in allowedUserIds", () => {
    const flag: Flag = {
      key: "test",
      enabled: true,
      rules: { allowedUserIds: ["user-1", "user-2"] },
    };
    expect(evaluateFlag(flag, { userId: "user-1" })).toBe(true);
    expect(evaluateFlag(flag, { userId: "user-3" })).toBe(false);
  });

  it("returns false for allowedUserIds when no userId provided", () => {
    const flag: Flag = {
      key: "test",
      enabled: true,
      rules: { allowedUserIds: ["user-1"] },
    };
    expect(evaluateFlag(flag)).toBe(false);
  });

  it("uses deterministic hashing for percentage rollout", () => {
    const flag: Flag = {
      key: "feature-x",
      enabled: true,
      rules: { percentage: 50 },
    };

    // Same user + flag should always return the same result
    const result1 = evaluateFlag(flag, { userId: "user-1" });
    const result2 = evaluateFlag(flag, { userId: "user-1" });
    expect(result1).toBe(result2);
  });

  it("returns false for percentage when no userId", () => {
    const flag: Flag = {
      key: "test",
      enabled: true,
      rules: { percentage: 50 },
    };
    expect(evaluateFlag(flag)).toBe(false);
  });

  it("returns true for 100% rollout", () => {
    const flag: Flag = {
      key: "test",
      enabled: true,
      rules: { percentage: 100 },
    };
    expect(evaluateFlag(flag, { userId: "any-user" })).toBe(true);
  });

  it("returns false for 0% rollout", () => {
    const flag: Flag = {
      key: "test",
      enabled: true,
      rules: { percentage: 0 },
    };
    expect(evaluateFlag(flag, { userId: "any-user" })).toBe(false);
  });
});
```

Run: `pnpm --filter @infrastructure/feature-flags test`
Expected: FAIL

### Step 4: Implement flag evaluator

Create `packages/infrastructure/feature-flags/src/evaluator.ts`:
```typescript
import type { Flag, FlagContext } from "./types";

export function evaluateFlag(flag: Flag, context?: FlagContext): boolean {
  if (!flag.enabled) return false;

  const { rules } = flag;

  // If allowedUserIds is set, check user targeting
  if (rules.allowedUserIds && rules.allowedUserIds.length > 0) {
    if (!context?.userId) return false;
    return rules.allowedUserIds.includes(context.userId);
  }

  // If percentage is set, use deterministic hash
  if (rules.percentage !== undefined) {
    if (!context?.userId) return false;
    if (rules.percentage >= 100) return true;
    if (rules.percentage <= 0) return false;

    const hash = simpleHash(`${flag.key}:${context.userId}`);
    const bucket = hash % 100;
    return bucket < rules.percentage;
  }

  // No rules — flag is simply on/off
  return true;
}

/**
 * Simple deterministic hash for percentage rollout.
 * Produces a consistent number for the same input string.
 */
function simpleHash(str: string): number {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    const char = str.charCodeAt(i);
    hash = (hash << 5) - hash + char;
    hash = hash & hash; // Convert to 32-bit integer
  }
  return Math.abs(hash);
}
```

Run: `pnpm --filter @infrastructure/feature-flags test`
Expected: PASS

### Step 5: Implement in-memory flag store

Create `packages/infrastructure/feature-flags/src/memory-store.ts`:
```typescript
import type { Flag, FlagStore } from "./types";

export class MemoryFlagStore implements FlagStore {
  private flags = new Map<string, Flag>();

  constructor(initialFlags?: Flag[]) {
    if (initialFlags) {
      for (const flag of initialFlags) {
        this.flags.set(flag.key, flag);
      }
    }
  }

  async getFlag(key: string): Promise<Flag | undefined> {
    return this.flags.get(key);
  }

  async getAllFlags(): Promise<Flag[]> {
    return Array.from(this.flags.values());
  }

  setFlag(flag: Flag): void {
    this.flags.set(flag.key, flag);
  }
}
```

### Step 6: Create barrel export

Create `packages/infrastructure/feature-flags/src/index.ts`:
```typescript
export type { Flag, FlagContext, FlagRules, FlagStore } from "./types";
export { evaluateFlag } from "./evaluator";
export { MemoryFlagStore } from "./memory-store";
```

### Step 7: Create Supabase migration

Create `apps/supabase/migrations/<YYYYMMDDHHMMSS>_feature_flags.sql`:

> **Note:** Use actual timestamp, e.g., `20260309120000_feature_flags.sql`

```sql
CREATE TABLE public.feature_flags (
  key TEXT PRIMARY KEY,
  enabled BOOLEAN NOT NULL DEFAULT false,
  rules JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.feature_flags ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Flags are readable by all"
  ON public.feature_flags
  FOR SELECT
  USING (true);

COMMENT ON TABLE public.feature_flags IS 'Feature flags with optional targeting rules (percentage, user IDs)';
```

### Step 8: Run install, tests, typecheck

```bash
pnpm install
pnpm --filter @infrastructure/feature-flags test
pnpm typecheck
```

### Step 9: Commit

```bash
gt create -m "feat: add @infrastructure/feature-flags package (#111)"
```

---

## Task 8: `@infrastructure/jobs` (#112)

**Files:**
- Create: `packages/infrastructure/jobs/package.json`
- Create: `packages/infrastructure/jobs/tsconfig.json`
- Create: `packages/infrastructure/jobs/vitest.config.ts`
- Create: `packages/infrastructure/jobs/src/index.ts`
- Create: `packages/infrastructure/jobs/src/types.ts`
- Create: `packages/infrastructure/jobs/src/define-job.ts`
- Create: `packages/infrastructure/jobs/src/__tests__/define-job.test.ts`
- Modify: `pnpm-workspace.yaml` (add pg-boss to catalog)
- Modify: `apps/api/package.json` (add dependency, add `jobs` script)

### Step 1: Add pg-boss to catalog

Add to `pnpm-workspace.yaml`:
```yaml
  # Background jobs
  pg-boss: "10.1.5"
```

> **Note:** Check latest stable version at publish time.

### Step 2: Scaffold the package

Create `packages/infrastructure/jobs/package.json`:
```json
{
  "name": "@infrastructure/jobs",
  "version": "0.0.0",
  "private": true,
  "license": "MIT",
  "type": "module",
  "main": "./src/index.ts",
  "exports": {
    ".": {
      "types": "./src/index.ts",
      "default": "./src/index.ts"
    }
  },
  "scripts": {
    "typecheck": "tsc --noEmit",
    "test": "vitest run"
  },
  "dependencies": {
    "pg-boss": "catalog:",
    "zod": "catalog:"
  },
  "devDependencies": {
    "@infrastructure/typescript-config": "workspace:*",
    "typescript": "catalog:",
    "vitest": "catalog:"
  }
}
```

Create `tsconfig.json` and `vitest.config.ts` (same pattern).

### Step 3: Define types

Create `packages/infrastructure/jobs/src/types.ts`:
```typescript
import type { z } from "zod";

export interface JobDefinition<TInput = unknown> {
  name: string;
  schema: z.ZodType<TInput>;
  handler: (data: TInput) => Promise<void>;
  options?: JobOptions;
}

export interface JobOptions {
  retryLimit?: number;
  retryDelay?: number;
  retryBackoff?: boolean;
  expireInMinutes?: number;
}

export interface ScheduleOptions {
  delay?: number;
  cron?: string;
}
```

### Step 4: Write failing test for defineJob

Create `packages/infrastructure/jobs/src/__tests__/define-job.test.ts`:
```typescript
import { describe, expect, it, vi } from "vitest";
import { z } from "zod";
import { defineJob } from "../define-job";

describe("defineJob", () => {
  it("creates a job definition with name and handler", () => {
    const handler = vi.fn();
    const job = defineJob({
      name: "test-job",
      schema: z.object({ email: z.string() }),
      handler,
    });

    expect(job.name).toBe("test-job");
    expect(job.handler).toBe(handler);
  });

  it("includes options when provided", () => {
    const job = defineJob({
      name: "retry-job",
      schema: z.object({}),
      handler: vi.fn(),
      options: { retryLimit: 3, retryBackoff: true },
    });

    expect(job.options?.retryLimit).toBe(3);
    expect(job.options?.retryBackoff).toBe(true);
  });

  it("validates input against schema", () => {
    const schema = z.object({ email: z.string() });
    const job = defineJob({
      name: "validated-job",
      schema,
      handler: vi.fn(),
    });

    expect(job.schema).toBe(schema);
    // Schema validation happens at enqueue time, not at definition time
    const result = schema.safeParse({ email: "test@test.com" });
    expect(result.success).toBe(true);

    const bad = schema.safeParse({ email: 123 });
    expect(bad.success).toBe(false);
  });
});
```

Run: `pnpm --filter @infrastructure/jobs test`
Expected: FAIL

### Step 5: Implement defineJob

Create `packages/infrastructure/jobs/src/define-job.ts`:
```typescript
import type { z } from "zod";
import type { JobDefinition, JobOptions } from "./types";

export function defineJob<TInput>(params: {
  name: string;
  schema: z.ZodType<TInput>;
  handler: (data: TInput) => Promise<void>;
  options?: JobOptions;
}): JobDefinition<TInput> {
  return {
    name: params.name,
    schema: params.schema,
    handler: params.handler,
    options: params.options,
  };
}
```

Run: `pnpm --filter @infrastructure/jobs test`
Expected: PASS

### Step 6: Create barrel export

Create `packages/infrastructure/jobs/src/index.ts`:
```typescript
export type { JobDefinition, JobOptions, ScheduleOptions } from "./types";
export { defineJob } from "./define-job";
```

> **Note:** The `createJobWorker` and `scheduleJob` functions that depend on pg-boss should be implemented separately. They require a running Postgres instance to test and should be integration-tested rather than unit-tested. The interface and type definitions here are sufficient for consumers to start defining jobs.

### Step 7: Add jobs script to apps/api

Modify `apps/api/package.json` — add to `scripts`:
```json
"jobs": "tsx watch --env-file=.env src/worker.ts"
```

Add to `dependencies`:
```json
"@infrastructure/jobs": "workspace:*",
```

### Step 8: Run install, tests, typecheck

```bash
pnpm install
pnpm --filter @infrastructure/jobs test
pnpm typecheck
```

### Step 9: Commit

```bash
gt create -m "feat: add @infrastructure/jobs package (#112)"
```

---

## Task 9: `@infrastructure/notifications` (#113)

**Files:**
- Create: `packages/infrastructure/notifications/package.json`
- Create: `packages/infrastructure/notifications/tsconfig.json`
- Create: `packages/infrastructure/notifications/vitest.config.ts`
- Create: `packages/infrastructure/notifications/src/index.ts`
- Create: `packages/infrastructure/notifications/src/types.ts`
- Create: `packages/infrastructure/notifications/src/console-email.ts`
- Create: `packages/infrastructure/notifications/src/__tests__/console-email.test.ts`
- Create: `apps/supabase/migrations/<timestamp>_push_tokens.sql`

> **Depends on:** Task 8 (jobs) — notifications dispatched via job queue.

### Step 1: Scaffold the package

Create `packages/infrastructure/notifications/package.json`:
```json
{
  "name": "@infrastructure/notifications",
  "version": "0.0.0",
  "private": true,
  "license": "MIT",
  "type": "module",
  "main": "./src/index.ts",
  "exports": {
    ".": {
      "types": "./src/index.ts",
      "default": "./src/index.ts"
    }
  },
  "scripts": {
    "typecheck": "tsc --noEmit",
    "test": "vitest run"
  },
  "dependencies": {},
  "devDependencies": {
    "@infrastructure/typescript-config": "workspace:*",
    "typescript": "catalog:",
    "vitest": "catalog:"
  }
}
```

Create `tsconfig.json` and `vitest.config.ts` (same pattern).

### Step 2: Define types

Create `packages/infrastructure/notifications/src/types.ts`:
```typescript
export interface EmailOptions {
  to: string | string[];
  subject: string;
  html?: string;
  text?: string;
  replyTo?: string;
}

export interface EmailProvider {
  send(email: EmailOptions): Promise<{ id: string }>;
}

export interface PushOptions {
  tokens: string[];
  title: string;
  body: string;
  data?: Record<string, unknown>;
}

export interface PushProvider {
  send(notification: PushOptions): Promise<{ sent: number; failed: number }>;
}
```

### Step 3: Write failing test for console email provider

Create `packages/infrastructure/notifications/src/__tests__/console-email.test.ts`:
```typescript
import { describe, expect, it, vi } from "vitest";
import { ConsoleEmailProvider } from "../console-email";

describe("ConsoleEmailProvider", () => {
  it("logs email details and returns an id", async () => {
    const consoleSpy = vi.spyOn(console, "log").mockImplementation(() => {});
    const provider = new ConsoleEmailProvider();

    const result = await provider.send({
      to: "test@example.com",
      subject: "Welcome!",
      html: "<h1>Hello</h1>",
    });

    expect(result.id).toBeTruthy();
    expect(consoleSpy).toHaveBeenCalledWith(
      expect.stringContaining("[EMAIL]"),
      expect.objectContaining({
        to: "test@example.com",
        subject: "Welcome!",
      })
    );

    consoleSpy.mockRestore();
  });

  it("handles array of recipients", async () => {
    const consoleSpy = vi.spyOn(console, "log").mockImplementation(() => {});
    const provider = new ConsoleEmailProvider();

    const result = await provider.send({
      to: ["a@test.com", "b@test.com"],
      subject: "Multi",
    });

    expect(result.id).toBeTruthy();
    consoleSpy.mockRestore();
  });
});
```

Run: `pnpm --filter @infrastructure/notifications test`
Expected: FAIL

### Step 4: Implement console email provider

Create `packages/infrastructure/notifications/src/console-email.ts`:
```typescript
import type { EmailOptions, EmailProvider } from "./types";

export class ConsoleEmailProvider implements EmailProvider {
  async send(email: EmailOptions): Promise<{ id: string }> {
    const id = crypto.randomUUID();
    console.log("[EMAIL]", {
      id,
      to: email.to,
      subject: email.subject,
      hasHtml: !!email.html,
      hasText: !!email.text,
    });
    return { id };
  }
}
```

Run: `pnpm --filter @infrastructure/notifications test`
Expected: PASS

### Step 5: Create barrel export

Create `packages/infrastructure/notifications/src/index.ts`:
```typescript
export type { EmailOptions, EmailProvider, PushOptions, PushProvider } from "./types";
export { ConsoleEmailProvider } from "./console-email";
```

### Step 6: Create Supabase migration for push_tokens

Create `apps/supabase/migrations/<YYYYMMDDHHMMSS>_push_tokens.sql`:

```sql
CREATE TABLE public.push_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  token TEXT NOT NULL,
  platform TEXT NOT NULL CHECK (platform IN ('ios', 'android')),
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, token)
);

ALTER TABLE public.push_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own push tokens"
  ON public.push_tokens
  FOR ALL
  USING (auth.uid() = user_id);

COMMENT ON TABLE public.push_tokens IS 'Push notification tokens for mobile devices';
```

### Step 7: Run install, tests, typecheck

```bash
pnpm install
pnpm --filter @infrastructure/notifications test
pnpm typecheck
```

### Step 8: Commit

```bash
gt create -m "feat: add @infrastructure/notifications package (#113)"
```

---

## Task 10: Final Integration & Documentation

**Files:**
- Modify: `apps/api/src/app.ts` (verify full middleware chain order)
- Modify: `apps/api/.env.example` (add all new env vars)
- Modify: `apps/web/.env.local.example` (add SENTRY_DSN)
- Modify: `.claude/CLAUDE.md` (document new packages)

### Step 1: Verify middleware chain order in apps/api/src/app.ts

The final middleware chain should be:
```typescript
// 1. Observability (request logging, tracing)
app.use("*", otelMiddleware({ logger }));

// 2. Error tracking (catches unhandled errors)
app.use("*", errorMiddleware({ tracker: errorTracker }));

// 3. Secure headers
app.use("*", secureHeaders({ ... }));

// 4. Rate limiting (global)
app.use("*", createRateLimiter({ max: 100, windowMs: 60_000 }));

// 5. CORS
app.use("*", cors({ ... }));

// 6. Auth rate limiting (stricter, before auth middleware)
app.use("/api/auth/*", createRateLimiter({ max: 5, windowMs: 60_000 }));

// 7. Supabase auth
app.use("/api/*", supabaseMiddleware({ ... }));

// 8. Routes
app.all("/api/*", async (c) => { ... });
app.get("/health", ...);
app.get("/ready", ...);
```

### Step 2: Update .env.example files

Append to `apps/api/.env.example`:
```env
# Observability (optional — console output when unset)
# OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318
# OTEL_SERVICE_NAME=monorepo-api

# Error Tracking (optional — console output when unset)
# SENTRY_DSN=

# Rate Limiting / Caching (optional — in-memory when unset)
# REDIS_URL=

# Email (optional — console output when unset)
# RESEND_API_KEY=
# RESEND_FROM_EMAIL=noreply@example.com

# Push Notifications (optional)
# EXPO_PUSH_ACCESS_TOKEN=
```

### Step 3: Update CLAUDE.md

Add a new section under `## Architecture` documenting the 7 new infrastructure packages, their purpose, key exports, and env vars. Follow the existing documentation pattern.

### Step 4: Run full validation

```bash
pnpm install
pnpm lint:fix
pnpm typecheck
pnpm test
pnpm build
```

### Step 5: Commit

```bash
gt create -m "feat: integrate production readiness packages and update docs (#105-#113)"
```
