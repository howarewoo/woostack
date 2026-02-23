"use client";

import { render, screen } from "@testing-library/react";
import type React from "react";
import { describe, expect, it, vi } from "vitest";

vi.mock("@infrastructure/navigation", () => ({
  Link: ({ children, ...props }: React.ComponentProps<"a">) => <a {...props}>{children}</a>,
}));

vi.mock("@/components/auth-form", () => ({
  AuthForm: ({ title, submitLabel }: { title: string; submitLabel: string }) => (
    <div data-testid="auth-form">
      <span>{title}</span>
      <span>{submitLabel}</span>
    </div>
  ),
}));

import { ResetPasswordForm } from "../reset-password-form";

describe("ResetPasswordForm", () => {
  it("renders with correct title", () => {
    render(<ResetPasswordForm />);
    expect(screen.getByText("Reset Password")).toBeDefined();
  });

  it("renders Update Password submit label", () => {
    render(<ResetPasswordForm />);
    expect(screen.getByText("Update Password")).toBeDefined();
  });
});
