"use client";

import { useNavigation } from "@infrastructure/navigation";
import { useAuth } from "@infrastructure/supabase/auth";
import { useState } from "react";
import { toast } from "sonner";
import { AuthForm } from "@/components/auth-form";

export default function SignInPage() {
  const { signIn, signInWithOAuth } = useAuth();
  const { replace } = useNavigation();
  const [error, setError] = useState("");
  const [isLoading, setIsLoading] = useState(false);

  async function handleSubmit(email: string, password: string) {
    setError("");
    setIsLoading(true);
    try {
      await signIn({ email, password });
      replace("/dashboard");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Sign in failed");
      setIsLoading(false);
    }
  }

  async function handleOAuth(_provider: "google" | "apple" | "github") {
    try {
      toast.error(
        "OAuth for provider sign in is not implemented yet. Please use email and password to sign in."
      );
      // TODO: Implement OAuth sign-in logic for provider, which will depend on your backend/auth provider. For example, if using Supabase, you would call signInWithOAuth(provider) here to initiate the OAuth flow.
      // await signInWithOAuth(provider);
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "OAuth sign in failed");
    }
  }

  return (
    <AuthForm
      title="Sign In"
      description="Enter your credentials to access your account"
      submitLabel="Sign In"
      onSubmit={handleSubmit}
      showOAuth
      onOAuthClick={handleOAuth}
      error={error}
      isLoading={isLoading}
      defaultEmail="demo@example.com"
      defaultPassword="demo1234"
      disabled
      footer={
        <>
          <a href="/forgot-password" className="text-muted-foreground hover:text-foreground">
            Forgot password?
          </a>
          <p className="mt-2 text-muted-foreground">
            Don&apos;t have an account?{" "}
            <a href="/sign-up" className="text-foreground underline">
              Sign Up
            </a>
          </p>
        </>
      }
    />
  );
}
