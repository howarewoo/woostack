import type { TypedSupabaseClient } from "@infrastructure/supabase";
import { createSSRBrowserClient } from "@infrastructure/supabase/browser-ssr";
import { createSSRServerClient } from "@infrastructure/supabase/server-ssr";

function getSupabaseConfig() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!url) throw new Error("NEXT_PUBLIC_SUPABASE_URL is required");
  if (!key) throw new Error("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY is required");
  return { url, key };
}

/** Creates a Supabase client for use in client components. */
export function createBrowserSupabase(): TypedSupabaseClient {
  const { url, key } = getSupabaseConfig();
  return createSSRBrowserClient(url, key);
}

/** Creates a Supabase client for use in server components. */
export async function createServerSupabase(): Promise<TypedSupabaseClient> {
  const { url, key } = getSupabaseConfig();
  const { cookies } = await import("next/headers");
  return createSSRServerClient(url, key, await cookies());
}
