import { randomUUID } from "node:crypto";

export interface EventBus {
  on(event: string, listener: (data: unknown) => void): () => void;
  emit(event: string, data: unknown): void;
}

export function record(value: unknown): Record<string, unknown> | undefined {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : undefined;
}

export class RpcClient {
  private pending = new Set<(error: Error) => void>();
  private closed = false;
  private bus: EventBus;

  constructor(bus: EventBus) {
    this.bus = bus;
  }

  request(
    method: string,
    params: Record<string, unknown> = {},
    timeoutMs = 5_000,
  ): Promise<unknown> {
    if (this.closed) return Promise.reject(new Error("Subagent UI session closed."));
    return new Promise((resolve, reject) => {
      const requestId = randomUUID();
      let unsubscribe = () => {};
      const finish = (error?: Error, data?: unknown) => {
        clearTimeout(timer);
        unsubscribe();
        this.pending.delete(cancel);
        if (error) reject(error);
        else resolve(data);
      };
      const cancel = (error: Error) => finish(error);
      const timer = setTimeout(() => {
        const suffix = ["steer", "stop"].includes(method)
          ? " The outcome is unknown; inspect status before trying again."
          : " Check that pi-subagents 0.87.0 or newer is loaded, then refresh.";
        finish(new Error(`pi-subagents ${method} did not reply.${suffix}`));
      }, timeoutMs);
      this.pending.add(cancel);
      unsubscribe = this.bus.on(`subagents:rpc:v1:reply:${requestId}`, (raw) => {
        const reply = record(raw);
        if (reply?.requestId !== requestId || reply.version !== 1) return;
        if (reply.success === true) finish(undefined, reply.data);
        else {
          const error = record(reply.error);
          finish(
            new Error(typeof error?.message === "string" ? error.message : "Invalid RPC reply."),
          );
        }
      });
      try {
        this.bus.emit("subagents:rpc:v1:request", { version: 1, requestId, method, params });
      } catch (error) {
        finish(error instanceof Error ? error : new Error(String(error)));
      }
    });
  }

  dispose(): void {
    this.closed = true;
    for (const cancel of this.pending) cancel(new Error("Subagent UI session closed."));
  }
}
