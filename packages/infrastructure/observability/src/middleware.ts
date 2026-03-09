import type { Logger } from "pino";
import type { MiddlewareHandler } from "hono";

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

    await next();

    const duration = Math.round(performance.now() - start);

    logger.info(
      {
        requestId,
        method: c.req.method,
        path: c.req.path,
        status: c.res.status,
        duration,
      },
      "request completed"
    );
  };
}
