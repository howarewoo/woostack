"use client";

import { render, screen } from "@testing-library/react";
import type React from "react";
import { describe, expect, it, vi } from "vitest";

vi.mock("@infrastructure/navigation", () => ({
  Link: ({ children, ...props }: React.ComponentProps<"a">) => <a {...props}>{children}</a>,
}));

import { ForgotPasswordForm } from "../forgot-password-form";

describe("ForgotPasswordForm", () => {
  it("renders with correct title", () => {
    render(<ForgotPasswordForm />);
    expect(screen.getByText("Forgot Password")).toBeDefined();
  });

  it("does not render a password field", () => {
    render(<ForgotPasswordForm />);
    expect(screen.queryByLabelText(/password/i)).toBeNull();
  });

  it("renders back to sign-in link", () => {
    render(<ForgotPasswordForm />);
    expect(screen.getByText(/Sign In/)).toBeDefined();
  });
});
