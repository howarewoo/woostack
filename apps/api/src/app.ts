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
const supabaseSecretKey = requireEnv("SUPABASE_SECRET_KEY");
const supabasePublishableKey = requireEnv("SUPABASE_PUBLISHABLE_KEY");

const app = new Hono();

app.use(
  "*",
  cors({
    origin: process.env.CORS_ALLOWED_ORIGINS?.split(",") || [
      "http://localhost:3000",
      "http://localhost:3002",
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
    supabaseSecretKey,
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

app.get("/", (c) => {
  return c.json({ message: "Monorepo API is running!" });
});

export { app };
