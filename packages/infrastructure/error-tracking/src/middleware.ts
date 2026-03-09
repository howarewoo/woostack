import type { Context, ErrorHandler } from "hono";
import type { ErrorReporter } from "./types";

/** Options for the error boundary. */
export interface ErrorBoundaryOptions {
  /** The error reporter to use for capturing unhandled errors. */
  reporter: ErrorReporter;
}

/** Create a Hono onError handler that reports errors and returns structured JSON. */
export function createErrorBoundary(options: ErrorBoundaryOptions): ErrorHandler {
  const { reporter } = options;

  return (thrown: Error, c: Context) => {
    const error = thrown instanceof Error ? thrown : new Error(String(thrown));
    const requestId: string | undefined = c.get("requestId");

    reporter.captureException(error, {
      requestId,
      method: c.req.method,
      path: c.req.path,
    });

    return c.json(
      {
        error: {
          message: "Internal Server Error",
          ...(requestId ? { requestId } : {}),
        },
      },
      500
    );
  };
}
