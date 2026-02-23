"use client";

import { render, screen } from "@testing-library/react";
import type React from "react";
import { describe, expect, it, vi } from "vitest";

vi.mock("@infrastructure/navigation", () => ({
  Link: ({ children, ...props }: React.ComponentProps<"a">) => <a {...props}>{children}</a>,
}));

import { SignUpForm } from "../sign-up-form";

describe("SignUpForm", () => {
  it("renders sign-up title", () => {
    render(<SignUpForm />);
    expect(screen.getByText("Sign Up")).toBeDefined();
  });

  it("renders Create Account submit button", () => {
    render(<SignUpForm />);
    expect(screen.getByText("Create Account")).toBeDefined();
  });

  it("renders sign-in link", () => {
    render(<SignUpForm />);
    expect(screen.getByText(/Sign In/)).toBeDefined();
  });
});
