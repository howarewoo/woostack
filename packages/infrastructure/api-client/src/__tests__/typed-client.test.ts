import { describe, expect, it, vi } from "vitest";

let capturedRPCLinkOptions: Record<string, unknown>;

vi.mock("@orpc/client", () => ({
  createORPCClient: vi.fn(() => ({ mocked: true })),
}));

vi.mock("@orpc/client/fetch", () => ({
  RPCLink: vi.fn(function (this: unknown, options: Record<string, unknown>) {
    capturedRPCLinkOptions = options;
  }),
}));

vi.mock("@orpc/tanstack-query", () => ({
  createTanstackQueryUtils: vi.fn((client: unknown) => ({
    client,
    utils: true,
  })),
}));

import { createTypedApiClient, createTypedOrpcUtils } from "../typed-client";

describe("createTypedApiClient", () => {
  it("creates a pre-typed client for the given base URL", () => {
    const client = createTypedApiClient("http://localhost:3001/api");
    expect(client).toBeDefined();
  });

  it("passes getToken option through to RPCLink headers", async () => {
    const getToken = vi.fn().mockResolvedValue("typed-jwt-token");

    createTypedApiClient("http://localhost:3001/api", { getToken });

    expect(capturedRPCLinkOptions.headers).toBeInstanceOf(Function);
    const headersFn = capturedRPCLinkOptions.headers as () => Promise<Record<string, string>>;
    const headers = await headersFn();
    expect(headers).toEqual({ Authorization: "Bearer typed-jwt-token" });
  });
});

describe("createTypedOrpcUtils", () => {
  it("creates pre-typed tanstack query utils from a typed client", () => {
    const client = createTypedApiClient("http://localhost:3001/api");
    const utils = createTypedOrpcUtils(client);
    expect(utils).toBeDefined();
  });
});
