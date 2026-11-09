import assert from "node:assert/strict";
import test from "node:test";
import type {
  ExtensionAPI,
  ExtensionContext,
  ExtensionCommandContext,
  Theme,
} from "@earendil-works/pi-coding-agent";
import type { KeybindingsManager, TUI } from "@earendil-works/pi-tui";
import extension from "../src/index.ts";
import type { FleetInspector } from "../src/view.ts";
import { agent, Bus, ping, snapshot, tick, workflow } from "./helpers.ts";

type Handler = (event: unknown, ctx: ExtensionContext) => unknown;

function host(mode = "tui", runs: unknown[] = [agent]) {
  const bus = new Bus();
  bus.handler = (method, params) =>
    method === "ping"
      ? ping
      : method === "status" && !params.id
        ? snapshot(runs)
        : { text: "acknowledged" };
  const events = new Map<string, Handler>();
  const commands = new Map<
    string,
    { handler: (args: string, ctx: ExtensionCommandContext) => Promise<void> }
  >();
  const widgets: unknown[] = [];
  const confirmations: string[] = [];
  const notifications: string[] = [];
  let confirm = false;
  let draft: string | undefined;
  let inspector: FleetInspector | undefined;
  const theme = { fg: (_key: string, text: string) => text, bold: (text: string) => text } as Theme;
  const tui = { terminal: { rows: 30 }, requestRender() {} } as TUI;
  const keys = {
    matches: (data: string, action: string) => action === "tui.select.cancel" && data === "esc",
  } as KeybindingsManager;
  const ctx = {
    mode,
    hasUI: mode !== "print",
    sessionManager: { getSessionId: () => "parent" },
    ui: {
      setWidget: (...args: unknown[]) => widgets.push(args),
      notify: (text: string) => notifications.push(text),
      confirm: async (_title: string, description: string) => {
        confirmations.push(description);
        return confirm;
      },
      editor: async () => draft,
      custom: async (
        factory: (
          tui: TUI,
          theme: Theme,
          keys: KeybindingsManager,
          done: (value: unknown) => void,
        ) => FleetInspector,
      ) =>
        new Promise((resolve) => {
          inspector = factory(tui, theme, keys, (value) => {
            inspector?.dispose();
            inspector = undefined;
            resolve(value);
          });
        }),
    },
  } as unknown as ExtensionCommandContext;
  extension({
    events: bus,
    on: (name: string, handler: Handler) => events.set(name, handler),
    registerCommand: (
      name: string,
      command: typeof commands extends Map<string, infer V> ? V : never,
    ) => commands.set(name, command),
    registerShortcut() {},
  } as unknown as ExtensionAPI);
  return {
    bus,
    events,
    widgets,
    confirmations,
    notifications,
    ctx,
    inspector: () => inspector,
    confirm: (value: boolean) => {
      confirm = value;
    },
    draft: (value?: string) => {
      draft = value;
    },
    start: () => events.get("session_start")!({}, ctx),
    shutdown: () => events.get("session_shutdown")!({}, ctx),
    open: () => commands.get("agents-ui")!.handler("", ctx),
    command: (args: string) => commands.get("agents-ui")!.handler(args, ctx),
  };
}

async function ready(getInspector: () => FleetInspector | undefined): Promise<FleetInspector> {
  for (let index = 0; index < 50; index++) {
    const inspector = getInspector();
    if (inspector) return inspector;
    await tick();
  }
  throw new Error("Inspector did not open.");
}

test("entrypoint requests no stop until confirmed and labels workflow-wide scope", async () => {
  const app = host("tui", [workflow]);
  await app.start();
  const opened = app.open();
  try {
    (await ready(app.inspector)).handleInput("x");
    await tick();
    await ready(app.inspector);
    assert.match(app.confirmations[0], /entire workflow and its children/);
    assert.equal(app.bus.requests.filter((request) => request.method === "stop").length, 0);
    app.confirm(true);
    app.inspector()!.handleInput("x");
    await tick();
    await ready(app.inspector);
    assert.equal(app.bus.requests.filter((request) => request.method === "stop").length, 1);
    assert.match(app.notifications.at(-1)!, /not proof/);
    app.inspector()!.handleInput("esc");
    await opened;
  } finally {
    app.shutdown();
  }
});

test("steering editor cancellation dispatches nothing and submission targets the selected run", async () => {
  const app = host();
  await app.start();
  const opened = app.open();
  try {
    (await ready(app.inspector)).handleInput("s");
    await tick();
    await ready(app.inspector);
    assert.equal(app.bus.requests.filter((request) => request.method === "steer").length, 0);
    app.draft("Check the tests");
    app.inspector()!.handleInput("s");
    await tick();
    await ready(app.inspector);
    assert.deepEqual(app.bus.requests.find((request) => request.method === "steer")?.params, {
      id: "actual-run-id",
      message: "Check the tests",
      mode: "steer",
    });
    app.inspector()!.handleInput("esc");
    await opened;
  } finally {
    app.shutdown();
  }
});

test("show/hide only touches the extension's widget and shutdown closes its inspector", async () => {
  const app = host();
  await app.start();
  await app.command("hide");
  assert.deepEqual(app.widgets.at(-1), ["woostack-subagents-ui", undefined]);
  const opened = app.open();
  await ready(app.inspector);
  app.shutdown();
  await opened;
  assert.equal(app.bus.listeners.size, 0);
});

test("noninteractive hosts do not request runtime state or create widgets", async () => {
  for (const mode of ["rpc", "print", "sdk"]) {
    const app = host(mode);
    await app.start();
    await app.open();
    app.shutdown();
    assert.equal(app.bus.requests.length, 0);
    assert.equal(app.widgets.length, 0);
  }
});
