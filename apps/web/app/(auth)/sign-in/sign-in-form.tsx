"use client";

import { SignInSchema } from "@features/auth";
import { Link, useNavigation } from "@infrastructure/navigation";
import { useAuth } from "@infrastructure/supabase/auth";
import {
  Button,
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
  Field,
  FieldError,
  FieldLabel,
  Input,
} from "@infrastructure/ui-web";
import { useForm } from "@tanstack/react-form";
import { useState } from "react";
import { toast } from "sonner";

/** Client-side sign-in form with email/password validation and OAuth support. */
export function SignInForm() {
  const { signIn } = useAuth();
  const { replace } = useNavigation();
  const [serverError, setServerError] = useState("");

  const form = useForm({
    defaultValues: {
      email: "",
      password: "",
    },
    validators: {
      onBlur: SignInSchema,
      onSubmit: SignInSchema,
    },
    onSubmit: async ({ value }) => {
      setServerError("");
      try {
        await signIn({ email: value.email, password: value.password });
        replace("/dashboard");
      } catch (err) {
        setServerError(err instanceof Error ? err.message : "Sign in failed");
      }
    },
  });

  function handleOAuth(provider: "google" | "apple" | "github") {
    toast.info(`TODO: Implement OAuth sign-in for ${provider}`);
  }

  return (
    <div className="min-h-screen flex items-center justify-center">
      <Card className="w-full max-w-md">
        <CardHeader>
          <CardTitle className="text-2xl">Sign In</CardTitle>
          <CardDescription>Enter your credentials to access your account</CardDescription>
        </CardHeader>
        <CardContent>
          <form
            onSubmit={(e) => {
              e.preventDefault();
              form.handleSubmit();
            }}
          >
            <div className="flex flex-col gap-4">
              <form.Field
                name="email"
                children={(field) => {
                  const isInvalid = field.state.meta.isTouched && !field.state.meta.isValid;
                  return (
                    <Field data-invalid={isInvalid}>
                      <FieldLabel htmlFor={field.name}>Email</FieldLabel>
                      <Input
                        id={field.name}
                        name={field.name}
                        type="email"
                        placeholder="you@example.com"
                        value={field.state.value}
                        onBlur={field.handleBlur}
                        onChange={(e) => field.handleChange(e.target.value)}
                        aria-invalid={isInvalid}
                      />
                      <FieldError errors={field.state.meta.errors} />
                    </Field>
                  );
                }}
              />
              <form.Field
                name="password"
                children={(field) => {
                  const isInvalid = field.state.meta.isTouched && !field.state.meta.isValid;
                  return (
                    <Field data-invalid={isInvalid}>
                      <FieldLabel htmlFor={field.name}>Password</FieldLabel>
                      <Input
                        id={field.name}
                        name={field.name}
                        type="password"
                        value={field.state.value}
                        onBlur={field.handleBlur}
                        onChange={(e) => field.handleChange(e.target.value)}
                        aria-invalid={isInvalid}
                      />
                      <FieldError errors={field.state.meta.errors} />
                    </Field>
                  );
                }}
              />
              {serverError && (
                <p role="alert" className="text-sm text-destructive">
                  {serverError}
                </p>
              )}
              <Button type="submit" className="w-full" disabled={form.state.isSubmitting}>
                Sign In
              </Button>
            </div>
          </form>
          <div className="mt-4 space-y-4">
            <div className="relative justify-center flex">
              <span className="bg-card px-2 text-xs text-muted-foreground">Or continue with</span>
            </div>
            <div className="grid grid-cols-3 gap-2">
              <Button
                variant="outline"
                aria-label="Continue with Google"
                onClick={() => handleOAuth("google")}
              >
                Google
              </Button>
              <Button
                variant="outline"
                aria-label="Continue with Apple"
                onClick={() => handleOAuth("apple")}
              >
                Apple
              </Button>
              <Button
                variant="outline"
                aria-label="Continue with GitHub"
                onClick={() => handleOAuth("github")}
              >
                GitHub
              </Button>
            </div>
          </div>
          <div className="mt-4 text-center text-sm">
            <Link href="/forgot-password" className="text-muted-foreground hover:text-foreground">
              Forgot password?
            </Link>
            <p className="mt-2 text-muted-foreground">
              Don&apos;t have an account?{" "}
              <Link href="/sign-up" className="text-foreground underline">
                Sign Up
              </Link>
            </p>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
