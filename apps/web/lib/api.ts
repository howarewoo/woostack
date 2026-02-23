import { createTypedApiClient, createTypedOrpcUtils } from "@infrastructure/api-client";
import { createBrowserSupabase } from "./supabase";

const API_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:3001/api";

export const apiClient = createTypedApiClient(API_URL, {
  getToken: async () => {
    const supabase = createBrowserSupabase();
    const { data } = await supabase.auth.getSession();
    return data.session?.access_token;
  },
});
export const orpc = createTypedOrpcUtils(apiClient);
