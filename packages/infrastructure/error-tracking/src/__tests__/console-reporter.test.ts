import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { ConsoleReporter } from "../console-reporter";

describe("ConsoleReporter", () => {
  let reporter: ConsoleReporter;

  beforeEach(() => {
    reporter = new ConsoleReporter();
    vi.spyOn(console, "error").mockImplementation(() => {});
    vi.spyOn(console, "warn").mockImplementation(() => {});
    vi.spyOn(console, "info").mockImplementation(() => {});
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  describe("captureException", () => {
    it("logs error with message and stack to console.error", () => {
      const error = new Error("test error");
      reporter.captureException(error);

      expect(console.error).toHaveBeenCalledOnce();
      const call = vi.mocked(console.error).mock.calls[0]!;
      expect(call[0]).toBe("[ErrorTracking]");
      const parsed = JSON.parse(call[1] as string);
      expect(parsed.type).toBe("exception");
      expect(parsed.message).toBe("test error");
      expect(parsed.stack).toBeDefined();
    });

    it("includes context in the log entry", () => {
      const error = new Error("ctx error");
      reporter.captureException(error, { requestId: "req-123", userId: 42 });

      const call = vi.mocked(console.error).mock.calls[0]!;
      const json = call[1] as string;
      const parsed = JSON.parse(json);
      expect(parsed.requestId).toBe("req-123");
      expect(parsed.userId).toBe(42);
    });
  });

  describe("captureMessage", () => {
    it("logs to console.error by default", () => {
      reporter.captureMessage("something broke");

      expect(console.error).toHaveBeenCalledOnce();
      const json = vi.mocked(console.error).mock.calls[0]![1] as string;
      const parsed = JSON.parse(json);
      expect(parsed.type).toBe("message");
      expect(parsed.level).toBe("error");
      expect(parsed.message).toBe("something broke");
    });

    it("logs to console.info for info level", () => {
      reporter.captureMessage("info msg", "info");

      expect(console.info).toHaveBeenCalledOnce();
      const json = vi.mocked(console.info).mock.calls[0]![1] as string;
      const parsed = JSON.parse(json);
      expect(parsed.level).toBe("info");
    });

    it("logs to console.warn for warning level", () => {
      reporter.captureMessage("warn msg", "warning");

      expect(console.warn).toHaveBeenCalledOnce();
      const json = vi.mocked(console.warn).mock.calls[0]![1] as string;
      const parsed = JSON.parse(json);
      expect(parsed.level).toBe("warning");
    });

    it("logs to console.error for fatal level", () => {
      reporter.captureMessage("fatal msg", "fatal");

      expect(console.error).toHaveBeenCalledOnce();
      const json = vi.mocked(console.error).mock.calls[0]![1] as string;
      const parsed = JSON.parse(json);
      expect(parsed.level).toBe("fatal");
    });

    it("includes context in the log entry", () => {
      reporter.captureMessage("msg", "error", { requestId: "req-456" });

      const json = vi.mocked(console.error).mock.calls[0]![1] as string;
      const parsed = JSON.parse(json);
      expect(parsed.requestId).toBe("req-456");
    });
  });
});
