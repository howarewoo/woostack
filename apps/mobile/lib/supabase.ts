import { createBrowserClient } from "@infrastructure/supabase";

/** Creates a Supabase client for React Native. */
export function createMobileSupabase() {
  const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL;
  const supabasePublishableKey = process.env.EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY;

  if (!supabaseUrl) throw new Error("EXPO_PUBLIC_SUPABASE_URL is required");
  if (!supabasePublishableKey) throw new Error("EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY is required");

  return createBrowserClient(supabaseUrl, supabasePublishableKey);
}
