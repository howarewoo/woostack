import { createBrowserClient } from "@infrastructure/supabase";

const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL!;
const supabaseAnonKey = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY!;

/** Creates a Supabase client for React Native. */
export function createMobileSupabase() {
  return createBrowserClient(supabaseUrl, supabaseAnonKey);
}
