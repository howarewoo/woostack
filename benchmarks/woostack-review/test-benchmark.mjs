#!/usr/bin/env node

import { createHash } from "node:crypto";
import assert from "node:assert/strict";
import { chmodSync, existsSync, mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { basename, dirname, join, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const root = dirname(fileURLToPath(import.meta.url));
const harness = join(root, "benchmark.mjs");
const skillRoot = resolve(root, "..", "..", "skills", "woostack-review");
const workspace = mkdtempSync(join(tmpdir(), "woostack-review-benchmark-test-"));

function execute(...args) {
  return spawnSync(process.execPath, [harness, ...args], { encoding: "utf8" });
}

function run(...args) {
  const result = execute(...args);
  assert.equal(result.status, 0, `${args.join(" ")}\n${result.stdout}\n${result.stderr}`);
  return result.stdout.trim();
}

function runWithInput(input, ...args) {
  const result = spawnSync(process.execPath, [harness, ...args], { encoding: "utf8", input });
  assert.equal(result.status, 0, `${args.join(" ")}\n${result.stdout}\n${result.stderr}`);
  return result.stdout.trim();
}

function writeJson(path, value) {
  writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`);
}

function makeUsageDb(path, sessions, malformed = false) {
  const schema = "CREATE TABLE messages (id INTEGER PRIMARY KEY, session_file TEXT, entry_id TEXT, model TEXT, provider TEXT, agent_type TEXT, input_tokens INTEGER, output_tokens INTEGER, cache_read_tokens INTEGER, cache_write_tokens INTEGER, cost_total REAL, error_message TEXT);";
  const rows = sessions.map(({ sessionFile, terminalEntryId }, index) => {
    const input = malformed && index === 0 ? "NULL" : 100;
    return `INSERT INTO messages VALUES (${index + 1},'${sessionFile}','${terminalEntryId}','test-model','test-provider','task',${input},10,1000,50,0.1,NULL);`;
  }).join(" ");
  const sqlite = spawnSync("sqlite3", [path, `${schema} ${rows}`], { encoding: "utf8" });
  assert.equal(sqlite.status, 0, sqlite.stderr);
}

function sha256(value) {
  return `sha256:${createHash("sha256").update(value).digest("hex")}`;
}

function finding(label) {
  return { title: `${label} title`, description: `${label} description` };
}

function prepareReadbackCase(caseRoot) {
  const reviewRoot = join(caseRoot, "review");
  const baseSha = "1".repeat(40);
  const headSha = "2".repeat(40);
  const file = "packages/features/ee/workflows/api/scheduleEmailReminders.ts";
  const reviewId = "4923307916";
  const actorId = 12345;
  const body = "**Position finding**\n\nPosition description";
  mkdirSync(reviewRoot, { recursive: true });
  writeJson(join(caseRoot, "fixture.json"), {
    repository: "benchmark/private-fixture",
    prNumber: 42,
    defaultBranch: "main",
    baseBranch: "main",
    headBranch: "benchmark-head",
    baseSha,
    headSha,
    localBaseSha: baseSha,
    localHeadSha: headSha,
    localMergeBaseSha: baseSha,
    remoteBaseSha: baseSha,
    remoteHeadSha: headSha,
    remoteMergeBaseSha: baseSha,
    prBaseSha: baseSha,
    prHeadSha: headSha,
  });
  writeJson(join(reviewRoot, "meta.json"), { headRefOid: headSha });
  writeJson(join(reviewRoot, "findings.json"), [{
    title: "Position finding",
    description: "Position description",
    file,
    line: 56,
  }]);
  const requestPayloadPath = join(caseRoot, "review-request.json");
  writeJson(requestPayloadPath, {
    commit_id: headSha,
    body: "review body",
    event: "COMMENT",
    comments: [{ path: file, line: 56, side: "RIGHT", body }],
  });
  writeJson(join(reviewRoot, "delivery-create.json"), {
    schemaVersion: 1,
    attemptId: `attempt-${Date.now()}-${basename(caseRoot)}`,
    reviewId,
    event: "COMMENT",
    postEquivalentAttempts: 1,
  });
  const context = Array.from({ length: 24 }, (_, index) => ` context ${index + 32}`).join("\n");
  writeFileSync(join(reviewRoot, "diff.txt"), [
    `diff --git a/${file} b/${file}`,
    `--- a/${file}`,
    `+++ b/${file}`,
    "@@ -32,24 +32,25 @@",
    context,
    "+changed line 56",
    "",
  ].join("\n"));
  const review = {
    id: Number(reviewId),
    commit_id: headSha,
    state: "COMMENTED",
    body: "review body",
    user: { id: actorId },
  };
  const comment = {
    id: 9001,
    pull_request_review_id: Number(reviewId),
    path: file,
    body,
    commit_id: headSha,
    original_commit_id: headSha,
    html_url: "https://github.com/benchmark/private-fixture/pull/42#discussion_r9001",
    user: { id: actorId },
    diff_hunk: `@@ -32,24 +32,25 @@\n${context}\n+changed line 56`,
  };
  return { reviewRoot, requestPayloadPath, review, comment };
}

function nestedSession(jobId, role, sessionFile, terminalEntryId) {
  const sessionDir = dirname(sessionFile);
  return {
    jobId,
    role,
    sessionFile,
    terminalEntryId,
    closed: true,
    argv: ["/test/bin/omp", "--session-dir", sessionDir, "--max-time", role === "candidate" ? "30m" : "15m", "-p", "prompt"],
    stdin: "ignore",
  };
}
function writeBoundSessionUsage(sessions) {
  for (const session of sessions) {
    mkdirSync(dirname(session.sessionFile), { recursive: true });
    writeFileSync(session.sessionFile, `${JSON.stringify({
      type: "message",
      id: session.terminalEntryId,
      message: {
        role: "assistant",
        provider: "test-provider",
        model: "test-model",
        stopReason: "stop",
        usage: {
          input: 100,
          output: 10,
          cacheRead: 1000,
          cacheWrite: 50,
          cost: { total: 0.1 },
        },
      },
    })}\n`);
  }
}


function prepare(runRoot, dense = false, cohort = "historical-five-pr") {
  run("init", "--run-root", runRoot, "--skill-root", skillRoot, "--cohort", cohort);
  const corpus = JSON.parse(readFileSync(join(runRoot, "corpus.json"), "utf8"));
  const manifest = JSON.parse(readFileSync(join(runRoot, "manifest.json"), "utf8"));
  const activeCases = manifest.caseIds.map((id) => corpus.cases.find((item) => item.id === id));
  const stages = [];
  const timingStartMs = Date.now() - 12_000;
  const instant = (seconds) => new Date(timingStartMs + seconds * 1000).toISOString();
  for (const [index, item] of activeCases.entries()) {
    const findings = dense || item.id === "cal-dot-com" ? [finding(item.id)] : [];
    const reviewRoot = join(runRoot, "cases", item.id, "review");
    mkdirSync(reviewRoot);
    writeJson(join(runRoot, "cases", item.id, "findings.json"), findings);
    writeJson(join(reviewRoot, "findings.json"), findings);
    writeJson(join(reviewRoot, "raw_findings.json"), [...findings, finding("adjudicator-drop"), finding("finalizer-drop")]);
    writeJson(join(reviewRoot, "findings.adjudicator.json"), [...findings, finding("finalizer-drop")]);
    writeJson(join(reviewRoot, "validator-metrics.json"), { mode: "adjudicator", degraded: false, adjudicator_count: findings.length, kept_count: findings.length, nit_count: 0, deferred_count: 0 });
    const retried = index === 0 ? ["bugs"] : [];
    writeJson(join(reviewRoot, "swarm-metrics.json"), { schema_version: 1, mode: "host-managed", max_concurrency: null, angles_total: 2, chunks_total: 1, work_items_total: 2, first_pass_failed: retried, retry_angles: retried, still_invalid: [], degraded: false, executed_angles: ["bugs", "security"], expected_total: 2, missing_receipts: [] });
    const receiptIdentity = {
      runner: "test-runner",
      model: "test-model",
      tier: "standard",
      authority: "advisory-only",
      reviewerProfile: "test-profile",
      reviewerSessionId: `reviewer:${item.id}`,
      reviewerPrincipalId: "test-principal",
      reviewerCredentialContextId: "test-credential",
    };
    for (const angle of ["bugs", "security", "adjudicator"]) writeJson(join(reviewRoot, `receipt.${angle}.json`), { angle, chunk: null, ...receiptIdentity });
    const adjudicatorPath = join(reviewRoot, "findings.adjudicator.json");
    const adjudicatorReceiptPath = join(reviewRoot, "receipt.adjudicator.json");
    writeJson(join(reviewRoot, "validator-bindings.json"), {
      schemaVersion: 2,
      adjudicator: {
        ...receiptIdentity,
        findingsSha256: sha256(readFileSync(adjudicatorPath)),
        receiptSha256: sha256(readFileSync(adjudicatorReceiptPath)),
      },
    });
    const fixtureBase = String(index + 100).padStart(40, "0");
    const fixtureHead = String(index + 1).padStart(40, "0");
    writeJson(join(runRoot, "cases", item.id, "fixture.json"), {
      repository: "benchmark/private-fixture",
      prNumber: index + 1,
      defaultBranch: "main",
      baseBranch: "main",
      headBranch: "benchmark-head",
      baseSha: fixtureBase,
      headSha: fixtureHead,
      localBaseSha: fixtureBase,
      localHeadSha: fixtureHead,
      localMergeBaseSha: fixtureBase,
      remoteBaseSha: fixtureBase,
      remoteHeadSha: fixtureHead,
      remoteMergeBaseSha: fixtureBase,
      prBaseSha: fixtureBase,
      prHeadSha: fixtureHead,
    });
    writeJson(join(reviewRoot, "meta.json"), { headRefOid: fixtureHead });
    const event = findings.length ? "COMMENT" : "APPROVE";
    writeJson(join(reviewRoot, "delivery-create.json"), {
      schemaVersion: 1,
      attemptId: `create-${item.id}`,
      reviewId: `review-${item.id}`,
      event,
      postEquivalentAttempts: 1,
    });
    writeJson(join(reviewRoot, "delivery-readback.json"), {
      schemaVersion: 1,
      repository: "benchmark/private-fixture",
      prNumber: index + 1,
      headSha: fixtureHead,
      reviewId: `review-${item.id}`,
      event,
      state: event === "COMMENT" ? "COMMENTED" : "APPROVED",
      actorId: "benchmark-actor",
      comments: findings.map((entry, findingIndex) => ({
        findingSha256: sha256(JSON.stringify({ description: entry.description, title: entry.title })),
        commentId: `${item.id}-${findingIndex}`,
        url: `https://github.com/benchmark/private-fixture/pull/${index + 1}#discussion_r${findingIndex + 1}`,
      })),
    });
    const second = index * 2;
    stages.push({ caseId: item.id, name: "candidate-generation", startedAt: instant(second), completedAt: instant(second + 1) });
    stages.push({ caseId: item.id, name: "adjudication", startedAt: instant(second + 1), completedAt: instant(second + 2) });
  }
  stages.push({ caseId: null, name: "semantic-judging", startedAt: instant(10), completedAt: instant(11) });
  const planSummary = JSON.parse(run("plan", "--run-root", runRoot));
  assert.equal(planSummary.cases, 5);
  assert.equal(planSummary.candidates, dense ? 5 : 1);
  const plan = JSON.parse(readFileSync(join(runRoot, "judge-plan.json"), "utf8"));
  const sessions = [{ jobId: "benchmark/controller", role: "controller", sessionFile: join(workspace, "sessions", "benchmark-controller.jsonl"), terminalEntryId: "terminal-controller", closed: true }];
  for (const [index, item] of activeCases.entries()) {
    for (const label of ["bugs", "security"]) {
      sessions.push(nestedSession(`${item.id}/${label}/attempt-1`, "candidate", join(workspace, "sessions", `${item.id}-${label}-1`, "session.jsonl"), `terminal-${item.id}-${label}-1`));
    }
    if (index === 0) sessions.push(nestedSession(`${item.id}/bugs/attempt-2`, "candidate", join(workspace, "sessions", `${item.id}-bugs-2`, "session.jsonl"), `terminal-${item.id}-bugs-2`));
    sessions.push(nestedSession(`${item.id}/adjudicator`, "adjudicator", join(workspace, "sessions", `${item.id}-adjudicator`, "session.jsonl"), `terminal-${item.id}-adjudicator`));
  }
  sessions.push(...plan.pairs.map(({ id }) => nestedSession(`judge/${id}`, "judge", join(workspace, "sessions", `judge-${id}`, "session.jsonl"), `terminal-judge-${id}`)));
  writeJson(join(runRoot, "stage-timings.json"), { schemaVersion: 2, sessions, startedAt: instant(0), completedAt: instant(11), stages });
  const judgeContract = { schemaVersion: 1, provider: "test-provider", model: "test-model", agentType: "task", tier: "standard", effort: "high" };
  writeJson(join(runRoot, "judge-contract.json"), judgeContract);
  for (const pair of plan.pairs) {
    const decisionPath = join(runRoot, pair.decisionPath);
    writeJson(decisionPath, { reasoning: dense || pair.goldenId === "G01" ? "The underlying issue matches." : "The underlying issues differ.", match: dense || pair.goldenId === "G01", confidence: 0.99 });
    const session = sessions.find(({ jobId }) => jobId === `judge/${pair.id}`);
    writeJson(decisionPath.replace(/\.json$/, ".receipt.json"), {
      ...judgeContract,
      pairId: pair.id,
      promptSha256: sha256(pair.prompt),
      decisionSha256: sha256(readFileSync(decisionPath)),
      sessionFile: session.sessionFile,
      terminalEntryId: session.terminalEntryId,
    });
  }
  plan.sessions = sessions;
  return plan;
}

try {
  assert.equal(spawnSync("sqlite3", ["-version"], { encoding: "utf8" }).status, 0, "sqlite3 is required by the benchmark harness");
  const usageSource = join(workspace, "usage-source");
  const usageSourcePlan = prepare(usageSource, true);
  const usageDb = join(workspace, "usage.db");
  makeUsageDb(usageDb, usageSourcePlan.sessions);
  const verified = JSON.parse(run("verify-corpus"));
  assert.equal(verified.valid, true);
  assert.equal(verified.cases, 10);
  assert.equal(verified.goldens, 30);

  const historicalSelectionRoot = join(workspace, "historical-selection");
  run("init", "--run-root", historicalSelectionRoot, "--skill-root", skillRoot);
  const historicalManifest = JSON.parse(readFileSync(join(historicalSelectionRoot, "manifest.json"), "utf8"));
  assert.equal(historicalManifest.cohort, "historical-five-pr");
  assert.deepEqual(historicalManifest.caseIds, ["cal-dot-com", "discourse", "grafana", "keycloak", "sentry"]);
  const fullSelectionRoot = join(workspace, "full-selection");
  run("init", "--run-root", fullSelectionRoot, "--skill-root", skillRoot, "--cohort", "full-ten-pr");
  const fullManifest = JSON.parse(readFileSync(join(fullSelectionRoot, "manifest.json"), "utf8"));
  const fullCaseIds = ["cal-dot-com", "cal-dot-com-2", "discourse", "discourse-2", "grafana", "grafana-2", "keycloak", "keycloak-2", "sentry", "sentry-2"];
  assert.equal(fullManifest.cohort, "full-ten-pr");
  assert.deepEqual(fullManifest.caseIds, fullCaseIds);
  assert.deepEqual(fullManifest.expectedFindings, fullCaseIds.map((id) => `cases/${id}/findings.json`));
  assert.deepEqual(fullManifest.expectedReviewEvidence, fullCaseIds.map((id) => `cases/${id}/review`));
  for (const id of fullCaseIds) assert.equal(existsSync(join(fullSelectionRoot, "cases", id)), true);
  const identityPlanRoot = join(workspace, "identity-plan");
  run("init", "--run-root", identityPlanRoot, "--skill-root", skillRoot, "--cohort", "full-ten-pr");
  const identityFindings = [
    { title: "same accepted title", description: "same accepted description", file: "src/first.ts", line: 125 },
    { title: "same accepted title", description: "same accepted description", file: "src/second.ts", line: 125 },
  ];
  for (const item of JSON.parse(readFileSync(join(identityPlanRoot, "corpus.json"), "utf8")).cases) {
    writeJson(join(identityPlanRoot, "cases", item.id, "findings.json"), item.id === "cal-dot-com-2" ? identityFindings : []);
  }
  const identitySummary = JSON.parse(run("plan", "--run-root", identityPlanRoot));
  assert.deepEqual(identitySummary, { cases: 10, candidates: 2, pairs: 4 });
  const identityPlan = JSON.parse(readFileSync(join(identityPlanRoot, "judge-plan.json"), "utf8"));
  const identityCase = identityPlan.cases.find(({ id }) => id === "cal-dot-com-2");
  assert.deepEqual(identityCase.candidates.map(({ id }) => id), ["C01", "C02"]);
  assert.deepEqual(identityCase.candidates.map(({ text }) => text), [
    "same accepted title. same accepted description",
    "same accepted title. same accepted description",
  ]);
  assert.equal(identityPlan.pairs.length, 4);
  assert.deepEqual(identityPlan.cases.filter(({ id }) => id !== "cal-dot-com-2").map(({ candidates }) => candidates.length), Array(9).fill(0));

  const duplicateIdentityRoot = join(workspace, "duplicate-identity-plan");
  run("init", "--run-root", duplicateIdentityRoot, "--skill-root", skillRoot, "--cohort", "full-ten-pr");
  for (const item of JSON.parse(readFileSync(join(duplicateIdentityRoot, "corpus.json"), "utf8")).cases) {
    writeJson(join(duplicateIdentityRoot, "cases", item.id, "findings.json"), item.id === "cal-dot-com-2" ? [identityFindings[0], identityFindings[0]] : []);
  }
  assert.notEqual(execute("plan", "--run-root", duplicateIdentityRoot).status, 0);
  assert.equal(existsSync(join(duplicateIdentityRoot, "judge-plan.json")), false);

  const invalidCohortRoot = join(workspace, "invalid-cohort");
  assert.notEqual(execute("init", "--run-root", invalidCohortRoot, "--skill-root", skillRoot, "--cohort", "unknown").status, 0);
  assert.equal(existsSync(invalidCohortRoot), false);
  const fakeOmp = join(workspace, "fake-omp.mjs");
  writeFileSync(fakeOmp, `#!/usr/bin/env node
import { readSync, writeFileSync } from "node:fs";
const args = process.argv.slice(2);
const sessionDir = args[args.indexOf("--session-dir") + 1];
writeFileSync(process.env.FAKE_OMP_RECORD, JSON.stringify({ argv: args, stdinIgnored: readSync(0, Buffer.alloc(1), 0, 1, null) === 0 }));
process.stdout.write("captured stdout\\n");
process.stderr.write("captured stderr\\n");
if (process.env.FAKE_OMP_MODE === "nonzero") process.exit(7);
if (process.env.FAKE_OMP_MODE !== "missing") {
  writeFileSync(sessionDir + "/session.jsonl", JSON.stringify({ type: "message", id: "terminal-launch", message: { role: "assistant", usage: {} } }) + "\\n");
}
`);
  chmodSync(fakeOmp, 0o755);
  for (const [role, maxTime] of [["candidate", "30m"], ["adjudicator", "15m"], ["judge", "15m"]]) {
    const sessionDir = join(workspace, `launch-${role}`);
    const recordPath = join(workspace, `launch-${role}.json`);
    process.env.FAKE_OMP_RECORD = recordPath;
    const launchEvidence = JSON.parse(runWithInput(
      "sentinel",
      "launch-nested",
      "--role", role,
      "--job-id", `fixture/${role}`,
      "--session-dir", sessionDir,
      "--executable", fakeOmp,
      "--",
      "-p", `prompt-${role}`,
    ));
    assert.deepEqual(launchEvidence, {
      jobId: `fixture/${role}`,
      role,
      sessionFile: join(sessionDir, "session.jsonl"),
      terminalEntryId: "terminal-launch",
      closed: true,
      argv: [fakeOmp, "--session-dir", sessionDir, "--max-time", maxTime, "-p", `prompt-${role}`],
      stdin: "ignore",
    });
    assert.deepEqual(JSON.parse(readFileSync(recordPath, "utf8")), {
      argv: ["--session-dir", sessionDir, "--max-time", maxTime, "-p", `prompt-${role}`],
      stdinIgnored: true,
    });
    assert.equal(readFileSync(join(sessionDir, "launch.stdout.log"), "utf8"), "captured stdout\n");
    assert.equal(readFileSync(join(sessionDir, "launch.stderr.log"), "utf8"), "captured stderr\n");
  }
  const missingSessionDir = join(workspace, "launch-missing");
  process.env.FAKE_OMP_RECORD = join(workspace, "launch-missing.json");
  process.env.FAKE_OMP_MODE = "missing";
  assert.notEqual(execute(
    "launch-nested",
    "--role", "candidate",
    "--job-id", "fixture/missing",
    "--session-dir", missingSessionDir,
    "--executable", fakeOmp,
    "--",
    "-p", "prompt",
  ).status, 0);
  delete process.env.FAKE_OMP_MODE;
  assert.notEqual(execute(
    "launch-nested",
    "--role", "candidate",
    "--job-id", "fixture/collision",
    "--session-dir", missingSessionDir,
    "--executable", fakeOmp,
    "--",
    "-p", "prompt",
  ).status, 0);

  const runA = join(workspace, "a", "same-run");
  const runB = join(workspace, "b", "same-run");
  mkdirSync(dirname(runA));
  mkdirSync(dirname(runB));
  const runAPlan = prepare(runA);
  prepare(runB);
  const summary = JSON.parse(run("score", "--run-root", runA, "--usage-db", usageDb));
  assert.deepEqual(
    { tp: summary.tp, fp: summary.fp, fn: summary.fn, precision: summary.precision, recall: summary.recall, f1: summary.f1, f2: summary.f2, comparisonPassed: summary.comparisonPassed },
    { tp: 1, fp: 0, fn: 11, precision: 1, recall: 1 / 12, f1: 2 / 13, f2: 5 / 49, comparisonPassed: false },
  );
  assert.equal(summary.runRoot, runA);
  assert.match(summary.resultSha256, /^sha256:[0-9a-f]{64}$/);
  const result = JSON.parse(readFileSync(join(runA, "result.json"), "utf8"));
  assert.deepEqual(result.accounting.jobs, { candidateGeneration: { planned: 10, attempts: 11, retries: 1, completed: 10 }, adjudication: { planned: 5, attempts: 5, completed: 5 } });
  assert.deepEqual(result.accounting.rejectionReasons, { candidateFirstPassInvalid: 1, candidateInvalidAfterRetry: 0, candidateMissingReceipt: 0, adjudicatorRejected: 5, deterministicFinalizerRejected: 5 });
  assert.deepEqual(
    { candidateGeneration: result.accounting.timing.durationsMs.candidateGeneration, adjudication: result.accounting.timing.durationsMs.adjudication, semanticJudging: result.accounting.timing.durationsMs.semanticJudging },
    { candidateGeneration: 5000, adjudication: 5000, semanticJudging: 1000 },
  );
  assert.ok(result.accounting.timing.durationsMs.wall >= 12_000);
  assert.ok(result.accounting.timing.durationsMs.wall < 30_000);
  assert.equal(result.accounting.timing.completedAt, new Date(Date.parse(result.accounting.timing.startedAt) + result.accounting.timing.durationsMs.wall).toISOString());
  assert.ok(Date.parse(result.accounting.timing.completedAt) >= Date.parse(result.accounting.timing.stageCompletedAt));
  const requestCount = runAPlan.sessions.length;
  assert.deepEqual({
    requests: result.accounting.usage.modelRequests,
    input: result.accounting.usage.inputTokens,
    output: result.accounting.usage.outputTokens,
    cacheRead: result.accounting.usage.cacheReadTokens,
    cacheWrite: result.accounting.usage.cacheWriteTokens,
    cost: result.accounting.usage.cost,
  }, { requests: requestCount, input: requestCount * 100, output: requestCount * 10, cacheRead: requestCount * 1000, cacheWrite: requestCount * 50, cost: requestCount * 0.1 });
  assert.equal(result.comparison.directional, true);
  assert.equal(result.comparison.releaseVariance, false);
  run("score", "--run-root", runB, "--usage-db", usageDb);
  const resultB = JSON.parse(readFileSync(join(runB, "result.json"), "utf8"));
  const stableResult = (value) => {
    const copy = structuredClone(value);
    delete copy.accounting.timing;
    delete copy.comparison;
    return copy;
  };
  assert.deepEqual(stableResult(result), stableResult(resultB));
  assert.notEqual(execute("score", "--run-root", runA, "--usage-db", usageDb).status, 0);

  const passingRun = join(workspace, "passing");
  prepare(passingRun, true);
  run("score", "--run-root", passingRun, "--usage-db", usageDb);
  assert.equal(JSON.parse(readFileSync(join(passingRun, "result.json"), "utf8")).comparison.passed, true);
  const directUsageRun = join(workspace, "direct-session-usage");
  const directUsagePlan = prepare(directUsageRun);
  writeBoundSessionUsage(directUsagePlan.sessions);
  const emptyUsageDb = join(workspace, "empty-usage.db");
  makeUsageDb(emptyUsageDb, []);
  assert.equal(execute("score", "--run-root", directUsageRun, "--usage-db", emptyUsageDb).status, 0);


  const missingReceiptRun = join(workspace, "missing-receipt");
  prepare(missingReceiptRun);
  rmSync(join(missingReceiptRun, "cases", "cal-dot-com", "review", "receipt.bugs.json"));
  assert.notEqual(execute("score", "--run-root", missingReceiptRun, "--usage-db", usageDb).status, 0);
  assert.equal(existsSync(join(missingReceiptRun, "result.json")), false);

  const missingBindingRun = join(workspace, "missing-binding");
  prepare(missingBindingRun);
  rmSync(join(missingBindingRun, "cases", "cal-dot-com", "review", "validator-bindings.json"));
  assert.notEqual(execute("score", "--run-root", missingBindingRun, "--usage-db", usageDb).status, 0);
  assert.equal(existsSync(join(missingBindingRun, "result.json")), false);


  const mismatchedBindingRun = join(workspace, "mismatched-binding");
  prepare(mismatchedBindingRun);
  const bindingPath = join(mismatchedBindingRun, "cases", "cal-dot-com", "review", "validator-bindings.json");
  const mismatchedBinding = JSON.parse(readFileSync(bindingPath, "utf8"));
  mismatchedBinding.adjudicator.findingsSha256 = `sha256:${"0".repeat(64)}`;
  writeJson(bindingPath, mismatchedBinding);
  assert.notEqual(execute("score", "--run-root", mismatchedBindingRun, "--usage-db", usageDb).status, 0);
  assert.equal(existsSync(join(mismatchedBindingRun, "result.json")), false);

  const mismatchedDeliveryRun = join(workspace, "mismatched-delivery");
  prepare(mismatchedDeliveryRun);
  const deliveryPath = join(mismatchedDeliveryRun, "cases", "cal-dot-com", "review", "delivery-readback.json");
  const mismatchedDelivery = JSON.parse(readFileSync(deliveryPath, "utf8"));
  mismatchedDelivery.comments[0].findingSha256 = `sha256:${"0".repeat(64)}`;
  writeJson(deliveryPath, mismatchedDelivery);
  assert.notEqual(execute("score", "--run-root", mismatchedDeliveryRun, "--usage-db", usageDb).status, 0);
  assert.equal(existsSync(join(mismatchedDeliveryRun, "result.json")), false);
  const mappedStateRun = join(workspace, "mapped-state");
  prepare(mappedStateRun);
  const mappedStatePath = join(mappedStateRun, "cases", "cal-dot-com", "review", "delivery-readback.json");
  const mappedState = JSON.parse(readFileSync(mappedStatePath, "utf8"));
  mappedState.state = "APPROVED";
  writeJson(mappedStatePath, mappedState);
  assert.notEqual(execute("score", "--run-root", mappedStateRun, "--usage-db", usageDb).status, 0);
  assert.equal(existsSync(join(mappedStateRun, "result.json")), false);

  const invalidTopologyRun = join(workspace, "invalid-topology");
  prepare(invalidTopologyRun);
  const topologyPath = join(invalidTopologyRun, "cases", "cal-dot-com", "fixture.json");
  const invalidTopology = JSON.parse(readFileSync(topologyPath, "utf8"));
  invalidTopology.remoteHeadSha = invalidTopology.remoteBaseSha;
  writeJson(topologyPath, invalidTopology);
  assert.notEqual(execute("score", "--run-root", invalidTopologyRun, "--usage-db", usageDb).status, 0);
  assert.equal(existsSync(join(invalidTopologyRun, "result.json")), false);

  const divergedBranchRun = join(workspace, "diverged-branch");
  prepare(divergedBranchRun);
  const divergedTopologyPath = join(divergedBranchRun, "cases", "cal-dot-com", "fixture.json");
  const divergedTopology = JSON.parse(readFileSync(divergedTopologyPath, "utf8"));
  divergedTopology.localMergeBaseSha = divergedTopology.headSha;
  writeJson(divergedTopologyPath, divergedTopology);
  assert.notEqual(execute("score", "--run-root", divergedBranchRun, "--usage-db", usageDb).status, 0);
  assert.equal(existsSync(join(divergedBranchRun, "result.json")), false);

  const duplicateCreateRun = join(workspace, "duplicate-create");
  prepare(duplicateCreateRun);
  const duplicateCreateCorpus = JSON.parse(readFileSync(join(duplicateCreateRun, "corpus.json"), "utf8"));
  const duplicateCreateCases = duplicateCreateCorpus.cases.filter((item) => item.rank === 1);
  const firstCreateReceipt = JSON.parse(readFileSync(join(duplicateCreateRun, "cases", duplicateCreateCases[0].id, "review", "delivery-create.json"), "utf8"));
  const duplicateCreatePath = join(duplicateCreateRun, "cases", duplicateCreateCases[1].id, "review", "delivery-create.json");
  const duplicateCreateReceipt = JSON.parse(readFileSync(duplicateCreatePath, "utf8"));
  const secondAttemptId = duplicateCreateReceipt.attemptId;
  duplicateCreateReceipt.attemptId = firstCreateReceipt.attemptId;
  writeJson(duplicateCreatePath, duplicateCreateReceipt);
  assert.notEqual(execute("score", "--run-root", duplicateCreateRun, "--usage-db", usageDb).status, 0);
  assert.equal(existsSync(join(duplicateCreateRun, "result.json")), false);
  duplicateCreateReceipt.attemptId = secondAttemptId;
  duplicateCreateReceipt.reviewId = firstCreateReceipt.reviewId;
  writeJson(duplicateCreatePath, duplicateCreateReceipt);
  const duplicateReviewReadbackPath = join(duplicateCreateRun, "cases", duplicateCreateCases[1].id, "review", "delivery-readback.json");
  const duplicateReviewReadback = JSON.parse(readFileSync(duplicateReviewReadbackPath, "utf8"));
  duplicateReviewReadback.reviewId = firstCreateReceipt.reviewId;
  writeJson(duplicateReviewReadbackPath, duplicateReviewReadback);
  assert.notEqual(execute("score", "--run-root", duplicateCreateRun, "--usage-db", usageDb).status, 0);
  assert.equal(existsSync(join(duplicateCreateRun, "result.json")), false);

  const deliveryCaseRoot = join(workspace, "owned-delivery");
  const readbackFailureRoot = join(deliveryCaseRoot, "review");
  mkdirSync(readbackFailureRoot, { recursive: true });
  const deliveryBase = "1".repeat(40);
  const deliveryHead = "2".repeat(40);
  writeJson(join(deliveryCaseRoot, "fixture.json"), {
    repository: "benchmark/private-fixture",
    prNumber: 42,
    defaultBranch: "main",
    baseBranch: "main",
    headBranch: "benchmark-head",
    baseSha: deliveryBase,
    headSha: deliveryHead,
    localBaseSha: deliveryBase,
    localHeadSha: deliveryHead,
    localMergeBaseSha: deliveryBase,
    remoteBaseSha: deliveryBase,
    remoteHeadSha: deliveryHead,
    remoteMergeBaseSha: deliveryBase,
    prBaseSha: deliveryBase,
    prHeadSha: deliveryHead,
  });
  const requestPayloadPath = join(deliveryCaseRoot, "review-request.json");
  writeJson(requestPayloadPath, { event: "COMMENT", body: "review body" });
  const fakeGh = join(workspace, "fake-gh.mjs");
  writeFileSync(fakeGh, `#!/usr/bin/env node
import { existsSync, readFileSync, writeFileSync } from "node:fs";
const args = process.argv.slice(2);
if (args[args.indexOf("--method") + 1] !== "POST") process.exit(9);
const count = existsSync(process.env.FAKE_GH_COUNT) ? Number(readFileSync(process.env.FAKE_GH_COUNT, "utf8")) : 0;
writeFileSync(process.env.FAKE_GH_COUNT, String(count + 1));
writeFileSync(process.env.FAKE_GH_ARGS, JSON.stringify(args));
process.stdout.write(JSON.stringify({ id: "review-once" }));
`);
  chmodSync(fakeGh, 0o755);
  const fakeGhCount = join(workspace, "fake-gh-count");
  const fakeGhArgs = join(workspace, "fake-gh-args.json");
  process.env.FAKE_GH_COUNT = fakeGhCount;
  process.env.FAKE_GH_ARGS = fakeGhArgs;
  const created = JSON.parse(run(
    "create-delivery",
    "--review-root", readbackFailureRoot,
    "--attempt-id", "attempt-once",
    "--request-payload", requestPayloadPath,
    "--gh", fakeGh,
  ));
  assert.deepEqual(created, {
    schemaVersion: 1,
    attemptId: "attempt-once",
    reviewId: "review-once",
    event: "COMMENT",
    postEquivalentAttempts: 1,
  });
  assert.deepEqual(JSON.parse(readFileSync(fakeGhArgs, "utf8")), [
    "api", "--method", "POST", "repos/benchmark/private-fixture/pulls/42/reviews", "--input", requestPayloadPath,
  ]);
  assert.notEqual(spawnSync(fakeGh, ["api", "--method", "GET"], { encoding: "utf8" }).status, 0);
  assert.equal(readFileSync(fakeGhCount, "utf8"), "1");
  const createReceiptPath = join(readbackFailureRoot, "delivery-create.json");
  const firstCreateBytes = readFileSync(createReceiptPath, "utf8");
  assert.equal(existsSync(join(readbackFailureRoot, "delivery-readback.json")), false);
  assert.notEqual(execute(
    "create-delivery",
    "--review-root", readbackFailureRoot,
    "--attempt-id", "attempt-retry",
    "--request-payload", requestPayloadPath,
    "--gh", fakeGh,
  ).status, 0);
  assert.equal(readFileSync(fakeGhCount, "utf8"), "1");
  assert.equal(readFileSync(createReceiptPath, "utf8"), firstCreateBytes);

  const readbackGh = join(workspace, "fake-readback-gh.mjs");
  writeFileSync(readbackGh, `#!/usr/bin/env node
import { existsSync, readFileSync, writeFileSync } from "node:fs";
const args = process.argv.slice(2);
const prior = existsSync(process.env.FAKE_READBACK_GH_LOG) ? readFileSync(process.env.FAKE_READBACK_GH_LOG, "utf8") : "";
writeFileSync(process.env.FAKE_READBACK_GH_LOG, prior + JSON.stringify(args) + "\\n");
if (args[args.indexOf("--method") + 1] !== "GET") {
  writeFileSync(process.env.FAKE_READBACK_POST, "called");
  process.exit(9);
}
const response = JSON.parse(readFileSync(process.env.FAKE_READBACK_RESPONSE, "utf8"));
process.stdout.write(JSON.stringify(args.at(-1).includes("/comments?") ? [response.comments] : response.review));
`);
  chmodSync(readbackGh, 0o755);
  const readbackGhLog = join(workspace, "fake-readback-gh.log");
  const readbackPost = join(workspace, "fake-readback-post");
  const readbackResponse = join(workspace, "fake-readback-response.json");
  const resolver = join(skillRoot, "scripts", "resolve-diff-line.sh");
  process.env.FAKE_READBACK_GH_LOG = readbackGhLog;
  process.env.FAKE_READBACK_POST = readbackPost;
  process.env.FAKE_READBACK_RESPONSE = readbackResponse;
  const executeReadback = (caseRoot, response, explicitFixture = false) => {
    writeJson(readbackResponse, response);
    const prepared = prepareReadbackCase(caseRoot);
    const argv = [
      "read-delivery",
      "--review-root", prepared.reviewRoot,
      "--request-payload", prepared.requestPayloadPath,
      "--gh", readbackGh,
      "--resolver", resolver,
    ];
    if (explicitFixture) argv.push("--fixture", join(caseRoot, "fixture.json"));
    return { prepared, result: execute(...argv) };
  };

  const lineCaseRoot = join(workspace, "readback-line-side");
  const linePrepared = prepareReadbackCase(lineCaseRoot);
  const lineComment = {
    ...linePrepared.comment,
    line: 56,
    original_line: 56,
    side: "RIGHT",
    position: 25,
    original_position: 25,
  };
  writeJson(readbackResponse, { review: linePrepared.review, comments: [lineComment] });
  const lineReadback = JSON.parse(run(
    "read-delivery",
    "--review-root", linePrepared.reviewRoot,
    "--fixture", join(lineCaseRoot, "fixture.json"),
    "--request-payload", linePrepared.requestPayloadPath,
    "--gh", readbackGh,
    "--resolver", resolver,
  ));
  assert.equal(lineReadback.reviewId, "4923307916");
  assert.equal(lineReadback.comments.length, 1);

  const positionCaseRoot = join(workspace, "readback-position-only");
  const positionPrepared = prepareReadbackCase(positionCaseRoot);
  const positionComment = {
    ...positionPrepared.comment,
    line: null,
    original_line: null,
    side: null,
    position: 25,
    original_position: 25,
  };
  writeJson(readbackResponse, { review: positionPrepared.review, comments: [positionComment] });
  const positionResult = execute(
    "read-delivery",
    "--review-root", positionPrepared.reviewRoot,
    "--request-payload", positionPrepared.requestPayloadPath,
    "--gh", readbackGh,
    "--resolver", resolver,
  );
  assert.equal(positionResult.status, 0, positionResult.stderr);
  assert.equal(existsSync(join(positionPrepared.reviewRoot, "delivery-readback.json")), true);

  const wrongPositionRoot = join(workspace, "readback-wrong-position");
  const wrongPosition = executeReadback(wrongPositionRoot, {
    review: positionPrepared.review,
    comments: [{ ...positionComment, position: 24, original_position: 24 }],
  });
  assert.notEqual(wrongPosition.result.status, 0);
  assert.equal(existsSync(join(wrongPosition.prepared.reviewRoot, "delivery-readback.json")), false);

  const staleHeadRoot = join(workspace, "readback-stale-head");
  const staleHead = executeReadback(staleHeadRoot, {
    review: { ...positionPrepared.review, commit_id: "f".repeat(40) },
    comments: [positionComment],
  });
  assert.notEqual(staleHead.result.status, 0);
  assert.equal(existsSync(join(staleHead.prepared.reviewRoot, "delivery-readback.json")), false);

  const duplicateRoot = join(workspace, "readback-duplicate-comment");
  const duplicate = executeReadback(duplicateRoot, {
    review: positionPrepared.review,
    comments: [
      positionComment,
      {
        ...positionComment,
        id: 9002,
        html_url: "https://github.com/benchmark/private-fixture/pull/42#discussion_r9002",
      },
    ],
  });
  assert.notEqual(duplicate.result.status, 0);
  assert.equal(existsSync(join(duplicate.prepared.reviewRoot, "delivery-readback.json")), false);

  const missingRoot = join(workspace, "readback-missing-comment");
  const missing = executeReadback(missingRoot, { review: positionPrepared.review, comments: [] });
  assert.notEqual(missing.result.status, 0);
  assert.equal(existsSync(join(missing.prepared.reviewRoot, "delivery-readback.json")), false);
  assert.equal(existsSync(readbackPost), false);
  for (const argv of readFileSync(readbackGhLog, "utf8").trim().split("\n").map(JSON.parse)) {
    assert.equal(argv.includes("POST"), false);
  }

  const shellMarker = join(workspace, "shell-probe-marker");
  const shellPayload = `$(touch ${shellMarker})`;
  const promptRoot = join(workspace, "prompt-shell-safety");
  const promptUsageDb = join(workspace, "usage-shell-safety.db");
  const renderedPrompt = spawnSync(join(root, "run.sh"), ["--render-prompt", "--org", `owner-${shellPayload}`, "--run-root", promptRoot], {
    encoding: "utf8",
    env: { ...process.env, WOO_BENCHMARK_USAGE_DB: promptUsageDb },
  });
  assert.equal(renderedPrompt.status, 0, renderedPrompt.stderr);
  assert.ok(renderedPrompt.stdout.includes(`- create-new run root: ${promptRoot}`));
  assert.ok(renderedPrompt.stdout.includes(`- authenticated GitHub namespace: owner-${shellPayload}`));
  assert.match(renderedPrompt.stdout, /benchmark\.mjs create-delivery/);
  assert.match(renderedPrompt.stdout, /benchmark\.mjs launch-nested/);
  assert.match(renderedPrompt.stdout, /candidate 30m; adjudicator and judge 15m/);
  assert.equal(existsSync(shellMarker), false);
  const fullPromptRoot = join(workspace, "prompt-full");
  const fullPrompt = spawnSync(join(root, "run.sh"), ["--render-prompt", "--org", "benchmark-test", "--cohort", "full-ten-pr", "--run-root", fullPromptRoot], { encoding: "utf8" });
  assert.equal(fullPrompt.status, 0, fullPrompt.stderr);
  assert.match(fullPrompt.stdout, /- cohort: full-ten-pr/);
  for (const repository of ["woostack-review-recall-20260814-cal-dot-com", "woostack-review-recall-20260814-cal-dot-com-2", "woostack-review-recall-20260814-discourse", "woostack-review-recall-20260814-discourse-2", "woostack-review-recall-20260814-grafana", "woostack-review-recall-20260814-grafana-2", "woostack-review-recall-20260814-keycloak", "woostack-review-recall-20260814-keycloak-2", "woostack-review-recall-20260814-sentry", "woostack-review-recall-20260814-sentry-2"]) assert.match(fullPrompt.stdout, new RegExp(repository));
  const bugsPrompt = readFileSync(join(skillRoot, "prompts", "angles", "bugs.md"), "utf8");
  const validatorPrompt = readFileSync(join(skillRoot, "prompts", "validator.md"), "utf8");
  assert.match(bugsPrompt, /definitions? or signatures? visible in the diff or permitted evidence/);
  assert.match(bugsPrompt, /never infer unavailable overloads or source/);
  assert.match(validatorPrompt, /definitions or signatures visible in the diff or permitted evidence/);
  assert.match(validatorPrompt, /reject speculation about unavailable overloads or source/);

  const missingDeliveryRun = join(workspace, "missing-delivery");

  const staleDeliveryRun = join(workspace, "stale-delivery");
  prepare(staleDeliveryRun);
  writeJson(join(staleDeliveryRun, "cases", "cal-dot-com", "review", "meta.json"), { headRefOid: "f".repeat(40) });
  assert.notEqual(execute("score", "--run-root", staleDeliveryRun, "--usage-db", usageDb).status, 0);
  assert.equal(existsSync(join(staleDeliveryRun, "result.json")), false);

  const normalizedFindingRun = join(workspace, "normalized-finding");
  prepare(normalizedFindingRun);
  const normalizedReviewRoot = join(normalizedFindingRun, "cases", "cal-dot-com", "review");
  const normalizedPath = join(normalizedReviewRoot, "findings.adjudicator.json");
  const normalized = JSON.parse(readFileSync(normalizedPath, "utf8"));
  normalized[0].description = "Adjudicator-normalized evidence prose";
  normalized[0].blocking = false;
  writeJson(normalizedPath, normalized);
  const normalizedBindingPath = join(normalizedReviewRoot, "validator-bindings.json");
  const normalizedBinding = JSON.parse(readFileSync(normalizedBindingPath, "utf8"));
  normalizedBinding.adjudicator.findingsSha256 = sha256(readFileSync(normalizedPath));
  writeJson(normalizedBindingPath, normalizedBinding);
  assert.equal(execute("score", "--run-root", normalizedFindingRun, "--usage-db", usageDb).status, 0);

  const rewrittenFindingRun = join(workspace, "rewritten-finding");
  prepare(rewrittenFindingRun);
  const rewrittenPath = join(rewrittenFindingRun, "cases", "cal-dot-com", "review", "findings.adjudicator.json");
  const rewritten = JSON.parse(readFileSync(rewrittenPath, "utf8"));
  rewritten[0].title = "invented replacement";
  writeJson(rewrittenPath, rewritten);
  assert.notEqual(execute("score", "--run-root", rewrittenFindingRun, "--usage-db", usageDb).status, 0);
  assert.equal(existsSync(join(rewrittenFindingRun, "result.json")), false);

  const missingTerminalRun = join(workspace, "missing-terminal");
  const missingTerminalPlan = prepare(missingTerminalRun);
  const missingTerminalDb = join(workspace, "missing-terminal.db");
  makeUsageDb(missingTerminalDb, missingTerminalPlan.sessions);
  const missingTerminalTimingPath = join(missingTerminalRun, "stage-timings.json");
  const missingTerminalTiming = JSON.parse(readFileSync(missingTerminalTimingPath, "utf8"));
  missingTerminalTiming.sessions[0].terminalEntryId = "not-ingested";
  writeJson(missingTerminalTimingPath, missingTerminalTiming);
  assert.notEqual(execute("score", "--run-root", missingTerminalRun, "--usage-db", missingTerminalDb).status, 0);
  assert.equal(existsSync(join(missingTerminalRun, "result.json")), false);
  prepare(missingDeliveryRun);
  rmSync(join(missingDeliveryRun, "cases", "cal-dot-com", "review", "delivery-readback.json"));
  assert.notEqual(execute("score", "--run-root", missingDeliveryRun, "--usage-db", usageDb).status, 0);
  assert.equal(existsSync(join(missingDeliveryRun, "result.json")), false);

  const incompleteSessionsRun = join(workspace, "incomplete-sessions");
  prepare(incompleteSessionsRun);
  const incompleteTiming = JSON.parse(readFileSync(join(incompleteSessionsRun, "stage-timings.json"), "utf8"));
  incompleteTiming.sessions.pop();
  writeJson(join(incompleteSessionsRun, "stage-timings.json"), incompleteTiming);
  assert.notEqual(execute("score", "--run-root", incompleteSessionsRun, "--usage-db", usageDb).status, 0);
  assert.equal(existsSync(join(incompleteSessionsRun, "result.json")), false);

  const invalidLaunchRun = join(workspace, "invalid-launch");
  prepare(invalidLaunchRun);
  const invalidLaunchTimingPath = join(invalidLaunchRun, "stage-timings.json");
  const invalidLaunchTiming = JSON.parse(readFileSync(invalidLaunchTimingPath, "utf8"));
  const invalidCandidateLaunch = invalidLaunchTiming.sessions.find(({ role }) => role === "candidate");
  invalidCandidateLaunch.argv[invalidCandidateLaunch.argv.indexOf("--max-time") + 1] = "15m";
  writeJson(invalidLaunchTimingPath, invalidLaunchTiming);
  assert.notEqual(execute("score", "--run-root", invalidLaunchRun, "--usage-db", usageDb).status, 0);
  assert.equal(existsSync(join(invalidLaunchRun, "result.json")), false);

  const malformedTimingRun = join(workspace, "malformed-timing");
  prepare(malformedTimingRun);
  const timing = JSON.parse(readFileSync(join(malformedTimingRun, "stage-timings.json"), "utf8"));
  timing.stages.pop();
  writeJson(join(malformedTimingRun, "stage-timings.json"), timing);
  assert.notEqual(execute("score", "--run-root", malformedTimingRun, "--usage-db", usageDb).status, 0);
  assert.equal(existsSync(join(malformedTimingRun, "result.json")), false);

  const malformedUsageRun = join(workspace, "malformed-usage");
  const malformedUsagePlan = prepare(malformedUsageRun);
  const malformedUsageDb = join(workspace, "malformed-usage.db");
  makeUsageDb(malformedUsageDb, malformedUsagePlan.sessions, true);
  assert.notEqual(execute("score", "--run-root", malformedUsageRun, "--usage-db", malformedUsageDb).status, 0);
  assert.equal(existsSync(join(malformedUsageRun, "result.json")), false);

  const missingJudgmentRun = join(workspace, "missing-judgment");
  const missingPlan = prepare(missingJudgmentRun);
  rmSync(join(missingJudgmentRun, missingPlan.pairs[0].decisionPath));

  const mismatchedJudgeRun = join(workspace, "mismatched-judge");
  const mismatchedJudgePlan = prepare(mismatchedJudgeRun);
  const judgeReceiptPath = join(mismatchedJudgeRun, mismatchedJudgePlan.pairs[0].decisionPath.replace(/\.json$/, ".receipt.json"));
  const judgeReceipt = JSON.parse(readFileSync(judgeReceiptPath, "utf8"));
  judgeReceipt.promptSha256 = `sha256:${"0".repeat(64)}`;
  writeJson(judgeReceiptPath, judgeReceipt);
  assert.notEqual(execute("score", "--run-root", mismatchedJudgeRun, "--usage-db", usageDb).status, 0);
  assert.equal(existsSync(join(mismatchedJudgeRun, "result.json")), false);
  assert.notEqual(execute("score", "--run-root", missingJudgmentRun, "--usage-db", usageDb).status, 0);
  assert.equal(existsSync(join(missingJudgmentRun, "result.json")), false);

  const dryRunRoot = join(workspace, "dry-run");
  const dryRun = spawnSync(join(root, "run.sh"), ["--dry-run", "--org", "benchmark-test", "--run-root", dryRunRoot], { encoding: "utf8" });
  assert.equal(dryRun.status, 0, dryRun.stderr);
  assert.deepEqual(JSON.parse(dryRun.stdout), { repositoryRoot: resolve(root, "..", ".."), benchmarkRoot: root, skillRoot, runRoot: dryRunRoot, githubNamespace: "benchmark-test", usageDb: resolve(process.env.HOME, ".omp", "stats.db"), cohort: "historical-five-pr", caseIds: ["cal-dot-com", "discourse", "grafana", "keycloak", "sentry"], dryRun: true });
  assert.equal(existsSync(dryRunRoot), false);
  const fullDryRunRoot = join(workspace, "dry-run-full");
  const fullDryRun = spawnSync(join(root, "run.sh"), ["--dry-run", "--org", "benchmark-test", "--cohort", "full-ten-pr", "--run-root", fullDryRunRoot], { encoding: "utf8" });
  assert.equal(fullDryRun.status, 0, fullDryRun.stderr);
  assert.deepEqual(JSON.parse(fullDryRun.stdout).caseIds, ["cal-dot-com", "cal-dot-com-2", "discourse", "discourse-2", "grafana", "grafana-2", "keycloak", "keycloak-2", "sentry", "sentry-2"]);
  assert.equal(existsSync(fullDryRunRoot), false);
  console.log("benchmark harness tests passed");
} finally {
  rmSync(workspace, { recursive: true, force: true });
}
