import { usersRouter } from "@features/users/router";
import { MessageSchema } from "@infrastructure/api-client";
import type { SupabaseUser, TypedSupabaseClient } from "@infrastructure/supabase/types";
import { os } from "@orpc/server";

const pub = os.$context<{
  requestId?: string;
  user?: SupabaseUser;
  supabase: TypedSupabaseClient;
}>();

export const router = {
  health: pub.output(MessageSchema).handler(() => {
    return { message: "OK" };
  }),

  users: usersRouter,
};

export type Router = typeof router;
