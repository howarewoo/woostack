import { describe, expect, it, vi } from "vitest";
import { Cache, createCache } from "../cache";
import { MemoryCacheStore } from "../memory-store";

describe("Cache", () => {
  it("applies key prefix to get and set", async () => {
    const store = new MemoryCacheStore();
    const cache = new Cache({ store, keyPrefix: "app:" });

    await cache.set("user", "Alice");
    // Accessing store directly to verify prefix was applied
    expect(await store.get("app:user")).toBe("Alice");
    expect(await cache.get("user")).toBe("Alice");
  });

  it("uses default TTL", async () => {
    vi.useFakeTimers();
    try {
      const cache = new Cache({ defaultTtlMs: 5_000 });
      await cache.set("key", "value");

      vi.advanceTimersByTime(4_999);
      expect(await cache.get("key")).toBe("value");

      vi.advanceTimersByTime(1);
      expect(await cache.get("key")).toBeUndefined();
    } finally {
      vi.useRealTimers();
    }
  });

  it("invalidate removes a key", async () => {
    const cache = new Cache({ keyPrefix: "test:" });
    await cache.set("foo", "bar");
    expect(await cache.get("foo")).toBe("bar");

    await cache.invalidate("foo");
    expect(await cache.get("foo")).toBeUndefined();
  });

  it("invalidateByPrefix removes matching keys", async () => {
    const cache = new Cache({ keyPrefix: "app:" });
    await cache.set("user:1", "Alice");
    await cache.set("user:2", "Bob");
    await cache.set("post:1", "Hello");

    await cache.invalidateByPrefix("user:");

    expect(await cache.get("user:1")).toBeUndefined();
    expect(await cache.get("user:2")).toBeUndefined();
    expect(await cache.get("post:1")).toBe("Hello");
  });

  it("createCache returns a Cache instance", () => {
    const cache = createCache({ keyPrefix: "x:" });
    expect(cache).toBeInstanceOf(Cache);
  });
});
