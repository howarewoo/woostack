import type { TypedSupabaseClient } from "@infrastructure/supabase";
import { createSSRBrowserClient } from "@infrastructure/supabase/browser-ssr";
import { createSSRServerClient } from "@infrastructure/supabase/server-ssr";

if (!process.env.NEXT_PUBLIC_SUPABASE_URL) throw new Error("NEXT_PUBLIC_SUPABASE_URL is required");
if (!process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY)
  throw new Error("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY is required");

const supabaseUrl: string = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabasePublishableKey: string = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;

/** Creates a Supabase client for use in client components. */
export function createBrowserSupabase(): TypedSupabaseClient {
  return createSSRBrowserClient(supabaseUrl, supabasePublishableKey);
}

/** Creates a Supabase client for use in server components. */
export async function createServerSupabase(): Promise<TypedSupabaseClient> {
  const { cookies } = await import("next/headers");
  return createSSRServerClient(supabaseUrl, supabasePublishableKey, await cookies());
}
