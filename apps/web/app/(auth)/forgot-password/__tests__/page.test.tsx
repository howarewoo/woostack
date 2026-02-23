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
    hidePassword,
  }: {
    title: string;
    submitLabel: string;
    footer?: React.ReactNode;
    hidePassword?: boolean;
  }) => (
    <div data-testid="auth-form">
      <span>{title}</span>
      <span>{submitLabel}</span>
      <span data-testid="hide-password">{String(hidePassword)}</span>
      {footer}
    </div>
  ),
}));

import { ForgotPasswordForm } from "../forgot-password-form";

describe("ForgotPasswordForm", () => {
  it("renders with correct title", () => {
    render(<ForgotPasswordForm />);
    expect(screen.getByText("Forgot Password")).toBeDefined();
  });

  it("hides password field", () => {
    render(<ForgotPasswordForm />);
    expect(screen.getByTestId("hide-password").textContent).toBe("true");
  });

  it("renders back to sign-in link", () => {
    render(<ForgotPasswordForm />);
    expect(screen.getByText(/Sign In/)).toBeDefined();
  });
});
