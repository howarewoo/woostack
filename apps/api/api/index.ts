import { supabaseMiddleware } from "@infrastructure/supabase/middleware/hono";
import { RPCHandler } from "@orpc/server/fetch";
import { Hono } from "hono";
import { cors } from "hono/cors";
import { handle } from "hono/vercel";
import { router } from "../src/router";

const app = new Hono().basePath("/api");

app.use("*", cors());

app.use(
  "/*",
  supabaseMiddleware({
    supabaseUrl: process.env.SUPABASE_URL || "http://127.0.0.1:54321",
    supabaseServiceKey: process.env.SUPABASE_SERVICE_ROLE_KEY || "",
    supabaseAnonKey: process.env.SUPABASE_ANON_KEY || "",
  })
);

const handler = new RPCHandler(router);

app.all("/*", async (c) => {
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

export default handle(app);
