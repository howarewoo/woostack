import { describe, expect, it, vi } from "vitest";

vi.mock("@supabase/supabase-js", () => ({
  createClient: vi.fn(() => ({ auth: {}, from: vi.fn() })),
}));

import { createClient } from "@supabase/supabase-js";
import { createBrowserClient } from "./browser";

describe("createBrowserClient", () => {
  it("creates a Supabase client with the provided URL and anon key", () => {
    const client = createBrowserClient("http://localhost:54321", "test-anon-key");

    expect(createClient).toHaveBeenCalledWith("http://localhost:54321", "test-anon-key", undefined);
    expect(client).toBeDefined();
  });

  it("passes through custom options", () => {
    createBrowserClient("http://localhost:54321", "test-anon-key", {
      auth: { flowType: "pkce" },
    });

    expect(createClient).toHaveBeenCalledWith(
      "http://localhost:54321",
      "test-anon-key",
      expect.objectContaining({
        auth: expect.objectContaining({ flowType: "pkce" }),
      }),
    );
  });
});
