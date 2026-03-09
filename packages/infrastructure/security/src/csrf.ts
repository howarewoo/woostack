import type { MiddlewareHandler } from "hono";
import type { CsrfProtectionOptions } from "./types";

const STATE_CHANGING_METHODS = new Set(["POST", "PUT", "PATCH", "DELETE"]);

/**
 * Create a Hono middleware that validates the Origin or Referer header
 * on state-changing requests (POST, PUT, PATCH, DELETE) against a list
 * of allowed origins.
 */
export function csrfProtection(options: CsrfProtectionOptions): MiddlewareHandler {
  const allowedOrigins = new Set(options.allowedOrigins.map((origin) => origin.replace(/\/$/, "")));

  return async (c, next) => {
    if (!STATE_CHANGING_METHODS.has(c.req.method)) {
      await next();
      return;
    }

    const origin = c.req.header("Origin");
    const referer = c.req.header("Referer");

    let requestOrigin: string | null = null;

    if (origin) {
      requestOrigin = origin.replace(/\/$/, "");
    } else if (referer) {
      try {
        const url = new URL(referer);
        requestOrigin = url.origin;
      } catch {
        requestOrigin = null;
      }
    }

    if (!requestOrigin || !allowedOrigins.has(requestOrigin)) {
      return c.json({ error: "Forbidden" }, 403);
    }

    await next();
  };
}
