import type { Flag, FlagStore } from "./types";

/**
 * In-memory flag store for testing and development.
 * Stores flags in a Map keyed by flag key.
 */
export class MemoryFlagStore implements FlagStore {
  private flags: Map<string, Flag>;

  constructor(initialFlags?: Flag[]) {
    this.flags = new Map();
    if (initialFlags) {
      for (const flag of initialFlags) {
        this.flags.set(flag.key, flag);
      }
    }
  }

  async getFlag(key: string): Promise<Flag | undefined> {
    return this.flags.get(key);
  }

  async getAllFlags(): Promise<Flag[]> {
    return Array.from(this.flags.values());
  }

  /** Programmatically set or update a flag. */
  setFlag(flag: Flag): void {
    this.flags.set(flag.key, flag);
  }
}
