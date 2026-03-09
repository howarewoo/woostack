import type { MiddlewareHandler } from "hono";

/** Result returned by a rate limit store after incrementing a key. */
export interface RateLimitResult {
  /** Current request count within the window. */
  count: number;
  /** Timestamp (ms since epoch) when the current window resets. */
  resetAt: number;
}

/** Storage backend for rate limit state. */
export interface RateLimitStore {
  /** Increment the counter for a key within the given window. */
  increment(key: string, windowMs: number): Promise<RateLimitResult>;
  /** Reset (delete) the counter for a key. */
  reset(key: string): Promise<void>;
}

/** Options for the rate limiter middleware. */
export interface RateLimitOptions {
  /** Storage backend. Defaults to an in-memory store. */
  store?: RateLimitStore;
  /** Window duration in milliseconds. Defaults to 60000 (1 minute). */
  windowMs?: number;
  /** Maximum requests per window. Defaults to 100. */
  max?: number;
  /** Function to derive a rate-limit key from the request. Defaults to IP-based. */
  keyGenerator?: (c: Parameters<MiddlewareHandler>[0]) => string;
}
