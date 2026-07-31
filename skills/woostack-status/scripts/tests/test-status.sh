#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import copy
import json
import os
import re
import sys
import uuid
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
paths = {
    "skill": root / "skills/woostack-status/SKILL.md",
    "conventions": root / "skills/woostack-status/references/conventions.md",
    "evals": root / "skills/woostack-status/evals/evals.json",
    "fixture": root / "skills/woostack-status/evals/fixtures/linear-state.json",
    "expected": root / "skills/woostack-status/scripts/tests/fixtures/linear-state-expected.json",
    "test": root / "skills/woostack-status/scripts/tests/test-status.sh",
    "runner": root / "skills/woostack-status/scripts/tests/run-tests.sh",
}
texts = {name: path.read_text(encoding="utf-8") for name, path in paths.items()}


def fail(message):
    raise SystemExit(f"test-status: {message}")


def must(text, token, scope):
    if token not in text:
        fail(f"{scope} missing {token!r}")


def rejects(label, operation):
    try:
        operation()
    except (KeyError, TypeError, ValueError):
        return
    fail(f"{label} was accepted")


if not os.access(paths["test"], os.X_OK):
    fail("contract test is not executable")
if not os.access(paths["runner"], os.X_OK):
    fail("test runner is not executable")
if texts["runner"].count("test-status.sh") != 1:
    fail("test-status.sh must be registered exactly once")

workflow = re.sub(r"\s+", " ", texts["skill"] + "\n" + texts["conventions"])
for required in (
    "official host-exposed Linear MCP",
    "role-`feature`",
    "role-`increment`",
    "role-`work-item`",
    "fully paginate",
    "exact issue UUID",
    "designApproved → specHardened → specApproved → planning → ready",
    "executionApproved → executing → inReview → done",
    "`assignmentAccepted`",
    "`implementationEvidence`",
    "`verification`",
    "`precommitReview`",
    "`decisionResponse`",
    "`reviewResult`",
    "`acceptance`",
    "`issueDone`",
    "`restackAuthorized`",
    "exactly `baseCommitSha`, `headCommitSha`, and `committedDiffHash`",
    "current PR head/ref",
    "second complete issue read",
    "canonical PR number/URL",
    "`githubReviewId`",
    "`unresolvedThreadIds`",
    "`unresolvedFindingFingerprints`",
    "retained UUID",
    "type-aware responsible authority",
    "authenticated invoking MCP principal",
    "before UUID allocation",
    "assignment current at the event timestamp",
    "precommit",
    "RFC 4122",
    "historical",
    "reverse-bind",
    "exact named native revision",
    "inactive history",
    "authorization time < completion time <= expiresAt",
    "issue-local, root, or standalone",
    "never a coding worker",
    "complete actual project-event chain",
    "semantic `inReview → done`",
    "native `started → completed`",
    "all of its complete managed increment set is `done`",
    "Linear-Project: <verified stable project UUID>",
    "Linear-Issue: <TEAM-NUMBER>",
    "case-insensitive exact, indented, quoted, or fenced `Spec:` attribution candidate",
    "Standalone work items (no project)",
    "activityAt",
    "stale",
    "pending handoff",
    "exactly one next action",
    "independently read the complete issue",
    "Text output only",
):
    must(workflow, required, "status contract")

fixture = json.loads(texts["fixture"])
expected = json.loads(texts["expected"])
evals = json.loads(texts["evals"])
if set(fixture) != {
    "schemaVersion", "capturedAt", "policy", "project", "standaloneIssues", "github",
    "linearPullRequestRelations", "ancestryCases", "mutationReceipts", "failureCases",
}:
    fail("fixture top-level schema drift")
if fixture["schemaVersion"] != 1:
    fail("fixture schemaVersion must be 1")
if evals.get("schemaVersion") != 1 or evals.get("skill") != "woostack-status":
    fail("eval corpus envelope mismatch")
case_ids = {case["id"] for case in evals.get("cases", [])}
for case_id in (
    "renders-feature-and-standalone-text-board",
    "reconciles-only-merge-and-acceptance-eligible-issue",
    "accepts-open-git-parent-and-rejects-unsafe-dependencies",
    "rejects-malformed-terminal-event-payload",
    "rejects-malformed-review-result-evidence",
    "rejects-stale-review-result-evidence",
    "rejects-non-full-review-receipt",
    "blocks-git-linear-attribution-mismatch",
    "completes-project-only-after-all-increments-done",
    "blocks-wrong-principal-before-issue-done",
    "rejects-malformed-foreign-precommit-verification",
    "validates-consumed-restack-authorization-temporally",
    "validates-complete-project-event-dispatch",
    "validates-precommit-review-before-first-implementation",
    "validates-historical-native-revision-at-authorization-time",
    "treats-expired-unused-restack-records-as-inactive",
    "allows-empty-local-affected-relations-only",
    "dispatches-every-canonical-issue-event-strictly",
    "validates-principal-kind-verification-actor",
    "resolves-independent-native-linear-pr-relation",
    "validates-sweep-authorized-verification-revision",
    "selects-latest-valid-current-head-review-family",
    "resolves-unique-temporal-restack-consumers",
    "validates-historical-authorization-owner-at-time",
    "preserves-implementation-evidence-through-owner-handoff",
    "derives-blocker-issue-and-preserves-terminal-reconciliation",
):
    if case_id not in case_ids:
        fail(f"missing status eval case {case_id}")
for case in evals["cases"]:
    fixtures = case.get("fixtures", [])
    if case["id"] in case_ids & {
        "renders-feature-and-standalone-text-board",
        "reconciles-only-merge-and-acceptance-eligible-issue",
        "accepts-open-git-parent-and-rejects-unsafe-dependencies",
        "rejects-malformed-terminal-event-payload",
        "rejects-malformed-review-result-evidence",
        "rejects-stale-review-result-evidence",
        "rejects-non-full-review-receipt",
        "blocks-git-linear-attribution-mismatch",
        "completes-project-only-after-all-increments-done",
        "blocks-wrong-principal-before-issue-done",
        "rejects-malformed-foreign-precommit-verification",
        "validates-consumed-restack-authorization-temporally",
        "validates-complete-project-event-dispatch",
        "validates-precommit-review-before-first-implementation",
        "validates-historical-native-revision-at-authorization-time",
        "treats-expired-unused-restack-records-as-inactive",
        "allows-empty-local-affected-relations-only",
        "dispatches-every-canonical-issue-event-strictly",
        "validates-principal-kind-verification-actor",
        "resolves-independent-native-linear-pr-relation",
        "validates-sweep-authorized-verification-revision",
        "selects-latest-valid-current-head-review-family",
        "resolves-unique-temporal-restack-consumers",
        "validates-historical-authorization-owner-at-time",
        "preserves-implementation-evidence-through-owner-handoff",
        "derives-blocker-issue-and-preserves-terminal-reconciliation",
    } and fixtures != ["linear-state.json"]:
        fail(f"eval {case['id']} must consume only linear-state.json")

repository = fixture["policy"]["repository"]
project = fixture["project"]
project_id = project["id"]
project_client_id = project["envelope"]["clientId"]
now = datetime.fromisoformat(fixture["capturedAt"].replace("Z", "+00:00"))
if now.tzinfo is None:
    fail("capturedAt must be timezone-aware")


UUID_TEXT = re.compile(
    r"[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}"
)


def valid_uuid(value, field):
    if not isinstance(value, str) or UUID_TEXT.fullmatch(value) is None:
        raise ValueError(f"invalid {field}")
    parsed = uuid.UUID(value)
    if parsed.variant != uuid.RFC_4122 or parsed.version not in {1, 2, 3, 4, 5} or str(parsed) != value:
        raise ValueError(f"invalid {field}")


def timestamp(value):
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        raise ValueError("timestamp must be timezone-aware")
    return parsed.astimezone(timezone.utc)


def instant(value):
    parsed = timestamp(value)
    if parsed > now:
        raise ValueError("future timestamp")
    return parsed


def sorted_unique(values):
    return values == sorted(set(values))


def validate_complete(snapshot):
    pages = snapshot["policy"]["paginationComplete"]
    required = {
        "projects", "projectUpdates", "projectIssues", "teamIssues", "issueComments",
        "relations", "owners", "githubPullRequests", "githubReviews",
    }
    if set(pages) != required or not all(pages.values()):
        raise ValueError("partial pagination")
    if not snapshot["project"]["readComplete"] or not snapshot["github"]["readComplete"]:
        raise ValueError("partial resource read")
    if snapshot["github"]["repository"] != snapshot["policy"]["repository"]:
        raise ValueError("foreign GitHub repository")


validate_complete(fixture)

LINEAR_PR_RELATION_FIELDS = {
    "id", "issueId", "repository", "pullRequestNumber", "pullRequestUrl", "branch",
    "createdAt", "updatedAt", "readComplete",
}


def validate_linear_pr_relation_collection(collection):
    if (
        not isinstance(collection, dict)
        or set(collection) != {
            "readAt", "readComplete", "paginationComplete", "records",
        }
        or collection["readComplete"] is not True
        or collection["paginationComplete"] is not True
        or not isinstance(collection["records"], list)
    ):
        raise ValueError("partial native Linear PR relation collection")
    read_at = instant(collection["readAt"])
    records = []
    native_ids = set()
    for record in collection["records"]:
        if (
            not isinstance(record, dict)
            or set(record) != LINEAR_PR_RELATION_FIELDS
            or record["readComplete"] is not True
            or not isinstance(record["id"], str)
            or not record["id"]
            or record["id"] in native_ids
            or not isinstance(record["issueId"], str)
            or not record["issueId"]
            or record["repository"] != repository
            or type(record["pullRequestNumber"]) is not int
            or record["pullRequestNumber"] < 1
            or not isinstance(record["pullRequestUrl"], str)
            or not record["pullRequestUrl"]
            or not isinstance(record["branch"], str)
            or not record["branch"]
        ):
            raise ValueError("malformed or duplicate native Linear PR relation")
        created_at = instant(record["createdAt"])
        updated_at = instant(record["updatedAt"])
        if created_at > updated_at or updated_at > read_at:
            raise ValueError("stale native Linear PR relation read-back")
        native_ids.add(record["id"])
        records.append(record)
    return records


linear_pr_relation_records = validate_linear_pr_relation_collection(
    fixture["linearPullRequestRelations"],
)


def resolve_linear_pr_relation(
    issue, pull_request_number, pull_request_url, branch=None, at=None,
    records=None,
):
    candidates = [
        record for record in (
            linear_pr_relation_records if records is None else records
        )
        if record["issueId"] == issue["id"]
    ]
    if len(candidates) != 1:
        raise ValueError("missing or duplicate native Linear PR relation")
    relation = candidates[0]
    if (
        relation["repository"] != repository
        or relation["pullRequestNumber"] != pull_request_number
        or relation["pullRequestUrl"] != pull_request_url
        or (branch is not None and relation["branch"] != branch)
    ):
        raise ValueError("foreign native Linear PR relation identity")
    if at is not None and (
        instant(relation["createdAt"]) > at
        or instant(relation["updatedAt"]) > at
    ):
        raise ValueError("native Linear PR relation was stale at event time")
    return relation

BASE_RESOURCE = {"clientId", "kind", "label", "repository", "role", "schema"}
PROJECT_EVENT = BASE_RESOURCE | {
    "event", "revision", "projectId", "predecessorId", "relatedIds", "supersedesId",
}
ISSUE_EVENT = BASE_RESOURCE | {
    "event", "revision", "issueId", "relatedIds", "supersedesId",
}
PHASES = {
    "designApproved", "specHardened", "specApproved", "planning", "ready",
    "executionApproved", "executing", "inReview", "done", "abandoned",
}
NON_PHASE = {"decision", "progress", "blockerOpened", "blockerResolved", "handoff"}
NEXT_PHASE = {
    "designApproved": "specHardened",
    "specHardened": "specApproved",
    "specApproved": "planning",
    "planning": "ready",
    "ready": "executionApproved",
    "executionApproved": "executing",
    "executing": "inReview",
    "inReview": "done",
}
ISSUE_EVENTS = {
    "assignmentAccepted", "verification", "precommitReview", "implementationEvidence",
    "decisionRequest", "decisionResponse", "failure", "handoff", "blocked", "unblocked",
    "reviewResult", "acceptance", "restackAuthorized", "issueDone",
}
ASSIGNMENT_DATA = {"engineerName", "issueId", "ownerKind", "ownerPrincipalId", "runId"}
IMPLEMENTATION_DATA = {"baseCommitSha", "headCommitSha", "committedDiffHash"}
VERIFICATION_DATA = {
    "actor", "changedPaths", "commands", "issueId", "observedResults",
    "smokeObservations", "status",
}
VERIFICATION_RESULT = {"command", "exitCode", "result"}
PRECOMMIT_REVIEW_DATA = {
    "actor", "changedPaths", "issueId", "reviewedDiffHash", "reviewerReceipts",
    "verdict",
}
PRECOMMIT_REVIEW_RECEIPT = {
    "reviewType", "reviewerKind", "reviewerId", "reviewedDiffHash", "verdict",
}
DECISION_REQUEST_DATA = {
    "affectedIds", "issueId", "question", "requestKind", "requestedAuthorityKind",
    "requestedAuthorityPrincipalId", "safeNextAction",
}
DECISION_RESPONSE_DATA = {
    "decision", "decisionRequestId", "issueId", "resolution", "safeNextAction",
}
FAILURE_DATA = {
    "affectedIds", "boundary", "branch", "issueId", "observedResult",
    "safeNextAction", "worktreePath",
}
HANDOFF_DATA = {
    "branch", "issueId", "nextAction", "ownerKind", "ownerPrincipalId",
    "pullRequestUrl", "recoveryEvidenceIds", "runId", "unresolvedItems", "worktreePath",
}
BLOCKED_DATA = {"affectedIds", "condition", "issueId", "previousState"}
UNBLOCKED_DATA = {
    "blockedEventId", "issueId", "resolution", "resolutionEvidenceIds", "restoredState",
}
ACCEPTANCE_DATA = {"actor", "issueId", "result"}
RESTACK_AUTHORIZED_DATA = {
    "affectedRelationIds", "branch", "controllerPrincipalId", "controllerPrincipalKind",
    "expiresAt", "headCommitSha", "operationId", "registryClaimPath", "worktreePath",
}
RESTACK_DECISION_DATA = {
    "affectedIssueIds", "affectedRelationIds", "controllerPrincipalId",
    "controllerPrincipalKind", "expiresAt", "operationId",
}
REVIEW_RESULT_DATA = {
    "issueId", "pullRequestNumber", "pullRequestUrl", "reviewedHeadSha",
    "committedDiffHash", "githubReviewId", "unresolvedThreadIds",
    "unresolvedFindingFingerprints", "round", "result",
}


def git_oid(value, field):
    if not isinstance(value, str) or re.fullmatch(r"(?:[0-9a-f]{40}|[0-9a-f]{64})", value) is None:
        raise ValueError(f"invalid {field}")


def nonempty_text(value, field):
    if not isinstance(value, str) or not value:
        raise ValueError(f"invalid {field}")


def validate_paths(values, field):
    if (
        not isinstance(values, list)
        or not values
        or not sorted_unique(values)
        or any(not isinstance(value, str) or not value for value in values)
        or any(path.startswith("/") or ".." in Path(path).parts for path in values)
    ):
        raise ValueError(f"invalid {field}")


def validate_payload_principal(actor, field):
    if (
        not isinstance(actor, dict)
        or set(actor) != {"principalKind", "principalId"}
        or actor["principalKind"] not in {"app", "human"}
        or not isinstance(actor["principalId"], str)
        or not actor["principalId"]
    ):
        raise ValueError(f"invalid {field}")


def payload_as_native_actor(actor, field):
    validate_payload_principal(actor, field)
    return {
        "kind": actor["principalKind"],
        "principalId": actor["principalId"],
    }


def validate_ids(values, field, require_nonempty=False):
    if (
        not isinstance(values, list)
        or (require_nonempty and not values)
        or not sorted_unique(values)
        or any(not isinstance(value, str) or not value for value in values)
    ):
        raise ValueError(f"invalid {field}")


def validate_nullable_text(value, field):
    if value is not None:
        nonempty_text(value, field)


def validate_issue_event_payload(record):
    event = record["envelope"]["event"]
    data = record.get("data")
    if not isinstance(data, dict):
        raise ValueError("issue event data must be an object")
    if event == "assignmentAccepted":
        if set(data) != ASSIGNMENT_DATA:
            raise ValueError("assignmentAccepted data fields")
        for field in ("engineerName", "issueId", "ownerPrincipalId", "runId"):
            nonempty_text(data[field], f"assignmentAccepted {field}")
        if data["ownerKind"] not in {"app", "human"}:
            raise ValueError("assignmentAccepted owner kind")
    elif event == "implementationEvidence":
        if set(data) != IMPLEMENTATION_DATA:
            raise ValueError("implementation evidence must contain only canonical commit fields")
        git_oid(data["baseCommitSha"], "implementation baseCommitSha")
        git_oid(data["headCommitSha"], "implementation headCommitSha")
        git_oid(data["committedDiffHash"], "implementation committedDiffHash")
    elif event == "verification":
        if set(data) != VERIFICATION_DATA:
            raise ValueError("verification data fields")
        validate_payload_principal(data["actor"], "verification actor")
        nonempty_text(data["issueId"], "verification issue")
        commands = data["commands"]
        if (
            not isinstance(commands, list)
            or not commands
            or len(commands) != len(set(commands))
            or any(not isinstance(command, str) or not command for command in commands)
        ):
            raise ValueError("verification commands")
        results = data["observedResults"]
        if (
            not isinstance(results, list)
            or len(results) != len(commands)
            or any(not isinstance(result, dict) or set(result) != VERIFICATION_RESULT for result in results)
            or [result["command"] for result in results] != commands
            or any(type(result["exitCode"]) is not int or result["exitCode"] < 0 for result in results)
            or any(not isinstance(result["result"], str) or not result["result"] for result in results)
        ):
            raise ValueError("verification observed results")
        if (
            not isinstance(data["smokeObservations"], list)
            or not data["smokeObservations"]
            or any(
                not isinstance(observation, str) or not observation
                for observation in data["smokeObservations"]
            )
        ):
            raise ValueError("verification smokeObservations")
        validate_paths(data["changedPaths"], "verification changed paths")
        if data["status"] != "PASS":
            raise ValueError("verification status")
    elif event == "precommitReview":
        if set(data) != PRECOMMIT_REVIEW_DATA:
            raise ValueError("precommitReview data fields")
        nonempty_text(data["issueId"], "precommitReview issue")
        validate_payload_principal(data["actor"], "precommitReview actor")
        validate_paths(data["changedPaths"], "precommitReview changed paths")
        git_oid(data["reviewedDiffHash"], "precommitReview reviewed diff")
        receipts = data["reviewerReceipts"]
        if (
            not isinstance(receipts, list)
            or len(receipts) != 2
            or [receipt.get("reviewType") for receipt in receipts] != ["spec", "quality"]
        ):
            raise ValueError("precommitReview ordered reviewer receipts")
        for receipt in receipts:
            if not isinstance(receipt, dict) or set(receipt) != PRECOMMIT_REVIEW_RECEIPT:
                raise ValueError("precommitReview reviewer receipt fields")
            if receipt["reviewerKind"] not in {"app", "human"}:
                raise ValueError("precommitReview reviewer kind")
            nonempty_text(receipt["reviewerId"], "precommitReview reviewer ID")
            if (
                receipt["reviewedDiffHash"] != data["reviewedDiffHash"]
                or receipt["verdict"] != "PASS"
            ):
                raise ValueError("precommitReview reviewer receipt result")
        if data["verdict"] != "PASS":
            raise ValueError("precommitReview verdict")
    elif event == "decisionRequest":
        if set(data) != DECISION_REQUEST_DATA:
            raise ValueError("decisionRequest data fields")
        for field in (
            "issueId", "question", "requestKind", "requestedAuthorityPrincipalId",
            "safeNextAction",
        ):
            nonempty_text(data[field], f"decisionRequest {field}")
        if data["requestedAuthorityKind"] not in {"app", "human"}:
            raise ValueError("decisionRequest authority kind")
        validate_ids(data["affectedIds"], "decisionRequest affected IDs")
    elif event == "decisionResponse":
        if set(data) != DECISION_RESPONSE_DATA:
            raise ValueError("decisionResponse data fields")
        for field in (
            "decision", "decisionRequestId", "issueId", "resolution", "safeNextAction",
        ):
            nonempty_text(data[field], f"decisionResponse {field}")
    elif event == "failure":
        if set(data) != FAILURE_DATA:
            raise ValueError("failure data fields")
        for field in ("boundary", "issueId", "observedResult", "safeNextAction"):
            nonempty_text(data[field], f"failure {field}")
        validate_ids(data["affectedIds"], "failure affected IDs")
        validate_nullable_text(data["branch"], "failure branch")
        validate_nullable_text(data["worktreePath"], "failure worktree path")
    elif event == "handoff":
        if set(data) != HANDOFF_DATA:
            raise ValueError("handoff data fields")
        for field in ("issueId", "nextAction", "ownerPrincipalId", "runId"):
            nonempty_text(data[field], f"handoff {field}")
        if data["ownerKind"] not in {"app", "human"}:
            raise ValueError("handoff owner kind")
        for field in ("branch", "pullRequestUrl", "worktreePath"):
            validate_nullable_text(data[field], f"handoff {field}")
        validate_ids(data["unresolvedItems"], "handoff unresolved items")
        validate_ids(data["recoveryEvidenceIds"], "handoff recovery evidence")
    elif event == "blocked":
        if set(data) != BLOCKED_DATA:
            raise ValueError("blocked data fields")
        for field in ("condition", "issueId"):
            nonempty_text(data[field], f"blocked {field}")
        if data["previousState"] not in {"planned", "executing", "inReview"}:
            raise ValueError("blocked previous state")
        validate_ids(data["affectedIds"], "blocked affected IDs")
    elif event == "unblocked":
        if set(data) != UNBLOCKED_DATA:
            raise ValueError("unblocked data fields")
        for field in ("blockedEventId", "issueId", "resolution"):
            nonempty_text(data[field], f"unblocked {field}")
        if data["restoredState"] not in {"planned", "executing", "inReview"}:
            raise ValueError("unblocked restored state")
        validate_ids(
            data["resolutionEvidenceIds"], "unblocked resolution evidence",
            require_nonempty=True,
        )
    elif event == "reviewResult":
        if set(data) != REVIEW_RESULT_DATA:
            raise ValueError("reviewResult data fields")
        nonempty_text(data["issueId"], "reviewResult issue identity")
        if type(data["pullRequestNumber"]) is not int or data["pullRequestNumber"] < 1:
            raise ValueError("reviewResult pull request number")
        nonempty_text(data["pullRequestUrl"], "reviewResult pull request URL")
        git_oid(data["reviewedHeadSha"], "reviewResult reviewed head")
        git_oid(data["committedDiffHash"], "reviewResult committed diff hash")
        nonempty_text(data["githubReviewId"], "reviewResult GitHub review identity")
        for field in ("unresolvedThreadIds", "unresolvedFindingFingerprints"):
            values = data[field]
            if (
                not isinstance(values, list)
                or not sorted_unique(values)
                or any(not isinstance(value, str) or not value for value in values)
            ):
                raise ValueError(f"reviewResult {field}")
        if type(data["round"]) is not int or data["round"] < 1:
            raise ValueError("reviewResult round")
        if data["result"] not in {"PASS", "CHANGES_REQUESTED"}:
            raise ValueError("reviewResult result")
    elif event == "acceptance":
        if set(data) != ACCEPTANCE_DATA:
            raise ValueError("acceptance data fields")
        nonempty_text(data["issueId"], "acceptance issue")
        validate_payload_principal(data["actor"], "acceptance actor")
        if data["result"] != "PASS":
            raise ValueError("acceptance result")
    elif event == "restackAuthorized":
        if set(data) != RESTACK_AUTHORIZED_DATA:
            raise ValueError("restackAuthorized data fields")
        for field in (
            "branch", "controllerPrincipalId", "operationId", "registryClaimPath", "worktreePath",
        ):
            nonempty_text(data[field], f"restackAuthorized {field}")
        valid_uuid(data["operationId"], "restackAuthorized operationId")
        if data["controllerPrincipalKind"] not in {"app", "human"}:
            raise ValueError("restackAuthorized controller principal kind")
        affected = data["affectedRelationIds"]
        if (
            not isinstance(affected, list)
            or not sorted_unique(affected)
            or any(not isinstance(value, str) or not value for value in affected)
        ):
            raise ValueError("restackAuthorized affected relations")
        git_oid(data["headCommitSha"], "restackAuthorized headCommitSha")
        timestamp(data["expiresAt"])
    elif event == "issueDone":
        if set(data) != {"mergeCommitSha", "pullRequestNumber"}:
            raise ValueError("issueDone data fields")
        git_oid(data["mergeCommitSha"], "issueDone mergeCommitSha")
        if type(data["pullRequestNumber"]) is not int or data["pullRequestNumber"] < 1:
            raise ValueError("issueDone pull request number")
    else:
        raise ValueError("unsupported issue event payload dispatch")


def validate_base(envelope, role):
    valid_uuid(envelope["clientId"], "clientId")
    if envelope["kind"] == "resource":
        expected = BASE_RESOURCE
    elif envelope["kind"] == "projectEvent":
        expected = PROJECT_EVENT
    elif envelope["kind"] == "issueEvent":
        expected = ISSUE_EVENT
    else:
        raise ValueError("unsupported managed kind")
    if not expected <= set(envelope):
        raise ValueError("partial managed envelope")
    if (envelope["schema"], envelope["label"], envelope["repository"], envelope["role"]) != (
        1, "woostack", repository, role,
    ):
        raise ValueError("managed identity mismatch")


def current_revisions(records, kind, role, native_field, native_id):
    grouped = defaultdict(list)
    native_ids = set()
    for record in records:
        if record.get("readComplete") is not True:
            raise ValueError("partial event read")
        if record["id"] in native_ids:
            raise ValueError("duplicate native event id")
        native_ids.add(record["id"])
        instant(record["createdAt"])
        envelope = record["envelope"]
        validate_base(envelope, role)
        if envelope["kind"] != kind or envelope[native_field] != native_id:
            raise ValueError("event resource mismatch")
        expected_envelope = PROJECT_EVENT if kind == "projectEvent" else ISSUE_EVENT
        if set(envelope) != expected_envelope:
            raise ValueError("managed event envelope fields")
        if not isinstance(envelope["revision"], int) or envelope["revision"] < 1:
            raise ValueError("invalid revision")
        if not sorted_unique(envelope["relatedIds"]):
            raise ValueError("relatedIds must be sorted and unique")
        if kind == "issueEvent":
            validate_issue_event_payload(record)
        grouped[envelope["clientId"]].append(record)
    current = []
    for revisions in grouped.values():
        revisions.sort(key=lambda item: item["envelope"]["revision"])
        if [item["envelope"]["revision"] for item in revisions] != list(range(1, len(revisions) + 1)):
            raise ValueError("gapped or duplicate revision")
        if len({item["envelope"]["event"] for item in revisions}) != 1:
            raise ValueError("event changed kind across correction")
        for index, item in enumerate(revisions):
            expected = None if index == 0 else revisions[index - 1]["id"]
            if item["envelope"]["supersedesId"] != expected:
                raise ValueError("broken supersession")
            if index and instant(revisions[index - 1]["createdAt"]) >= instant(item["createdAt"]):
                raise ValueError("revision timestamps are not strictly increasing")
        current.append(revisions[-1])
    return current


def validate_actor(actor, field):
    if (
        not isinstance(actor, dict)
        or set(actor) != {"kind", "principalId"}
        or actor["kind"] not in {"app", "human"}
        or not isinstance(actor["principalId"], str)
        or not actor["principalId"]
    ):
        raise ValueError(f"invalid {field}")
    return actor


def validate_project_resource(value):
    if value.get("readComplete") is not True:
        raise ValueError("partial project read")
    envelope = value["envelope"]
    if set(envelope) != BASE_RESOURCE:
        raise ValueError("project resource envelope fields")
    validate_base(envelope, "feature")
    if envelope["kind"] != "resource":
        raise ValueError("project is not a resource")
    if value["status"]["category"] not in {
        "backlog", "planned", "started", "completed", "canceled",
    }:
        raise ValueError("unknown native project category")
    validate_actor(value["lead"], "project lead")
    authority = value["leadAuthority"]
    if (
        not isinstance(authority, dict)
        or set(authority) != {"actor", "readAt", "readComplete"}
        or authority["readComplete"] is not True
        or validate_actor(authority["actor"], "fresh project lead") != value["lead"]
    ):
        raise ValueError("incomplete or mismatched pinned-lead authority")
    instant(authority["readAt"])
    if set(value["phaseAuthorities"]) != PHASES:
        raise ValueError("project phase authority set")
    for event, actor in value["phaseAuthorities"].items():
        validate_actor(actor, f"{event} authority")


def validate_phase(events):
    current = current_revisions(events, "projectEvent", "feature", "projectId", project_id)
    for record in current:
        if record["envelope"]["event"] not in PHASES | NON_PHASE:
            raise ValueError("unsupported project event")
    phase = [record for record in current if record["envelope"]["event"] in PHASES]
    increment_ids = sorted(issue["id"] for issue in project["issues"])
    for record in phase:
        event = record["envelope"]["event"]
        if set(record) != {"actor", "createdAt", "envelope", "id", "readComplete"}:
            raise ValueError("phase event readable fields")
        actor = validate_actor(record.get("actor"), f"{event} phase actor")
        if actor != project["phaseAuthorities"][event]:
            raise ValueError("project phase actor authority mismatch")
        if event in {"executionApproved", "executing", "inReview", "done"} and actor != project["lead"]:
            raise ValueError("lead-owned project phase actor mismatch")
        if event in {"designApproved", "specHardened"}:
            expected_relations = []
        elif event == "specApproved":
            expected_relations = [record["envelope"]["predecessorId"]]
        else:
            expected_relations = increment_ids
        if record["envelope"]["relatedIds"] != expected_relations:
            raise ValueError("project phase relations")
    by_id = {record["id"]: record for record in phase}
    starts = [
        record for record in phase
        if record["envelope"]["event"] == "designApproved"
        and record["envelope"]["predecessorId"] is None
    ]
    if len(starts) != 1:
        raise ValueError("invalid phase root")
    for record in phase:
        if record is starts[0]:
            continue
        predecessor = by_id.get(record["envelope"]["predecessorId"])
        if predecessor is None:
            raise ValueError("missing current predecessor")
        previous = predecessor["envelope"]["event"]
        event = record["envelope"]["event"]
        if event == "abandoned":
            if previous in {"done", "abandoned"}:
                raise ValueError("illegal abandonment")
        elif previous == "ready" and event == "planning":
            raise ValueError("fixture omitted required evidence-free replan proof")
        elif NEXT_PHASE.get(previous) != event:
            raise ValueError("illegal phase transition")
    referenced = {
        record["envelope"]["predecessorId"]
        for record in phase if record["envelope"]["predecessorId"]
    }
    heads = [record for record in phase if record["id"] not in referenced]
    if len(heads) != 1:
        raise ValueError("multiple current phase heads")
    cursor = heads[0]
    visited = set()
    depth = {}
    chain = []
    while cursor is not None:
        if cursor["id"] in visited:
            raise ValueError("phase cycle")
        visited.add(cursor["id"])
        chain.append(cursor)
        predecessor_id = cursor["envelope"]["predecessorId"]
        cursor = by_id.get(predecessor_id) if predecessor_id else None
    if visited != set(by_id):
        raise ValueError("disconnected phase chain")
    for index, record in enumerate(reversed(chain)):
        depth[record["id"]] = index
    for record in current:
        if record["envelope"]["event"] not in NON_PHASE:
            continue
        predecessor = by_id.get(record["envelope"]["predecessorId"])
        if predecessor is None:
            raise ValueError("non-phase context is not a current phase")
        created = instant(record["createdAt"])
        if instant(predecessor["createdAt"]) > created or any(
            depth[candidate["id"]] > depth[predecessor["id"]]
            and instant(candidate["createdAt"]) <= created
            for candidate in phase
        ):
            raise ValueError("non-phase predecessor was not current when authored")
    return heads[0]["envelope"]["event"], current


def unresolved_project_blockers(current):
    opens = {record["id"]: record for record in current if record["envelope"]["event"] == "blockerOpened"}
    resolutions = defaultdict(list)
    for record in current:
        if record["envelope"]["event"] != "blockerResolved":
            continue
        matches = [native_id for native_id in record["envelope"]["relatedIds"] if native_id in opens]
        if len(matches) != 1:
            raise ValueError("ambiguous blocker resolution")
        resolutions[matches[0]].append(record["id"])
    if any(len(values) != 1 for values in resolutions.values()):
        raise ValueError("multiply resolved blocker")
    return sorted(set(opens) - set(resolutions))


validate_project_resource(project)
phase, project_current = validate_phase(project["events"])
if phase != expected["projectPhase"]:
    fail(f"fixture phase derived as {phase!r}")
if project["status"]["category"] != expected["projectNativeCategory"]:
    fail("project native category expectation mismatch")


SINGLETON_ISSUE_EVENTS = {
    "verification", "precommitReview", "implementationEvidence", "acceptance", "issueDone",
}
SUCCESSIVE_ISSUE_EVENTS = {"assignmentAccepted", "handoff", "blocked", "unblocked"}


def issue_event_by_native_id(issue, native_id):
    matches = [record for record in issue["events"] if record["id"] == native_id]
    if len(matches) != 1:
        raise ValueError("missing or duplicate exact native issue event")
    return matches[0]


def native_revision_current_at(issue, native_id, at):
    record = issue_event_by_native_id(issue, native_id)
    if instant(record["createdAt"]) > at:
        raise ValueError("related native revision did not exist at evidence time")
    client_id = record["envelope"]["clientId"]
    revisions = sorted(
        [
            candidate for candidate in issue["events"]
            if candidate["envelope"]["clientId"] == client_id
        ],
        key=lambda candidate: candidate["envelope"]["revision"],
    )
    eligible = [candidate for candidate in revisions if instant(candidate["createdAt"]) <= at]
    if not eligible or eligible[-1]["id"] != native_id:
        raise ValueError("related native revision was not current at evidence time")
    return record


def current_issue_records_at(issue, at, event=None, inclusive=True):
    records = [
        record for record in issue["events"]
        if (event is None or record["envelope"]["event"] == event)
        and (
            instant(record["createdAt"]) <= at
            if inclusive else instant(record["createdAt"]) < at
        )
    ]
    by_client = defaultdict(list)
    for record in records:
        by_client[record["envelope"]["clientId"]].append(record)
    return [
        max(revisions, key=lambda record: record["envelope"]["revision"])
        for revisions in by_client.values()
    ]


def issue_event_current_at(issue, event, at, inclusive=True):
    selected = current_issue_records_at(issue, at, event, inclusive)
    if not selected:
        raise ValueError(f"{event} has no revision at evidence time")
    selected.sort(key=lambda record: instant(record["createdAt"]))
    if (
        len(selected) > 1
        and instant(selected[-2]["createdAt"]) == instant(selected[-1]["createdAt"])
    ):
        raise ValueError(f"{event} has ambiguous successive families at evidence time")
    return selected[-1]


def validate_successive_event_families(issue, event):
    grouped = defaultdict(list)
    for record in issue["events"]:
        if record["envelope"]["event"] == event:
            grouped[record["envelope"]["clientId"]].append(record)
    ordered = sorted(
        grouped.values(),
        key=lambda family: min(instant(record["createdAt"]) for record in family),
    )
    for previous, successor in zip(ordered, ordered[1:]):
        if max(instant(record["createdAt"]) for record in previous) >= min(
            instant(record["createdAt"]) for record in successor
        ):
            raise ValueError(f"interleaved stable {event} event families")


def open_block_at(issue, at):
    blocks = current_issue_records_at(issue, at, "blocked", inclusive=False)
    unblocks = current_issue_records_at(issue, at, "unblocked", inclusive=False)
    resolved_ids = [record["data"]["blockedEventId"] for record in unblocks]
    if len(resolved_ids) != len(set(resolved_ids)):
        raise ValueError("one blocked event was resolved more than once")
    open_blocks = [record for record in blocks if record["id"] not in resolved_ids]
    if len(open_blocks) != 1:
        raise ValueError("unblocked event does not follow one exact open blocker")
    return open_blocks[0]


def expected_project_relation(role):
    return [project_id] if role == "increment" else []



def stable_family_start(issue, record):
    client_id = record["envelope"]["clientId"]
    return min(
        instant(candidate["createdAt"])
        for candidate in issue["events"]
        if candidate["envelope"]["clientId"] == client_id
    )


def issue_payload_owner(data):
    return {"kind": data["ownerKind"], "principalId": data["ownerPrincipalId"]}


def expected_controller(data):
    return {
        "kind": data["controllerPrincipalKind"],
        "principalId": data["controllerPrincipalId"],
    }


def validate_review_round_families(issue):
    grouped = defaultdict(list)
    for record in issue["events"]:
        if record["envelope"]["event"] == "reviewResult":
            grouped[record["envelope"]["clientId"]].append(record)
    families = []
    for revisions in grouped.values():
        rounds = {record["data"]["round"] for record in revisions}
        if len(rounds) != 1:
            raise ValueError("one reviewResult family changed full-review round")
        families.append(max(
            revisions, key=lambda record: record["envelope"]["revision"],
        ))
    families.sort(key=lambda record: instant(record["createdAt"]))
    rounds = [record["data"]["round"] for record in families]
    if rounds != list(range(1, len(rounds) + 1)):
        raise ValueError("reviewResult rounds are duplicate, gapped, or non-monotonic")
    return families


def validate_issue_event_dispatch(issue, role):
    records = issue["events"]
    record_ids = {record["id"] for record in records}
    if len(record_ids) != len(records):
        raise ValueError("duplicate native issue event")
    for event in SINGLETON_ISSUE_EVENTS:
        client_ids = {
            record["envelope"]["clientId"]
            for record in records
            if record["envelope"]["event"] == event
        }
        if len(client_ids) > 1:
            raise ValueError(f"multiple stable {event} event families")
    for event in SUCCESSIVE_ISSUE_EVENTS:
        validate_successive_event_families(issue, event)
    validate_review_round_families(issue)
    observed = set()
    for record in records:
        if set(record) != {"actor", "createdAt", "data", "envelope", "id", "readComplete"}:
            raise ValueError("issue event readable fields")
        event = record["envelope"]["event"]
        observed.add(event)
        if event not in ISSUE_EVENTS:
            raise ValueError("unsupported issue event dispatch")
        actor = validate_actor(record["actor"], f"{event} issue actor")
        at = instant(record["createdAt"])
        related = record["envelope"]["relatedIds"]
        data = record["data"]
        if event == "assignmentAccepted":
            owner = issue_payload_owner(data)
            if data["issueId"] != issue["id"] or actor != owner:
                raise ValueError("assignmentAccepted actor is not its type-aware owner")
            started_at = stable_family_start(issue, record)
            earlier_assignments = current_issue_records_at(
                issue, started_at, "assignmentAccepted", inclusive=False,
            )
            if not earlier_assignments:
                if related:
                    raise ValueError("initial assignmentAccepted relations must be empty")
            else:
                handoff = issue_event_current_at(
                    issue, "handoff", started_at, inclusive=False,
                )
                if (
                    related != [handoff["id"]]
                    or issue_payload_owner(handoff["data"]) != owner
                    or handoff["data"]["runId"] != data["runId"]
                ):
                    raise ValueError("successor assignmentAccepted handoff relation")
                native_revision_current_at(issue, handoff["id"], started_at)
        elif event == "verification":
            assignment = issue_event_current_at(issue, "assignmentAccepted", at)
            authorization_ids = [
                native_id for native_id in related
                if native_id in record_ids
                and issue_event_by_native_id(issue, native_id)["envelope"]["event"]
                == "restackAuthorized"
            ]
            if len(authorization_ids) > 1:
                raise ValueError("verification has competing authorizations")
            expected = sorted([
                assignment["id"], *expected_project_relation(role),
                *authorization_ids,
            ])
            if authorization_ids:
                authorization = native_revision_current_at(
                    issue, authorization_ids[0], at,
                )
                expected_actor = expected_controller(authorization["data"])
                if not (
                    instant(authorization["createdAt"])
                    < at
                    <= timestamp(authorization["data"]["expiresAt"])
                ):
                    raise ValueError("verification authorization window")
            else:
                expected_actor = assignment["actor"]
            if (
                actor != expected_actor
                or payload_as_native_actor(data["actor"], "verification actor") != actor
                or data["issueId"] != issue["id"]
                or related != expected
                or instant(assignment["createdAt"]) >= at
            ):
                raise ValueError("verification actor, issue, order, or relations")
        elif event == "precommitReview":
            assignment = issue_event_current_at(issue, "assignmentAccepted", at)
            verification = issue_event_current_at(issue, "verification", at)
            authorization_ids = [
                native_id for native_id in related
                if native_id in record_ids
                and issue_event_by_native_id(issue, native_id)["envelope"]["event"]
                == "restackAuthorized"
            ]
            expected = sorted([
                assignment["id"], verification["id"], *expected_project_relation(role),
                *authorization_ids,
            ])
            if len(authorization_ids) > 1:
                raise ValueError("precommitReview has competing authorizations")
            if authorization_ids:
                authorization = native_revision_current_at(issue, authorization_ids[0], at)
                expected_actor = expected_controller(authorization["data"])
                if not (
                    instant(authorization["createdAt"])
                    < at
                    <= timestamp(authorization["data"]["expiresAt"])
                ):
                    raise ValueError("precommitReview authorization window")
            else:
                expected_actor = assignment["actor"]
            payload_actor = payload_as_native_actor(
                data["actor"], "precommitReview actor",
            )
            if (
                related != expected
                or actor != expected_actor
                or payload_actor != actor
                or data["issueId"] != issue["id"]
                or data["changedPaths"] != verification["data"]["changedPaths"]
                or instant(verification["createdAt"]) >= at
            ):
                raise ValueError("precommitReview actor, issue, paths, order, or relations")
        elif event == "implementationEvidence":
            assignment = issue_event_current_at(issue, "assignmentAccepted", at)
            verification = issue_event_current_at(issue, "verification", at)
            precommit_review = issue_event_current_at(issue, "precommitReview", at)
            authorization_ids = [
                native_id for native_id in related
                if native_id in record_ids
                and issue_event_by_native_id(issue, native_id)["envelope"]["event"]
                == "restackAuthorized"
            ]
            expected = sorted([
                assignment["id"], verification["id"], precommit_review["id"],
                *expected_project_relation(role), *authorization_ids,
            ])
            if len(authorization_ids) > 1:
                raise ValueError("implementationEvidence has competing authorizations")
            if authorization_ids:
                authorization = native_revision_current_at(issue, authorization_ids[0], at)
                expected_actor = expected_controller(authorization["data"])
                if not (
                    instant(authorization["createdAt"])
                    < at
                    <= timestamp(authorization["data"]["expiresAt"])
                ):
                    raise ValueError("implementationEvidence authorization window")
            else:
                expected_actor = assignment["actor"]
            if (
                related != expected
                or actor != expected_actor
                or actor["kind"] not in {"app", "human"}
                or data["committedDiffHash"] != precommit_review["data"]["reviewedDiffHash"]
                or precommit_review["data"]["changedPaths"] != verification["data"]["changedPaths"]
                or instant(precommit_review["createdAt"]) >= at
            ):
                raise ValueError("implementationEvidence actor, review, order, or relations")
        elif event == "decisionRequest":
            assignment = issue_event_current_at(issue, "assignmentAccepted", at)
            expected = sorted([assignment["id"], *data["affectedIds"]])
            if (
                actor != assignment["actor"]
                or data["issueId"] != issue["id"]
                or related != expected
                or instant(assignment["createdAt"]) >= at
            ):
                raise ValueError("decisionRequest actor, issue, order, or relations")
            for native_id in data["affectedIds"]:
                if native_id in record_ids:
                    native_revision_current_at(issue, native_id, at)
        elif event == "decisionResponse":
            if related != [data["decisionRequestId"]]:
                raise ValueError("decisionResponse relation")
            request = native_revision_current_at(issue, data["decisionRequestId"], at)
            responses = [
                candidate for candidate in current_issue_records_at(
                    issue, at, "decisionResponse",
                )
                if candidate["data"]["decisionRequestId"] == data["decisionRequestId"]
            ]
            if (
                request["envelope"]["event"] != "decisionRequest"
                or data["issueId"] != issue["id"]
                or instant(request["createdAt"]) >= at
                or len(responses) != 1
                or actor != {
                    "kind": request["data"]["requestedAuthorityKind"],
                    "principalId": request["data"]["requestedAuthorityPrincipalId"],
                }
            ):
                raise ValueError("decisionResponse actor, issue, order, uniqueness, or relation")
        elif event in {"failure", "blocked"}:
            assignment = issue_event_current_at(issue, "assignmentAccepted", at)
            authorization_ids = [
                native_id for native_id in related
                if native_id in record_ids
                and issue_event_by_native_id(issue, native_id)["envelope"]["event"]
                == "restackAuthorized"
            ]
            if len(authorization_ids) > 1:
                raise ValueError(f"{event} has competing bounded authorizations")
            expected_actor = assignment["actor"]
            if authorization_ids:
                authorization = native_revision_current_at(issue, authorization_ids[0], at)
                expected_actor = expected_controller(authorization["data"])
                if not (
                    instant(authorization["createdAt"])
                    < at
                    <= timestamp(authorization["data"]["expiresAt"])
                ):
                    raise ValueError(f"{event} authorization window")
            expected = sorted([
                assignment["id"], *data["affectedIds"], *authorization_ids,
            ])
            if (
                actor != expected_actor
                or data["issueId"] != issue["id"]
                or related != expected
                or instant(assignment["createdAt"]) >= at
            ):
                raise ValueError(f"{event} actor, issue, order, or relations")
            for native_id in data["affectedIds"]:
                if native_id in record_ids:
                    native_revision_current_at(issue, native_id, at)
        elif event == "handoff":
            started_at = stable_family_start(issue, record)
            assignment = issue_event_current_at(
                issue, "assignmentAccepted", started_at, inclusive=False,
            )
            incoming_owner = issue_payload_owner(data)
            expected = sorted([assignment["id"], *data["recoveryEvidenceIds"]])
            if (
                actor != assignment["actor"]
                or incoming_owner == actor
                or data["issueId"] != issue["id"]
                or related != expected
                or instant(assignment["createdAt"]) >= started_at
            ):
                raise ValueError("handoff actor, owner, issue, order, or relations")
            for native_id in data["recoveryEvidenceIds"]:
                if native_id in record_ids:
                    native_revision_current_at(issue, native_id, started_at)
        elif event == "unblocked":
            assignment = issue_event_current_at(issue, "assignmentAccepted", at)
            blocked = open_block_at(issue, at)
            expected = sorted([
                blocked["id"], *data["resolutionEvidenceIds"],
            ])
            if (
                actor != assignment["actor"]
                or data["issueId"] != issue["id"]
                or data["blockedEventId"] != blocked["id"]
                or data["restoredState"] != blocked["data"]["previousState"]
                or related != expected
                or instant(blocked["createdAt"]) >= at
            ):
                raise ValueError("unblocked actor, issue, state, order, or relations")
            native_revision_current_at(issue, blocked["id"], at)
        elif event == "reviewResult":
            implementation = issue_event_current_at(
                issue, "implementationEvidence", at,
            )
            verification = issue_event_current_at(issue, "verification", at)
            relation = resolve_linear_pr_relation(
                issue, data["pullRequestNumber"], data["pullRequestUrl"], at=at,
            )
            expected = sorted([
                implementation["id"], verification["id"], relation["id"],
                data["githubReviewId"],
            ])
            matching_receipts = [
                receipt for receipt in fixture["github"]["reviews"]
                if receipt["id"] == data["githubReviewId"]
            ]
            receipt = matching_receipts[0] if len(matching_receipts) == 1 else None
            if (
                receipt is None
                or actor != receipt["reviewer"]
                or data["issueId"] != issue["id"]
                or related != expected
                or instant(receipt["submittedAt"]) > at
                or instant(implementation["createdAt"]) >= at
                or any(
                    native_id in related
                    for native_id in record_ids
                    if issue_event_by_native_id(issue, native_id)["envelope"]["event"]
                    == "precommitReview"
                )
            ):
                raise ValueError("reviewResult is not exact post-PR evidence")
        elif event == "acceptance":
            implementation = issue_event_current_at(issue, "implementationEvidence", at)
            verification = issue_event_current_at(issue, "verification", at)
            review = issue_event_current_at(issue, "reviewResult", at)
            payload_actor = payload_as_native_actor(
                data["actor"], "acceptance actor",
            )
            if (
                actor != issue["acceptanceAuthority"]
                or payload_actor != actor
                or data["issueId"] != issue["id"]
                or data["result"] != "PASS"
                or actor == implementation["actor"]
                or actor == review["actor"]
                or related != sorted([implementation["id"], verification["id"], review["id"]])
            ):
                raise ValueError("acceptance actor, issue, result, or relations")
        elif event == "restackAuthorized":
            assignment = issue_event_current_at(issue, "assignmentAccepted", at)
            implementation = issue_event_current_at(
                issue, "implementationEvidence", at,
            )
            relation = resolve_linear_pr_relation(
                issue, issue["pullRequestNumber"],
                f"{repository}/pull/{issue['pullRequestNumber']}",
                branch=data["branch"], at=at,
            )
            expected = sorted([
                assignment["id"], implementation["id"], relation["id"],
                *data["affectedRelationIds"],
            ])
            if (
                actor != assignment["actor"]
                or related != expected
                or data["headCommitSha"] != implementation["data"]["headCommitSha"]
                or at >= timestamp(data["expiresAt"])
            ):
                raise ValueError("restackAuthorized actor, head, expiry, or relations")
            native_revision_current_at(issue, implementation["id"], at)
            for native_id in implementation["envelope"]["relatedIds"]:
                if native_id in record_ids:
                    native_revision_current_at(issue, native_id, at)
        elif event == "issueDone":
            acceptance = issue_event_current_at(issue, "acceptance", at)
            implementation = issue_event_current_at(
                issue, "implementationEvidence", at,
            )
            verification = issue_event_current_at(issue, "verification", at)
            review = issue_event_current_at(issue, "reviewResult", at)
            relation = resolve_linear_pr_relation(
                issue, data["pullRequestNumber"],
                f"{repository}/pull/{data['pullRequestNumber']}", at=at,
            )
            expected = sorted([
                acceptance["id"], implementation["id"], verification["id"],
                review["id"], relation["id"],
            ])
            if actor != issue["acceptanceAuthority"] or related != expected:
                raise ValueError("issueDone actor or relations")
        else:
            raise ValueError("incomplete issue event dispatch")
    latest_assignment = issue_event_current_at(
        issue, "assignmentAccepted", max(instant(record["createdAt"]) for record in records),
    )
    handoffs = current_issue_records_at(
        issue, max(instant(record["createdAt"]) for record in records), "handoff",
    )
    latest_handoff = (
        max(handoffs, key=lambda record: instant(record["createdAt"]))
        if handoffs else None
    )
    current_owner = issue_payload_owner(latest_assignment["data"])
    if (
        latest_handoff is not None
        and instant(latest_handoff["createdAt"]) > instant(latest_assignment["createdAt"])
    ):
        current_owner = issue_payload_owner(latest_handoff["data"])
    if current_owner != issue["owner"]:
        raise ValueError("current type-aware owner conflicts with assignment/handoff history")
    return observed


observed_issue_event_kinds = set()


def validate_issue_resource(issue, role):
    if issue.get("readComplete") is not True:
        raise ValueError("partial issue read")
    envelope = issue["envelope"]
    expected = set(BASE_RESOURCE)
    if role == "increment":
        expected |= {"dependencyIds", "ordinal", "projectId"}
    if set(envelope) != expected:
        raise ValueError("issue resource envelope fields")
    validate_base(envelope, role)
    if envelope["kind"] != "resource":
        raise ValueError("issue is not a resource")
    if role == "increment":
        if envelope["projectId"] != project_id or not isinstance(envelope["ordinal"], int) or envelope["ordinal"] < 1:
            raise ValueError("increment project/ordinal mismatch")
        if not sorted_unique(envelope["dependencyIds"]):
            raise ValueError("invalid dependency IDs")
    else:
        if issue.get("projectMembership") is not None or "projectId" in envelope:
            raise ValueError("synthetic standalone project")
    owner = validate_actor(issue["owner"], "type-aware issue owner")
    if owner["kind"] == "human":
        if issue["assigneeId"] != owner["principalId"] or issue["delegateId"] is not None:
            raise ValueError("human owner mismatch")
    elif owner["kind"] == "app":
        if issue["delegateId"] != owner["principalId"]:
            raise ValueError("app delegate mismatch")
    else:
        raise ValueError("unknown owner kind")
    authority = validate_actor(
        issue["acceptanceAuthority"], "type-aware acceptance authority",
    )
    current = current_revisions(issue["events"], "issueEvent", role, "issueId", issue["id"])
    observed_issue_event_kinds.update(validate_issue_event_dispatch(issue, role))
    return current


increments = project["issues"]
standalone = fixture["standaloneIssues"]
if not increments:
    fail("feature fixture must contain managed increments")
all_issues = increments + standalone
if len({issue["id"] for issue in all_issues}) != len(all_issues):
    fail("duplicate native issue IDs")
if set(project["events"][3]["envelope"]["relatedIds"]) != {issue["id"] for issue in increments}:
    fail("planning event does not name the complete increment set")

expected_relation_issue_ids = {
    issue["id"] for issue in all_issues
    if issue["pullRequestNumber"] is not None
}
if (
    {record["issueId"] for record in linear_pr_relation_records}
    != expected_relation_issue_ids
    or len(linear_pr_relation_records) != len(expected_relation_issue_ids)
    or sorted(record["id"] for record in linear_pr_relation_records)
    != expected["linearPrRelationIds"]
):
    fail("native Linear PR relation universe drift")
current_events = {}
decision_issue = next(issue for issue in increments if issue["id"] == "issue-app-14")
foreign_response = copy.deepcopy(decision_issue)
next(
    event for event in foreign_response["events"]
    if event["id"] == "comment-app14-decision-response"
)["actor"]["principalId"] = "user-foreign"
rejects(
    "decision response from foreign authority",
    lambda: validate_issue_event_dispatch(foreign_response, "increment"),
)
misrelated_response = copy.deepcopy(decision_issue)
next(
    event for event in misrelated_response["events"]
    if event["id"] == "comment-app14-decision-response"
)["envelope"]["relatedIds"] = ["comment-app14-assignment"]
rejects(
    "decision response without exact request relation",
    lambda: validate_issue_event_dispatch(misrelated_response, "increment"),
)
duplicate_response = copy.deepcopy(decision_issue)
second_response = copy.deepcopy(next(
    event for event in duplicate_response["events"]
    if event["id"] == "comment-app14-decision-response"
))
second_response["id"] = "comment-app14-decision-response-duplicate"
second_response["createdAt"] = "2026-07-24T10:30:00Z"
second_response["envelope"]["clientId"] = "deadbeef-dead-4eef-8ead-deadbeef0002"
duplicate_response["events"].append(second_response)
rejects(
    "multiple current responses to one decision request",
    lambda: validate_issue_event_dispatch(duplicate_response, "increment"),
)
for issue in increments:
    current_events[issue["id"]] = validate_issue_resource(issue, "increment")
for issue in standalone:
    current_events[issue["id"]] = validate_issue_resource(issue, "work-item")
if sorted(observed_issue_event_kinds) != expected["issueEventKinds"]:
    fail("canonical issue event dispatch set drift")

successive_issue = increments[2]
for fixture_field, event_kind in (
    ("successiveAssignmentEventIds", "assignmentAccepted"),
    ("successiveHandoffEventIds", "handoff"),
    ("successiveBlockedEventIds", "blocked"),
    ("successiveUnblockedEventIds", "unblocked"),
):
    observed_ids = [
        event["id"] for event in successive_issue["events"]
        if event["envelope"]["event"] == event_kind
    ]
    if observed_ids != expected[fixture_field]:
        fail(f"successive stable {event_kind} families were not preserved")

initial_assignment_relation = copy.deepcopy(successive_issue)
next(
    event for event in initial_assignment_relation["events"]
    if event["id"] == "comment-app14-assignment"
)["envelope"]["relatedIds"] = ["issue-app-13"]
rejects(
    "initial assignmentAccepted related a dependency",
    lambda: validate_issue_resource(initial_assignment_relation, "increment"),
)

successor_assignment_relation = copy.deepcopy(successive_issue)
next(
    event for event in successor_assignment_relation["events"]
    if event["id"] == "comment-app14-assignment-app"
)["envelope"]["relatedIds"] = ["project-native-launch"]
rejects(
    "successor assignmentAccepted did not relate the exact preceding handoff",
    lambda: validate_issue_resource(successor_assignment_relation, "increment"),
)

wrong_assignment_owner = copy.deepcopy(successive_issue)
next(
    event for event in wrong_assignment_owner["events"]
    if event["id"] == "comment-app14-assignment-app"
)["data"]["ownerPrincipalId"] = "app-foreign-engineer"
rejects(
    "assignmentAccepted payload owner did not match its type-aware actor",
    lambda: validate_issue_resource(wrong_assignment_owner, "increment"),
)

gapped_assignment_family = copy.deepcopy(successive_issue)
next(
    event for event in gapped_assignment_family["events"]
    if event["id"] == "comment-app14-assignment-app"
)["envelope"]["revision"] = 2
rejects(
    "successive assignment family bypassed revision one",
    lambda: validate_issue_resource(gapped_assignment_family, "increment"),
)

non_temporal_successor = copy.deepcopy(successive_issue)
next(
    event for event in non_temporal_successor["events"]
    if event["id"] == "comment-app14-handoff-app"
)["createdAt"] = "2026-07-25T11:08:00Z"
rejects(
    "successor assignment preceded its authoritative handoff time",
    lambda: validate_issue_resource(non_temporal_successor, "increment"),
)


issue_by_id = {issue["id"]: issue for issue in all_issues}


def current_issue_evidence_at(issue_id, at, kinds=None):
    candidates = current_issue_records_at(
        issue_by_id[issue_id], at, inclusive=False,
    )
    if kinds is not None:
        candidates = [
            record for record in candidates
            if record["envelope"]["event"] in kinds
        ]
    if not candidates:
        raise ValueError("issue lacks current evidence at project event time")
    candidates.sort(key=lambda record: instant(record["createdAt"]))
    if (
        len(candidates) > 1
        and instant(candidates[-2]["createdAt"]) == instant(candidates[-1]["createdAt"])
    ):
        raise ValueError("issue has ambiguous current evidence at project event time")
    return candidates[-1]


def validate_affected_scope(
    affected_issue_ids, affected_relation_ids, relation_rewrite=False,
):
    if (
        not isinstance(affected_issue_ids, list)
        or not affected_issue_ids
        or not sorted_unique(affected_issue_ids)
        or any(not isinstance(value, str) or not value for value in affected_issue_ids)
        or not isinstance(affected_relation_ids, list)
        or not sorted_unique(affected_relation_ids)
        or any(not isinstance(value, str) or not value for value in affected_relation_ids)
        or ((len(affected_issue_ids) > 1 or relation_rewrite) and not affected_relation_ids)
    ):
        raise ValueError("invalid affected issue/relation scope")


def validate_project_event_dispatch(current):
    phase_ids = {
        record["id"] for record in current
        if record["envelope"]["event"] in PHASES
    }
    increment_id_set = {issue["id"] for issue in increments}
    opens = {
        record["id"]: record for record in current
        if record["envelope"]["event"] == "blockerOpened"
    }
    observed_kinds = sorted({record["envelope"]["event"] for record in current})
    lead_events = {
        "decision", "progress", "blockerOpened", "blockerResolved", "handoff",
        "executionApproved", "executing", "inReview", "done",
    }
    observed_lead_kinds = set()
    consumed_decision_ids = []
    inactive_decision_ids = []
    empty_relation_decision_ids = []
    for record in current:
        event = record["envelope"]["event"]
        envelope = record["envelope"]
        actor = validate_actor(record.get("actor"), f"{event} project actor")
        base_fields = {"actor", "createdAt", "envelope", "id", "readComplete"}
        expected_fields = base_fields | ({"data"} if event == "decision" else set())
        if set(record) != expected_fields or record["readComplete"] is not True:
            raise ValueError("project event readable fields")
        if event in lead_events:
            observed_lead_kinds.add(event)
            if actor != project["leadAuthority"]["actor"]:
                raise ValueError("fresh pinned lead project actor mismatch")
        if event in PHASES:
            continue
        if envelope["predecessorId"] not in phase_ids:
            raise ValueError("project event lacks current phase predecessor")
        related = envelope["relatedIds"]
        if event == "progress":
            affected = [native_id for native_id in related if native_id in increment_id_set]
            if not affected:
                raise ValueError("progress lacks affected issue")
            evidence = [
                current_issue_evidence_at(issue_id, instant(record["createdAt"]))["id"]
                for issue_id in affected
            ]
            if related != sorted(affected + evidence):
                raise ValueError("progress relations")
        elif event == "blockerOpened":
            affected = [native_id for native_id in related if native_id in increment_id_set]
            evidence = [
                current_issue_evidence_at(
                    issue_id, instant(record["createdAt"]), {"blocked", "failure"},
                )["id"]
                for issue_id in affected
            ]
            if not affected or related != sorted(affected + evidence):
                raise ValueError("blockerOpened relations")
        elif event == "blockerResolved":
            matching_opens = [native_id for native_id in related if native_id in opens]
            if len(matching_opens) != 1:
                raise ValueError("blockerResolved open blocker relation")
            opened = opens[matching_opens[0]]
            prior_resolutions = [
                candidate for candidate in current
                if candidate["envelope"]["event"] == "blockerResolved"
                and candidate["id"] != record["id"]
                and matching_opens[0] in candidate["envelope"]["relatedIds"]
                and instant(candidate["createdAt"]) < instant(record["createdAt"])
            ]
            if prior_resolutions:
                raise ValueError("blockerResolved does not name an open blocker")
            affected = [
                native_id for native_id in opened["envelope"]["relatedIds"]
                if native_id in increment_id_set
            ]
            if len(affected) != 1:
                raise ValueError("blockerResolved cannot derive one affected issue from opener")
            issue = issue_by_id[affected[0]]
            issue_event_ids = {candidate["id"] for candidate in issue["events"]}
            blocked_ids = [
                native_id for native_id in opened["envelope"]["relatedIds"]
                if native_id in issue_event_ids
                and issue_event_by_native_id(issue, native_id)["envelope"]["event"] == "blocked"
            ]
            if len(blocked_ids) != 1:
                raise ValueError("blockerOpened lacks one exact blocked issue event")
            blocked = native_revision_current_at(
                issue, blocked_ids[0], instant(opened["createdAt"]),
            )
            unblocks = [
                candidate for candidate in current_issue_records_at(
                    issue, instant(record["createdAt"]), "unblocked",
                )
                if candidate["data"]["blockedEventId"] == blocked["id"]
                and instant(opened["createdAt"])
                < instant(candidate["createdAt"])
                <= instant(record["createdAt"])
            ]
            if len(unblocks) != 1:
                raise ValueError("blockerResolved lacks exact unblocked evidence")
            unblocked = unblocks[0]
            if (
                unblocked["data"]["restoredState"] != blocked["data"]["previousState"]
                or unblocked["data"]["restoredState"] != issue["state"]
            ):
                raise ValueError("blockerResolved restoration state mismatch")
            expected = sorted([matching_opens[0], unblocked["id"]])
            if related != expected:
                raise ValueError("blockerResolved resolution relations")
        elif event == "handoff":
            expected = []
            for issue in increments:
                handoffs = current_issue_records_at(
                    issue, instant(record["createdAt"]), "handoff", inclusive=False,
                )
                if handoffs:
                    expected.append(
                        max(handoffs, key=lambda item: instant(item["createdAt"]))["id"]
                    )
            if not expected or related != sorted(expected):
                raise ValueError("project handoff relations")
        elif event == "decision":
            data = record["data"]
            if set(data) != RESTACK_DECISION_DATA:
                raise ValueError("restack decision data fields")
            valid_uuid(data["operationId"], "project decision operationId")
            if data["controllerPrincipalKind"] not in {"app", "human"}:
                raise ValueError("project decision controller kind")
            for field in ("controllerPrincipalId", "expiresAt"):
                nonempty_text(data[field], f"project decision {field}")
            validate_affected_scope(
                data["affectedIssueIds"], data["affectedRelationIds"],
            )
            if not set(data["affectedIssueIds"]) <= increment_id_set:
                raise ValueError("project decision foreign issue")
            authorizations = []
            completion_times = []
            for issue_id in data["affectedIssueIds"]:
                candidates = [
                    authorization
                    for authorization in current_events[issue_id]
                    if authorization["envelope"]["event"] == "restackAuthorized"
                    and authorization["data"]["operationId"] == data["operationId"]
                    and authorization["data"]["controllerPrincipalKind"]
                    == data["controllerPrincipalKind"]
                    and authorization["data"]["controllerPrincipalId"]
                    == data["controllerPrincipalId"]
                    and authorization["data"]["affectedRelationIds"]
                    == data["affectedRelationIds"]
                    and authorization["data"]["expiresAt"] == data["expiresAt"]
                ]
                if len(candidates) != 1:
                    raise ValueError("project decision lacks exact issue authorization")
                authorization = candidates[0]
                if not (
                    instant(authorization["createdAt"])
                    <= instant(record["createdAt"])
                    < timestamp(data["expiresAt"])
                ):
                    raise ValueError("project/issue restack decision temporal mismatch")
                consumers = [
                    implementation
                    for implementation in issue_by_id[issue_id]["events"]
                    if implementation["envelope"]["event"] == "implementationEvidence"
                    and authorization["id"] in implementation["envelope"]["relatedIds"]
                ]
                if len(consumers) > 1:
                    raise ValueError("project decision has competing completions")
                if consumers:
                    completion = instant(consumers[0]["createdAt"])
                    if not (
                        instant(authorization["createdAt"])
                        < completion
                        <= timestamp(data["expiresAt"])
                        and instant(record["createdAt"]) < completion
                    ):
                        raise ValueError("project decision completion outside authorization window")
                    completion_times.append(completion)
                authorizations.append(authorization["id"])
            if related != sorted(
                authorizations + data["affectedIssueIds"] + data["affectedRelationIds"]
            ):
                raise ValueError("restack decision relations")
            if completion_times:
                if len(completion_times) != len(authorizations):
                    raise ValueError("partially consumed project decision")
                consumed_decision_ids.append(record["id"])
            elif timestamp(data["expiresAt"]) <= now:
                inactive_decision_ids.append(record["id"])
            if not data["affectedRelationIds"]:
                empty_relation_decision_ids.append(record["id"])
        else:
            raise ValueError("unsupported project event dispatch")
    return {
        "eventKinds": observed_kinds,
        "leadOwnedEventKinds": sorted(observed_lead_kinds),
        "consumedDecisionIds": sorted(consumed_decision_ids),
        "inactiveDecisionIds": sorted(inactive_decision_ids),
        "emptyRelationDecisionIds": sorted(empty_relation_decision_ids),
    }


project_dispatch = validate_project_event_dispatch(project_current)
if (
    project_dispatch["eventKinds"] != expected["projectEventKinds"]
    or project_dispatch["leadOwnedEventKinds"] != expected["leadOwnedProjectEventKinds"]
    or project_dispatch["consumedDecisionIds"]
    != expected["consumedProjectDecisionEventIds"]
    or project_dispatch["inactiveDecisionIds"]
    != expected["inactiveProjectDecisionEventIds"]
    or project_dispatch["emptyRelationDecisionIds"]
    != expected["emptyAffectedDecisionEventIds"]
):
    fail("canonical project event dispatch set drift")
if unresolved_project_blockers(project_current):
    fail("resolved project blocker remained open")
if {issue["identifier"] for issue in standalone} != set(expected["standaloneIssueIdentifiers"]):
    fail("standalone fixture set mismatch")
if any("projectId" in issue["envelope"] or issue.get("projectMembership") is not None for issue in standalone):
    fail("standalone issue gained a project")

increment_ids = {issue["id"] for issue in increments}
for issue in increments:
    unknown = set(issue["envelope"]["dependencyIds"]) - increment_ids
    if unknown:
        fail(f"foreign increment dependency: {sorted(unknown)}")


def visit(issue_id, visiting, visited):
    if issue_id in visiting:
        raise ValueError("dependency cycle")
    if issue_id in visited:
        return
    visiting.add(issue_id)
    issue = next(value for value in increments if value["id"] == issue_id)
    for dependency_id in issue["envelope"]["dependencyIds"]:
        visit(dependency_id, visiting, visited)
    visiting.remove(issue_id)
    visited.add(issue_id)


visited = set()
for issue_id in increment_ids:
    visit(issue_id, set(), visited)


def validate_ancestry_case(case):
    dependencies = case["dependencyIds"]
    if not sorted_unique(dependencies):
        raise ValueError("ancestry dependency IDs")
    parent = case["parent"]
    parent_pr = parent["pullRequest"]
    child = case["child"]
    non_parents = case["nonParentDependencies"]
    non_parent_ids = [dependency["issueId"] for dependency in non_parents]
    if set(dependencies) != {parent["issueId"], *non_parent_ids}:
        raise ValueError("ancestry dependency set")
    if (
        child["state"] not in {"executing", "inReview", "done"}
        or child["gitParentIssueId"] != parent["issueId"]
        or child["gitParentPullRequestNumber"] != parent_pr["number"]
        or child["startCommitSha"] != parent_pr["headSha"]
        or child["baseSha"] != parent_pr["headSha"]
        or child["baseRefName"] != parent_pr["headRefName"]
        or child["graphiteParent"] != parent_pr["headRefName"]
        or not child["ancestryVerified"]
    ):
        raise ValueError("Git parent current-head mismatch")
    if parent["state"] == "inReview":
        if parent_pr["state"] == "OPEN":
            if parent_pr["mergedAt"] is not None or parent_pr["mergeCommitSha"] is not None:
                raise ValueError("open parent has merge identity")
            parent_mode = "open-parent-current-head"
        elif parent_pr["state"] == "MERGED":
            if parent_pr["mergedAt"] is None or not parent_pr["mergeCommitSha"]:
                raise ValueError("merged in-review parent lacks merge identity")
            parent_mode = "merged-parent"
        else:
            raise ValueError("in-review parent PR is not open or merged")
    elif parent["state"] == "done":
        if (
            parent_pr["state"] != "MERGED"
            or parent_pr["mergedAt"] is None
            or not parent_pr["mergeCommitSha"]
        ):
            raise ValueError("done parent is not merged")
        parent_mode = "merged-parent"
    else:
        raise ValueError("Git parent is not inReview or done")
    for dependency in non_parents:
        dependency_pr = dependency["pullRequest"]
        if (
            dependency["state"] != "done"
            or not dependency["acceptanceCurrent"]
            or dependency_pr["state"] != "MERGED"
            or dependency_pr["mergedAt"] is None
            or not dependency_pr["mergeCommitSha"]
            or not dependency["mergeRepresentedInChildAncestry"]
        ):
            raise ValueError("unsafe non-parent dependency")
    return parent_mode


ancestry_cases = fixture["ancestryCases"]
if validate_ancestry_case(ancestry_cases["validOpenParentStack"]) != "open-parent-current-head":
    fail("valid open-parent stack was not accepted at its current head")
rejects(
    "done parent with open PR",
    lambda: validate_ancestry_case(ancestry_cases["doneParentWithOpenPr"]),
)
rejects(
    "unmerged non-parent dependency",
    lambda: validate_ancestry_case(ancestry_cases["unmergedNonParentDependency"]),
)
rejects(
    "drifted open parent head",
    lambda: validate_ancestry_case(ancestry_cases["driftedOpenParentHead"]),
)

pull_requests = fixture["github"]["pullRequests"]
pr_counts = Counter(pr["number"] for pr in pull_requests)
if any(count != 1 for count in pr_counts.values()):
    fail("duplicate canonical PR number")
prs = {pr["number"]: pr for pr in pull_requests}

GITHUB_REVIEW_FIELDS = {
    "id", "url", "repository", "issueId", "pullRequestNumber", "pullRequestUrl",
    "headSha", "committedDiffHash", "fullReview", "headMarker", "reviewer", "round", "statusLine",
    "unresolvedFindingFingerprints", "unresolvedThreadIds", "submittedAt",
    "readComplete",
}


def validate_github_review(record):
    if set(record) != GITHUB_REVIEW_FIELDS or not record["readComplete"]:
        raise ValueError("partial GitHub review receipt")
    if (
        not isinstance(record["id"], str)
        or not record["id"]
        or not isinstance(record["url"], str)
        or not record["url"]
        or record["repository"] != repository
        or not isinstance(record["issueId"], str)
        or not record["issueId"]
        or type(record["pullRequestNumber"]) is not int
        or record["pullRequestNumber"] < 1
        or not isinstance(record["pullRequestUrl"], str)
        or not record["pullRequestUrl"]
    ):
        raise ValueError("GitHub review receipt identity")
    git_oid(record["headSha"], "GitHub review head")
    git_oid(record["committedDiffHash"], "GitHub review diff hash")
    if (
        record["fullReview"] is not True
        or record["headMarker"] != f"<!-- woostack-review:sha={record['headSha']} -->"
        or set(record["reviewer"]) != {"kind", "principalId"}
        or record["reviewer"]["kind"] not in {"app", "human"}
        or not record["reviewer"]["principalId"]
        or type(record["round"]) is not int
        or record["round"] < 1
        or record["statusLine"] not in {
            "APPROVED", "APPROVED WITH SUGGESTIONS", "CHANGES_REQUESTED",
        }
    ):
        raise ValueError("GitHub review receipt result")
    for field in ("unresolvedThreadIds", "unresolvedFindingFingerprints"):
        values = record[field]
        if (
            not isinstance(values, list)
            or not sorted_unique(values)
            or any(not isinstance(value, str) or not value for value in values)
        ):
            raise ValueError(f"GitHub review receipt {field}")
    instant(record["submittedAt"])


github_reviews = {}
for github_review in fixture["github"]["reviews"]:
    validate_github_review(github_review)
    if github_review["id"] in github_reviews:
        fail("duplicate native GitHub review receipt ID")
    github_reviews[github_review["id"]] = github_review


HISTORICAL_HEAD_FIELDS = {
    "branch", "committedDiffHash", "headSha", "issueId", "observedAt",
    "pullRequestNumber", "readComplete",
}
historical_heads = {}
for historical_head in fixture["github"]["historicalHeads"]:
    if set(historical_head) != HISTORICAL_HEAD_FIELDS or historical_head["readComplete"] is not True:
        fail("historical Git head receipt is incomplete")
    git_oid(historical_head["headSha"], "historical Git head")
    git_oid(historical_head["committedDiffHash"], "historical Git diff")
    instant(historical_head["observedAt"])
    key = (historical_head["issueId"], historical_head["headSha"])
    if key in historical_heads:
        fail("duplicate historical Git head receipt")
    historical_heads[key] = historical_head


def events_of(issue, event):
    return [record for record in current_events[issue["id"]] if record["envelope"]["event"] == event]


def latest_event(issue, event):
    matches = events_of(issue, event)
    return max(matches, key=lambda item: instant(item["createdAt"])) if matches else None


FENCE_PREFIX = re.compile(
    r"^(?:`{3,}|~{3,})(?:[A-Za-z0-9_+-]+[ \t]+)?",
)


def normalized_attribution_candidate(raw_line):
    candidate = raw_line.strip()
    while candidate.startswith(">"):
        candidate = candidate[1:].lstrip()
    fence = FENCE_PREFIX.match(candidate)
    if fence is not None:
        candidate = candidate[fence.end():].lstrip()
    while candidate[:1] in {"'", '"', "`"}:
        candidate = candidate[1:].lstrip()
    return candidate


def has_retired_spec_attribution(body_lines):
    return any(
        normalized_attribution_candidate(line).casefold().startswith("spec:")
        for line in body_lines
    )


def validate_pr(issue, role, prs_by_number=prs):
    number = issue["pullRequestNumber"]
    if number is None:
        return None
    pr = prs_by_number.get(number)
    if pr is None or pr["repository"] != repository:
        raise ValueError("missing or foreign PR")
    relation = resolve_linear_pr_relation(
        issue, pr["number"], pr["url"], branch=pr["headRefName"], at=now,
    )
    instant(pr["updatedAt"])
    if not pr["ancestry"]["verified"]:
        raise ValueError("unverified PR ancestry")
    body_lines = pr["body"].splitlines()
    if has_retired_spec_attribution(body_lines):
        raise ValueError("retired Spec attribution")
    nonblank = [line for line in body_lines if line.strip()]
    issue_line = f"Linear-Issue: {issue['identifier']}"
    if role == "increment":
        expected = [f"Linear-Project: {project_client_id}", issue_line]
        if nonblank[-2:] != expected:
            raise ValueError("increment trailer mismatch")
        if sum(line.startswith("Linear-Project:") for line in body_lines) != 1:
            raise ValueError("duplicate/missing project trailer")
    else:
        expected = [issue_line]
        if nonblank[-1:] != expected or any(line.startswith("Linear-Project:") for line in body_lines):
            raise ValueError("standalone trailer mismatch or synthetic project")
    if sum(line.startswith("Linear-Issue:") for line in body_lines) != 1:
        raise ValueError("duplicate/missing issue trailer")
    implementation = latest_event(issue, "implementationEvidence")
    if implementation is None:
        raise ValueError("missing implementation evidence")
    implementation_data = implementation["data"]
    if (
        implementation_data["baseCommitSha"] != pr["baseSha"]
        or implementation_data["headCommitSha"] != pr["headSha"]
        or implementation_data["committedDiffHash"] != pr["committedDiffHash"]
    ):
        raise ValueError("implementation/Git commit evidence mismatch")
    dependencies = issue["envelope"].get("dependencyIds", [])
    if dependencies and issue["state"] in {"executing", "inReview", "done", "blocked"}:
        parent_id = pr["ancestry"]["parentIssueId"]
        if parent_id not in dependencies:
            raise ValueError("dependency parent ancestry mismatch")
        parent_issue = next((value for value in increments if value["id"] == parent_id), None)
        parent_pr = prs_by_number.get(pr["ancestry"]["parentPullRequestNumber"])
        if (
            parent_issue is None
            or parent_pr is None
            or parent_issue["pullRequestNumber"] != parent_pr["number"]
            or pr["baseRefName"] != parent_pr["headRefName"]
            or pr["baseSha"] != parent_pr["headSha"]
        ):
            raise ValueError("dependency parent current-head mismatch")
        if parent_issue["state"] == "done":
            if parent_pr["state"] != "MERGED" or parent_pr["mergedAt"] is None or not parent_pr["mergeCommitSha"]:
                raise ValueError("done dependency parent is not merged")
        elif parent_issue["state"] == "inReview":
            if parent_pr["state"] == "OPEN":
                if parent_pr["mergedAt"] is not None or parent_pr["mergeCommitSha"] is not None:
                    raise ValueError("open dependency parent has merge identity")
            elif parent_pr["state"] == "MERGED":
                if parent_pr["mergedAt"] is None or not parent_pr["mergeCommitSha"]:
                    raise ValueError("merged in-review dependency parent lacks merge identity")
            else:
                raise ValueError("in-review dependency parent PR state")
        else:
            raise ValueError("dependency parent is not inReview or done")
        for dependency_id in set(dependencies) - {parent_id}:
            dependency = next(value for value in increments if value["id"] == dependency_id)
            dependency_pr = prs_by_number.get(dependency["pullRequestNumber"])
            if (
                dependency["state"] != "done"
                or dependency_pr is None
                or dependency_pr["state"] != "MERGED"
                or dependency_pr["mergedAt"] is None
                or not dependency_pr["mergeCommitSha"]
            ):
                raise ValueError("non-parent dependency is not done and merged")
        if not pr["ancestry"]["nonParentDependenciesMerged"]:
            raise ValueError("non-parent dependency merge ancestry is unverified")
    elif not dependencies and not pr["ancestry"]["rootBaseVerified"]:
        raise ValueError("root base ancestry mismatch")
    return pr


issue_prs = {}
for issue in increments:
    issue_prs[issue["id"]] = validate_pr(issue, "increment")
for issue in standalone:
    issue_prs[issue["id"]] = validate_pr(issue, "work-item")


def canonical_implementation_relations_at(issue, at, authorization_ids=()):
    assignment = issue_event_current_at(issue, "assignmentAccepted", at)
    verification = issue_event_current_at(issue, "verification", at)
    precommit_review = issue_event_current_at(issue, "precommitReview", at)
    expected = [
        assignment["id"], verification["id"], precommit_review["id"],
        *authorization_ids,
    ]
    if issue["envelope"]["role"] == "increment":
        expected.append(project_id)
    return sorted(expected)


def implementation_producer_records(issue, implementation):
    at = instant(implementation["createdAt"])
    authorization_ids = [
        native_id for native_id in implementation["envelope"]["relatedIds"]
        if any(
            candidate["id"] == native_id
            and candidate["envelope"]["event"] == "restackAuthorized"
            for candidate in issue["events"]
        )
    ]
    if len(authorization_ids) > 1:
        raise ValueError("implementationEvidence has competing authorizations")
    assignment = issue_event_current_at(issue, "assignmentAccepted", at)
    verification = issue_event_current_at(issue, "verification", at)
    precommit_review = issue_event_current_at(issue, "precommitReview", at)
    expected_actor = assignment["actor"]
    if authorization_ids:
        authorization = native_revision_current_at(
            issue, authorization_ids[0], at,
        )
        expected_actor = expected_controller(authorization["data"])
        if not (
            instant(authorization["createdAt"])
            < at
            <= timestamp(authorization["data"]["expiresAt"])
            and authorization["id"] in verification["envelope"]["relatedIds"]
            and authorization["id"] in precommit_review["envelope"]["relatedIds"]
            and verification["actor"] == expected_actor
            and precommit_review["actor"] == expected_actor
        ):
            raise ValueError("implementationEvidence lacks current authorized verification")
    if (
        implementation["actor"] != expected_actor
        or implementation["envelope"]["relatedIds"]
        != canonical_implementation_relations_at(issue, at, authorization_ids)
    ):
        raise ValueError("implementationEvidence producer authority or relations")
    for native_id in implementation["envelope"]["relatedIds"]:
        if any(candidate["id"] == native_id for candidate in issue["events"]):
            native_revision_current_at(issue, native_id, at)
    return assignment, verification, precommit_review, authorization_ids


def validate_current_implementation(issue, pr, implementation_override=None):
    implementation = implementation_override or latest_event(
        issue, "implementationEvidence",
    )
    current = latest_event(issue, "implementationEvidence")
    if implementation is None or current is None or pr is None:
        raise ValueError("missing current implementation/Git evidence")
    if (
        implementation["id"],
        implementation["envelope"]["clientId"],
        implementation["envelope"]["revision"],
    ) != (
        current["id"],
        current["envelope"]["clientId"],
        current["envelope"]["revision"],
    ):
        raise ValueError("implementationEvidence is not current")
    validate_issue_event_payload(implementation)
    _, verification, precommit_review, _ = implementation_producer_records(
        issue, implementation,
    )
    data = implementation["data"]
    if (
        data["baseCommitSha"] != pr["baseSha"]
        or data["headCommitSha"] != pr["headSha"]
        or data["committedDiffHash"] != pr["committedDiffHash"]
        or verification["data"]["changedPaths"] != pr["changedPaths"]
        or precommit_review["data"]["changedPaths"] != pr["changedPaths"]
        or precommit_review["data"]["reviewedDiffHash"]
        != data["committedDiffHash"]
    ):
        raise ValueError("current implementation/Git/producer identity mismatch")
    return implementation


def validate_historical_implementation(issue, implementation):
    if implementation is None:
        raise ValueError("missing historical implementation evidence")
    validate_issue_event_payload(implementation)
    implementation_producer_records(issue, implementation)
    data = implementation["data"]
    receipt = historical_heads.get((issue["id"], data["headCommitSha"]))
    pr = issue_prs.get(issue["id"])
    if (
        receipt is None
        or pr is None
        or receipt["readComplete"] is not True
        or receipt["pullRequestNumber"] != pr["number"]
        or receipt["branch"] != pr["headRefName"]
        or receipt["committedDiffHash"] != data["committedDiffHash"]
        or instant(receipt["observedAt"]) < instant(implementation["createdAt"])
    ):
        raise ValueError("historical implementation/Git identity mismatch")
    return implementation


def validate_verification(issue, event, implementation_override=None, pr_override=None):
    current_verification = latest_event(issue, "verification")
    envelope = event["envelope"]
    role = issue["envelope"]["role"]
    if (
        not event.get("readComplete")
        or set(envelope) != ISSUE_EVENT
        or envelope["kind"] != "issueEvent"
        or envelope["event"] != "verification"
        or envelope["issueId"] != issue["id"]
    ):
        raise ValueError("partial or foreign verification event")
    validate_base(envelope, role)
    if current_verification is None or (
        event["id"], envelope["clientId"], envelope["revision"],
    ) != (
        current_verification["id"],
        current_verification["envelope"]["clientId"],
        current_verification["envelope"]["revision"],
    ):
        raise ValueError("verification is not current")
    validate_issue_event_payload(event)
    pr = pr_override or issue_prs.get(issue["id"])
    implementation = validate_current_implementation(
        issue, pr, implementation_override,
    )
    _, producer_verification, _, authorization_ids = (
        implementation_producer_records(issue, implementation)
    )
    at = instant(event["createdAt"])
    assignment = issue_event_current_at(issue, "assignmentAccepted", at)
    expected_actor = assignment["actor"]
    if authorization_ids:
        authorization = native_revision_current_at(
            issue, authorization_ids[0], at,
        )
        expected_actor = expected_controller(authorization["data"])
        if not (
            instant(authorization["createdAt"])
            < at
            <= timestamp(authorization["data"]["expiresAt"])
        ):
            raise ValueError("verification authorization window")
    expected_relations = sorted([
        assignment["id"], *expected_project_relation(role),
        *authorization_ids,
    ])
    data = event["data"]
    if (
        event["id"] != producer_verification["id"]
        or envelope["relatedIds"] != expected_relations
        or data["issueId"] != issue["id"]
        or payload_as_native_actor(data["actor"], "verification actor")
        != event["actor"]
        or event["actor"] != expected_actor
        or event["id"] not in implementation["envelope"]["relatedIds"]
        or instant(event["createdAt"]) >= instant(implementation["createdAt"])
        or data["changedPaths"] != pr["changedPaths"]
    ):
        raise ValueError("verification precommit identity/reverse-binding mismatch")
    return True


def validate_precommit_review(issue, event, implementation_override=None, pr_override=None):
    current_review = latest_event(issue, "precommitReview")
    envelope = event["envelope"]
    role = issue["envelope"]["role"]
    if (
        current_review is None
        or not event.get("readComplete")
        or set(envelope) != ISSUE_EVENT
        or envelope["event"] != "precommitReview"
        or envelope["issueId"] != issue["id"]
        or (event["id"], envelope["clientId"], envelope["revision"])
        != (
            current_review["id"],
            current_review["envelope"]["clientId"],
            current_review["envelope"]["revision"],
        )
    ):
        raise ValueError("partial, foreign, or stale precommitReview")
    validate_issue_event_payload(event)
    implementation = validate_current_implementation(
        issue, pr_override or issue_prs[issue["id"]], implementation_override,
    )
    assignment, verification, producer_review, authorization_ids = (
        implementation_producer_records(issue, implementation)
    )
    expected = sorted([
        assignment["id"], verification["id"], *expected_project_relation(role),
        *authorization_ids,
    ])
    expected_actor = assignment["actor"]
    if authorization_ids:
        expected_actor = expected_controller(
            issue_event_by_native_id(issue, authorization_ids[0])["data"],
        )
    payload_actor = payload_as_native_actor(
        event["data"]["actor"], "precommitReview actor",
    )
    if (
        event["id"] != producer_review["id"]
        or envelope["relatedIds"] != expected
        or event["actor"] != expected_actor
        or payload_actor != event["actor"]
        or event["data"]["issueId"] != issue["id"]
        or event["data"]["changedPaths"] != verification["data"]["changedPaths"]
        or event["data"]["changedPaths"]
        != (pr_override or issue_prs[issue["id"]])["changedPaths"]
        or event["data"]["reviewedDiffHash"]
        != implementation["data"]["committedDiffHash"]
        or event["id"] not in implementation["envelope"]["relatedIds"]
        or not (
            instant(verification["createdAt"])
            < instant(event["createdAt"])
            < instant(implementation["createdAt"])
        )
    ):
        raise ValueError("precommitReview identity, authority, order, or reverse binding")
    return True


def validate_restack_authorized(
    issue, event, pr, current_implementation_override=None,
    historical_implementation_override=None, consumer_override=None,
):
    envelope = event["envelope"]
    if (
        not any(
            (
                candidate["id"], candidate["envelope"]["clientId"],
                candidate["envelope"]["revision"],
            ) == (event["id"], envelope["clientId"], envelope["revision"])
            for candidate in events_of(issue, "restackAuthorized")
        )
        or not event.get("readComplete")
        or set(envelope) != ISSUE_EVENT
        or envelope["event"] != "restackAuthorized"
        or envelope["issueId"] != issue["id"]
    ):
        raise ValueError("partial, foreign, or stale restackAuthorized event")
    validate_base(envelope, issue["envelope"]["role"])
    validate_issue_event_payload(event)
    auth_at = instant(event["createdAt"])
    data = event["data"]
    implementation_ids = [
        native_id for native_id in envelope["relatedIds"]
        if any(
            candidate["id"] == native_id
            and candidate["envelope"]["event"] == "implementationEvidence"
            for candidate in issue["events"]
        )
    ]
    if len(implementation_ids) != 1 or pr is None:
        raise ValueError("restackAuthorized lacks exact historical implementation A")
    historical_native = native_revision_current_at(
        issue, implementation_ids[0], auth_at,
    )
    historical_implementation = (
        historical_implementation_override or historical_native
    )
    if (
        historical_implementation["id"] != historical_native["id"]
        or historical_implementation["envelope"]["clientId"]
        != historical_native["envelope"]["clientId"]
        or historical_implementation["envelope"]["revision"]
        != historical_native["envelope"]["revision"]
    ):
        raise ValueError("historical implementation override identity")
    validate_issue_event_payload(historical_implementation)
    historical_assignment, _, historical_precommit, _ = (
        implementation_producer_records(issue, historical_implementation)
    )
    historical_git = historical_heads.get((
        issue["id"], historical_implementation["data"]["headCommitSha"],
    ))
    assignment = issue_event_current_at(issue, "assignmentAccepted", auth_at)
    relation = resolve_linear_pr_relation(
        issue, pr["number"], pr["url"], branch=data["branch"], at=auth_at,
    )
    expected_relations = sorted([
        assignment["id"], historical_implementation["id"], relation["id"],
        *data["affectedRelationIds"],
    ])
    if (
        historical_git is None
        or historical_git["pullRequestNumber"] != pr["number"]
        or historical_git["branch"] != data["branch"]
        or historical_git["committedDiffHash"]
        != historical_implementation["data"]["committedDiffHash"]
        or instant(historical_git["observedAt"]) >= auth_at
        or historical_assignment["id"]
        not in historical_implementation["envelope"]["relatedIds"]
        or event["actor"] != assignment["actor"]
        or data["branch"] != pr["headRefName"]
        or envelope["relatedIds"] != expected_relations
        or data["headCommitSha"]
        != historical_implementation["data"]["headCommitSha"]
        or data["registryClaimPath"]
        != f".woostack/worktrees/.registry/{issue['id']}/claim.json"
        or not Path(data["worktreePath"]).is_absolute()
        or not data["worktreePath"].endswith(
            f"/.woostack/worktrees/issues/{issue['id']}"
        )
        or auth_at >= timestamp(data["expiresAt"])
    ):
        raise ValueError("restackAuthorized historical operation/owner/path mismatch")

    consumers = [
        implementation
        for implementation in issue["events"]
        if implementation["envelope"]["event"] == "implementationEvidence"
        and event["id"] in implementation["envelope"]["relatedIds"]
    ]
    if consumer_override is not None:
        consumers = [
            consumer_override if candidate["id"] == consumer_override["id"]
            else candidate
            for candidate in consumers
        ]
        if (
            event["id"] in consumer_override["envelope"]["relatedIds"]
            and all(candidate["id"] != consumer_override["id"] for candidate in consumers)
        ):
            consumers.append(consumer_override)
    if len(consumers) > 1:
        raise ValueError("restackAuthorized has multiple implementation consumers")
    consumer = consumers[0] if consumers else None
    consumed = consumer is not None
    inactive = not consumed and timestamp(data["expiresAt"]) <= now
    if consumed:
        completion = instant(consumer["createdAt"])
        _, verification, precommit_review, authorization_ids = (
            implementation_producer_records(issue, consumer)
        )
        if not (
            auth_at < completion <= timestamp(data["expiresAt"])
            and consumer["data"]["headCommitSha"]
            != historical_implementation["data"]["headCommitSha"]
            and consumer["actor"] == expected_controller(data)
            and authorization_ids == [event["id"]]
            and event["id"] in verification["envelope"]["relatedIds"]
            and event["id"] in precommit_review["envelope"]["relatedIds"]
            and consumer.get("readComplete") is True
        ):
            raise ValueError("consumed authorization completion/controller/verification")
    else:
        authorized_reviews = [
            review for review in issue["events"]
            if review["envelope"]["event"] == "precommitReview"
            and event["id"] in review["envelope"]["relatedIds"]
            and instant(review["createdAt"]) > auth_at
        ]
        if authorized_reviews:
            raise ValueError("authorized rewrite omitted implementation consumer")

    current_implementation = (
        current_implementation_override
        or latest_event(issue, "implementationEvidence")
    )
    if not consumed and not inactive and (
        current_implementation["id"] != historical_implementation["id"]
        or current_implementation["data"]["headCommitSha"] != pr["headSha"]
    ):
        raise ValueError("active unconsumed authorization/current A mismatch")
    validate_current_implementation(issue, pr, current_implementation)
    _, _, current_precommit, _ = implementation_producer_records(
        issue, current_implementation,
    )
    return {
        "consumed": consumed,
        "inactive": inactive,
        "operationId": data["operationId"],
        "authorizationOwner": assignment["actor"],
        "currentOwner": issue["owner"],
        "assignmentEventId": assignment["id"],
        "historicalImplementationId": historical_implementation["id"],
        "historicalPrecommitReviewId": historical_precommit["id"],
        "currentPrecommitReviewId": current_precommit["id"],
        "resultingImplementationId": consumer["id"] if consumer else None,
        "resultingHeadSha": (
            consumer["data"]["headCommitSha"] if consumer else None
        ),
        "currentImplementationId": current_implementation["id"],
        "currentHeadSha": current_implementation["data"]["headCommitSha"],
        "linearPrRelationId": relation["id"],
    }


restack_authorization_ids = []
consumed_restack_authorization_ids = []
inactive_restack_authorization_ids = []
empty_relation_authorization_ids = []
for issue in all_issues:
    for authorization in events_of(issue, "restackAuthorized"):
        details = validate_restack_authorized(
            issue, authorization, issue_prs[issue["id"]],
        )
        if details["consumed"]:
            consumed_restack_authorization_ids.append(authorization["id"])
        if details["inactive"]:
            inactive_restack_authorization_ids.append(authorization["id"])
        if not authorization["data"]["affectedRelationIds"]:
            empty_relation_authorization_ids.append(authorization["id"])
        restack_authorization_ids.append(authorization["id"])
if (
    restack_authorization_ids != expected["restackAuthorizationEventIds"]
    or consumed_restack_authorization_ids
    != expected["consumedRestackAuthorizationEventIds"]
    or inactive_restack_authorization_ids
    != expected["inactiveRestackAuthorizationEventIds"]
    or empty_relation_authorization_ids
    != expected["emptyAffectedAuthorizationEventIds"]
):
    fail("canonical restackAuthorized event set drift")


def validate_review_result(
    issue, event, pr, reviews_by_id=github_reviews, verification_override=None,
    require_current_head=True,
):
    envelope = event["envelope"]
    role = issue["envelope"]["role"]
    family_currents = validate_review_round_families(issue)
    if (
        not event.get("readComplete")
        or set(envelope) != ISSUE_EVENT
        or envelope["kind"] != "issueEvent"
        or envelope["event"] != "reviewResult"
        or envelope["issueId"] != issue["id"]
        or not any(
            (
                candidate["id"], candidate["envelope"]["clientId"],
                candidate["envelope"]["revision"],
            ) == (event["id"], envelope["clientId"], envelope["revision"])
            for candidate in family_currents
        )
    ):
        raise ValueError("partial, foreign, or stale reviewResult event")
    validate_base(envelope, role)
    validate_issue_event_payload(event)
    at = instant(event["createdAt"])
    implementation_ids = [
        native_id for native_id in envelope["relatedIds"]
        if any(
            candidate["id"] == native_id
            and candidate["envelope"]["event"] == "implementationEvidence"
            for candidate in issue["events"]
        )
    ]
    verification_ids = [
        native_id for native_id in envelope["relatedIds"]
        if any(
            candidate["id"] == native_id
            and candidate["envelope"]["event"] == "verification"
            for candidate in issue["events"]
        )
    ]
    if len(implementation_ids) != 1 or len(verification_ids) != 1 or pr is None:
        raise ValueError("reviewResult lacks exact implementation or verification")
    implementation = native_revision_current_at(
        issue, implementation_ids[0], at,
    )
    resolved_verification = native_revision_current_at(
        issue, verification_ids[0], at,
    )
    verification = verification_override or resolved_verification
    if (
        verification["id"] != resolved_verification["id"]
        or verification["envelope"]["revision"]
        != resolved_verification["envelope"]["revision"]
    ):
        raise ValueError("reviewResult verification override identity")
    _, producer_verification, _, _ = implementation_producer_records(
        issue, implementation,
    )
    if producer_verification["id"] != verification["id"]:
        raise ValueError("reviewResult did not bind implementation verification")
    data = event["data"]
    relation = resolve_linear_pr_relation(
        issue, data["pullRequestNumber"], data["pullRequestUrl"], at=at,
    )
    receipt = reviews_by_id.get(data["githubReviewId"])
    if receipt is None:
        raise ValueError("reviewResult lacks its native GitHub review receipt")
    validate_github_review(receipt)
    if instant(receipt["submittedAt"]) > at:
        raise ValueError("reviewResult/native review receipt timestamp mismatch")
    expected_relations = sorted([
        implementation["id"], verification["id"], relation["id"], receipt["id"],
    ])
    implementation_data = implementation["data"]
    if (
        envelope["relatedIds"] != expected_relations
        or data["issueId"] != issue["id"]
        or data["pullRequestNumber"] != pr["number"]
        or data["pullRequestUrl"] != pr["url"]
        or data["reviewedHeadSha"] != implementation_data["headCommitSha"]
        or data["committedDiffHash"]
        != implementation_data["committedDiffHash"]
        or receipt["issueId"] != issue["id"]
        or receipt["pullRequestNumber"] != pr["number"]
        or receipt["pullRequestUrl"] != pr["url"]
        or not receipt["url"].startswith(f"{pr['url']}#pullrequestreview-")
        or receipt["headSha"] != data["reviewedHeadSha"]
        or receipt["committedDiffHash"] != data["committedDiffHash"]
        or receipt["reviewer"] != event["actor"]
        or receipt["round"] != data["round"]
        or receipt["unresolvedThreadIds"] != data["unresolvedThreadIds"]
        or receipt["unresolvedFindingFingerprints"]
        != data["unresolvedFindingFingerprints"]
    ):
        raise ValueError("reviewResult issue/PR/head/diff/relation/receipt mismatch")
    accepted = data["result"] == "PASS"
    if accepted:
        if (
            receipt["statusLine"]
            not in {"APPROVED", "APPROVED WITH SUGGESTIONS"}
            or data["unresolvedThreadIds"]
            or data["unresolvedFindingFingerprints"]
        ):
            raise ValueError("accepted reviewResult is unresolved")
    elif (
        receipt["statusLine"] != "CHANGES_REQUESTED"
        or not (data["unresolvedThreadIds"] or data["unresolvedFindingFingerprints"])
    ):
        raise ValueError("changes-requested reviewResult lacks current findings")
    if require_current_head:
        current_implementation = validate_current_implementation(issue, pr)
        validate_verification(issue, verification)
        validate_precommit_review(issue, latest_event(issue, "precommitReview"))
        if (
            implementation["id"] != current_implementation["id"]
            or data["reviewedHeadSha"] != pr["headSha"]
            or data["committedDiffHash"] != pr["committedDiffHash"]
            or (
                accepted
                and pr["reviewState"] != "PASS"
            )
            or (
                not accepted
                and pr["reviewState"] != "CHANGES_REQUESTED"
            )
        ):
            raise ValueError("reviewResult is not valid for the current PR head")
    return accepted


def select_current_review_result(issue, pr, reviews_by_id=github_reviews):
    families = validate_review_round_families(issue)
    current_implementation = latest_event(issue, "implementationEvidence")
    candidates = []
    for event in families:
        validate_review_result(
            issue, event, pr, reviews_by_id, require_current_head=False,
        )
        if (
            event["data"]["reviewedHeadSha"]
            == current_implementation["data"]["headCommitSha"]
            == pr["headSha"]
            and event["data"]["committedDiffHash"]
            == current_implementation["data"]["committedDiffHash"]
            == pr["committedDiffHash"]
        ):
            candidates.append(event)
    if not candidates:
        raise ValueError("no valid reviewResult for current PR head")
    selected_round = max(event["data"]["round"] for event in candidates)
    selected = [
        event for event in candidates
        if event["data"]["round"] == selected_round
    ]
    if len(selected) != 1:
        raise ValueError("ambiguous latest current-head reviewResult")
    validate_review_result(issue, selected[0], pr, reviews_by_id)
    return selected[0]


accepted_review_event_ids = []
selected_review_event_ids = []
for issue in all_issues:
    if validate_review_round_families(issue):
        selected_review = select_current_review_result(
            issue, issue_prs[issue["id"]],
        )
        selected_review_event_ids.append(selected_review["id"])
        if validate_review_result(
            issue, selected_review, issue_prs[issue["id"]],
        ):
            accepted_review_event_ids.append(selected_review["id"])
if accepted_review_event_ids != expected["acceptedReviewResultEventIds"]:
    fail("accepted current reviewResult set drift")
if selected_review_event_ids != expected["latestCurrentHeadReviewEventIds"]:
    fail("latest current-head reviewResult selection drift")
if sorted(github_reviews) != expected["currentGithubReviewReceiptIds"]:
    fail("native GitHub review receipt set drift")


def validate_issue_done_principal_gate(issue, gate):
    if (
        not isinstance(gate, dict)
        or set(gate) != {"acceptanceAuthority", "authenticatedPrincipal", "readComplete"}
        or gate["readComplete"] is not True
        or gate["acceptanceAuthority"] != issue["acceptanceAuthority"]
        or gate["authenticatedPrincipal"] != gate["acceptanceAuthority"]
    ):
        raise ValueError("authenticated issueDone principal mismatch")
    return True


def validate_issue_done(
    issue, event, pr, receipt=None, review_override=None, reviews_by_id=github_reviews,
    verification_override=None, precommit_override=None,
):
    implementation = latest_event(issue, "implementationEvidence")
    verification = verification_override or latest_event(issue, "verification")
    precommit_review = precommit_override or latest_event(issue, "precommitReview")
    review = review_override or select_current_review_result(issue, pr, reviews_by_id)
    acceptance = latest_event(issue, "acceptance")
    if any(
        value is None
        for value in (
            implementation, verification, precommit_review, review, acceptance, pr,
        )
    ):
        raise ValueError("issueDone lacks current terminal evidence")
    if receipt is not None:
        validate_issue_done_principal_gate(issue, receipt["principalGate"])
    validate_verification(issue, verification)
    validate_precommit_review(issue, precommit_review)
    review_accepted = validate_review_result(
        issue, review, pr, reviews_by_id, verification,
    )
    relation = resolve_linear_pr_relation(
        issue, pr["number"], pr["url"], branch=pr["headRefName"], at=now,
    )
    expected_evidence = sorted([
        acceptance["id"],
        implementation["id"],
        review["id"],
        verification["id"],
        relation["id"],
    ])
    if event["actor"] != issue["acceptanceAuthority"]:
        raise ValueError("issueDone actor is not the type-aware acceptance authority")
    if event["envelope"]["relatedIds"] != expected_evidence:
        raise ValueError("issueDone related evidence mismatch")
    if (
        event["data"]["pullRequestNumber"] != pr["number"]
        or event["data"]["mergeCommitSha"] != pr["mergeCommitSha"]
        or pr["state"] != "MERGED"
        or pr["mergedAt"] is None
        or not pr["mergeCommitSha"]
        or verification["data"]["status"] != "PASS"
        or not review_accepted
        or acceptance["data"].get("result") != "PASS"
        or acceptance["data"].get("issueId") != issue["id"]
        or acceptance["actor"] != issue["acceptanceAuthority"]
    ):
        raise ValueError("issueDone terminal evidence mismatch")
    if receipt is not None and (
        receipt["eventClientId"] != event["envelope"]["clientId"]
        or receipt["eventNativeId"] != event["id"]
        or receipt["evidenceIds"] != expected_evidence
        or receipt["linearPullRequestRelationId"] != relation["id"]
    ):
        raise ValueError("issueDone receipt identity mismatch")
    return expected_evidence


def open_blocker(issue):
    blocks = events_of(issue, "blocked")
    unblocks = events_of(issue, "unblocked")
    resolutions = defaultdict(list)
    for unblocked in unblocks:
        resolutions[unblocked["data"]["blockedEventId"]].append(unblocked)
    if any(len(values) != 1 for values in resolutions.values()):
        raise ValueError("one blocked event was resolved more than once")
    unknown = set(resolutions) - {blocked["id"] for blocked in blocks}
    if unknown:
        raise ValueError("unblocked event names an unknown blocker")
    open_blocks = [blocked for blocked in blocks if blocked["id"] not in resolutions]
    if issue["state"] == "blocked":
        if len(open_blocks) != 1:
            raise ValueError("blocked native state/event mismatch")
        if open_blocks[0]["data"]["previousState"] != issue["previousState"]:
            raise ValueError("blocked previous state mismatch")
        return open_blocks[0]
    if open_blocks:
        raise ValueError("open blocker conflicts with native state")
    if unblocks:
        latest_unblock = max(unblocks, key=lambda record: instant(record["createdAt"]))
        if latest_unblock["data"]["restoredState"] != issue["state"]:
            raise ValueError("unblocked evidence/native state mismatch")
    return None


def pending_handoff(issue):
    handoff = latest_event(issue, "handoff")
    if handoff is None:
        return None
    target = issue_payload_owner(handoff["data"])
    if target != issue["owner"]:
        raise ValueError("handoff target/owner mismatch")
    fulfilled = [
        event for event in events_of(issue, "assignmentAccepted")
        if instant(event["createdAt"]) > instant(handoff["createdAt"])
        and event["actor"] == target
        and event["envelope"]["relatedIds"] == [handoff["id"]]
    ]
    return None if fulfilled else handoff


def terminal_eligible(
    issue, review_override=None, reviews_by_id=github_reviews, verification_override=None,
    precommit_override=None,
):
    if issue["state"] != "inReview" or open_blocker(issue) or pending_handoff(issue):
        return False
    implementation = latest_event(issue, "implementationEvidence")
    verification = verification_override or latest_event(issue, "verification")
    precommit_review = precommit_override or latest_event(issue, "precommitReview")
    pr = issue_prs[issue["id"]]
    review = review_override or (
        select_current_review_result(issue, pr, reviews_by_id)
        if pr is not None and validate_review_round_families(issue) else None
    )
    acceptance = latest_event(issue, "acceptance")
    if any(
        value is None
        for value in (
            implementation, verification, precommit_review, review, acceptance, pr,
        )
    ):
        return False
    validate_verification(issue, verification)
    validate_precommit_review(issue, precommit_review)
    if verification["data"]["status"] != "PASS":
        return False
    if not validate_review_result(issue, review, pr, reviews_by_id, verification):
        return False
    payload_actor = payload_as_native_actor(
        acceptance["data"]["actor"], "acceptance actor",
    )
    if (
        acceptance["data"].get("result") != "PASS"
        or acceptance["data"].get("issueId") != issue["id"]
        or acceptance["actor"] != issue["acceptanceAuthority"]
        or payload_actor != acceptance["actor"]
        or acceptance["actor"] == implementation["actor"]
        or acceptance["actor"] == review["actor"]
    ):
        return False
    required = {implementation["id"], verification["id"], review["id"]}
    if set(acceptance["envelope"]["relatedIds"]) != required:
        return False
    return pr["state"] == "MERGED" and pr["mergedAt"] is not None and bool(pr["mergeCommitSha"])


receipts = fixture["mutationReceipts"]["issueDone"]
receipt_by_target = {receipt["targetId"]: receipt for receipt in receipts}
if len(receipt_by_target) != len(receipts):
    fail("duplicate issue terminal receipt target")

pre_append_issues = []
for issue in all_issues:
    before = copy.deepcopy(issue)
    receipt = receipt_by_target.get(issue["id"])
    if receipt is not None:
        before["state"] = receipt["from"]
        before["events"] = [
            event for event in before["events"]
            if event["envelope"]["event"] != "issueDone"
        ]
    pre_append_issues.append(before)
eligible = [issue for issue in pre_append_issues if terminal_eligible(issue)]
if [issue["identifier"] for issue in eligible] != ["APP-12"]:
    fail(f"eligible terminal set is {[issue['identifier'] for issue in eligible]!r}")
if len(receipts) != len(eligible):
    fail("terminal receipt cardinality mismatch")

for before, receipt in zip(eligible, receipts):
    issue = next(value for value in all_issues if value["id"] == before["id"])
    if not validate_issue_done_principal_gate(issue, receipt["principalGate"]):
        fail("issueDone authenticated principal gate did not pass")
    done_events = events_of(issue, "issueDone")
    if len(done_events) != 1:
        fail("second full read lacks one current issueDone")
    done_event = done_events[0]
    expected_evidence = validate_issue_done(issue, done_event, issue_prs[issue["id"]], receipt)
    if (
        receipt["operation"] != "issueState"
        or receipt["targetId"] != issue["id"]
        or receipt["targetClientId"] != issue["envelope"]["clientId"]
        or receipt["from"] != "inReview"
        or receipt["to"] != "done"
        or receipt["evidenceIds"] != expected_evidence
    ):
        fail("issue mutation receipt does not match the exact preview")
    retry = receipt["retryDiscovery"]
    if (
        retry["clientId"] != done_event["envelope"]["clientId"]
        or not retry["complete"]
        or retry["nativeIds"] != [done_event["id"]]
        or retry["reappend"]
    ):
        fail("issueDone retry does not discover the retained UUID exactly once")
    read_back = receipt["readBack"]
    second_current = validate_issue_resource(copy.deepcopy(issue), "increment")
    current_event_ids = sorted(event["id"] for event in second_current)
    if not read_back.get("complete") or not read_back.get("eventsComplete"):
        fail("second issue mutation read-back is partial")
    if (
        read_back["id"], read_back["clientId"], read_back["repository"], read_back["role"],
        read_back["projectId"], read_back["state"], read_back["owner"],
        read_back["dependencyIds"], read_back["pullRequestNumber"],
        read_back["linearPullRequestRelationId"],
        read_back["issueDoneEventClientId"], read_back["issueDoneEventNativeId"],
        read_back["currentEventIds"],
    ) != (
        issue["id"], issue["envelope"]["clientId"], repository, "increment", project_id,
        "done", issue["owner"], issue["envelope"]["dependencyIds"],
        issue["pullRequestNumber"], "linear-relation-app12-pr42",
        done_event["envelope"]["clientId"], done_event["id"], current_event_ids,
    ):
        fail("second complete issue read-back drift")

if expected["issueDonePrincipalGatePassed"] is not True:
    fail("fixture principal-gate expectation drift")
wrong_principal = fixture["failureCases"]["wrongIssueDonePrincipalScenario"]
rejects(
    "foreign authenticated principal before issueDone UUID allocation",
    lambda: validate_issue_done_principal_gate(increments[0], wrong_principal["principalGate"]),
)
if wrong_principal["eventUuidAllocated"] or wrong_principal["mutationsAttempted"]:
    fail("wrong-principal scenario crossed the issueDone pre-allocation mutation gate")

if [issue["identifier"] for issue in all_issues if terminal_eligible(issue)]:
    fail("second status read attempted to replay a verified terminal transition")
states_after = {issue["id"]: issue["state"] for issue in increments}
progress = {"done": sum(state == "done" for state in states_after.values()), "total": len(states_after)}
if progress != expected["progressAfterReconciliation"]:
    fail(f"progress derived as {progress!r}")

rollup = {"merged": 0, "open": 0, "none": 0}
for issue in increments:
    pr = issue_prs[issue["id"]]
    if pr is None:
        rollup["none"] += 1
    elif pr["state"] == "MERGED":
        rollup["merged"] += 1
    elif pr["state"] == "OPEN":
        rollup["open"] += 1
if rollup != expected["projectPrRollup"]:
    fail(f"project PR rollup derived as {rollup!r}")


def activity_at(issue):
    values = [instant(event["createdAt"]) for event in current_events[issue["id"]]]
    pr = issue_prs[issue["id"]]
    if pr:
        values.append(instant(pr["updatedAt"]))
        if pr["mergedAt"]:
            values.append(instant(pr["mergedAt"]))
    if not values:
        raise ValueError("missing activity evidence")
    return max(values)


stale = []
for issue in all_issues:
    state = states_after.get(issue["id"], issue["state"])
    age_days = (now - activity_at(issue)).days
    if state != "done" and age_days >= fixture["policy"]["staleDays"]:
        stale.append(issue["identifier"])
if stale != expected["staleIssueIdentifiers"]:
    fail(f"stale set derived as {stale!r}")

blocked = [issue["identifier"] for issue in all_issues if open_blocker(issue)]
handoffs = [issue["identifier"] for issue in all_issues if pending_handoff(issue)]
if blocked != expected["blockedIssueIdentifiers"]:
    fail(f"blocked set derived as {blocked!r}")
if handoffs != expected["handoffIssueIdentifiers"]:
    fail(f"handoff set derived as {handoffs!r}")


def next_action(issue):
    state = states_after.get(issue["id"], issue["state"])
    if state == "done":
        return "none — done"
    blocker = open_blocker(issue)
    if blocker:
        return f"{issue['owner']['principalId']}: resolve blocker {blocker['id']}"
    handoff = pending_handoff(issue)
    if handoff:
        return f"{handoff['data']['ownerPrincipalId']}: {handoff['data']['nextAction']}"
    dependencies = issue["envelope"].get("dependencyIds", [])
    waiting = [dependency for dependency in dependencies if states_after.get(dependency) != "done"]
    if waiting:
        return f"wait for {','.join(waiting)}"
    pr = issue_prs[issue["id"]]
    if pr and pr["state"] == "OPEN":
        return f"review and merge PR #{pr['number']}"
    return "continue verified issue work"


derived_actions = {issue["identifier"]: next_action(issue) for issue in all_issues}
if derived_actions != expected["nextActions"]:
    fail(f"next actions derived as {derived_actions!r}")


def project_completion_eligible(preconditions, expected_issue_ids, phase_events):
    derived_phase, current_project_events = validate_phase(phase_events)
    validate_project_event_dispatch(current_project_events)
    return (
        derived_phase == "done"
        and preconditions["projectCategory"] == "started"
        and set(preconditions["issueStates"]) == set(expected_issue_ids)
        and bool(preconditions["issueStates"])
        and all(state == "done" for state in preconditions["issueStates"].values())
        and preconditions["allPullRequestsMerged"]
        and preconditions["dependenciesSatisfied"]
        and not preconditions["unresolvedBlockerIds"]
        and not preconditions["handoffConflicts"]
        and preconditions["leadReadComplete"]
        and preconditions["mutationPrincipal"] == project["lead"]
    )


baseline_preconditions = {
    "projectCategory": project["status"]["category"],
    "issueStates": states_after,
    "allPullRequestsMerged": rollup["open"] == 0 and rollup["none"] == 0,
    "dependenciesSatisfied": False,
    "unresolvedBlockerIds": [latest_event(increments[2], "blocked")["id"]],
    "handoffConflicts": [],
    "leadReadComplete": True,
    "mutationPrincipal": project["lead"],
}
if project_completion_eligible(baseline_preconditions, increment_ids, project["events"]):
    fail("partial baseline project was eligible for completion")
scenario = fixture["mutationReceipts"]["allDoneProjectScenario"]
scenario_events = copy.deepcopy(project["events"]) + [
    copy.deepcopy(scenario["donePhaseEvent"]),
]
scenario_phase, _ = validate_phase(scenario_events)
if (
    scenario_phase != "done"
    or scenario["donePhaseEvent"]["actor"] != project["lead"]
    or scenario["donePhaseEvent"]["envelope"]["predecessorId"] != "update-in-review"
):
    fail("all-done scenario lacks an actual current lead-authored done chain")
if not project_completion_eligible(
    scenario["preconditions"], increment_ids, scenario_events,
):
    fail("all-done scenario was not eligible for project completion")
not_all_done = copy.deepcopy(scenario["preconditions"])
not_all_done["issueStates"]["issue-app-14"] = "inReview"
if project_completion_eligible(not_all_done, increment_ids, scenario_events):
    fail("project completion accepted a non-done increment")
wrong_lead = copy.deepcopy(scenario["preconditions"])
wrong_lead["mutationPrincipal"] = {"kind": "human", "principalId": "user-not-lead"}
if project_completion_eligible(wrong_lead, increment_ids, scenario_events):
    fail("project completion accepted a principal other than the freshly verified pinned lead")
unauthorized_done_events = copy.deepcopy(project["events"]) + [
    copy.deepcopy(fixture["failureCases"]["unauthorizedProjectDoneEvent"]),
]
rejects(
    "project done authored by a non-lead",
    lambda: project_completion_eligible(
        scenario["preconditions"], increment_ids, unauthorized_done_events,
    ),
)
missing_done_events = [
    event for event in scenario_events
    if event["id"] != fixture["failureCases"]["missingProjectDoneEventId"]
]
if project_completion_eligible(
    scenario["preconditions"], increment_ids, missing_done_events,
):
    fail("project completion accepted a missing done phase event")
project_receipt = scenario["readBack"]
if (
    scenario["operation"] != "projectStatus"
    or scenario["targetId"] != project_id
    or scenario["targetClientId"] != project_client_id
    or scenario["fromCategory"] != "started"
    or scenario["toCategory"] != "completed"
    or not project_receipt.get("complete")
    or project_receipt["id"] != project_id
    or project_receipt["clientId"] != project_client_id
    or project_receipt["repository"] != repository
    or project_receipt["role"] != "feature"
    or project_receipt["phase"] != scenario_phase
    or project_receipt["category"] != "completed"
    or set(project_receipt["issueIds"]) != increment_ids
    or project_receipt["issueStates"] != scenario["preconditions"]["issueStates"]
):
    fail("all-done project receipt is not exact and complete")
if any(issue["id"] in project_receipt["issueIds"] for issue in standalone):
    fail("standalone issue leaked into project completion")

ambiguous = copy.deepcopy(project["events"])
ambiguous.append(copy.deepcopy(fixture["failureCases"]["ambiguousPhaseEvent"]))
rejects("forked phase chain", lambda: validate_phase(ambiguous))

foreign_project_events = copy.deepcopy(project["events"])
next(
    event for event in foreign_project_events
    if event["id"] == "update-progress-app12-done"
)["envelope"]["repository"] = fixture["failureCases"]["foreignProjectEventRepository"]
rejects("foreign current project event", lambda: validate_phase(foreign_project_events))

unauthorized_design_events = copy.deepcopy(project["events"])
next(
    event for event in unauthorized_design_events
    if event["id"] == "update-spec-hardened"
)["actor"] = fixture["failureCases"]["unauthorizedDesignActor"]
rejects("design phase actor outside its authority", lambda: validate_phase(unauthorized_design_events))

unauthorized_progress_events = copy.deepcopy(project["events"])
next(
    event for event in unauthorized_progress_events
    if event["id"] == "update-progress-app12-done"
)["actor"] = fixture["failureCases"]["unauthorizedProjectActor"]
rejects(
    "project progress by a non-lead",
    lambda: validate_project_event_dispatch(validate_phase(unauthorized_progress_events)[1]),
)

malformed_progress_events = copy.deepcopy(project["events"])
next(
    event for event in malformed_progress_events
    if event["id"] == "update-progress-app12-done"
)["data"] = fixture["failureCases"]["malformedProjectProgressData"]
rejects(
    "status-invented project progress data",
    lambda: validate_project_event_dispatch(validate_phase(malformed_progress_events)[1]),
)

wrong_progress_relations = copy.deepcopy(project["events"])
next(
    event for event in wrong_progress_relations
    if event["id"] == "update-progress-app12-done"
)["envelope"]["relatedIds"] = fixture["failureCases"]["projectProgressWrongRelatedIds"]
rejects(
    "project progress without exact current evidence",
    lambda: validate_project_event_dispatch(validate_phase(wrong_progress_relations)[1]),
)

malformed_resolution_events = copy.deepcopy(project["events"])
next(
    event for event in malformed_resolution_events
    if event["id"] == "update-project-blocker-resolved"
)["envelope"]["relatedIds"] = (
    fixture["failureCases"]["malformedProjectBlockerResolvedRelatedIds"]
)
rejects(
    "project blocker resolution without verified resolution evidence",
    lambda: validate_project_event_dispatch(validate_phase(malformed_resolution_events)[1]),
)
malformed_resolution_completion = malformed_resolution_events + [
    copy.deepcopy(fixture["mutationReceipts"]["allDoneProjectScenario"]["donePhaseEvent"]),
]
rejects(
    "malformed blocker resolution project completion",
    lambda: project_completion_eligible(
        fixture["mutationReceipts"]["allDoneProjectScenario"]["preconditions"],
        increment_ids,
        malformed_resolution_completion,
    ),
)

wrong_project_handoff = copy.deepcopy(project["events"])
next(
    event for event in wrong_project_handoff
    if event["id"] == "update-project-handoff"
)["envelope"]["relatedIds"] = fixture["failureCases"]["projectHandoffWrongRelatedIds"]
rejects(
    "project handoff without exact current issue events",
    lambda: validate_project_event_dispatch(validate_phase(wrong_project_handoff)[1]),
)

wrong_project_decision = copy.deepcopy(project["events"])
next(
    event for event in wrong_project_decision
    if event["id"] == "update-restack-decision"
)["envelope"]["relatedIds"] = fixture["failureCases"]["projectDecisionWrongRelatedIds"]
rejects(
    "restack decision without exact authorization relations",
    lambda: validate_project_event_dispatch(validate_phase(wrong_project_decision)[1]),
)

malformed_project_decision = copy.deepcopy(project["events"])
next(
    event for event in malformed_project_decision
    if event["id"] == "update-restack-decision"
)["data"] = fixture["failureCases"]["malformedProjectDecisionData"]
rejects(
    "malformed restack decision payload",
    lambda: validate_project_event_dispatch(validate_phase(malformed_project_decision)[1]),
)

for non_phase_kind in sorted(NON_PHASE):
    source_id = next(
        event["id"] for event in project["events"]
        if event["envelope"]["event"] == non_phase_kind
    )

    foreign_actor_events = copy.deepcopy(project["events"])
    next(
        event for event in foreign_actor_events if event["id"] == source_id
    )["actor"] = fixture["failureCases"]["unauthorizedProjectActor"]
    rejects(
        f"{non_phase_kind} accepted a foreign pinned-lead actor",
        lambda foreign_actor_events=foreign_actor_events: validate_project_event_dispatch(
            validate_phase(foreign_actor_events)[1],
        ),
    )

    missing_relation_events = copy.deepcopy(project["events"])
    missing_relation_record = next(
        event for event in missing_relation_events if event["id"] == source_id
    )
    missing_relation_record["envelope"]["relatedIds"] = (
        missing_relation_record["envelope"]["relatedIds"][:-1]
    )
    rejects(
        f"{non_phase_kind} accepted a missing producer relation",
        lambda missing_relation_events=missing_relation_events: (
            validate_project_event_dispatch(validate_phase(missing_relation_events)[1])
        ),
    )

    extra_relation_events = copy.deepcopy(project["events"])
    extra_relation_record = next(
        event for event in extra_relation_events if event["id"] == source_id
    )
    extra_relation_record["envelope"]["relatedIds"] = sorted([
        *extra_relation_record["envelope"]["relatedIds"],
        "foreign-native-relation",
    ])
    rejects(
        f"{non_phase_kind} accepted an extra producer relation",
        lambda extra_relation_events=extra_relation_events: (
            validate_project_event_dispatch(validate_phase(extra_relation_events)[1])
        ),
    )

    stale_predecessor_events = copy.deepcopy(project["events"])
    next(
        event for event in stale_predecessor_events if event["id"] == source_id
    )["envelope"]["predecessorId"] = "update-executing"
    rejects(
        f"{non_phase_kind} accepted a stale phase predecessor",
        lambda stale_predecessor_events=stale_predecessor_events: (
            validate_project_event_dispatch(validate_phase(stale_predecessor_events)[1])
        ),
    )

    partial_read_events = copy.deepcopy(project["events"])
    next(
        event for event in partial_read_events if event["id"] == source_id
    )["readComplete"] = False
    rejects(
        f"{non_phase_kind} accepted a partial native read-back",
        lambda partial_read_events=partial_read_events: (
            validate_project_event_dispatch(validate_phase(partial_read_events)[1])
        ),
    )

    payload_events = copy.deepcopy(project["events"])
    payload_record = next(
        event for event in payload_events if event["id"] == source_id
    )
    if non_phase_kind == "decision":
        payload_record["data"]["unexpectedProducerField"] = True
    else:
        payload_record["data"] = {}
    rejects(
        f"{non_phase_kind} accepted a producer payload mismatch",
        lambda payload_events=payload_events: validate_project_event_dispatch(
            validate_phase(payload_events)[1],
        ),
    )

mismatched_prs = copy.deepcopy(prs)
mismatched_prs[42]["body"] = fixture["failureCases"]["gitMismatchBody"]
rejects("Git/Linear attribution mismatch", lambda: validate_pr(increments[0], "increment", mismatched_prs))

if (
    validate_pr(increments[0], "increment")["number"] != 42
    or validate_pr(standalone[0], "work-item")["number"] != 51
):
    fail("valid role-derived Linear suffix was rejected")

retired_spec_bodies = fixture["failureCases"]["retiredSpecAttributionBodies"]
attribution_fixture_roles = {
    "increment": (increments[0], "increment"),
    "workItem": (standalone[0], "work-item"),
}
if set(retired_spec_bodies) != set(attribution_fixture_roles):
    fail("retired Spec attribution fixture role drift")
for fixture_role, (issue, validation_role) in attribution_fixture_roles.items():
    bodies = retired_spec_bodies[fixture_role]
    if set(bodies) != {"exact", "indented", "mixedCaseQuoted", "mixedCaseFenced"}:
        fail(f"retired Spec attribution variant drift for {fixture_role}")
    expected_suffix = (
        [f"Linear-Project: {project_client_id}", f"Linear-Issue: {issue['identifier']}"]
        if validation_role == "increment"
        else [f"Linear-Issue: {issue['identifier']}"]
    )
    for variant, body in bodies.items():
        fixture_nonblank = [line for line in body.splitlines() if line.strip()]
        if fixture_nonblank[-len(expected_suffix):] != expected_suffix:
            fail(f"{fixture_role} {variant} fixture lacks its otherwise-valid Linear suffix")
        variant_prs = copy.deepcopy(prs)
        variant_prs[issue["pullRequestNumber"]]["body"] = body
        reconciliation_plan = []
        mutation_attempts = []

        def attempt_status_reconciliation():
            validate_pr(issue, validation_role, variant_prs)
            reconciliation_plan.append(issue["id"])
            mutation_attempts.append(issue["id"])

        rejects(
            f"{fixture_role} {variant} retired Spec attribution",
            attempt_status_reconciliation,
        )
        if reconciliation_plan or mutation_attempts:
            fail(f"{fixture_role} {variant} crossed the attribution mutation gate")

partial = copy.deepcopy(fixture)
partial["policy"]["paginationComplete"][fixture["failureCases"]["partialCollection"]] = False
rejects("partial provider collection", lambda: validate_complete(partial))

missing_relation_collection = copy.deepcopy(fixture["linearPullRequestRelations"])
missing_relation_collection["records"] = [
    record for record in missing_relation_collection["records"]
    if record["id"] != fixture["failureCases"]["missingLinearPrRelationId"]
]
missing_relation_records = validate_linear_pr_relation_collection(
    missing_relation_collection,
)
rejects(
    "missing native Linear PR relation",
    lambda: resolve_linear_pr_relation(
        increments[0], 42, issue_prs[increments[0]["id"]]["url"],
        records=missing_relation_records,
    ),
)

partial_relation_collection = copy.deepcopy(fixture["linearPullRequestRelations"])
partial_relation_collection["records"][0]["readComplete"] = (
    fixture["failureCases"]["partialLinearPrRelationReadComplete"]
)
rejects(
    "partial native Linear PR relation read-back",
    lambda: validate_linear_pr_relation_collection(partial_relation_collection),
)

duplicate_relation_collection = copy.deepcopy(fixture["linearPullRequestRelations"])
duplicate_relation_collection["records"].append(
    copy.deepcopy(fixture["failureCases"]["duplicateLinearPrRelation"]),
)
duplicate_relation_records = validate_linear_pr_relation_collection(
    duplicate_relation_collection,
)
rejects(
    "duplicate native Linear PR relation",
    lambda: resolve_linear_pr_relation(
        increments[0], 42, issue_prs[increments[0]["id"]]["url"],
        records=duplicate_relation_records,
    ),
)

foreign_relation_collection = copy.deepcopy(fixture["linearPullRequestRelations"])
foreign_relation_collection["records"][0]["repository"] = (
    fixture["failureCases"]["foreignLinearPrRelationRepository"]
)
rejects(
    "foreign native Linear PR relation",
    lambda: validate_linear_pr_relation_collection(foreign_relation_collection),
)

stale_relation_collection = copy.deepcopy(fixture["linearPullRequestRelations"])
stale_relation_collection["records"][0]["createdAt"] = (
    fixture["failureCases"]["staleLinearPrRelationCreatedAt"]
)
stale_relation_collection["records"][0]["updatedAt"] = (
    fixture["failureCases"]["staleLinearPrRelationCreatedAt"]
)
stale_relation_records = validate_linear_pr_relation_collection(
    stale_relation_collection,
)
rejects(
    "stale native Linear PR relation at review event",
    lambda: resolve_linear_pr_relation(
        increments[0], 42, issue_prs[increments[0]["id"]]["url"],
        records=stale_relation_records,
        at=instant(next(
            event["createdAt"] for event in increments[0]["events"]
            if event["envelope"]["event"] == "reviewResult"
        )),
    ),
)

malformed_implementation = copy.deepcopy(increments[0])
coding_worker_implementation = copy.deepcopy(increments[0])
next(
    event for event in coding_worker_implementation["events"]
    if event["envelope"]["event"] == "implementationEvidence"
)["actor"] = fixture["failureCases"]["implementationCodingWorkerActor"]
rejects(
    "coding worker authored implementationEvidence",
    lambda: validate_issue_resource(coding_worker_implementation, "increment"),
)

foreign_canonical_event = copy.deepcopy(increments[0])
next(
    event for event in foreign_canonical_event["events"]
    if event["envelope"]["event"] == "precommitReview"
)["envelope"]["issueId"] = fixture["failureCases"]["precommitReviewForeignIssueId"]
rejects(
    "foreign canonical issue event",
    lambda: validate_issue_resource(foreign_canonical_event, "increment"),
)

unsupported_canonical_event = copy.deepcopy(increments[0])
next(
    event for event in unsupported_canonical_event["events"]
    if event["envelope"]["event"] == "precommitReview"
)["envelope"]["event"] = fixture["failureCases"]["unsupportedIssueEventKind"]
rejects(
    "unsupported canonical issue event fallthrough",
    lambda: validate_issue_resource(unsupported_canonical_event, "increment"),
)
required_payload_field = {
    "acceptance": "issueId",
    "assignmentAccepted": "issueId",
    "blocked": "issueId",
    "decisionRequest": "issueId",
    "decisionResponse": "issueId",
    "failure": "issueId",
    "handoff": "issueId",
    "implementationEvidence": "baseCommitSha",
    "issueDone": "pullRequestNumber",
    "precommitReview": "issueId",
    "restackAuthorized": "operationId",
    "reviewResult": "issueId",
    "unblocked": "issueId",
    "verification": "issueId",
}
for canonical_kind in sorted(ISSUE_EVENTS):
    source_issue = next(
        issue for issue in all_issues
        if any(
            event["envelope"]["event"] == canonical_kind
            for event in issue["events"]
        )
    )
    malformed_canonical = copy.deepcopy(source_issue)
    next(
        event for event in malformed_canonical["events"]
        if event["envelope"]["event"] == canonical_kind
    )["data"]["unexpectedCanonicalField"] = True
    rejects(
        f"{canonical_kind} payload accepted an unrecognized field",
        lambda malformed_canonical=malformed_canonical: validate_issue_resource(
            malformed_canonical, malformed_canonical["envelope"]["role"],
        ),
    )
    missing_canonical = copy.deepcopy(source_issue)
    next(
        event for event in missing_canonical["events"]
        if event["envelope"]["event"] == canonical_kind
    )["data"].pop(required_payload_field[canonical_kind])
    rejects(
        f"{canonical_kind} payload accepted a missing canonical field",
        lambda missing_canonical=missing_canonical: validate_issue_resource(
            missing_canonical, missing_canonical["envelope"]["role"],
        ),
    )
    foreign_actor_canonical = copy.deepcopy(source_issue)
    next(
        event for event in foreign_actor_canonical["events"]
        if event["envelope"]["event"] == canonical_kind
    )["actor"] = fixture["failureCases"]["precommitReviewWrongActor"]
    rejects(
        f"{canonical_kind} accepted a foreign actor",
        lambda foreign_actor_canonical=foreign_actor_canonical: validate_issue_resource(
            foreign_actor_canonical, foreign_actor_canonical["envelope"]["role"],
        ),
    )
    foreign_relation_canonical = copy.deepcopy(source_issue)
    relation_event = next(
        event for event in foreign_relation_canonical["events"]
        if event["envelope"]["event"] == canonical_kind
    )
    relation_event["envelope"]["relatedIds"] = sorted([
        *relation_event["envelope"]["relatedIds"],
        "foreign-relation-receipt",
    ])
    rejects(
        f"{canonical_kind} accepted a foreign relation",
        lambda foreign_relation_canonical=foreign_relation_canonical: (
            validate_issue_resource(
                foreign_relation_canonical,
                foreign_relation_canonical["envelope"]["role"],
            )
        ),
    )
next(
    event for event in malformed_implementation["events"]
    if event["envelope"]["event"] == "implementationEvidence"
)["data"] = fixture["failureCases"]["malformedImplementationEvidenceData"]
rejects(
    "non-canonical implementationEvidence payload",
    lambda: validate_issue_resource(malformed_implementation, "increment"),
)

app12_review = latest_event(increments[0], "reviewResult")
app12_before = next(issue for issue in pre_append_issues if issue["id"] == increments[0]["id"])
if not validate_review_result(increments[0], app12_review, issue_prs[increments[0]["id"]]):
    fail("complete current-head sweep reviewResult was not accepted")
app12_native_review = github_reviews[app12_review["data"]["githubReviewId"]]
if not (
    instant(app12_native_review["submittedAt"])
    < instant(app12_review["createdAt"])
):
    fail("fixture does not prove an earlier full-review receipt is accepted")
future_review_receipts = copy.deepcopy(github_reviews)
future_review_receipts[app12_review["data"]["githubReviewId"]]["submittedAt"] = (
    fixture["failureCases"]["reviewReceiptAfterEventAt"]
)
rejects(
    "reviewResult accepted a native full-review receipt from the future",
    lambda: validate_review_result(
        increments[0], app12_review, issue_prs[increments[0]["id"]],
        future_review_receipts,
    ),
)

strict_verification_ids = []
strict_precommit_ids = []
for issue in all_issues:
    current_precommit = latest_event(issue, "precommitReview")
    if current_precommit is not None:
        validate_precommit_review(issue, current_precommit)
        strict_precommit_ids.append(current_precommit["id"])
if strict_precommit_ids != expected["strictPrecommitReviewEventIds"]:
    fail("strict current precommitReview set drift")
for issue in all_issues:
    post_pr_review_ids = {
        event["id"] for event in issue["events"]
        if event["envelope"]["event"] == "reviewResult"
    }
    for implementation in (
        event for event in issue["events"]
        if event["envelope"]["event"] == "implementationEvidence"
    ):
        if post_pr_review_ids & set(implementation["envelope"]["relatedIds"]):
            fail("implementationEvidence reverse-bound post-PR reviewResult")

first_execution_order = [
    event["envelope"]["event"] for event in increments[0]["events"]
    if event["envelope"]["event"] in {
        "assignmentAccepted", "verification", "precommitReview",
        "implementationEvidence", "reviewResult",
    }
][0:5]
if first_execution_order != expected["normalFirstExecutionOrder"]:
    fail("first execution did not review the uncommitted diff before implementation")

app12_precommit = latest_event(increments[0], "precommitReview")
for data_field, fixture_field in (
    ("issueId", "precommitReviewForeignIssueId"),
    ("actor", "precommitReviewWrongActor"),
):
    malformed_precommit = copy.deepcopy(app12_precommit)
    malformed_value = fixture["failureCases"][fixture_field]
    if data_field == "actor":
        malformed_value = {
            "principalKind": malformed_value["kind"],
            "principalId": malformed_value["principalId"],
        }
    malformed_precommit["data"][data_field] = malformed_value
    rejects(
        f"precommitReview with invalid {data_field}",
        lambda malformed_precommit=malformed_precommit: validate_precommit_review(
            increments[0], malformed_precommit,
        ),
    )
coding_worker_precommit = copy.deepcopy(app12_precommit)
coding_worker_precommit["actor"] = fixture["failureCases"]["implementationCodingWorkerActor"]
coding_worker_precommit["data"]["actor"] = {
    "principalKind": coding_worker_precommit["actor"]["kind"],
    "principalId": coding_worker_precommit["actor"]["principalId"],
}
rejects(
    "coding worker authored precommitReview",
    lambda: validate_precommit_review(increments[0], coding_worker_precommit),
)
future_precommit = copy.deepcopy(app12_precommit)
future_precommit["data"].update(fixture["failureCases"]["precommitReviewFutureFields"])
rejects(
    "precommitReview contains future commit or PR receipt",
    lambda: validate_precommit_review(increments[0], future_precommit),
)
receipt_hash_mismatch = copy.deepcopy(app12_precommit)
receipt_hash_mismatch["data"]["reviewerReceipts"][0]["reviewedDiffHash"] = (
    fixture["failureCases"]["precommitReviewReceiptHashMismatch"]
)
rejects(
    "precommitReview reviewer receipt diff mismatch",
    lambda: validate_precommit_review(increments[0], receipt_hash_mismatch),
)
wrong_precommit_relations = copy.deepcopy(app12_precommit)
wrong_precommit_relations["envelope"]["relatedIds"] = (
    fixture["failureCases"]["precommitReviewWrongRelatedIds"]
)
rejects(
    "precommitReview without exact assignment and verification relations",
    lambda: validate_precommit_review(increments[0], wrong_precommit_relations),
)
rejects(
    "terminal eligibility with invalid precommitReview",
    lambda: terminal_eligible(
        app12_before, precommit_override=wrong_precommit_relations,
    ),
)
missing_precommit_reverse_binding = copy.deepcopy(
    latest_event(increments[0], "implementationEvidence")
)
missing_precommit_reverse_binding["envelope"]["relatedIds"] = (
    fixture["failureCases"]["implementationMissingPrecommitRelatedIds"]
)
rejects(
    "implementationEvidence without precommitReview reverse binding",
    lambda: validate_precommit_review(
        increments[0], app12_precommit,
        implementation_override=missing_precommit_reverse_binding,
    ),
)
for issue in all_issues:
    current_verification = latest_event(issue, "verification")
    if current_verification is not None:
        validate_verification(issue, current_verification)
        strict_verification_ids.append(current_verification["id"])
if strict_verification_ids != expected["strictVerificationEventIds"]:
    fail("strict current verification set drift")

app12_verification = latest_event(increments[0], "verification")
minimal_verification = copy.deepcopy(app12_verification)
minimal_verification["data"] = fixture["failureCases"]["minimalVerificationData"]
rejects(
    "minimal verification terminal eligibility",
    lambda: terminal_eligible(
        app12_before, verification_override=minimal_verification,
    ),
)

for data_field, fixture_field in (
    ("issueId", "verificationForeignIssueId"),
    ("actor", "verificationWrongActor"),
):
    invalid_verification = copy.deepcopy(app12_verification)
    invalid_verification["data"][data_field] = fixture["failureCases"][fixture_field]
    rejects(
        f"verification with invalid {data_field}",
        lambda invalid_verification=invalid_verification: terminal_eligible(
            app12_before, verification_override=invalid_verification,
        ),
    )

obsolete_kind_verification = copy.deepcopy(app12_verification)
obsolete_kind_verification["data"]["actor"] = (
    fixture["failureCases"]["verificationObsoleteActor"]
)
rejects(
    "verification payload actor retained obsolete kind",
    lambda: terminal_eligible(
        app12_before, verification_override=obsolete_kind_verification,
    ),
)

future_verification = copy.deepcopy(app12_verification)
future_verification["data"].update(
    fixture["failureCases"]["verificationFutureImplementationFields"]
)
rejects(
    "verification predicting future implementation identity",
    lambda: terminal_eligible(
        app12_before, verification_override=future_verification,
    ),
)

wrong_verification_relations = copy.deepcopy(app12_verification)
wrong_verification_relations["envelope"]["relatedIds"] = (
    fixture["failureCases"]["verificationWrongRelatedIds"]
)
rejects(
    "verification without positive current assignment relation",
    lambda: terminal_eligible(
        app12_before, verification_override=wrong_verification_relations,
    ),
)
missing_verification_reverse_binding = copy.deepcopy(
    latest_event(increments[0], "implementationEvidence")
)
missing_verification_reverse_binding["envelope"]["relatedIds"] = (
    fixture["failureCases"]["implementationMissingVerificationRelatedIds"]
)
rejects(
    "implementationEvidence without verification reverse binding",
    lambda: validate_verification(
        increments[0],
        app12_verification,
        implementation_override=missing_verification_reverse_binding,
    ),
)
partial_verification = copy.deepcopy(app12_verification)
partial_verification["readComplete"] = fixture["failureCases"]["partialVerificationReadComplete"]
rejects(
    "verification with partial independent receipt",
    lambda: terminal_eligible(
        app12_before, verification_override=partial_verification,
    ),
)

app13_sweep_verification = latest_event(increments[1], "verification")
wrong_sweep_verification_actor = copy.deepcopy(app13_sweep_verification)
wrong_sweep_verification_actor["actor"] = (
    fixture["failureCases"]["sweepVerificationWrongNativeActor"]
)
rejects(
    "sweep-authorized verification used the owner instead of controller",
    lambda: validate_verification(increments[1], wrong_sweep_verification_actor),
)

missing_sweep_authorization = copy.deepcopy(app13_sweep_verification)
missing_sweep_authorization["envelope"]["relatedIds"] = (
    fixture["failureCases"]["sweepVerificationMissingAuthorizationRelatedIds"]
)
rejects(
    "sweep-authorized verification omitted authorization relation",
    lambda: validate_verification(increments[1], missing_sweep_authorization),
)

outside_sweep_window = copy.deepcopy(app13_sweep_verification)
outside_sweep_window["createdAt"] = (
    fixture["failureCases"]["sweepVerificationOutsideWindowAt"]
)
rejects(
    "sweep-authorized verification was outside authorization window",
    lambda: validate_verification(increments[1], outside_sweep_window),
)

stale_authorized_verification_binding = copy.deepcopy(
    latest_event(increments[1], "implementationEvidence"),
)
stale_authorized_verification_binding["envelope"]["relatedIds"] = (
    fixture["failureCases"]["implementationStaleVerificationRelatedIds"]
)
rejects(
    "rewrite implementation bound stale pre-authorization verification",
    lambda: validate_current_implementation(
        increments[1], issue_prs[increments[1]["id"]],
        stale_authorized_verification_binding,
    ),
)

app13_pre_handoff_implementation = next(
    event for event in increments[1]["events"]
    if event["id"] == expected["restackHistoricalImplementationId"]
)
validate_historical_implementation(
    increments[1], app13_pre_handoff_implementation,
)
if increments[1]["owner"] == implementation_producer_records(
    increments[1], app13_pre_handoff_implementation,
)[0]["actor"]:
    fail("owner handoff fixture did not change the current owner")
present_assignment_historical_implementation = copy.deepcopy(
    app13_pre_handoff_implementation,
)
present_assignment_historical_implementation["envelope"]["relatedIds"] = (
    fixture["failureCases"]["implementationPresentAssignmentRelatedIds"]
)
rejects(
    "historical implementation evidence validated against present assignment",
    lambda: validate_historical_implementation(
        increments[1], present_assignment_historical_implementation,
    ),
)

app13_restack = next(
    event for event in events_of(increments[1], "restackAuthorized")
    if event["id"] == expected["consumedRestackAuthorizationEventIds"][0]
)
restack_details = validate_restack_authorized(
    increments[1], app13_restack, issue_prs[increments[1]["id"]],
)
if (
    restack_details["operationId"] != expected["restackOperationId"]
    or restack_details["authorizationOwner"]
    != expected["restackHistoricalAuthorizationOwner"]
    or restack_details["currentOwner"] != expected["restackCurrentOwner"]
    or restack_details["assignmentEventId"] != "comment-app13-assignment"
    or restack_details["consumed"] is not True
    or restack_details["historicalImplementationId"]
    != expected["restackHistoricalImplementationId"]
    or restack_details["resultingImplementationId"]
    != expected["restackResultingImplementationId"]
    or restack_details["resultingHeadSha"]
    != expected["restackResultingHeadSha"]
    or restack_details["historicalPrecommitReviewId"]
    != expected["restackHistoricalPrecommitReviewId"]
    or restack_details["currentPrecommitReviewId"]
    != expected["restackCurrentPrecommitReviewId"]
    or terminal_eligible(increments[1])
):
    fail("canonical consumed restackAuthorized changed ownership or supplied terminal evidence")

app13_second_restack = next(
    event for event in events_of(increments[1], "restackAuthorized")
    if event["id"] == expected["consumedRestackAuthorizationEventIds"][1]
)
second_restack_details = validate_restack_authorized(
    increments[1], app13_second_restack, issue_prs[increments[1]["id"]],
)
if (
    second_restack_details["operationId"]
    != expected["secondRestackOperationId"]
    or second_restack_details["authorizationOwner"]
    != expected["restackHistoricalAuthorizationOwner"]
    or second_restack_details["currentOwner"]
    != expected["restackCurrentOwner"]
    or second_restack_details["historicalImplementationId"]
    != expected["secondRestackHistoricalImplementationId"]
    or second_restack_details["resultingImplementationId"]
    != expected["secondRestackResultingImplementationId"]
    or second_restack_details["currentImplementationId"]
    != expected["secondRestackResultingImplementationId"]
    or second_restack_details["consumed"] is not True
):
    fail("second canonical restack authorization/consumer drift")

present_owner_historical_authorization = copy.deepcopy(app13_restack)
present_owner_historical_authorization["actor"] = increments[1]["owner"]
rejects(
    "historical authorization validated against present owner",
    lambda: validate_restack_authorized(
        increments[1], present_owner_historical_authorization,
        issue_prs[increments[1]["id"]],
    ),
)
wrong_restack_revision_author = copy.deepcopy(increments[1])
next(
    event for event in wrong_restack_revision_author["events"]
    if event["id"] == expected["restackResultingImplementationId"]
)["actor"] = increments[1]["owner"]
rejects(
    "restack implementation revision not authored by named controller",
    lambda: validate_issue_resource(wrong_restack_revision_author, "increment"),
)
inactive_restack = next(
    event for event in events_of(increments[1], "restackAuthorized")
    if event["id"] == expected["inactiveRestackAuthorizationEventIds"][0]
)
inactive_restack_details = validate_restack_authorized(
    increments[1], inactive_restack, issue_prs[increments[1]["id"]],
)
if (
    inactive_restack_details["consumed"]
    or not inactive_restack_details["inactive"]
    or inactive_restack["data"]["affectedRelationIds"]
):
    fail("expired unconsumed empty-scope authorization poisoned status")
expired_authorization_consumer = copy.deepcopy(
    latest_event(increments[1], "implementationEvidence")
)
expired_authorization_consumer["createdAt"] = (
    fixture["failureCases"]["inactiveRestackCompletionAfterExpiry"]
)
expired_authorization_consumer["actor"] = expected_controller(inactive_restack["data"])
expired_authorization_consumer["envelope"]["relatedIds"] = sorted([
    *expired_authorization_consumer["envelope"]["relatedIds"],
    inactive_restack["id"],
])
rejects(
    "expired unconsumed authorization authorized a later mutation",
    lambda: validate_restack_authorized(
        increments[1],
        inactive_restack,
        issue_prs[increments[1]["id"]],
        consumer_override=expired_authorization_consumer,
    ),
)
validate_affected_scope([increments[1]["id"]], [])
rejects(
    "cross-issue rewrite with empty affected relations",
    lambda: validate_affected_scope(
        fixture["failureCases"]["crossIssueDecisionEmptyAffectedRelations"][
            "affectedIssueIds"
        ],
        fixture["failureCases"]["crossIssueDecisionEmptyAffectedRelations"][
            "affectedRelationIds"
        ],
    ),
)
rejects(
    "issue-local relation rewrite with empty affected relations",
    lambda: validate_affected_scope([increments[1]["id"]], [], relation_rewrite=True),
)
wrong_restack_relations = copy.deepcopy(app13_restack)
wrong_restack_relations["envelope"]["relatedIds"] = (
    fixture["failureCases"]["restackWrongRelatedIds"]
)
rejects(
    "restackAuthorized with incomplete affected relations",
    lambda: validate_restack_authorized(
        increments[1], wrong_restack_relations, issue_prs[increments[1]["id"]],
    ),
)

malformed_restack_operation = copy.deepcopy(app13_restack)
malformed_restack_operation["data"]["operationId"] = (
    fixture["failureCases"]["malformedRestackOperationId"]
)
rejects(
    "restackAuthorized with malformed operation UUID",
    lambda: validate_restack_authorized(
        increments[1], malformed_restack_operation, issue_prs[increments[1]["id"]],
    ),
)

wrong_historical_restack = copy.deepcopy(app13_restack)
wrong_historical_restack["data"]["headCommitSha"] = (
    fixture["failureCases"]["restackHistoricalHeadMismatch"]
)
rejects(
    "restackAuthorized without immutable historical head A",
    lambda: validate_restack_authorized(
        increments[1], wrong_historical_restack, issue_prs[increments[1]["id"]],
    ),
)

wrong_current_restack_pr = copy.deepcopy(issue_prs[increments[1]["id"]])
wrong_current_restack_pr["headSha"] = fixture["failureCases"]["restackCurrentHeadMismatch"]
rejects(
    "historical authorization accepted without separately valid current head",
    lambda: validate_restack_authorized(
        increments[1], app13_restack, wrong_current_restack_pr,
    ),
)

missing_consumption_relation = copy.deepcopy(next(
    event for event in increments[1]["events"]
    if event["id"] == expected["restackResultingImplementationId"]
))
missing_consumption_relation["envelope"]["relatedIds"] = (
    fixture["failureCases"]["restackMissingConsumptionRelatedIds"]
)
rejects(
    "consumed restackAuthorized without implementation relation",
    lambda: validate_restack_authorized(
        increments[1],
        app13_restack,
        issue_prs[increments[1]["id"]],
        consumer_override=missing_consumption_relation,
    ),
)
if instant(next(
    event for event in increments[1]["events"]
    if event["id"] == expected["restackResultingImplementationId"]
)["createdAt"]) != timestamp(
    app13_restack["data"]["expiresAt"]
):
    fail("fixture does not cover inclusive completion-at-expiry")

duplicate_authorization_consumer = copy.deepcopy(
    latest_event(increments[1], "implementationEvidence"),
)
duplicate_authorization_consumer["envelope"]["relatedIds"] = sorted([
    *duplicate_authorization_consumer["envelope"]["relatedIds"],
    app13_restack["id"],
])
rejects(
    "restack authorization consumed by more than one implementation revision",
    lambda: validate_restack_authorized(
        increments[1], app13_restack, issue_prs[increments[1]["id"]],
        consumer_override=duplicate_authorization_consumer,
    ),
)

latest_revision_substitution = copy.deepcopy(
    next(
        event for event in increments[1]["events"]
        if event["id"] == expected["restackHistoricalImplementationId"]
    )
)
latest_revision_substitution["envelope"]["relatedIds"] = (
    fixture["failureCases"]["restackHistoricalUsesCurrentPrecommitRelatedIds"]
)
rejects(
    "latest-by-kind substituted for exact historical related revision",
    lambda: validate_restack_authorized(
        increments[1],
        app13_restack,
        issue_prs[increments[1]["id"]],
        historical_implementation_override=latest_revision_substitution,
    ),
)
for label, completion_time in (
    ("completion at authorization timestamp", app13_restack["createdAt"]),
    ("completion after authorization expiry", fixture["failureCases"]["restackCompletionAfterExpiry"]),
):
    out_of_window_implementation = copy.deepcopy(next(
        event for event in increments[1]["events"]
        if event["id"] == expected["restackResultingImplementationId"]
    ))
    out_of_window_implementation["createdAt"] = completion_time
    rejects(
        label,
        lambda out_of_window_implementation=out_of_window_implementation: (
            validate_restack_authorized(
                increments[1],
                app13_restack,
                issue_prs[increments[1]["id"]],
                consumer_override=out_of_window_implementation,
            )
        ),
    )

app13_review_families = validate_review_round_families(increments[1])
if [
    [event["envelope"]["clientId"], event["data"]["round"], event["id"]]
    for event in app13_review_families
] != expected["app13CurrentReviewFamilies"]:
    fail("multiple reviewResult client families drift")
app13_selected_review = select_current_review_result(
    increments[1], issue_prs[increments[1]["id"]],
)
if (
    app13_selected_review["id"] != expected["app13SelectedReviewResultId"]
    or app13_selected_review["data"]["round"]
    != expected["app13SelectedReviewRound"]
):
    fail("latest valid current-head reviewResult selection drift")

duplicate_review_round_issue = copy.deepcopy(increments[1])
duplicate_round_event = copy.deepcopy(app13_selected_review)
duplicate_round_event["id"] = "comment-app13-review-duplicate-round"
duplicate_round_event["envelope"]["clientId"] = (
    fixture["failureCases"]["reviewDuplicateCurrentHeadClientId"]
)
duplicate_review_round_issue["events"].append(duplicate_round_event)
rejects(
    "two reviewResult client families claimed one full-review round",
    lambda: validate_issue_resource(duplicate_review_round_issue, "increment"),
)

nonmonotonic_review_issue = copy.deepcopy(increments[1])
next(
    event for event in nonmonotonic_review_issue["events"]
    if event["id"] == "comment-app13-review-restacked"
)["data"]["round"] = fixture["failureCases"]["reviewNonMonotonicRound"]
rejects(
    "reviewResult family rounds were not monotonic",
    lambda: validate_issue_resource(nonmonotonic_review_issue, "increment"),
)

minimal_review = copy.deepcopy(app12_review)
minimal_review["data"] = fixture["failureCases"]["minimalReviewResultData"]
rejects(
    "minimal PASS plus PR reviewResult terminal eligibility",
    lambda: terminal_eligible(app12_before, minimal_review),
)

for data_field, fixture_field in (
    ("reviewedHeadSha", "reviewStaleHeadSha"),
    ("committedDiffHash", "reviewStaleDiffHash"),
    ("issueId", "reviewForeignIssueId"),
    ("pullRequestNumber", "reviewForeignPullRequestNumber"),
    ("pullRequestUrl", "reviewForeignPullRequestUrl"),
):
    malformed_review = copy.deepcopy(app12_review)
    malformed_review["data"][data_field] = fixture["failureCases"][fixture_field]
    rejects(
        f"reviewResult with invalid {data_field}",
        lambda malformed_review=malformed_review: terminal_eligible(
            app12_before, malformed_review,
        ),
    )

wrong_review_relations = copy.deepcopy(app12_review)
wrong_review_relations["envelope"]["relatedIds"] = fixture["failureCases"]["reviewWrongRelatedIds"]
rejects(
    "reviewResult with foreign native review relation",
    lambda: terminal_eligible(app12_before, wrong_review_relations),
)

for missing_field in fixture["failureCases"]["reviewMissingFields"]:
    missing_review_field = copy.deepcopy(app12_review)
    missing_review_field["data"].pop(missing_field)
    rejects(
        f"reviewResult missing {missing_field}",
        lambda missing_review_field=missing_review_field: terminal_eligible(
            app12_before, missing_review_field,
        ),
    )

non_positive_round = copy.deepcopy(app12_review)
non_positive_round["data"]["round"] = fixture["failureCases"]["reviewNonPositiveRound"]
rejects(
    "reviewResult with non-positive round",
    lambda: terminal_eligible(app12_before, non_positive_round),
)

incomplete_review_receipts = copy.deepcopy(github_reviews)
for missing_field in fixture["failureCases"]["reviewReceiptMissingFields"]:
    incomplete_review_receipts[app12_review["data"]["githubReviewId"]].pop(missing_field)
rejects(
    "reviewResult with incomplete GitHub receipt thread state",
    lambda: terminal_eligible(
        app12_before, app12_review, incomplete_review_receipts,
    ),
)

partial_review_receipts = copy.deepcopy(github_reviews)
partial_review_receipts[app12_review["data"]["githubReviewId"]]["readComplete"] = (
    fixture["failureCases"]["partialReviewReceiptReadComplete"]
)
rejects(
    "reviewResult with partial GitHub receipt",
    lambda: terminal_eligible(app12_before, app12_review, partial_review_receipts),
)
non_full_review_receipts = copy.deepcopy(github_reviews)
non_full_review_receipts[app12_review["data"]["githubReviewId"]]["fullReview"] = (
    fixture["failureCases"]["nonFullReviewReceipt"]
)
rejects(
    "reviewResult without a complete full-review sweep receipt",
    lambda: terminal_eligible(app12_before, app12_review, non_full_review_receipts),
)


unresolved_review = copy.deepcopy(app12_review)
unresolved_review["data"]["unresolvedThreadIds"] = (
    fixture["failureCases"]["reviewUnresolvedThreadIds"]
)
unresolved_review_receipts = copy.deepcopy(github_reviews)
unresolved_review_receipts[app12_review["data"]["githubReviewId"]][
    "unresolvedThreadIds"
] = fixture["failureCases"]["reviewUnresolvedThreadIds"]
rejects(
    "accepted reviewResult with unresolved thread state",
    lambda: terminal_eligible(
        app12_before, unresolved_review, unresolved_review_receipts,
    ),
)

partial_review_event = copy.deepcopy(app12_review)
partial_review_event["readComplete"] = fixture["failureCases"]["partialReviewEventReadComplete"]
rejects(
    "partial reviewResult event terminal eligibility",
    lambda: terminal_eligible(app12_before, partial_review_event),
)

malformed_done = copy.deepcopy(increments[0])
next(
    event for event in malformed_done["events"]
    if event["envelope"]["event"] == "issueDone"
)["data"] = fixture["failureCases"]["malformedIssueDoneData"]
rejects(
    "malformed issueDone payload",
    lambda: validate_issue_resource(malformed_done, "increment"),
)

app12_done = events_of(increments[0], "issueDone")[0]
rejects(
    "issueDone with minimal verification",
    lambda: validate_issue_done(
        increments[0], app12_done, issue_prs[increments[0]["id"]],
        verification_override=minimal_verification,
    ),
)
rejects(
    "issueDone with invalid precommitReview",
    lambda: validate_issue_done(
        increments[0], app12_done, issue_prs[increments[0]["id"]],
        precommit_override=wrong_precommit_relations,
    ),
)
stale_done_head_review = copy.deepcopy(app12_review)
stale_done_head_review["data"]["reviewedHeadSha"] = fixture["failureCases"]["reviewStaleHeadSha"]
rejects(
    "issueDone with stale reviewed head",
    lambda: validate_issue_done(
        increments[0], app12_done, issue_prs[increments[0]["id"]],
        review_override=stale_done_head_review,
    ),
)
stale_done_diff_review = copy.deepcopy(app12_review)
stale_done_diff_review["data"]["committedDiffHash"] = fixture["failureCases"]["reviewStaleDiffHash"]
rejects(
    "issueDone with stale reviewed diff",
    lambda: validate_issue_done(
        increments[0], app12_done, issue_prs[increments[0]["id"]],
        review_override=stale_done_diff_review,
    ),
)
rejects(
    "issueDone with minimal PASS plus PR reviewResult",
    lambda: validate_issue_done(
        increments[0], app12_done, issue_prs[increments[0]["id"]],
        review_override=minimal_review,
    ),
)
rejects(
    "issueDone with partial GitHub review receipt",
    lambda: validate_issue_done(
        increments[0], app12_done, issue_prs[increments[0]["id"]],
        review_override=app12_review, reviews_by_id=partial_review_receipts,
    ),
)
wrong_related = copy.deepcopy(app12_done)
wrong_related["envelope"]["relatedIds"] = fixture["failureCases"]["issueDoneWrongRelatedIds"]
rejects(
    "issueDone with incomplete terminal evidence",
    lambda: validate_issue_done(increments[0], wrong_related, issue_prs[increments[0]["id"]]),
)

missing_done_relation = copy.deepcopy(app12_done)
missing_done_relation["envelope"]["relatedIds"] = [
    native_id for native_id in missing_done_relation["envelope"]["relatedIds"]
    if native_id != "linear-relation-app12-pr42"
]
rejects(
    "issueDone omitted independently read native Linear PR relation",
    lambda: validate_issue_done(
        increments[0], missing_done_relation, issue_prs[increments[0]["id"]],
    ),
)

wrong_relation_receipt = copy.deepcopy(receipts[0])
wrong_relation_receipt["linearPullRequestRelationId"] = (
    fixture["failureCases"]["syntheticLinearPrRelationId"]
)
rejects(
    "issueDone receipt named a synthetic or foreign PR relation",
    lambda: validate_issue_done(
        increments[0], app12_done, issue_prs[increments[0]["id"]],
        wrong_relation_receipt,
    ),
)

wrong_receipt = copy.deepcopy(receipts[0])
wrong_receipt["eventClientId"] = fixture["failureCases"]["issueDoneWrongReceiptClientId"]
rejects(
    "issueDone receipt identity mismatch",
    lambda: validate_issue_done(increments[0], app12_done, issue_prs[increments[0]["id"]], wrong_receipt),
)

if expected["issueWriteIds"] != [receipt["targetId"] for receipt in receipts]:
    fail("fixture expected write set drift")
if expected["secondReadIssueDoneEventIds"] != [
    event["id"] for event in events_of(increments[0], "issueDone")
]:
    fail("fixture second-read issueDone set drift")
if expected["projectWrite"] is not False:
    fail("baseline fixture must not complete the project")
if expected["standaloneProjectIds"] != []:
    fail("fixture gives standalone work a synthetic project")
if expected["unrelatedMutations"] != []:
    fail("fixture permits unrelated mutation")
if expected["output"] != "text":
    fail("fixture output must be text")

print("test-status: ok")
PY
