import { useNavigation } from "@infrastructure/navigation";
import { useAuth } from "@infrastructure/supabase/auth";
import { toast } from "sonner";

/** Hook providing a sign-out handler that navigates to the sign-in page. */
export function useSignOut() {
  const { signOut } = useAuth();
  const { replace } = useNavigation();

  return async function handleSignOut() {
    try {
      await signOut();
      replace("/sign-in");
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Sign out failed");
    }
  };
}
