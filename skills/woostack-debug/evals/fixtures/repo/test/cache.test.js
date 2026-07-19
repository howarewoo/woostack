import { isFresh } from "../src/cache.js";

test("expires an entry older than 30 seconds", () => {
  expect(isFresh({ createdAtMs: Date.now() - 31_000 })).toBe(false);
});
