"use client";

import { resetPasswordSchema } from "@features/auth";
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

/** Client-side reset-password form for setting a new password. */
export function ResetPasswordForm() {
  const [serverError, setServerError] = useState("");

  const form = useForm({
    defaultValues: { password: "", confirmPassword: "" },
    validators: {
      onBlur: resetPasswordSchema,
      onSubmit: resetPasswordSchema,
    },
    onSubmit: async ({ value: _value }) => {
      setServerError("");
      try {
        // TODO: Implement password reset logic (e.g. supabase.auth.updateUser({ password }))
        toast.info("TODO: Implement password reset logic");
      } catch (err) {
        setServerError(err instanceof Error ? err.message : "Failed to reset password");
      }
    },
  });

  return (
    <div className="min-h-screen flex items-center justify-center">
      <Card className="w-full max-w-md">
        <CardHeader>
          <CardTitle className="text-2xl">Reset Password</CardTitle>
          <CardDescription>Enter your new password</CardDescription>
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
                name="password"
                children={(field) => {
                  const isInvalid = field.state.meta.isTouched && !field.state.meta.isValid;
                  return (
                    <Field data-invalid={isInvalid}>
                      <FieldLabel htmlFor={field.name}>New Password</FieldLabel>
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
              <form.Field
                name="confirmPassword"
                children={(field) => {
                  const isInvalid = field.state.meta.isTouched && !field.state.meta.isValid;
                  return (
                    <Field data-invalid={isInvalid}>
                      <FieldLabel htmlFor={field.name}>Confirm Password</FieldLabel>
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
              {serverError && <p className="text-sm text-destructive">{serverError}</p>}
              <Button type="submit" className="w-full" disabled={form.state.isSubmitting}>
                Update Password
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
