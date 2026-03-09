import { describe, expect, it } from "vitest";
import { createLogger } from "../logger";

describe("createLogger", () => {
  it("returns a pino logger with the given service name", () => {
    const logger = createLogger({ serviceName: "test-service" });
    expect(logger).toBeDefined();
    expect(typeof logger.info).toBe("function");
    expect(typeof logger.error).toBe("function");
    expect(typeof logger.warn).toBe("function");
    expect(typeof logger.debug).toBe("function");
  });

  it("defaults to info level", () => {
    const logger = createLogger({ serviceName: "test-service" });
    expect(logger.level).toBe("info");
  });

  it("respects a custom log level", () => {
    const logger = createLogger({ serviceName: "test-service", level: "debug" });
    expect(logger.level).toBe("debug");
  });

  it("includes the service name in bindings", () => {
    const logger = createLogger({ serviceName: "my-api" });
    const bindings = logger.bindings();
    expect(bindings.service).toBe("my-api");
  });
});
