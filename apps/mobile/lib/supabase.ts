import { createBrowserClient } from "@infrastructure/supabase";

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is required`);
  return value;
}

const supabaseUrl = requireEnv("EXPO_PUBLIC_SUPABASE_URL");
const supabaseAnonKey = requireEnv("EXPO_PUBLIC_SUPABASE_ANON_KEY");

/** Creates a Supabase client for React Native. */
export function createMobileSupabase() {
  return createBrowserClient(supabaseUrl, supabaseAnonKey);
}
