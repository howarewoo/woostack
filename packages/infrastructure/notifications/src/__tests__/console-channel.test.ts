import { describe, expect, it, vi } from "vitest";
import { ConsoleChannel } from "../console-channel";
import type { Notification } from "../types";

describe("ConsoleChannel", () => {
  const notification: Notification = {
    to: "user@example.com",
    subject: "Test Subject",
    body: "Test body content",
  };

  it("has the name 'console'", () => {
    const channel = new ConsoleChannel();
    expect(channel.name).toBe("console");
  });

  it("logs the notification to console", async () => {
    const channel = new ConsoleChannel();
    const spy = vi.spyOn(console, "log").mockImplementation(() => {});

    await channel.send(notification);

    expect(spy).toHaveBeenCalledOnce();
    expect(spy).toHaveBeenCalledWith(
      '[notification] to=user@example.com subject="Test Subject" body="Test body content"'
    );

    spy.mockRestore();
  });

  it("returns a successful result", async () => {
    const channel = new ConsoleChannel();
    vi.spyOn(console, "log").mockImplementation(() => {});

    const result = await channel.send(notification);

    expect(result).toEqual({ channel: "console", success: true });
  });
});
