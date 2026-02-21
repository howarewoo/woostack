// Auth
export type { AuthContextValue, AuthState } from "./auth";
export { AuthProvider, useAuth, useUser } from "./auth";

// Clients
export { createBrowserClient } from "./clients/browser";
export { createSSRBrowserClient } from "./clients/browser-ssr";
export { createServerClient } from "./clients/server";
export { createSSRServerClient } from "./clients/server-ssr";

// Middleware (consumers use subpath imports, but also available from main)
export { supabaseMiddleware } from "./middleware/hono";
export { createSupabaseMiddleware } from "./middleware/nextjs";

// Storage
export { createStorageClient } from "./storage/storage";

// Types
export type { Database } from "./generated/database";
export type {
  Enums,
  SupabaseUser,
  Tables,
  TablesInsert,
  TablesUpdate,
  TypedSupabaseClient,
} from "./types";
