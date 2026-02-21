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
      supabaseServiceKey: "test-service-key",
      supabaseAnonKey: "test-anon-key",
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
      supabaseServiceKey: "test-service-key",
      supabaseAnonKey: "test-anon-key",
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
    const { createClient } = await import("@supabase/supabase-js");
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
    } as any);

    const app = new Hono();
    const middleware = supabaseMiddleware({
      supabaseUrl: "http://localhost:54321",
      supabaseServiceKey: "test-service-key",
      supabaseAnonKey: "test-anon-key",
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
