import { serve } from "@hono/node-server";
import { app, logger } from "./app";

const port = Number(process.env.PORT) || 3100;

serve({
  fetch: app.fetch,
  port,
});

logger.info({ port }, "Server is running");

export default app;
