import { renderHook } from "@testing-library/react";
import type { ReactNode } from "react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { AuthProvider } from "../AuthProvider";
import { useAuth } from "../useAuth";

function createMockSupabaseClient() {
  return {
    auth: {
      getSession: vi.fn(() => Promise.resolve({ data: { session: null }, error: null })),
      getUser: vi.fn(() => Promise.resolve({ data: { user: null }, error: null })),
      onAuthStateChange: vi.fn((_callback: any) => {
        return {
          data: {
            subscription: { unsubscribe: vi.fn() },
          },
        };
      }),
      signInWithPassword: vi.fn(() =>
        Promise.resolve({ data: { session: null, user: null }, error: null })
      ),
      signUp: vi.fn(() => Promise.resolve({ data: { session: null, user: null }, error: null })),
      signOut: vi.fn(() => Promise.resolve({ error: null })),
      signInWithOAuth: vi.fn(() =>
        Promise.resolve({ data: { url: null, provider: "google" }, error: null })
      ),
    },
  };
}

describe("AuthProvider", () => {
  let mockClient: ReturnType<typeof createMockSupabaseClient>;

  beforeEach(() => {
    mockClient = createMockSupabaseClient();
  });

  function wrapper({ children }: { children: ReactNode }) {
    return <AuthProvider supabase={mockClient as any}>{children}</AuthProvider>;
  }

  it("provides initial loading state", () => {
    const { result } = renderHook(() => useAuth(), { wrapper });
    expect(result.current.isLoading).toBe(true);
    expect(result.current.user).toBeNull();
    expect(result.current.session).toBeNull();
  });

  it("subscribes to auth state changes on mount", () => {
    renderHook(() => useAuth(), { wrapper });
    expect(mockClient.auth.onAuthStateChange).toHaveBeenCalledOnce();
  });

  it("calls getUser on mount for server-validated auth", () => {
    renderHook(() => useAuth(), { wrapper });
    expect(mockClient.auth.getUser).toHaveBeenCalledOnce();
  });
});
