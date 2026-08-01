#!/usr/bin/env bash
# Structural contract for diagnosis, approval, explicitly selected plan persistence, and delivery.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import json, re, sys
from pathlib import Path
text=re.sub(r"\s+"," ",(Path(sys.argv[1])/"skills/woostack-fix/SKILL.md").read_text())
checks={
 "selected project":r"When the caller supplies an exact Linear project or explicitly requests persistence, the approved fix plan is persisted as one project",
 "exact project without policy":r"`--project` selects one exact existing plan project.*persisted there, even when repository Linear policy is absent",
 "no implicit provider access":r"Without either selection, make no Linear read or write",
 "policy not authority":r"policy may supply validated non-secret defaults only after selection and never authorizes a provider write",
 "one gate":r"exactly one hard gate.*approve-to-execute",
 "project hierarchy":r"one selected project containing the proved diagnosis.*one parent plan issue.*one native child issue",
 "repository and team verification":r"verify the canonical repository association and resolved caller-selected workspace/team",
 "proved root cause":r"root cause and causal chain",
 "no patch in debug":r"Do not patch during diagnosis",
 "hardened contract":r"Produce one reviewable bounded contract",
 "explicit approval":r"request explicit.*approve-to-execute",
 "no preapproval write":r"Do not create a branch, worktree, edit, commit, PR, or artifact write before approval",
 "isolated execute":r"dispatch exactly the approved bounded increment to `woostack-execute`",
 "exact execution context":r"exact persisted project, parent plan issue, and increment child context",
 "red green":r"observes the failing reproduction.*observes it passing",
 "scope invalidates":r"scope expansion.*invalidates approval",
 "review and commit":r"Require task-wide contract and quality review.*woostack-commit",
 "artifact narrow exception":r"Except for the workflow-owned canceled project transition on explicit abandonment.*do not mutate assignment, ownership, status",
 "abandon any phase":r"Explicit abandonment may occur at any phase",
 "canonical closure":r"canonical.*fix/build project-closure procedure",
 "cancel persisted project":r"exact persisted fix project exists.*native status must be set to the validated.*projectStatuses\.canceled",
 "no project no creation":r"no project exists.*nothing to close.*never create one merely to cancel",
 "non-abandon outcomes":r"distinct from handoff, replanning, and blocker handling.*leave project status unchanged",
 "closure failure":r"failed or unknown closure.*artifact blocker.*never resumes repository work",
 "repository readback":r"independently read its commit/head/base/body",
 "never merge":r"never merges",
}
failures=[name for name,pat in checks.items() if not re.search(pat,text,re.I|re.S)]
if re.search(r"--issue|Linear-Issue:|must.*exactly one managed issue",text,re.I|re.S):
 failures.append("legacy issue-only lifecycle returned")

root = Path(sys.argv[1])
evals = json.loads((root / "skills/woostack-fix/evals/evals.json").read_text())

def case_for_fixture(fixture_name, *, prompt_contains=None):
 cases = [
  case for case in evals["cases"]
  if case.get("fixtures") == [fixture_name]
  and (prompt_contains is None or prompt_contains in case.get("prompt", ""))
 ]
 if len(cases) != 1:
  failures.append(f"{fixture_name}: expected one declared eval case, found {len(cases)}")
  return {"assertions": [], "prompt": ""}
 case = cases[0]
 if f"fixtures/{fixture_name}" not in case["prompt"]:
  failures.append(f"{fixture_name}: eval prompt does not name its declared fixture")
 return case

def assertions(case):
 return {assertion.get("pointer"): assertion.get("expected") for assertion in case["assertions"]}

def complete_pages(pages):
 return (
  bool(pages)
  and pages[-1].get("complete") is True
  and pages[-1].get("hasNextPage") is False
  and [page.get("page") for page in pages] == list(range(1, len(pages) + 1))
 )

def context_matches(resource, intended):
 return all(resource.get(key) == intended.get(key) for key in ("contentIdentity", "revision", "contentHash"))

selected = json.loads((root / "skills/woostack-fix/evals/fixtures/selected-project-persistence.json").read_text())
selected_case = case_for_fixture("selected-project-persistence.json", prompt_contains="immediately after explicit")
selected_assertions = assertions(selected_case)
selected_project = selected["selectedProjectRead"]["fresh"]
if (
 selected["caller"]["workspaceId"] != selected_project["workspaceId"]
 or selected["caller"]["teamId"] != selected_project["teamId"]
 or selected["repositoryOrigin"] != selected_project["repository"]
):
 failures.append("selected-project fixture does not verify caller repository/workspace/team")
for resource, pages in selected["preMutationHierarchyReads"].items():
 if not complete_pages(pages):
  failures.append(f"selected-project fixture has incomplete pre-write {resource} pages")

parent_before = selected["preMutationHierarchyReads"]["parents"][0]["items"][0]
child_before = selected["preMutationHierarchyReads"]["children"][0]["items"][0]
approved = selected["approvedFix"]
events = selected["providerEvents"]
project_write, project_read, parent_write, parent_read, child_write, child_read, relation_read = events
if (
 project_write["target"] != selected_project["id"]
 or project_write["clientId"] != selected["caller"]["clientIds"]["project"]
 or not context_matches(project_write, approved["projectContext"])
 or project_read["fresh"]["id"] != selected_project["id"]
 or project_read["fresh"]["clientId"] != project_write["clientId"]
 or not context_matches(project_read["fresh"], approved["projectContext"])
 or project_read["fresh"]["repository"] != selected["repositoryOrigin"]
 or project_read["fresh"]["workspaceId"] != selected["caller"]["workspaceId"]
 or project_read["fresh"]["teamId"] != selected["caller"]["teamId"]
):
 failures.append("selected-project approved project context is not independently read back")
if (
 parent_write["target"] != parent_before["id"]
 or parent_write["clientId"] != selected["caller"]["clientIds"]["parent"]
 or not context_matches(parent_write, approved["parentPlan"])
 or parent_read["fresh"]["id"] != parent_before["id"]
 or parent_read["fresh"]["clientId"] != parent_write["clientId"]
 or not context_matches(parent_read["fresh"], approved["parentPlan"])
 or parent_read["fresh"]["projectMembership"] != selected_project["id"]
):
 failures.append("selected-project parent reconciliation is not identity-preserving")
if (
 child_write["target"] != child_before["id"]
 or child_write["clientId"] != selected["caller"]["clientIds"]["child"]
 or child_write["taskId"] != approved["increment"]["taskId"]
 or not context_matches(child_write, approved["increment"])
 or child_read["fresh"]["id"] != child_before["id"]
 or child_read["fresh"]["clientId"] != child_write["clientId"]
 or child_read["fresh"]["taskId"] != approved["increment"]["taskId"]
 or not context_matches(child_read["fresh"], approved["increment"])
 or child_read["fresh"]["parentLink"] != parent_before["id"]
 or child_read["fresh"]["projectMembership"] != selected_project["id"]
 or relation_read["fresh"].get("complete") is not True
 or relation_read["fresh"].get("items") != selected["preMutationHierarchyReads"]["relations"][0]["items"]
):
 failures.append("selected-project child/relation reconciliation is not completely read back")
for pointer, expected in {
 "/projectId": selected_project["id"],
 "/projectCreated": False,
 "/preMutationHierarchyReadComplete": True,
 "/parentPlanIssueId": parent_read["fresh"]["id"],
 "/incrementChildIssueIds": [child_read["fresh"]["id"]],
 "/hierarchyReadBackVerified": True,
 "/approvedProjectContextReadBackVerified": True,
}.items():
 if selected_assertions.get(pointer) != expected:
  failures.append(f"selected-project fixture is not grounded at {pointer}")
selected_pointers = [assertion.get("pointer") for assertion in selected_case["assertions"]]
selected_context_index = selected_pointers.index("/approvedProjectContextReadBackVerified")
selected_context_assertion = selected_case["assertions"][selected_context_index]
if (
 selected_context_assertion.get("critical") is not True
 or selected_context_index > selected_pointers.index("/executionDelegated")
):
 failures.append("selected-project context read-back is not a critical pre-delegation assertion")

partial = selected["partialReadScenario"]
partial_case = case_for_fixture("selected-project-persistence.json", prompt_contains="partialReadScenario")
partial_assertions = assertions(partial_case)
partial_pages = partial["preMutationHierarchyReads"]["parents"]
if (
 partial_pages[-1].get("complete") is not False
 or partial["providerEvents"] != []
 or partial_assertions.get("/providerMutationCount") != 0
 or partial_assertions.get("/projectCreated") is not False
 or partial_assertions.get("/executionDelegated") is not False
):
 failures.append("selected-project partial read must block without mutation or delegation")

created = json.loads((root / "skills/woostack-fix/evals/fixtures/explicit-project-create.json").read_text())
created_case = case_for_fixture("explicit-project-create.json")
created_assertions = assertions(created_case)
created_events = created["providerEvents"]
created_operations = [event["operation"] for event in created_events]
if created_operations != [
 "lookup-project-by-client-id",
 "create-project",
 "read-project-by-client-id",
 "create-parent",
 "read-parent",
 "create-child",
 "read-child",
]:
 failures.append("explicit-create transcript does not preserve recovery ordering")
absence, project_create, project_read = created_events[:3]
recovered = project_read.get("freshMatches", [])
if (
 absence.get("clientId") != created["caller"]["clientIds"]["project"]
 or absence.get("freshMatches") != []
 or absence.get("complete") is not True
 or project_create.get("clientId") != absence.get("clientId")
 or project_create.get("outcome") != "timeout-unknown"
 or not context_matches(project_create, created["approvedFix"]["projectContext"])
 or project_read.get("clientId") != project_create.get("clientId")
 or project_read.get("complete") is not True
 or len(recovered) != 1
 or recovered[0].get("clientId") != project_create.get("clientId")
 or not context_matches(recovered[0], created["approvedFix"]["projectContext"])
):
 failures.append("explicit-create recovery does not prove absence then resolve one same-ID project context")

for index, context_key in ((3, "parentPlan"), (5, "increment")):
 write = created_events[index]
 fresh = created_events[index + 1]["fresh"]
 intended = created["approvedFix"][context_key]
 if (
  write.get("clientId") not in created["caller"]["clientIds"].values()
  or fresh.get("clientId") != write.get("clientId")
  or fresh.get("id") != write["response"].get("id")
  or not context_matches(write["response"], intended)
  or not context_matches(fresh, intended)
 ):
  failures.append(f"explicit-create {write['operation']} read-back changed identity or approved context")
for pointer, expected in {
 "/absenceProvedBeforeCreate": True,
 "/projectMutationId": created["caller"]["clientIds"]["project"],
 "/parentMutationId": created["caller"]["clientIds"]["parent"],
 "/childMutationIds": [created["caller"]["clientIds"]["child"]],
 "/createAttempts": {
  "project": 1,
  "parent": 1,
  "children": 1,
  "parentChildLinks": 1,
 },
 "/retryMatchedExistingHierarchy": True,
 "/replacementCreated": False,
 "/approvedProjectContextReadBackVerified": True,
}.items():
 if created_assertions.get(pointer) != expected:
  failures.append(f"explicit-create fixture is not grounded at {pointer}")
created_context_assertion = next(
 assertion for assertion in created_case["assertions"]
 if assertion.get("pointer") == "/approvedProjectContextReadBackVerified"
)
if created_context_assertion.get("critical") is not True:
 failures.append("explicit-create project context read-back assertion is not critical")
if sum(event["operation"] == "create-project" for event in created_events) != 1:
 failures.append("explicit-create retry replays the project create")

classified = json.loads((root / "skills/woostack-fix/evals/fixtures/exact-project-classification.json").read_text())
classified_case = case_for_fixture("exact-project-classification.json")
decision_assertion = assertions(classified_case).get("/decisions", {})
if set(decision_assertion) != set(classified["candidates"]):
 failures.append("exact-project classification candidates do not match the fixture")
if re.search(r"decisions must classify\b", classified_case.get("prompt", ""), re.I):
 failures.append("exact-project classification prompt contains the answer")
if failures:
 print("fix contract violations:",file=sys.stderr)
 print("\n".join(f"- {f}" for f in failures),file=sys.stderr)
 raise SystemExit(1)
print("conditional fix plan contract: ok")
PY
