import { createServerClient } from "@supabase/ssr";
import type { Database } from "../generated/database";
import type { TypedSupabaseClient } from "../types";

interface CookieStore {
  getAll(): Array<{ name: string; value: string }>;
  set(name: string, value: string, options?: Record<string, unknown>): void;
}

/**
 * Creates a Supabase server client for Next.js server components and route handlers.
 * Uses cookies for session management (not localStorage).
 *
 * Usage:
 * ```typescript
 * import { cookies } from "next/headers";
 * const supabase = createSSRServerClient(url, key, await cookies());
 * ```
 */
export function createSSRServerClient(
  supabaseUrl: string,
  supabaseAnonKey: string,
  cookieStore: CookieStore
): TypedSupabaseClient {
  return createServerClient<Database>(supabaseUrl, supabaseAnonKey, {
    cookies: {
      getAll() {
        return cookieStore.getAll();
      },
      setAll(cookiesToSet) {
        try {
          for (const { name, value, options } of cookiesToSet) {
            cookieStore.set(name, value, options);
          }
        } catch {
          // Called from a Server Component where cookies can't be set.
          // The middleware proxy handles token refresh in this case.
        }
      },
    },
  });
}
