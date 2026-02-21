import type { TypedSupabaseClient } from "@infrastructure/supabase";
import { createSSRBrowserClient } from "@infrastructure/supabase/browser-ssr";
import { createSSRServerClient } from "@infrastructure/supabase/server-ssr";

if (!process.env.NEXT_PUBLIC_SUPABASE_URL) throw new Error("NEXT_PUBLIC_SUPABASE_URL is required");
if (!process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY)
  throw new Error("NEXT_PUBLIC_SUPABASE_ANON_KEY is required");

const supabaseUrl: string = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseAnonKey: string = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

/** Creates a Supabase client for use in client components. */
export function createBrowserSupabase(): TypedSupabaseClient {
  return createSSRBrowserClient(supabaseUrl, supabaseAnonKey);
}

/** Creates a Supabase client for use in server components. */
export async function createServerSupabase(): Promise<TypedSupabaseClient> {
  const { cookies } = await import("next/headers");
  return createSSRServerClient(supabaseUrl, supabaseAnonKey, await cookies());
}
