"use client";

import { ForgotPasswordSchema } from "@features/auth";
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

/** Client-side forgot-password form that sends a password reset email. */
export function ForgotPasswordForm() {
  const [serverError, setServerError] = useState("");
  const [sent, setSent] = useState(false);

  const form = useForm({
    defaultValues: { email: "" },
    validators: {
      onBlur: ForgotPasswordSchema,
      onSubmit: ForgotPasswordSchema,
    },
    onSubmit: async ({ value: _value }) => {
      setServerError("");
      try {
        // TODO: Implement password reset email (e.g. supabase.auth.resetPasswordForEmail(email))
        toast.info("TODO: Implement password reset email");
        setSent(true);
      } catch (err) {
        setServerError(err instanceof Error ? err.message : "Failed to send reset email");
      }
    },
  });

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
    <div className="min-h-screen flex items-center justify-center">
      <Card className="w-full max-w-md">
        <CardHeader>
          <CardTitle className="text-2xl">Forgot Password</CardTitle>
          <CardDescription>Enter your email to receive a password reset link</CardDescription>
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
              {serverError && (
                <p role="alert" className="text-sm text-destructive">
                  {serverError}
                </p>
              )}
              <Button type="submit" className="w-full" disabled={form.state.isSubmitting}>
                Send Reset Link
              </Button>
            </div>
          </form>
          <div className="mt-4 text-center text-sm">
            <Link href="/sign-in" className="text-muted-foreground hover:text-foreground">
              Back to Sign In
            </Link>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
