import type { Notification, NotificationChannel, NotificationResult } from "./types";

/** A notification channel that logs to the console. Useful for local development. */
export class ConsoleChannel implements NotificationChannel {
  readonly name = "console";

  /** Send a notification by logging it to `console.log`. */
  async send(notification: Notification): Promise<NotificationResult> {
    console.log(
      `[notification] to=${notification.to} subject="${notification.subject}" body="${notification.body}"`
    );
    return { channel: this.name, success: true };
  }
}
