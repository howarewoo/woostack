import { createBrowserClient } from "@supabase/ssr";
import type { Database } from "../generated/database";
import type { TypedSupabaseClient } from "../types";

/**
 * Creates a Supabase browser client for Next.js client components.
 * Uses cookies (not localStorage) for session management, ensuring
 * the session is accessible in both server and client rendering.
 */
export function createSSRBrowserClient(
  supabaseUrl: string,
  supabaseAnonKey: string
): TypedSupabaseClient {
  return createBrowserClient<Database>(supabaseUrl, supabaseAnonKey);
}
