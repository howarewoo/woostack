import { createClient, type SupabaseClientOptions } from "@supabase/supabase-js";
import type { Database } from "../generated/database";
import type { TypedSupabaseClient } from "../types";

/**
 * Creates a Supabase browser client for use in client-side React code.
 * Uses the publishable key. Session is managed automatically via localStorage.
 */
export function createBrowserClient(
  supabaseUrl: string,
  supabasePublishableKey: string,
  options?: SupabaseClientOptions<"public">
): TypedSupabaseClient {
  return createClient<Database>(supabaseUrl, supabasePublishableKey, options);
}
