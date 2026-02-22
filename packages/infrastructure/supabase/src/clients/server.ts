import { createClient } from "@supabase/supabase-js";
import type { Database } from "../generated/database";
import type { TypedSupabaseClient } from "../types";

/**
 * Creates a Supabase server client for use in API routes and server-side code.
 * Disables auto-refresh and session persistence since the server manages its own auth.
 */
export function createServerClient(supabaseUrl: string, supabaseKey: string): TypedSupabaseClient {
  return createClient<Database>(supabaseUrl, supabaseKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
}
