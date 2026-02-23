import { redirect } from "next/navigation";
import { createServerSupabase } from "@/lib/supabase";

export default async function ProtectedLayout({ children }: { children: React.ReactNode }) {
  const supabase = await createServerSupabase();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/sign-in");
  }

  return <>{children}</>;
}
