import { beforeEach, describe, expect, it, vi } from "vitest";
import { createSupabaseMiddleware } from "../nextjs";

// Mock @supabase/ssr
const mockGetUser = vi.fn();
vi.mock("@supabase/ssr", () => ({
  createServerClient: vi.fn(() => ({
    auth: {
      getUser: mockGetUser,
    },
  })),
}));

// Mock next/server
const mockRedirect = vi.fn((url: URL) => ({
  type: "redirect" as const,
  url,
  cookies: { set: vi.fn() },
}));

const mockNext = vi.fn((opts?: { request: any }) => ({
  type: "next" as const,
  request: opts?.request,
  cookies: { set: vi.fn() },
}));

vi.mock("next/server", () => ({
  NextResponse: {
    redirect: (url: URL) => mockRedirect(url),
    next: (opts?: { request: any }) => mockNext(opts),
  },
}));

function createMockRequest(pathname: string) {
  const url = new URL(`http://localhost:3000${pathname}`);
  return {
    cookies: {
      getAll: vi.fn(() => []),
      set: vi.fn(),
    },
    nextUrl: {
      pathname,
      clone: () => ({ ...url, pathname }),
    },
  };
}

describe("createSupabaseMiddleware", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("returns a middleware function", () => {
    const middleware = createSupabaseMiddleware({
      supabaseUrl: "http://localhost:54321",
      supabaseAnonKey: "test-anon-key",
      protectedRoutes: ["/dashboard"],
      loginPath: "/login",
    });

    expect(typeof middleware).toBe("function");
  });

  it("redirects unauthenticated users from protected routes to login", async () => {
    mockGetUser.mockResolvedValue({ data: { user: null }, error: null });

    const middleware = createSupabaseMiddleware({
      supabaseUrl: "http://localhost:54321",
      supabaseAnonKey: "test-anon-key",
      protectedRoutes: ["/dashboard"],
      loginPath: "/login",
    });

    const request = createMockRequest("/dashboard/settings");
    await middleware(request as any);

    expect(mockRedirect).toHaveBeenCalledOnce();
    const redirectUrl = mockRedirect.mock.calls[0]![0] as URL;
    expect(redirectUrl.pathname).toBe("/login");
  });

  it("allows authenticated users on protected routes", async () => {
    mockGetUser.mockResolvedValue({
      data: { user: { id: "user-123", email: "test@example.com" } },
      error: null,
    });

    const middleware = createSupabaseMiddleware({
      supabaseUrl: "http://localhost:54321",
      supabaseAnonKey: "test-anon-key",
      protectedRoutes: ["/dashboard"],
      loginPath: "/login",
    });

    const request = createMockRequest("/dashboard");
    await middleware(request as any);

    expect(mockRedirect).not.toHaveBeenCalled();
    expect(mockNext).toHaveBeenCalled();
  });

  it("allows unauthenticated users on non-protected routes", async () => {
    mockGetUser.mockResolvedValue({ data: { user: null }, error: null });

    const middleware = createSupabaseMiddleware({
      supabaseUrl: "http://localhost:54321",
      supabaseAnonKey: "test-anon-key",
      protectedRoutes: ["/dashboard"],
      loginPath: "/login",
    });

    const request = createMockRequest("/about");
    await middleware(request as any);

    expect(mockRedirect).not.toHaveBeenCalled();
    expect(mockNext).toHaveBeenCalled();
  });

  it("uses /login as default loginPath when not specified", async () => {
    mockGetUser.mockResolvedValue({ data: { user: null }, error: null });

    const middleware = createSupabaseMiddleware({
      supabaseUrl: "http://localhost:54321",
      supabaseAnonKey: "test-anon-key",
      protectedRoutes: ["/settings"],
    });

    const request = createMockRequest("/settings");
    await middleware(request as any);

    expect(mockRedirect).toHaveBeenCalledOnce();
    const redirectUrl = mockRedirect.mock.calls[0]![0] as URL;
    expect(redirectUrl.pathname).toBe("/login");
  });
});
