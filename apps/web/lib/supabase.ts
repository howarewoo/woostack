import type { TypedSupabaseClient } from "@infrastructure/supabase";
import { createSSRBrowserClient } from "@infrastructure/supabase/browser-ssr";
import { createSSRServerClient } from "@infrastructure/supabase/server-ssr";

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is required`);
  return value;
}

const supabaseUrl = requireEnv("NEXT_PUBLIC_SUPABASE_URL");
const supabaseAnonKey = requireEnv("NEXT_PUBLIC_SUPABASE_ANON_KEY");

/** Creates a Supabase client for use in client components. */
export function createBrowserSupabase(): TypedSupabaseClient {
  return createSSRBrowserClient(supabaseUrl, supabaseAnonKey);
}

/** Creates a Supabase client for use in server components. */
export async function createServerSupabase(): Promise<TypedSupabaseClient> {
  const { cookies } = await import("next/headers");
  return createSSRServerClient(supabaseUrl, supabaseAnonKey, await cookies());
}
