import type { User } from "@supabase/supabase-js";
import { useAuth } from "./useAuth";

/**
 * Returns the current authenticated user, or null if not signed in.
 * Convenience wrapper around useAuth() that extracts just the user.
 */
export function useUser(): User | null {
  const { user } = useAuth();
  return user;
}
