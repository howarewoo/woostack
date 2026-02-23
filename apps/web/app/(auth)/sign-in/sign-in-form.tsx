"use client";

import { Link, useNavigation } from "@infrastructure/navigation";
import { useAuth } from "@infrastructure/supabase/auth";
import { useState } from "react";
import { toast } from "sonner";
import { AuthForm } from "@/components/auth-form";

const isDev = process.env.NODE_ENV === "development";

/** Client-side sign-in form with email/password and OAuth support. */
export function SignInForm() {
  const { signIn } = useAuth();
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

  async function handleOAuth(provider: "google" | "apple" | "github") {
    try {
      toast.info(`TODO: Implement OAuth sign-in for ${provider}`);
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
      defaultEmail={isDev ? "demo@example.com" : ""}
      defaultPassword={isDev ? "demo1234" : ""}
      disabled={isDev}
      footer={
        <>
          <Link href="/forgot-password" className="text-muted-foreground hover:text-foreground">
            Forgot password?
          </Link>
          <p className="mt-2 text-muted-foreground">
            Don&apos;t have an account?{" "}
            <Link href="/sign-up" className="text-foreground underline">
              Sign Up
            </Link>
          </p>
        </>
      }
    />
  );
}
