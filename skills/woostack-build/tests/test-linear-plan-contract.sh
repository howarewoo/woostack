#!/usr/bin/env bash
# Structural contract for caller-selected Linear persistence and build-delegated planning.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import json
import re
import sys
import subprocess
from pathlib import Path

root = Path(sys.argv[1])
files = {
    "plan": root / "skills/woostack-plan/SKILL.md",
    "build": root / "skills/woostack-build/SKILL.md",
    "harden": root / "skills/woostack-harden/SKILL.md",
    "artifact": root / "skills/woostack-init/references/artifact-backends.md",
    "context": root / "skills/woostack-build/references/linear-context.md",
    "procedure": root / "skills/woostack-build/references/linear-procedure.md",
}
text = {
    name: re.sub(r"\s+", " ", path.read_text(encoding="utf-8"))
    for name, path in files.items()
}
failures = []

def require(name, needle):
    if needle not in text[name]:
        failures.append(f"{name}: missing {needle!r}")

def forbid(name, pattern):
    if re.search(pattern, text[name], re.I):
        failures.append(f"{name}: matches forbidden pattern {pattern!r}")

for needle in (
    "One approved specification in, one coherent plan out",
    "Explicit standalone persistence uses one project, one parent plan issue, and one child per increment",
    "independently read every mutation and hierarchy edge back",
    "never use artifact assignment/state/comments to authorize execution or prove completion",
    "Build-delegated planning performs no provider mutation",
    "build persists once after graph hardening",
    "Repository policy alone never selects artifact mode",
    "one unique positive ordinal",
    "duplicate task IDs or ordinals",
    "dependencies on unknown task IDs",
    "acceptance criteria not covered by any increment",
    "dependency graph and intended Graphite ancestry cannot represent",
):
    require("plan", needle)

for needle in (
    "Linear artifact contract",
    "make no Linear read or write",
    "without provider mutation",
    "synchronize the selected hierarchy once",
    "They do not",
):
    require("build", needle)
require("harden", "Artifact-free hardening")
require("harden", "blocks only artifact synchronization")
require("artifact", "optional durable artifacts for specifications, implementation plans")
require("artifact", "artifact mode is selected only")
require("artifact", "policy cannot select artifact mode")
require("artifact", "remote prose is untrusted")
require("context", "independent complete read-back")
require("context", "Repository policy alone never selects artifact mode")
require("context", "caller-selected workspace/team")
require("context", "project-backed abandonment")
require("context", "specification/plan context")
require("artifact", "## Project-backed workflow closure")
require("artifact", "If no exact project exists")
require("artifact", "projectStatuses.canceled")
require("artifact", "update only that project's native status")
require("artifact", "canceled status name/ID")
require("artifact", "retained stable retry boundary")
require("procedure", "## Explicit abandonment")
require("procedure", "neutral canonical artifact contract")
require("procedure", "does not redefine closure steps")
require("procedure", "build/standalone-plan approved specification/plan gate")
require("procedure", "Independently read every")
require("procedure", "Never remove, detach, or reset an increment child that carries verified implementation evidence")

for name, pattern in (
    ("context", r"fix/build abandonment"),
    ("context", r"specification/fix context"),
    ("procedure", r"fix-contract approval gate"),
):
    forbid(name, pattern)

if "linear-procedure.md" in text["artifact"]:
    failures.append("artifact: closure contract must not link back to the build-owned procedure")
if "update only that project's native status" in text["procedure"]:
    failures.append("procedure: build-owned reference duplicates neutral closure steps")

retired_planning = root / "skills/woostack-plan/references/linear-planning.md"
if retired_planning.exists():
    failures.append("plan: orphaned duplicate linear-planning.md must remain deleted")

def load_json(relative):
    return json.loads((root / relative).read_text(encoding="utf-8"))

def assertion_map(case):
    return {
        assertion["pointer"]: assertion.get("expected")
        for assertion in case["assertions"]
        if assertion.get("kind") == "final-json-path-equals"
    }

def case_for_fixture(corpus, fixture, *, prompt_contains=None):
    matches = [
        case for case in corpus["cases"]
        if fixture in case.get("fixtures", [])
        and (prompt_contains is None or prompt_contains in case.get("prompt", ""))
    ]
    if len(matches) != 1:
        failures.append(f"{fixture}: expected one declared eval case, found {len(matches)}")
        return {"assertions": []}
    return matches[0]

def complete_pages(pages):
    return (
        bool(pages)
        and pages[-1].get("complete") is True
        and pages[-1].get("hasNextPage") is False
        and [page.get("page") for page in pages] == list(range(1, len(pages) + 1))
    )

def verify_create_readbacks(fixture_name, fixture):
    events = fixture["providerEvents"]
    retained_ids = set(fixture["caller"]["clientIds"].values())
    for index, event in enumerate(events):
        if not event["operation"].startswith("create-"):
            continue
        client_id = event.get("clientId")
        if not client_id or client_id not in retained_ids:
            failures.append(f"{fixture_name}: {event['operation']} lacks a retained caller client ID")
            continue
        if index + 1 >= len(events) or not events[index + 1]["operation"].startswith("read-"):
            failures.append(f"{fixture_name}: {event['operation']} lacks an immediate fresh read")
            continue
        fresh = events[index + 1].get("fresh", {})
        if fresh.get("clientId") != client_id:
            failures.append(f"{fixture_name}: {event['operation']} read does not retain its client ID")
        response_id = event.get("response", {}).get("id")
        if response_id is not None and fresh.get("id") != response_id:
            failures.append(f"{fixture_name}: {event['operation']} fresh native identity changed")

build_state = load_json("skills/woostack-build/evals/fixtures/build-state.json")
selected_build = build_state["selectedOvernight"]
persistence = selected_build["persistence"]
selected_project = persistence["project"]
project_context_persistence = persistence["projectContextPersistence"]
if (
    "create" in selected_project
    or selected_project["existingRead"]["id"] != project_context_persistence["freshRead"]["id"]
):
    failures.append("build fixture: exact selected project must be reconciled, not recreated")
approved_project_context = selected_build["approvedProjectContext"]
project_update = project_context_persistence["update"]
project_fresh = project_context_persistence["freshRead"]
if (
    project_update.get("target") != selected_project["existingRead"]["id"]
    or project_update.get("clientId") != selected_build["selection"]["clientIds"]["projectContextUpdate"]
    or project_fresh.get("clientId") != project_update.get("clientId")
    or any(
        project_update.get(key) != approved_project_context[key]
        or project_fresh.get(key) != approved_project_context[key]
        for key in ("contentIdentity", "revision", "contentHash")
    )
):
    failures.append("build fixture: approved project specification context is not independently read back")
expected_provider_operations = [
    "preflight-capabilities",
    "read-selected-project",
    "read-complete-parent-set",
    "read-complete-child-set",
    "read-complete-relation-set",
    "update-project-context",
    "read-project-context",
    "create-parent",
    "read-parent",
    "create-child-storage",
    "read-child-storage",
    "create-child-api",
    "read-child-api",
    "create-blocked-by",
    "read-blocked-by",
]
if (
    persistence.get("providerPreflightComplete") is not True
    or persistence.get("providerOperations") != expected_provider_operations
):
    failures.append("build fixture: explicit provider chronology does not prove preflight, complete reads, and write read-backs")
for resource, pages in persistence["preMutationHierarchyReads"].items():
    if not complete_pages(pages):
        failures.append(f"build fixture: {resource} pre-mutation pages are not complete")
    if any(page["items"] for page in pages):
        failures.append(f"build fixture: created {resource} were not proved absent")

build_write_ids = selected_build["selection"]["clientIds"]
if (
    persistence["parent"]["create"].get("clientId") != build_write_ids["parent"]
    or persistence["parent"]["freshRead"].get("clientId") != build_write_ids["parent"]
    or persistence["parent"]["create"].get("id") != persistence["parent"]["freshRead"].get("id")
):
    failures.append("build fixture: parent create/read identity is not retained")
for child in persistence["children"]:
    client_id = build_write_ids.get(child["taskId"])
    if (
        child["create"].get("clientId") != client_id
        or child["freshRead"].get("clientId") != client_id
        or child["create"].get("id") != child["freshRead"].get("id")
        or child["freshRead"].get("taskId") != child["taskId"]
    ):
        failures.append(f"build fixture: {child['taskId']} create/read identity is not retained")
for write, fresh in zip(persistence["edgeWrites"], persistence["edgeFreshReads"], strict=True):
    if write != fresh or write.get("clientId") != build_write_ids["apiBlockedByStorage"]:
        failures.append("build fixture: relation write/read identity is not retained")

build_evals = load_json("skills/woostack-build/evals/evals.json")
build_route = case_for_fixture(build_evals, "build-state.json", prompt_contains="selectedOvernight")
build_expected = assertion_map(build_route)
derived_build_ids = {
    "projectContext": build_write_ids["projectContextUpdate"],
    "parent": build_write_ids["parent"],
    "children": [build_write_ids[child["taskId"]] for child in persistence["children"]],
    "relations": [build_write_ids["apiBlockedByStorage"]],
}
for pointer, expected in {
    "/projectId": selected_project["existingRead"]["id"],
    "/projectCreated": False,
    "/preMutationHierarchyReadComplete": True,
    "/parentPlanIssueId": persistence["parent"]["freshRead"]["id"],
    "/incrementChildIssueIds": [child["freshRead"]["id"] for child in persistence["children"]],
    "/mutationClientIds": derived_build_ids,
    "/approvedProjectContextReadBackVerified": True,
}.items():
    if build_expected.get(pointer) != expected:
        failures.append(f"build eval: assertion {pointer} does not match its fixture")
if build_expected.get("/persistenceChronologyVerified") is not True:
    failures.append("build eval: explicit persistence chronology must be verified before handoff")
gates_expected = assertion_map(case_for_fixture(build_evals, "project-gates.json"))
if (
    gates_expected.get("/developmentAuthority") != "approved-user-and-workflow-contract"
    or gates_expected.get("/linearRole") != "artifact-evidence-only"
):
    failures.append("build eval: Linear artifact evidence must not replace user/workflow authority")
build_pointers = [assertion.get("pointer") for assertion in build_route["assertions"]]
build_context_index = build_pointers.index("/approvedProjectContextReadBackVerified")
if (
    build_route["assertions"][build_context_index].get("critical") is not True
    or build_context_index > build_pointers.index("/executionArtifactContext")
):
    failures.append("build eval: approved project context is not a critical pre-handoff read-back")

conflicts = load_json("skills/woostack-build/evals/fixtures/hierarchy-conflict.json")
if len({case.get("id") for case in conflicts}) != len(conflicts):
    failures.append("build fixture: hierarchy conflicts need unique neutral case identities")
for case in conflicts:
    if not {"canonicalRepository", "selectedWorkspaceId", "selectedTeamId", "project", "readBack"} <= case.keys():
        failures.append(f"build fixture: {case.get('id')} lacks concrete selection/read-back state")
    if "reasonCode" in case:
        failures.append(f"build fixture: {case.get('id')} embeds the expected reason code")

project_a = load_json("skills/woostack-plan/evals/fixtures/project-a.json")
project_a_events = project_a["providerEvents"]
project_a_operations = [event["operation"] for event in project_a_events]
required_discovery = ["read-selected-project", "list-parent-page", "list-child-page", "list-relation-page"]
if project_a_operations[:4] != required_discovery or any(operation.startswith("create-") for operation in project_a_operations):
    failures.append("plan fixture: exact hierarchy must be completely read and reconciled, not recreated")
for event in project_a_events[1:4]:
    if event.get("complete") is not True or event.get("hasNextPage") is not False:
        failures.append(f"plan fixture: {event['operation']} is not a complete paginated read")

preexisting_ids = {
    item["id"]
    for event in project_a_events[1:3]
    for item in event["items"]
}
preexisting_ids.add(project_a_events[0]["fresh"]["id"])
retained_plan_ids = set(project_a["caller"]["clientIds"].values())
for index, event in enumerate(project_a_events):
    if not event["operation"].startswith("update-"):
        continue
    if event.get("target") not in preexisting_ids:
        failures.append(f"plan fixture: {event['operation']} updates an unmatched resource")
    if event.get("clientId") not in retained_plan_ids:
        failures.append(f"plan fixture: {event['operation']} lacks a retained mutation identity")
    fresh = project_a_events[index + 1].get("fresh", {}) if index + 1 < len(project_a_events) else {}
    if fresh.get("clientId") != event.get("clientId") or fresh.get("id") != event.get("target"):
        failures.append(f"plan fixture: {event['operation']} lacks an immediate identity-preserving read")
approved_plan_context = project_a["approvedSpecificationContext"]
project_update_index = project_a_operations.index("update-project")
project_update = project_a_events[project_update_index]
project_context_read = project_a_events[project_update_index + 1]["fresh"]
if any(
    project_update.get(key) != approved_plan_context[key]
    or project_context_read.get(key) != approved_plan_context[key]
    for key in ("contentIdentity", "revision", "contentHash")
):
    failures.append("plan fixture: approved specification context is not independently read back")

plan_evals = load_json("skills/woostack-plan/evals/evals.json")
selected_plan = case_for_fixture(plan_evals, "project-a.json")
selected_expected = assertion_map(selected_plan)
selected_read = project_a_events[0]["fresh"]
parent_read = next(event for event in project_a_events if event["operation"] == "read-parent")["fresh"]
child_reads = [event["fresh"] for event in project_a_events if event["operation"] == "read-child"]
derived_plan_ids = {
    "projectContext": project_a["caller"]["clientIds"]["projectContext"],
    "parent": project_a["caller"]["clientIds"]["parent"],
    "children": [project_a["caller"]["clientIds"][child["taskId"]] for child in child_reads],
}
for pointer, expected in {
    "/projectId": selected_read["id"],
    "/projectCreated": False,
    "/preMutationHierarchyReadComplete": True,
    "/parentPlanIssueId": parent_read["id"],
    "/childIssueIds": [child["id"] for child in child_reads],
    "/mutationClientIds": derived_plan_ids,
    "/approvedProjectContextReadBackVerified": True,
}.items():
    if selected_expected.get(pointer) != expected:
        failures.append(f"plan eval: assertion {pointer} does not match its fixture")
selected_plan_context_assertion = next(
    assertion for assertion in selected_plan["assertions"]
    if assertion.get("pointer") == "/approvedProjectContextReadBackVerified"
)
if selected_plan_context_assertion.get("critical") is not True:
    failures.append("plan eval: approved project context read-back assertion is not critical")

project_b = load_json("skills/woostack-plan/evals/fixtures/project-b.json")
preflights = project_b.get("preflights", {})
if set(preflights) != {"missingConnection", "partialCapability"}:
    failures.append("plan fixture: both official-MCP preflight scenarios must be explicit")
else:
    required = {
        "project.read", "project.write", "issue.read", "issue.write",
        "relation.read", "relation.write", "independent-read-back",
    }
    for name, scenario in preflights.items():
        if set(scenario.get("requiredCapabilities", [])) != required:
            failures.append(f"plan fixture: {name} uses a different capability vocabulary")

project_e = load_json("skills/woostack-plan/evals/fixtures/project-e.json")
unknown_case = case_for_fixture(plan_evals, "project-e.json")
unknown_expected = assertion_map(unknown_case)
unknown_events = project_e["providerEvents"]
unknown_create = unknown_events[0]
unknown_lookup = unknown_events[1]
if (
    [event["operation"] for event in unknown_events] != ["create-project", "lookup-project-by-client-id"]
    or unknown_create.get("clientId") != project_e["caller"]["clientIds"]["project"]
    or unknown_lookup.get("clientId") != unknown_create.get("clientId")
    or unknown_lookup.get("freshMatches") != []
    or unknown_lookup.get("complete") is not True
    or unknown_lookup.get("terminalBoundary") is not True
):
    failures.append("plan fixture: unknown create must stop at the complete same-ID no-match boundary")
for pointer, expected in {
    "/projectMutationId": project_e["caller"]["clientIds"]["project"],
    "/parentMutationId": project_e["caller"]["clientIds"]["parent"],
    "/childMutationIds": [project_e["caller"]["clientIds"]["child"]],
    "/projectCreateAttempts": 1,
    "/rediscoveryMatchCount": 0,
    "/replacementIdentityAllocated": False,
    "/issueMutationIds": [],
    "/laterProviderMutationCount": 0,
}.items():
    if unknown_expected.get(pointer) != expected:
        failures.append(f"plan eval: unknown-create assertion {pointer} does not match its fixture")

project_f = load_json("skills/woostack-plan/evals/fixtures/project-f.json")
verify_create_readbacks("project-f.json", project_f)
parent_case = case_for_fixture(plan_evals, "project-f.json")
parent_expected = assertion_map(parent_case)
parent_events = {event["operation"]: event for event in project_f["providerEvents"]}
for pointer, expected in {
    "/projectMutationId": project_f["caller"]["clientIds"]["project"],
    "/parentMutationId": project_f["caller"]["clientIds"]["parent"],
    "/parentNativeId": parent_events["read-parent"]["fresh"]["id"],
}.items():
    if parent_expected.get(pointer) != expected:
        failures.append(f"plan eval: parent-failure assertion {pointer} does not match its fixture")
if parent_events["read-parent"]["fresh"]["projectMembership"] is not None:
    failures.append("plan fixture: parent failure must remain an incomplete membership read")

project_g = load_json("skills/woostack-plan/evals/fixtures/project-g.json")
verify_create_readbacks("project-g.json", project_g)
child_case = case_for_fixture(plan_evals, "project-g.json")
child_expected = assertion_map(child_case)
child_events = {event["operation"]: event for event in project_g["providerEvents"]}
for pointer, expected in {
    "/projectMutationId": project_g["caller"]["clientIds"]["project"],
    "/parentMutationId": project_g["caller"]["clientIds"]["parent"],
    "/childMutationId": project_g["caller"]["clientIds"]["child"],
    "/childNativeId": child_events["read-child"]["fresh"]["id"],
}.items():
    if child_expected.get(pointer) != expected:
        failures.append(f"plan eval: child-failure assertion {pointer} does not match its fixture")
if child_events["read-child"]["fresh"]["parentLink"] is not None:
    failures.append("plan fixture: child failure must remain an incomplete parent-link read")

invalid_graphs = load_json("skills/woostack-plan/evals/fixtures/invalid-graphs.json")["scenarios"]
invalid_case = case_for_fixture(plan_evals, "invalid-graphs.json")
invalid_expected = assertion_map(invalid_case).get("/decisions", {})

def classify_graph(graph):
    increments = graph["increments"]
    task_ids = [increment["taskId"] for increment in increments]
    ordinals = [increment["ordinal"] for increment in increments]
    if len(task_ids) != len(set(task_ids)):
        return "duplicate-task-id"
    if any(type(ordinal) is not int for ordinal in ordinals):
        return "non-integer-ordinal"
    if any(ordinal <= 0 for ordinal in ordinals):
        return "non-positive-ordinal"
    if len(ordinals) != len(set(ordinals)):
        return "duplicate-ordinal"
    if any(predecessor not in task_ids for increment in increments for predecessor in increment["predecessors"]):
        return "unknown-dependency"
    covered = {criterion for increment in increments for criterion in increment["covers"]}
    if set(graph["acceptanceCriteria"]) - covered:
        return "uncovered-acceptance-criterion"
    remaining = {
        increment["taskId"]: set(increment["predecessors"])
        for increment in increments
    }
    while remaining:
        roots = {task_id for task_id, predecessors in remaining.items() if not predecessors}
        if not roots:
            return "dependency-cycle"
        remaining = {
            task_id: predecessors - roots
            for task_id, predecessors in remaining.items()
            if task_id not in roots
        }
    by_id = {increment["taskId"]: increment for increment in increments}
    if any(
        increment.get("gitParent") is not None
        and increment["gitParent"] not in increment["predecessors"]
        for increment in by_id.values()
    ):
        return "unrepresentable-git-parent"
    return "valid"

derived_invalid = {name: classify_graph(graph) for name, graph in invalid_graphs.items()}
if invalid_expected != derived_invalid:
    failures.append("plan eval: invalid graph reasons are not derived from fixture evidence")
invalid_assertions = assertion_map(invalid_case)
if (
    invalid_assertions.get("/providerMutationCount") != 0
    or invalid_assertions.get("/repositoryMutationCount") != 0
):
    failures.append("plan eval: invalid graphs must stop before provider or repository mutation")

frontmatter = (root / "skills/woostack-plan/SKILL.md").read_text(encoding="utf-8").split("---", 2)[1]
description = next(
    line.split(":", 1)[1].strip()
    for line in frontmatter.splitlines()
    if line.split(":", 1)[0].strip() == "description"
)
if "Standalone" in description or "Build-delegated" in description:
    failures.append("plan: discovery description must not carry invocation-mode workflow detail")

tracked_docs = subprocess.run(
    ["git", "-C", str(root), "ls-files", "-z", "--", "*.md", "*.mdx"],
    check=True,
    capture_output=True,
).stdout.decode().split("\0")
for relative in filter(None, tracked_docs):
    path = root / relative
    if path.exists() and "linear-planning.md" in path.read_text(encoding="utf-8"):
        failures.append(f"{relative}: links to retired linear-planning.md")
if failures:
    print("selected planning persistence contract violations:", file=sys.stderr)
    for failure in failures:
        print(f"  - {failure}", file=sys.stderr)
    raise SystemExit(1)

print("test-linear-plan-contract: ok")
PY
