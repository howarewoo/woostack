import assert from "node:assert/strict";
import test from "node:test";
import type { Theme } from "@earendil-works/pi-coding-agent";
import type { KeybindingsManager, TUI } from "@earendil-works/pi-tui";
import { FleetController } from "../src/controller.ts";
import { FleetInspector } from "../src/view.ts";
import { agent, Bus, deferred, ping, snapshot, tick } from "./helpers.ts";

test("selection survives reordering and removal clears the old transcript including late replies", async () => {
  const bus = new Bus();
  let runs: unknown[] = [agent, { ...agent, id: "second", label: "Second" }];
  bus.handler = (method, params) =>
    method === "ping" ? ping : params.id ? { text: "OLD TRANSCRIPT" } : snapshot(runs);
  const controller = new FleetController(bus, "parent");
  await controller.start();
  const theme = {
    fg: (_color: string, text: string) => text,
    bold: (text: string) => text,
  } as Theme;
  const tui = { terminal: { rows: 30 }, requestRender() {} } as TUI;
  const inspector = new FleetInspector(
    controller,
    tui,
    theme,
    { matches: () => false } as unknown as KeybindingsManager,
    () => {},
  );
  try {
    await tick();
    runs.reverse();
    await controller.refresh();
    await tick();
    assert.equal(bus.requests.at(-1)?.params.id, "actual-run-id");
    const late = deferred<unknown>();
    bus.handler = (_method, params) => (params.id ? late.promise : snapshot(runs));
    inspector.handleInput("r");
    await tick();
    runs = [];
    await controller.refresh();
    late.resolve({ text: "LATE TRANSCRIPT" });
    await tick();
    const rendered = inspector.render(100).join("\n");
    assert.match(rendered, /No agents yet/);
    assert.doesNotMatch(rendered, /OLD TRANSCRIPT|LATE TRANSCRIPT/);
  } finally {
    inspector.dispose();
    controller.dispose();
  }
});
