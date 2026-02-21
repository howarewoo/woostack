import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "./generated/database";

/** Supabase client typed with the generated Database schema. */
export type TypedSupabaseClient = SupabaseClient<Database>;

/** Helper to extract a row type from a table name. */
export type Tables<T extends keyof Database["public"]["Tables"]> =
  Database["public"]["Tables"][T]["Row"];

/** Helper to extract an insert type from a table name. */
export type TablesInsert<T extends keyof Database["public"]["Tables"]> =
  Database["public"]["Tables"][T]["Insert"];

/** Helper to extract an update type from a table name. */
export type TablesUpdate<T extends keyof Database["public"]["Tables"]> =
  Database["public"]["Tables"][T]["Update"];

/** Helper to extract an enum type by name. */
export type Enums<T extends keyof Database["public"]["Enums"]> = Database["public"]["Enums"][T];
