import { Hono } from "hono";
import { describe, expect, it, vi } from "vitest";
import { createErrorBoundary } from "../middleware";
import type { ErrorReporter } from "../types";

type AppEnv = { Variables: { requestId: string } };

function createMockReporter(): ErrorReporter {
  return {
    captureException: vi.fn(),
    captureMessage: vi.fn(),
  };
}

function createApp(reporter: ErrorReporter) {
  const app = new Hono();
  app.onError(createErrorBoundary({ reporter }));
  return app;
}

describe("createErrorBoundary", () => {
  it("passes through successful requests without reporting", async () => {
    const reporter = createMockReporter();
    const app = createApp(reporter);
    app.get("/", (c) => c.text("ok"));

    const res = await app.request("/");

    expect(res.status).toBe(200);
    expect(await res.text()).toBe("ok");
    expect(reporter.captureException).not.toHaveBeenCalled();
  });

  it("catches thrown errors and returns 500 JSON response", async () => {
    const reporter = createMockReporter();
    const app = createApp(reporter);
    app.get("/", () => {
      throw new Error("boom");
    });

    const res = await app.request("/");

    expect(res.status).toBe(500);
    const body = await res.json();
    expect(body).toEqual({
      error: { message: "Internal Server Error" },
    });
  });

  it("reports the error to the reporter with method and path", async () => {
    const reporter = createMockReporter();
    const app = createApp(reporter);
    app.get("/users", () => {
      throw new Error("db down");
    });

    await app.request("/users");

    expect(reporter.captureException).toHaveBeenCalledOnce();
    const call = vi.mocked(reporter.captureException).mock.calls[0]!;
    expect(call[0].message).toBe("db down");
    expect(call[1]?.method).toBe("GET");
    expect(call[1]?.path).toBe("/users");
  });

  it("includes requestId in response when available", async () => {
    const reporter = createMockReporter();
    const app = new Hono<AppEnv>();
    app.onError(createErrorBoundary({ reporter }));
    // Simulate otelMiddleware setting requestId
    app.use("*", async (c, next) => {
      c.set("requestId", "req-abc-123");
      await next();
    });
    app.get("/", () => {
      throw new Error("fail");
    });

    const res = await app.request("/");
    const body = await res.json();

    expect(body).toEqual({
      error: {
        message: "Internal Server Error",
        requestId: "req-abc-123",
      },
    });
  });

  it("includes requestId in reported context", async () => {
    const reporter = createMockReporter();
    const app = new Hono<AppEnv>();
    app.onError(createErrorBoundary({ reporter }));
    app.use("*", async (c, next) => {
      c.set("requestId", "req-xyz");
      await next();
    });
    app.get("/", () => {
      throw new Error("fail");
    });

    await app.request("/");

    const call = vi.mocked(reporter.captureException).mock.calls[0]!;
    expect(call[1]?.requestId).toBe("req-xyz");
  });

  it("handles errors with custom properties", async () => {
    const reporter = createMockReporter();
    const app = createApp(reporter);
    app.get("/", () => {
      const err = new Error("custom error");
      (err as Error & { code: string }).code = "DB_CONN_FAILED";
      throw err;
    });

    const res = await app.request("/");

    expect(res.status).toBe(500);
    const body = await res.json();
    expect(body).toEqual({
      error: { message: "Internal Server Error" },
    });
    const call = vi.mocked(reporter.captureException).mock.calls[0]!;
    expect(call[0].message).toBe("custom error");
  });

  it("omits requestId from response when not set", async () => {
    const reporter = createMockReporter();
    const app = createApp(reporter);
    app.get("/", () => {
      throw new Error("no request id");
    });

    const res = await app.request("/");
    const body = await res.json();

    expect(body.error).not.toHaveProperty("requestId");
  });
});
