import type { MiddlewareHandler } from "hono";
import { MemoryStore } from "./memory-store";
import type { RateLimitOptions } from "./types";

/** Default rate limit window duration in milliseconds (1 minute). */
const DEFAULT_WINDOW_MS = 60_000;

/** Default maximum number of requests per window. */
const DEFAULT_MAX_REQUESTS = 100;

/**
 * Create a Hono rate limiter middleware.
 *
 * The default key generator extracts the client IP from the `X-Forwarded-For`
 * header (first entry), then `X-Real-IP`, and falls back to `"unknown"`. This
 * assumes a trusted reverse proxy (e.g., nginx, cloud load balancer) that sets
 * these headers. For direct-to-internet deployments without a reverse proxy,
 * provide a custom `keyGenerator` that derives the client identity from a
 * reliable source (e.g., authenticated user ID, Hono's `c.req.raw` connection
 * info).
 */
export function createRateLimiter(options?: RateLimitOptions): MiddlewareHandler {
  const store = options?.store ?? new MemoryStore();
  const windowMs = options?.windowMs ?? DEFAULT_WINDOW_MS;
  const max = options?.max ?? DEFAULT_MAX_REQUESTS;
  const keyGenerator =
    options?.keyGenerator ??
    ((c) => {
      const forwarded = c.req.header("x-forwarded-for");
      if (forwarded) {
        return forwarded.split(",")[0]?.trim() ?? "unknown";
      }
      return c.req.header("x-real-ip") ?? "unknown";
    });

  return async (c, next) => {
    const key = keyGenerator(c);
    const result = await store.increment(key, windowMs);

    c.header("X-RateLimit-Limit", String(max));
    c.header("X-RateLimit-Remaining", String(Math.max(0, max - result.count)));
    c.header("X-RateLimit-Reset", String(result.resetAt));

    if (result.count > max) {
      const retryAfterSec = Math.ceil((result.resetAt - Date.now()) / 1000);
      c.header("Retry-After", String(retryAfterSec));
      return c.json({ error: "Too Many Requests" }, 429);
    }

    await next();
  };
}
