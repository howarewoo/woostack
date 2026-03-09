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
});
