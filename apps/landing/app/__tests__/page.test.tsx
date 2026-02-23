import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";

// Mock child components
vi.mock("@/components/hero", () => ({
  Hero: () => <div data-testid="hero">Hero</div>,
}));

vi.mock("@/components/navbar", () => ({
  Navbar: () => <div data-testid="navbar">Navbar</div>,
}));

vi.mock("@/components/footer", () => ({
  Footer: () => <div data-testid="footer">Footer</div>,
}));

vi.mock("@/components/feature-section", () => ({
  FeatureSection: () => <div data-testid="feature-section">FeatureSection</div>,
}));

vi.mock("@/components/logo-bar", () => ({
  TechStackBar: () => <div data-testid="tech-stack-bar">TechStackBar</div>,
}));

vi.mock("@infrastructure/ui-web", () => ({
  Button: ({ children }: { children: React.ReactNode }) => (
    <button type="button">{children}</button>
  ),
  Card: ({ children }: { children: React.ReactNode }) => <div>{children}</div>,
  CardContent: ({ children }: { children: React.ReactNode }) => <div>{children}</div>,
  CardHeader: ({ children }: { children: React.ReactNode }) => <div>{children}</div>,
  CardTitle: ({ children }: { children: React.ReactNode }) => <h3>{children}</h3>,
}));

import LandingPage from "@/app/page";

describe("LandingPage", () => {
  it("renders mission statement", () => {
    render(<LandingPage />);
    expect(screen.getByText("One codebase for web, mobile, and API.")).toBeTruthy();
  });

  it("renders value prop titles", () => {
    render(<LandingPage />);
    expect(screen.getByText("Shared by Default")).toBeTruthy();
    expect(screen.getByText("Type-Safe End to End")).toBeTruthy();
    expect(screen.getByText("Auth & Storage Built In")).toBeTruthy();
  });

  it("renders value prop figure labels", () => {
    render(<LandingPage />);
    expect(screen.getByText("FIG 0.1")).toBeTruthy();
    expect(screen.getByText("FIG 0.2")).toBeTruthy();
    expect(screen.getByText("FIG 0.3")).toBeTruthy();
  });

  it("renders testimonial names", () => {
    render(<LandingPage />);
    expect(screen.getByText("Alex Chen")).toBeTruthy();
    expect(screen.getByText("Sarah Park")).toBeTruthy();
  });

  it("renders CTA buttons", () => {
    render(<LandingPage />);
    const buttons = screen.getAllByText("Get Started");
    expect(buttons.length).toBeGreaterThan(0);
    expect(screen.getAllByText("View on GitHub").length).toBeGreaterThan(0);
  });

  it("renders final CTA section text", () => {
    render(<LandingPage />);
    expect(screen.getByText("Built for the future.")).toBeTruthy();
    expect(screen.getByText("Available today.")).toBeTruthy();
  });
});
