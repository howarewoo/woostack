import { describe, expect, it } from "vitest";
import {
  forgotPasswordSchema,
  resetPasswordSchema,
  signInSchema,
  signUpSchema,
} from "../authSchemas";

describe("signInSchema", () => {
  it("accepts valid email and password", () => {
    const result = signInSchema.safeParse({ email: "user@example.com", password: "pass123" });
    expect(result.success).toBe(true);
  });

  it("rejects invalid email", () => {
    const result = signInSchema.safeParse({ email: "not-an-email", password: "pass123" });
    expect(result.success).toBe(false);
  });

  it("rejects empty password", () => {
    const result = signInSchema.safeParse({ email: "user@example.com", password: "" });
    expect(result.success).toBe(false);
  });
});

describe("signUpSchema", () => {
  it("accepts valid email and strong password", () => {
    const result = signUpSchema.safeParse({ email: "user@example.com", password: "longpass8" });
    expect(result.success).toBe(true);
  });

  it("rejects password shorter than 8 characters", () => {
    const result = signUpSchema.safeParse({ email: "user@example.com", password: "short" });
    expect(result.success).toBe(false);
  });

  it("rejects invalid email", () => {
    const result = signUpSchema.safeParse({ email: "bad", password: "longpass8" });
    expect(result.success).toBe(false);
  });
});

describe("forgotPasswordSchema", () => {
  it("accepts valid email", () => {
    const result = forgotPasswordSchema.safeParse({ email: "user@example.com" });
    expect(result.success).toBe(true);
  });

  it("rejects invalid email", () => {
    const result = forgotPasswordSchema.safeParse({ email: "nope" });
    expect(result.success).toBe(false);
  });
});

describe("resetPasswordSchema", () => {
  it("accepts matching passwords", () => {
    const result = resetPasswordSchema.safeParse({
      password: "newpass88",
      confirmPassword: "newpass88",
    });
    expect(result.success).toBe(true);
  });

  it("rejects mismatched passwords", () => {
    const result = resetPasswordSchema.safeParse({
      password: "newpass88",
      confirmPassword: "different",
    });
    expect(result.success).toBe(false);
  });

  it("rejects short password", () => {
    const result = resetPasswordSchema.safeParse({
      password: "short",
      confirmPassword: "short",
    });
    expect(result.success).toBe(false);
  });
});
