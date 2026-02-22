import { serve } from "@hono/node-server";
import { logger } from "hono/logger";
import { app } from "./app";

app.use("*", logger());

const port = Number(process.env.PORT) || 3001;
console.log(`Server is running on http://localhost:${port}`);

serve({
  fetch: app.fetch,
  port,
});

export default app;
