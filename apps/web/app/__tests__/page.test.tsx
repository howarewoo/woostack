import { describe, expect, it, vi } from "vitest";

const { mockRedirect, mockGetUser } = vi.hoisted(() => ({
  mockRedirect: vi.fn(),
  mockGetUser: vi.fn(),
}));

vi.mock("next/navigation", () => ({
  redirect: mockRedirect,
}));

vi.mock("@/lib/supabase", () => ({
  createServerSupabase: () =>
    Promise.resolve({
      auth: { getUser: mockGetUser },
    }),
}));

import Home from "@/app/page";

describe("Root page", () => {
  it("redirects to /dashboard when user exists", async () => {
    mockGetUser.mockResolvedValue({
      data: { user: { id: "123" } },
      error: null,
    });
    await Home();
    expect(mockRedirect).toHaveBeenCalledWith("/dashboard");
  });

  it("redirects to /sign-in when no user", async () => {
    mockGetUser.mockResolvedValue({
      data: { user: null },
      error: null,
    });
    await Home();
    expect(mockRedirect).toHaveBeenCalledWith("/sign-in");
  });
});
