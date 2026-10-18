// Behavioral tests for the shared bundle projection: shared/mapping.json drives
// byte-identical generated copies into skills/, and node shared/sync.mjs (or the
// exported runSync against injected roots) verifies the projection without
// mutating anything in --check mode.
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import {
  cp,
  mkdir,
  mkdtemp,
  readlink,
  readdir,
  readFile,
  rm,
  symlink,
  writeFile,
} from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { runSync } from "../../../shared/sync.mjs";
import { validateSkillAssets } from "./skill-assets.mjs";
import { PUBLIC_ORDER } from "./gen-skills.mjs";

const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..", "..");

async function makeRoot(t) {
  const root = await mkdtemp(path.join(os.tmpdir(), "woostack-shared-sync-"));
  t.after(() => rm(root, { recursive: true, force: true }));
  return root;
}

// A minimal canonical tree: core.md and a dependent extra.md that links the
// core copy plus a transitive runtime script asset, all projected onto a
// consumer package that links only the entry reference.
async function makeFixture(t, { extraBody }) {
  const root = await makeRoot(t);
  const shared = path.join(root, "shared");
  await mkdir(path.join(shared, "references"), { recursive: true });
  await mkdir(path.join(shared, "scripts"), { recursive: true });
  await mkdir(path.join(shared, "templates"), { recursive: true });
  await writeFile(path.join(shared, "references", "extra.md"), extraBody);
  await writeFile(path.join(shared, "references", "core.md"), "# Core\n\n## Core anchor\n");
  await writeFile(path.join(shared, "scripts", "asset.py"), "asset = 'canonical'\n");
  await writeFile(path.join(shared, "templates", "gitignore-template"), "disposable/\n");
  return { root, shared };
}

async function writeConsumer(root, name, body) {
  const packageRoot = path.join(root, "skills", name);
  await mkdir(path.join(packageRoot, "references"), { recursive: true });
  await writeFile(
    path.join(packageRoot, "SKILL.md"),
    `---\nname: ${name}\ndescription: Bundle consumer.\n---\n# ${name}\n${body}\n`,
  );
  return packageRoot;
}

function consumerMapping(sources, consumer = "woostack-first") {
  return new Map(sources.map((source) => [source, [consumer]]));
}

function mappingSymbols(iterable) {
  return [...iterable].sort();
}

test("runSync writes mapped copies once and a second run is a no-op", async (t) => {
  const { root, shared } = await makeFixture(t, {
    extraBody: "# Extra\n\nFrom the [core](core.md#core-anchor) source.\n",
  });
  const consumer = await writeConsumer(root, "woostack-first", "[Extra](references/extra.md)");
  await writeFile(
    path.join(shared, "mapping.json"),
    JSON.stringify({
      entries: mappingSymbols(
        consumerMapping(["references/extra.md", "references/core.md", "scripts/asset.py"]),
      ).map(([source, consumers]) => ({ source, consumers })),
    }),
  );

  const first = await runSync({ sharedDir: shared, skillsDir: path.join(root, "skills") });
  assert.equal(first.problems.length, 0, first.problems.join("\n"));
  assert.deepEqual(
    (await readFile(path.join(consumer, "references", "extra.md"), "utf8")).includes(
      "core.md#core-anchor",
    ),
    true,
  );
  assert.deepEqual(
    await readFile(path.join(consumer, "scripts", "asset.py"), "utf8"),
    "asset = 'canonical'\n",
  );

  const second = await runSync({ sharedDir: shared, skillsDir: path.join(root, "skills") });
  assert.deepEqual(second.writes, 0, "an identical second run rewrites nothing");
  assert.equal(second.problems.length, 0, second.problems.join("\n"));
});

test("--check reports missing and drifted copies without rewriting anything", async (t) => {
  const { root, shared } = await makeFixture(t, {
    extraBody: "# Extra\n",
  });
  const consumer = await writeConsumer(root, "woostack-first", "[Extra](references/extra.md)");
  const consumers = [...consumerMapping(["references/extra.md", "references/core.md"])].map(
    ([source, list]) => ({ source, consumers: list }),
  );
  await writeFile(path.join(shared, "mapping.json"), JSON.stringify({ entries: consumers }));
  await runSync({ sharedDir: shared, skillsDir: path.join(root, "skills") });

  await writeFile(path.join(consumer, "references", "core.md"), "# Drifted copy\n");
  await rm(path.join(consumer, "references", "extra.md"));

  const result = await runSync({
    sharedDir: shared,
    skillsDir: path.join(root, "skills"),
    check: true,
  });

  assert.deepEqual(
    result.problems.some((problem) => problem.includes("drifted generated copy")),
    true,
    result.problems.join("\n"),
  );
  assert.deepEqual(
    result.problems.some((problem) => problem.includes("missing generated copy")),
    true,
    result.problems.join("\n"),
  );
  assert.deepEqual(
    await readFile(path.join(consumer, "references", "core.md"), "utf8"),
    "# Drifted copy\n",
  );
  assert.deepEqual(
    await readFile(path.join(consumer, "references", "extra.md"), "utf8").then(
      () => "still-present",
      () => "missing",
    ),
    "missing",
  );
});

test("anchor drift in generated copies fails the check", async (t) => {
  const { root, shared } = await makeFixture(t, {
    extraBody: "# Extra\n\nSee [core](core.md#core-anchor).\n",
  });
  await writeConsumer(root, "woostack-first", "[Extra](references/extra.md)");
  await writeFile(
    path.join(shared, "mapping.json"),
    JSON.stringify({
      entries: [...consumerMapping(["references/extra.md", "references/core.md"])].map(
        ([source, consumers]) => ({ source, consumers }),
      ),
    }),
  );
  const result = await runSync({
    sharedDir: shared,
    skillsDir: path.join(root, "skills"),
    check: false,
  });
  assert.deepEqual(
    result.problems.filter((problem) => problem.includes("anchor")),
    [],
    result.problems.join("\n"),
  );

  // Anchors are validated against the bytes of the target file. A SKILL.md
  // fragment demanding a heading the copy never had fails closure even though
  // the copy itself is byte-perfect.
  await writeFile(
    path.join(root, "skills", "woostack-first", "SKILL.md"),
    "---\nname: woostack-first\ndescription: Bundle consumer.\n---\n# woostack-first\n[Extra](references/extra.md#absent-anchor)\n",
  );
  const result2 = await runSync({
    sharedDir: shared,
    skillsDir: path.join(root, "skills"),
    check: true,
  });
  assert.deepEqual(
    result2.problems.some((problem) => problem.includes("references/extra.md#absent-anchor")) &&
      result2.problems.some((problem) => problem.includes("anchor missing in package target")),
    true,
    result2.problems.join("\n"),
  );
});

test("unmapped canonical assets lingering inside a package are reported", async (t) => {
  const { root, shared } = await makeFixture(t, { extraBody: "# Extra\n" });
  const consumer = await writeConsumer(root, "woostack-first", "[Extra](references/extra.md)");
  await mkdir(path.join(consumer, "templates"), { recursive: true });
  await writeFile(path.join(consumer, "templates", "gitignore-template"), "disposable/\n");
  await writeFile(path.join(consumer, "references", "core.md"), "# Core\n");
  await writeFile(
    path.join(shared, "mapping.json"),
    JSON.stringify({
      entries: [...consumerMapping(["references/extra.md"])].map(([source, list]) => ({
        source,
        consumers: list,
      })),
    }),
  );
  const result = await runSync({
    sharedDir: shared,
    skillsDir: path.join(root, "skills"),
    check: true,
  });
  assert.deepEqual(
    result.problems.some((problem) =>
      problem.includes("woostack-first/templates/gitignore-template"),
    ),
    true,
    result.problems.join("\n"),
  );
  assert.ok(
    result.problems.some((problem) => problem.includes("woostack-first/references/core.md")),
    result.problems.join("\n"),
  );
});

test("transitive runtime assets stay injectable and the check detects their absence", async (t) => {
  const { root, shared } = await makeFixture(t, {
    extraBody: "# Extra\n\ncopy me via [asset](../scripts/asset.py)\n",
  });
  await writeConsumer(root, "woostack-first", "[Extra](references/extra.md)");
  const mapped = ["references/extra.md", "references/core.md"];
  const entries = (sources) =>
    mappingSymbols(consumerMapping(sources)).map(([source, consumers]) => ({ source, consumers }));
  await writeFile(path.join(shared, "mapping.json"), JSON.stringify({ entries: entries(mapped) }));

  const before = await runSync({
    sharedDir: shared,
    skillsDir: path.join(root, "skills"),
    check: true,
  });
  assert.deepEqual(
    before.problems.some(
      (problem) => problem.includes("scripts/asset.py") || problem.includes("does not exist"),
    ),
    true,
    before.problems.join("\n"),
  );

  await writeFile(
    path.join(shared, "mapping.json"),
    JSON.stringify({ entries: entries([...mapped, "scripts/asset.py"]) }),
  );
  const fixed = await runSync({ sharedDir: shared, skillsDir: path.join(root, "skills") });
  assert.equal(fixed.problems.length, 0, fixed.problems.join("\n"));
});

test("the repository entrypoint --check is a clean, non-mutating production run", () => {
  execFileSync(process.execPath, [path.join(REPO_ROOT, "shared", "sync.mjs"), "--check"], {
    cwd: REPO_ROOT,
    stdio: ["ignore", "pipe", "pipe"],
  });
});

test("the CLI reports projection drift in a disposable fixture without mutating it", async (t) => {
  // A disposable clone of the repo's tool directories: shared/ (including
  // sync.mjs, mapping.json and canonical assets) plus the parser module it
  // imports from apps/docs/scripts.
  const root = await makeRoot(t);
  await mkdir(path.join(root, "apps", "docs", "scripts"), { recursive: true });
  await cp(
    path.join(REPO_ROOT, "apps", "docs", "scripts", "skill-assets.mjs"),
    path.join(root, "apps", "docs", "scripts", "skill-assets.mjs"),
  );
  await cp(path.join(REPO_ROOT, "shared"), path.join(root, "shared"), { recursive: true });
  // A deliberate projection drift: the consumer's single mapped copy is edited
  // so the canonical value no longer matches.
  await mkdir(path.join(root, "skills", "woostack-loom", "references"), { recursive: true });
  await writeFile(
    path.join(root, "skills", "woostack-loom", "SKILL.md"),
    "---\nname: woostack-loom\ndescription: Drift fixture.\n---\n# woostack-loom\n",
  );
  await writeFile(
    path.join(root, "skills", "woostack-loom", "references", "tdd.md"),
    "# Drifted consumer copy\n",
  );
  await writeFile(
    path.join(root, "shared", "mapping.json"),
    JSON.stringify({ entries: [{ source: "references/tdd.md", consumers: ["woostack-loom"] }] }),
  );
  let reported;
  try {
    execFileSync(process.execPath, [path.join(root, "shared", "sync.mjs"), "--check"], {
      cwd: root,
      stdio: ["ignore", "pipe", "pipe"],
    });
  } catch (error) {
    reported = error.stderr.toString();
  }
  assert.match(String(reported), /drifted generated copy/);
  assert.match(String(reported), /references\/tdd\.md/);
  assert.deepEqual(
    await readFile(path.join(root, "skills", "woostack-loom", "references", "tdd.md"), "utf8"),
    "# Drifted consumer copy\n",
  );
});
test("an installed single-skill collection validates in isolation", async (t) => {
  const root = await makeRoot(t);
  const container = path.join(root, "installed");
  const consumer = await writeConsumer(
    root,
    "woostack-lone",
    "[Doc](references/notes.md#entry-point)",
  );
  await cp(consumer, path.join(container, "woostack-lone"), { recursive: true });
  await mkdir(path.join(container, "woostack-lone", "references"), { recursive: true });
  await writeFile(
    path.join(container, "woostack-lone", "references", "notes.md"),
    "# Notes\n\n## Entry point\n",
  );
  const parsed = await validateSkillAssets(container, ["woostack-lone"]);
  assert.deepEqual(
    parsed.map(({ name }) => name),
    ["woostack-lone"],
  );
  await rm(path.join(container, "woostack-lone", "references", "notes.md"));
  await assert.rejects(
    validateSkillAssets(container, ["woostack-lone"]),
    /local link target does not exist/,
  );
});

test("every production skill resolves and runs its bundled support helpers in isolation", async (t) => {
  const root = await makeRoot(t);
  const consumer = path.join(root, "consumer");
  await mkdir(path.join(consumer, ".woostack"), { recursive: true });
  await writeFile(path.join(consumer, ".woostack", "config.json"), "{}\n");
  await cp(
    path.join(REPO_ROOT, "shared", "templates", "gitignore"),
    path.join(consumer, ".woostack", ".gitignore"),
  );
  const mapping = JSON.parse(
    await readFile(path.join(REPO_ROOT, "shared", "mapping.json"), "utf8"),
  );
  const resolverConsumers = mapping.entries.find(
    ({ source }) => source === "scripts/config/resolve-config.sh",
  ).consumers;

  for (const name of PUBLIC_ORDER) {
    const container = path.join(root, name);
    const installed = path.join(container, name);
    await cp(path.join(REPO_ROOT, "skills", name), installed, { recursive: true });
    const parsed = await validateSkillAssets(container, [name]);
    assert.deepEqual(
      parsed.map(({ name: found }) => found),
      [name],
    );
    if (resolverConsumers.includes(name)) {
      const effective = execFileSync(
        "bash",
        [path.join(installed, "scripts", "config", "resolve-config.sh"), consumer],
        { cwd: consumer, encoding: "utf8" },
      );
      assert.deepEqual(JSON.parse(effective), {}, `${name}: isolated resolver`);
    }
    if (name === "woostack-init" || name === "woostack-doctor") {
      execFileSync("bash", [path.join(installed, "scripts", "doctor.sh"), "--check", consumer], {
        cwd: consumer,
        stdio: ["ignore", "pipe", "pipe"],
      });
    }
  }
});

test("mapping sources outside references/, scripts/, or templates/ are rejected", async (t) => {
  const { root, shared } = await makeFixture(t, { extraBody: "# Extra\n" });
  await writeConsumer(root, "woostack-first", "[Extra](references/extra.md)");
  await writeFile(
    path.join(shared, "mapping.json"),
    JSON.stringify({
      entries: [
        { source: "../../outside.md", consumers: ["woostack-first"] },
        { source: "references/extra.md", consumers: ["woostack-first"] },
      ],
    }),
  );
  const result = await runSync({
    sharedDir: shared,
    skillsDir: path.join(root, "skills"),
    check: true,
  });
  assert.deepEqual(
    result.problems.some((problem) =>
      problem.includes("normalized references/, scripts/, or templates/ path"),
    ),
    true,
    result.problems.join("\n"),
  );
  assert.deepEqual(
    result.problems.some((problem) => problem.includes("outside.md")),
    true,
    result.problems.join("\n"),
  );
});

test("symlinked destination parents block the copy and nothing is created", async (t) => {
  const { root, shared } = await makeFixture(t, { extraBody: "# Extra\n" });
  const consumer = await writeConsumer(root, "woostack-first", "[Extra](references/extra.md)");
  const outside = path.join(root, "outside");
  await mkdir(outside, { recursive: true });
  await symlink(
    path.join(outside, "extra.md-redirect"),
    path.join(consumer, "references", "extra.md"),
  );
  await writeFile(
    path.join(shared, "mapping.json"),
    JSON.stringify({
      entries: [...consumerMapping(["references/extra.md"])].map(([source, consumers]) => ({
        source,
        consumers,
      })),
    }),
  );
  const before = (await readdir(root, { withFileTypes: true })).map((entry) => entry.name).sort();
  for (const check of [true, false]) {
    const result = await runSync({
      sharedDir: shared,
      skillsDir: path.join(root, "skills"),
      check,
    });
    assert.deepEqual(
      result.problems.some((problem) =>
        problem.includes("destination is symlinked or sits under a symlink"),
      ),
      true,
      result.problems.join("\n"),
    );
  }
  assert.deepEqual(
    (await readdir(root, { withFileTypes: true })).map((entry) => entry.name).sort(),
    before,
    "running the tool creates nothing next to the skill tree",
  );
  assert.deepEqual(
    await readlink(path.join(consumer, "references", "extra.md")),
    path.join(outside, "extra.md-redirect"),
  );
});
