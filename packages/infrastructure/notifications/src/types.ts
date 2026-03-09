/** A notification to be dispatched through one or more channels. */
export interface Notification {
  /** Recipient identifier (email address, user ID, device token, etc.). */
  to: string;
  /** Short summary or subject line. */
  subject: string;
  /** Notification body content. */
  body: string;
  /** Optional key-value metadata for channel-specific extensions. */
  metadata?: Record<string, string>;
}

/** Result of sending a single notification through a channel. */
export interface NotificationResult {
  /** Name of the channel that processed the notification. */
  channel: string;
  /** Whether the send succeeded. */
  success: boolean;
  /** Error message when `success` is `false`. */
  error?: string;
}

/** A delivery channel capable of sending notifications. */
export interface NotificationChannel {
  /** Unique name identifying this channel (e.g. "console", "email", "push"). */
  readonly name: string;
  /** Send a notification and return the result. */
  send(notification: Notification): Promise<NotificationResult>;
}
