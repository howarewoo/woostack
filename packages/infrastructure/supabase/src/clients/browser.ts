import { type SupabaseClientOptions, createClient } from "@supabase/supabase-js";
import type { Database } from "../generated/database";
import type { TypedSupabaseClient } from "../types";

/**
 * Creates a Supabase browser client for use in client-side React code.
 * Uses the anon/publishable key. Session is managed automatically via localStorage.
 */
export function createBrowserClient(
  supabaseUrl: string,
  supabaseAnonKey: string,
  options?: SupabaseClientOptions<"public">,
): TypedSupabaseClient {
  return createClient<Database>(supabaseUrl, supabaseAnonKey, options);
}
