import type { z } from "zod";
import type { JobDefinition, JobOptions } from "./types";

/**
 * Creates a type-safe job definition.
 *
 * Schema validation happens at enqueue time, not at definition time.
 */
export function defineJob<TInput>(params: {
  name: string;
  schema: z.ZodType<TInput>;
  handler: (data: TInput) => Promise<void>;
  options?: JobOptions;
}): JobDefinition<TInput> {
  return {
    name: params.name,
    schema: params.schema,
    handler: params.handler,
    options: params.options,
  };
}
