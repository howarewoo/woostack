import type { Flag, FlagContext } from "./types";

/**
 * Deterministic hash function (djb2) that produces a value in the range [0, 99].
 * Same input always yields the same bucket, enabling consistent percentage rollouts.
 */
export function hashToBucket(input: string): number {
  let hash = 5381;
  for (let i = 0; i < input.length; i++) {
    hash = (hash * 33) ^ input.charCodeAt(i);
  }
  return Math.abs(hash) % 100;
}

/**
 * Evaluate whether a feature flag should be enabled for the given context.
 *
 * Logic:
 * 1. If the flag is disabled, return false.
 * 2. If `allowedUserIds` is set and non-empty, return true only if `context.userId` is in the list.
 * 3. If `percentage` is set, use a deterministic hash of `flag.key + userId` to bucket (0-99).
 *    Return true if the bucket is less than the percentage. Return false if no userId.
 * 4. If no rules are set, return true (flag is simply on/off).
 */
export function evaluateFlag(flag: Flag, context?: FlagContext): boolean {
  if (!flag.enabled) {
    return false;
  }

  const { rules } = flag;

  // User targeting takes priority
  if (rules.allowedUserIds && rules.allowedUserIds.length > 0) {
    if (!context?.userId) {
      return false;
    }
    return rules.allowedUserIds.includes(context.userId);
  }

  // Percentage rollout
  if (rules.percentage !== undefined) {
    if (rules.percentage >= 100) {
      return true;
    }
    if (rules.percentage <= 0) {
      return false;
    }
    if (!context?.userId) {
      return false;
    }
    const bucket = hashToBucket(`${flag.key}${context.userId}`);
    return bucket < rules.percentage;
  }

  // No rules — flag is simply on/off
  return true;
}
