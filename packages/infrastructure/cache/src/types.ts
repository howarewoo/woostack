/** Interface for cache storage backends. */
export interface CacheStore {
  /** Retrieve a value by key. Returns undefined if missing or expired. */
  get<T>(key: string): Promise<T | undefined>;
  /** Store a value with a TTL in milliseconds. */
  set<T>(key: string, value: T, ttlMs: number): Promise<void>;
  /** Delete a specific key. */
  delete(key: string): Promise<void>;
  /** Delete all keys that start with the given prefix. */
  deleteByPrefix(prefix: string): Promise<void>;
}

/** Options for creating a Cache instance. */
export interface CacheOptions {
  /** The underlying store implementation. Defaults to MemoryCacheStore. */
  store?: CacheStore;
  /** Default TTL in milliseconds when not specified per-call. Defaults to 60000 (1 minute). */
  defaultTtlMs?: number;
  /** Prefix prepended to all keys. Defaults to empty string. */
  keyPrefix?: string;
}
