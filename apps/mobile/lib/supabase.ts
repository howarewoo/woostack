import { createBrowserClient } from "@infrastructure/supabase";

/** Creates a Supabase client for React Native. */
export function createMobileSupabase() {
  const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL;
  const supabaseAnonKey = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY;

  if (!supabaseUrl) throw new Error("EXPO_PUBLIC_SUPABASE_URL is required");
  if (!supabaseAnonKey) throw new Error("EXPO_PUBLIC_SUPABASE_ANON_KEY is required");

  return createBrowserClient(supabaseUrl, supabaseAnonKey);
}
