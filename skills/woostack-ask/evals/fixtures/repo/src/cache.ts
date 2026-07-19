const MAX_AGE_MS = 30_000;
export const isFresh = (ageMs: number) => ageMs < MAX_AGE_MS;
