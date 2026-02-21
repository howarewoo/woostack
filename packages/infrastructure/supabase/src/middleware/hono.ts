import { createClient, type SupabaseClient, type User } from "@supabase/supabase-js";
import type { MiddlewareHandler } from "hono";
import type { Database } from "../generated/database";

declare module "hono" {
  interface ContextVariableMap {
    user: User | undefined;
    supabase: SupabaseClient<Database>;
  }
}

interface SupabaseMiddlewareOptions {
  supabaseUrl: string;
  supabaseServiceKey: string;
}

/**
 * Hono middleware that validates Supabase JWTs and attaches the user
 * and an RLS-scoped Supabase client to the request context.
 *
 * - If a valid Bearer token is present, `c.get("user")` returns the authenticated user
 *   and `c.get("supabase")` returns a client scoped to that user's JWT (respects RLS).
 * - If no token or invalid token, `c.get("user")` is undefined and `c.get("supabase")`
 *   is an unauthenticated service client.
 */
export function supabaseMiddleware(options: SupabaseMiddlewareOptions): MiddlewareHandler {
  return async (c, next) => {
    const { supabaseUrl, supabaseServiceKey } = options;

    const authHeader = c.req.header("Authorization");
    const token = authHeader?.startsWith("Bearer ") ? authHeader.slice(7) : undefined;

    if (token) {
      const supabase = createClient<Database>(supabaseUrl, supabaseServiceKey, {
        global: { headers: { Authorization: `Bearer ${token}` } },
        auth: { autoRefreshToken: false, persistSession: false },
      });

      const {
        data: { user },
        error,
      } = await supabase.auth.getUser(token);

      if (!error && user) {
        c.set("user", user);
        c.set("supabase", supabase);
        return next();
      }
    }

    const supabase = createClient<Database>(supabaseUrl, supabaseServiceKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    c.set("user", undefined);
    c.set("supabase", supabase);

    return next();
  };
}
