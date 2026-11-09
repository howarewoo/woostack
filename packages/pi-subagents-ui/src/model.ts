import { record } from "./rpc.ts";

export interface AgentRow {
  key: string;
  runId: string;
  index?: number;
  label: string;
  state: string;
  kind: "subagent" | "workflow" | "foreground";
  agent?: string;
  model?: string;
  activity?: string;
  startedAt?: number;
  tokens?: number;
}

export interface Fleet {
  rows: AgentRow[];
  omitted: number;
}

export function cleanText(value: string): string {
  // Child output is untrusted terminal content. Keep text, not escape sequences,
  // C0/C1 controls, hyperlinks, carriage returns, or bidi presentation controls.
  /* oxlint-disable no-control-regex -- explicitly remove terminal control sequences */
  return value
    .replace(/\x1b\][\s\S]*?(?:\x07|\x1b\\)/g, "")
    .replace(/\x1b[P^_][\s\S]*?\x1b\\/g, "")
    .replace(/\x1b\[[0-?]*[ -/]*[@-~]/g, "")
    .replace(/\x1b[ -/]*[@-~]/g, "")
    .replace(/[\x00-\x08\x0b-\x1f\x7f-\x9f\u202a-\u202e\u2066-\u2069]/g, "")
    .replace(/\t/g, "  ");
  /* oxlint-enable no-control-regex */
}

export function label(value: unknown, fallback = ""): string {
  return typeof value === "string" ? cleanText(value).replace(/\n/g, " ").slice(0, 500) : fallback;
}

function finite(value: unknown): number | undefined {
  return typeof value === "number" && Number.isFinite(value) && value >= 0 ? value : undefined;
}

export function parseFleet(data: unknown): Fleet {
  const snapshot = record(record(data)?.asyncSnapshot);
  if (
    snapshot?.kind !== "pi-subagents.async-status-snapshot" ||
    snapshot.version !== 1 ||
    !Array.isArray(snapshot.runs)
  ) {
    throw new Error(
      "This runtime does not expose async-status snapshot v1. Use pi-subagents 0.87.0 or newer.",
    );
  }
  const rows: AgentRow[] = [];
  const seen = new Set<string>();
  for (const value of snapshot.runs.slice(0, 100)) {
    const node = record(value);
    if (!node || typeof node.id !== "string" || !node.id.trim() || seen.has(node.id)) continue;
    if (node.kind !== "subagent" && node.kind !== "workflow") continue;
    seen.add(node.id);
    const children = Array.isArray(node.children)
      ? node.children.map(record).filter((v) => !!v)
      : [];
    const active = children.find((child) => child.state === "running") ?? children[0];
    const activity = record(node.activity) ?? record(active?.activity);
    rows.push({
      key: `async:${node.id}`,
      runId: node.id,
      kind: node.kind,
      label: label(node.label, "Subagent"),
      state: label(node.state, "unknown"),
      agent: label(node.agent ?? active?.agent) || undefined,
      model: label(node.model ?? active?.model) || undefined,
      activity: label(activity?.currentTool ?? activity?.state) || undefined,
      startedAt: finite(node.startedAt),
    });
  }
  const omitted = record(snapshot.omitted);
  return { rows, omitted: finite(omitted?.runs) ?? 0 };
}

export function foregroundRows(details: unknown): AgentRow[] {
  const value = record(details);
  if (typeof value?.runId !== "string" || !Array.isArray(value.results)) return [];
  return value.results.flatMap((raw): AgentRow[] => {
    const child = record(raw);
    const index = finite(child?.index);
    if (!child || index === undefined || !Number.isInteger(index)) return [];
    return [
      {
        key: `foreground:${value.runId}:${index}`,
        runId: value.runId as string,
        index,
        kind: "foreground",
        label: label(child.task ?? child.agent, "Foreground child"),
        state: label(child.state, "running"),
        agent: label(child.agent) || undefined,
        model: label(child.model) || undefined,
        activity: label(record(child.progress)?.currentTool) || undefined,
        tokens: finite(record(child.usage)?.totalTokens),
      },
    ];
  });
}

export function canSteer(row: AgentRow): boolean {
  return row.kind === "subagent" && row.state === "running";
}

export function canStop(row: AgentRow): boolean {
  return row.kind !== "foreground" && ["running", "queued", "paused"].includes(row.state);
}

export function duration(startedAt: number | undefined, now = Date.now()): string {
  if (startedAt === undefined) return "";
  const seconds = Math.max(0, Math.floor((now - startedAt) / 1_000));
  if (seconds < 60) return `${seconds}s`;
  const minutes = Math.floor(seconds / 60);
  return minutes < 60
    ? `${minutes}m ${seconds % 60}s`
    : `${Math.floor(minutes / 60)}h ${minutes % 60}m`;
}
