import { renderHook } from "@testing-library/react";
import type { ReactNode } from "react";
import { describe, expect, it } from "vitest";
import { AuthContext } from "./context";
import type { AuthContextValue } from "./types";
import { useAuth } from "./useAuth";

const mockValue: AuthContextValue = {
  session: null,
  user: null,
  isLoading: false,
  signIn: async () => {},
  signUp: async () => {},
  signOut: async () => {},
  signInWithOAuth: async () => {},
};

describe("useAuth", () => {
  it("returns context value when used within provider", () => {
    function wrapper({ children }: { children: ReactNode }) {
      return <AuthContext.Provider value={mockValue}>{children}</AuthContext.Provider>;
    }
    const { result } = renderHook(() => useAuth(), { wrapper });
    expect(result.current.isLoading).toBe(false);
    expect(result.current.user).toBeNull();
  });

  it("throws when used outside provider", () => {
    expect(() => {
      renderHook(() => useAuth());
    }).toThrow("useAuth must be used within an AuthProvider");
  });
});
