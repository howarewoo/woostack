import "../global.css";
import { NavigationProvider } from "@infrastructure/navigation";
import { AuthProvider } from "@infrastructure/supabase/auth";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { Stack } from "expo-router";
import { StatusBar } from "expo-status-bar";
import { useState } from "react";
import { useMobileNavigation } from "../lib/navigation";
import { createMobileSupabase } from "../lib/supabase";

export default function RootLayout() {
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
  const [supabase] = useState(() => createMobileSupabase());

  const navigationValue = useMobileNavigation();

  return (
    <QueryClientProvider client={queryClient}>
      <AuthProvider supabase={supabase}>
        <NavigationProvider value={navigationValue}>
          <StatusBar style="auto" />
          <Stack screenOptions={{ headerShown: false }} />
        </NavigationProvider>
      </AuthProvider>
    </QueryClientProvider>
  );
}
