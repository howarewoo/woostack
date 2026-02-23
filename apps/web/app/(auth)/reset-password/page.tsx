"use client";

import { useNavigation } from "@infrastructure/navigation";
import { useState } from "react";
import { toast } from "sonner";
import { AuthForm } from "@/components/auth-form";
// import { createBrowserSupabase } from "@/lib/supabase";

export default function ResetPasswordPage() {
  const { replace } = useNavigation();
  const [error, setError] = useState("");
  const [isLoading, setIsLoading] = useState(false);

  async function handleSubmit(_email: string, _password: string) {
    setError("");
    setIsLoading(true);
    try {
      toast.info("TODO: Implement password reset logic");
      // TODO: This is a placeholder for the actual password reset logic, which will depend on your backend/auth provider. For example, if using Supabase, you would call supabase.auth.updateUser({ password }) here to update the user's password, and then redirect to the dashboard or sign-in page.
      // const supabase = createBrowserSupabase();
      // const { error: updateError } = await supabase.auth.updateUser({ password });
      // if (updateError) throw updateError;
      replace("/dashboard");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to reset password");
      setIsLoading(false);
    }
  }

  return (
    <AuthForm
      title="Reset Password"
      description="Enter your new password"
      submitLabel="Update Password"
      onSubmit={handleSubmit}
      error={error}
      isLoading={isLoading}
      footer={
        <a href="/sign-in" className="text-muted-foreground hover:text-foreground">
          Back to Sign In
        </a>
      }
    />
  );
}
