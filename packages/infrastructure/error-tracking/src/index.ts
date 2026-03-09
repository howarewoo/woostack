import { ConsoleReporter } from "./console-reporter";
import type { ErrorContext, ErrorLevel } from "./types";

export { ConsoleReporter } from "./console-reporter";
export type { ErrorBoundaryOptions } from "./middleware";
export { createErrorBoundary } from "./middleware";
export type { ErrorContext, ErrorLevel, ErrorReporter } from "./types";

const defaultReporter = new ConsoleReporter();

/** Convenience function to report an error using the default ConsoleReporter. */
export function reportError(error: Error, context?: ErrorContext): void {
  defaultReporter.captureException(error, context);
}

/** Convenience function to report a message using the default ConsoleReporter. */
export function reportMessage(message: string, level?: ErrorLevel, context?: ErrorContext): void {
  defaultReporter.captureMessage(message, level, context);
}
