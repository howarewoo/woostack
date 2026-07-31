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
  printf 'test-linear-build-contract: python3 or python is required\n' >&2
  exit 1
fi
"$PYTHON" - "$(tool_path_arg "$PYTHON" "$ROOT")" <<'PY'
import copy
import json
import os
import re
import sys
import uuid
from collections import defaultdict
from pathlib import Path

root = Path(sys.argv[1])
paths = {
    "build": root / "skills/woostack-build/SKILL.md",
    "procedure": root / "skills/woostack-build/references/linear-procedure.md",
    "context": root / "skills/woostack-build/references/linear-context.md",
    "plan": root / "skills/woostack-plan/SKILL.md",
    "planning": root / "skills/woostack-plan/references/linear-planning.md",
    "harden": root / "skills/woostack-harden/SKILL.md",
    "status": root / "skills/woostack-status/SKILL.md",
    "conventions": root / "skills/woostack-status/references/conventions.md",
    "evals": root / "skills/woostack-build/evals/evals.json",
    "test": root / "skills/woostack-build/tests/test-linear-build-contract.sh",
    "runner": root / "skills/woostack-init/scripts/tests/run-tests.sh",
}
texts = {name: path.read_text(encoding="utf-8") for name, path in paths.items()}


def fail(message):
    raise SystemExit(f"test-linear-build-contract: {message}")


def must(text, token, scope):
    if token not in text:
        fail(f"{scope} missing {token!r}")


def rejects(label, operation):
    try:
        operation()
    except ValueError:
        return
    fail(f"{label} was accepted")


if not os.access(paths["test"], os.X_OK):
    fail("contract test is not executable")
if texts["runner"].count("test-linear-build-contract.sh") != 1:
    fail("contract test must be registered exactly once")

workflow = "\n".join(texts[name] for name in (
    "build", "procedure", "context", "plan", "planning", "harden", "status", "conventions"
))

for required in (
    "official host-exposed Linear MCP",
    "canonical repository URL",
    "projectEvent",
    "stable event `clientId`",
    "revision",
    "predecessorId",
    "supersedesId",
    "exactly one current lifecycle chain",
    "designApproved → specHardened → specApproved → planning → ready",
    "executionApproved",
    "independently read",
    "fail closed",
):
    must(workflow, required, "Linear lifecycle docs")

names = re.findall(r'<HARD-GATE name="([^"]+)">', texts["procedure"])
if names != ["design-approval", "spec-approval", "execution-handoff"]:
    fail(f"hard gate set/order is {names!r}")
if len(re.findall(r"<HARD-GATE\b", workflow)) != 3:
    fail("workflow must contain exactly three hard-gate openings")
for token in (
    "ready → planning",
    "explicitly empty implementation branch and PR evidence",
    "same stable event UUID at exactly the next revision",
    "new `abandoned` phase event",
    "`blockerOpened`",
    "`blockerResolved`",
    "then set native `planned` and read that back",
    "native `canceled`",
):
    must(texts["procedure"], token, "Linear procedure")
for token in (
    "one managed `increment` issue",
    "stable client UUID",
    "native Linear relations",
    "unique positive ordinal",
    "acceptance criterion",
    "independent complete read-back",
):
    must(texts["plan"] + texts["planning"], token, "Linear planning")
for token in (
    "`backlog`",
    "`planned`",
    "`started`",
    "`completed`",
    "`canceled`",
):
    must(texts["conventions"], token, "coarse status mapping")

# The build corpus owns observable decisions; fixtures are input-only snapshots. Keep exact
# dispositions in host-side assertions, never in the prompt or fixture visible to a worker.
eval_corpus = json.loads(texts["evals"])
eval_cases = eval_corpus.get("cases", [])
expected_case_ids = [
    "routes-approved-build-to-overnight-handoff",
    "classifies-existing-development-materials-without-project-reference",
    *[f"classifies-build-snapshot-{number:02d}" for number in range(1, 13)],
    "enforces-project-gates-and-bounded-routing",
    "fails-closed-on-project-update-conflicts",
    "refuses-unsafe-project-replan",
]
if [case.get("id") for case in eval_cases] != expected_case_ids:
    fail("build behavior corpus case set/order changed")
eval_by_id = {case["id"]: case for case in eval_cases}
fixtures_root = root / "skills/woostack-build/evals/fixtures"

happy_case = eval_by_id["routes-approved-build-to-overnight-handoff"]
if happy_case.get("fixtures") != ["build-state.json"]:
    fail("complete happy graph fixture changed")
happy_fixture = json.loads((fixtures_root / "build-state.json").read_text(encoding="utf-8"))
happy_authority = happy_fixture.get("authority", {})
observed_capabilities = {
    item.get("capability")
    for item in happy_authority.get("capabilityObservations", [])
    if item.get("available") is True and item.get("independentReadAvailable") is True
}
if (
    happy_authority.get("preflightComplete") is not True
    or happy_authority.get("paginationExhausted") is not True
    or happy_authority.get("authentication", {}).get("authenticated") is not True
    or observed_capabilities != set(happy_authority.get("requiredCapabilities", []))
):
    fail("complete happy graph lacks raw official-MCP preflight evidence")
happy_dependencies = {
    issue["id"]: issue["envelope"]["dependencyIds"]
    for issue in happy_fixture.get("incrementIssues", [])
}
if happy_dependencies != {
    "linear-issue-41": [],
    "linear-issue-42": ["linear-issue-41"],
}:
    fail("complete happy increment graph changed")

local_case = eval_by_id[
    "classifies-existing-development-materials-without-project-reference"
]
local_contract = {
    "/status": "blocked",
    "/canonicalProjectIdentityResolved": False,
    "/localSpecAccepted": False,
    "/localPlanAccepted": False,
    "/linearDocumentAccepted": False,
    "/fallbackAllowed": False,
    "/managedMutationCount": 0,
    "/gitMutationCount": 0,
    "/nextAction": "require-canonical-feature-project-uuid-or-url",
}
observed_local_contract = {
    assertion.get("pointer"): assertion.get("expected")
    for assertion in local_case.get("assertions", [])
    if assertion.get("kind") == "final-json-path-equals"
}
if observed_local_contract != local_contract:
    fail("local-material rejection must remain externally asserted")

negative_reasons = {
    1: "official-linear-mcp-capability-missing",
    2: "official-linear-mcp-unauthenticated",
    3: "managed-pagination-incomplete",
    4: "managed-read-back-incomplete",
    5: "mutation-read-receipt-mismatch",
    6: "duplicate-current-phase-head",
    7: "multiple-current-phase-heads",
    8: "phase-predecessor-mismatch",
    9: "native-category-lifecycle-mismatch",
    10: "increment-dependency-relation-missing",
    11: "increment-dependency-relation-foreign",
    12: "increment-dependency-cycle",
}
negative_fixtures = {}
for number, reason in negative_reasons.items():
    case_id = f"classifies-build-snapshot-{number:02d}"
    fixture_name = f"build-snapshot-{number:02d}.json"
    case = eval_by_id[case_id]
    if case.get("fixtures") != [fixture_name]:
        fail(f"{case_id} must bind only its neutral raw snapshot")
    if case.get("capabilities") != ["read-workspace"]:
        fail(f"{case_id} must remain read-only")
    expected_output = {
        "/status": "blocked",
        "/reasonCode": reason,
        "/executionDispatchCount": 0,
        "/managedMutationCount": 0,
        "/repositoryMutationCount": 0,
    }
    observed_output = {
        assertion.get("pointer"): assertion.get("expected")
        for assertion in case.get("assertions", [])
        if assertion.get("kind") == "final-json-path-equals"
    }
    if observed_output != expected_output:
        fail(f"{case_id} blocked decision contract must remain exclusively external")

    fixture = json.loads((fixtures_root / fixture_name).read_text(encoding="utf-8"))
    negative_fixtures[number] = fixture
    if fixture.get("authority", {}).get("preflightComplete") is not True:
        fail(f"{fixture_name} must retain the misleading positive summary flag")
    if "inputScenarios" in fixture:
        fail(f"{fixture_name} contains an unrelated labeled input scenario")
    visible_input = case.get("prompt", "") + "\n" + json.dumps(fixture, sort_keys=True)
    for leaked_answer in (
        *negative_reasons.values(),
        '"status": "blocked"',
        '"status":"blocked"',
        "expected answer",
        "must block",
        "reject this snapshot",
        "invalid snapshot",
        "malformed snapshot",
        "zero dispatch",
        "no dispatch",
    ):
        if leaked_answer.lower() in visible_input.lower():
            fail(f"{case_id} leaks its disposition to the worker: {leaked_answer!r}")

required = set(negative_fixtures[1]["authority"]["requiredCapabilities"])
observed = {
    item["capability"]
    for item in negative_fixtures[1]["authority"]["capabilityObservations"]
    if item["available"] is True and item["independentReadAvailable"] is True
}
if required - observed != {"issue-relation-read"}:
    fail("snapshot 01 does not encode one raw missing capability observation")
if negative_fixtures[2]["authority"]["authentication"] != {
    "source": "host-connection",
    "authenticated": False,
    "workspace": "acme",
    "team": "APP",
    "principal": None,
}:
    fail("snapshot 02 does not encode raw unavailable host authentication")
if negative_fixtures[3]["authority"]["paginationExhausted"] is not False:
    fail("snapshot 03 does not encode raw incomplete pagination")


def fixture_issue(number, native_id):
    return next(
        item for item in negative_fixtures[number]["incrementIssues"]
        if item["id"] == native_id
    )


def fixture_update(number, native_id):
    return next(
        item for item in negative_fixtures[number]["projectUpdates"]
        if item["id"] == native_id
    )


if fixture_issue(4, "linear-issue-42")["independentReadReceipt"]["readComplete"] is not False:
    fail("snapshot 04 does not encode a raw incomplete issue read-back")
ready_mutation = fixture_update(5, "update-ready")
if (
    ready_mutation["contentRevision"] != 1
    or ready_mutation["independentReadReceipt"]["contentRevision"] != 2
):
    fail("snapshot 05 does not encode a raw mutation/read receipt mismatch")
duplicate_records = [
    item
    for item in negative_fixtures[6]["projectUpdates"]
    if item["envelope"]["clientId"] == "88888888-8888-4888-8888-888888888888"
    and item["envelope"]["revision"] == 1
    and item["envelope"]["supersedesId"] is None
]
if sorted(item["id"] for item in duplicate_records) != [
    "update-9c",
    "update-execution-approved",
]:
    fail("snapshot 06 does not encode duplicate current records for one phase identity")
multiple_records = [
    item
    for item in negative_fixtures[7]["projectUpdates"]
    if item["envelope"]["event"] == "executionApproved"
    and item["envelope"]["predecessorId"] == "update-ready"
    and item["envelope"]["supersedesId"] is None
]
if (
    sorted(item["id"] for item in multiple_records)
    != ["update-9d", "update-execution-approved"]
    or len({item["envelope"]["clientId"] for item in multiple_records}) != 2
):
    fail("snapshot 07 does not encode multiple current phase heads")
wrong_predecessor = fixture_update(8, "update-execution-approved")
if (
    wrong_predecessor["envelope"]["predecessorId"] != "update-planning"
    or wrong_predecessor["independentReadReceipt"]["predecessorId"] != "update-planning"
):
    fail("snapshot 08 does not encode a matching raw wrong-predecessor record")
if (
    negative_fixtures[9]["project"]["nativeStatus"]["category"] != "backlog"
    or negative_fixtures[9]["project"]["independentReadReceipt"][
        "nativeStatusCategory"
    ] != "backlog"
):
    fail("snapshot 09 does not encode the raw native category observation")
missing_relation = fixture_issue(10, "linear-issue-42")
if (
    missing_relation["contract"]["dependencyClientIds"]
    != ["22222222-2222-4222-8222-222222222222"]
    or missing_relation["envelope"]["dependencyIds"] != []
    or missing_relation["independentReadReceipt"]["dependencyIds"] != []
):
    fail("snapshot 10 does not encode a missing native dependency relation")
foreign_relation = fixture_issue(11, "linear-issue-42")
if (
    foreign_relation["envelope"]["dependencyIds"]
    != ["linear-issue-41", "linear-issue-99"]
    or foreign_relation["independentReadReceipt"]["dependencyIds"]
    != ["linear-issue-41", "linear-issue-99"]
    or "linear-issue-99"
    in negative_fixtures[11]["project"]["independentReadReceipt"]["issueIds"]
):
    fail("snapshot 11 does not encode a foreign native dependency relation")
cyclic_relations = {
    issue["id"]: issue["envelope"]["dependencyIds"]
    for issue in negative_fixtures[12]["incrementIssues"]
}
if cyclic_relations != {
    "linear-issue-41": ["linear-issue-42"],
    "linear-issue-42": ["linear-issue-41"],
}:
    fail("snapshot 12 does not encode the raw cyclic dependency relations")

PHASES = {
    "designApproved", "specHardened", "specApproved", "planning", "ready",
    "executionApproved", "executing", "inReview", "done", "abandoned",
}
NON_PHASE = {"decision", "progress", "blockerOpened", "blockerResolved", "handoff"}
NEXT = {
    "designApproved": "specHardened",
    "specHardened": "specApproved",
    "specApproved": "planning",
    "planning": "ready",
    "ready": "executionApproved",
    "executionApproved": "executing",
    "executing": "inReview",
    "inReview": "done",
}
CATEGORY = {
    "designApproved": "backlog",
    "specHardened": "backlog",
    "specApproved": "backlog",
    "planning": "backlog",
    "ready": "planned",
    "executionApproved": "planned",
    "executing": "started",
    "inReview": "started",
    "done": "completed",
    "abandoned": "canceled",
}
REPOSITORY = "https://github.com/acme/widgets"
PROJECT_CLIENT = "00000000-0000-4000-8000-000000000001"
PROJECT_ID = "project-native-1"


def client(number):
    return f"00000000-0000-4000-8000-{number:012d}"


def event(kind, native_id, number, predecessor=None, related=None, revision=1,
          supersedes=None, client_id=None):
    return {
        "schema": 1,
        "kind": "projectEvent",
        "clientId": client_id or client(number),
        "repository": REPOSITORY,
        "label": "woostack",
        "role": "feature",
        "projectId": PROJECT_ID,
        "event": kind,
        "revision": revision,
        "predecessorId": predecessor,
        "relatedIds": sorted(related or []),
        "supersedesId": supersedes,
        "id": native_id,
    }


def receipts(events):
    result = {}
    for item in events:
        result[item["id"]] = {**item, "source": "independent-read"}
    return result


def make_chain(kinds):
    result = []
    predecessor = None
    for index, kind in enumerate(kinds, start=10):
        item = event(kind, f"u-{index}", index, predecessor)
        result.append(item)
        predecessor = item["id"]
    return result


def validate(events, read_backs, native_category, replan_evidence=None):
    required = {
        "schema", "kind", "clientId", "repository", "label", "role", "projectId",
        "event", "revision", "predecessorId", "relatedIds", "supersedesId", "id",
    }
    grouped = defaultdict(list)
    native_ids = set()
    for item in events:
        if set(item) != required:
            raise ValueError("event envelope fields")
        if item["id"] in native_ids:
            raise ValueError("duplicate native id")
        native_ids.add(item["id"])
        try:
            uuid.UUID(item["clientId"])
        except (ValueError, TypeError):
            raise ValueError("invalid stable client id")
        if (item["schema"], item["kind"], item["repository"], item["label"],
                item["role"], item["projectId"]) != (
                1, "projectEvent", REPOSITORY, "woostack", "feature", PROJECT_ID):
            raise ValueError("managed identity conflict")
        if item["event"] not in PHASES | NON_PHASE:
            raise ValueError("unknown event")
        if not isinstance(item["revision"], int) or item["revision"] < 1:
            raise ValueError("invalid revision")
        if item["relatedIds"] != sorted(set(item["relatedIds"])):
            raise ValueError("related ids not sorted unique")
        receipt = read_backs.get(item["id"])
        if receipt is None or receipt.get("source") != "independent-read":
            raise ValueError("missing independent read-back")
        for key in required:
            if receipt.get(key) != item[key]:
                raise ValueError("conflicting read-back")
        grouped[item["clientId"]].append(item)

    current = []
    for revisions in grouped.values():
        kinds = {item["event"] for item in revisions}
        if len(kinds) != 1:
            raise ValueError("event kind changed across correction")
        by_revision = {}
        for item in revisions:
            if item["revision"] in by_revision:
                raise ValueError("duplicate revision")
            by_revision[item["revision"]] = item
        if sorted(by_revision) != list(range(1, len(revisions) + 1)):
            raise ValueError("missing revision")
        for revision in range(1, len(revisions) + 1):
            item = by_revision[revision]
            expected = None if revision == 1 else by_revision[revision - 1]["id"]
            if item["supersedesId"] != expected:
                raise ValueError("invalid supersession")
        current.append(by_revision[len(revisions)])

    phase_events = [item for item in current if item["event"] in PHASES]
    current_by_native = {item["id"]: item for item in phase_events}
    starts = [item for item in phase_events
              if item["event"] == "designApproved" and item["predecessorId"] is None]
    if len(starts) != 1:
        raise ValueError("invalid design start")
    for item in phase_events:
        if item is starts[0]:
            continue
        if item["predecessorId"] not in current_by_native:
            raise ValueError("missing predecessor")
    referenced = {item["predecessorId"] for item in phase_events if item["predecessorId"]}
    heads = [item for item in phase_events if item["id"] not in referenced]
    if len(heads) != 1:
        raise ValueError("multiple current heads")

    chain = []
    cursor = heads[0]
    visited = set()
    while cursor is not None:
        if cursor["id"] in visited:
            raise ValueError("phase cycle")
        visited.add(cursor["id"])
        chain.append(cursor)
        predecessor = cursor["predecessorId"]
        cursor = current_by_native.get(predecessor) if predecessor else None
    chain.reverse()
    if len(chain) != len(phase_events):
        raise ValueError("disconnected phase chain")

    for previous, following in zip(chain, chain[1:]):
        source, target = previous["event"], following["event"]
        if source == "ready" and target == "planning":
            evidence = (replan_evidence or {}).get(following["id"])
            if not evidence or evidence.get("source") != "independent-linear-and-github-read":
                raise ValueError("missing replan evidence")
            if evidence.get("projectId") != PROJECT_ID:
                raise ValueError("foreign replan evidence")
            if sorted(evidence.get("issueIds", [])) != following["relatedIds"]:
                raise ValueError("incomplete replan issue evidence")
            if evidence.get("branches") != [] or evidence.get("pullRequests") != []:
                raise ValueError("unsafe replan evidence")
        elif target == "abandoned":
            if source in {"done", "abandoned"}:
                raise ValueError("terminal abandonment")
        elif NEXT.get(source) != target:
            raise ValueError("illegal phase transition")

    for item in current:
        if item["event"] in NON_PHASE and item["predecessorId"] not in current_by_native:
            raise ValueError("non-phase event missing current phase")

    opened = {item["id"]: item for item in current if item["event"] == "blockerOpened"}
    resolved_counts = defaultdict(int)
    for item in current:
        if item["event"] != "blockerResolved":
            continue
        matches = [related for related in item["relatedIds"] if related in opened]
        if len(matches) != 1:
            raise ValueError("blocker resolution does not identify exact open blocker")
        resolved_counts[matches[0]] += 1
    if any(count != 1 for count in resolved_counts.values()):
        raise ValueError("blocker resolved multiple times")
    unresolved = [native for native in opened if resolved_counts[native] == 0]
    expected_category = "planned" if unresolved else CATEGORY[heads[0]["event"]]
    if native_category != expected_category:
        raise ValueError("native category conflicts with lifecycle read-back")
    return heads[0]["event"]


# Happy path.
happy = make_chain([
    "designApproved", "specHardened", "specApproved", "planning", "ready",
    "executionApproved", "executing", "inReview", "done",
])
if validate(happy, receipts(happy), "completed") != "done":
    fail("happy path did not reach done")

# Missing predecessor.
missing = make_chain(["designApproved", "specHardened", "specApproved"])
missing[-1]["predecessorId"] = "missing-native-update"
rejects("missing predecessor", lambda: validate(missing, receipts(missing), "backlog"))

# Duplicate revision of one stable event.
duplicate = make_chain(["designApproved", "specHardened"])
extra = copy.deepcopy(duplicate[-1])
extra["id"] = "u-duplicate-revision"
duplicate.append(extra)
rejects("duplicate revision", lambda: validate(duplicate, receipts(duplicate), "backlog"))

# Multiple valid-looking current heads.
branched = make_chain(["designApproved", "specHardened", "specApproved", "planning"])
branched.extend([
    event("ready", "u-ready-head", 70, branched[-1]["id"]),
    event("abandoned", "u-abandoned-head", 71, branched[-1]["id"]),
])
rejects("multiple current heads", lambda: validate(branched, receipts(branched), "planned"))

# Independent read-back conflicts with the mutation envelope.
conflict = make_chain(["designApproved", "specHardened"])
conflicting_receipts = receipts(conflict)
conflicting_receipts[conflict[-1]["id"]]["revision"] = 99
rejects("conflicting read-back", lambda: validate(conflict, conflicting_receipts, "backlog"))

# Append-only correction of the current phase.
corrected = make_chain(["designApproved", "specHardened", "specApproved", "planning", "ready"])
prior_ready = corrected[-1]
corrected.append(event(
    "ready", "u-ready-revision-2", 99, prior_ready["predecessorId"],
    revision=2, supersedes=prior_ready["id"], client_id=prior_ready["clientId"],
))
if validate(corrected, receipts(corrected), "planned") != "ready":
    fail("valid correction did not preserve ready")

# Evidence-backed ready-to-planning replan, plus missing-evidence rejection.
replan = make_chain(["designApproved", "specHardened", "specApproved", "planning", "ready"])
replan_event = event("planning", "u-replan", 120, replan[-1]["id"], related=["issue-1", "issue-2"])
replan.append(replan_event)
replan_proof = {
    replan_event["id"]: {
        "source": "independent-linear-and-github-read",
        "projectId": PROJECT_ID,
        "issueIds": ["issue-1", "issue-2"],
        "branches": [],
        "pullRequests": [],
    }
}
if validate(replan, receipts(replan), "backlog", replan_proof) != "planning":
    fail("evidence-backed replan did not return to planning")
rejects("replan without evidence", lambda: validate(replan, receipts(replan), "backlog"))

# Explicit abandonment from an active phase.
abandoned = make_chain(["designApproved", "specHardened", "specApproved", "planning"])
abandoned.append(event("abandoned", "u-abandoned", 130, abandoned[-1]["id"], related=["issue-1"]))
if validate(abandoned, receipts(abandoned), "canceled") != "abandoned":
    fail("valid abandonment did not become terminal")

# Exact blocker resolution preserves phase and restores its coarse category.
blockers = make_chain(["designApproved", "specHardened", "specApproved", "planning", "ready"])
phase_head = blockers[-1]["id"]
opened = event("blockerOpened", "u-blocker-open", 140, phase_head, related=["issue-1"])
resolved = event("blockerResolved", "u-blocker-resolved", 141, phase_head, related=[opened["id"]])
blockers.extend([opened, resolved])
if validate(blockers, receipts(blockers), "planned") != "ready":
    fail("resolved blocker changed the phase")
unresolved = blockers[:-1]
if validate(unresolved, receipts(unresolved), "planned") != "ready":
    fail("open blocker did not preserve phase under planned status")

print("test-linear-build-contract: ok")
PY
