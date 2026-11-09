import assert from "node:assert/strict";
import test from "node:test";
import { visibleWidth, type KeybindingsManager, type TUI } from "@earendil-works/pi-tui";
import type { Theme } from "@earendil-works/pi-coding-agent";
import { FleetInspector, renderWidget } from "../src/view.ts";
import { cleanText, duration, foregroundRows, parseFleet } from "../src/model.ts";
import { FleetController } from "../src/controller.ts";
import { agent, Bus, deferred, ping, snapshot, tick } from "./helpers.ts";

const theme = {
  fg: (_color: string, text: string) => text,
  bold: (text: string) => text,
} as Theme;
const tui = { terminal: { rows: 30 }, requestRender() {} } as TUI;
const keys = {
  matches: (data: string, action: string) =>
    ({
      "tui.select.up": "up",
      "tui.select.down": "down",
      "tui.select.confirm": "enter",
      "tui.select.cancel": "esc",
    })[action] === data,
} as KeybindingsManager;

test("normalizes versioned snapshots without deriving IDs from opaque fleet keys", () => {
  const data = {
    ...snapshot([agent, agent, null, { kind: "subagent", label: "missing id" }]),
    fleet: { entries: [{ key: "opaque", goal: "not a run id" }] },
  };
  const fleet = parseFleet(data);
  assert.equal(fleet.rows.length, 1);
  assert.equal(fleet.rows[0].runId, "actual-run-id");
  assert.throws(() => parseFleet({ fleet: data.fleet }), /snapshot v1/);
  assert.deepEqual(foregroundRows({ runId: "run", results: [{ agent: "no explicit index" }] }), []);
});

test("strips terminal escape sequences, controls and bidi overrides from child output", () => {
  assert.equal(cleanText("\x1b[31mred\x1b[0m\x1b]52;c;secret\x07\r\u202e!\t你好"), "red!  你好");
  assert.equal(cleanText("before\x1bPpayload\x1b\\after"), "beforeafter");
  assert.equal(cleanText("\x1b]8;;https://bad.test\x1b\\link\x1b]8;;\x1b\\"), "link");
});

test("widget remains compact and width-safe for wide characters and long labels", () => {
  const rows = parseFleet(
    snapshot(
      Array.from({ length: 9 }, (_, index) => ({
        ...agent,
        id: `run-${index}`,
        label: "查看代理 🧑‍💻 ".repeat(30),
      })),
    ),
  ).rows;
  for (const width of [1, 12, 40, 100]) {
    const lines = renderWidget({ rows, connected: true, omitted: 2 }, theme, width, 61_000);
    assert.ok(lines.length <= 7);
    assert.ok(lines.every((line) => visibleWidth(line) <= width));
  }
  assert.deepEqual(renderWidget({ rows: [], connected: true, omitted: 0 }, theme, 80), []);
  assert.match(
    renderWidget(
      { rows: [], connected: false, omitted: 0, error: "Missing backend" },
      theme,
      80,
    ).join("\n"),
    /reconnect/,
  );
  assert.equal(duration(1_000, 62_000), "1m 1s");
});

test("inspector navigates and requests actions on a stable selected run", async () => {
  const bus = new Bus();
  bus.handler = (method) =>
    method === "ping" ? ping : snapshot([agent, { ...agent, id: "second", label: "Second" }]);
  const controller = new FleetController(bus, "parent");
  await controller.start();
  bus.handler = () => ({ text: "Latest output\n".repeat(20) });
  let result: unknown;
  const inspector = new FleetInspector(controller, tui, theme, keys, (value) => {
    result = value;
  });
  try {
    await tick();
    inspector.handleInput("down");
    await tick();
    assert.equal(bus.requests.at(-1)?.params.id, "second");
    inspector.handleInput("s");
    assert.equal((result as { row: { runId: string } }).row.runId, "second");
    assert.equal(
      bus.requests.filter((request) => request.method === "steer").length,
      0,
      "view returns an intent; entrypoint owns editor/confirmation",
    );
    for (const width of [1, 20, 80]) {
      assert.ok(inspector.render(width).every((line) => visibleWidth(line) <= width));
    }
    inspector.handleInput("enter");
    inspector.handleInput("up");
    assert.match(inspector.render(100).join("\n"), /Scroll paused/);
    inspector.handleInput("esc");
    assert.equal((result as { action: string }).action, "close");
  } finally {
    inspector.dispose();
    controller.dispose();
  }
});

test("late transcript results cannot replace a newly selected agent", async () => {
  const bus = new Bus();
  bus.handler = (method) =>
    method === "ping" ? ping : snapshot([agent, { ...agent, id: "second", label: "Second" }]);
  const controller = new FleetController(bus, "parent");
  await controller.start();
  const slow = deferred<unknown>();
  bus.handler = (_method, params) =>
    params.id === "actual-run-id" ? slow.promise : { text: "SECOND OUTPUT" };
  const inspector = new FleetInspector(controller, tui, theme, keys, () => {});
  try {
    await tick();
    inspector.handleInput("down");
    await tick();
    slow.resolve({ text: "STALE FIRST OUTPUT" });
    await tick();
    const rendered = inspector.render(100).join("\n");
    assert.match(rendered, /SECOND OUTPUT/);
    assert.doesNotMatch(rendered, /STALE FIRST OUTPUT/);
  } finally {
    inspector.dispose();
    controller.dispose();
  }
});
