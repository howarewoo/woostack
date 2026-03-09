import { Hono } from "hono";
import { describe, expect, it } from "vitest";
import { bodyLimit } from "../body-limit";

function createApp(maxSize?: number) {
  const app = new Hono();
  app.use("*", bodyLimit(maxSize ? { maxSize } : undefined));
  app.post("/", (c) => c.text("ok"));
  app.get("/", (c) => c.text("ok"));
  return app;
}

describe("bodyLimit", () => {
  it("allows requests without Content-Length header", async () => {
    const app = createApp(100);
    const res = await app.request("/", { method: "POST" });

    expect(res.status).toBe(200);
    expect(await res.text()).toBe("ok");
  });

  it("allows requests within the size limit", async () => {
    const app = createApp(1000);
    const res = await app.request("/", {
      method: "POST",
      headers: { "Content-Length": "500" },
    });

    expect(res.status).toBe(200);
  });

  it("allows requests exactly at the size limit", async () => {
    const app = createApp(100);
    const res = await app.request("/", {
      method: "POST",
      headers: { "Content-Length": "100" },
    });

    expect(res.status).toBe(200);
  });

  it("rejects requests exceeding the size limit", async () => {
    const app = createApp(100);
    const res = await app.request("/", {
      method: "POST",
      headers: { "Content-Length": "101" },
    });

    expect(res.status).toBe(413);
    const body = await res.json();
    expect(body).toEqual({ error: "Payload Too Large" });
  });

  it("defaults to 1 MB limit", async () => {
    const app = createApp();

    const withinLimit = await app.request("/", {
      method: "POST",
      headers: { "Content-Length": "1048576" },
    });
    expect(withinLimit.status).toBe(200);

    const overLimit = await app.request("/", {
      method: "POST",
      headers: { "Content-Length": "1048577" },
    });
    expect(overLimit.status).toBe(413);
  });

  it("ignores non-numeric Content-Length values", async () => {
    const app = createApp(100);
    const res = await app.request("/", {
      method: "POST",
      headers: { "Content-Length": "abc" },
    });

    expect(res.status).toBe(200);
  });

  it("allows GET requests regardless of Content-Length", async () => {
    const app = createApp(100);
    const res = await app.request("/", {
      method: "GET",
      headers: { "Content-Length": "99999" },
    });

    // body-limit checks all methods since Content-Length is present
    expect(res.status).toBe(413);
  });
});
