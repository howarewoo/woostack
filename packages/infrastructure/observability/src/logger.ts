import pino, { type Level, type Logger } from "pino";

export interface LoggerOptions {
  /** Service name included in every log line */
  serviceName: string;
  /** Log level (default: "info") */
  level?: Level;
}

/**
 * Creates a structured JSON logger backed by pino.
 *
 * Every log entry includes the `service` binding so logs from
 * different services can be filtered in aggregation tools.
 */
export function createLogger({ serviceName, level = "info" }: LoggerOptions): Logger {
  return pino({
    level,
    base: { service: serviceName },
  });
}
