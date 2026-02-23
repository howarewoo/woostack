"use client";

import { Link } from "@infrastructure/navigation";
import { useState } from "react";
import { toast } from "sonner";
import { AuthForm } from "@/components/auth-form";

/** Client-side reset-password form for setting a new password. */
export function ResetPasswordForm() {
  const [error, setError] = useState("");
  const [isLoading, setIsLoading] = useState(false);

  async function handleSubmit(_email: string, _password: string) {
    setError("");
    setIsLoading(true);
    try {
      // TODO: Implement password reset logic (e.g. supabase.auth.updateUser({ password }))
      toast.info("TODO: Implement password reset logic");
      setIsLoading(false);
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
        <Link href="/sign-in" className="text-muted-foreground hover:text-foreground">
          Back to Sign In
        </Link>
      }
    />
  );
}
