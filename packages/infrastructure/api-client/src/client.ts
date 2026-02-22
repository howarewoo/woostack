import { createORPCClient } from "@orpc/client";
import { RPCLink } from "@orpc/client/fetch";
import type { RouterClient } from "@orpc/server";
import { createTanstackQueryUtils } from "@orpc/tanstack-query";

export interface ApiClientOptions {
  /** Async function that returns the current auth token, or undefined if not authenticated. */
  getToken?: () => Promise<string | undefined>;
}

// biome-ignore lint/suspicious/noExplicitAny: oRPC's AnyRouter type requires `any` constraint — using `unknown` causes TS2344/TS2345
export function createApiClient<TRouter extends Record<string, any>>(
  baseUrl: string,
  options?: ApiClientOptions
): RouterClient<TRouter> {
  const link = new RPCLink({
    url: baseUrl,
    headers: options?.getToken
      ? async () => {
          const token = await options.getToken!();
          return token ? { Authorization: `Bearer ${token}` } : {};
        }
      : undefined,
  });

  return createORPCClient(link);
}

// biome-ignore lint/suspicious/noExplicitAny: oRPC's NestedClient type requires `any` constraint — using `unknown` causes TS2345
export function createOrpcUtils<TClient extends Record<string, any>>(client: TClient) {
  return createTanstackQueryUtils(client);
}
