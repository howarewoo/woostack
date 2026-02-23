"use client";

import { SignUpSchema } from "@features/auth";
import { Link } from "@infrastructure/navigation";
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

/** Client-side sign-up form with email/password validation and OAuth support. */
export function SignUpForm() {
  const [serverError, setServerError] = useState("");

  const form = useForm({
    defaultValues: { email: "", password: "" },
    validators: {
      onBlur: SignUpSchema,
      onSubmit: SignUpSchema,
    },
    onSubmit: async ({ value: _value }) => {
      setServerError("");
      try {
        // TODO: Implement sign-up logic (e.g. signUp({ email, password }) via your auth provider)
        toast.info("TODO: Implement sign-up logic");
      } catch (err) {
        setServerError(err instanceof Error ? err.message : "Sign up failed");
      }
    },
  });

  function handleOAuth(provider: "google" | "apple" | "github") {
    toast.info(`TODO: Implement OAuth sign-up for ${provider}`);
  }

  return (
    <div className="min-h-screen flex items-center justify-center">
      <Card className="w-full max-w-md">
        <CardHeader>
          <CardTitle className="text-2xl">Sign Up</CardTitle>
          <CardDescription>Create an account to get started</CardDescription>
        </CardHeader>
        <CardContent>
          <form
            onSubmit={(e) => {
              e.preventDefault();
              form.handleSubmit();
            }}
          >
            <div className="flex flex-col gap-4">
              <form.Field name="email">
                {(field) => {
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
              </form.Field>
              <form.Field name="password">
                {(field) => {
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
              </form.Field>
              {serverError && (
                <p role="alert" className="text-sm text-destructive">
                  {serverError}
                </p>
              )}
              <Button type="submit" className="w-full" disabled={form.state.isSubmitting}>
                Create Account
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
            <p className="text-muted-foreground">
              Already have an account?{" "}
              <Link href="/sign-in" className="text-foreground underline">
                Sign In
              </Link>
            </p>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
