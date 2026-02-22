import { describe, expect, it, vi } from "vitest";

const { mockCreateBrowserClient } = vi.hoisted(() => ({
  mockCreateBrowserClient: vi.fn(() => ({ auth: {}, from: vi.fn() })),
}));

vi.mock("@supabase/ssr", () => ({
  createBrowserClient: mockCreateBrowserClient,
}));

import { createSSRBrowserClient } from "../browser-ssr";

describe("createSSRBrowserClient", () => {
  it("calls @supabase/ssr createBrowserClient with URL and key", () => {
    const client = createSSRBrowserClient("http://localhost:54321", "test-publishable-key");

    expect(mockCreateBrowserClient).toHaveBeenCalledWith(
      "http://localhost:54321",
      "test-publishable-key"
    );
    expect(client).toBeDefined();
  });
});
