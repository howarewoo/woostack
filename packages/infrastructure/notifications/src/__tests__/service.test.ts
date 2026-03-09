import { describe, expect, it, vi } from "vitest";
import { NotificationService } from "../service";
import type { Notification, NotificationChannel } from "../types";

describe("NotificationService", () => {
  const notification: Notification = {
    to: "user@example.com",
    subject: "Hello",
    body: "World",
    metadata: { priority: "high" },
  };

  function createMockChannel(
    name: string,
    success = true,
  ): NotificationChannel {
    return {
      name,
      send: vi.fn(async () => ({ channel: name, success })),
    };
  }

  it("throws when no channels are configured", async () => {
    const service = new NotificationService();
    await expect(service.send(notification)).rejects.toThrow(
      "No notification channels configured",
    );
  });

  it("dispatches to a single channel", async () => {
    const service = new NotificationService();
    const channel = createMockChannel("email");
    service.addChannel(channel);

    const results = await service.send(notification);

    expect(results).toHaveLength(1);
    expect(results[0]).toEqual({ channel: "email", success: true });
    expect(channel.send).toHaveBeenCalledWith(notification);
  });

  it("dispatches to multiple channels", async () => {
    const service = new NotificationService();
    const email = createMockChannel("email");
    const push = createMockChannel("push");
    service.addChannel(email);
    service.addChannel(push);

    const results = await service.send(notification);

    expect(results).toHaveLength(2);
    expect(results[0]).toEqual({ channel: "email", success: true });
    expect(results[1]).toEqual({ channel: "push", success: true });
  });

  it("catches channel errors and reports them as failures", async () => {
    const service = new NotificationService();
    const failing: NotificationChannel = {
      name: "broken",
      send: vi.fn(async () => {
        throw new Error("connection refused");
      }),
    };
    service.addChannel(failing);

    const results = await service.send(notification);

    expect(results).toHaveLength(1);
    expect(results[0]).toEqual({
      channel: "broken",
      success: false,
      error: "connection refused",
    });
  });

  it("handles mixed success and failure across channels", async () => {
    const service = new NotificationService();
    const good = createMockChannel("email");
    const bad: NotificationChannel = {
      name: "push",
      send: vi.fn(async () => {
        throw new Error("timeout");
      }),
    };
    service.addChannel(good);
    service.addChannel(bad);

    const results = await service.send(notification);

    expect(results).toHaveLength(2);
    expect(results[0]).toEqual({ channel: "email", success: true });
    expect(results[1]).toEqual({
      channel: "push",
      success: false,
      error: "timeout",
    });
  });

  it("handles non-Error thrown values", async () => {
    const service = new NotificationService();
    const weird: NotificationChannel = {
      name: "weird",
      send: vi.fn(async () => {
        throw "string error";
      }),
    };
    service.addChannel(weird);

    const results = await service.send(notification);

    expect(results[0]).toEqual({
      channel: "weird",
      success: false,
      error: "Unknown error",
    });
  });
});
