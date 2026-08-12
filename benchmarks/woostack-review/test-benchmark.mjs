#!/usr/bin/env node

import assert from "node:assert/strict";
import { existsSync, mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const root = dirname(fileURLToPath(import.meta.url));
const harness = join(root, "benchmark.mjs");
const skillRoot = resolve(root, "..", "..", "skills", "woostack-review");
const workspace = mkdtempSync(join(tmpdir(), "woostack-review-benchmark-test-"));

function run(...args) {
  const result = spawnSync(process.execPath, [harness, ...args], { encoding: "utf8" });
  assert.equal(result.status, 0, `${args.join(" ")}\n${result.stdout}\n${result.stderr}`);
  return result.stdout.trim();
}

function build(runRoot) {
  run("init", "--run-root", runRoot, "--skill-root", skillRoot);
  const corpus = JSON.parse(readFileSync(join(runRoot, "corpus.json"), "utf8"));
  for (const item of corpus.cases) {
    const findings = item.id === "cal-dot-com"
      ? [{ title: "Unawaited reminder cleanup", description: "Asynchronous reminder deletion runs inside forEach without being awaited, so cancellation can finish before cleanup." }]
      : [];
    writeFileSync(join(runRoot, "cases", item.id, "findings.json"), `${JSON.stringify(findings)}\n`);
  }
  const planSummary = JSON.parse(run("plan", "--run-root", runRoot));
  assert.deepEqual(planSummary, { cases: 10, candidates: 1, pairs: 3 });
  const plan = JSON.parse(readFileSync(join(runRoot, "judge-plan.json"), "utf8"));
  for (const pair of plan.pairs) {
    const decision = {
      reasoning: pair.goldenId === "G01" ? "Both identify unawaited asynchronous reminder deletion." : "The underlying issues differ.",
      match: pair.goldenId === "G01",
      confidence: 0.99,
    };
    writeFileSync(join(runRoot, pair.decisionPath), `${JSON.stringify(decision)}\n`);
  }
  const score = JSON.parse(run("score", "--run-root", runRoot));
  assert.deepEqual(score, { tp: 1, fp: 0, fn: 24, precision: 1, recall: 1 / 25, f1: 1 / 13, f2: 5 / 101 });
  return readFileSync(join(runRoot, "result.json"), "utf8");
}

try {
  const verified = JSON.parse(run("verify-corpus"));
  assert.equal(verified.valid, true);
  assert.equal(verified.cases, 10);
  assert.equal(verified.goldens, 30);
  const first = build(join(workspace, "run-a"));
  const second = build(join(workspace, "run-b"));
  assert.equal(first, second, "identical inputs must produce byte-identical results");
  const rerun = spawnSync(process.execPath, [harness, "score", "--run-root", join(workspace, "run-a")], { encoding: "utf8" });
  assert.notEqual(rerun.status, 0, "result artifacts must be create-new");
  const dryRunRoot = join(workspace, "dry-run");
  const dryRun = spawnSync(join(root, "run.sh"), ["--dry-run", "--org", "benchmark-test", "--run-root", dryRunRoot], { encoding: "utf8" });
  assert.equal(dryRun.status, 0, dryRun.stderr);
  assert.deepEqual(JSON.parse(dryRun.stdout), {
    repositoryRoot: resolve(root, "..", ".."),
    benchmarkRoot: root,
    skillRoot,
    runRoot: dryRunRoot,
    githubNamespace: "benchmark-test",
    dryRun: true,
  });
  assert.equal(existsSync(dryRunRoot), false, "dry run must not create the run root");
  console.log("benchmark harness tests passed");
} finally {
  rmSync(workspace, { recursive: true, force: true });
}
