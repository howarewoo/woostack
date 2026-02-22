import { useContext } from "react";
import { AuthContext } from "./context";
import type { AuthContextValue } from "./types";

/**
 * Returns the current auth state and actions (signIn, signOut, signUp, signInWithOAuth).
 * Must be used within an AuthProvider.
 */
export function useAuth(): AuthContextValue {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error("useAuth must be used within an AuthProvider");
  }
  return context;
}
