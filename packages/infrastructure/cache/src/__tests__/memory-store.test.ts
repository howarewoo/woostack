import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { MemoryCacheStore } from "../memory-store";

describe("MemoryCacheStore", () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it("stores and retrieves values", async () => {
    const store = new MemoryCacheStore();
    await store.set("key1", { name: "Alice" }, 10_000);
    const result = await store.get<{ name: string }>("key1");
    expect(result).toEqual({ name: "Alice" });
  });

  it("returns undefined for missing keys", async () => {
    const store = new MemoryCacheStore();
    const result = await store.get("nonexistent");
    expect(result).toBeUndefined();
  });

  it("expires values after TTL", async () => {
    const store = new MemoryCacheStore();
    await store.set("key1", "value1", 5_000);

    vi.advanceTimersByTime(4_999);
    expect(await store.get("key1")).toBe("value1");

    vi.advanceTimersByTime(1);
    expect(await store.get("key1")).toBeUndefined();
  });

  it("evicts oldest entry when max size exceeded", async () => {
    const store = new MemoryCacheStore({ maxEntries: 3 });
    await store.set("a", 1, 60_000);
    await store.set("b", 2, 60_000);
    await store.set("c", 3, 60_000);

    // Adding a 4th should evict "a" (oldest)
    await store.set("d", 4, 60_000);

    expect(await store.get("a")).toBeUndefined();
    expect(await store.get("b")).toBe(2);
    expect(await store.get("c")).toBe(3);
    expect(await store.get("d")).toBe(4);
  });

  it("deletes a specific key", async () => {
    const store = new MemoryCacheStore();
    await store.set("key1", "value1", 60_000);
    await store.delete("key1");
    expect(await store.get("key1")).toBeUndefined();
  });

  it("deletes keys by prefix", async () => {
    const store = new MemoryCacheStore();
    await store.set("user:1", "Alice", 60_000);
    await store.set("user:2", "Bob", 60_000);
    await store.set("post:1", "Hello", 60_000);

    await store.deleteByPrefix("user:");

    expect(await store.get("user:1")).toBeUndefined();
    expect(await store.get("user:2")).toBeUndefined();
    expect(await store.get("post:1")).toBe("Hello");
  });

  it("refreshes LRU order on get", async () => {
    const store = new MemoryCacheStore({ maxEntries: 3 });
    await store.set("a", 1, 60_000);
    await store.set("b", 2, 60_000);
    await store.set("c", 3, 60_000);

    // Access "a" to make it most recently used
    await store.get("a");

    // Adding "d" should evict "b" (now the oldest)
    await store.set("d", 4, 60_000);

    expect(await store.get("a")).toBe(1);
    expect(await store.get("b")).toBeUndefined();
  });
});
