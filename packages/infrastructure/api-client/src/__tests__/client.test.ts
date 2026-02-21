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

import { createApiClient, createOrpcUtils } from "../client";

describe("createApiClient", () => {
  it("creates a typed client for the given base URL", () => {
    type TestRouter = { health: { message: string } };
    const client = createApiClient<TestRouter>("http://localhost:3001/api");
    expect(client).toBeDefined();
  });

  it("creates RPCLink without headers when getToken is not provided", () => {
    type TestRouter = { health: { message: string } };
    createApiClient<TestRouter>("http://localhost:3001/api");
    expect(capturedRPCLinkOptions.url).toBe("http://localhost:3001/api");
    expect(capturedRPCLinkOptions.headers).toBeUndefined();
  });

  it("creates RPCLink with headers function when getToken is provided", async () => {
    type TestRouter = { health: { message: string } };
    const getToken = vi.fn().mockResolvedValue("test-jwt-token");

    createApiClient<TestRouter>("http://localhost:3001/api", { getToken });

    expect(capturedRPCLinkOptions.headers).toBeInstanceOf(Function);
    const headersFn = capturedRPCLinkOptions.headers as () => Promise<Record<string, string>>;
    const headers = await headersFn();
    expect(headers).toEqual({ Authorization: "Bearer test-jwt-token" });
    expect(getToken).toHaveBeenCalledOnce();
  });

  it("returns empty headers when getToken resolves to undefined", async () => {
    type TestRouter = { health: { message: string } };
    const getToken = vi.fn().mockResolvedValue(undefined);

    createApiClient<TestRouter>("http://localhost:3001/api", { getToken });

    const headersFn = capturedRPCLinkOptions.headers as () => Promise<Record<string, string>>;
    const headers = await headersFn();
    expect(headers).toEqual({});
  });
});

describe("createOrpcUtils", () => {
  it("creates tanstack query utils from a client", () => {
    const mockClient = { users: {} };
    const utils = createOrpcUtils(mockClient);
    expect(utils).toBeDefined();
  });
});
