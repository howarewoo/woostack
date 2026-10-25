import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { copyFileSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { test } from "node:test";

test("launcher uses Node, preserves arguments and runtime identity, and forwards force policy", () => {
  const root = mkdtempSync(path.join(tmpdir(), "turbo launcher "));
  try {
    mkdirSync(path.join(root, "scripts"));
    mkdirSync(path.join(root, "node_modules/turbo/bin"), { recursive: true });
    const launcher = path.join(root, "scripts/turbo.mjs");
    copyFileSync(new URL("./turbo.mjs", import.meta.url), launcher);
    // No executable bit, shebang, or package-manager shim is available in this fixture.
    writeFileSync(
      path.join(root, "node_modules/turbo/bin/turbo"),
      `
      console.log(JSON.stringify({ args: process.argv.slice(2), force: process.env.TURBO_FORCE ?? null,
        runtime: process.env.TURBO_RUNTIME_HASH, cwd: process.cwd() }))
      process.exit(Number(process.env.LAUNCHER_TEST_EXIT || 0))
    `,
    );
    const identity = `node:${process.version};platform:${process.platform};arch:${process.arch}`;
    const runtime = createHash("sha256").update(identity).digest("hex").slice(0, 16);
    for (const [args, inherited, expected] of [
      [["run", "verify", "--force"], undefined, "true"],
      [["run", "verify", "--force=true"], undefined, "true"],
      [["run", "verify", "--force", "false"], "true", "false"],
      [["run", "verify", "--force=false"], "true", "false"],
      [["run", "test"], "true", "true"],
      [["run", "test", "--", "--force", "argument with spaces"], undefined, undefined],
    ]) {
      const env = { ...process.env, TURBO_RUNTIME_HASH: "stale" };
      delete env.TURBO_FORCE;
      if (inherited !== undefined) env.TURBO_FORCE = inherited;
      const result = spawnSync(process.execPath, [launcher, ...args], {
        cwd: root,
        env,
        encoding: "utf8",
      });
      assert.equal(result.status, 0, result.stderr);
      assert.deepEqual(JSON.parse(result.stdout), {
        args,
        force: expected ?? null,
        runtime,
        cwd: root,
      });
    }
    const failed = spawnSync(process.execPath, [launcher, "run", "test"], {
      env: { ...process.env, LAUNCHER_TEST_EXIT: "7" },
    });
    assert.equal(failed.status, 7);
    rmSync(path.join(root, "node_modules"), { recursive: true });
    assert.equal(spawnSync(process.execPath, [launcher, "--version"]).status, 1);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
});
