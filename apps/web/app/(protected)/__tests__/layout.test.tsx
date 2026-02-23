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

import ProtectedLayout from "../layout";

describe("ProtectedLayout", () => {
  it("redirects to /sign-in when no user", async () => {
    mockGetUser.mockResolvedValue({ data: { user: null }, error: null });
    await ProtectedLayout({ children: <div>child</div> });
    expect(mockRedirect).toHaveBeenCalledWith("/sign-in");
  });

  it("renders children when user exists", async () => {
    mockGetUser.mockResolvedValue({
      data: { user: { id: "123", email: "test@test.com" } },
      error: null,
    });
    const result = await ProtectedLayout({ children: <div>child</div> });
    expect(result).toBeDefined();
  });
});
