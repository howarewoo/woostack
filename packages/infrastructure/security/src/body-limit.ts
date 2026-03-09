import type { MiddlewareHandler } from "hono";
import type { BodyLimitOptions } from "./types";

const DEFAULT_MAX_SIZE = 1_048_576; // 1 MB

/** Create a Hono middleware that rejects requests whose Content-Length exceeds the maximum size. */
export function bodyLimit(options?: BodyLimitOptions): MiddlewareHandler {
  const maxSize = options?.maxSize ?? DEFAULT_MAX_SIZE;

  return async (c, next) => {
    const contentLength = c.req.header("Content-Length");

    if (contentLength) {
      const length = Number.parseInt(contentLength, 10);

      if (!Number.isNaN(length) && length > maxSize) {
        return c.json({ error: "Payload Too Large" }, 413);
      }
    }

    await next();
  };
}
