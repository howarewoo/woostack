import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import path from "node:path";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const identity = `node:${process.version};platform:${process.platform};arch:${process.arch}`;
const runtimeHash = createHash("sha256").update(identity).digest("hex").slice(0, 16);

const turboBin = path.join(root, "node_modules", "turbo", "bin", "turbo");
const args = process.argv.slice(2);
const env = { ...process.env, TURBO_RUNTIME_HASH: runtimeHash };

// Nested verification must inherit an explicit cache bypass, even in strict env mode.
for (let i = 0; i < args.length && args[i] !== "--"; i++) {
  if (args[i] === "--force") {
    env.TURBO_FORCE = /^(true|false)$/.test(args[i + 1]) ? args[++i] : "true";
  } else if (args[i].startsWith("--force=")) {
    env.TURBO_FORCE = args[i].slice("--force=".length);
  }
}
const result = spawnSync(process.execPath, [turboBin, ...args], {
  cwd: process.cwd(),
  env,
  stdio: "inherit",
});

if (result.error) {
  console.error(result.error);
  process.exit(1);
}
if (result.signal) {
  process.exit(1);
}
process.exit(result.status ?? 1);
