import { renderHook } from "@testing-library/react";
import type { ReactNode } from "react";
import { describe, expect, it } from "vitest";
import { AuthContext } from "./context";
import type { AuthContextValue } from "./types";
import { useUser } from "./useUser";

const mockValue: AuthContextValue = {
  session: null,
  user: null,
  isLoading: false,
  signIn: async () => {},
  signUp: async () => {},
  signOut: async () => {},
  signInWithOAuth: async () => {},
};

describe("useUser", () => {
  it("returns null when no user is signed in", () => {
    function wrapper({ children }: { children: ReactNode }) {
      return <AuthContext.Provider value={mockValue}>{children}</AuthContext.Provider>;
    }
    const { result } = renderHook(() => useUser(), { wrapper });
    expect(result.current).toBeNull();
  });

  it("returns user when signed in", () => {
    const mockUser = { id: "123", email: "test@test.com" } as any;
    function wrapper({ children }: { children: ReactNode }) {
      return (
        <AuthContext.Provider value={{ ...mockValue, user: mockUser }}>
          {children}
        </AuthContext.Provider>
      );
    }
    const { result } = renderHook(() => useUser(), { wrapper });
    expect(result.current).toEqual(mockUser);
  });
});
