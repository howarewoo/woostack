"use client";

import { render, screen } from "@testing-library/react";
import type React from "react";
import { describe, expect, it, vi } from "vitest";

vi.mock("@infrastructure/supabase/auth", () => ({
  useAuth: () => ({
    signOut: vi.fn(),
    user: { id: "123", email: "test@example.com" },
    isLoading: false,
    session: {},
    signIn: vi.fn(),
    signUp: vi.fn(),
    signInWithOAuth: vi.fn(),
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

vi.mock("@infrastructure/ui-web", () => ({
  Button: ({ children, ...props }: React.ComponentProps<"button">) => (
    <button type="button" {...props}>
      {children}
    </button>
  ),
  Card: ({ children }: { children: React.ReactNode }) => <div>{children}</div>,
  CardContent: ({ children }: { children: React.ReactNode }) => <div>{children}</div>,
  CardDescription: ({ children }: { children: React.ReactNode }) => <p>{children}</p>,
  CardHeader: ({ children }: { children: React.ReactNode }) => <div>{children}</div>,
  CardTitle: ({ children }: { children: React.ReactNode }) => <h3>{children}</h3>,
}));

vi.mock("@/components/user-list", () => ({
  UserList: () => <div data-testid="user-list">Mocked UserList</div>,
}));

import { DashboardContent } from "../dashboard-content";

describe("DashboardContent", () => {
  it("renders welcome message with user email", () => {
    render(<DashboardContent email="test@example.com" />);
    expect(screen.getByText(/Welcome back/)).toBeDefined();
    expect(screen.getAllByText(/test@example.com/).length).toBeGreaterThan(0);
  });

  it("renders user avatar with first letter of email", () => {
    render(<DashboardContent email="test@example.com" />);
    expect(screen.getByText("t")).toBeDefined();
  });

  it("renders sign out button", () => {
    render(<DashboardContent email="test@example.com" />);
    expect(screen.getByText("Sign Out")).toBeDefined();
  });

  it("renders settings link", () => {
    render(<DashboardContent email="test@example.com" />);
    expect(screen.getByText("Settings")).toBeDefined();
  });

  it("renders UserList component", () => {
    render(<DashboardContent email="test@example.com" />);
    expect(screen.getByTestId("user-list")).toBeDefined();
  });
});
