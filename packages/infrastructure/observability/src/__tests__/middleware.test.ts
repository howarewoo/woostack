import { describe, expect, it, vi } from "vitest";
import type { Logger } from "pino";
import { Hono } from "hono";
import { otelMiddleware } from "../middleware";

function createMockLogger() {
  return {
    info: vi.fn(),
    error: vi.fn(),
    warn: vi.fn(),
    debug: vi.fn(),
    fatal: vi.fn(),
    trace: vi.fn(),
    level: "info",
    silent: vi.fn(),
    child: vi.fn(),
    bindings: vi.fn(),
    flush: vi.fn(),
    isLevelEnabled: vi.fn(),
  } as unknown as Logger & { info: ReturnType<typeof vi.fn> };
}

describe("otelMiddleware", () => {
  it("sets x-request-id response header from incoming header", async () => {
    const logger = createMockLogger();
    const app = new Hono();
    app.use("*", otelMiddleware({ logger }));
    app.get("/", (c) => c.text("ok"));

    const res = await app.request("/", {
      headers: { "x-request-id": "test-id-123" },
    });

    expect(res.status).toBe(200);
    expect(res.headers.get("x-request-id")).toBe("test-id-123");
  });

  it("generates a request ID when none is provided", async () => {
    const logger = createMockLogger();
    const app = new Hono();
    app.use("*", otelMiddleware({ logger }));
    app.get("/", (c) => c.text("ok"));

    const res = await app.request("/");

    expect(res.status).toBe(200);
    const requestId = res.headers.get("x-request-id");
    expect(requestId).toBeTruthy();
    // UUID v4 format
    expect(requestId).toMatch(
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/
    );
  });

  it("makes requestId available via c.get('requestId')", async () => {
    const logger = createMockLogger();
    const app = new Hono();
    app.use("*", otelMiddleware({ logger }));

    let capturedRequestId: string | undefined;
    app.get("/", (c) => {
      capturedRequestId = c.get("requestId");
      return c.text("ok");
    });

    await app.request("/", {
      headers: { "x-request-id": "abc-123" },
    });

    expect(capturedRequestId).toBe("abc-123");
  });

  it("logs request details after response", async () => {
    const logger = createMockLogger();
    const app = new Hono();
    app.use("*", otelMiddleware({ logger }));
    app.get("/health", (c) => c.text("ok"));

    await app.request("/health", {
      headers: { "x-request-id": "req-1" },
    });

    expect(logger.info).toHaveBeenCalledTimes(1);
    const [logObj, logMsg] = logger.info.mock.calls[0]!;
    expect(logMsg).toBe("request completed");
    expect(logObj.requestId).toBe("req-1");
    expect(logObj.method).toBe("GET");
    expect(logObj.path).toBe("/health");
    expect(logObj.status).toBe(200);
    expect(typeof logObj.duration).toBe("number");
  });

  it("logs correct status for non-200 responses", async () => {
    const logger = createMockLogger();
    const app = new Hono();
    app.use("*", otelMiddleware({ logger }));
    app.get("/missing", (c) => c.notFound());

    await app.request("/missing");

    const [logObj] = logger.info.mock.calls[0]!;
    expect(logObj.status).toBe(404);
  });
});
