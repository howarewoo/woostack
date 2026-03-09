import type { RateLimitResult, RateLimitStore } from "./types";

const MAX_ENTRIES = 10_000;

interface Entry {
  count: number;
  resetAt: number;
}

/** In-memory sliding window rate limit store. */
export class MemoryStore implements RateLimitStore {
  private store = new Map<string, Entry>();

  async increment(key: string, windowMs: number): Promise<RateLimitResult> {
    const now = Date.now();
    const existing = this.store.get(key);

    if (existing && now < existing.resetAt) {
      existing.count += 1;
      return { count: existing.count, resetAt: existing.resetAt };
    }

    const entry: Entry = { count: 1, resetAt: now + windowMs };
    this.store.set(key, entry);

    if (this.store.size > MAX_ENTRIES) {
      this.cleanup(now);
    }

    return { count: entry.count, resetAt: entry.resetAt };
  }

  async reset(key: string): Promise<void> {
    this.store.delete(key);
  }

  private cleanup(now: number): void {
    for (const [k, v] of this.store) {
      if (now >= v.resetAt) {
        this.store.delete(k);
      }
    }
  }
}
