import { describe, expect, it, vi } from "vitest";

vi.mock("@supabase/supabase-js", () => ({
  createClient: vi.fn(() => ({ auth: {}, from: vi.fn() })),
}));

import { createClient } from "@supabase/supabase-js";
import { createServerClient } from "./server";

describe("createServerClient", () => {
  it("creates a Supabase client with the provided URL and key", () => {
    const client = createServerClient("http://localhost:54321", "test-service-key");

    expect(createClient).toHaveBeenCalledWith(
      "http://localhost:54321",
      "test-service-key",
      expect.objectContaining({
        auth: expect.objectContaining({
          autoRefreshToken: false,
          persistSession: false,
        }),
      })
    );
    expect(client).toBeDefined();
  });

  it("disables auto-refresh and session persistence for server usage", () => {
    createServerClient("http://localhost:54321", "test-key");

    const options = vi.mocked(createClient).mock.calls[0]?.[2];
    expect(options?.auth?.autoRefreshToken).toBe(false);
    expect(options?.auth?.persistSession).toBe(false);
  });
});
