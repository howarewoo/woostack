import {
  canSteer,
  canStop,
  cleanText,
  foregroundRows,
  parseFleet,
  type AgentRow,
} from "./model.ts";
import { record, RpcClient, type EventBus } from "./rpc.ts";

export interface UiState {
  rows: AgentRow[];
  omitted: number;
  connected: boolean;
  error?: string;
}

export class FleetController {
  state: UiState = { rows: [], omitted: 0, connected: false };
  private client: RpcClient;
  private bus: EventBus;
  private sessionId: string;
  private listeners = new Set<() => void>();
  private subscriptions: (() => void)[] = [];
  private eventSubscriptions: (() => void)[] = [];
  private foreground = new Map<string, AgentRow>();
  private timer?: ReturnType<typeof setTimeout>;
  private refreshing = false;
  private dirty = false;
  private connecting = false;
  private closed = false;
  private methods = new Set<string>();

  constructor(bus: EventBus, sessionId: string) {
    this.bus = bus;
    this.sessionId = sessionId;
    this.client = new RpcClient(bus);
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  private changed(): void {
    if (!this.closed) for (const listener of this.listeners) listener();
  }

  async start(): Promise<void> {
    this.subscriptions.push(this.bus.on("subagents:rpc:v1:ready", () => void this.connect()));
    await this.connect();
  }

  private async connect(): Promise<void> {
    if (this.closed || this.connecting) return;
    this.connecting = true;
    try {
      const ping = record(await this.client.request("ping", {}, 1_500));
      if (this.closed) return;
      const session = record(ping?.session);
      const capabilities = record(ping?.capabilities);
      if (
        ping?.version !== 1 ||
        session?.sessionId !== this.sessionId ||
        !Array.isArray(ping.methods)
      ) {
        throw new Error("pi-subagents did not confirm this parent session.");
      }
      if (record(capabilities?.asyncStatusSnapshot)?.version !== 1) {
        throw new Error("pi-subagents async-status snapshot v1 is required.");
      }
      this.methods = new Set(
        ping.methods.filter((method): method is string => typeof method === "string"),
      );
      if (capabilities?.nonRecoveringSteer !== true) this.methods.delete("steer");
      if (!this.methods.has("status")) throw new Error("pi-subagents status RPC is unavailable.");
      for (const unsubscribe of this.eventSubscriptions.splice(0)) unsubscribe();
      const events = record(ping.events);
      for (const key of [
        "jobsChanged",
        "asyncStarted",
        "childStatus",
        "asyncComplete",
        "processTerminal",
      ]) {
        if (typeof events?.[key] === "string") {
          this.eventSubscriptions.push(this.bus.on(events[key], () => this.schedule()));
        }
      }
      this.state = { ...this.state, connected: true, error: undefined };
      await this.refresh();
    } catch (error) {
      if (!this.closed) {
        this.state = { ...this.state, connected: false, error: this.message(error) };
        this.changed();
      }
    } finally {
      this.connecting = false;
    }
  }

  private message(error: unknown): string {
    return cleanText(error instanceof Error ? error.message : String(error)).slice(0, 1_000);
  }

  private schedule(): void {
    if (this.closed) return;
    this.dirty = true;
    if (this.timer || this.refreshing) return;
    this.timer = setTimeout(() => {
      this.timer = undefined;
      void this.refresh();
    }, 150);
  }

  async refresh(): Promise<void> {
    if (this.closed) return;
    if (!this.state.connected) {
      await this.connect();
      return;
    }
    if (this.refreshing) {
      this.dirty = true;
      return;
    }
    this.refreshing = true;
    this.dirty = false;
    try {
      const fleet = parseFleet(await this.client.request("status"));
      if (this.closed) return;
      this.state = {
        rows: [...fleet.rows, ...this.foreground.values()],
        omitted: fleet.omitted,
        connected: true,
      };
    } catch (error) {
      if (!this.closed) this.state = { ...this.state, error: this.message(error) };
    } finally {
      this.refreshing = false;
      this.changed();
      if (this.dirty) this.schedule();
    }
  }

  observeForeground(details: unknown, terminal?: "failed" | "finished"): void {
    for (const row of foregroundRows(details)) {
      const previous = this.foreground.get(row.key);
      this.foreground.set(row.key, {
        ...previous,
        ...row,
        state: terminal && row.state === "running" ? terminal : row.state,
      });
    }
    // Bounded display history only; no child files or lifecycle records are changed.
    if (this.foreground.size > 40) {
      for (const [key, row] of this.foreground) {
        if (this.foreground.size <= 40) break;
        if (row.state !== "running") this.foreground.delete(key);
      }
    }
    this.state = {
      ...this.state,
      rows: [
        ...this.state.rows.filter((row) => row.kind !== "foreground"),
        ...this.foreground.values(),
      ],
    };
    this.changed();
  }

  async inspect(row: AgentRow): Promise<string> {
    const data = record(
      await this.client.request("status", {
        id: row.runId,
        view: row.kind === "workflow" ? "fleet" : "transcript",
        ...(row.index !== undefined ? { index: row.index } : {}),
        lines: 160,
      }),
    );
    if (typeof data?.text !== "string")
      throw new Error("pi-subagents returned no transcript text.");
    return cleanText(data.text).slice(-80_000);
  }

  async steer(row: AgentRow, message: string): Promise<string> {
    const current = this.state.rows.find((candidate) => candidate.key === row.key);
    if (!current || !canSteer(current) || !this.methods.has("steer")) {
      throw new Error(
        "Steering is available only for a running background agent. Refresh its status.",
      );
    }
    if (!message.trim()) throw new Error("Enter a message to steer this agent.");
    const data = record(
      await this.client.request("steer", { id: current.runId, message, mode: "steer" }, 15_000),
    );
    return typeof data?.text === "string" ? cleanText(data.text) : "Steering request acknowledged.";
  }

  async stop(row: AgentRow): Promise<string> {
    const current = this.state.rows.find((candidate) => candidate.key === row.key);
    if (!current || !canStop(current) || !this.methods.has("stop")) {
      throw new Error("This run cannot be stopped here. Refresh its status.");
    }
    await this.client.request("stop", { id: current.runId }, 15_000);
    this.schedule();
    return "Stop requested; this is not proof that the writer or its processes have exited.";
  }

  dispose(): void {
    this.closed = true;
    clearTimeout(this.timer);
    for (const unsubscribe of [...this.subscriptions, ...this.eventSubscriptions]) unsubscribe();
    this.client.dispose();
    this.listeners.clear();
    this.foreground.clear();
  }
}
