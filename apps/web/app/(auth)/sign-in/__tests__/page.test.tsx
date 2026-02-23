"use client";

import { render, screen } from "@testing-library/react";
import type React from "react";
import { describe, expect, it, vi } from "vitest";

const mockSignIn = vi.fn();
const mockSignInWithOAuth = vi.fn();

vi.mock("@infrastructure/supabase/auth", () => ({
  useAuth: () => ({
    signIn: mockSignIn,
    signInWithOAuth: mockSignInWithOAuth,
    isLoading: false,
    session: null,
    user: null,
    signUp: vi.fn(),
    signOut: vi.fn(),
  }),
}));

vi.mock("@infrastructure/navigation", () => ({
  Link: ({ children, ...props }: React.ComponentProps<"a">) => <a {...props}>{children}</a>,
  useNavigation: () => ({
    navigate: vi.fn(),
    replace: vi.fn(),
    back: vi.fn(),
  }),
}));

vi.mock("@/components/auth-form", () => ({
  AuthForm: ({
    title,
    submitLabel,
    footer,
  }: {
    title: string;
    submitLabel: string;
    footer?: React.ReactNode;
  }) => (
    <div data-testid="auth-form">
      <span data-testid="auth-title">{title}</span>
      <span data-testid="auth-submit">{submitLabel}</span>
      {footer}
    </div>
  ),
}));

import { SignInForm } from "../sign-in-form";

describe("SignInForm", () => {
  it("renders AuthForm with sign-in title", () => {
    render(<SignInForm />);
    expect(screen.getByTestId("auth-title").textContent).toBe("Sign In");
  });

  it("renders sign-up link", () => {
    render(<SignInForm />);
    expect(screen.getByText(/Sign Up/)).toBeDefined();
  });

  it("renders forgot password link", () => {
    render(<SignInForm />);
    expect(screen.getByText(/Forgot password/i)).toBeDefined();
  });
});
