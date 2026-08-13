#!/usr/bin/env node

import { createHash } from "node:crypto";
import { existsSync, linkSync, lstatSync, mkdirSync, readFileSync, readdirSync, realpathSync, renameSync, statSync, unlinkSync, writeFileSync } from "node:fs";
import { basename, dirname, isAbsolute, join, relative, resolve, sep } from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const benchmarkRoot = dirname(fileURLToPath(import.meta.url));
const corpusPath = join(benchmarkRoot, "corpus.json");
const coreCategories = new Set(["api", "bug", "concurrency", "data", "doc_defect", "perf", "security", "test_gap"]);
const historicalCohort = "historical-five-pr";
const deliveryStates = Object.freeze({
  COMMENT: "COMMENTED",
  APPROVE: "APPROVED",
  REQUEST_CHANGES: "CHANGES_REQUESTED",
});
const thresholds = {
  falsePositivesBelow: 8,
  precisionAbove: 0.333,
  truePositivesAtLeast: 4,
  recallAtLeast: 0.333,
  f2AtLeast: 0.333,
  wallTimeMsBelow: 1_157_335,
  costBelow: 79.5203485,
};

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
function findingIdentity(finding) {
  return canonical({
    file: finding.file ?? null,
    line: finding.line ?? null,
    end_line: finding.end_line ?? null,
    title: finding.title ?? null,
  });
}

function sha256(value) {
  return `sha256:${createHash("sha256").update(value).digest("hex")}`;
}
function requireFixtureTopology(fixture, label) {
  assertExactKeys(fixture, [
    "repository", "prNumber", "defaultBranch", "baseBranch", "headBranch",
    "baseSha", "headSha", "localBaseSha", "localHeadSha", "localMergeBaseSha",
    "remoteBaseSha", "remoteHeadSha", "remoteMergeBaseSha", "prBaseSha", "prHeadSha",
  ], label);
  const shaFields = [
    "baseSha", "headSha", "localBaseSha", "localHeadSha", "localMergeBaseSha",
    "remoteBaseSha", "remoteHeadSha", "remoteMergeBaseSha", "prBaseSha", "prHeadSha",
  ];
  if (fixture.defaultBranch !== "main"
    || fixture.baseBranch !== "main"
    || fixture.headBranch !== "benchmark-head"
    || !shaFields.every((field) => typeof fixture[field] === "string" && /^[0-9a-f]{40}$/.test(fixture[field]))
    || fixture.baseSha === fixture.headSha
    || fixture.localBaseSha !== fixture.baseSha
    || fixture.localHeadSha !== fixture.headSha
    || fixture.localMergeBaseSha !== fixture.baseSha
    || fixture.remoteBaseSha !== fixture.baseSha
    || fixture.remoteHeadSha !== fixture.headSha
    || fixture.remoteMergeBaseSha !== fixture.baseSha
    || fixture.prBaseSha !== fixture.baseSha
    || fixture.prHeadSha !== fixture.headSha) fail(`${label} does not prove the expected base/head topology`);
}

function validateNestedLaunchEvidence(binding, label) {
  if (!["candidate", "adjudicator", "judge"].includes(binding.role)
    || !Array.isArray(binding.argv)
    || binding.argv.some((value) => typeof value !== "string" || !value)
    || binding.stdin !== "ignore"
    || !isAbsolute(binding.sessionFile)) fail(`invalid nested launch evidence for ${label}`);
  if (binding.argv.length < 6 || !isAbsolute(binding.argv[0])) fail(`invalid OMP argv for ${label}`);
  const flagValues = (flag) => binding.argv.flatMap((value, index) => value === flag ? [binding.argv[index + 1]] : []);
  const sessionDirs = flagValues("--session-dir");
  const maxTimes = flagValues("--max-time");
  const expectedMaxTime = binding.role === "candidate" ? "30m" : "15m";
  if (sessionDirs.length !== 1 || maxTimes.length !== 1 || !sessionDirs[0] || !isAbsolute(sessionDirs[0])
    || maxTimes[0] !== expectedMaxTime) fail(`invalid OMP argv for ${label}`);
  const sessionRelative = relative(resolve(sessionDirs[0]), resolve(binding.sessionFile));
  if (!sessionRelative || sessionRelative === ".." || sessionRelative.startsWith(`..${sep}`) || isAbsolute(sessionRelative)) {
    fail(`session file is outside the dedicated session directory for ${label}`);
  }
}

function terminalAssistantEntry(sessionFile) {
  let entries;
  try {
    entries = readFileSync(sessionFile, "utf8")
      .split(/\r?\n/)
      .filter(Boolean)
      .map((line) => JSON.parse(line));
  } catch (error) {
    fail(`cannot read nested session ${sessionFile}: ${error.message}`);
  }
  const terminal = entries.filter((entry) => entry?.type === "message"
    && entry.message?.role === "assistant"
    && entry.message.usage
    && typeof entry.message.usage === "object"
    && !Array.isArray(entry.message.usage)).at(-1);
  if (typeof terminal?.id !== "string" || !terminal.id) fail(`cannot resolve terminal assistant entry from ${sessionFile}`);
  return terminal.id;
}

function launchNested(args) {
  const separator = args.indexOf("--");
  if (separator < 0) fail("launch-nested requires -- before the nested OMP arguments");
  const flags = parseFlags(args.slice(0, separator), ["--role", "--job-id", "--session-dir", "--executable"]);
  for (const field of ["--role", "--job-id", "--session-dir", "--executable"]) {
    if (!flags[field]) fail(`launch-nested requires ${field}`);
  }
  if (!["candidate", "adjudicator", "judge"].includes(flags["--role"])) fail("launch-nested has an invalid role");
  if (!isAbsolute(flags["--executable"]) || !existsSync(flags["--executable"])) fail("launch-nested requires an existing absolute executable");
  const forwarded = args.slice(separator + 1);
  if (!forwarded.length || forwarded.includes("--session-dir") || forwarded.includes("--max-time")) {
    fail("launch-nested requires complete non-owned arguments without --session-dir or --max-time");
  }
  const sessionDir = resolve(flags["--session-dir"]);
  mkdirSync(dirname(sessionDir), { recursive: true });
  try {
    mkdirSync(sessionDir);
  } catch (error) {
    fail(`nested session directory must be create-new: ${error.message}`);
  }
  const maxTime = flags["--role"] === "candidate" ? "30m" : "15m";
  const argv = [flags["--executable"], "--session-dir", sessionDir, "--max-time", maxTime, ...forwarded];
  const result = spawnSync(argv[0], argv.slice(1), { encoding: "utf8", shell: false, stdin: "ignore" });
  try {
    writeFileSync(join(sessionDir, "launch.stdout.log"), result.stdout ?? "", { flag: "wx" });
    writeFileSync(join(sessionDir, "launch.stderr.log"), result.stderr ?? "", { flag: "wx" });
  } catch (error) {
    fail(`cannot persist nested launch output: ${error.message}`);
  }
  if (result.error) fail(`nested OMP launch failed: ${result.error.message}`);
  if (result.status !== 0 || result.signal) {
    fail(`nested OMP exited with status ${result.status ?? "null"}${result.signal ? ` and signal ${result.signal}` : ""}`);
  }
  const sessionFiles = readdirSync(sessionDir).filter((name) => name.endsWith(".jsonl") && lstatSync(join(sessionDir, name)).isFile());
  if (sessionFiles.length !== 1) fail(`expected exactly one nested session JSONL in ${sessionDir}; found ${sessionFiles.length}`);
  const sessionFile = join(sessionDir, sessionFiles[0]);
  const binding = {
    jobId: flags["--job-id"],
    role: flags["--role"],
    sessionFile,
    terminalEntryId: terminalAssistantEntry(sessionFile),
    closed: true,
    argv,
    stdin: "ignore",
  };
  validateNestedLaunchEvidence(binding, binding.jobId);
  console.log(JSON.stringify(binding));
}

function createDelivery(args) {
  const flags = parseFlags(args, ["--review-root", "--attempt-id", "--request-payload", "--gh"]);
  for (const field of ["--review-root", "--attempt-id", "--request-payload", "--gh"]) {
    if (!flags[field]) fail(`create-delivery requires ${field}`);
  }
  if (!isAbsolute(flags["--gh"]) || !existsSync(flags["--gh"])) fail("create-delivery requires an existing absolute gh executable");
  const reviewRoot = resolve(flags["--review-root"]);
  if (!existsSync(reviewRoot) || !lstatSync(reviewRoot).isDirectory()) fail(`review root does not exist: ${reviewRoot}`);
  const requestPayloadPath = resolve(flags["--request-payload"]);
  const requestPayloadBytes = readFileSync(requestPayloadPath);
  const requestPayload = readJson(requestPayloadPath);
  if (!requestPayload || typeof requestPayload !== "object" || Array.isArray(requestPayload)
    || !Object.hasOwn(deliveryStates, requestPayload.event)) fail("create-delivery request payload has an invalid event");
  const fixture = readJson(join(dirname(reviewRoot), "fixture.json"));
  requireFixtureTopology(fixture, "delivery fixture identity");
  if (typeof fixture.repository !== "string" || !/^[^/]+\/[^/]+$/.test(fixture.repository)
    || !Number.isInteger(fixture.prNumber) || fixture.prNumber < 1) fail("invalid delivery fixture identity");
  const nativeArgs = ["api", "--method", "POST", `repos/${fixture.repository}/pulls/${fixture.prNumber}/reviews`, "--input", requestPayloadPath];
  const lockPath = join(reviewRoot, "delivery-create.lock");
  try {
    mkdirSync(lockPath);
  } catch (error) {
    fail(`delivery create already claimed or cannot be claimed: ${error.message}`);
  }
  const receiptPath = join(reviewRoot, "delivery-create.json");
  const indeterminate = {
    schemaVersion: 1,
    status: "INDETERMINATE",
    attemptId: flags["--attempt-id"],
    reviewId: null,
    event: requestPayload.event,
    postEquivalentAttempts: 1,
    requestPayloadSha256: sha256(requestPayloadBytes),
    argv: [flags["--gh"], ...nativeArgs],
  };
  try {
    writeFileSync(receiptPath, `${JSON.stringify(indeterminate, null, 2)}\n`, { flag: "wx" });
  } catch (error) {
    fail(`cannot persist indeterminate delivery receipt: ${error.message}`);
  }
  const result = spawnSync(flags["--gh"], nativeArgs, { encoding: "utf8", shell: false, stdin: "ignore" });
  if (result.error) fail(`native delivery create outcome is indeterminate: ${result.error.message}`);
  if (result.status !== 0 || result.signal) {
    fail(`native delivery create outcome is indeterminate after status ${result.status ?? "null"}${result.signal ? ` and signal ${result.signal}` : ""}`);
  }
  let response;
  try {
    response = JSON.parse(result.stdout.trim());
  } catch (error) {
    fail(`native delivery create outcome is indeterminate: invalid JSON response (${error.message})`);
  }
  const returnedId = response && !Array.isArray(response) ? response.id : null;
  if (!((typeof returnedId === "string" && returnedId) || (Number.isInteger(returnedId) && returnedId > 0))) {
    fail("native delivery create outcome is indeterminate: expected one returned review ID");
  }
  const receipt = {
    schemaVersion: 1,
    attemptId: flags["--attempt-id"],
    reviewId: String(returnedId),
    event: requestPayload.event,
    postEquivalentAttempts: 1,
  };
  const successPath = join(lockPath, "success.json");
  try {
    writeFileSync(successPath, `${JSON.stringify(receipt, null, 2)}\n`, { flag: "wx" });
    renameSync(successPath, receiptPath);
  } catch (error) {
    fail(`native delivery create succeeded but its first-create receipt is indeterminate: ${error.message}`);
  }
  console.log(JSON.stringify(receipt));
}

const reviewAngles = new Set([
  "bugs", "security", "conventions", "acceptance", "seo", "aeo", "design", "react",
  "database", "tests", "api", "infra", "observability", "types", "i18n", "docs",
  "deps", "architecture", "skills", "comments", "simplify", "production-readiness",
]);

function runGhJson(gh, argv, label) {
  const result = spawnSync(gh, argv, { encoding: "utf8", shell: false, stdin: "ignore" });
  if (result.error) fail(`${label} failed: ${result.error.message}`);
  if (result.status !== 0 || result.signal) {
    fail(`${label} exited with status ${result.status ?? "null"}${result.signal ? ` and signal ${result.signal}` : ""}`);
  }
  try {
    return JSON.parse(result.stdout.trim());
  } catch (error) {
    fail(`${label} returned invalid JSON: ${error.message}`);
  }
}

function renderFindingBody(finding, label) {
  if (!finding || typeof finding !== "object" || Array.isArray(finding)
    || typeof finding.title !== "string" || !finding.title.trim()
    || typeof finding.description !== "string" || !finding.description.trim()) fail(`${label} cannot be rendered`);
  const nit = finding.nit === true;
  let title = finding.title.trim();
  if (nit && !title.toLowerCase().startsWith("nit:")) title = `Nit: ${title}`;
  let body = `**${title}**\n\n${finding.description.trim()}`;
  const deferredTo = typeof finding.deferred_to === "string"
    ? finding.deferred_to.trim().replace(/[`_*\[\]<>\n\r]/g, "")
    : "";
  if (deferredTo) body += `\n\n_Deferred to ${deferredTo}; non-blocking._`;
  const fix = typeof finding.fix === "string" ? finding.fix.trim() : "";
  if (fix) body += `\n\nFix: ${fix}`;
  if (finding.fix_type === "suggestion" && typeof finding.suggestion === "string" && finding.suggestion) {
    const suggestion = finding.suggestion.split(/\r?\n/).map((line) => (
      /^\s*`{3,}/.test(line) ? line.replace(/`/g, "'") : line
    )).join("\n");
    body += `\n\n\`\`\`suggestion\n${suggestion}\n\`\`\``;
  }
  const footer = [];
  const severity = typeof finding.severity === "string" ? finding.severity.trim().toUpperCase() : "";
  if (["HIGH", "MEDIUM", "LOW"].includes(severity)) {
    footer.push(`<strong>${severity}${nit ? " · NIT" : finding.blocking === true ? " · BLOCKING" : ""}</strong>`);
  }
  const angle = typeof finding.angle === "string" ? finding.angle.trim() : "";
  if (reviewAngles.has(angle)) footer.push(`<code>${angle}</code>`);
  if (footer.length) body += `\n\n<sub>— ${footer.join(" · ")}</sub>`;
  return body;
}

function parseDiffPath(header) {
  let value = header.slice(4);
  if (value.startsWith("\"")) {
    try {
      value = JSON.parse(value);
    } catch {
      return null;
    }
  } else {
    value = value.split("\t", 1)[0];
  }
  if (value === "/dev/null") return null;
  return value.startsWith("b/") ? value.slice(2) : value;
}

function lineAtDiffPosition(diff, wantedPath, wantedPosition) {
  let path = null;
  let inHunks = false;
  let position = 0;
  let newLine = 0;
  for (const text of diff.split(/\r?\n/)) {
    if (text.startsWith("diff --git ")) {
      path = null;
      inHunks = false;
      position = 0;
      continue;
    }
    if (text.startsWith("+++ ")) {
      path = parseDiffPath(text);
      continue;
    }
    if (path !== wantedPath) continue;
    const hunk = text.match(/^@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@/);
    if (hunk) {
      if (inHunks) {
        position += 1;
        if (position === wantedPosition) return null;
      }
      newLine = Number(hunk[1]);
      inHunks = true;
      continue;
    }
    if (!inHunks) continue;
    position += 1;
    const resolved = text.startsWith("+") || text.startsWith(" ") ? newLine : null;
    if (position === wantedPosition) return resolved;
    if (text.startsWith("+") || text.startsWith(" ")) newLine += 1;
  }
  return null;
}

function validateChangedLine(resolver, diffPath, path, line, label) {
  const result = spawnSync(resolver, [
    "--file", path, "--line", String(line), "--diff", diffPath, "--no-cache",
  ], { encoding: "utf8", shell: false, stdin: "ignore" });
  if (result.error) fail(`${label} resolver failed: ${result.error.message}`);
  if (result.status !== 0 || result.signal || result.stdout.trim() !== String(line)) {
    fail(`${label} does not resolve to a changed RIGHT-side line`);
  }
  return line;
}

function resolveNativeAnchor(comment, diff, diffPath, resolver, label) {
  if (typeof comment.path !== "string" || !comment.path) fail(`${label} has no path`);
  const hasLineFields = comment.line !== null && comment.line !== undefined
    || comment.original_line !== null && comment.original_line !== undefined
    || comment.side !== null && comment.side !== undefined;
  if (hasLineFields) {
    if (!Number.isInteger(comment.line) || comment.line < 1 || comment.side !== "RIGHT") {
      fail(`${label} has invalid native line/side coordinates`);
    }
    const line = validateChangedLine(resolver, diffPath, comment.path, comment.line, label);
    if (comment.original_line !== null && comment.original_line !== undefined && comment.original_line !== line) {
      fail(`${label} has inconsistent original_line`);
    }
    return { path: comment.path, line };
  }
  const positions = [comment.position, comment.original_position]
    .filter((value) => value !== null && value !== undefined);
  if (!positions.length || positions.some((value) => !Number.isInteger(value) || value < 1)) {
    fail(`${label} has neither valid line/side nor position coordinates`);
  }
  const resolved = positions.map((position) => lineAtDiffPosition(diff, comment.path, position));
  if (resolved.some((line) => !Number.isInteger(line)) || new Set(resolved).size !== 1) {
    fail(`${label} position coordinates do not deterministically resolve`);
  }
  return {
    path: comment.path,
    line: validateChangedLine(resolver, diffPath, comment.path, resolved[0], label),
  };
}

function expectedDeliveryComments(findings, requestPayload, fixture) {
  if (!Array.isArray(findings) || !Array.isArray(requestPayload.comments)
    || findings.length !== requestPayload.comments.length) fail("delivery request/finalized finding count mismatch");
  const expected = findings.map((finding, index) => {
    const label = `finalized finding ${index + 1}`;
    const request = requestPayload.comments[index];
    if (!request || typeof request !== "object" || Array.isArray(request)
      || typeof finding.file !== "string" || !finding.file
      || !Number.isInteger(finding.line) || finding.line < 1
      || request.path !== finding.file
      || request.side !== "RIGHT"
      || !Number.isInteger(request.line) || request.line < 1
      || typeof request.body !== "string"
      || request.body !== renderFindingBody(finding, label)) fail(`${label} is not bound to its request comment`);
    const finalLine = finding.end_line === null || finding.end_line === undefined ? finding.line : finding.end_line;
    if (!Number.isInteger(finalLine) || finalLine < finding.line || request.line !== finalLine) {
      fail(`${label} has an invalid final changed-line anchor`);
    }
    if (finding.end_line !== null && finding.end_line !== undefined) {
      if (request.start_line !== finding.line || request.start_side !== "RIGHT") fail(`${label} has an invalid request range`);
    } else if (request.start_line !== undefined || request.start_side !== undefined) {
      fail(`${label} has an unexpected request range`);
    }
    return {
      findingSha256: sha256(canonical(finding)),
      path: request.path,
      line: request.line,
      body: request.body,
    };
  });
  const identities = expected.map(({ findingSha256, path, line, body }) => canonical({ findingSha256, path, line, body }));
  if (new Set(identities).size !== identities.length) fail("finalized findings do not have unique delivery identities");
  if (requestPayload.commit_id !== fixture.headSha) fail("delivery request commit does not match the fixture head");
  return expected;
}

function writeCreateNewAtomic(path, value) {
  if (existsSync(path)) fail(`create-new output already exists: ${path}`);
  const temporary = `${path}.tmp-${process.pid}`;
  try {
    writeFileSync(temporary, `${JSON.stringify(value, null, 2)}\n`, { flag: "wx" });
    linkSync(temporary, path);
    unlinkSync(temporary);
  } catch (error) {
    if (existsSync(temporary)) unlinkSync(temporary);
    fail(`cannot atomically create ${path}: ${error.message}`);
  }
}

function readDelivery(args) {
  const flags = parseFlags(args, ["--review-root", "--fixture", "--request-payload", "--gh", "--resolver"]);
  for (const field of ["--review-root", "--request-payload", "--gh", "--resolver"]) {
    if (!flags[field]) fail(`read-delivery requires ${field}`);
  }
  for (const field of ["--gh", "--resolver"]) {
    if (!isAbsolute(flags[field]) || !existsSync(flags[field]) || !statSync(flags[field]).isFile()) {
      fail(`read-delivery requires an existing absolute ${field.slice(2)} executable`);
    }
    flags[field] = realpathSync(flags[field]);
  }
  const reviewRoot = resolve(flags["--review-root"]);
  if (!existsSync(reviewRoot) || !lstatSync(reviewRoot).isDirectory()) fail(`review root does not exist: ${reviewRoot}`);
  const readbackPath = join(reviewRoot, "delivery-readback.json");
  if (existsSync(readbackPath)) fail(`create-new output already exists: ${readbackPath}`);
  const fixture = readJson(flags["--fixture"] ? resolve(flags["--fixture"]) : join(dirname(reviewRoot), "fixture.json"));
  requireFixtureTopology(fixture, "delivery fixture identity");
  if (typeof fixture.repository !== "string" || !/^[^/]+\/[^/]+$/.test(fixture.repository)
    || !Number.isInteger(fixture.prNumber) || fixture.prNumber < 1) fail("invalid delivery fixture identity");
  if (readJson(join(reviewRoot, "meta.json"))?.headRefOid !== fixture.headSha) {
    fail("review metadata does not match the fixture head");
  }
  const receipt = readJson(join(reviewRoot, "delivery-create.json"));
  assertExactKeys(receipt, ["schemaVersion", "attemptId", "reviewId", "event", "postEquivalentAttempts"], "delivery create receipt");
  if (receipt.schemaVersion !== 1
    || typeof receipt.attemptId !== "string" || !receipt.attemptId
    || typeof receipt.reviewId !== "string" || !/^[1-9]\d*$/.test(receipt.reviewId)
    || !Object.hasOwn(deliveryStates, receipt.event)
    || receipt.postEquivalentAttempts !== 1) fail("invalid delivery create receipt");
  const requestPayload = readJson(resolve(flags["--request-payload"]));
  if (!requestPayload || typeof requestPayload !== "object" || Array.isArray(requestPayload)
    || requestPayload.event !== receipt.event
    || typeof requestPayload.body !== "string") fail("invalid or mismatched delivery request payload");
  const expected = expectedDeliveryComments(readJson(join(reviewRoot, "findings.json")), requestPayload, fixture);
  const diffPath = join(reviewRoot, "diff.txt");
  if (!existsSync(diffPath) || !lstatSync(diffPath).isFile()) fail("reviewed diff is missing");
  const diff = readFileSync(diffPath, "utf8");
  const reviewEndpoint = `repos/${fixture.repository}/pulls/${fixture.prNumber}/reviews/${receipt.reviewId}`;
  const nativeReview = runGhJson(flags["--gh"], ["api", "--method", "GET", reviewEndpoint], "native review read-back");
  const actorId = nativeReview?.user?.id;
  if (!nativeReview || typeof nativeReview !== "object" || Array.isArray(nativeReview)
    || String(nativeReview.id) !== receipt.reviewId
    || nativeReview.commit_id !== fixture.headSha
    || nativeReview.state !== deliveryStates[receipt.event]
    || !((typeof actorId === "string" && actorId) || (Number.isInteger(actorId) && actorId > 0))
    || nativeReview.body !== requestPayload.body) fail("native review does not match the created delivery");
  const commentsEndpoint = `${reviewEndpoint}/comments?per_page=100`;
  const commentsResponse = runGhJson(
    flags["--gh"],
    ["api", "--method", "GET", "--paginate", "--slurp", commentsEndpoint],
    "native review-comment read-back",
  );
  let nativeComments = commentsResponse;
  if (Array.isArray(commentsResponse) && commentsResponse.every((page) => Array.isArray(page))) {
    nativeComments = commentsResponse.flat();
  }
  if (!Array.isArray(nativeComments) || nativeComments.length !== expected.length) {
    fail("native review-comment count does not match finalized findings");
  }
  const resolved = nativeComments.map((comment, index) => {
    const label = `native review comment ${index + 1}`;
    if (!comment || typeof comment !== "object" || Array.isArray(comment)
      || String(comment.pull_request_review_id) !== receipt.reviewId
      || comment.commit_id !== fixture.headSha
      || comment.original_commit_id !== fixture.headSha
      || String(comment.user?.id) !== String(actorId)
      || typeof comment.body !== "string"
      || !((typeof comment.id === "string" && comment.id) || (Number.isInteger(comment.id) && comment.id > 0))
      || typeof comment.html_url !== "string"
      || !comment.html_url.startsWith(`https://github.com/${fixture.repository}/pull/${fixture.prNumber}#discussion_r`)) {
      fail(`${label} does not match the exact review, head, actor, or fixture`);
    }
    return {
      ...resolveNativeAnchor(comment, diff, diffPath, flags["--resolver"], label),
      body: comment.body,
      commentId: String(comment.id),
      url: comment.html_url,
    };
  });
  const used = new Set();
  const deliveryComments = expected.map((finding) => {
    const matches = resolved.flatMap((comment, index) => (
      !used.has(index) && comment.path === finding.path && comment.line === finding.line && comment.body === finding.body
        ? [index]
        : []
    ));
    if (matches.length !== 1) fail("native comments do not uniquely match finalized finding anchors and bodies");
    const index = matches[0];
    used.add(index);
    return {
      findingSha256: finding.findingSha256,
      commentId: resolved[index].commentId,
      url: resolved[index].url,
    };
  });
  const readback = {
    schemaVersion: 1,
    repository: fixture.repository,
    prNumber: fixture.prNumber,
    headSha: fixture.headSha,
    reviewId: receipt.reviewId,
    event: receipt.event,
    state: nativeReview.state,
    actorId: String(actorId),
    comments: deliveryComments,
  };
  writeCreateNewAtomic(readbackPath, readback);
  console.log(JSON.stringify(readback));
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
  assertExactKeys(manifest, [
    "schemaVersion", "benchmark", "cohort", "runId", "caseIds", "corpusSha256",
    "skillRoot", "skillInventory", "skillSha256", "candidateContract", "judgeContract",
    "expectedFindings", "expectedReviewEvidence", "timingPath",
  ], "manifest");
  const activeCases = corpus.cases.filter((item) => item.rank === 1);
  const caseIds = activeCases.map((item) => item.id);
  const expectedFindings = caseIds.map((id) => `cases/${id}/findings.json`);
  const expectedReviewEvidence = caseIds.map((id) => `cases/${id}/review`);
  if (manifest.schemaVersion !== 2
    || manifest.benchmark !== corpus.name
    || manifest.cohort !== historicalCohort
    || manifest.runId !== basename(runRoot)
    || canonical(manifest.caseIds) !== canonical(caseIds)
    || canonical(manifest.expectedFindings) !== canonical(expectedFindings)
    || canonical(manifest.expectedReviewEvidence) !== canonical(expectedReviewEvidence)
    || manifest.timingPath !== "stage-timings.json") fail("unsupported or malformed run manifest");
  if (manifest.corpusSha256 !== sha256(canonical(corpus))) fail("run corpus no longer matches manifest");
  if (!Array.isArray(manifest.skillInventory) || manifest.skillSha256 !== sha256(canonical(manifest.skillInventory))) fail("run skill inventory no longer matches manifest");
  return { manifest, corpus, activeCases };
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
  const activeCases = corpus.cases.filter((item) => item.rank === 1);
  mkdirSync(runRoot, { recursive: false });
  mkdirSync(join(runRoot, "cases"));
  mkdirSync(join(runRoot, "judgments"));
  for (const item of activeCases) mkdirSync(join(runRoot, "cases", item.id));
  writeFileSync(join(runRoot, "corpus.json"), `${JSON.stringify(corpus, null, 2)}\n`);
  const skillInventory = inventory(skillRoot);
  const manifest = {
    schemaVersion: 2,
    benchmark: corpus.name,
    cohort: historicalCohort,
    runId: basename(runRoot),
    caseIds: activeCases.map((item) => item.id),
    corpusSha256: sha256(canonical(corpus)),
    skillRoot: resolve(skillRoot),
    skillInventory,
    skillSha256: sha256(canonical(skillInventory)),
    candidateContract: "accepted structured findings: <title>. <description>",
    judgeContract: "one isolated semantic-match decision per golden/candidate pair",
    expectedFindings: activeCases.map((item) => `cases/${item.id}/findings.json`),
    expectedReviewEvidence: activeCases.map((item) => `cases/${item.id}/review`),
    timingPath: "stage-timings.json",
  };
  writeFileSync(join(runRoot, "manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`, { flag: "wx" });
  console.log(resolve(runRoot));
}

function validateFinding(finding, label) {
  if (!finding || typeof finding !== "object" || Array.isArray(finding)) fail(`${label} is not an object`);
  for (const field of ["title", "description"]) if (typeof finding[field] !== "string" || !finding[field].trim()) fail(`${label} missing ${field}`);
}

function createPlan(runRoot) {
  const { corpus, activeCases } = requireRun(runRoot);
  const cases = [];
  const pairs = [];
  for (const item of activeCases) {
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
function parseInstant(value, label) {
  const instant = typeof value === "string" ? Date.parse(value) : Number.NaN;
  if (!Number.isFinite(instant)) fail(`invalid ${label}`);
  return instant;
}

function collectTimings(runRoot, manifest) {
  const timing = readJson(join(runRoot, manifest.timingPath));
  assertExactKeys(timing, ["schemaVersion", "sessions", "startedAt", "completedAt", "stages"], "stage timings");
  if (timing.schemaVersion !== 2 || !Array.isArray(timing.sessions) || !Array.isArray(timing.stages)) fail("invalid stage timings");
  const sessions = timing.sessions.map((binding) => {
    const nested = binding?.role !== "controller";
    assertExactKeys(binding, nested
      ? ["jobId", "role", "sessionFile", "terminalEntryId", "closed", "argv", "stdin"]
      : ["jobId", "role", "sessionFile", "terminalEntryId", "closed"], "session binding");
    if (typeof binding.jobId !== "string" || !binding.jobId
      || !["controller", "candidate", "adjudicator", "judge"].includes(binding.role)
      || typeof binding.sessionFile !== "string" || !binding.sessionFile
      || typeof binding.terminalEntryId !== "string" || !binding.terminalEntryId
      || binding.closed !== true) fail("invalid session binding");
    if (nested) validateNestedLaunchEvidence(binding, binding.jobId);
    return binding;
  });
  if (new Set(sessions.map(({ jobId }) => jobId)).size !== sessions.length
    || new Set(sessions.map(({ sessionFile }) => sessionFile)).size !== sessions.length) fail("duplicate session binding");
  const startedAt = parseInstant(timing.startedAt, "run start");
  const completedAt = parseInstant(timing.completedAt, "run completion");
  if (completedAt < startedAt) fail("run completion precedes start");
  const expected = new Set(manifest.caseIds.flatMap((caseId) => [
    `${caseId}/candidate-generation`,
    `${caseId}/adjudication`,
  ]).concat("benchmark/semantic-judging"));
  const seen = new Set();
  const durationsMs = { candidateGeneration: 0, adjudication: 0, semanticJudging: 0 };
  const caseStages = new Map();
  for (const stage of timing.stages) {
    assertExactKeys(stage, ["caseId", "name", "startedAt", "completedAt"], "stage timing");
    const key = `${stage.caseId ?? "benchmark"}/${stage.name}`;
    if (!expected.has(key) || seen.has(key)) fail(`unexpected or duplicate stage timing ${key}`);
    const start = parseInstant(stage.startedAt, `${key} start`);
    const end = parseInstant(stage.completedAt, `${key} completion`);
    if (start < startedAt || end < start || end > completedAt) fail(`invalid interval for ${key}`);
    seen.add(key);
    caseStages.set(key, { start, end });
    const duration = end - start;
    if (stage.name === "candidate-generation") durationsMs.candidateGeneration += duration;
    else if (stage.name === "adjudication") durationsMs.adjudication += duration;
    else durationsMs.semanticJudging += duration;
  }
  if (seen.size !== expected.size) fail(`missing stage timings: ${[...expected].filter((key) => !seen.has(key)).join(",")}`);
  for (const caseId of manifest.caseIds) {
    if (caseStages.get(`${caseId}/candidate-generation`).end > caseStages.get(`${caseId}/adjudication`).start) fail(`adjudication overlaps candidate generation for ${caseId}`);
  }
  const judging = caseStages.get("benchmark/semantic-judging");
  if (Math.max(...manifest.caseIds.map((caseId) => caseStages.get(`${caseId}/adjudication`).end)) > judging.start) fail("semantic judging starts before adjudication completes");
  return { sessions, startedAt: timing.startedAt, stageCompletedAt: timing.completedAt, durationsMs };
}

function requireArray(path, label) {
  const value = readJson(path);
  if (!Array.isArray(value)) fail(`${label} must be an array`);
  return value;
}

function requireReceipt(path, angle, chunk = "") {
  const receipt = readJson(path);
  if (!receipt || typeof receipt !== "object" || Array.isArray(receipt)
    || receipt.angle !== angle
    || (receipt.chunk ?? "") !== chunk
    || ["runner", "model", "tier"].some((field) => typeof receipt[field] !== "string" || !receipt[field].trim())
    || receipt.authority !== "advisory-only") fail(`invalid receipt ${path}`);
  return receipt;
}

function requireAdjudicatorBinding(reviewRoot, receipt) {
  const binding = readJson(join(reviewRoot, "validator-bindings.json"));
  assertExactKeys(binding, ["schemaVersion", "adjudicator"], "validator bindings");
  if (binding.schemaVersion !== 2 || !binding.adjudicator || typeof binding.adjudicator !== "object" || Array.isArray(binding.adjudicator)) fail("invalid validator bindings");
  const expected = binding.adjudicator;
  const identityFields = ["runner", "model", "tier", "reviewerProfile", "reviewerSessionId", "reviewerPrincipalId", "reviewerCredentialContextId"];
  if (identityFields.some((field) => typeof expected[field] !== "string" || !expected[field] || receipt[field] !== expected[field])) fail("adjudicator receipt does not match validator binding");
  if (expected.findingsSha256 !== sha256(readFileSync(join(reviewRoot, "findings.adjudicator.json")))
    || expected.receiptSha256 !== sha256(readFileSync(join(reviewRoot, "receipt.adjudicator.json")))) fail("adjudicator artifact digest mismatch");
}

function requireDeliveryReadback(caseRoot, reviewRoot, finalized) {
  const fixture = readJson(join(caseRoot, "fixture.json"));
  requireFixtureTopology(fixture, "fixture identity");
  if (typeof fixture.repository !== "string" || !/^[^/]+\/[^/]+$/.test(fixture.repository)
    || !Number.isInteger(fixture.prNumber) || fixture.prNumber < 1) fail("invalid fixture identity");
  const meta = readJson(join(reviewRoot, "meta.json"));
  if (meta.headRefOid !== fixture.headSha) fail("fixture identity does not match reviewed PR head");
  const createReceipt = readJson(join(reviewRoot, "delivery-create.json"));
  assertExactKeys(createReceipt, ["schemaVersion", "attemptId", "reviewId", "event", "postEquivalentAttempts"], "delivery create receipt");
  if (createReceipt.schemaVersion !== 1
    || typeof createReceipt.attemptId !== "string" || !createReceipt.attemptId
    || typeof createReceipt.reviewId !== "string" || !createReceipt.reviewId
    || !Object.hasOwn(deliveryStates, createReceipt.event)
    || createReceipt.postEquivalentAttempts !== 1) fail("invalid delivery create receipt");
  const delivery = readJson(join(reviewRoot, "delivery-readback.json"));
  assertExactKeys(delivery, ["schemaVersion", "repository", "prNumber", "headSha", "reviewId", "event", "state", "actorId", "comments"], "delivery read-back");
  if (delivery.schemaVersion !== 1
    || delivery.repository !== fixture.repository
    || delivery.prNumber !== fixture.prNumber
    || delivery.headSha !== fixture.headSha
    || delivery.reviewId !== createReceipt.reviewId
    || delivery.event !== createReceipt.event
    || !Object.hasOwn(deliveryStates, delivery.event)
    || delivery.state !== deliveryStates[delivery.event]
    || typeof delivery.actorId !== "string" || !delivery.actorId
    || !Array.isArray(delivery.comments)) fail("invalid delivery read-back state");
  if (delivery.comments.length !== finalized.length) fail("delivery read-back finding count mismatch");
  const expected = finalized.map((finding) => sha256(canonical(finding))).sort();
  const observed = delivery.comments.map((comment) => {
    assertExactKeys(comment, ["findingSha256", "commentId", "url"], "delivery comment");
    if (typeof comment.findingSha256 !== "string"
      || typeof comment.commentId !== "string" || !comment.commentId
      || typeof comment.url !== "string" || !comment.url) fail("invalid delivery comment");
    return comment.findingSha256;
  }).sort();
  if (canonical(observed) !== canonical(expected)
    || new Set(delivery.comments.map(({ commentId }) => commentId)).size !== delivery.comments.length) fail("delivery read-back does not bind accepted findings");
  return createReceipt;
}

function requireJudgeBinding(runRoot, pair, decisionPath, contract) {
  const receiptPath = decisionPath.replace(/\.json$/, ".receipt.json");
  const receipt = readJson(receiptPath);
  assertExactKeys(receipt, ["schemaVersion", "pairId", "promptSha256", "decisionSha256", "sessionFile", "terminalEntryId", "provider", "model", "agentType", "tier", "effort"], `judge receipt ${pair.id}`);
  if (receipt.schemaVersion !== 1
    || receipt.pairId !== pair.id
    || receipt.promptSha256 !== sha256(pair.prompt)
    || receipt.decisionSha256 !== sha256(readFileSync(decisionPath))
    || typeof receipt.sessionFile !== "string" || !receipt.sessionFile
    || typeof receipt.terminalEntryId !== "string" || !receipt.terminalEntryId
    || ["provider", "model", "agentType", "tier", "effort"].some((field) => receipt[field] !== contract[field])) fail(`invalid judge receipt ${pair.id}`);
  return receipt;
}

function collectReviewAccounting(runRoot, activeCases) {
  const jobs = {
    candidateGeneration: { planned: 0, attempts: 0, retries: 0, completed: 0 },
    adjudication: { planned: activeCases.length, attempts: activeCases.length, completed: 0 },
  };
  const expectedSessionJobs = [{ jobId: "benchmark/controller", role: "controller" }];
  const rejectionReasons = {
    candidateFirstPassInvalid: 0,
    candidateInvalidAfterRetry: 0,
    candidateMissingReceipt: 0,
    adjudicatorRejected: 0,
    deterministicFinalizerRejected: 0,
  };
  const deliveryCreateReceipts = [];
  for (const item of activeCases) {
    const reviewRoot = join(runRoot, "cases", item.id, "review");
    const swarm = readJson(join(reviewRoot, "swarm-metrics.json"));
    for (const field of ["work_items_total", "expected_total"]) {
      if (!Number.isInteger(swarm[field]) || swarm[field] < 1) fail(`invalid ${field} for ${item.id}`);
    }
    for (const field of ["first_pass_failed", "retry_angles", "still_invalid", "executed_angles", "missing_receipts"]) {
      if (!Array.isArray(swarm[field]) || swarm[field].some((value) => typeof value !== "string" || !value)) fail(`invalid ${field} for ${item.id}`);
    }
    if (swarm.schema_version !== 1
      || swarm.degraded !== false
      || swarm.work_items_total !== swarm.expected_total
      || new Set(swarm.executed_angles).size !== swarm.expected_total
      || canonical([...swarm.first_pass_failed].sort()) !== canonical([...swarm.retry_angles].sort())
      || swarm.still_invalid.length
      || swarm.missing_receipts.length) fail(`incomplete candidate-generation accounting for ${item.id}`);
    jobs.candidateGeneration.planned += swarm.expected_total;
    jobs.candidateGeneration.attempts += swarm.work_items_total + swarm.retry_angles.length;
    jobs.candidateGeneration.retries += swarm.retry_angles.length;
    jobs.candidateGeneration.completed += swarm.executed_angles.length;
    rejectionReasons.candidateFirstPassInvalid += swarm.first_pass_failed.length;
    rejectionReasons.candidateInvalidAfterRetry += swarm.still_invalid.length;
    rejectionReasons.candidateMissingReceipt += swarm.missing_receipts.length;

    const raw = requireArray(join(reviewRoot, "raw_findings.json"), `${item.id} raw findings`);
    const adjudicated = requireArray(join(reviewRoot, "findings.adjudicator.json"), `${item.id} adjudicated findings`);
    const finalized = requireArray(join(reviewRoot, "findings.json"), `${item.id} finalized findings`);
    const accepted = requireArray(join(runRoot, "cases", item.id, "findings.json"), `${item.id} accepted findings`);
    const rawCounts = new Map();
    for (const finding of raw) {
      const key = findingIdentity(finding);
      rawCounts.set(key, (rawCounts.get(key) ?? 0) + 1);
    }
    for (const finding of adjudicated) {
      const key = findingIdentity(finding);
      if (!rawCounts.get(key)) fail(`adjudicator rewrote or invented a finding identity for ${item.id}`);
      rawCounts.set(key, rawCounts.get(key) - 1);
    }
    if (finalized.length > adjudicated.length || canonical(finalized) !== canonical(accepted)) fail(`inconsistent adjudication artifacts for ${item.id}`);
    const adjudicatorReceipt = requireReceipt(join(reviewRoot, "receipt.adjudicator.json"), "adjudicator");
    requireAdjudicatorBinding(reviewRoot, adjudicatorReceipt);
    deliveryCreateReceipts.push(requireDeliveryReadback(join(runRoot, "cases", item.id), reviewRoot, finalized));
    expectedSessionJobs.push({ jobId: `${item.id}/adjudicator`, role: "adjudicator" });
    for (const label of swarm.executed_angles) {
      const [angle, ...chunkParts] = label.split(".");
      requireReceipt(join(reviewRoot, `receipt.${label}.json`), angle, chunkParts.join("."));
      expectedSessionJobs.push({ jobId: `${item.id}/${label}/attempt-1`, role: "candidate" });
      if (swarm.retry_angles.includes(label)) expectedSessionJobs.push({ jobId: `${item.id}/${label}/attempt-2`, role: "candidate" });
    }
    const validator = readJson(join(reviewRoot, "validator-metrics.json"));
    if (validator.mode !== "adjudicator" || validator.degraded !== false || validator.adjudicator_count !== finalized.length || validator.kept_count !== finalized.length) fail(`invalid adjudication accounting for ${item.id}`);
    jobs.adjudication.completed += 1;
    rejectionReasons.adjudicatorRejected += raw.length - adjudicated.length;
    rejectionReasons.deterministicFinalizerRejected += adjudicated.length - finalized.length;
  }
  if (new Set(deliveryCreateReceipts.map(({ attemptId }) => attemptId)).size !== deliveryCreateReceipts.length
    || new Set(deliveryCreateReceipts.map(({ reviewId }) => reviewId)).size !== deliveryCreateReceipts.length) {
    fail("duplicate delivery create attempt or review ID");
  }
  return { jobs, rejectionReasons, expectedSessionJobs };
}
function readBoundSessionUsage(sessionBindings, judgeReceipts) {
  const judgeAgentTypes = new Map(judgeReceipts.map((receipt) => [receipt.sessionFile, receipt.agentType]));
  return sessionBindings.flatMap((binding) => {
    let entries;
    try {
      entries = readFileSync(binding.sessionFile, "utf8")
        .split(/\r?\n/)
        .filter(Boolean)
        .map((line) => JSON.parse(line));
    } catch (error) {
      fail(`cannot read exact bound session usage ${binding.sessionFile}: ${error.message}`);
    }
    return entries.flatMap((entry) => {
      const message = entry?.type === "message" && entry.message?.role === "assistant" ? entry.message : null;
      const usage = message?.usage;
      if (!usage || Array.isArray(usage)) return [];
      return [{
        session_file: binding.sessionFile,
        entry_id: entry.id,
        model: message.model,
        provider: message.provider,
        agent_type: judgeAgentTypes.get(binding.sessionFile) ?? "main",
        input_tokens: usage.input,
        output_tokens: usage.output,
        cache_read_tokens: usage.cacheRead,
        cache_write_tokens: usage.cacheWrite,
        cost_total: usage.cost?.total,
        error_message: message.stopReason === "error" ? "model request failed" : null,
      }];
    });
  });
}

function collectUsage(usageDb, sessionBindings, expectedSessionJobs, judgeReceipts) {
  if (!existsSync(usageDb)) fail(`missing OMP usage database ${usageDb}`);
  const expected = [...expectedSessionJobs].sort((left, right) => left.jobId.localeCompare(right.jobId));
  const observed = sessionBindings.map(({ jobId, role }) => ({ jobId, role })).sort((left, right) => left.jobId.localeCompare(right.jobId));
  if (canonical(observed) !== canonical(expected)) fail("session bindings do not match the complete planned job set");
  for (const receipt of judgeReceipts) {
    const binding = sessionBindings.find(({ jobId }) => jobId === `judge/${receipt.pairId}`);
    if (!binding || binding.sessionFile !== receipt.sessionFile || binding.terminalEntryId !== receipt.terminalEntryId) fail(`judge receipt session mismatch for ${receipt.pairId}`);
  }
  const sessionFiles = sessionBindings.map(({ sessionFile }) => sessionFile);
  const literals = sessionFiles.map((value) => `'${value.replaceAll("'", "''")}'`).join(",");
  const query = `SELECT session_file,entry_id,model,provider,agent_type,input_tokens,output_tokens,cache_read_tokens,cache_write_tokens,cost_total,error_message FROM messages WHERE session_file IN (${literals}) ORDER BY session_file,id`;
  const sqlite = spawnSync("sqlite3", ["-json", usageDb, query], { encoding: "utf8" });
  if (sqlite.status !== 0) fail(`cannot query OMP usage database: ${sqlite.stderr.trim() || "sqlite3 failed"}`);
  let rows;
  try {
    rows = JSON.parse(sqlite.stdout || "[]");
  } catch (error) {
    fail(`malformed OMP usage output: ${error.message}`);
  }
  if (!Array.isArray(rows)) fail("malformed OMP usage output");
  if (rows.length === 0) rows = readBoundSessionUsage(sessionBindings, judgeReceipts);
  const rowsBySession = new Map(sessionFiles.map((sessionFile) => [sessionFile, []]));
  for (const row of rows) rowsBySession.get(row.session_file)?.push(row);
  if (sessionBindings.some(({ sessionFile, terminalEntryId }) => !rowsBySession.get(sessionFile)?.some(({ entry_id: entryId }) => entryId === terminalEntryId))) fail("missing OMP usage for one or more exact bound session terminals");
  for (const receipt of judgeReceipts) {
    const terminal = rowsBySession.get(receipt.sessionFile)?.find(({ entry_id: entryId }) => entryId === receipt.terminalEntryId);
    if (!terminal || terminal.provider !== receipt.provider || terminal.model !== receipt.model || terminal.agent_type !== receipt.agentType) fail(`judge usage identity mismatch for ${receipt.pairId}`);
  }
  const boundSessions = new Set(sessionFiles);
  const totals = { modelRequests: 0, inputTokens: 0, outputTokens: 0, cacheReadTokens: 0, cacheWriteTokens: 0, cost: 0, errorRequests: 0 };
  const models = new Map();
  for (const row of rows) {
    if (!boundSessions.has(row.session_file) || typeof row.entry_id !== "string" || !row.entry_id
      || ["model", "provider", "agent_type"].some((field) => typeof row[field] !== "string" || !row[field])) fail("malformed OMP usage identity");
    for (const field of ["input_tokens", "output_tokens", "cache_read_tokens", "cache_write_tokens"]) {
      if (!Number.isInteger(row[field]) || row[field] < 0) fail(`malformed OMP usage ${field}`);
    }
    if (typeof row.cost_total !== "number" || !Number.isFinite(row.cost_total) || row.cost_total < 0) fail("malformed OMP usage cost_total");
    totals.modelRequests += 1;
    totals.inputTokens += row.input_tokens;
    totals.outputTokens += row.output_tokens;
    totals.cacheReadTokens += row.cache_read_tokens;
    totals.cacheWriteTokens += row.cache_write_tokens;
    totals.cost += row.cost_total;
    if (row.error_message !== null) totals.errorRequests += 1;
    const key = `${row.provider}\0${row.model}\0${row.agent_type}`;
    const model = models.get(key) ?? { provider: row.provider, model: row.model, agentType: row.agent_type, requests: 0, inputTokens: 0, outputTokens: 0, cacheReadTokens: 0, cacheWriteTokens: 0, cost: 0 };
    model.requests += 1;
    model.inputTokens += row.input_tokens;
    model.outputTokens += row.output_tokens;
    model.cacheReadTokens += row.cache_read_tokens;
    model.cacheWriteTokens += row.cache_write_tokens;
    model.cost += row.cost_total;
    models.set(key, model);
  }
  totals.cost = Number(totals.cost.toFixed(9));
  const breakdown = [...models.values()].sort((left, right) => canonical(left).localeCompare(canonical(right))).map((model) => ({ ...model, cost: Number(model.cost.toFixed(9)) }));
  return { sessions: sessionBindings, ...totals, models: breakdown };
}

function compareThresholds(result, wallTimeMs, cost) {
  const checks = {
    falsePositives: { observed: result.fp, operator: "<", threshold: thresholds.falsePositivesBelow, passed: result.fp < thresholds.falsePositivesBelow },
    precision: { observed: result.precision, operator: ">", threshold: thresholds.precisionAbove, passed: result.precision > thresholds.precisionAbove },
    truePositives: { observed: result.tp, operator: ">=", threshold: thresholds.truePositivesAtLeast, passed: result.tp >= thresholds.truePositivesAtLeast },
    recall: { observed: result.recall, operator: ">=", threshold: thresholds.recallAtLeast, passed: result.recall >= thresholds.recallAtLeast },
    f2: { observed: result.f2, operator: ">=", threshold: thresholds.f2AtLeast, passed: result.f2 >= thresholds.f2AtLeast },
    wallTimeMs: { observed: wallTimeMs, operator: "<", threshold: thresholds.wallTimeMsBelow, passed: wallTimeMs < thresholds.wallTimeMsBelow },
    cost: { observed: cost, operator: "<", threshold: thresholds.costBelow, passed: cost < thresholds.costBelow },
  };
  return {
    baseline: { cohort: historicalCohort, tp: 4, fp: 8, fn: 8, precision: 1 / 3, recall: 1 / 3, f1: 1 / 3, f2: 1 / 3, wallTimeMs: 2_314_670, cost: 159.040697 },
    directional: true,
    releaseVariance: false,
    checks,
    passed: Object.values(checks).every((check) => check.passed),
  };
}

function score(runRoot, usageDb) {
  const { manifest, corpus, activeCases } = requireRun(runRoot);
  const plan = readJson(join(runRoot, "judge-plan.json"));
  assertExactKeys(plan, ["schemaVersion", "corpusSha256", "cases", "pairs"], "judge plan");
  if (plan.schemaVersion !== 1
    || plan.corpusSha256 !== sha256(canonical(corpus))
    || canonical(plan.cases.map((item) => item.id)) !== canonical(manifest.caseIds)
    || !Array.isArray(plan.pairs)) fail("judge plan does not match run manifest");
  const judgeContract = readJson(join(runRoot, "judge-contract.json"));
  assertExactKeys(judgeContract, ["schemaVersion", "provider", "model", "agentType", "tier", "effort"], "judge contract");
  if (judgeContract.schemaVersion !== 1
    || ["provider", "model", "agentType", "tier", "effort"].some((field) => typeof judgeContract[field] !== "string" || !judgeContract[field])) fail("invalid judge contract");
  const decisions = new Map();
  const judgeReceipts = [];
  for (const pair of plan.pairs) {
    const path = join(runRoot, pair.decisionPath);
    if (!existsSync(path)) fail(`missing judgment ${path}`);
    const decision = readJson(path);
    assertExactKeys(decision, ["reasoning", "match", "confidence"], `judgment ${pair.id}`);
    if (typeof decision.reasoning !== "string" || !decision.reasoning.trim() || typeof decision.match !== "boolean" || typeof decision.confidence !== "number" || !Number.isFinite(decision.confidence) || decision.confidence < 0 || decision.confidence > 1) fail(`invalid judgment ${pair.id}`);
    decisions.set(pair.id, decision);
    judgeReceipts.push(requireJudgeBinding(runRoot, pair, path, judgeContract));
  }
  const timing = collectTimings(runRoot, manifest);
  const { expectedSessionJobs, ...review } = collectReviewAccounting(runRoot, activeCases);
  expectedSessionJobs.push(...plan.pairs.map(({ id }) => ({ jobId: `judge/${id}`, role: "judge" })));
  const usage = collectUsage(usageDb, timing.sessions, expectedSessionJobs, judgeReceipts);
  let tp = 0;
  let fn = 0;
  let fp = 0;
  let excludedMatched = 0;
  const caseResults = [];
  for (const item of activeCases) {
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
  const scoringCompletedAtMs = Date.now();
  if (scoringCompletedAtMs < Date.parse(timing.stageCompletedAt)) fail("scoring completion precedes stage completion");
  const resultTiming = {
    ...timing,
    completedAt: new Date(scoringCompletedAtMs).toISOString(),
    durationsMs: { ...timing.durationsMs, wall: scoringCompletedAtMs - Date.parse(timing.startedAt) },
  };
  const precision = tp + fp ? tp / (tp + fp) : 0;
  const recall = tp + fn ? tp / (tp + fn) : 0;
  const result = {
    schemaVersion: 2,
    benchmark: corpus.name,
    cohort: manifest.cohort,
    runId: manifest.runId,
    profile: "core",
    complete: true,
    tp,
    fp,
    fn,
    excludedMatched,
    precision,
    recall,
    f1: fbeta(precision, recall, 1),
    f2: fbeta(precision, recall, 2),
    accounting: { complete: true, ...review, timing: resultTiming, usage },
    cases: caseResults,
  };
  result.comparison = compareThresholds(result, resultTiming.durationsMs.wall, usage.cost);
  const resultBytes = `${JSON.stringify(result, null, 2)}\n`;
  writeFileSync(join(runRoot, "result.json"), resultBytes, { flag: "wx" });
  const fixtures = activeCases.map((item) => {
    const fixture = readJson(join(runRoot, "cases", item.id, "fixture.json"));
    const delivery = readJson(join(runRoot, "cases", item.id, "review", "delivery-readback.json"));
    return { caseId: item.id, pullRequestUrl: `https://github.com/${fixture.repository}/pull/${fixture.prNumber}`, reviewId: delivery.reviewId };
  });
  console.log(JSON.stringify({
    runRoot,
    fixtures,
    jobs: review.jobs,
    durationsMs: resultTiming.durationsMs,
    usage,
    rejectionReasons: review.rejectionReasons,
    tp,
    fp,
    fn,
    precision,
    recall,
    f1: result.f1,
    f2: result.f2,
    comparisonPassed: result.comparison.passed,
    resultSha256: sha256(resultBytes),
  }));
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
} else if (command === "launch-nested") {
  launchNested(args);
} else if (command === "create-delivery") {
  createDelivery(args);
} else if (command === "read-delivery") {
  readDelivery(args);
} else if (command === "score") {
  const flags = parseFlags(args, ["--run-root", "--usage-db"]);
  if (!flags["--run-root"] || !flags["--usage-db"]) fail("score requires --run-root and --usage-db");
  score(resolve(flags["--run-root"]), resolve(flags["--usage-db"]));
} else {
  fail(`usage: ${basename(process.argv[1])} verify-corpus [--benchmark-root PATH] | init --run-root PATH --skill-root PATH | plan --run-root PATH | launch-nested --role ROLE --job-id ID --session-dir PATH --executable PATH -- OMP_ARGS... | create-delivery --review-root PATH --attempt-id ID --request-payload PATH --gh PATH | read-delivery --review-root PATH [--fixture PATH] --request-payload PATH --gh PATH --resolver PATH | score --run-root PATH --usage-db PATH`);
}
