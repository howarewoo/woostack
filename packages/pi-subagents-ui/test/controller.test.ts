import assert from "node:assert/strict";
import test from "node:test";
import { FleetController } from "../src/controller.ts";
import { agent, Bus, deferred, ping, snapshot, tick, workflow } from "./helpers.ts";

function setup(runs = [agent, workflow]) {
  const bus = new Bus();
  bus.handler = (method, params) =>
    method === "ping"
      ? ping
      : method === "status" && !params.id
        ? snapshot(runs)
        : { text: "runtime text" };
  const controller = new FleetController(bus, "parent");
  return { bus, controller };
}

test("connects through public RPC and targets real run IDs, not fleet display keys", async () => {
  const { controller, bus } = setup();
  try {
    await controller.start();
    assert.equal(controller.state.connected, true);
    assert.equal(controller.state.rows.length, 2);
    const row = controller.state.rows[0];
    await controller.inspect(row);
    assert.deepEqual(bus.requests.at(-1)?.params, {
      id: "actual-run-id",
      view: "transcript",
      lines: 160,
    });
    await controller.steer(row, "Check the boundary");
    assert.equal(bus.requests.at(-1)?.params.id, "actual-run-id");
    const receipt = await controller.stop(row);
    assert.match(receipt, /not proof/);
    assert.equal(controller.state.rows[0].state, "running");
    assert.equal(bus.requests.at(-1)?.method, "stop");
  } finally {
    controller.dispose();
  }
});

test("workflows get an overview and whole-run stop, never accidental first-child steering", async () => {
  const { controller, bus } = setup();
  try {
    await controller.start();
    const row = controller.state.rows[1];
    await controller.inspect(row);
    assert.deepEqual(bus.requests.at(-1)?.params, { id: "workflow-id", view: "fleet", lines: 160 });
    await assert.rejects(controller.steer(row, "wrong child"), /only for a running/);
    assert.equal(bus.requests.filter((request) => request.method === "steer").length, 0);
    await controller.stop(row);
    assert.deepEqual(bus.requests.at(-1)?.params, { id: "workflow-id" });
  } finally {
    controller.dispose();
  }
});

test("refreshes on notifications, coalesces bursts, and preserves an event during an in-flight read", async () => {
  const { controller, bus } = setup();
  try {
    await controller.start();
    const pending = deferred<unknown>();
    let reads = 0;
    bus.handler = (method) => {
      if (method !== "status") return ping;
      reads++;
      return reads === 1 ? pending.promise : snapshot([{ ...agent, state: "complete" }]);
    };
    const refresh = controller.refresh();
    await tick();
    for (let index = 0; index < 10; index++) bus.emit("subagent:jobs-changed", {});
    pending.resolve(snapshot([agent]));
    await refresh;
    await new Promise((resolve) => setTimeout(resolve, 220));
    assert.equal(reads, 2);
    assert.equal(controller.state.rows[0].state, "complete");
    const after = bus.requests.length;
    await new Promise((resolve) => setTimeout(resolve, 200));
    assert.equal(bus.requests.length, after, "no periodic runtime polling");
  } finally {
    controller.dispose();
  }
});

test("rejects another parent session and incompatible snapshot capabilities", async () => {
  for (const response of [
    { ...ping, session: { sessionId: "foreign" } },
    { ...ping, capabilities: {} },
  ]) {
    const { controller, bus } = setup();
    bus.handler = () => response;
    await controller.start();
    assert.equal(controller.state.connected, false);
    assert.ok(controller.state.error);
    assert.deepEqual(
      bus.requests.map((request) => request.method),
      ["ping"],
    );
    controller.dispose();
  }
});

test("reconciles selection state before mutation and rejects a stale running row", async () => {
  const { controller, bus } = setup();
  try {
    await controller.start();
    const old = controller.state.rows[0];
    bus.handler = (method) =>
      method === "status" ? snapshot([{ ...agent, state: "complete" }]) : {};
    await controller.refresh();
    await assert.rejects(controller.steer(old, "too late"), /only for a running/);
    await assert.rejects(controller.stop(old), /cannot be stopped/);
    assert.equal(
      bus.requests.filter((request) => ["stop", "steer"].includes(request.method)).length,
      0,
    );
  } finally {
    controller.dispose();
  }
});

test("foreground results use explicit indices and remain read-only in the UI", async () => {
  const { controller, bus } = setup([]);
  try {
    await controller.start();
    controller.observeForeground({
      runId: "foreground-run",
      results: [{ index: 7, agent: "reviewer" }],
    });
    const row = controller.state.rows[0];
    await controller.inspect(row);
    assert.equal(bus.requests.at(-1)?.params.index, 7);
    await assert.rejects(controller.stop(row), /cannot be stopped/);
    controller.observeForeground(
      { runId: "foreground-run", results: [{ index: 7, agent: "reviewer" }] },
      "failed",
    );
    assert.equal(controller.state.rows[0].state, "failed");
  } finally {
    controller.dispose();
  }
});

test("disposal removes subscriptions and discards a late status reply", async () => {
  const { controller, bus } = setup();
  await controller.start();
  const held = deferred<unknown>();
  bus.handler = () => held.promise;
  const pending = controller.refresh();
  controller.dispose();
  held.resolve(snapshot([]));
  await pending;
  assert.equal(controller.state.rows.length, 2);
  assert.equal(bus.listeners.size, 0);
});
