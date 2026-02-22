import { describe, expect, it } from "vitest";
import { assertDefined, isDefined, isValidEmail } from "../validation";

describe("isValidEmail", () => {
  it("should validate correct email", () => {
    expect(isValidEmail("test@example.com")).toBe(true);
  });

  it("should reject invalid email", () => {
    expect(isValidEmail("invalid-email")).toBe(false);
    expect(isValidEmail("@example.com")).toBe(false);
    expect(isValidEmail("test@")).toBe(false);
  });
});

describe("isDefined", () => {
  it("should return true for defined values", () => {
    expect(isDefined("hello")).toBe(true);
    expect(isDefined(0)).toBe(true);
    expect(isDefined(false)).toBe(true);
  });

  it("should return false for null and undefined", () => {
    expect(isDefined(null)).toBe(false);
    expect(isDefined(undefined)).toBe(false);
  });
});

describe("assertDefined", () => {
  it("should not throw for defined values", () => {
    expect(() => assertDefined("hello")).not.toThrow();
  });

  it("should throw for null", () => {
    expect(() => assertDefined(null)).toThrow("Value is null or undefined");
  });

  it("should throw with custom message", () => {
    expect(() => assertDefined(undefined, "Custom error")).toThrow("Custom error");
  });
});
