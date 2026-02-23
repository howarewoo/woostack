import { createServerSupabase } from "@/lib/supabase";
import { SettingsContent } from "./settings-content";

export default async function SettingsPage() {
  const supabase = await createServerSupabase();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  return (
    <SettingsContent
      email={user?.email ?? "—"}
      userId={user?.id ?? "—"}
      createdAt={user?.created_at ?? null}
    />
  );
}
