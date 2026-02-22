import type { RouterClient } from "@orpc/server";
import type { ApiClientOptions } from "./client";
import { createApiClient, createOrpcUtils } from "./client";
import type { Router } from "./generated/router-types";

/** Creates an API client pre-typed with the generated Router type. */
export function createTypedApiClient(
  baseUrl: string,
  options?: ApiClientOptions
): RouterClient<Router> {
  return createApiClient<Router>(baseUrl, options);
}

/** Creates TanStack Query utils pre-typed with the generated Router type. */
export function createTypedOrpcUtils(client: RouterClient<Router>) {
  return createOrpcUtils(client);
}
