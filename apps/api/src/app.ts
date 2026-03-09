import { ConsoleReporter, createErrorBoundary } from "@infrastructure/error-tracking";
import { createLogger, type Logger, otelMiddleware } from "@infrastructure/observability";
import { bodyLimit, securityHeaders } from "@infrastructure/security";
import { supabaseMiddleware } from "@infrastructure/supabase/middleware/hono";
import { RPCHandler } from "@orpc/server/fetch";
import { Hono } from "hono";
import { cors } from "hono/cors";
import { router } from "./router";

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is required`);
  return value;
}

const supabaseUrl = process.env.SUPABASE_URL || "http://127.0.0.1:54321";
const supabasePublishableKey = requireEnv("SUPABASE_PUBLISHABLE_KEY");

const logger: Logger = createLogger({ serviceName: "api" });

const errorReporter = new ConsoleReporter();

const app = new Hono();

app.onError(createErrorBoundary({ reporter: errorReporter }));

app.use("*", otelMiddleware({ logger }));
app.use("*", securityHeaders());
app.use("*", bodyLimit({ maxSize: 1_048_576 }));

app.use(
  "*",
  cors({
    origin: process.env.CORS_ALLOWED_ORIGINS?.split(",") || [
      "http://localhost:3000",
      "http://localhost:3001",
    ],
    allowMethods: ["GET", "POST", "OPTIONS"],
    allowHeaders: ["Content-Type", "Authorization", "x-request-id"],
    credentials: true,
  })
);

app.use(
  "/api/*",
  supabaseMiddleware({
    supabaseUrl,
    supabasePublishableKey,
  })
);

const handler = new RPCHandler(router);

app.all("/api/*", async (c) => {
  const url = new URL(c.req.url);
  url.pathname = url.pathname.replace(/^\/api/, "");

  const request = new Request(url, c.req.raw);

  const result = await handler.handle(request, {
    prefix: "/",
    context: {
      requestId: c.req.header("x-request-id"),
      user: c.get("user"),
      supabase: c.get("supabase"),
    },
  });

  if (result.matched) {
    return result.response;
  }

  return c.notFound();
});

// --- Health check routes (outside /api/* — no auth required) ---

const startTime = Date.now();

/** Liveness probe — confirms the process is running. */
app.get("/health", (c) => {
  const uptimeSeconds = Math.floor((Date.now() - startTime) / 1000);
  return c.json({ status: "ok", uptime: uptimeSeconds });
});

/**
 * Readiness probe — confirms the service can handle requests.
 * Checks Supabase DB connectivity when env vars are configured.
 */
app.get("/ready", async (c) => {
  if (!supabaseUrl || !supabasePublishableKey) {
    return c.json({ status: "ready", checks: { db: "skipped" } });
  }

  try {
    const response = await fetch(`${supabaseUrl}/rest/v1/`, {
      method: "HEAD",
      headers: {
        apikey: supabasePublishableKey,
        Authorization: `Bearer ${supabasePublishableKey}`,
      },
      signal: AbortSignal.timeout(5000),
    });

    if (!response.ok) {
      return c.json({ status: "not_ready", checks: { db: "failed" } }, 503);
    }

    return c.json({ status: "ready", checks: { db: "ok" } });
  } catch {
    return c.json({ status: "not_ready", checks: { db: "failed" } }, 503);
  }
});

app.get("/", (c) => {
  return c.json({ message: "Monorepo API is running!" });
});

export { app, logger };
