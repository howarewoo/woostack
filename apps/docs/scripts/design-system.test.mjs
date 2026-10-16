import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import {
  copyFile,
  mkdir,
  mkdtemp,
  readFile,
  readdir,
  rm,
  symlink,
  writeFile,
} from "node:fs/promises";
import { createRequire } from "node:module";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const templates = fileURLToPath(
  new URL("../../../skills/woostack-design-system/templates/", import.meta.url),
);
// Use the site's actual installed compiler, not a compiler stub or a verifier copy.
const typescript = path.dirname(require.resolve("typescript/package.json"));

function entry(
  id,
  importExample,
  specimen = `src/examples/${id}.tsx`,
  importPath = "../public-api",
) {
  return {
    id,
    name: id,
    group: "Project",
    importPath,
    importExample,
    specimen,
    provenance: "fixture",
  };
}

async function fixture(t, entries, extensions = []) {
  const root = await mkdtemp(path.join(os.tmpdir(), "woostack-design-system-"));
  t.after(() => rm(root, { recursive: true, force: true }));
  await mkdir(path.join(root, "scripts"));
  await mkdir(path.join(root, "node_modules"));
  await symlink(typescript, path.join(root, "node_modules/typescript"), "dir");
  await copyFile(
    path.join(templates, "scripts/check-catalog.mjs.template"),
    path.join(root, "scripts/check-catalog.mjs"),
  );
  const config = JSON.parse(await readFile(path.join(templates, "tsconfig.json.template"), "utf8"));
  config.compilerOptions.types = [];
  await writeFile(path.join(root, "tsconfig.json"), JSON.stringify(config));
  await mkdir(path.join(root, "src"));
  await writeFile(
    path.join(root, "src/public-api.ts"),
    "export const Button = 1; export default Button;\n",
  );
  await writeFile(
    path.join(root, "src/inventory.json"),
    JSON.stringify({
      version: 1,
      reference: { revision: "fixture" },
      upstream: { catalog: "fixture" },
      entries,
      projectExtensions: extensions,
    }),
  );
  for (const item of [...entries, ...extensions]) {
    const filename = path.join(root, item.specimen);
    await mkdir(path.dirname(filename), { recursive: true });
    // A valid specimen must not hide a broken inventory import by sharing its error.
    await writeFile(
      filename,
      `import { Button } from ${JSON.stringify(item.importPath)};\nexport default function Specimen() { return null; }\nvoid Button;\n`,
    );
  }
  return root;
}

function verify(root) {
  const result = spawnSync(process.execPath, ["scripts/check-catalog.mjs"], {
    cwd: root,
    encoding: "utf8",
  });
  assert.ifError(result.error);
  return { ...result, output: `${result.stdout}${result.stderr}` };
}

async function sourceFiles(root) {
  return (await readdir(path.join(root, "src"), { recursive: true })).sort();
}

test("catalog verifier rejects nonexistent public exports and cleans its modules", async (t) => {
  const root = await fixture(t, [
    entry("broken", 'import { MissingExport } from "../public-api";'),
  ]);
  const before = await sourceFiles(root);
  const result = verify(root);
  assert.notEqual(result.status, 0, result.output);
  assert.match(result.output, /MissingExport/);
  assert.deepEqual(await sourceFiles(root), before);
});

test("catalog verifier preserves aliases, default and namespace imports across entries", async (t) => {
  const imports = [
    'import { Button as ProjectButton } from "../public-api";',
    'import { Button as ProjectButton } from "../public-api";',
    'import PublicAPI from "../public-api";',
    'import PublicAPI from "../public-api";',
    'import * as PublicAPI from "../public-api";',
    'import * as PublicAPI from "../public-api";',
  ];
  const root = await fixture(
    t,
    imports.map((value, index) => entry(`api-${index}`, value)),
  );
  const before = await sourceFiles(root);
  const result = verify(root);
  assert.equal(result.status, 0, result.output);
  assert.deepEqual(await sourceFiles(root), before);
});

test("catalog verifier accepts nested extension filenames and relative public imports", async (t) => {
  const root = await fixture(
    t,
    [],
    [
      entry(
        "nested",
        'import { Button as CustomButton } from "../../public-api";',
        "src/examples/project/custom.panel.tsx",
        "../../public-api",
      ),
    ],
  );
  const before = await sourceFiles(root);
  const result = verify(root);
  assert.equal(result.status, 0, result.output);
  assert.match(result.output, /0 baseline entries and 1 project extensions/);
  assert.deepEqual(await sourceFiles(root), before);
});

test("catalog verifier rejects specimens outside the recursive runtime loader", async (t) => {
  for (const specimen of [
    "src/other/custom.tsx",
    "src/examples/../custom.tsx",
    "src/examples/.hidden.tsx",
    "src/examples/.hidden/custom.tsx",
    "src/examples/custom.ts",
  ]) {
    await t.test(specimen, async (child) => {
      const root = await fixture(
        child,
        [],
        [entry("outside", 'import { Button } from "../public-api";', specimen)],
      );
      const before = await sourceFiles(root);
      const result = verify(root);
      assert.notEqual(result.status, 0, result.output);
      assert.match(result.output, /specimen must be inside src\/examples/);
      assert.deepEqual(await sourceFiles(root), before);
    });
  }
});

test("catalog verifier preserves colliding files and cleans earlier task-created modules", async (t) => {
  const root = await fixture(t, [
    entry("first", 'import { Button } from "../public-api";'),
    entry("second", 'import { Button } from "../public-api";'),
  ]);
  const collision = path.join(root, "src/examples/catalog-public-import-1.ts");
  const original = "// Existing project file, not owned by the verifier.\n";
  await writeFile(collision, original);
  const before = await sourceFiles(root);
  const result = verify(root);
  assert.notEqual(result.status, 0, result.output);
  assert.match(result.output, /EEXIST/);
  assert.equal(await readFile(collision, "utf8"), original);
  assert.deepEqual(await sourceFiles(root), before);
});

test("catalog verifier does not overwrite or clean a dangling collision symlink", async (t) => {
  const root = await fixture(t, [entry("first", 'import { Button } from "../public-api";')]);
  const collision = path.join(root, "src/examples/catalog-public-import-0.ts");
  await symlink("missing-project-file.ts", collision);
  const before = await sourceFiles(root);
  const result = verify(root);
  assert.notEqual(result.status, 0, result.output);
  assert.match(result.output, /EEXIST/);
  assert.deepEqual(await sourceFiles(root), before);
});
