"use client";

import { useNavigation } from "@infrastructure/navigation";
// import { useAuth } from "@infrastructure/supabase/auth";
import { useState } from "react";
import { toast } from "sonner";
import { AuthForm } from "@/components/auth-form";

export default function SignUpPage() {
  // const { signUp, signInWithOAuth } = useAuth();
  const { replace } = useNavigation();
  const [error, setError] = useState("");
  const [isLoading, setIsLoading] = useState(false);

  async function handleSubmit(email: string, password: string) {
    setError("");
    setIsLoading(true);
    try {
      console.log("TODO: Implement sign-up logic for email:", email);
      console.log("TODO: Implement sign-up logic for password:", password);
      // TODO: This is a placeholder for the actual sign-up logic, which will depend on your backend/auth provider. For example, if using Supabase, you would call signUp({ email, password }) here to create the user, and then redirect to the dashboard or sign-in page.
      // await signUp({ email, password });
      replace("/dashboard");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Sign up failed");
      setIsLoading(false);
    }
  }

  async function handleOAuth(provider: "google" | "apple" | "github") {
    try {
      console.log("TODO: Implement OAuth sign-up logic for provider:", provider);
      // TODO: This is a placeholder for the actual OAuth sign-up logic, which will depend on your backend/auth provider. For example, if using Supabase, you would call signInWithOAuth(provider) here to initiate the OAuth flow.
      // await signInWithOAuth(provider);
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
          <a href="/sign-in" className="text-foreground underline">
            Sign In
          </a>
        </p>
      }
    />
  );
}
