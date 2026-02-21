// Types
export type { Database } from "./generated/database";
export type { TypedSupabaseClient, Tables, TablesInsert, TablesUpdate, Enums } from "./types";
export type { AuthState, AuthContextValue } from "./auth";

// Clients
export { createServerClient } from "./clients/server";
export { createBrowserClient } from "./clients/browser";
export { createSSRServerClient } from "./clients/server-ssr";
export { createSSRBrowserClient } from "./clients/browser-ssr";

// Auth
export { AuthProvider } from "./auth";
export { useAuth, useUser } from "./auth";

// Storage
export { createStorageClient } from "./storage/storage";

// Middleware (consumers use subpath imports, but also available from main)
export { supabaseMiddleware } from "./middleware/hono";
export { createSupabaseMiddleware } from "./middleware/nextjs";
