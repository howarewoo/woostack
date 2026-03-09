import { describe, expect, it } from "vitest";
import { Hono } from "hono";
import { securityHeaders } from "../headers";

function createApp(options?: Parameters<typeof securityHeaders>[0]) {
  const app = new Hono();
  app.use("*", securityHeaders(options));
  app.get("/", (c) => c.text("ok"));
  return app;
}

describe("securityHeaders", () => {
  it("sets default security headers", async () => {
    const app = createApp();
    const res = await app.request("/");

    expect(res.status).toBe(200);
    expect(res.headers.get("X-Content-Type-Options")).toBe("nosniff");
    expect(res.headers.get("X-Frame-Options")).toBe("DENY");
    expect(res.headers.get("Strict-Transport-Security")).toBe(
      "max-age=31536000; includeSubDomains"
    );
    expect(res.headers.get("X-XSS-Protection")).toBe("0");
    expect(res.headers.get("Referrer-Policy")).toBe("strict-origin-when-cross-origin");
  });

  it("does not set CSP or Permissions-Policy by default", async () => {
    const app = createApp();
    const res = await app.request("/");

    expect(res.headers.get("Content-Security-Policy")).toBeNull();
    expect(res.headers.get("Permissions-Policy")).toBeNull();
  });

  it("allows overriding default header values", async () => {
    const app = createApp({
      frameOptions: "SAMEORIGIN",
      referrerPolicy: "no-referrer",
    });
    const res = await app.request("/");

    expect(res.headers.get("X-Frame-Options")).toBe("SAMEORIGIN");
    expect(res.headers.get("Referrer-Policy")).toBe("no-referrer");
    // Others should still be defaults
    expect(res.headers.get("X-Content-Type-Options")).toBe("nosniff");
  });

  it("sets optional CSP and Permissions-Policy when provided", async () => {
    const app = createApp({
      contentSecurityPolicy: "default-src 'self'",
      permissionsPolicy: "camera=(), microphone=()",
    });
    const res = await app.request("/");

    expect(res.headers.get("Content-Security-Policy")).toBe("default-src 'self'");
    expect(res.headers.get("Permissions-Policy")).toBe("camera=(), microphone=()");
  });
});
