import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";

import { PhoneFrame } from "@/components/phone-frame";

describe("PhoneFrame", () => {
  it("renders app header", () => {
    render(<PhoneFrame />);
    expect(screen.getByText("Monorepo Template")).toBeTruthy();
  });

  it("renders sign-in title", () => {
    render(<PhoneFrame />);
    expect(screen.getAllByText("Sign In").length).toBeGreaterThan(0);
  });

  it("renders form fields", () => {
    render(<PhoneFrame />);
    expect(screen.getByText("Email")).toBeTruthy();
    expect(screen.getByText("Password")).toBeTruthy();
  });

  it("renders OAuth provider buttons", () => {
    render(<PhoneFrame />);
    expect(screen.getByText("Google")).toBeTruthy();
    expect(screen.getByText("Apple")).toBeTruthy();
    expect(screen.getByText("GitHub")).toBeTruthy();
  });

  it("renders sign-up link", () => {
    render(<PhoneFrame />);
    expect(screen.getByText("Sign Up")).toBeTruthy();
  });

  it("renders status bar time", () => {
    render(<PhoneFrame />);
    expect(screen.getByText("9:41")).toBeTruthy();
  });
});
