/** A feature flag definition. */
export interface Flag {
  key: string;
  enabled: boolean;
  rules: FlagRules;
}

/** Rules that control flag evaluation beyond the simple on/off toggle. */
export interface FlagRules {
  /** Percentage of users (0-100) who should see this flag enabled. */
  percentage?: number;
  /** Explicit list of user IDs that should always see this flag enabled. */
  allowedUserIds?: string[];
}

/** Async store interface for retrieving feature flags. */
export interface FlagStore {
  /** Retrieve a single flag by key. */
  getFlag(key: string): Promise<Flag | undefined>;
  /** Retrieve all flags. */
  getAllFlags(): Promise<Flag[]>;
}

/** Context provided during flag evaluation. */
export interface FlagContext {
  userId?: string;
}
