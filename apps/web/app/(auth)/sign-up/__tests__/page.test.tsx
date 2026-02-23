"use client";

import { render, screen } from "@testing-library/react";
import type React from "react";
import { describe, expect, it, vi } from "vitest";

vi.mock("@infrastructure/navigation", () => ({
  Link: ({ children, ...props }: React.ComponentProps<"a">) => <a {...props}>{children}</a>,
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
      <span>{title}</span>
      <span>{submitLabel}</span>
      {footer}
    </div>
  ),
}));

import { SignUpForm } from "../sign-up-form";

describe("SignUpForm", () => {
  it("renders AuthForm with sign-up title", () => {
    render(<SignUpForm />);
    expect(screen.getByText("Sign Up")).toBeDefined();
  });

  it("renders Create Account submit label", () => {
    render(<SignUpForm />);
    expect(screen.getByText("Create Account")).toBeDefined();
  });

  it("renders sign-in link", () => {
    render(<SignUpForm />);
    expect(screen.getByText(/Sign In/)).toBeDefined();
  });
});
