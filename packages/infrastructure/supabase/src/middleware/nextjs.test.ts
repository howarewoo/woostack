import { describe, expect, it } from "vitest";
import { createSupabaseMiddleware } from "./nextjs";

describe("createSupabaseMiddleware", () => {
  it("returns a middleware function", () => {
    const middleware = createSupabaseMiddleware({
      supabaseUrl: "http://localhost:54321",
      supabaseAnonKey: "test-anon-key",
      protectedRoutes: ["/dashboard"],
      loginPath: "/login",
    });

    expect(typeof middleware).toBe("function");
  });
});
