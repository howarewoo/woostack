#!/usr/bin/env node

import { createHash } from "node:crypto";
import { existsSync, lstatSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { basename, dirname, join, relative, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const benchmarkRoot = dirname(fileURLToPath(import.meta.url));
const corpusPath = join(benchmarkRoot, "corpus.json");
const coreCategories = new Set(["api", "bug", "concurrency", "data", "doc_defect", "perf", "security", "test_gap"]);

function fail(message) {
  console.error(`benchmark: ${message}`);
  process.exit(1);
}

function readJson(path) {
  try {
    return JSON.parse(readFileSync(path, "utf8"));
  } catch (error) {
    fail(`cannot read JSON ${path}: ${error.message}`);
  }
}

function canonical(value) {
  if (Array.isArray(value)) return `[${value.map(canonical).join(",")}]`;
  if (value && typeof value === "object") {
    return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${canonical(value[key])}`).join(",")}}`;
  }
  return JSON.stringify(value);
}

function sha256(value) {
  return `sha256:${createHash("sha256").update(value).digest("hex")}`;
}

function assertExactKeys(value, expected, label) {
  const actual = Object.keys(value).sort();
  const wanted = [...expected].sort();
  if (canonical(actual) !== canonical(wanted)) fail(`${label} has fields ${actual.join(",")}; expected ${wanted.join(",")}`);
}

function validateCorpus(corpus) {
  assertExactKeys(corpus, ["schemaVersion", "name", "source", "selection", "profile", "cases"], "corpus");
  if (corpus.schemaVersion !== 1 || corpus.name !== "woostack-review-ten-pr" || corpus.profile !== "core") fail("unsupported corpus identity");
  assertExactKeys(corpus.selection, ["algorithm", "seed", "input", "casesPerSourceFile"], "selection");
  if (corpus.selection.algorithm !== "lowest-two-sha256"
    || corpus.selection.seed !== "woostack-review-five-pr-v1"
    || corpus.selection.input !== "<seed>\n<original-pr-url>"
    || corpus.selection.casesPerSourceFile !== 2) fail("unsupported corpus selection");
  if (!Array.isArray(corpus.cases) || corpus.cases.length !== 10) fail("corpus must contain exactly ten cases");
  const projectCounts = new Map();
  const projectRanks = new Set();
  const ids = new Set();
  const urls = new Set();
  for (const item of corpus.cases) {
    assertExactKeys(item, ["project", "id", "sourceFile", "rank", "url", "title", "rankHash", "caseHash", "goldens"], `case ${item.id}`);
    const projectRank = `${item.project}/${item.rank}`;
    if (!/^[a-z0-9-]+$/.test(item.id) || ids.has(item.id) || urls.has(item.url) || projectRanks.has(projectRank)) fail(`duplicate or invalid case ${item.id}`);
    if (!Number.isInteger(item.rank) || item.rank < 1 || item.rank > corpus.selection.casesPerSourceFile) fail(`invalid rank for ${item.id}`);
    if (!/^https:\/\/github\.com\/[^/]+\/[^/]+\/pull\/\d+$/.test(item.url)) fail(`invalid PR URL for ${item.id}`);
    if (!/^sha256:[0-9a-f]{64}$/.test(item.caseHash) || !/^[0-9a-f]{64}$/.test(item.rankHash)) fail(`invalid hash for ${item.id}`);
    if (!Array.isArray(item.goldens) || item.goldens.length === 0) fail(`case ${item.id} has no goldens`);
    const hashInput = { ...item };
    delete hashInput.caseHash;
    if (sha256(canonical(hashInput)) !== item.caseHash) fail(`case hash mismatch for ${item.id}`);
    const goldenIds = new Set();
    for (const golden of item.goldens) {
      assertExactKeys(golden, ["id", "comment", "severity", "category"], `golden ${item.id}/${golden.id}`);
      if (!/^G\d{2}$/.test(golden.id) || goldenIds.has(golden.id) || typeof golden.comment !== "string" || !golden.comment.trim()) fail(`invalid golden ${item.id}/${golden.id}`);
      if (!new Set(["Low", "Medium", "High", "Critical"]).has(golden.severity)) fail(`invalid severity for ${item.id}/${golden.id}`);
      goldenIds.add(golden.id);
    }
    ids.add(item.id);
    urls.add(item.url);
    projectRanks.add(projectRank);
    projectCounts.set(item.project, (projectCounts.get(item.project) ?? 0) + 1);
  }
  if (projectCounts.size !== 5 || [...projectCounts.values()].some((count) => count !== corpus.selection.casesPerSourceFile)) fail("corpus must contain two cases from each source project");
  return corpus;
}

function parseFlags(args, allowed) {
  const flags = {};
  for (let index = 0; index < args.length; index += 2) {
    const name = args[index];
    const value = args[index + 1];
    if (!allowed.includes(name) || value === undefined || flags[name] !== undefined) fail(`invalid arguments: ${args.join(" ")}`);
    flags[name] = value;
  }
  return flags;
}

function filesUnder(root) {
  const files = [];
  function walk(directory) {
    for (const name of readdirSync(directory).sort()) {
      const path = join(directory, name);
      const stat = lstatSync(path);
      if (stat.isSymbolicLink()) fail(`symlink not allowed in skill snapshot: ${path}`);
      if (stat.isDirectory()) walk(path);
      else if (stat.isFile()) files.push(path);
    }
  }
  walk(root);
  return files;
}

function inventory(root) {
  return filesUnder(root).map((path) => ({
    path: relative(root, path),
    bytes: readFileSync(path).length,
    sha256: sha256(readFileSync(path)),
  }));
}

function requireRun(runRoot) {
  const manifest = readJson(join(runRoot, "manifest.json"));
  const corpus = validateCorpus(readJson(join(runRoot, "corpus.json")));
  if (manifest.corpusSha256 !== sha256(canonical(corpus))) fail("run corpus no longer matches manifest");
  return { manifest, corpus };
}

function verifyCorpus(sourceRoot) {
  const corpus = validateCorpus(readJson(corpusPath));
  if (sourceRoot) {
    const git = spawnSync("git", ["rev-parse", "HEAD"], { cwd: sourceRoot, encoding: "utf8" });
    if (git.status !== 0 || git.stdout.trim() !== corpus.source.commit) fail(`benchmark root must be at ${corpus.source.commit}`);
    for (const item of corpus.cases) {
      const entries = readJson(join(sourceRoot, item.sourceFile));
      const ranked = entries.map((entry) => ({
        entry,
        rankHash: createHash("sha256").update(`${corpus.selection.seed}\n${entry.url}`).digest("hex"),
      })).sort((left, right) => left.rankHash.localeCompare(right.rankHash));
      const selected = ranked[item.rank - 1];
      if (!selected || selected.entry.url !== item.url || selected.rankHash !== item.rankHash) fail(`selection mismatch for ${item.id}`);
      const expected = item.goldens.map(({ comment, severity, category }) => ({ comment, severity, category }));
      if (selected.entry.pr_title !== item.title || canonical(selected.entry.comments) !== canonical(expected)) fail(`source bytes changed for ${item.id}`);
    }
  }
  console.log(JSON.stringify({ valid: true, cases: corpus.cases.length, goldens: corpus.cases.reduce((sum, item) => sum + item.goldens.length, 0), corpusSha256: sha256(canonical(corpus)) }));
}

function initRun(runRoot, skillRoot) {
  if (existsSync(runRoot)) fail(`run root already exists: ${runRoot}`);
  if (!existsSync(join(skillRoot, "SKILL.md"))) fail(`invalid skill root: ${skillRoot}`);
  const corpus = validateCorpus(readJson(corpusPath));
  mkdirSync(runRoot, { recursive: false });
  mkdirSync(join(runRoot, "cases"));
  mkdirSync(join(runRoot, "judgments"));
  for (const item of corpus.cases) mkdirSync(join(runRoot, "cases", item.id));
  writeFileSync(join(runRoot, "corpus.json"), `${JSON.stringify(corpus, null, 2)}\n`);
  const skillInventory = inventory(skillRoot);
  const manifest = {
    schemaVersion: 1,
    benchmark: corpus.name,
    corpusSha256: sha256(canonical(corpus)),
    skillRoot: resolve(skillRoot),
    skillInventory,
    skillSha256: sha256(canonical(skillInventory)),
    candidateContract: "accepted structured findings: <title>. <description>",
    judgeContract: "one isolated semantic-match decision per golden/candidate pair",
    expectedFindings: corpus.cases.map((item) => `cases/${item.id}/findings.json`),
  };
  writeFileSync(join(runRoot, "manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`, { flag: "wx" });
  console.log(resolve(runRoot));
}

function validateFinding(finding, label) {
  if (!finding || typeof finding !== "object" || Array.isArray(finding)) fail(`${label} is not an object`);
  for (const field of ["title", "description"]) if (typeof finding[field] !== "string" || !finding[field].trim()) fail(`${label} missing ${field}`);
}

function createPlan(runRoot) {
  const { corpus } = requireRun(runRoot);
  const cases = [];
  const pairs = [];
  for (const item of corpus.cases) {
    const findingsPath = join(runRoot, "cases", item.id, "findings.json");
    if (!existsSync(findingsPath)) fail(`missing ${findingsPath}`);
    const findings = readJson(findingsPath);
    if (!Array.isArray(findings)) fail(`${findingsPath} must be an array`);
    const candidates = findings.map((finding, index) => {
      validateFinding(finding, `${item.id} finding ${index}`);
      return { id: `C${String(index + 1).padStart(2, "0")}`, text: `${finding.title.trim()}. ${finding.description.trim()}` };
    });
    if (new Set(candidates.map((candidate) => candidate.text)).size !== candidates.length) fail(`duplicate accepted candidate in ${item.id}`);
    cases.push({ id: item.id, url: item.url, candidates });
    for (const golden of item.goldens) {
      for (const candidate of candidates) {
        const id = `${item.id}--${golden.id}--${candidate.id}`;
        pairs.push({
          id,
          caseId: item.id,
          goldenId: golden.id,
          candidateId: candidate.id,
          prompt: `You are evaluating an AI code review tool. Determine whether the candidate identifies the SAME underlying issue as the golden comment. Accept semantic matches despite different wording.\n\nGolden comment:\n${golden.comment}\n\nCandidate issue:\n${candidate.text}\n\nReturn only JSON with exactly: {"reasoning":"brief explanation","match":true|false,"confidence":0.0-1.0}`,
          decisionPath: `judgments/${id}.json`,
        });
      }
    }
  }
  const plan = { schemaVersion: 1, corpusSha256: sha256(canonical(corpus)), cases, pairs };
  writeFileSync(join(runRoot, "judge-plan.json"), `${JSON.stringify(plan, null, 2)}\n`, { flag: "wx" });
  console.log(JSON.stringify({ cases: cases.length, candidates: cases.reduce((sum, item) => sum + item.candidates.length, 0), pairs: pairs.length }));
}

function fbeta(precision, recall, beta) {
  if (precision === 0 && recall === 0) return 0;
  const squared = beta * beta;
  return (1 + squared) * precision * recall / (squared * precision + recall);
}

function score(runRoot) {
  const { corpus } = requireRun(runRoot);
  const plan = readJson(join(runRoot, "judge-plan.json"));
  if (plan.corpusSha256 !== sha256(canonical(corpus))) fail("judge plan corpus mismatch");
  const decisions = new Map();
  for (const pair of plan.pairs) {
    const path = join(runRoot, pair.decisionPath);
    if (!existsSync(path)) fail(`missing judgment ${path}`);
    const decision = readJson(path);
    assertExactKeys(decision, ["reasoning", "match", "confidence"], `judgment ${pair.id}`);
    if (typeof decision.reasoning !== "string" || !decision.reasoning.trim() || typeof decision.match !== "boolean" || typeof decision.confidence !== "number" || decision.confidence < 0 || decision.confidence > 1) fail(`invalid judgment ${pair.id}`);
    decisions.set(pair.id, decision);
  }
  let tp = 0;
  let fn = 0;
  let fp = 0;
  let excludedMatched = 0;
  const caseResults = [];
  for (const item of corpus.cases) {
    const planned = plan.cases.find((entry) => entry.id === item.id);
    const matchedCandidates = new Set();
    const goldenResults = [];
    for (const golden of item.goldens) {
      const matches = planned.candidates.map((candidate) => ({ candidate, decision: decisions.get(`${item.id}--${golden.id}--${candidate.id}`) })).filter((entry) => entry.decision?.match).sort((left, right) => right.decision.confidence - left.decision.confidence);
      const best = matches[0] ?? null;
      if (best) matchedCandidates.add(best.candidate.id);
      const included = coreCategories.has(golden.category);
      if (included && best) tp += 1;
      else if (included) fn += 1;
      else if (best) excludedMatched += 1;
      goldenResults.push({ goldenId: golden.id, category: golden.category, included, matchedCandidateId: best?.candidate.id ?? null, confidence: best?.decision.confidence ?? null });
    }
    const unmatched = planned.candidates.filter((candidate) => !matchedCandidates.has(candidate.id));
    fp += unmatched.length;
    caseResults.push({ id: item.id, candidates: planned.candidates.length, falsePositives: unmatched.map((candidate) => candidate.id), goldens: goldenResults });
  }
  const precision = tp + fp ? tp / (tp + fp) : 0;
  const recall = tp + fn ? tp / (tp + fn) : 0;
  const result = { schemaVersion: 1, benchmark: corpus.name, profile: "core", complete: true, tp, fp, fn, excludedMatched, precision, recall, f1: fbeta(precision, recall, 1), f2: fbeta(precision, recall, 2), cases: caseResults };
  writeFileSync(join(runRoot, "result.json"), `${JSON.stringify(result, null, 2)}\n`, { flag: "wx" });
  console.log(JSON.stringify({ tp, fp, fn, precision, recall, f1: result.f1, f2: result.f2 }));
}

const [command, ...args] = process.argv.slice(2);
if (command === "verify-corpus") {
  const flags = parseFlags(args, ["--benchmark-root"]);
  verifyCorpus(flags["--benchmark-root"] ? resolve(flags["--benchmark-root"]) : null);
} else if (command === "init") {
  const flags = parseFlags(args, ["--run-root", "--skill-root"]);
  if (!flags["--run-root"] || !flags["--skill-root"]) fail("init requires --run-root and --skill-root");
  initRun(resolve(flags["--run-root"]), resolve(flags["--skill-root"]));
} else if (command === "plan") {
  const flags = parseFlags(args, ["--run-root"]);
  if (!flags["--run-root"]) fail("plan requires --run-root");
  createPlan(resolve(flags["--run-root"]));
} else if (command === "score") {
  const flags = parseFlags(args, ["--run-root"]);
  if (!flags["--run-root"]) fail("score requires --run-root");
  score(resolve(flags["--run-root"]));
} else {
  fail(`usage: ${basename(process.argv[1])} verify-corpus [--benchmark-root PATH] | init --run-root PATH --skill-root PATH | plan --run-root PATH | score --run-root PATH`);
}
