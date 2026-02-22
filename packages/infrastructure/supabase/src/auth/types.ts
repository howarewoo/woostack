import type { Session, User } from "@supabase/supabase-js";

/** State of the authentication session. */
export interface AuthState {
  session: Session | null;
  user: User | null;
  isLoading: boolean;
}

/** Value provided by AuthProvider to consuming components. */
export interface AuthContextValue extends AuthState {
  signIn(credentials: { email: string; password: string }): Promise<void>;
  signUp(credentials: { email: string; password: string }): Promise<void>;
  signOut(): Promise<void>;
  signInWithOAuth(provider: "google" | "apple" | "github"): Promise<void>;
}
