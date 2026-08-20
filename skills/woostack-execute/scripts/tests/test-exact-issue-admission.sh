#!/usr/bin/env bash
# Structural contract: exact resources, plain local artifacts, sequential open-PR delivery.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
if [ -e "$ROOT/skills/woostack-execute/references/inline-driver.md" ]; then
    echo "removed inline driver still exists" >&2
    exit 1
fi

python3 - "$ROOT" <<'PY'
import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
skill = re.sub(r"\s+", " ", (root / "skills/woostack-execute/SKILL.md").read_text(encoding="utf-8"))
controller = re.sub(r"\s+", " ", (root / "skills/woostack-execute/references/controller.md").read_text(encoding="utf-8"))
artifact = re.sub(r"\s+", " ", (root / "skills/woostack-init/references/artifact-backends.md").read_text(encoding="utf-8"))
worktrees = re.sub(r"\s+", " ", (root / "skills/woostack-init/references/worktrees.md").read_text(encoding="utf-8"))
driver = re.sub(r"\s+", " ", (root / "skills/woostack-execute/references/subagent-driver.md").read_text(encoding="utf-8"))
repo_rules = re.sub(r"\s+", " ", (root / "AGENTS.md").read_text(encoding="utf-8"))

checks = [
    (skill, r"`--project`, `--issue`, and `--run` are mutually exclusive; exactly one is required", "exact resource admission missing"),
    (skill, r"lowest-ordinal unfinished (?:task or issue|issue|task)", "lowest unfinished selection missing"),
    (skill, r"stop marker", "stop-marker behavior missing"),
    (skill, r"issue mode.*never advances siblings", "issue mode may advance siblings"),
    (skill, r"configured fast-model subagent", "fast-model dispatch missing"),
    (skill, r"one focused verification.*one small bounded spec-compliance validator", "narrow verification boundary missing"),
    (skill, r"branch, commit, PR URL/head/base.*verification", "delivery evidence missing"),
    (skill, r"clean exact worktree", "clean-worktree gate missing"),
    (skill, r"never create a duplicate", "duplicate resume protection missing"),
    (controller, r"Execute accepts exactly one of `--project`, `--issue`, or `--run`", "controller exact resource admission missing"),
    (controller, r"select lowest unfinished ordinal", "controller deterministic selection missing"),
    (controller, r"immediate predecessor's complete delivery checkpoint", "predecessor checkpoint proof missing"),
    (controller, r"one worktree", "controller worktree ownership missing"),
    (controller, r"fast-model subagent", "controller fast dispatch missing"),
    (controller, r"bounded spec-compliance validator", "controller validator missing"),
    (controller, r"Successful submission requires branch, commit, PR", "controller PR gate missing"),
    (controller, r"fresh independent evidence", "resume evidence missing"),
    (driver, r"configured fast-model subagent", "driver fast model missing"),
    (skill, r"active Execute project-start synchronization", "project-status contract link missing"),
    (skill, r"both `--project` and `--issue` modes", "both Execute provider modes missing"),
    (skill, r"issueStates\.executing.*issueStates\.inReview.*native category.*started", "configured issue-state resolution missing"),
    (skill, r"persisted checkpoint.*teardown.*resume.*sibling", "checkpoint-gated delivery missing"),
    (controller, r"full delivery checkpoint.*teardown.*resume.*sibling", "controller checkpoint gate missing"),
    (artifact, r"Write `project-spec\.md` exactly once", "plain specification write contract missing"),
    (artifact, r"Write `execution-plan\.md` exactly once", "plain plan write contract missing"),
    (artifact, r"taskExecutions\[stableTaskKey\].*`active`.*before worktree or source mutation.*`blocked`.*safe resume action.*`delivered`.*complete", "task checkpoint contract missing"),
    (artifact, r"If the current tip equals the planning tip, continue without a question", "unchanged base contract missing"),
    (artifact, r"If the same branch has a different tip, make zero mutations", "changed base pre-choice boundary missing"),
    (artifact, r"`Continue`.*`Revise spec/plan`.*`Stop`", "base-change choices missing"),
    (artifact, r"This is never automatic", "automatic base admission remains possible"),
    (artifact, r"checks.*for observation only", "observation-only checks contract missing"),
    (artifact, r"exact existing started status is an idempotent no-op", "project status idempotency missing"),
    (artifact, r"completed or canceled project.*terminal conflict.*blocks", "terminal project conflict missing"),
    (artifact, r"update only the native status field", "one-field project mutation missing"),
    (repo_rules, r"Merge authority is human-only.*never mark a PR ready.*auto-merge.*enqueue.*merge", "human-only merge boundary missing"),
    (skill, r"stop at that verified open-PR boundary.*No user wording overrides", "Execute terminal no-merge boundary missing"),
    (controller, r"terminal repository mutation is Graphite PR submission or update.*never marks a PR ready.*auto-merge.*merge queue.*merges", "controller terminal no-merge boundary missing"),
]
for text, pattern, message in checks:
    if not re.search(pattern, text, re.I | re.S):
        raise SystemExit(f"{message}: {pattern}")

if "inline-driver.md" in (skill + controller + driver).lower():
    raise SystemExit("removed inline driver is still referenced")
if re.search(r"(direct issue|issue lifecycle|issue status).{0,100}`In (Progress|Review)`", skill + controller, re.I | re.S):
    raise SystemExit("literal issue status name remains lifecycle authority")
if re.search(r"reviews/checks/threads", worktrees + artifact + controller, re.I):
    raise SystemExit("combined mandatory reviews/checks/threads contract remains")

# These identifiers may appear here as negative assertions, but not in current source.
for obsolete in (
    r"canonicalProjectSpecFingerprint",
    r"canonicalIncrementFingerprint",
    r"projectSpecApprovalRecord",
    r"executionPlanApprovalRecord",
    r"fingerprintVersion",
    r"providerPresentationCanonicalization",
    r"compatible[- ]advancement|compatible parent advancement",
    r"reaccept|re-accept",
):
    if re.search(obsolete, skill + controller + artifact, re.I):
        raise SystemExit(f"obsolete content-identity contract remains: {obsolete}")

evals = json.loads((root / "skills/woostack-execute/evals/evals.json").read_text(encoding="utf-8"))
cases = {case["id"]: case for case in evals["cases"]}
required_cases = {
    "project-selects-lowest-unfinished",
    "project-stop-marker-pauses",
    "issue-mode-never-advances",
    "delivery-same-state-is-idempotent",
    "delivery-distinct-state-transitions-once",
    "resume-reuses-existing-pr",
    "missing-delivery-checkpoint-blocks-resume",
    "failure-retains-worktree",
    "in-review-mapping-missing-blocks",
    "in-review-mapping-ambiguous-blocks",
    "in-review-mapping-foreign-blocks",
    "in-review-mapping-non-started-blocks",
    "executing-mapping-non-started-blocks",
    "planned-project-with-in-progress-issue-starts-project",
    "planned-project-with-in-review-issue-starts-project",
    "started-project-is-idempotent",
    "all-planned-transitions-then-starts-project",
    "terminal-project-conflict-blocks",
    "project-status-unknown-boundary-blocks",
    "local-run-exact-admission-proceeds",
    "local-run-fuzzy-path-rejected",
    "local-run-unsafe-permissions-rejected",
    "local-run-legacy-approval-schema-rejected",
    "local-run-abandoned-state-rejected",
    "local-run-cas-checkpoint-resume",
    "local-run-mirror-write-failure-does-not-invalidate",
    "verified-delivery-stops-at-open-pr",
    "explicit-merge-request-conflicts",
    "predecessor-failed-checks-observed-only",
    "predecessor-pending-checks-observed-only",
    "unchanged-planning-tip-proceeds",
    "changed-planning-tip-asks-options",
}
missing = sorted(required_cases - cases.keys())
if missing:
    raise SystemExit(f"Execute eval cases missing: {missing}")

removed_cases = {
    "admission-requires-record-pair",
    "local-run-stale-hash-record-rejected",
    "local-run-recheck-unchanged-preserves-records",
    "local-run-recheck-changed-spec-invalidates",
    "local-run-recheck-changed-plan-invalidates",
}
remaining = sorted(removed_cases & cases.keys())
if remaining:
    raise SystemExit(f"obsolete approval/content-identity evals remain: {remaining}")

for case_id in ("verified-delivery-stops-at-open-pr", "explicit-merge-request-conflicts"):
    assertions = {item["pointer"]: item["expected"] for item in cases[case_id]["assertions"]}
    if assertions.get("/mergeMutation") is not False:
        raise SystemExit(f"{case_id}: merge mutation is not forbidden")
    if assertions.get("/readyTransition") is not False:
        raise SystemExit(f"{case_id}: ready transition is not forbidden")
    if assertions.get("/mergeQueueMutation") is not False:
        raise SystemExit(f"{case_id}: merge queue mutation is not forbidden")

for case_id in ("predecessor-failed-checks-observed-only", "predecessor-pending-checks-observed-only"):
    assertions = {item["pointer"]: item["expected"] for item in cases[case_id]["assertions"]}
    if assertions.get("/checkCausedBlockers") != []:
        raise SystemExit(f"{case_id}: check outcomes create a blocker")
    observation = assertions.get("/predecessorObservation")
    if observation != {"deliveryCheckpoint": "complete", "reviews": "satisfied", "baseTip": "unchanged"}:
        raise SystemExit(f"{case_id}: predecessor evidence is not observation-only")

unchanged = {item["pointer"]: item["expected"] for item in cases["unchanged-planning-tip-proceeds"]["assertions"]}
if unchanged.get("/planningTip") != unchanged.get("/currentTip"):
    raise SystemExit("unchanged planning-tip eval does not compare equal tips")
if unchanged.get("/questionAsked") is not False:
    raise SystemExit("unchanged planning-tip eval asks unnecessarily")

changed = {item["pointer"]: item["expected"] for item in cases["changed-planning-tip-asks-options"]["assertions"]}
if changed.get("/options") != ["Continue", "Revise spec/plan", "Stop"]:
    raise SystemExit("changed planning-tip options mismatch")
if changed.get("/mutationCount") != 0:
    raise SystemExit("changed planning-tip eval mutates before choice")
for pointer in ("/providerMutationStarted", "/worktreeMutationStarted", "/sourceMutationStarted"):
    if changed.get(pointer) is not False:
        raise SystemExit(f"changed planning-tip eval permits mutation at {pointer}")

local_admission = {item["pointer"]: item["expected"] for item in cases["local-run-exact-admission-proceeds"]["assertions"]}
if local_admission.get("/checkpointPersistence") != "atomic-manifest-replacement":
    raise SystemExit("local admission does not use the plain manifest checkpoint contract")

legacy_case = cases["local-run-legacy-approval-schema-rejected"]
legacy_text = legacy_case["prompt"] + " " + legacy_case["expected"]
for term in ("projectSpecApprovalRecord", "executionPlanApprovalRecord", "SHA-256", "byteLength"):
    if term not in legacy_text:
        raise SystemExit(f"legacy schema rejection does not name {term}")
for case_id, case in cases.items():
    if case_id == "local-run-legacy-approval-schema-rejected":
        continue
    current = json.dumps(case, sort_keys=True)
    if re.search(r"projectSpecApprovalRecord|executionPlanApprovalRecord|SHA-256|byteLength|fingerprint", current, re.I):
        raise SystemExit(f"{case_id}: obsolete approval/content-identity term remains")

project_select = cases["project-selects-lowest-unfinished"]
checkpoint = next(item for item in project_select["assertions"] if item["id"] == "project-checkpoint")
if checkpoint["expected"] != {"issueId": "issue-001", "ordinal": 1, "status": "complete"}:
    raise SystemExit("project selection predecessor checkpoint mismatch")

print("sequential exact-resource execution admission: ok")
PY
