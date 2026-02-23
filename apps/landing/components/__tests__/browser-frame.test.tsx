import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";

import { BrowserFrame } from "@/components/browser-frame";

describe("BrowserFrame", () => {
  it("renders URL bar with localhost:3000", () => {
    render(<BrowserFrame />);
    expect(screen.getByText("localhost:3000")).toBeTruthy();
  });

  it("renders welcome message", () => {
    render(<BrowserFrame />);
    expect(screen.getByText("Welcome back")).toBeTruthy();
  });

  it("renders user email", () => {
    render(<BrowserFrame />);
    expect(screen.getAllByText("user@email.com").length).toBeGreaterThan(0);
  });

  it("renders sign out button", () => {
    render(<BrowserFrame />);
    expect(screen.getByText("Sign Out")).toBeTruthy();
  });

  it("renders users from API card", () => {
    render(<BrowserFrame />);
    expect(screen.getByText("Users from API")).toBeTruthy();
    expect(screen.getByText("Alex Chen")).toBeTruthy();
    expect(screen.getByText("Sarah Park")).toBeTruthy();
  });

  it("renders infrastructure badges including supabase", () => {
    render(<BrowserFrame />);
    expect(screen.getByText("api-client")).toBeTruthy();
    expect(screen.getByText("supabase")).toBeTruthy();
    expect(screen.getByText("ui-web")).toBeTruthy();
  });

  it("renders tooling badges", () => {
    render(<BrowserFrame />);
    expect(screen.getByText("Turborepo")).toBeTruthy();
    expect(screen.getByText("Biome")).toBeTruthy();
    expect(screen.getByText("Vitest")).toBeTruthy();
  });
});
