"use client";

import { NavigationProvider } from "@infrastructure/navigation";
import { AuthProvider } from "@infrastructure/supabase/auth";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { useState } from "react";
import { useWebNavigation } from "../lib/navigation";
import { createBrowserSupabase } from "../lib/supabase";

export function Providers({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(
    () =>
      new QueryClient({
        defaultOptions: {
          queries: {
            staleTime: 60 * 1000,
          },
        },
      })
  );
  const [supabase] = useState(() => createBrowserSupabase());

  const navigationValue = useWebNavigation();

  return (
    <QueryClientProvider client={queryClient}>
      <AuthProvider supabase={supabase}>
        <NavigationProvider value={navigationValue}>{children}</NavigationProvider>
      </AuthProvider>
    </QueryClientProvider>
  );
}
