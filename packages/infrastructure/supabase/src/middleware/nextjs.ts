import { createServerClient } from "@supabase/ssr";
import { type NextRequest, NextResponse } from "next/server";
import type { Database } from "../generated/database";

interface SupabaseMiddlewareOptions {
  supabaseUrl: string;
  supabaseAnonKey: string;
  /** Route prefixes that require authentication. E.g., ["/dashboard", "/settings"]. */
  protectedRoutes?: string[];
  /** Path to redirect unauthenticated users to. Defaults to "/login". */
  loginPath?: string;
}

/**
 * Creates a Next.js middleware that refreshes the Supabase auth session
 * on every request and optionally redirects unauthenticated users from
 * protected routes to the login page.
 */
export function createSupabaseMiddleware(options: SupabaseMiddlewareOptions) {
  const { supabaseUrl, supabaseAnonKey, protectedRoutes = [], loginPath = "/login" } = options;

  return async function middleware(request: NextRequest) {
    let supabaseResponse = NextResponse.next({ request });

    const supabase = createServerClient<Database>(supabaseUrl, supabaseAnonKey, {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          for (const { name, value } of cookiesToSet) {
            request.cookies.set(name, value);
          }
          supabaseResponse = NextResponse.next({ request });
          for (const { name, value, options } of cookiesToSet) {
            supabaseResponse.cookies.set(name, value, options);
          }
        },
      },
    });

    const {
      data: { user },
    } = await supabase.auth.getUser();

    const isProtected = protectedRoutes.some((route) =>
      request.nextUrl.pathname.startsWith(route),
    );

    if (isProtected && !user) {
      const url = request.nextUrl.clone();
      url.pathname = loginPath;
      return NextResponse.redirect(url);
    }

    return supabaseResponse;
  };
}
