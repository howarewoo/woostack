import { MemoryCacheStore } from "./memory-store";
import type { CacheOptions, CacheStore } from "./types";

const DEFAULT_TTL_MS = 60_000;

/**
 * High-level cache wrapper that adds key prefixing and default TTL
 * on top of any CacheStore implementation.
 */
export class Cache {
  private readonly store: CacheStore;
  private readonly defaultTtlMs: number;
  private readonly keyPrefix: string;

  constructor(options?: CacheOptions) {
    this.store = options?.store ?? new MemoryCacheStore();
    this.defaultTtlMs = options?.defaultTtlMs ?? DEFAULT_TTL_MS;
    this.keyPrefix = options?.keyPrefix ?? "";
  }

  /** Retrieve a cached value by key. */
  async get<T>(key: string): Promise<T | undefined> {
    return this.store.get<T>(this.keyPrefix + key);
  }

  /** Store a value with an optional TTL (defaults to defaultTtlMs). */
  async set<T>(key: string, value: T, ttlMs?: number): Promise<void> {
    return this.store.set<T>(this.keyPrefix + key, value, ttlMs ?? this.defaultTtlMs);
  }

  /** Remove a specific key from the cache. */
  async invalidate(key: string): Promise<void> {
    return this.store.delete(this.keyPrefix + key);
  }

  /** Remove all keys matching the given prefix. */
  async invalidateByPrefix(prefix: string): Promise<void> {
    return this.store.deleteByPrefix(this.keyPrefix + prefix);
  }
}

/** Create a new Cache instance with the given options. */
export function createCache(options?: CacheOptions): Cache {
  return new Cache(options);
}
