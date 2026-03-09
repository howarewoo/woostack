import type { CacheStore } from "./types";

interface CacheEntry<T = unknown> {
  value: T;
  expiresAt: number;
}

/** Options for MemoryCacheStore. */
export interface MemoryCacheStoreOptions {
  /** Maximum number of entries before LRU eviction. Defaults to 1000. */
  maxEntries?: number;
}

/**
 * In-memory cache store with LRU eviction and TTL-based expiration.
 * Uses a Map to preserve insertion order for LRU tracking.
 */
export class MemoryCacheStore implements CacheStore {
  private readonly map = new Map<string, CacheEntry>();
  private readonly maxEntries: number;

  constructor(options?: MemoryCacheStoreOptions) {
    this.maxEntries = options?.maxEntries ?? 1000;
  }

  async get<T>(key: string): Promise<T | undefined> {
    const entry = this.map.get(key);
    if (!entry) {
      return undefined;
    }

    if (Date.now() >= entry.expiresAt) {
      this.map.delete(key);
      return undefined;
    }

    // Move to end for LRU (most recently used)
    this.map.delete(key);
    this.map.set(key, entry);

    return entry.value as T;
  }

  async set<T>(key: string, value: T, ttlMs: number): Promise<void> {
    // Delete first so re-insertion moves to end
    this.map.delete(key);

    // Evict oldest entry if at capacity
    if (this.map.size >= this.maxEntries) {
      const oldestKey = this.map.keys().next().value as string;
      this.map.delete(oldestKey);
    }

    this.map.set(key, {
      value,
      expiresAt: Date.now() + ttlMs,
    });
  }

  async delete(key: string): Promise<void> {
    this.map.delete(key);
  }

  async deleteByPrefix(prefix: string): Promise<void> {
    for (const key of [...this.map.keys()]) {
      if (key.startsWith(prefix)) {
        this.map.delete(key);
      }
    }
  }
}
