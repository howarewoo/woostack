import type {
  Notification,
  NotificationChannel,
  NotificationResult,
} from "./types";

/** Dispatches notifications through one or more configured channels. */
export class NotificationService {
  private channels: NotificationChannel[] = [];

  /** Register a channel for notification delivery. */
  addChannel(channel: NotificationChannel): void {
    this.channels.push(channel);
  }

  /**
   * Send a notification through all registered channels.
   * Returns one result per channel. Channels that throw are reported as failures.
   */
  async send(notification: Notification): Promise<NotificationResult[]> {
    if (this.channels.length === 0) {
      throw new Error(
        "No notification channels configured. Add at least one channel before sending.",
      );
    }

    const results = await Promise.all(
      this.channels.map(async (channel) => {
        try {
          return await channel.send(notification);
        } catch (err) {
          const message =
            err instanceof Error ? err.message : "Unknown error";
          return {
            channel: channel.name,
            success: false,
            error: message,
          } satisfies NotificationResult;
        }
      }),
    );

    return results;
  }
}
