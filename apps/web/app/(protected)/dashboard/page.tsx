import { createServerSupabase } from "@/lib/supabase";
import { DashboardContent } from "./dashboard-content";

export default async function DashboardPage() {
  const supabase = await createServerSupabase();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const email = user?.email ?? "User";

  return <DashboardContent email={email} />;
}
