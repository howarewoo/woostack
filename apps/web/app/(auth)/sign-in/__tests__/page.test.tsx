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

import { SignInForm } from "../sign-in-form";

describe("SignInForm", () => {
  it("renders sign-in title and submit button", () => {
    render(<SignInForm />);
    const matches = screen.getAllByText("Sign In");
    expect(matches.length).toBe(2);
    expect(screen.getByRole("button", { name: "Sign In" })).toBeDefined();
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
