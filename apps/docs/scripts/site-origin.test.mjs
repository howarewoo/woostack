import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import test from "node:test";
import { getSiteOrigin } from "../lib/site-origin.mjs";

function configuredOrigin(value) {
  const env = { ...process.env };
  delete env.DOCS_SITE_ORIGIN;
  if (value !== undefined) env.DOCS_SITE_ORIGIN = value;
  return execFileSync(
    process.execPath,
    [
      "--input-type=module",
      "-e",
      `import {getSiteOrigin} from ${JSON.stringify(new URL("../lib/site-origin.mjs", import.meta.url).href)}; console.log(getSiteOrigin().href);`,
    ],
    { env, encoding: "utf8" },
  ).trim();
}

test("unset origin uses the production site, not localhost", () => {
  assert.equal(configuredOrigin(), "https://woostack-docs.adam-nathaniel-woo.workers.dev/");
});

test("explicit build origin resolves relative social images", () => {
  assert.equal(configuredOrigin("https://preview.example.com"), "https://preview.example.com/");
  assert.equal(
    new URL("/og/docs/getting-started/image.png", getSiteOrigin("https://docs.example.com/")).href,
    "https://docs.example.com/og/docs/getting-started/image.png",
  );
});

test("malformed origins and URL components cannot silently select a fallback", () => {
  for (const value of [
    "",
    "not a url",
    "/relative",
    "http://docs.example.com",
    "javascript:alert(1)",
    "https://user:password@docs.example.com",
    "https://docs.example.com/path",
    "https://docs.example.com/?query=value",
    "https://docs.example.com/#fragment",
    "https://localhost",
    "https://test.localhost",
    "https://127.0.0.1",
    "https://[::1]",
  ]) {
    assert.throws(() => getSiteOrigin(value), undefined, value);
  }
});
