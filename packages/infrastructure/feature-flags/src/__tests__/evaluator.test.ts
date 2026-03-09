import { describe, expect, it } from "vitest";
import { evaluateFlag, hashToBucket } from "../evaluator";
import type { Flag } from "../types";

describe("evaluateFlag", () => {
  it("returns false when flag is disabled", () => {
    const flag: Flag = { key: "test", enabled: false, rules: {} };
    expect(evaluateFlag(flag)).toBe(false);
  });

  it("returns true when flag is enabled with no rules", () => {
    const flag: Flag = { key: "test", enabled: true, rules: {} };
    expect(evaluateFlag(flag)).toBe(true);
  });

  it("returns true when user is in allowedUserIds", () => {
    const flag: Flag = {
      key: "test",
      enabled: true,
      rules: { allowedUserIds: ["user-1", "user-2"] },
    };
    expect(evaluateFlag(flag, { userId: "user-1" })).toBe(true);
    expect(evaluateFlag(flag, { userId: "user-2" })).toBe(true);
  });

  it("returns false when user is NOT in allowedUserIds", () => {
    const flag: Flag = {
      key: "test",
      enabled: true,
      rules: { allowedUserIds: ["user-1"] },
    };
    expect(evaluateFlag(flag, { userId: "user-99" })).toBe(false);
  });

  it("returns false for allowedUserIds when no userId provided", () => {
    const flag: Flag = {
      key: "test",
      enabled: true,
      rules: { allowedUserIds: ["user-1"] },
    };
    expect(evaluateFlag(flag)).toBe(false);
    expect(evaluateFlag(flag, {})).toBe(false);
  });

  it("produces deterministic results for percentage rollout", () => {
    const flag: Flag = {
      key: "rollout",
      enabled: true,
      rules: { percentage: 50 },
    };
    const result1 = evaluateFlag(flag, { userId: "user-abc" });
    const result2 = evaluateFlag(flag, { userId: "user-abc" });
    expect(result1).toBe(result2);
  });

  it("returns false for percentage when no userId provided", () => {
    const flag: Flag = {
      key: "test",
      enabled: true,
      rules: { percentage: 50 },
    };
    expect(evaluateFlag(flag)).toBe(false);
    expect(evaluateFlag(flag, {})).toBe(false);
  });

  it("returns true for 100% rollout", () => {
    const flag: Flag = {
      key: "test",
      enabled: true,
      rules: { percentage: 100 },
    };
    expect(evaluateFlag(flag, { userId: "anyone" })).toBe(true);
  });

  it("returns false for 0% rollout", () => {
    const flag: Flag = {
      key: "test",
      enabled: true,
      rules: { percentage: 0 },
    };
    expect(evaluateFlag(flag, { userId: "anyone" })).toBe(false);
  });
});

describe("hashToBucket", () => {
  it("returns a value between 0 and 99", () => {
    for (const input of ["a", "b", "test-key-user-123", "flag:uid"]) {
      const bucket = hashToBucket(input);
      expect(bucket).toBeGreaterThanOrEqual(0);
      expect(bucket).toBeLessThan(100);
    }
  });

  it("returns consistent results for the same input", () => {
    expect(hashToBucket("same-input")).toBe(hashToBucket("same-input"));
  });
});
