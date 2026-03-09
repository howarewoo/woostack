import { serve } from "@hono/node-server";
import { app, logger } from "./app";

const port = Number(process.env.PORT) || 3100;

const server = serve({
  fetch: app.fetch,
  port,
});

logger.info({ port }, "Server is running");

// --- Graceful shutdown ---

function shutdown(signal: string) {
  logger.info({ signal }, "Received signal, shutting down gracefully...");
  server.close(() => {
    logger.info("Server closed.");
    process.exit(0);
  });

  const forceTimeout = setTimeout(() => {
    logger.error("Shutdown timed out, forcing exit.");
    process.exit(1);
  }, 30_000);
  forceTimeout.unref();
}

process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));

export default app;
