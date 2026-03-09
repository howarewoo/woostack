import { describe, expect, it, vi } from "vitest";
import { z } from "zod";
import { defineJob } from "../define-job";

describe("defineJob", () => {
  it("creates a job definition with name and handler", () => {
    const handler = vi.fn(async () => {});
    const schema = z.object({ userId: z.string() });

    const job = defineJob({
      name: "send-welcome-email",
      schema,
      handler,
    });

    expect(job.name).toBe("send-welcome-email");
    expect(job.schema).toBe(schema);
    expect(job.handler).toBe(handler);
    expect(job.options).toBeUndefined();
  });

  it("includes options when provided", () => {
    const job = defineJob({
      name: "process-payment",
      schema: z.object({ amount: z.number() }),
      handler: async () => {},
      options: {
        retryLimit: 3,
        retryDelay: 5000,
        retryBackoff: true,
        expireInMinutes: 30,
      },
    });

    expect(job.options).toEqual({
      retryLimit: 3,
      retryDelay: 5000,
      retryBackoff: true,
      expireInMinutes: 30,
    });
  });

  it("schema validates input correctly", () => {
    const schema = z.object({
      email: z.email(),
      name: z.string().min(1),
    });

    const job = defineJob({
      name: "send-notification",
      schema,
      handler: async () => {},
    });

    const validResult = job.schema.safeParse({ email: "test@example.com", name: "Alice" });
    expect(validResult.success).toBe(true);

    const invalidResult = job.schema.safeParse({ email: "not-an-email", name: "" });
    expect(invalidResult.success).toBe(false);
  });
});
