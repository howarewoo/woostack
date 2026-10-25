import { cpSync, mkdirSync, writeFileSync } from "node:fs";
import { relative } from "node:path";
import { fileURLToPath } from "node:url";

// Direct Wrangler commands do not run OpenNext's cache-population step.
cpSync(
  new URL("../.open-next/cache/", import.meta.url),
  new URL("../.open-next/assets/cdn-cgi/_next_cache/", import.meta.url),
  { recursive: true },
);

// Keep discovery local to each invocation directory without duplicating Worker settings.
const configPath = fileURLToPath(new URL("../wrangler.jsonc", import.meta.url));
for (const directory of ["../.wrangler/deploy/", "../../../.wrangler/deploy/"]) {
  const deployDirectory = new URL(directory, import.meta.url);
  mkdirSync(deployDirectory, { recursive: true });
  writeFileSync(
    new URL("config.json", deployDirectory),
    `${JSON.stringify({ configPath: relative(fileURLToPath(deployDirectory), configPath) }, null, 2)}\n`,
  );
}
