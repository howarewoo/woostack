"use client";

import {
  Button,
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
  Input,
  Label,
} from "@infrastructure/ui-web";
import { type ReactNode, useState } from "react";

interface AuthFormProps {
  title: string;
  description: string;
  submitLabel: string;
  onSubmit: (email: string, password: string) => void;
  showOAuth?: boolean;
  onOAuthClick?: (provider: "google" | "apple" | "github") => void;
  footer?: ReactNode;
  error?: string;
  isLoading?: boolean;
  hidePassword?: boolean;
  defaultEmail?: string;
  defaultPassword?: string;
  disabled?: boolean;
}

/** Reusable authentication form supporting sign-in, sign-up, forgot-password, and reset-password flows via props. */
export function AuthForm({
  title,
  description,
  submitLabel,
  onSubmit,
  showOAuth,
  onOAuthClick,
  footer,
  error,
  isLoading,
  hidePassword,
  defaultEmail = "",
  defaultPassword = "",
  disabled,
}: AuthFormProps) {
  const [email, setEmail] = useState(defaultEmail);
  const [password, setPassword] = useState(defaultPassword);

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    onSubmit(email, password);
  }

  return (
    <div className="min-h-screen flex items-center justify-center">
      <Card className="w-full max-w-md">
        <CardHeader>
          <CardTitle className="text-2xl">{title}</CardTitle>
          <CardDescription>{description}</CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit}>
            <div className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="email">Email</Label>
                <Input
                  id="email"
                  type="email"
                  placeholder="you@example.com"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  disabled={disabled}
                />
              </div>
              {!hidePassword && (
                <div className="space-y-2">
                  <Label htmlFor="password">Password</Label>
                  <Input
                    id="password"
                    type="password"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    disabled={disabled}
                  />
                </div>
              )}
              {error && <p className="text-sm text-destructive">{error}</p>}
              <Button type="submit" className="w-full" disabled={isLoading}>
                {submitLabel}
              </Button>
            </div>
          </form>
          {showOAuth && (
            <div className="mt-4 space-y-4">
              <div className="relative justify-center flex">
                <span className="bg-card px-2 text-xs text-muted-foreground">Or continue with</span>
              </div>
              <div className="grid grid-cols-3 gap-2">
                <Button
                  variant="outline"
                  aria-label="Continue with Google"
                  onClick={() => onOAuthClick?.("google")}
                >
                  Google
                </Button>
                <Button
                  variant="outline"
                  aria-label="Continue with Apple"
                  onClick={() => onOAuthClick?.("apple")}
                >
                  Apple
                </Button>
                <Button
                  variant="outline"
                  aria-label="Continue with GitHub"
                  onClick={() => onOAuthClick?.("github")}
                >
                  GitHub
                </Button>
              </div>
            </div>
          )}
          {footer && <div className="mt-4 text-center text-sm">{footer}</div>}
        </CardContent>
      </Card>
    </div>
  );
}
