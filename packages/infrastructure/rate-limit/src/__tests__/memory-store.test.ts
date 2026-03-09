import { beforeEach, describe, expect, it, vi } from "vitest";
import { MemoryStore } from "../memory-store";

describe("MemoryStore", () => {
  let store: MemoryStore;
  const windowMs = 60_000;

  beforeEach(() => {
    store = new MemoryStore();
    vi.useRealTimers();
  });

  it("increments count for a new key", async () => {
    const result = await store.increment("ip-1", windowMs);
    expect(result.count).toBe(1);
    expect(result.resetAt).toBeGreaterThan(Date.now() - 1000);
  });

  it("increments on subsequent calls within the window", async () => {
    await store.increment("ip-1", windowMs);
    const result = await store.increment("ip-1", windowMs);
    expect(result.count).toBe(2);

    const result3 = await store.increment("ip-1", windowMs);
    expect(result3.count).toBe(3);
  });

  it("resets count after window expires", async () => {
    vi.useFakeTimers();

    await store.increment("ip-1", windowMs);
    await store.increment("ip-1", windowMs);

    vi.advanceTimersByTime(windowMs + 1);

    const result = await store.increment("ip-1", windowMs);
    expect(result.count).toBe(1);
  });

  it("tracks different keys independently", async () => {
    await store.increment("ip-1", windowMs);
    await store.increment("ip-1", windowMs);
    const result = await store.increment("ip-2", windowMs);

    expect(result.count).toBe(1);
  });

  it("reset() clears a specific key", async () => {
    await store.increment("ip-1", windowMs);
    await store.increment("ip-1", windowMs);

    await store.reset("ip-1");

    const result = await store.increment("ip-1", windowMs);
    expect(result.count).toBe(1);
  });

  it("evicts expired entries when store exceeds MAX_ENTRIES", async () => {
    vi.useFakeTimers();

    const tinyWindow = 1; // 1ms window so entries expire almost immediately

    // Fill the store with entries that will expire quickly
    for (let i = 0; i < 10_001; i++) {
      await store.increment(`key-${i}`, tinyWindow);
    }

    // Advance time so all existing entries have expired
    vi.advanceTimersByTime(2);

    // This increment triggers cleanup because size > MAX_ENTRIES
    const result = await store.increment("fresh-key", windowMs);
    expect(result.count).toBe(1);

    // After cleanup, expired entries should be removed.
    // A previously inserted key should start fresh if re-inserted.
    const result2 = await store.increment("key-0", windowMs);
    expect(result2.count).toBe(1);
  });

  it("evicts oldest active entries when store exceeds MAX_ENTRIES", async () => {
    vi.useFakeTimers();

    const longWindow = 600_000; // entries won't expire during the test

    // Fill the store beyond MAX_ENTRIES with non-expiring entries
    for (let i = 0; i < 10_001; i++) {
      await store.increment(`key-${i}`, longWindow);
    }

    // Trigger cleanup with one more insert — all entries are active,
    // so the overflow eviction path must evict the oldest entries
    const result = await store.increment("overflow-key", longWindow);
    expect(result.count).toBe(1);

    // key-0 was the oldest and should have been evicted
    const result2 = await store.increment("key-0", longWindow);
    expect(result2.count).toBe(1); // fresh entry, not count=2
  });
});
