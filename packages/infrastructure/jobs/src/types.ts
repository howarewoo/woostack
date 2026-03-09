import type { z } from "zod";

/** Configuration for job retry and expiration behavior. */
export interface JobOptions {
  retryLimit?: number;
  retryDelay?: number;
  retryBackoff?: boolean;
  expireInMinutes?: number;
}

/** Options for scheduling a job (delay or cron). */
export interface ScheduleOptions {
  delay?: number;
  cron?: string;
}

/** A fully defined background job with name, schema, handler, and optional config. */
export interface JobDefinition<TInput = unknown> {
  name: string;
  schema: z.ZodType<TInput>;
  handler: (data: TInput) => Promise<void>;
  options?: JobOptions;
}
