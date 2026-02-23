import { render, screen } from "@testing-library/react";
import type { ReactNode } from "react";
import { describe, expect, it, vi } from "vitest";

vi.mock("@infrastructure/ui-web", () => ({
  Button: ({ children }: { children: ReactNode }) => <button type="button">{children}</button>,
}));

import { Hero } from "@/components/hero";

describe("Hero", () => {
  it("renders headline text", () => {
    render(<Hero />);
    expect(screen.getByText("The modern monorepo")).toBeTruthy();
    expect(screen.getByText("template")).toBeTruthy();
  });

  it("renders subtitle", () => {
    render(<Hero />);
    expect(screen.getByText(/Ship web, mobile, and API from a single codebase/)).toBeTruthy();
    expect(screen.getByText(/Authentication, database, and storage/)).toBeTruthy();
  });

  it("renders announcement badge", () => {
    render(<Hero />);
    expect(screen.getByText("Now with Supabase Auth, Database & Storage")).toBeTruthy();
  });

  it("renders CTA buttons", () => {
    render(<Hero />);
    expect(screen.getAllByText("Get Started")).toHaveLength(1);
    expect(screen.getAllByText("View on GitHub")).toHaveLength(1);
  });

  it("renders browser frame content", () => {
    render(<Hero />);
    expect(screen.getByText("localhost:3000")).toBeTruthy();
  });

  it("renders phone frame content", () => {
    render(<Hero />);
    expect(screen.getAllByText("Monorepo Template")).toHaveLength(2);
  });
});
