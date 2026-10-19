import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { copyFile, mkdir, mkdtemp, readFile, rm, symlink, writeFile } from "node:fs/promises";
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

function entry(id, specimen = `src/examples/${id}.tsx`, importPath = "../public-api") {
  return {
    id,
    name: id,
    group: "Project",
    importPath,
    specimen,
    provenance: "fixture",
  };
}

async function fixture(t, entries, extensions = [], specimens = {}) {
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
    // Preview code is real specimen source; invalid imports must fail the project compile.
    await writeFile(
      filename,
      specimens[item.specimen] ??
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

test("catalog verifier rejects invalid imports in real preview code", async (t) => {
  const root = await fixture(t, [entry("broken")], [], {
    "src/examples/broken.tsx":
      'import { MissingExport } from "../public-api";\nexport default function Specimen() { return null; }\n',
  });
  const result = verify(root);
  assert.notEqual(result.status, 0, result.output);
  assert.match(result.output, /MissingExport/);
});

test("catalog verifier accepts supported import forms in live specimens", async (t) => {
  const imports = [
    ['import { Button as ProjectButton } from "../public-api";', "ProjectButton"],
    ['import PublicAPI from "../public-api";', "PublicAPI"],
    ['import * as PublicAPI from "../public-api";', "PublicAPI"],
  ];
  const entries = [...imports.keys()].map((index) => entry(`api-${index}`));
  const specimens = Object.fromEntries(
    imports.map(([value, binding], index) => [
      `src/examples/api-${index}.tsx`,
      `${value}\nexport default function Specimen() { return null; }\nvoid ${binding};\n`,
    ]),
  );
  const root = await fixture(t, entries, [], specimens);
  const result = verify(root);
  assert.equal(result.status, 0, result.output);
});

test("catalog verifier accepts nested extension filenames and relative public imports", async (t) => {
  const root = await fixture(
    t,
    [],
    [entry("nested", "src/examples/project/custom.panel.tsx", "../../public-api")],
    {
      "src/examples/project/custom.panel.tsx":
        'import { Button as CustomButton } from "../../public-api";\nexport default function Specimen() { return null; }\nvoid CustomButton;\n',
    },
  );
  const result = verify(root);
  assert.equal(result.status, 0, result.output);
  assert.match(result.output, /0 baseline entries and 1 project extensions/);
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
      const root = await fixture(child, [entry("outside", specimen)]);
      const result = verify(root);
      assert.notEqual(result.status, 0, result.output);
      assert.match(result.output, /specimen must be inside src\/examples/);
    });
  }
});
