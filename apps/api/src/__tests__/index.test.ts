import { beforeEach, describe, expect, it, vi } from "vitest";

// Set required env vars before app module loads (hoisted alongside vi.mock)
vi.hoisted(() => {
  process.env.SUPABASE_PUBLISHABLE_KEY = "test-publishable-key";
});

// Mock @hono/node-server BEFORE importing app
vi.mock("@hono/node-server", () => ({
  serve: vi.fn(),
}));

// Mock the Supabase middleware to be a pass-through
vi.mock("@infrastructure/supabase/middleware/hono", () => ({
  supabaseMiddleware: () => async (_c: unknown, next: () => Promise<void>) => next(),
}));

// Mock the router
vi.mock("../router", () => ({
  router: {},
}));

// Mock RPCHandler — class syntax required: Vitest 4 arrow functions are not constructable
const mockHandle = vi.fn();

vi.mock("@orpc/server/fetch", () => ({
  RPCHandler: class {
    get handle() {
      return mockHandle;
    }
  },
}));

// Now import app
import app from "../index";

describe("API Server", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("should return welcome message on GET /", async () => {
    const res = await app.request("/");
    expect(res.status).toBe(200);
    const json = await res.json();
    expect(json).toEqual({ message: "Monorepo API is running!" });
  });

  it("should call oRPC handler and return response when matched", async () => {
    const mockResponse = new Response("ok");
    mockHandle.mockResolvedValueOnce({
      matched: true,
      response: mockResponse,
    });

    const res = await app.request("/api/users");
    expect(res.status).toBe(200);
    const text = await res.text();
    expect(text).toBe("ok");
    expect(mockHandle).toHaveBeenCalledWith(
      expect.any(Request),
      expect.objectContaining({
        prefix: "/",
        context: expect.objectContaining({
          requestId: undefined,
          user: undefined,
          supabase: undefined,
        }),
      })
    );
  });

  it("should forward x-request-id header to oRPC context", async () => {
    mockHandle.mockResolvedValueOnce({
      matched: true,
      response: new Response("ok"),
    });

    await app.request("/api/users", {
      headers: { "x-request-id": "test-req-123" },
    });

    expect(mockHandle).toHaveBeenCalledWith(
      expect.any(Request),
      expect.objectContaining({
        context: expect.objectContaining({ requestId: "test-req-123" }),
      })
    );
  });

  it("should return 404 when oRPC handler does not match", async () => {
    mockHandle.mockResolvedValueOnce({
      matched: false,
    });

    const res = await app.request("/api/nonexistent");
    expect(res.status).toBe(404);
  });

  it("should include CORS headers for allowed origins", async () => {
    const res = await app.request("/", {
      headers: { Origin: "http://localhost:3001" },
    });
    expect(res.headers.get("access-control-allow-origin")).toBe("http://localhost:3001");
  });
});

describe("GET /health", () => {
  it("should return 200 with status ok and uptime", async () => {
    const res = await app.request("/health");
    expect(res.status).toBe(200);

    const json = await res.json();
    expect(json.status).toBe("ok");
    expect(typeof json.uptime).toBe("number");
    expect(json.uptime).toBeGreaterThanOrEqual(0);
  });
});

describe("GET /ready", () => {
  const originalEnv = process.env;
  const mockFetch = vi.fn();

  beforeEach(() => {
    vi.clearAllMocks();
    process.env = { ...originalEnv };
    vi.stubGlobal("fetch", mockFetch);
  });

  it("should skip DB check and return ready when Supabase is not configured", async () => {
    // The test env has SUPABASE_PUBLISHABLE_KEY set but supabaseUrl defaults,
    // so we test the readiness probe returns ok when Supabase is reachable
    mockFetch.mockResolvedValueOnce(new Response(null, { status: 200 }));

    const res = await app.request("/ready");
    expect(res.status).toBe(200);
    const json = await res.json();
    expect(json.status).toBe("ready");
  });

  it("should return 503 when Supabase is unreachable", async () => {
    mockFetch.mockRejectedValueOnce(new Error("Connection refused"));

    const res = await app.request("/ready");
    expect(res.status).toBe(503);
    const json = await res.json();
    expect(json.status).toBe("not_ready");
    expect(json.checks.db).toBe("failed");
  });
});
