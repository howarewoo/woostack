import type { ErrorContext, ErrorLevel, ErrorReporter } from "./types";

/** Default error reporter that logs to the console with structured context. */
export class ConsoleReporter implements ErrorReporter {
  /** Report an exception to console.error with optional context. */
  captureException(error: Error, context?: ErrorContext): void {
    const entry = {
      type: "exception",
      message: error.message,
      stack: error.stack,
      ...context,
    };
    console.error("[ErrorTracking]", JSON.stringify(entry));
  }

  /** Report a message to the console at the appropriate log level. */
  captureMessage(message: string, level: ErrorLevel = "error", context?: ErrorContext): void {
    const entry = {
      type: "message",
      level,
      message,
      ...context,
    };

    switch (level) {
      case "info":
        console.info("[ErrorTracking]", JSON.stringify(entry));
        break;
      case "warning":
        console.warn("[ErrorTracking]", JSON.stringify(entry));
        break;
      case "fatal":
      case "error":
      default:
        console.error("[ErrorTracking]", JSON.stringify(entry));
        break;
    }
  }
}
