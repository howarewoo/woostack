"use client";

import { render, screen } from "@testing-library/react";
import type React from "react";
import { describe, expect, it, vi } from "vitest";

vi.mock("@infrastructure/supabase/auth", () => ({
  useAuth: () => ({
    signOut: vi.fn(),
    user: {
      id: "abc-123",
      email: "test@example.com",
      created_at: "2026-01-15T10:30:00Z",
    },
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

import { SettingsContent } from "../settings-content";

describe("SettingsContent", () => {
  it("renders Settings heading", () => {
    render(
      <SettingsContent email="test@example.com" userId="abc-123" createdAt="2026-01-15T10:30:00Z" />
    );
    expect(screen.getByText("Settings")).toBeDefined();
  });

  it("renders user email", () => {
    render(
      <SettingsContent email="test@example.com" userId="abc-123" createdAt="2026-01-15T10:30:00Z" />
    );
    expect(screen.getByText("test@example.com")).toBeDefined();
  });

  it("renders user ID", () => {
    render(
      <SettingsContent email="test@example.com" userId="abc-123" createdAt="2026-01-15T10:30:00Z" />
    );
    expect(screen.getByText(/abc-123/)).toBeDefined();
  });

  it("renders sign out button", () => {
    render(
      <SettingsContent email="test@example.com" userId="abc-123" createdAt="2026-01-15T10:30:00Z" />
    );
    expect(screen.getByText("Sign Out")).toBeDefined();
  });

  it("renders back to dashboard link", () => {
    render(
      <SettingsContent email="test@example.com" userId="abc-123" createdAt="2026-01-15T10:30:00Z" />
    );
    expect(screen.getByText(/Dashboard/)).toBeDefined();
  });
});
