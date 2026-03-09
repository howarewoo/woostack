import type { MiddlewareHandler } from "hono";
import { MemoryStore } from "./memory-store";
import type { RateLimitOptions } from "./types";

/** Create a Hono rate limiter middleware. */
export function createRateLimiter(options?: RateLimitOptions): MiddlewareHandler {
  const store = options?.store ?? new MemoryStore();
  const windowMs = options?.windowMs ?? 60_000;
  const max = options?.max ?? 100;
  const keyGenerator =
    options?.keyGenerator ??
    ((c) => {
      const forwarded = c.req.header("x-forwarded-for");
      return forwarded?.split(",")[0]?.trim() ?? "unknown";
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
