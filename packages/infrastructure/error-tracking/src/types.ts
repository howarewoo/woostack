/** Additional context attached to error reports. */
export interface ErrorContext {
  /** Unique identifier for the request that triggered the error. */
  requestId?: string;
  /** Arbitrary key-value metadata to include in the report. */
  [key: string]: string | number | boolean | undefined;
}

/** Severity level for captured messages. */
export type ErrorLevel = "info" | "warning" | "error" | "fatal";

/** Interface for error reporting adapters (e.g. Sentry, Datadog, console). */
export interface ErrorReporter {
  /** Report an exception with optional context. */
  captureException(error: Error, context?: ErrorContext): void;
  /** Report a message at a given severity level with optional context. */
  captureMessage(message: string, level?: ErrorLevel, context?: ErrorContext): void;
}
