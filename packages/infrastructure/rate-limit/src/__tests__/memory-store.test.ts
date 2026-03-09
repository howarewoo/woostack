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
});
