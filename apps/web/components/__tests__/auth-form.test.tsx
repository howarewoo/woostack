"use client";

import { fireEvent, render, screen } from "@testing-library/react";
import type React from "react";
import { describe, expect, it, vi } from "vitest";

vi.mock("@infrastructure/ui-web", () => ({
  Button: ({ children, ...props }: React.ComponentProps<"button">) => (
    <button type="button" {...props}>
      {children}
    </button>
  ),
  Card: ({ children }: { children: React.ReactNode }) => <div data-testid="card">{children}</div>,
  CardContent: ({ children }: { children: React.ReactNode }) => <div>{children}</div>,
  CardDescription: ({ children }: { children: React.ReactNode }) => <p>{children}</p>,
  CardHeader: ({ children }: { children: React.ReactNode }) => <div>{children}</div>,
  CardTitle: ({ children }: { children: React.ReactNode }) => <h2>{children}</h2>,
  Input: (props: React.ComponentProps<"input">) => <input {...props} />,
  Label: ({ children, ...props }: React.ComponentProps<"label">) => (
    // biome-ignore lint/a11y/noLabelWithoutControl: test mock — htmlFor passed via props spread
    <label {...props}>{children}</label>
  ),
  Separator: ({ className }: { className?: string }) => <hr className={className} />,
}));

import { AuthForm } from "@/components/auth-form";

describe("AuthForm", () => {
  it("renders title and description", () => {
    render(
      <AuthForm
        title="Sign In"
        description="Welcome back"
        submitLabel="Sign In"
        onSubmit={vi.fn()}
      />
    );
    expect(screen.getByRole("heading", { name: "Sign In" })).toBeDefined();
    expect(screen.getByText("Welcome back")).toBeDefined();
  });

  it("renders email and password fields", () => {
    render(
      <AuthForm
        title="Sign In"
        description="Welcome back"
        submitLabel="Sign In"
        onSubmit={vi.fn()}
      />
    );
    expect(screen.getByLabelText("Email")).toBeDefined();
    expect(screen.getByLabelText("Password")).toBeDefined();
  });

  it("renders submit button with custom label", () => {
    render(
      <AuthForm
        title="Sign Up"
        description="Create an account"
        submitLabel="Create Account"
        onSubmit={vi.fn()}
      />
    );
    expect(screen.getByRole("button", { name: "Create Account" })).toBeDefined();
  });

  it("renders OAuth buttons when showOAuth is true", () => {
    render(
      <AuthForm
        title="Sign In"
        description="Welcome back"
        submitLabel="Sign In"
        onSubmit={vi.fn()}
        showOAuth
        onOAuthClick={vi.fn()}
      />
    );
    expect(screen.getByRole("button", { name: /google/i })).toBeDefined();
    expect(screen.getByRole("button", { name: /apple/i })).toBeDefined();
    expect(screen.getByRole("button", { name: /github/i })).toBeDefined();
  });

  it("does not render OAuth when showOAuth is false", () => {
    render(
      <AuthForm
        title="Sign In"
        description="Welcome back"
        submitLabel="Sign In"
        onSubmit={vi.fn()}
      />
    );
    expect(screen.queryByRole("button", { name: /google/i })).toBeNull();
    expect(screen.queryByRole("button", { name: /apple/i })).toBeNull();
    expect(screen.queryByRole("button", { name: /github/i })).toBeNull();
  });

  it("renders footer when provided", () => {
    render(
      <AuthForm
        title="Sign In"
        description="Welcome back"
        submitLabel="Sign In"
        onSubmit={vi.fn()}
        footer={<span>Already have an account?</span>}
      />
    );
    expect(screen.getByText("Already have an account?")).toBeDefined();
  });

  it("calls onSubmit with email and password on form submit", () => {
    const handleSubmit = vi.fn();
    render(
      <AuthForm
        title="Sign In"
        description="Welcome back"
        submitLabel="Sign In"
        onSubmit={handleSubmit}
      />
    );

    fireEvent.change(screen.getByLabelText("Email"), {
      target: { value: "test@example.com" },
    });
    fireEvent.change(screen.getByLabelText("Password"), {
      target: { value: "secret123" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Sign In" }));

    expect(handleSubmit).toHaveBeenCalledWith("test@example.com", "secret123");
  });

  it("displays error message when provided", () => {
    render(
      <AuthForm
        title="Sign In"
        description="Welcome back"
        submitLabel="Sign In"
        onSubmit={vi.fn()}
        error="Invalid credentials"
      />
    );
    expect(screen.getByText("Invalid credentials")).toBeDefined();
  });

  it("disables submit button when loading", () => {
    render(
      <AuthForm
        title="Sign In"
        description="Welcome back"
        submitLabel="Sign In"
        onSubmit={vi.fn()}
        isLoading
      />
    );
    const submitButton = screen.getByRole("button", { name: "Sign In" });
    expect(submitButton).toBeDefined();
    expect((submitButton as HTMLButtonElement).disabled).toBe(true);
  });
});
