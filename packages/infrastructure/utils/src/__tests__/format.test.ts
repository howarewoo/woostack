import { describe, expect, it } from "vitest";
import { formatCurrency, truncate } from "../format";

describe("formatCurrency", () => {
  it("should format USD currency", () => {
    expect(formatCurrency(1234.56)).toBe("$1,234.56");
  });

  it("should format EUR currency", () => {
    const result = formatCurrency(1234.56, "EUR", "de-DE");
    expect(result).toContain("1.234,56");
    expect(result).toContain("€");
  });
});

describe("truncate", () => {
  it("should not truncate short strings", () => {
    expect(truncate("Hello", 10)).toBe("Hello");
  });

  it("should truncate long strings with ellipsis", () => {
    expect(truncate("Hello, World!", 10)).toBe("Hello, ...");
  });
});
