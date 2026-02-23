import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { Field, FieldError, FieldLabel } from "../index";

describe("Field", () => {
  it("renders children", () => {
    render(<Field>field content</Field>);
    expect(screen.getByText("field content")).toBeDefined();
  });

  it("sets data-invalid attribute", () => {
    render(<Field data-invalid={true}>content</Field>);
    const field = screen.getByRole("group");
    expect(field.getAttribute("data-invalid")).toBe("true");
  });
});

describe("FieldLabel", () => {
  it("renders label text", () => {
    render(<FieldLabel>Email</FieldLabel>);
    expect(screen.getByText("Email")).toBeDefined();
  });

  it("associates with input via htmlFor", () => {
    render(<FieldLabel htmlFor="email-input">Email</FieldLabel>);
    const label = screen.getByText("Email");
    expect(label.getAttribute("for")).toBe("email-input");
  });
});

describe("FieldError", () => {
  it("renders nothing when no errors", () => {
    const { container } = render(<FieldError errors={[]} />);
    expect(container.innerHTML).toBe("");
  });

  it("renders single error message", () => {
    render(<FieldError errors={[{ message: "Required" }]} />);
    expect(screen.getByText("Required")).toBeDefined();
  });

  it("renders multiple error messages as list", () => {
    render(<FieldError errors={[{ message: "Too short" }, { message: "Must contain number" }]} />);
    expect(screen.getByText("Too short")).toBeDefined();
    expect(screen.getByText("Must contain number")).toBeDefined();
  });

  it("has role=alert for accessibility", () => {
    render(<FieldError errors={[{ message: "Error" }]} />);
    expect(screen.getByRole("alert")).toBeDefined();
  });
});
