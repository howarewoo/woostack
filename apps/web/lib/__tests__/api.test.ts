import { describe, expect, it, vi } from "vitest";

vi.mock("@infrastructure/api-client", () => ({
  createTypedApiClient: vi.fn((url: string) => ({ url })),
  createTypedOrpcUtils: vi.fn((client: unknown) => ({ client })),
}));

vi.mock("@/lib/supabase", () => ({
  createBrowserSupabase: vi.fn(() => ({
    auth: { getSession: vi.fn(() => Promise.resolve({ data: { session: null } })) },
  })),
}));

describe("api", () => {
  it("creates API client with default URL when env var not set", async () => {
    const { createTypedApiClient } = await import("@infrastructure/api-client");
    const { apiClient } = await import("@/lib/api");

    expect(createTypedApiClient).toHaveBeenCalledWith(
      "http://localhost:3001/api",
      expect.objectContaining({ getToken: expect.any(Function) })
    );
    expect(apiClient).toBeDefined();
  });

  it("creates oRPC utils with the API client", async () => {
    const { createTypedOrpcUtils } = await import("@infrastructure/api-client");
    const { apiClient, orpc } = await import("@/lib/api");

    expect(createTypedOrpcUtils).toHaveBeenCalledWith(apiClient);
    expect(orpc).toBeDefined();
  });
});
