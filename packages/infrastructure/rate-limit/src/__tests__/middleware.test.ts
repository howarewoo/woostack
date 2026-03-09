import { Hono } from "hono";
import { describe, expect, it } from "vitest";
import { createRateLimiter } from "../middleware";

function createApp(max: number) {
  const app = new Hono();
  app.use("*", createRateLimiter({ max, windowMs: 60_000 }));
  app.get("/", (c) => c.text("ok"));
  return app;
}

describe("createRateLimiter", () => {
  it("allows requests under the limit", async () => {
    const app = createApp(5);
    const res = await app.request("/");
    expect(res.status).toBe(200);
    expect(await res.text()).toBe("ok");
  });

  it("returns 429 when limit exceeded", async () => {
    const app = createApp(2);

    await app.request("/");
    await app.request("/");
    const res = await app.request("/");

    expect(res.status).toBe(429);
    const body = await res.json();
    expect(body).toEqual({ error: "Too Many Requests" });
    expect(res.headers.get("Retry-After")).toBeTruthy();
  });

  it("sets rate limit headers correctly", async () => {
    const app = createApp(10);

    const res = await app.request("/");

    expect(res.headers.get("X-RateLimit-Limit")).toBe("10");
    expect(res.headers.get("X-RateLimit-Remaining")).toBe("9");
    expect(res.headers.get("X-RateLimit-Reset")).toBeTruthy();
  });

  it("uses a custom keyGenerator when provided", async () => {
    const app = new Hono();
    app.use(
      "*",
      createRateLimiter({
        max: 1,
        windowMs: 60_000,
        keyGenerator: (c) => c.req.header("x-api-key") ?? "anon",
      })
    );
    app.get("/", (c) => c.text("ok"));

    // First request with key "abc" — allowed
    const res1 = await app.request("/", {
      headers: { "x-api-key": "abc" },
    });
    expect(res1.status).toBe(200);

    // Second request with key "abc" — blocked
    const res2 = await app.request("/", {
      headers: { "x-api-key": "abc" },
    });
    expect(res2.status).toBe(429);

    // First request with a different key "xyz" — allowed (independent bucket)
    const res3 = await app.request("/", {
      headers: { "x-api-key": "xyz" },
    });
    expect(res3.status).toBe(200);
  });

  it("extracts key from x-forwarded-for header", async () => {
    const app = createApp(1);

    const res1 = await app.request("/", {
      headers: { "x-forwarded-for": "1.2.3.4, 10.0.0.1" },
    });
    expect(res1.status).toBe(200);

    const res2 = await app.request("/", {
      headers: { "x-forwarded-for": "1.2.3.4, 10.0.0.1" },
    });
    expect(res2.status).toBe(429);
  });

  it("falls back to x-real-ip when x-forwarded-for is absent", async () => {
    const app = createApp(1);

    const res1 = await app.request("/", {
      headers: { "x-real-ip": "5.6.7.8" },
    });
    expect(res1.status).toBe(200);

    const res2 = await app.request("/", {
      headers: { "x-real-ip": "5.6.7.8" },
    });
    expect(res2.status).toBe(429);
  });

  it("applies independent rate limits per IP", async () => {
    const app = createApp(1);

    // IP A gets rate limited
    const resA1 = await app.request("/", {
      headers: { "x-forwarded-for": "10.0.0.1" },
    });
    expect(resA1.status).toBe(200);

    const resA2 = await app.request("/", {
      headers: { "x-forwarded-for": "10.0.0.1" },
    });
    expect(resA2.status).toBe(429);

    // IP B is unaffected
    const resB1 = await app.request("/", {
      headers: { "x-forwarded-for": "10.0.0.2" },
    });
    expect(resB1.status).toBe(200);
  });
});
