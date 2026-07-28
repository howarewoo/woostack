#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
# shellcheck source=../../woostack-init/scripts/path-args.sh
. "$ROOT/skills/woostack-init/scripts/path-args.sh"

if python3 -c 'import sys' >/dev/null 2>&1; then
  PYTHON=python3
elif python -c 'import sys' >/dev/null 2>&1; then
  PYTHON=python
else
  printf 'test-linear-plan-contract: python3 or python is required\n' >&2
  exit 1
fi
"$PYTHON" - "$(tool_path_arg "$PYTHON" "$ROOT")" <<'PY'
import copy
import json
import os
import sys
import uuid
from pathlib import Path

root = Path(sys.argv[1])
paths = {
    "plan": root / "skills/woostack-plan/SKILL.md",
    "planning": root / "skills/woostack-plan/references/linear-planning.md",
    "tdd": root / "skills/woostack-tdd/SKILL.md",
    "evals": root / "skills/woostack-plan/evals/evals.json",
    "fixture": root / "skills/woostack-plan/evals/fixtures/project-a.json",
    "test": root / "skills/woostack-build/tests/test-linear-plan-contract.sh",
    "runner": root / "skills/woostack-init/scripts/tests/run-tests.sh",
}
texts = {name: path.read_text(encoding="utf-8") for name, path in paths.items()}


def fail(message):
    raise SystemExit(f"test-linear-plan-contract: {message}")


def must(text, token, scope):
    if token not in text:
        fail(f"{scope} missing {token!r}")


if not os.access(paths["test"], os.X_OK):
    fail("contract test is not executable")
if texts["runner"].count("test-linear-plan-contract.sh") != 1:
    fail("contract test must be registered exactly once")

planning = texts["plan"] + "\n" + texts["planning"]
for required in (
    "official host-exposed Linear MCP",
    "one ownership-valid `feature` project",
    "stable client UUID",
    "unique positive integer ordinal",
    "exactly one Git parent declaration",
    "Ordinals are presentation order, never implicit dependency edges",
    "unknown or cross-project dependencies",
    "Independent tracks are explicit dependency roots",
    "`planning` project event",
    "`specApproved` native update ID as `predecessorId`",
    "ready → planning",
    "no implementation branch or pull request",
    "Reconcile by stable identity",
    "Preserve execution evidence verbatim",
    "independently read every",
    "never deletes or silently detaches a managed increment",
):
    must(planning, required, "Linear planning contract")

for forbidden in (
    "scripts/artifacts/linear.sh",
    "resolve-backend.sh",
    "artifacts.specPlan",
):
    if forbidden in planning:
        fail(f"Linear planning contract retains retired authority {forbidden!r}")

for required in (
    "verified feature project, verified increment issue",
    "complete read-back",
    "standalone issue or issue-only PR attribution is unsupported",
    "Official MCP only",
):
    must(texts["tdd"], required, "TDD Linear target contract")

evals = json.loads(texts["evals"])
cases = evals.get("cases", [])
expected_ids = [
    "reconciles-stable-increments-with-native-dependencies",
    "refuses-evidence-bearing-issue-removal",
    "enters-planning-before-reconciling-increments",
    "blocks-unavailable-or-partial-official-mcp",
    "blocks-wrong-project-role-or-repository",
    "blocks-duplicate-revisions-or-current-heads",
    "preserves-event-uuid-after-unknown-planning-outcome",
    "blocks-issue-mutation-on-incomplete-planning-readback",
    "stops-reconciliation-on-incomplete-issue-readback",
]
if [case.get("id") for case in cases] != expected_ids:
    fail("planning behavior corpus case set/order changed")

by_id = {case["id"]: case for case in cases}
assertions = {
    case_id: {
        assertion.get("pointer"): assertion.get("expected")
        for assertion in case.get("assertions", [])
        if assertion.get("kind") == "final-json-path-equals"
    }
    for case_id, case in by_id.items()
}
linear_only_ids = expected_ids[2:]
positive = assertions[linear_only_ids[0]]
if positive.get("/status") != "planning-complete":
    fail("positive reconciliation no longer completes planning")
if positive.get("/operationOrder", [])[:5] != [
    "verify-mcp-capabilities",
    "verify-project-identity",
    "verify-current-phase-chain",
    "build-desired-issue-graph",
    "append-planning",
]:
    fail("planning must be verified before issue reconciliation")
if positive.get("/allReadBacksVerified") is not True:
    fail("positive reconciliation lacks complete read-back")
if positive.get("/readyAppended") is not False:
    fail("plan must hand back in planning rather than append ready")
if positive.get("/repositoryMutationCount") != 0:
    fail("plan corpus permits repository mutation")

for case_id in linear_only_ids[1:]:
    observed = assertions[case_id]
    if observed.get("/status") != "blocked":
        fail(f"{case_id} must fail closed")
    if observed.get("/repositoryMutationCount") != 0:
        fail(f"{case_id} permits repository mutation")

unknown = assertions["preserves-event-uuid-after-unknown-planning-outcome"]
if (
    unknown.get("/replacementEventAllocated") is not False
    or unknown.get("/samePhaseRetryAllowed") is not False
    or unknown.get("/issueMutationIds") != []
):
    fail("unknown planning outcome does not preserve stable identity")

partial_issue = assertions["stops-reconciliation-on-incomplete-issue-readback"]
if (
    partial_issue.get("/stableIssueIdPreserved") is not True
    or partial_issue.get("/relationMutationIds") != []
    or partial_issue.get("/finalGraphAccepted") is not False
):
    fail("incomplete issue read-back does not stop reconciliation safely")

fixture = json.loads(texts["fixture"])
records = [
    response["record"]
    for response in fixture.get("syntheticResponses", [])
    if response.get("operation") == "read-increment"
]
if len(records) != 2:
    fail("positive fixture must contain two independently read increments")
ordinals = [record["envelope"].get("ordinal") for record in records]
if ordinals != [1, 2] or len(set(ordinals)) != len(ordinals):
    fail("positive fixture increment ordinals are not unique and stable")
if records[0]["envelope"].get("dependencyNativeIds") != []:
    fail("positive fixture root must remain independent")
if records[1]["envelope"].get("dependencyNativeIds") != [records[0]["nativeId"]]:
    fail("positive fixture child dependency changed")
for record in records:
    contract = record.get("contract", {})
    required_contract = {
        "objective",
        "filesAndResponsibilities",
        "tasks",
        "acceptanceCriteria",
        "acceptanceCoverage",
        "automatedVerification",
        "manualVerification",
        "gitParent",
    }
    if not required_contract <= set(contract):
        fail(f"{record['nativeId']} has an incomplete exact issue contract")
    if [task.get("phase") for task in contract["tasks"]] != ["red", "green", "refactor"]:
        fail(f"{record['nativeId']} does not retain Red→Green→Refactor tasks")

def rejects(label, operation):
    try:
        operation()
    except ValueError:
        return
    fail(f"{label} was accepted")


def validate_issue_graph(
    existing,
    desired,
    read_backs,
    existing_relation_reads,
    relation_mutations,
    relation_reads,
    relation_deletions=(),
):
    if not desired:
        raise ValueError("empty issue graph")
    native_ids = [record["nativeId"] for record in desired]
    if len(native_ids) != len(set(native_ids)):
        raise ValueError("duplicate native issue identity")
    client_ids = [record["envelope"].get("clientId") for record in desired]
    if len(client_ids) != len(set(client_ids)):
        raise ValueError("duplicate stable issue identity")
    for client_id in client_ids:
        if not client_id or uuid.UUID(client_id).version != 4:
            raise ValueError("missing or malformed stable issue identity")
    ordinals = [record["envelope"].get("ordinal") for record in desired]
    if any(not isinstance(value, int) or value < 1 for value in ordinals):
        raise ValueError("invalid issue ordinal")
    if len(ordinals) != len(set(ordinals)):
        raise ValueError("duplicate issue ordinal")

    desired_by_native = {record["nativeId"]: record for record in desired}
    existing_by_native = {record["nativeId"]: record for record in existing}
    read_by_native = {record["nativeId"]: record for record in read_backs}
    if set(read_by_native) != set(desired_by_native):
        raise ValueError("incomplete issue read-back")
    for native_id, wanted in desired_by_native.items():
        observed = read_by_native[native_id]
        for field in ("workspace", "team"):
            if observed.get(field) != wanted.get(field):
                raise ValueError("ownership drift")
        for field in ("clientId", "projectId", "repository", "role", "ordinal"):
            if observed["envelope"].get(field) != wanted["envelope"].get(field):
                raise ValueError("managed envelope read-back mismatch")
        if observed.get("contract") != wanted.get("contract"):
            raise ValueError("readable issue description mismatch")
        if native_id in existing_by_native:
            before = existing_by_native[native_id]
            if before["envelope"].get("clientId") != wanted["envelope"].get("clientId"):
                raise ValueError("replan changed stable issue identity")
            for field in ("workspace", "team"):
                if before.get(field) != wanted.get(field):
                    raise ValueError("replan changed issue ownership")
            for field in ("projectId", "repository", "role"):
                if before["envelope"].get(field) != wanted["envelope"].get(field):
                    raise ValueError("replan changed issue authority")

        contract = wanted.get("contract", {})
        criteria = {item.get("id") for item in contract.get("acceptanceCriteria", [])}
        coverage = contract.get("acceptanceCoverage", [])
        if not criteria or {item.get("criterionId") for item in coverage} != criteria:
            raise ValueError("acceptance coverage mismatch")
        phases = {task.get("phase") for task in contract.get("tasks", [])}
        task_commands = {task.get("command") for task in contract.get("tasks", [])}
        manual_steps = {item.get("step") for item in contract.get("manualVerification", [])}
        for mapping in coverage:
            if (
                mapping.get("redTaskPhase") not in phases
                or mapping.get("greenTaskPhase") not in phases
                or mapping.get("automatedVerificationCommand") not in task_commands
                or mapping.get("manualVerificationStep") not in manual_steps
            ):
                raise ValueError("acceptance criterion is not mapped to executable evidence")

    removed = set(existing_by_native) - set(desired_by_native)
    for native_id in removed:
        prior = existing_by_native[native_id]
        if any(
            key in prior.get("contract", {})
            for key in (
                "branch",
                "pullRequest",
                "assignmentAcceptance",
                "implementationEvidence",
                "reviewEvidence",
                "verificationEvidence",
                "acceptanceEvidence",
                "failureEvidence",
            )
        ):
            raise ValueError("evidence-bearing issue removal")
        raise ValueError("managed issue removal")

    dependencies = {
        record["nativeId"]: set(record["envelope"].get("dependencyNativeIds", []))
        for record in desired
    }
    for native_id, dependency_ids in dependencies.items():
        if dependency_ids - set(desired_by_native):
            raise ValueError("unknown or cross-project dependency")
        parent = desired_by_native[native_id].get("contract", {}).get("gitParent")
        if not isinstance(parent, dict):
            raise ValueError("missing git parent")
        if not dependency_ids:
            if parent != {"kind": "projectBase", "freezeOwner": "woostack-build"}:
                raise ValueError("root has an unrepresentable git parent")
        elif (
            parent.get("kind") != "issue"
            or set(parent) != {"kind", "issueId"}
            or parent.get("issueId") not in dependency_ids
        ):
            raise ValueError("child has an unrepresentable git parent")

    visiting = set()
    visited = set()

    def visit(native_id):
        if native_id in visiting:
            raise ValueError("dependency cycle")
        if native_id in visited:
            return
        visiting.add(native_id)
        for dependency_id in dependencies[native_id]:
            visit(dependency_id)
        visiting.remove(native_id)
        visited.add(native_id)

    for native_id in dependencies:
        visit(native_id)

    expected_relations = {
        (native_id, dependency_id, "depends-on")
        for native_id, dependency_ids in dependencies.items()
        for dependency_id in dependency_ids
    }
    if existing_relation_reads is None:
        raise ValueError("existing relation discovery outcome is unknown")
    if relation_mutations is None or relation_deletions is None:
        raise ValueError("relation mutation outcome is unknown")
    existing_relations = {
        (
            item["record"].get("fromNativeId"),
            item["record"].get("toNativeId"),
            item["record"].get("relation"),
        )
        for item in existing_relation_reads
    }
    created_relations = {
        (item.get("fromNativeId"), item.get("toNativeId"), item.get("relation"))
        for item in relation_mutations
    }
    deleted_relations = {
        (item.get("fromNativeId"), item.get("toNativeId"), item.get("relation"))
        for item in relation_deletions
    }
    if (
        not isinstance(relation_reads, dict)
        or not relation_reads.get("readComplete")
        or not relation_reads.get("paginationComplete")
    ):
        raise ValueError("final relation snapshot is incomplete")
    observed_relations = {
        (
            item.get("fromNativeId"),
            item.get("toNativeId"),
            item.get("relation"),
        )
        for item in relation_reads.get("records", [])
    }
    if created_relations != expected_relations - existing_relations:
        raise ValueError("native relation create delta mismatch")
    if deleted_relations != existing_relations - expected_relations:
        raise ValueError("native relation delete delta mismatch")
    if observed_relations != expected_relations:
        raise ValueError("native relation read-back mismatch")


responses = fixture["syntheticResponses"]
existing_relation_responses = [
    response for response in responses if response.get("operation") == "read-existing-relations"
]
if len(existing_relation_responses) != 1 or not existing_relation_responses[0].get("paginationComplete"):
    fail("initial relation discovery is missing or incomplete")
existing_relation_reads = [
    {"record": record} for record in existing_relation_responses[0].get("records", [])
]
relation_mutations = [
    response for response in responses if response.get("operation") == "create-relation"
]
final_relation_responses = [
    response for response in responses if response.get("operation") == "read-final-relations"
]
if len(final_relation_responses) != 1:
    fail("complete final relation snapshot is missing")
relation_reads = final_relation_responses[0]
final_relation_existing_reads = [
    {"record": record} for record in relation_reads.get("records", [])
]
empty_relation_snapshot = {"records": [], "readComplete": True, "paginationComplete": True}

# An approved replan may rewire an unstarted issue. Delete only `existing - desired`, then prove the
# deleted relation is absent from the complete final relation read.
rewired = copy.deepcopy(records)
rewired[1]["envelope"]["dependencyNativeIds"] = []
rewired[1]["contract"]["gitParent"] = {"kind": "projectBase", "freezeOwner": "woostack-build"}
relation_deletions = [
    {
        "fromNativeId": "issue-cache-72",
        "toNativeId": "issue-cache-71",
        "relation": "depends-on",
    }
]
validate_issue_graph(
    records,
    rewired,
    copy.deepcopy(rewired),
    final_relation_existing_reads,
    [],
    empty_relation_snapshot,
    relation_deletions,
)

rejects(
    "unknown relation create outcome",
    lambda: validate_issue_graph(
        records, records, copy.deepcopy(records), existing_relation_reads, None, relation_reads
    ),
)
rejects(
    "unknown relation delete outcome",
    lambda: validate_issue_graph(
        records, rewired, copy.deepcopy(rewired), final_relation_existing_reads, [], empty_relation_snapshot, None
    ),
)
validate_issue_graph([], records, records, existing_relation_reads, relation_mutations, relation_reads)

# Replanning independently discovers the existing full relation set and mutates no relation.
replanned = copy.deepcopy(records)
replanned[0]["envelope"]["ordinal"] = 2
replanned[1]["envelope"]["ordinal"] = 1
validate_issue_graph(
    records, replanned, copy.deepcopy(replanned), final_relation_existing_reads, [], relation_reads
)

rejects(
    "unknown existing relation discovery",
    lambda: validate_issue_graph(
        records, replanned, copy.deepcopy(replanned), None, [], relation_reads
    ),
)

duplicate_uuid = copy.deepcopy(records)
duplicate_uuid[1]["envelope"]["clientId"] = duplicate_uuid[0]["envelope"]["clientId"]
rejects(
    "duplicate stable client UUID",
    lambda: validate_issue_graph([], duplicate_uuid, duplicate_uuid, [], relation_mutations, relation_reads),
)
missing_uuid = copy.deepcopy(records)
missing_uuid[0]["envelope"]["clientId"] = None
rejects(
    "missing stable client UUID",
    lambda: validate_issue_graph([], missing_uuid, missing_uuid, [], relation_mutations, relation_reads),
)
changed_identity = copy.deepcopy(records)
changed_identity[0]["envelope"]["clientId"] = "70000000-0000-4000-8000-000000000001"
rejects(
    "replan identity change",
    lambda: validate_issue_graph(records, changed_identity, changed_identity, [], relation_mutations, relation_reads),
)
description_drift = copy.deepcopy(records)
description_drift[0]["contract"]["objective"] = "Different objective"
rejects(
    "readable issue description drift",
    lambda: validate_issue_graph([], records, description_drift, [], relation_mutations, relation_reads),
)
coverage_drift = copy.deepcopy(records)
coverage_drift[0]["contract"]["acceptanceCoverage"][0]["criterionId"] = "AC-foreign"
rejects(
    "acceptance mapping drift",
    lambda: validate_issue_graph([], coverage_drift, coverage_drift, [], relation_mutations, relation_reads),
)
missing_relation_read = {"records": [], "readComplete": False, "paginationComplete": False}
rejects(
    "missing native blocked-by read-back",
    lambda: validate_issue_graph([], records, records, [], relation_mutations, missing_relation_read),
)
wrong_parent = copy.deepcopy(records)
wrong_parent[1]["contract"]["gitParent"]["issueId"] = "issue-foreign"
rejects(
    "unrepresentable Git parent",
    lambda: validate_issue_graph([], wrong_parent, wrong_parent, [], relation_mutations, relation_reads),
)
cyclic = copy.deepcopy(records)
cyclic[0]["envelope"]["dependencyNativeIds"] = [cyclic[1]["nativeId"]]
cyclic[0]["contract"]["gitParent"] = {"kind": "issue", "issueId": cyclic[1]["nativeId"]}
cycle_relations = relation_mutations + [
    {
        "fromNativeId": cyclic[0]["nativeId"],
        "toNativeId": cyclic[1]["nativeId"],
        "relation": "depends-on",
    }
]
rejects(
    "dependency cycle",
    lambda: validate_issue_graph([], cyclic, cyclic, [], cycle_relations, relation_reads),
)
foreign = copy.deepcopy(records)
foreign[1]["envelope"]["dependencyNativeIds"] = ["issue-other-project"]
foreign[1]["contract"]["gitParent"]["issueId"] = "issue-other-project"
rejects(
    "cross-project dependency",
    lambda: validate_issue_graph([], foreign, foreign, [], relation_mutations, relation_reads),
)
ownership_drift = copy.deepcopy(records)
ownership_drift[0]["workspace"] = "Other"
rejects(
    "ownership drift",
    lambda: validate_issue_graph(records, ownership_drift, ownership_drift, [], relation_mutations, relation_reads),
)
evidence_bearing = copy.deepcopy(records)
evidence_bearing[1]["contract"]["implementationEvidence"] = {"commit": "abc123"}
rejects(
    "evidence-bearing issue removal",
    lambda: validate_issue_graph(evidence_bearing, evidence_bearing[:1], evidence_bearing[:1], [], [], []),
)
print("test-linear-plan-contract: ok")
PY
