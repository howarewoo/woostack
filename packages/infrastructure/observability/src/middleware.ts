import type { MiddlewareHandler } from "hono";
import type { Logger } from "pino";

declare module "hono" {
  interface ContextVariableMap {
    requestId: string;
  }
}

interface OtelMiddlewareOptions {
  /** Pino logger instance used for request logging */
  logger: Logger;
}

/**
 * Hono middleware that adds request-level observability:
 *
 * 1. Generates or reuses a request ID (`x-request-id` header)
 * 2. Sets the request ID on the Hono context and response header
 * 3. Logs method, path, status, and duration after the response completes
 */
export function otelMiddleware({ logger }: OtelMiddlewareOptions): MiddlewareHandler {
  return async (c, next) => {
    const requestId = c.req.header("x-request-id") || crypto.randomUUID();
    c.set("requestId", requestId);
    c.header("x-request-id", requestId);

    const start = performance.now();

    try {
      await next();
    } finally {
      const duration = Math.round(performance.now() - start);

      const MAX_PATH_LOG_LENGTH = 256;
      const logPath =
        c.req.path.length > MAX_PATH_LOG_LENGTH
          ? `${c.req.path.slice(0, MAX_PATH_LOG_LENGTH)}...[truncated]`
          : c.req.path;

      logger.info(
        {
          requestId,
          method: c.req.method,
          path: logPath,
          status: c.res.status,
          duration,
        },
        "request completed"
      );
    }
  };
}
