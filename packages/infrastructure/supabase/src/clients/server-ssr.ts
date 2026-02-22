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
  supabasePublishableKey: string,
  cookieStore: CookieStore
): TypedSupabaseClient {
  return createServerClient<Database>(supabaseUrl, supabasePublishableKey, {
    cookies: {
      getAll() {
        return cookieStore.getAll();
      },
      setAll(cookiesToSet) {
        try {
          for (const { name, value, options } of cookiesToSet) {
            cookieStore.set(name, value, options);
          }
        } catch (_error) {
          // Expected in Server Components where cookies are read-only.
          // The Next.js middleware handles token refresh in this case.
        }
      },
    },
  });
}
