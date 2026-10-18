#!/usr/bin/env node
// Deterministic projection of canonical shared assets into skill-local copies.
//
// Canonical sources live under shared/ (references/, scripts/, templates/).
// shared/mapping.json names, per canonical file, every skill package under
// skills/ that receives a byte-identical generated copy at the same relative
// path. Nothing else is copied: a skill's bundle contains only the shared files
// it links, plus any transitively linked assets.
//
// Usage:
//   node shared/sync.mjs           write missing or drifted copies under skills/
//   node shared/sync.mjs --check   non-mutating consistency report
//
// Diagnosing an installed or external skill collection is done with the
// production validator (validateSkillAssets(<collection>, [name])) directly,
// not with this CLI, whose mapping expects the full catalog.
//
// Exit codes: 0 clean, 1 problems found, 2 invalid invocation.

import { lstat, mkdir, readdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { validateSkillAssets } from "../apps/docs/scripts/skill-assets.mjs";

const SHARED_DIR = path.dirname(fileURLToPath(import.meta.url));
const DEFAULT_SKILLS_DIR = path.resolve(SHARED_DIR, "..", "skills");

async function isRegularFile(target) {
  try {
    const state = await lstat(target);
    return state.isFile();
  } catch (error) {
    if (error?.code !== "ENOENT") throw error;
    return false;
  }
}

// Every local directory containing a SKILL.md file is a skill package.
async function discoveredNames(skillsDir) {
  const names = [];
  for (const entry of await readdir(skillsDir, { withFileTypes: true })) {
    if (!entry.isDirectory()) continue;
    if (await isRegularFile(path.join(skillsDir, entry.name, "SKILL.md"))) {
      names.push(entry.name);
    }
  }
  return names.sort();
}

// Assets inside a skill package, relative to the package root.
async function collectAssets(packageRoot) {
  const files = [];
  async function visit(directory) {
    for (const entry of await readdir(directory, { withFileTypes: true })) {
      const absolute = path.join(directory, entry.name);
      if (entry.isDirectory()) await visit(absolute);
      else if (entry.isFile()) {
        files.push(path.relative(packageRoot, absolute));
      }
    }
  }
  await visit(packageRoot);
  return files;
}

// Canonical files under shared/, relative to shared/ itself. mapping.json is
// the projection contract, not an asset.
async function collectCanonicalFiles(sharedDir) {
  const files = new Set();
  async function visit(directory) {
    for (const entry of await readdir(directory, { withFileTypes: true })) {
      if (entry.name === "mapping.json") continue;
      const absolute = path.join(directory, entry.name);
      if (entry.isDirectory()) await visit(absolute);
      else if (entry.isFile()) {
        files.add(path.relative(sharedDir, absolute).split(path.sep).join("/"));
      }
    }
  }
  await visit(sharedDir);
  return files;
}

// Detect an already-symlinked ancestor of a relative path without following
// links beyond it: any preexisting symlinked parent means the write would
// resolve somewhere unexpected, and it blocks the copy in both modes.
async function symlinkedAncestor(base, segments) {
  let current = base;
  for (const segment of segments.slice(0, -1)) {
    current = path.join(current, segment);
    let state;
    try {
      state = await lstat(current);
    } catch (error) {
      if (error?.code === "ENOENT") return null;
      throw error;
    }
    if (state.isSymbolicLink()) return current;
  }
  return null;
}

// One deterministic run projects every mapped canonical copy into a skill
// package. Writing is the default; `check: true` audits without touching the
// tree (no writes, no mkdir, no chmod) and reports missing or drifted copies,
// unmapped canonical leftovers, unmapped stray assets, and anchor-closure or
// consumer-validation problems instead.
async function runSync({ sharedDir = SHARED_DIR, skillsDir = DEFAULT_SKILLS_DIR, check = false }) {
  const problems = [];
  let writes = 0;

  let mapping;
  try {
    mapping = JSON.parse(await readFile(path.join(sharedDir, "mapping.json"), "utf8"));
  } catch (error) {
    throw new Error(`shared/mapping.json is unreadable or missing: ${error.message}`);
  }
  if (!Array.isArray(mapping.entries)) {
    throw new Error('shared/mapping.json must contain an "entries" array');
  }

  let packageStat;
  try {
    packageStat = await lstat(skillsDir);
  } catch (error) {
    if (error?.code === "ENOENT") {
      throw new Error(`skill packages directory not found: ${skillsDir}`);
    }
    throw error;
  }
  if (!packageStat.isDirectory()) {
    throw new Error(`skill packages path is not a directory: ${skillsDir}`);
  }

  const packages = new Set(await discoveredNames(skillsDir));
  const mappedDestinations = new Set();

  for (const entry of mapping.entries) {
    if (typeof entry?.source !== "string" || !Array.isArray(entry?.consumers)) {
      problems.push('mapping entry needs a string "source" and a "consumers" array');
      continue;
    }
    const source = path.posix.normalize(entry.source);
    if (
      source !== entry.source ||
      source.startsWith("/") ||
      /^(?:\.\.(?:\/|$))/.test(source) ||
      !/^(?:references|scripts|templates)\/[A-Za-z0-9][A-Za-z0-9._-]*(?:\/[A-Za-z0-9][A-Za-z0-9._-]*)*$/.test(
        source,
      )
    ) {
      problems.push(
        `mapping source must be a normalized references/, scripts/, or templates/ path: ${entry.source}`,
      );
      continue;
    }
    const sourceLinkParent = await symlinkedAncestor(sharedDir, source.split("/"));
    if (sourceLinkParent !== null) {
      problems.push(`canonical source is symlinked or sits under a symlink: shared/${source}`);
      continue;
    }
    const sourceAbsolute = path.join(sharedDir, source);
    const sourceBytes = (await isRegularFile(sourceAbsolute))
      ? await readFile(sourceAbsolute)
      : null;
    if (sourceBytes === null) problems.push(`canonical source missing: shared/${entry.source}`);

    for (const consumer of [...entry.consumers].sort()) {
      if (!packages.has(consumer)) {
        problems.push(`mapping consumer is not a detected skill package: ${consumer}`);
        continue;
      }
      mappedDestinations.add(`${consumer}/${entry.source}`);
      if (sourceBytes === null) continue;
      const destination = path.join(skillsDir, consumer, ...source.split("/"));
      const destinationLinkParent = await symlinkedAncestor(skillsDir, [
        consumer,
        ...source.split("/"),
      ]);
      if (destinationLinkParent !== null) {
        problems.push(
          `destination is symlinked or sits under a symlink: ${path.relative(skillsDir, destination)}`,
        );
        continue;
      }
      let destinationIsLink = false;
      try {
        destinationIsLink = (await lstat(destination)).isSymbolicLink();
      } catch (error) {
        if (error?.code !== "ENOENT") throw error;
      }
      if (destinationIsLink) {
        problems.push(
          `destination is symlinked or sits under a symlink: ${path.relative(skillsDir, destination)}`,
        );
        continue;
      }
      const destinationBytes = (await isRegularFile(destination))
        ? await readFile(destination)
        : null;
      if (destinationBytes === null || Buffer.compare(destinationBytes, sourceBytes) !== 0) {
        if (check) {
          problems.push(
            destinationBytes === null
              ? `missing generated copy: ${path.relative(skillsDir, destination)} (from shared/${entry.source})`
              : `drifted generated copy: ${path.relative(skillsDir, destination)} differs from shared/${entry.source}`,
          );
        } else {
          await mkdir(path.dirname(destination), { recursive: true });
          await writeFile(destination, sourceBytes);
          writes += 1;
        }
      }
    }
  }

  // Mapping audit: no canonical asset may linger as an unmapped copy inside a
  // skill package, whatever its type (references, scripts, or templates).
  const canonicalFiles = await collectCanonicalFiles(sharedDir);
  for (const name of packages) {
    for (const relative of await collectAssets(path.join(skillsDir, name))) {
      const canonical = relative.split(path.sep).join("/");
      if (!canonicalFiles.has(canonical)) continue;
      if (!mappedDestinations.has(`${name}/${canonical}`)) {
        problems.push(
          `unmapped copy of canonical asset: ${name}/${canonical} — add ${name} to the consumers of ${canonical} in shared/mapping.json`,
        );
      }
    }
  }

  // Strict per-package closure: structural validation, link resolution, and
  // anchor targets for every Markdown file of every skill. Reports from every
  // direction (missing copy, missing link target, missing anchor) are appended
  // to the same deterministic problem list.
  try {
    await validateSkillAssets(skillsDir, [...packages]);
  } catch (error) {
    problems.push(error.message);
  }

  const sorted = (items) => [...items].sort((a, b) => a.localeCompare(b));
  return {
    check,
    packages: [...packages],
    writes,
    problems: sorted(problems),
  };
}

function report(result, { cliCommand }) {
  for (const problem of result.problems) console.error(`sync: problem: ${problem}`);
  if (result.check) {
    if (result.problems.length > 0) {
      console.error(
        `sync --check: ${result.problems.length} problem(s); run \`${cliCommand}\` to write missing or drifted mapped copies after correcting shared/mapping.json entries (mapped but retired assets, unmapped canonical files)`,
      );
      return 1;
    }
    console.log(
      `sync --check: clean (${result.packages.length} skill packages, mapping fully closed and byte-identical)`,
    );
    return 0;
  }
  console.log(
    `sync: wrote ${result.writes} generated copy/copies (${result.problems.length} problem(s) remaining)`,
  );
  return result.problems.length > 0 ? 1 : 0;
}

async function main(argv) {
  let check = false;
  for (const argument of argv) {
    if (argument === "--check") check = true;
    else {
      console.error(`sync: unexpected argument: ${argument}`);
      return 2;
    }
  }
  let result;
  try {
    result = await runSync({ check });
  } catch (error) {
    console.error(`sync: ${error.message}`);
    return 2;
  }
  return report(result, { cliCommand: "node shared/sync.mjs" });
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.exit(await main(process.argv.slice(2)));
}

export { runSync };
