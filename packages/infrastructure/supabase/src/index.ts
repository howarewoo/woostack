// Types

export type { AuthContextValue, AuthState } from "./auth";
// Auth
export { AuthProvider, useAuth, useUser } from "./auth";
export { createBrowserClient } from "./clients/browser";
export { createSSRBrowserClient } from "./clients/browser-ssr";
// Clients
export { createServerClient } from "./clients/server";
export { createSSRServerClient } from "./clients/server-ssr";
export type { Database } from "./generated/database";
// Middleware (consumers use subpath imports, but also available from main)
export { supabaseMiddleware } from "./middleware/hono";
export { createSupabaseMiddleware } from "./middleware/nextjs";
// Storage
export { createStorageClient } from "./storage/storage";
export type {
  Enums,
  SupabaseUser,
  Tables,
  TablesInsert,
  TablesUpdate,
  TypedSupabaseClient,
} from "./types";
