#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "$HERE/.." && pwd)"

if [[ -e "$SKILL_ROOT/references/report-template.md" ]]; then
  echo "FAIL: legacy local overnight report template still exists" >&2
  exit 1
fi

python3 - "$SKILL_ROOT" <<'PY'
import json
from datetime import datetime
import sys
from pathlib import Path

root = Path(sys.argv[1])
fixture = json.loads((root / "evals/fixtures/overnight-state.json").read_text())
evals = json.loads((root / "evals/evals.json").read_text())

skill = (root / "SKILL.md").read_text()
for retired_token in (".woostack/overnight/", "references/report-template.md"):
    if retired_token in skill:
        raise SystemExit(f"FAIL: retired local-report contract returned: {retired_token}")
if "localReportPath" in fixture or ".woostack/overnight/" in json.dumps(fixture):
    raise SystemExit("FAIL: active overnight fixture contains a local report path")

required_cases = {
    "renders-remote-handback-and-continues-independent-track",
    "validates-canonical-app-22-unattended-records",
    "every-receipt-family-is-required-for-acceptance",
    "admits-fresh-or-exact-monotonic-resume-only",
    "requires-fresh-pinned-lead-for-every-project-mutation",
    "keeps-implementation-evidence-commit-only",
    "keeps-coding-worker-observation-only",
}
case_ids = {case["id"] for case in evals["cases"]}
missing_cases = required_cases - case_ids
if missing_cases:
    raise SystemExit(f"FAIL: missing overnight eval cases: {sorted(missing_cases)}")

required_resume_scenarios = {
    "fresh-execution-approved",
    "verified-executing-resume",
    "verified-in-review-resume",
    "foreign-retained-run",
    "stale-retained-run",
    "partial-unknown-retained-boundary",
}
resume_scenarios = {scenario["id"]: scenario for scenario in fixture["resumeAdmissionScenarios"]}
missing_resume = required_resume_scenarios - set(resume_scenarios)
if missing_resume:
    raise SystemExit(f"FAIL: missing resume fixtures: {sorted(missing_resume)}")
if resume_scenarios["fresh-execution-approved"]["admission"] != "fresh-run":
    raise SystemExit("FAIL: executionApproved fixture must be fresh-run only")
if (
    resume_scenarios["verified-executing-resume"]["admission"] != "resume"
    or resume_scenarios["verified-executing-resume"]["nextBoundary"] != "push-or-submit"
):
    raise SystemExit("FAIL: verified executing fixture must resume after implementation evidence")
if (
    resume_scenarios["verified-in-review-resume"]["admission"] != "resume"
    or resume_scenarios["verified-in-review-resume"]["nextBoundary"] != "full-review-sweep"
):
    raise SystemExit("FAIL: verified inReview fixture must resume at the sweep")
for scenario_id in (
    "foreign-retained-run",
    "stale-retained-run",
    "partial-unknown-retained-boundary",
):
    scenario = resume_scenarios[scenario_id]
    if (
        scenario["admission"] != "blocked"
        or scenario["newUuidAllowed"] is not False
        or scenario["replayAllowed"] is not False
    ):
        raise SystemExit(f"FAIL: {scenario_id} must block without UUID allocation or replay")

canonical_payload_keys = ["baseCommitSha", "headCommitSha", "committedDiffHash"]
contract = fixture["implementationEvidenceContract"]
if (
    contract["producer"] != "woostack-commit"
    or contract["boundaryOwner"] != "issue-controller"
    or contract["boundary"] != "after-finalized-commit-before-push-or-pr-submission"
    or contract["payloadKeys"] != canonical_payload_keys
    or contract["prDataIncluded"] is not False
):
    raise SystemExit("FAIL: implementationEvidence producer contract drifted")

implementation_events = [
    issue["controllerReceipts"]["implementationEvidence"]
    for issue in fixture["issues"]
    if "controllerReceipts" in issue
    and "implementationEvidence" in issue["controllerReceipts"]
]
implementation_events.extend(
    scenario["issue"]["implementationEvidence"]
    for scenario in fixture["resumeAdmissionScenarios"]
    if "issue" in scenario and "implementationEvidence" in scenario["issue"]
)
for event in implementation_events:
    if set(event["data"]) != set(canonical_payload_keys):
        raise SystemExit("FAIL: implementationEvidence payload is not exactly the canonical fields")

PROJECT_ID = fixture["project"]["id"]
REPOSITORY = fixture["repository"]
APP_21_ID = "21111111-1111-4111-8111-111111111111"
APP_22_ID = "22222222-2222-4222-8222-222222222222"
ENGINEER_NATIVE_ACTOR = {
    "kind": "app",
    "principalId": "app-overnight-engineer",
}
ENGINEER_PAYLOAD_ACTOR = {
    "principalKind": "app",
    "principalId": "app-overnight-engineer",
}
RAW_ISSUE_EVENT_KEYS = {
    "id",
    "createdAt",
    "actor",
    "data",
    "readComplete",
    "envelope",
}
ISSUE_ENVELOPE_KEYS = {
    "clientId",
    "event",
    "issueId",
    "kind",
    "label",
    "relatedIds",
    "repository",
    "revision",
    "role",
    "schema",
    "supersedesId",
}


def parse_time(value):
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def assert_issue_event(
    record,
    *,
    event,
    issue_id,
    native_id,
    client_id,
    created_at,
    data_keys,
    related_ids,
):
    if set(record) != RAW_ISSUE_EVENT_KEYS:
        raise SystemExit(
            f"FAIL: {event} must be a raw canonical issue record, got {sorted(record)}"
        )
    if (
        record["id"] != native_id
        or record["createdAt"] != created_at
        or record["actor"] != ENGINEER_NATIVE_ACTOR
        or record["readComplete"] is not True
        or set(record["data"]) != set(data_keys)
    ):
        raise SystemExit(f"FAIL: {event} native identity, author, time, data, or read-back drifted")
    envelope = record["envelope"]
    if set(envelope) != ISSUE_ENVELOPE_KEYS:
        raise SystemExit(f"FAIL: {event} envelope is not the exact canonical key set")
    expected_envelope = {
        "clientId": client_id,
        "event": event,
        "issueId": issue_id,
        "kind": "issueEvent",
        "label": "woostack",
        "relatedIds": related_ids,
        "repository": REPOSITORY,
        "revision": 1,
        "role": "increment",
        "schema": 1,
        "supersedesId": None,
    }
    if envelope != expected_envelope or related_ids != sorted(related_ids):
        raise SystemExit(f"FAIL: {event} canonical envelope or sorted relations drifted")


issues = {issue["identifier"]: issue for issue in fixture["issues"]}
app22 = issues["APP-22"]
app22_receipts = app22["controllerReceipts"]
assignment = app22_receipts["assignmentAccepted"]
verification = app22_receipts["verification"]
precommit = app22_receipts["precommitReview"]
implementation = app22_receipts["implementationEvidence"]

assert_issue_event(
    assignment,
    event="assignmentAccepted",
    issue_id=APP_22_ID,
    native_id="comment-app-22-assignment",
    client_id="70000000-0000-4000-8000-000000000031",
    created_at="2026-07-16T02:00:00Z",
    data_keys={"issueId", "ownerKind", "ownerPrincipalId", "engineerName", "runId"},
    related_ids=[],
)
if assignment["data"] != {
    "issueId": APP_22_ID,
    "ownerKind": "app",
    "ownerPrincipalId": "app-overnight-engineer",
    "engineerName": "overnight-engineer",
    "runId": fixture["runId"],
}:
    raise SystemExit("FAIL: APP-22 assignmentAccepted data is not exact")

verification_relations = sorted([PROJECT_ID, assignment["id"]])
assert_issue_event(
    verification,
    event="verification",
    issue_id=APP_22_ID,
    native_id="comment-app-22-verification",
    client_id="70000000-0000-4000-8000-000000000033",
    created_at="2026-07-16T02:10:00Z",
    data_keys={
        "issueId",
        "actor",
        "commands",
        "observedResults",
        "smokeObservations",
        "changedPaths",
        "status",
    },
    related_ids=verification_relations,
)
verification_data = verification["data"]
if (
    verification_data["issueId"] != APP_22_ID
    or verification_data["actor"] != ENGINEER_PAYLOAD_ACTOR
    or verification_data["status"] != "PASS"
    or not verification_data["commands"]
    or not verification_data["smokeObservations"]
    or verification_data["changedPaths"] != sorted(set(verification_data["changedPaths"]))
    or [result["command"] for result in verification_data["observedResults"]]
    != verification_data["commands"]
    or any(result["exitCode"] != 0 for result in verification_data["observedResults"])
):
    raise SystemExit("FAIL: APP-22 verification is not exact passing precommit evidence")

precommit_relations = sorted([PROJECT_ID, assignment["id"], verification["id"]])
assert_issue_event(
    precommit,
    event="precommitReview",
    issue_id=APP_22_ID,
    native_id="comment-app-22-precommit-review",
    client_id="70000000-0000-4000-8000-000000000035",
    created_at="2026-07-16T02:15:00Z",
    data_keys={
        "issueId",
        "actor",
        "reviewerReceipts",
        "verdict",
        "changedPaths",
        "reviewedDiffHash",
    },
    related_ids=precommit_relations,
)
precommit_data = precommit["data"]
reviewer_receipts = precommit_data["reviewerReceipts"]
if (
    precommit_data["issueId"] != APP_22_ID
    or precommit_data["actor"] != ENGINEER_PAYLOAD_ACTOR
    or precommit_data["verdict"] != "PASS"
    or precommit_data["changedPaths"] != verification_data["changedPaths"]
    or [receipt["reviewType"] for receipt in reviewer_receipts] != ["spec", "quality"]
    or any(
        set(receipt)
        != {"reviewType", "reviewerKind", "reviewerId", "reviewedDiffHash", "verdict"}
        or receipt["reviewedDiffHash"] != precommit_data["reviewedDiffHash"]
        or receipt["verdict"] != "PASS"
        for receipt in reviewer_receipts
    )
):
    raise SystemExit("FAIL: APP-22 precommitReview receipts or reviewed diff drifted")

implementation_relations = sorted(
    [PROJECT_ID, assignment["id"], verification["id"], precommit["id"]]
)
assert_issue_event(
    implementation,
    event="implementationEvidence",
    issue_id=APP_22_ID,
    native_id="comment-app-22-implementation",
    client_id="70000000-0000-4000-8000-000000000032",
    created_at="2026-07-16T02:20:00Z",
    data_keys=canonical_payload_keys,
    related_ids=implementation_relations,
)
finalized_commit = app22["finalizedCommit"]
if (
    set(finalized_commit)
    != {
        "baseCommitSha",
        "headCommitSha",
        "committedDiffHash",
        "changedPaths",
        "committedAt",
        "readComplete",
    }
    or finalized_commit["readComplete"] is not True
    or implementation["data"]
    != {key: finalized_commit[key] for key in canonical_payload_keys}
    or finalized_commit["changedPaths"] != precommit_data["changedPaths"]
    or finalized_commit["committedDiffHash"] != precommit_data["reviewedDiffHash"]
):
    raise SystemExit("FAIL: APP-22 implementation does not reverse-bind the reviewed commit")

linear_pr_relation = app22["pr"]["linearRelation"]
if (
    set(linear_pr_relation)
    != {
        "id",
        "issueId",
        "repository",
        "pullRequestNumber",
        "pullRequestUrl",
        "headSha",
        "createdAt",
        "readComplete",
    }
    or linear_pr_relation
    != {
        "id": "linear-pr-relation-22",
        "issueId": APP_22_ID,
        "repository": REPOSITORY,
        "pullRequestNumber": 22,
        "pullRequestUrl": "https://github.com/howarewoo/woostack/pull/22",
        "headSha": finalized_commit["headCommitSha"],
        "createdAt": "2026-07-16T02:24:00Z",
        "readComplete": True,
    }
):
    raise SystemExit("FAIL: APP-22 native Linear PR relation drifted")

github_review = app22["sweep"]["githubReviewReceipt"]
if (
    set(github_review)
    != {
        "id",
        "url",
        "repository",
        "issueId",
        "pullRequestNumber",
        "pullRequestUrl",
        "headSha",
        "committedDiffHash",
        "fullReview",
        "headMarker",
        "reviewer",
        "round",
        "statusLine",
        "unresolvedFindingFingerprints",
        "unresolvedThreadIds",
        "submittedAt",
        "readComplete",
    }
    or github_review["id"] != "github-review-2201"
    or github_review["issueId"] != APP_22_ID
    or github_review["repository"] != REPOSITORY
    or github_review["pullRequestNumber"] != 22
    or github_review["pullRequestUrl"] != linear_pr_relation["pullRequestUrl"]
    or github_review["headSha"] != finalized_commit["headCommitSha"]
    or github_review["committedDiffHash"] != finalized_commit["committedDiffHash"]
    or github_review["fullReview"] is not True
    or github_review["reviewer"] != ENGINEER_NATIVE_ACTOR
    or github_review["round"] != 1
    or github_review["statusLine"] != "APPROVED"
    or github_review["unresolvedFindingFingerprints"] != []
    or github_review["unresolvedThreadIds"] != []
    or github_review["submittedAt"] != "2026-07-16T02:28:00Z"
    or github_review["readComplete"] is not True
):
    raise SystemExit("FAIL: APP-22 native GitHub full-review receipt drifted")

review_result = app22["sweep"]["linearReviewResult"]
review_relations = sorted(
    [
        implementation["id"],
        verification["id"],
        linear_pr_relation["id"],
        github_review["id"],
    ]
)
assert_issue_event(
    review_result,
    event="reviewResult",
    issue_id=APP_22_ID,
    native_id="comment-app-22-review-result",
    client_id="70000000-0000-4000-8000-000000000034",
    created_at="2026-07-16T02:30:00Z",
    data_keys={
        "issueId",
        "pullRequestNumber",
        "pullRequestUrl",
        "reviewedHeadSha",
        "committedDiffHash",
        "githubReviewId",
        "unresolvedThreadIds",
        "unresolvedFindingFingerprints",
        "round",
        "result",
    },
    related_ids=review_relations,
)
if review_result["data"] != {
    "issueId": APP_22_ID,
    "pullRequestNumber": linear_pr_relation["pullRequestNumber"],
    "pullRequestUrl": linear_pr_relation["pullRequestUrl"],
    "reviewedHeadSha": github_review["headSha"],
    "committedDiffHash": github_review["committedDiffHash"],
    "githubReviewId": github_review["id"],
    "unresolvedThreadIds": [],
    "unresolvedFindingFingerprints": [],
    "round": github_review["round"],
    "result": "PASS",
}:
    raise SystemExit("FAIL: APP-22 reviewResult data does not match its native receipts")

ordered_times = [
    parse_time(assignment["createdAt"]),
    parse_time(verification["createdAt"]),
    parse_time(precommit["createdAt"]),
    parse_time(finalized_commit["committedAt"]),
    parse_time(implementation["createdAt"]),
    parse_time(linear_pr_relation["createdAt"]),
    parse_time(github_review["submittedAt"]),
    parse_time(review_result["createdAt"]),
]
if any(left >= right for left, right in zip(ordered_times, ordered_times[1:])):
    raise SystemExit(
        "FAIL: APP-22 must order verification and precommit review before commit/evidence and post-PR review"
    )
if (
    app22["driverObservations"]["complete"] is not True
    or app22["resolvedOwner"]
    != {
        "kind": "app",
        "field": "delegate",
        "principalId": "app-overnight-engineer",
        "readBack": "complete",
    }
    or app22["state"] != "inReview"
    or app22["sweep"]["invocation"]["status"] != "complete"
):
    raise SystemExit("FAIL: APP-22 cannot be classified clean from incomplete issue records")

app21 = issues["APP-21"]
app21_assignment = app21["controllerReceipts"]["assignmentAccepted"]
assert_issue_event(
    app21_assignment,
    event="assignmentAccepted",
    issue_id=APP_21_ID,
    native_id="comment-app-21-assignment",
    client_id="70000000-0000-4000-8000-000000000021",
    created_at="2026-07-16T01:00:00Z",
    data_keys={"issueId", "ownerKind", "ownerPrincipalId", "engineerName", "runId"},
    related_ids=[],
)
app21_issue_events = {event["envelope"]["event"]: event for event in app21["sweep"]["issueEvents"]}
failure_event = app21_issue_events["failure"]
blocked_event = app21_issue_events["blocked"]
assert_issue_event(
    failure_event,
    event="failure",
    issue_id=APP_21_ID,
    native_id="comment-app-21-failure",
    client_id="70000000-0000-4000-8000-000000000024",
    created_at="2026-07-16T01:30:00Z",
    data_keys={
        "issueId",
        "boundary",
        "observedResult",
        "affectedIds",
        "branch",
        "worktreePath",
        "safeNextAction",
    },
    related_ids=sorted([app21_assignment["id"], "linear-pr-relation-21", "pull-request-21"]),
)
assert_issue_event(
    blocked_event,
    event="blocked",
    issue_id=APP_21_ID,
    native_id="comment-app-21-blocked",
    client_id="70000000-0000-4000-8000-000000000025",
    created_at="2026-07-16T01:31:00Z",
    data_keys={"issueId", "previousState", "condition", "affectedIds"},
    related_ids=sorted([app21_assignment["id"], failure_event["id"]]),
)
if "handoff" in app21_issue_events:
    raise SystemExit("FAIL: ordinary blocked work must not fabricate an ownership handoff")
if (
    failure_event["data"]["affectedIds"] != ["linear-pr-relation-21", "pull-request-21"]
    or blocked_event["data"]["affectedIds"] != [failure_event["id"]]
):
    raise SystemExit("FAIL: APP-21 failure and blocked evidence is not exact")

lead_scenarios = {
    scenario["id"]: scenario for scenario in fixture["projectMutationAuthorityScenarios"]
}
non_lead = lead_scenarios["non-lead-issue-owner"]
if (
    non_lead["projectMutationAllowed"] is not False
    or non_lead["issueEvidenceAppendAllowed"] is not True
    or non_lead["projectEventUuidAllocationAllowed"] is not False
):
    raise SystemExit("FAIL: non-lead project mutation barrier drifted")
if non_lead["responsibleProjectAuthorityPrincipalId"] != fixture["project"]["pinnedLead"]["principalId"]:
    raise SystemExit("FAIL: non-lead project action does not return to the pinned lead")
PROJECT_EVENT_KEYS = {"id", "createdAt", "actor", "readComplete", "envelope"}
PROJECT_ENVELOPE_KEYS = {
    "clientId",
    "event",
    "kind",
    "label",
    "predecessorId",
    "projectId",
    "relatedIds",
    "repository",
    "revision",
    "role",
    "schema",
    "supersedesId",
}
expected_project_records = {
    "project-progress-track-a": {
        "clientId": "80000000-0000-4000-8000-000000000021",
        "event": "progress",
        "createdAt": "2026-07-16T01:32:30Z",
        "relatedIds": sorted([APP_21_ID, "23333333-3333-4333-8333-333333333333", blocked_event["id"]]),
    },
    "project-blocker-track-a": {
        "clientId": "80000000-0000-4000-8000-000000000022",
        "event": "blockerOpened",
        "createdAt": "2026-07-16T01:33:00Z",
        "relatedIds": sorted([APP_21_ID, blocked_event["id"]]),
    },
    "project-progress-track-b": {
        "clientId": "80000000-0000-4000-8000-000000000023",
        "event": "progress",
        "createdAt": "2026-07-16T02:31:00Z",
        "relatedIds": sorted([APP_22_ID, review_result["id"]]),
    },
}
project_records = {record["id"]: record for record in fixture["projectUpdates"]}
if set(project_records) != set(expected_project_records):
    raise SystemExit("FAIL: project event native IDs drifted")
project_actor = {
    "kind": fixture["project"]["pinnedLead"]["kind"],
    "principalId": fixture["project"]["pinnedLead"]["principalId"],
}
for native_id, expected in expected_project_records.items():
    record = project_records[native_id]
    envelope = record["envelope"]
    if (
        set(record) != PROJECT_EVENT_KEYS
        or record["createdAt"] != expected["createdAt"]
        or record["actor"] != project_actor
        or record["readComplete"] is not True
        or set(envelope) != PROJECT_ENVELOPE_KEYS
        or envelope
        != {
            "clientId": expected["clientId"],
            "event": expected["event"],
            "kind": "projectEvent",
            "label": "woostack",
            "predecessorId": fixture["project"]["phaseHeadId"],
            "projectId": PROJECT_ID,
            "relatedIds": expected["relatedIds"],
            "repository": REPOSITORY,
            "revision": 1,
            "role": "feature",
            "schema": 1,
            "supersedesId": None,
        }
    ):
        raise SystemExit(f"FAIL: project event {native_id} is not a canonical pinned-lead record")

blocker_relations = project_records["project-blocker-track-a"]["envelope"]["relatedIds"]
if blocker_relations != sorted([APP_21_ID, blocked_event["id"]]):
    raise SystemExit("FAIL: blockerOpened must pair each affected issue with blocked/failure evidence")
if "localReportPath" in fixture:
    raise SystemExit("FAIL: terminal handback must not depend on a local report artifact")

boundary = fixture["controllerWorkerBoundary"]
worker = boundary["codingWorker"]
expected_worker_actions = [
    "analyze-selected-issue",
    "edit-selected-surface",
    "run-focused-tests",
    "run-changed-path-smoke-check",
    "report-observations",
]
if (
    worker["issueIds"] != ["22222222-2222-4222-8222-222222222222"]
    or worker["allowedActions"] != expected_worker_actions
    or worker["leavesChangesUncommitted"] is not True
    or worker["handback"] != "observations-only"
):
    raise SystemExit("FAIL: coding worker must remain one-issue and observation-only")

escalation = boundary["scopeEscalationAttempt"]
expected_escalation_actions = [
    "commit",
    "push",
    "submit-or-update-pr",
    "append-linear-event",
    "mutate-relations-or-state",
    "request-inReview",
    "perform-project-update",
    "decide-acceptance",
]
if (
    escalation["actor"] != "coding-worker"
    or escalation["requestedActions"] != expected_escalation_actions
    or escalation["decision"] != "blocked"
    or escalation["mutationAttempted"] is not False
    or escalation["eventUuidAllocated"] is not False
    or escalation["nextAuthority"] != "issue-controller"
):
    raise SystemExit("FAIL: coding-worker scope escalation must stop before every side effect")

controller = boundary["controllerProgression"]
expected_controller_boundaries = [
    "verification-append-read-back",
    "precommitReview-append-read-back",
    "commit",
    "implementationEvidence-append-read-back",
    "push",
    "graphite-pr-submit-or-update",
    "github-pr-read-back",
    "linear-pr-relation-read-back",
    "inReview-request-read-back",
]
if (
    controller["actor"] != "issue-controller"
    or controller["independentReads"]
    != {"owner": "complete", "contract": "complete", "evidence": "complete"}
    or controller["freshReadBackBeforeEachBoundary"] is not True
    or controller["boundaryOwner"] != "issue-controller"
    or controller["orderedBoundaries"] != expected_controller_boundaries
    or controller["verificationAppendReadBack"] != "complete"
    or controller["implementationEvidenceProducer"] != "woostack-commit"
    or controller["implementationEvidenceAppendReadBack"] != "complete"
    or controller["projectMutationOwner"] != "fresh-pinned-lead"
    or controller["acceptanceDecisionOwner"] != "type-aware-acceptance-authority"
    or controller["unattendedContinuationAllowed"] is not True
):
    raise SystemExit("FAIL: controller-owned unattended progression contract drifted")

failure_examples = fixture["receiptFailureExamples"]
expected_incomplete_ids = {
    "missingWorker": "driver-observations-app-22",
    "missingControllerIssueReceipt": "comment-app-22-precommit-review",
    "missingReview": "github-review-2201",
    "missingMutationReadBack": "comment-app-22-review-result",
}
if set(failure_examples) != set(expected_incomplete_ids):
    raise SystemExit("FAIL: concrete incomplete-receipt variants drifted")
for scenario_id, expected_native_id in expected_incomplete_ids.items():
    example = failure_examples[scenario_id]
    receipt = example["incompleteReceipt"]
    completeness = [
        example["driverObservationsComplete"],
        example["controllerIssueReceiptsComplete"],
        example["reviewReceiptComplete"],
        example["mutationReadBackComplete"],
    ]
    if (
        example["issueId"] != APP_22_ID
        or receipt["id"] != expected_native_id
        or receipt["readComplete"] is not False
        or completeness.count(False) != 1
        or example["admission"] != "blocked"
        or example["acceptanceAllowed"] is not False
    ):
        raise SystemExit(f"FAIL: {scenario_id} incomplete receipt must block APP-22")

print("PASS: overnight canonical issue, review, blocker, handoff, and resume fixtures")
PY

bash "$SKILL_ROOT/scripts/tests/run-tests.sh"
