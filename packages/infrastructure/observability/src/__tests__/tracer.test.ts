import { describe, expect, it } from "vitest";
import { getTracer, withSpan } from "../tracer";

describe("getTracer", () => {
  it("returns a Tracer instance", () => {
    const tracer = getTracer();
    expect(tracer).toBeDefined();
    expect(typeof tracer.startActiveSpan).toBe("function");
    expect(typeof tracer.startSpan).toBe("function");
  });

  it("accepts a custom tracer name", () => {
    const tracer = getTracer("custom");
    expect(tracer).toBeDefined();
  });
});

describe("withSpan", () => {
  it("returns the function's result", async () => {
    const result = await withSpan("test-span", async () => 42);
    expect(result).toBe(42);
  });

  it("re-throws on error", async () => {
    await expect(
      withSpan("error-span", async () => {
        throw new Error("boom");
      })
    ).rejects.toThrow("boom");
  });
});
