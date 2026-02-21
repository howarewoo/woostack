import type { Session, SupabaseClient, User } from "@supabase/supabase-js";
import { type ReactNode, useCallback, useEffect, useMemo, useState } from "react";
import { AuthContext } from "./context";
import type { AuthContextValue } from "./types";

interface AuthProviderProps {
  supabase: SupabaseClient;
  children: ReactNode;
}

/** Provides auth state and actions to the component tree. */
export function AuthProvider({ supabase, children }: AuthProviderProps) {
  const [session, setSession] = useState<Session | null>(null);
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session: initialSession } }) => {
      setSession(initialSession);
      setUser(initialSession?.user ?? null);
      setIsLoading(false);
    });

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, newSession) => {
      setSession(newSession);
      setUser(newSession?.user ?? null);
      setIsLoading(false);
    });

    return () => subscription.unsubscribe();
  }, [supabase]);

  const signIn = useCallback(
    async (credentials: { email: string; password: string }) => {
      const { error } = await supabase.auth.signInWithPassword(credentials);
      if (error) throw error;
    },
    [supabase]
  );

  const signUp = useCallback(
    async (credentials: { email: string; password: string }) => {
      const { error } = await supabase.auth.signUp(credentials);
      if (error) throw error;
    },
    [supabase]
  );

  const signOut = useCallback(async () => {
    const { error } = await supabase.auth.signOut();
    if (error) throw error;
  }, [supabase]);

  const signInWithOAuth = useCallback(
    async (provider: "google" | "apple" | "github") => {
      const { error } = await supabase.auth.signInWithOAuth({ provider });
      if (error) throw error;
    },
    [supabase]
  );

  const value = useMemo<AuthContextValue>(
    () => ({ session, user, isLoading, signIn, signUp, signOut, signInWithOAuth }),
    [session, user, isLoading, signIn, signUp, signOut, signInWithOAuth]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}
