import { Hono } from "hono";
import { describe, expect, it } from "vitest";
import { csrfProtection } from "../csrf";

const ALLOWED_ORIGINS = ["http://localhost:3000", "http://localhost:3001"];

function createApp() {
  const app = new Hono();
  app.use("*", csrfProtection({ allowedOrigins: ALLOWED_ORIGINS }));
  app.get("/", (c) => c.text("ok"));
  app.post("/", (c) => c.text("created"));
  app.put("/data", (c) => c.text("updated"));
  app.patch("/data", (c) => c.text("patched"));
  app.delete("/data", (c) => c.text("deleted"));
  return app;
}

describe("csrfProtection", () => {
  it("allows GET requests without Origin header", async () => {
    const app = createApp();
    const res = await app.request("/");

    expect(res.status).toBe(200);
    expect(await res.text()).toBe("ok");
  });

  it("allows POST with valid Origin header", async () => {
    const app = createApp();
    const res = await app.request("/", {
      method: "POST",
      headers: { Origin: "http://localhost:3000" },
    });

    expect(res.status).toBe(200);
    expect(await res.text()).toBe("created");
  });

  it("allows PUT with valid Origin header", async () => {
    const app = createApp();
    const res = await app.request("/data", {
      method: "PUT",
      headers: { Origin: "http://localhost:3001" },
    });

    expect(res.status).toBe(200);
  });

  it("allows PATCH with valid Referer header when Origin is absent", async () => {
    const app = createApp();
    const res = await app.request("/data", {
      method: "PATCH",
      headers: { Referer: "http://localhost:3000/some/path" },
    });

    expect(res.status).toBe(200);
  });

  it("rejects POST with no Origin or Referer header", async () => {
    const app = createApp();
    const res = await app.request("/", { method: "POST" });

    expect(res.status).toBe(403);
    const body = await res.json();
    expect(body).toEqual({ error: "Forbidden" });
  });

  it("rejects DELETE with disallowed Origin", async () => {
    const app = createApp();
    const res = await app.request("/data", {
      method: "DELETE",
      headers: { Origin: "http://evil.example.com" },
    });

    expect(res.status).toBe(403);
    const body = await res.json();
    expect(body).toEqual({ error: "Forbidden" });
  });

  it("rejects POST with invalid Referer URL", async () => {
    const app = createApp();
    const res = await app.request("/", {
      method: "POST",
      headers: { Referer: "not-a-url" },
    });

    expect(res.status).toBe(403);
  });

  it("strips trailing slashes from allowed origins for comparison", async () => {
    const app = new Hono();
    app.use("*", csrfProtection({ allowedOrigins: ["http://localhost:3000/"] }));
    app.post("/", (c) => c.text("ok"));

    const res = await app.request("/", {
      method: "POST",
      headers: { Origin: "http://localhost:3000" },
    });

    expect(res.status).toBe(200);
  });
});
