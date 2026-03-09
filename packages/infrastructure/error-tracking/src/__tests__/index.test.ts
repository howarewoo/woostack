import { afterEach, describe, expect, it, vi } from "vitest";
import { reportError, reportMessage } from "../index";

describe("reportError", () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("logs the error to console.error via the default ConsoleReporter", () => {
    vi.spyOn(console, "error").mockImplementation(() => {});

    reportError(new Error("convenience test"), { requestId: "req-conv" });

    expect(console.error).toHaveBeenCalledOnce();
    const call = vi.mocked(console.error).mock.calls[0]!;
    expect(call[0]).toBe("[ErrorTracking]");
    const parsed = JSON.parse(call[1] as string);
    expect(parsed.message).toBe("convenience test");
    expect(parsed.requestId).toBe("req-conv");
  });
});

describe("reportMessage", () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("logs a message to console via the default ConsoleReporter", () => {
    vi.spyOn(console, "warn").mockImplementation(() => {});

    reportMessage("something happened", "warning");

    expect(console.warn).toHaveBeenCalledOnce();
    const json = vi.mocked(console.warn).mock.calls[0]![1] as string;
    const parsed = JSON.parse(json);
    expect(parsed.message).toBe("something happened");
    expect(parsed.level).toBe("warning");
  });
});
