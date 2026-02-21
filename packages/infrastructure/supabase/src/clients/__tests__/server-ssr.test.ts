import { beforeEach, describe, expect, it, vi } from "vitest";

const { mockCreateServerClient } = vi.hoisted(() => ({
  mockCreateServerClient: vi.fn(() => ({ auth: {}, from: vi.fn() })),
}));

vi.mock("@supabase/ssr", () => ({
  createServerClient: mockCreateServerClient,
}));

import { createSSRServerClient } from "../server-ssr";

describe("createSSRServerClient", () => {
  beforeEach(() => {
    mockCreateServerClient.mockClear();
  });

  it("calls @supabase/ssr createServerClient with cookie handlers", () => {
    const mockCookieStore = {
      getAll: vi.fn(() => [{ name: "sb-token", value: "abc" }]),
      set: vi.fn(),
    };

    const client = createSSRServerClient(
      "http://localhost:54321",
      "test-anon-key",
      mockCookieStore as unknown as Parameters<typeof createSSRServerClient>[2]
    );

    expect(mockCreateServerClient).toHaveBeenCalledWith(
      "http://localhost:54321",
      "test-anon-key",
      expect.objectContaining({
        cookies: expect.objectContaining({
          getAll: expect.any(Function),
          setAll: expect.any(Function),
        }),
      })
    );
    expect(client).toBeDefined();
  });

  it("delegates getAll to the cookie store", () => {
    const mockCookies = [{ name: "sb-token", value: "xyz" }];
    const mockCookieStore = {
      getAll: vi.fn(() => mockCookies),
      set: vi.fn(),
    };

    createSSRServerClient(
      "http://localhost:54321",
      "key",
      mockCookieStore as unknown as Parameters<typeof createSSRServerClient>[2]
    );

    const lastCall = mockCreateServerClient.mock.calls[0] as unknown as [
      string,
      string,
      { cookies: { getAll: () => Array<{ name: string; value: string }> } },
    ];
    const result = lastCall[2].cookies.getAll();
    expect(mockCookieStore.getAll).toHaveBeenCalled();
    expect(result).toEqual(mockCookies);
  });
});
