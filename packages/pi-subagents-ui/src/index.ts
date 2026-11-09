import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import type { TUI } from "@earendil-works/pi-tui";
import { FleetController } from "./controller.ts";
import { label } from "./model.ts";
import { FleetInspector, renderWidget, type InspectorResult } from "./view.ts";

const WIDGET_KEY = "woostack-subagents-ui";

export default function subagentsUi(pi: ExtensionAPI): void {
  let controller: FleetController | undefined;
  let widgetTui: TUI | undefined;
  let clock: ReturnType<typeof setInterval> | undefined;
  let hidden = false;
  let inspectorOpen = false;
  let closeInspector: (() => void) | undefined;

  function showWidget(ctx: ExtensionContext): void {
    if (ctx.mode !== "tui") return;
    if (hidden || !controller) {
      ctx.ui.setWidget(WIDGET_KEY, undefined);
      return;
    }
    const current = controller;
    ctx.ui.setWidget(
      WIDGET_KEY,
      (tui, theme) => {
        widgetTui = tui;
        return {
          render: (width) => renderWidget(current.state, theme, width),
          invalidate() {},
        };
      },
      { placement: "belowEditor" },
    );
  }

  async function openInspector(ctx: ExtensionContext): Promise<void> {
    if (ctx.mode !== "tui") {
      if (ctx.hasUI)
        ctx.ui.notify("The agent inspector requires Pi's interactive terminal mode.", "warning");
      return;
    }
    const current = controller;
    if (!current || inspectorOpen) return;
    inspectorOpen = true;
    let selectedKey: string | undefined;
    try {
      await current.refresh();
      while (controller === current) {
        const result = await ctx.ui.custom<InspectorResult>((tui, theme, keys, done) => {
          closeInspector = () => done({ action: "close" });
          return new FleetInspector(current, tui, theme, keys, done, selectedKey);
        });
        closeInspector = undefined;
        if (controller !== current || !result || result.action === "close") break;
        selectedKey = result.selectedKey;
        const row = result.row;
        if (!row) continue;
        try {
          if (result.action === "steer") {
            const message = await ctx.ui.editor(`Steer ${label(row.label)}`, "");
            if (controller !== current) break;
            if (message?.trim()) ctx.ui.notify(label(await current.steer(row, message)), "info");
          } else {
            const scope =
              row.kind === "workflow" ? "the entire workflow and its children" : "this agent";
            const confirmed = await ctx.ui.confirm(
              `Stop ${label(row.label)}?`,
              `Request a stop for ${scope}. This does not delete work or prove processes have exited.`,
            );
            if (controller !== current) break;
            if (confirmed) ctx.ui.notify(await current.stop(row), "info");
          }
        } catch (error) {
          if (controller === current)
            ctx.ui.notify(label(error instanceof Error ? error.message : String(error)), "error");
        }
      }
    } finally {
      inspectorOpen = false;
      closeInspector = undefined;
    }
  }

  pi.on("session_start", async (_event, ctx) => {
    if (ctx.mode !== "tui") return;
    clearInterval(clock);
    controller?.dispose();
    const current = new FleetController(pi.events, ctx.sessionManager.getSessionId());
    controller = current;
    showWidget(ctx);
    current.subscribe(() => widgetTui?.requestRender());
    // Clock updates redraw local text only. Runtime data is event-driven, not polled.
    clock = setInterval(() => {
      if (current.state.rows.some((row) => row.state === "running")) widgetTui?.requestRender();
    }, 1_000);
    clock.unref();
    await current.start();
  });

  pi.on("tool_execution_update", (event) => {
    if (event.toolName === "subagent") controller?.observeForeground(event.partialResult?.details);
  });
  pi.on("tool_execution_end", (event) => {
    if (event.toolName === "subagent")
      controller?.observeForeground(event.result?.details, event.isError ? "failed" : "finished");
  });

  pi.on("session_shutdown", (_event, ctx) => {
    const previous = controller;
    controller = undefined;
    closeInspector?.();
    clearInterval(clock);
    previous?.dispose();
    widgetTui = undefined;
    if (ctx.mode === "tui") ctx.ui.setWidget(WIDGET_KEY, undefined);
  });

  pi.registerCommand("agents-ui", {
    description: "Inspect subagents, read transcripts, steer or stop; show/hide the fleet panel",
    getArgumentCompletions: (prefix) =>
      ["show", "hide"]
        .filter((value) => value.startsWith(prefix))
        .map((value) => ({ value, label: value })),
    handler: async (args, ctx) => {
      if (args.trim() === "hide" || args.trim() === "show") {
        hidden = args.trim() === "hide";
        showWidget(ctx);
      } else if (args.trim()) {
        if (ctx.hasUI)
          ctx.ui.notify("Use /agents-ui, /agents-ui show, or /agents-ui hide.", "warning");
      } else await openInspector(ctx);
    },
  });
  pi.registerShortcut("ctrl+shift+u", {
    description: "Open the subagent fleet inspector",
    handler: openInspector,
  });
}
