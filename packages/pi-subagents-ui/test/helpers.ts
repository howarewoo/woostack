import type { EventBus } from "../src/rpc.ts";

export class Bus implements EventBus {
  listeners = new Map<string, Set<(data: unknown) => void>>();
  requests: { method: string; params: Record<string, unknown>; requestId: string }[] = [];
  handler?: (method: string, params: Record<string, unknown>) => unknown | Promise<unknown>;

  on(event: string, listener: (data: unknown) => void): () => void {
    const listeners = this.listeners.get(event) ?? new Set();
    listeners.add(listener);
    this.listeners.set(event, listeners);
    return () => {
      listeners.delete(listener);
      if (listeners.size === 0) this.listeners.delete(event);
    };
  }

  emit(event: string, data: unknown): void {
    for (const listener of this.listeners.get(event) ?? []) listener(data);
    if (event === "subagents:rpc:v1:request") {
      const request = data as (typeof this.requests)[number];
      this.requests.push(request);
      if (!this.handler) return;
      Promise.resolve()
        .then(() => this.handler!(request.method, request.params))
        .then(
          (result) => this.reply(request.requestId, result),
          (error) =>
            this.emit(`subagents:rpc:v1:reply:${request.requestId}`, {
              version: 1,
              requestId: request.requestId,
              success: false,
              error: { message: String(error) },
            }),
        );
    }
  }

  reply(requestId: string, data: unknown): void {
    this.emit(`subagents:rpc:v1:reply:${requestId}`, {
      version: 1,
      requestId,
      success: true,
      data,
    });
  }
}

export function snapshot(runs: unknown[] = []) {
  return {
    asyncSnapshot: {
      kind: "pi-subagents.async-status-snapshot",
      version: 1,
      generatedAt: 1_000,
      omitted: { runs: 0, children: 0, byteLimitExceeded: false },
      runs,
    },
  };
}

export const agent = {
  id: "actual-run-id",
  kind: "subagent",
  label: "Review auth flow",
  state: "running",
  startedAt: 1_000,
};
export const workflow = {
  id: "workflow-id",
  kind: "workflow",
  label: "Build and review",
  state: "running",
};
export const ping = {
  version: 1,
  session: { sessionId: "parent" },
  methods: ["status", "steer", "stop"],
  capabilities: { asyncStatusSnapshot: { version: 1 }, nonRecoveringSteer: true },
  events: { jobsChanged: "subagent:jobs-changed", asyncComplete: "subagent:async-complete" },
};

export function deferred<T>() {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((done) => {
    resolve = done;
  });
  return { promise, resolve };
}

export const tick = () => new Promise<void>((resolve) => setImmediate(resolve));
