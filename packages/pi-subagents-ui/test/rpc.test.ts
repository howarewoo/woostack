import assert from "node:assert/strict";
import test from "node:test";
import { RpcClient } from "../src/rpc.ts";
import { Bus } from "./helpers.ts";

test("RPC correlates replies, ignores foreign envelopes, and removes listeners", async () => {
  const bus = new Bus();
  const client = new RpcClient(bus);
  const pending = client.request("status");
  const { requestId } = bus.requests[0];
  bus.emit(`subagents:rpc:v1:reply:${requestId}`, {
    version: 2,
    requestId,
    success: true,
    data: "wrong version",
  });
  bus.emit(`subagents:rpc:v1:reply:${requestId}`, {
    version: 1,
    requestId: "other",
    success: true,
    data: "wrong id",
  });
  bus.reply(requestId, { text: "right" });
  assert.deepEqual(await pending, { text: "right" });
  assert.equal(bus.listeners.size, 0);
  client.dispose();
});

test("a mutation timeout reports unknown outcome without retrying", async () => {
  const bus = new Bus();
  const client = new RpcClient(bus);
  await assert.rejects(client.request("stop", { id: "run" }, 10), /outcome is unknown/);
  assert.equal(bus.requests.length, 1);
  assert.equal(bus.listeners.size, 0);
  client.dispose();
});

test("RPC shutdown rejects pending requests and prevents further dispatch", async () => {
  const bus = new Bus();
  const client = new RpcClient(bus);
  const pending = client.request("status");
  client.dispose();
  await assert.rejects(pending, /session closed/);
  await assert.rejects(client.request("stop"), /session closed/);
  assert.equal(bus.requests.length, 1);
  assert.equal(bus.listeners.size, 0);
});

test("RPC surfaces backend errors and synchronous transport failures", async () => {
  const bus = new Bus();
  bus.handler = () => {
    throw new Error("not owned by this session");
  };
  const client = new RpcClient(bus);
  await assert.rejects(client.request("stop"), /not owned/);
  assert.equal(bus.listeners.size, 0);
  const broken = new RpcClient({
    on: () => () => {},
    emit: () => {
      throw new Error("offline");
    },
  });
  await assert.rejects(broken.request("status"), /offline/);
  broken.dispose();
  client.dispose();
});
