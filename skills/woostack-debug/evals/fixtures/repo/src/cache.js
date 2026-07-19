import { nowSeconds } from "./clock.js";
export function isFresh(entry) {
  return nowSeconds() - entry.createdAtMs < 30_000;
}
