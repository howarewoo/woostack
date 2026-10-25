import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { execFileSync } from "node:child_process";
import { createRequire } from "node:module";
const root = fileURLToPath(new URL("../", import.meta.url));
const inventory = JSON.parse(readFileSync(resolve(root, "src/inventory.json"), "utf8"));
assert.ok(inventory.version && inventory.reference.revision && inventory.upstream.catalog);
const entries = [...inventory.entries, ...inventory.projectExtensions];
assert.equal(
  new Set(entries.map((entry) => entry.id)).size,
  entries.length,
  "Duplicate stable anchors",
);
for (const entry of entries) {
  for (const field of ["id", "name", "group", "importPath", "specimen"])
    assert.ok(entry[field]?.trim(), `${entry.id}: missing ${field}`);
  assert.match(entry.id, /^[a-z][a-z0-9-]*$/, "Unsafe anchor");
  assert.match(
    entry.specimen,
    /^src\/examples\/(?:[^./\\][^/\\]*\/)*[^./\\][^/\\]*\.tsx$/,
    `${entry.id}: specimen must be inside src/examples/**/*.tsx`,
  );
  assert.ok(existsSync(resolve(root, entry.specimen)), `${entry.id}: missing live specimen`);
  const specimen = readFileSync(resolve(root, entry.specimen), "utf8");
  assert.match(specimen, /export default/, `${entry.id}: specimen must expose a default component`);
  assert.ok(
    specimen.includes(entry.importPath),
    `${entry.id}: specimen does not consume the declared public import`,
  );
  assert.ok(entry.provenance ?? inventory.upstream.provenance, `${entry.id}: missing provenance`);
}
// Typecheck the actual catalog and live specimen modules with the project compiler.
const require = createRequire(import.meta.url);
const compilerManifest = require.resolve("typescript/package.json");
const compiler = resolve(
  dirname(compilerManifest),
  JSON.parse(readFileSync(compilerManifest, "utf8")).bin.tsc,
);
execFileSync(
  process.execPath,
  [compiler, "--noEmit", "--project", resolve(root, "tsconfig.json")],
  { cwd: root, stdio: "inherit" },
);
console.log(
  `Catalog: ${inventory.entries.length} baseline entries and ${inventory.projectExtensions.length} project extensions; specimens typechecked. Browser behavior still requires real browser verification.`,
);
