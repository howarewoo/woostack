import { beforeEach, describe, expect, it, vi } from "vitest";

// Set required env vars before app module loads (hoisted alongside vi.mock)
vi.hoisted(() => {
  process.env.SUPABASE_SECRET_KEY = "test-secret-key";
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
      headers: { Origin: "http://localhost:3000" },
    });
    expect(res.headers.get("access-control-allow-origin")).toBe("http://localhost:3000");
  });
});
