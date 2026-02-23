import { z } from "zod";

/** Schema for sign-in form: email + password (any length). */
export const SignInSchema = z.object({
  email: z.email("Please enter a valid email"),
  password: z.string().min(1, "Password is required"),
});

export type SignInValues = z.infer<typeof SignInSchema>;

/** Schema for sign-up form: email + password (8–128 characters). */
export const SignUpSchema = z.object({
  email: z.email("Please enter a valid email"),
  password: z
    .string()
    .min(8, "Password must be at least 8 characters")
    .max(128, "Password must be at most 128 characters"),
});

export type SignUpValues = z.infer<typeof SignUpSchema>;

/** Schema for forgot-password form: email only. */
export const ForgotPasswordSchema = z.object({
  email: z.email("Please enter a valid email"),
});

export type ForgotPasswordValues = z.infer<typeof ForgotPasswordSchema>;

/** Schema for reset-password form: password (8–128 chars) + confirmPassword must match. */
export const ResetPasswordSchema = z
  .object({
    password: z
      .string()
      .min(8, "Password must be at least 8 characters")
      .max(128, "Password must be at most 128 characters"),
    confirmPassword: z.string().min(1, "Please confirm your password"),
  })
  .refine((data) => data.password === data.confirmPassword, {
    message: "Passwords don't match",
    path: ["confirmPassword"],
  });

export type ResetPasswordValues = z.infer<typeof ResetPasswordSchema>;
