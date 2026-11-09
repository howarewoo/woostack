import type { Theme } from "@earendil-works/pi-coding-agent";
import {
  matchesKey,
  truncateToWidth,
  wrapTextWithAnsi,
  type Component,
  type KeybindingsManager,
  type TUI,
} from "@earendil-works/pi-tui";
import { canSteer, canStop, duration, label, type AgentRow } from "./model.ts";
import type { FleetController, UiState } from "./controller.ts";

const stateMarks: Record<string, string> = {
  running: "●",
  queued: "○",
  pending: "○",
  complete: "✓",
  completed: "✓",
  finished: "✓",
  failed: "!",
  rejected: "!",
  partial: "!",
  paused: "Ⅱ",
  stopped: "■",
};

function stateColor(state: string): "accent" | "success" | "warning" | "error" | "muted" {
  if (state === "running") return "accent";
  if (["complete", "completed", "finished"].includes(state)) return "success";
  if (["failed", "rejected"].includes(state)) return "error";
  return ["paused", "partial"].includes(state) ? "warning" : "muted";
}

function rowLine(row: AgentRow, theme: Theme, now: number, selected = false): string {
  const prefix = selected ? theme.fg("accent", "› ") : "  ";
  const mark = theme.fg(stateColor(row.state), stateMarks[row.state] ?? "?");
  const name = selected ? theme.bold(row.label) : row.label;
  const detail = [row.state, row.activity, duration(row.startedAt, now)]
    .filter(Boolean)
    .join(" · ");
  return `${prefix}${mark} ${name} ${theme.fg("dim", detail)}`;
}

export function renderWidget(
  state: UiState,
  theme: Theme,
  width: number,
  now = Date.now(),
): string[] {
  const fit = (line: string) => truncateToWidth(line, Math.max(1, width));
  if (state.error) {
    return [
      fit(theme.fg("warning", `Agents · ${label(state.error)}`)),
      fit(theme.fg("dim", "/agents-ui to reconnect")),
    ];
  }
  if (!state.connected) return [fit(theme.fg("dim", "Agents · connecting to pi-subagents…"))];
  if (state.rows.length === 0) return [];
  const active = state.rows.filter((row) => ["running", "queued", "paused"].includes(row.state));
  const recent = state.rows.filter((row) => !active.includes(row)).slice(-2);
  const shown = [...active, ...recent].slice(0, 5);
  const lines = [
    theme.bold("Agents") + theme.fg("dim", ` · ${active.length} active · /agents-ui`),
    ...shown.map((row) => rowLine(row, theme, now)),
  ];
  const hidden = state.rows.length - shown.length + state.omitted;
  if (hidden > 0) lines.push(theme.fg("dim", `  +${hidden} more · open inspector`));
  return lines.map(fit);
}

export interface InspectorResult {
  action: "close" | "steer" | "stop";
  row?: AgentRow;
  selectedKey?: string;
}

export class FleetInspector implements Component {
  private controller: FleetController;
  private tui: TUI;
  private theme: Theme;
  private keys: KeybindingsManager;
  private done: (result: InspectorResult) => void;
  private unsubscribe: () => void;
  private selectedKey?: string;
  private transcriptKey?: string;
  private transcript = "Select an agent to read its transcript.";
  private loading = false;
  private requestVersion = 0;
  private needsRefresh = false;
  private closed = false;
  private offset = 0;
  private follow = true;
  private pane: "fleet" | "transcript" = "fleet";
  private layoutWidth = 0;
  private layoutLines: string[] = [];
  private layoutText = "";

  constructor(
    controller: FleetController,
    tui: TUI,
    theme: Theme,
    keys: KeybindingsManager,
    done: (result: InspectorResult) => void,
    selectedKey?: string,
  ) {
    this.controller = controller;
    this.tui = tui;
    this.theme = theme;
    this.keys = keys;
    this.done = done;
    this.selectedKey = selectedKey;
    this.unsubscribe = controller.subscribe(() => {
      this.reconcileSelection();
      void this.loadTranscript();
      this.tui.requestRender();
    });
    this.reconcileSelection();
    void this.loadTranscript();
  }

  private selected(): AgentRow | undefined {
    return this.controller.state.rows.find((row) => row.key === this.selectedKey);
  }

  private reconcileSelection(): void {
    if (!this.selected()) this.selectedKey = this.controller.state.rows[0]?.key;
  }

  private async loadTranscript(): Promise<void> {
    const row = this.selected();
    if (this.closed) return;
    if (!row) {
      this.requestVersion++;
      this.loading = false;
      this.needsRefresh = false;
      this.transcriptKey = undefined;
      this.transcript = "Select an agent to read its transcript.";
      return;
    }
    if (this.loading && this.transcriptKey === row.key) {
      this.needsRefresh = true;
      return;
    }
    const version = ++this.requestVersion;
    const changed = this.transcriptKey !== row.key;
    this.transcriptKey = row.key;
    this.loading = true;
    if (changed) {
      this.transcript = "Loading transcript…";
      this.follow = true;
      this.offset = 0;
    }
    try {
      const text = await this.controller.inspect(row);
      if (!this.closed && version === this.requestVersion) this.transcript = text;
    } catch (error) {
      if (!this.closed && version === this.requestVersion) {
        this.transcript = label(error instanceof Error ? error.message : String(error));
      }
    } finally {
      if (!this.closed && version === this.requestVersion) {
        this.loading = false;
        this.tui.requestRender();
        if (this.needsRefresh) {
          this.needsRefresh = false;
          void this.loadTranscript();
        }
      }
    }
  }

  private finish(action: InspectorResult["action"]): void {
    this.done({ action, row: this.selected(), selectedKey: this.selectedKey });
  }

  handleInput(data: string): void {
    if (this.keys.matches(data, "tui.select.cancel") || matchesKey(data, "ctrl+c")) {
      this.finish("close");
      return;
    }
    if (matchesKey(data, "tab") || this.keys.matches(data, "tui.select.confirm")) {
      this.pane = this.pane === "fleet" ? "transcript" : "fleet";
    } else if (data === "r") {
      void this.controller.refresh();
      void this.loadTranscript();
    } else if (data === "s" && this.selected() && canSteer(this.selected()!)) {
      this.finish("steer");
      return;
    } else if (data === "x" && this.selected() && canStop(this.selected()!)) {
      this.finish("stop");
      return;
    } else if (matchesKey(data, "end")) {
      this.follow = true;
    } else if (matchesKey(data, "home")) {
      this.offset = 0;
      this.follow = false;
    } else if (
      this.keys.matches(data, "tui.select.up") ||
      this.keys.matches(data, "tui.select.down") ||
      matchesKey(data, "pageUp") ||
      matchesKey(data, "pageDown")
    ) {
      const down = this.keys.matches(data, "tui.select.down") || matchesKey(data, "pageDown");
      const page = matchesKey(data, "pageUp") || matchesKey(data, "pageDown");
      if (this.pane === "fleet" && !page) {
        const rows = this.controller.state.rows;
        const index = rows.findIndex((row) => row.key === this.selectedKey);
        this.selectedKey =
          rows[Math.max(0, Math.min(rows.length - 1, index + (down ? 1 : -1)))]?.key;
        void this.loadTranscript();
      } else {
        this.follow = false;
        this.offset = Math.max(0, this.offset + (down ? 1 : -1) * (page ? 8 : 1));
      }
    } else return;
    this.tui.requestRender();
  }

  render(width: number): string[] {
    const w = Math.max(1, width);
    const height = Math.max(6, this.tui.terminal.rows - 4);
    const rows = this.controller.state.rows;
    const selectedIndex = rows.findIndex((row) => row.key === this.selectedKey);
    const listSize = Math.min(5, Math.max(1, Math.floor(height / 3)));
    const start = Math.max(0, selectedIndex - listSize + 1);
    const selected = this.selected();
    const lines = [
      this.theme.fg("accent", this.theme.bold("Agents")) +
        this.theme.fg("dim", ` · ${rows.length} runs · ${this.pane} focused`),
    ];
    if (this.controller.state.error)
      lines.push(this.theme.fg("warning", label(this.controller.state.error)));
    if (rows.length === 0)
      lines.push(
        this.theme.fg(
          "muted",
          "No agents yet. Ask Pi to delegate a task; this UI does not launch work.",
        ),
      );
    else
      lines.push(
        ...rows
          .slice(start, start + listSize)
          .map((row) => rowLine(row, this.theme, Date.now(), row.key === this.selectedKey)),
      );
    if (rows.length > listSize)
      lines.push(this.theme.fg("dim", `${selectedIndex + 1}/${rows.length} · ↑↓ select`));
    lines.push(this.theme.fg("dim", "─".repeat(w)));
    if (selected) {
      const title =
        selected.kind === "workflow"
          ? "Workflow overview · actions target the whole run"
          : "Transcript · latest 160 source lines";
      lines.push(this.theme.fg("muted", `${title}${this.loading ? " · updating" : ""}`));
      lines.push(
        this.theme.fg(
          "dim",
          [
            selected.agent,
            selected.model,
            selected.kind === "foreground" ? "foreground · read-only controls" : "",
          ]
            .filter(Boolean)
            .join(" · "),
        ),
      );
    }
    const footer = [
      "Tab/Enter switch pane",
      "↑↓ move",
      "PgUp/PgDn scroll",
      "End follow",
      "r refresh",
      ...(selected && canSteer(selected) ? ["s steer"] : []),
      ...(selected && canStop(selected) ? ["x stop"] : []),
      "Esc close",
    ].join(" · ");
    const bodyHeight = Math.max(1, height - lines.length - 2);
    if (this.layoutWidth !== w || this.layoutText !== this.transcript) {
      this.layoutWidth = w;
      this.layoutText = this.transcript;
      this.layoutLines = this.transcript.split("\n").flatMap((line) => wrapTextWithAnsi(line, w));
    }
    const maxOffset = Math.max(0, this.layoutLines.length - bodyHeight);
    this.offset = this.follow ? maxOffset : Math.min(this.offset, maxOffset);
    lines.push(...this.layoutLines.slice(this.offset, this.offset + bodyHeight));
    lines.push(
      this.theme.fg(
        "dim",
        this.follow ? "Following latest output" : "Scroll paused · End to follow",
      ),
    );
    lines.push(this.theme.fg("dim", footer));
    return lines.map((line) => truncateToWidth(line, w));
  }

  invalidate(): void {
    this.layoutWidth = 0;
  }

  dispose(): void {
    this.closed = true;
    this.requestVersion++;
    this.unsubscribe();
  }
}
