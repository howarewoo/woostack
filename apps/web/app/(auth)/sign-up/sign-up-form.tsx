"use client";

import { Link } from "@infrastructure/navigation";
import { useState } from "react";
import { toast } from "sonner";
import { AuthForm } from "@/components/auth-form";

/** Client-side sign-up form with email/password and OAuth support. */
export function SignUpForm() {
  const [error, setError] = useState("");
  const [isLoading, setIsLoading] = useState(false);

  async function handleSubmit(_email: string, _password: string) {
    setError("");
    setIsLoading(true);
    try {
      // TODO: Implement sign-up logic (e.g. signUp({ email, password }) via your auth provider)
      toast.info("TODO: Implement sign-up logic");
      setIsLoading(false);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Sign up failed");
      setIsLoading(false);
    }
  }

  async function handleOAuth(provider: "google" | "apple" | "github") {
    try {
      toast.info(`TODO: Implement OAuth sign-up for ${provider}`);
      // TODO: Implement OAuth sign-up logic (e.g. signInWithOAuth(provider) via your auth provider)
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "OAuth sign in failed");
    }
  }

  return (
    <AuthForm
      title="Sign Up"
      description="Create an account to get started"
      submitLabel="Create Account"
      onSubmit={handleSubmit}
      showOAuth
      onOAuthClick={handleOAuth}
      error={error}
      isLoading={isLoading}
      footer={
        <p className="text-muted-foreground">
          Already have an account?{" "}
          <Link href="/sign-in" className="text-foreground underline">
            Sign In
          </Link>
        </p>
      }
    />
  );
}
