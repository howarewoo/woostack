"use client";

import { Link } from "@infrastructure/navigation";
import { useState } from "react";
import { toast } from "sonner";
import { AuthForm } from "@/components/auth-form";

/** Client-side forgot-password form that sends a password reset email. */
export function ForgotPasswordForm() {
  const [error, setError] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [sent, setSent] = useState(false);

  async function handleSubmit(_email: string) {
    setError("");
    setIsLoading(true);
    try {
      // TODO: Implement password reset email (e.g. supabase.auth.resetPasswordForEmail(email))
      toast.info("TODO: Implement password reset email");
      setSent(true);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to send reset email");
    }
    setIsLoading(false);
  }

  if (sent) {
    return (
      <div className="flex min-h-screen items-center justify-center p-4">
        <div className="w-full max-w-md space-y-4 text-center">
          <h2 className="text-2xl font-bold">Check your email</h2>
          <p className="text-muted-foreground">
            We sent a password reset link to your email address.
          </p>
          <Link href="/sign-in" className="text-sm text-muted-foreground hover:text-foreground">
            Back to Sign In
          </Link>
        </div>
      </div>
    );
  }

  return (
    <AuthForm
      title="Forgot Password"
      description="Enter your email to receive a password reset link"
      submitLabel="Send Reset Link"
      onSubmit={handleSubmit}
      error={error}
      isLoading={isLoading}
      hidePassword
      footer={
        <Link href="/sign-in" className="text-muted-foreground hover:text-foreground">
          Back to Sign In
        </Link>
      }
    />
  );
}
