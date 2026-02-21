import { usersRouter } from "@features/users/router";
import { MessageSchema } from "@infrastructure/api-client";
import { os } from "@orpc/server";

const pub = os.$context<{
  requestId?: string;
  user?: import("@supabase/supabase-js").User;
  supabase: import("@supabase/supabase-js").SupabaseClient;
}>();

export const router = {
  health: pub.output(MessageSchema).handler(() => {
    return { message: "OK" };
  }),

  users: usersRouter,
};

export type Router = typeof router;
