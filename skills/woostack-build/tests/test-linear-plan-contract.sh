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
import os
import sys
import uuid
from pathlib import Path

root = Path(sys.argv[1])
paths = {
    "plan": root / "skills/woostack-plan/SKILL.md",
    "adapter": root / "skills/woostack-plan/references/linear-adapter.md",
    "authority": root / "skills/woostack-init/references/artifact-backends.md",
    "template": root / "skills/woostack-plan/references/plan-template.md",
    "tdd": root / "skills/woostack-tdd/SKILL.md",
    "router": root / "skills/using-woostack/SKILL.md",
    "test": root / "skills/woostack-build/tests/test-linear-plan-contract.sh",
    "runner": root / "skills/woostack-init/scripts/tests/run-tests.sh",
}
texts = {name: path.read_text(encoding="utf-8") for name, path in paths.items()}


def fail(message):
    raise SystemExit(f"test-linear-plan-contract: {message}")


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
if texts["runner"].count("test-linear-plan-contract.sh") != 1:
    fail("contract test must be registered exactly once")

workflow = "\n".join(texts[name] for name in ("plan", "adapter", "template", "tdd"))
for required in (
    "stable client UUID",
    "unique positive integer ordinal",
    "acceptance coverage",
    "Native Linear dependency/blocker",
    "exactly one Git parent declaration",
    "Ordinals are presentation order, never implicit dependency edges",
    "Independent tracks are explicit dependency roots",
    "preserving stable",
    "cannot be rewritten as unstarted",
    "independently read every",
    "cross-project dependencies",
    "Graphite ancestry that cannot represent the declared parent",
):
    must(workflow, required, "Linear planning contract")
for required in (
    "exact project UUID or URL **and** exact issue UUID or URL",
    "local code-test output only",
    "official host-exposed Linear MCP",
):
    must(texts["tdd"], required, "TDD artifact input contract")
for required in (
    "It is not a local file output",
    "native Linear `blocked by` relation",
    "independently read every mutation",
):
    must(texts["template"], required, "increment issue template")
for required in (
    "## Automated verification",
    "{{EXACT_AUTOMATED_COMMAND}}",
    "{{EXACT_MACHINE_CHECKED_RESULT}}",
    "## Manual verification",
    "{{EXACT_MANUAL_VERIFICATION_STEPS}}",
    "{{EXACT_OBSERVED_RESULT}}",
):
    must(texts["template"], required, "public verification fields")
if texts["template"].index("## Automated verification") > texts["template"].index("## Manual verification"):
    fail("public verification fields are out of order")
for forbidden in ("<plan-path>", "code block, PR, spec, or plan"):
    if forbidden.lower() in texts["router"].lower():
        fail(f"router-obsolete guidance returned: {forbidden!r}")

for forbidden in (
    "resolve-backend.sh",
    "linear.sh",
    "Markdown plan",
    ".woostack/plans/",
    "Normalized backend input",
    "Backend output contract",
):
    if forbidden.lower() in workflow.lower():
        fail(f"planning retains forbidden authority token {forbidden!r}")

PROJECT = "project-native-1"
BASE = "0123456789abcdef0123456789abcdef01234567"
PENDING_BASE = {"kind": "projectFrozenBase", "state": "pending"}


def bound_base(branch="main", sha=BASE):
    return {"kind": "projectFrozenBase", "state": "bound", "branch": branch, "sha": sha}


def client(number):
    return f"00000000-0000-4000-8000-{number:012d}"


def issue(number, ordinal, dependencies=(), parent=None, project=PROJECT, evidence=()):
    client_id = client(number)
    contract = {
        "objective": f"Deliver increment {number}",
        "files": [f"src/increment-{number}.ts"],
        "tasks": [f"Red {number}", f"Green {number}", f"Refactor {number}"],
        "acceptance": [f"AC-{number}"],
        "automated": [f"test increment {number}"],
        "manual": [f"exercise increment {number}"],
    }
    description = "\n".join(
        [contract["objective"]]
        + contract["files"]
        + contract["tasks"]
        + contract["acceptance"]
        + contract["automated"]
        + contract["manual"]
    )
    return {
        "clientId": client_id,
        "projectId": project,
        "role": "increment",
        "ordinal": ordinal,
        "dependencies": list(dependencies),
        "gitParent": copy.deepcopy(PENDING_BASE if parent is None else parent),
        "contract": contract,
        "description": description,
        "evidence": list(evidence),
    }


def validate(current, desired, receipts, acceptance_criteria, ready=False, frozen_branch=None, frozen_sha=None):
    desired_by_id = {}
    ordinals = set()
    for item in desired:
        try:
            uuid.UUID(item["clientId"])
        except (KeyError, TypeError, ValueError):
            raise ValueError("invalid stable identity")
        if item["clientId"] in desired_by_id:
            raise ValueError("duplicate stable identity")
        desired_by_id[item["clientId"]] = item
        if not isinstance(item["ordinal"], int) or item["ordinal"] < 1 or item["ordinal"] in ordinals:
            raise ValueError("invalid or duplicate ordinal")
        ordinals.add(item["ordinal"])
        if item["projectId"] != PROJECT or item["role"] != "increment":
            raise ValueError("ownership drift")
        required = {"objective", "files", "tasks", "acceptance", "automated", "manual"}
        if set(item["contract"]) != required or any(not item["contract"][key] for key in required):
            raise ValueError("incomplete issue contract")
        rendered = "\n".join(
            [item["contract"]["objective"]]
            + item["contract"]["files"]
            + item["contract"]["tasks"]
            + item["contract"]["acceptance"]
            + item["contract"]["automated"]
            + item["contract"]["manual"]
        )
        if item["description"] != rendered:
            raise ValueError("description drift")

    current_by_id = {item["clientId"]: item for item in current}
    removed = set(current_by_id) - set(desired_by_id)
    if removed:
        if any(current_by_id[item_id]["evidence"] for item_id in removed):
            raise ValueError("evidence-bearing issue removal")
        raise ValueError("silent issue removal")

    covered = set()
    graph = {}
    for item_id, item in desired_by_id.items():
        dependencies = item["dependencies"]
        if len(dependencies) != len(set(dependencies)):
            raise ValueError("duplicate dependency")
        if any(dependency not in desired_by_id for dependency in dependencies):
            raise ValueError("unknown or cross-project dependency")
        graph[item_id] = dependencies
        covered.update(item["contract"]["acceptance"])
        parent = item["gitParent"]
        if not dependencies:
            if not isinstance(parent, dict) or parent.get("kind") != "projectFrozenBase":
                raise ValueError("root lacks typed project base reference")
            if ready:
                if parent != bound_base(frozen_branch, frozen_sha):
                    raise ValueError("root parent is pending or bound to wrong frozen base")
            elif parent not in (PENDING_BASE, bound_base(frozen_branch, frozen_sha)):
                raise ValueError("invalid root base state")
        elif parent not in dependencies:
            raise ValueError("Git parent is not one dependency")

        prior = current_by_id.get(item_id)
        changed = prior is None or prior != item
        if changed:
            receipt = receipts.get(item_id)
            if receipt != {"source": "independent-read", "issue": item}:
                raise ValueError("missing or conflicting independent read-back")

    if set(acceptance_criteria) != covered:
        raise ValueError("acceptance coverage drift")

    visiting = set()
    visited = set()

    def visit(item_id):
        if item_id in visiting:
            raise ValueError("dependency cycle")
        if item_id in visited:
            return
        visiting.add(item_id)
        for dependency in graph[item_id]:
            visit(dependency)
        visiting.remove(item_id)
        visited.add(item_id)

    for item_id in graph:
        visit(item_id)
    return [item["clientId"] for item in sorted(desired, key=lambda value: value["ordinal"])]


def bind_roots_for_ready(current, branch, sha, receipts):
    desired = copy.deepcopy(current)
    for item in desired:
        if not item["dependencies"]:
            item["gitParent"] = bound_base(branch, sha)
            receipt = receipts.get(item["clientId"])
            if receipt != {"source": "independent-read", "issue": item}:
                raise ValueError("root base reconciliation lacks exact read-back")
    validate(current, desired, receipts, [f"AC-{n}" for n in (1, 2, 3)],
             ready=True, frozen_branch=branch, frozen_sha=sha)
    return desired


# Ordinal order deliberately differs from dependency order. The child with ordinal 1 depends on
# the root with ordinal 3; ordinal adjacency must not create or reject ancestry.
root_issue = issue(3, 3)
child = issue(1, 1, dependencies=(root_issue["clientId"],), parent=root_issue["clientId"])
independent = issue(2, 2)
desired = [child, independent, root_issue]
receipts = {
    item["clientId"]: {"source": "independent-read", "issue": item}
    for item in desired
}
if validate([], desired, receipts, ["AC-1", "AC-2", "AC-3"]) != [
    child["clientId"], independent["clientId"], root_issue["clientId"]
]:
    fail("valid graph did not preserve explicit ordinal presentation")
root_receipts = {}
for item in desired:
    if not item["dependencies"]:
        bound = copy.deepcopy(item)
        bound["gitParent"] = bound_base("main", BASE)
        root_receipts[item["clientId"]] = {"source": "independent-read", "issue": bound}
ready_graph = bind_roots_for_ready(desired, "main", BASE, root_receipts)
if any(item["gitParent"] != bound_base("main", BASE) for item in ready_graph if not item["dependencies"]):
    fail("not all roots bind to the exact frozen BASE")
rejects("ready with pending root", lambda: validate(
    desired, desired, {}, ["AC-1", "AC-2", "AC-3"], ready=True,
    frozen_branch="main", frozen_sha=BASE,
))
wrong_graph = copy.deepcopy(ready_graph)
wrong_graph[1]["gitParent"]["sha"] = "f" * 40
rejects("ready with wrong root SHA", lambda: validate(
    ready_graph, wrong_graph,
    {wrong_graph[1]["clientId"]: {"source": "independent-read", "issue": wrong_graph[1]}},
    ["AC-1", "AC-2", "AC-3"], ready=True, frozen_branch="main", frozen_sha=BASE,
))
partial_receipts = dict(root_receipts)
partial_receipts.pop(independent["clientId"])
rejects("partial root binding receipt", lambda: bind_roots_for_ready(
    desired, "main", BASE, partial_receipts,
))

# Replan updates content under the same stable identity and requires a fresh exact receipt.
current = copy.deepcopy(desired)
replanned = copy.deepcopy(desired)
replanned[0]["contract"]["objective"] = "Deliver the revised first increment"
replanned[0]["description"] = "\n".join(
    [replanned[0]["contract"]["objective"]]
    + replanned[0]["contract"]["files"]
    + replanned[0]["contract"]["tasks"]
    + replanned[0]["contract"]["acceptance"]
    + replanned[0]["contract"]["automated"]
    + replanned[0]["contract"]["manual"]
)
replan_receipts = {
    replanned[0]["clientId"]: {"source": "independent-read", "issue": replanned[0]}
}
validate(current, replanned, replan_receipts, ["AC-1", "AC-2", "AC-3"])
if replanned[0]["clientId"] != current[0]["clientId"]:
    fail("replan changed stable identity")

missing_receipt = copy.deepcopy(replan_receipts)
missing_receipt.clear()
rejects("mutation without read-back", lambda: validate(
    current, replanned, missing_receipt, ["AC-1", "AC-2", "AC-3"]
))

cycle = copy.deepcopy(desired)
cycle[2]["dependencies"] = [cycle[0]["clientId"]]
cycle[2]["gitParent"] = cycle[0]["clientId"]
cycle_receipts = {item["clientId"]: {"source": "independent-read", "issue": item} for item in cycle}
rejects("dependency cycle", lambda: validate([], cycle, cycle_receipts, ["AC-1", "AC-2", "AC-3"]))

foreign = copy.deepcopy(desired)
foreign[1]["projectId"] = "foreign-project"
foreign_receipts = {item["clientId"]: {"source": "independent-read", "issue": item} for item in foreign}
rejects("cross-project ownership", lambda: validate([], foreign, foreign_receipts, ["AC-1", "AC-2", "AC-3"]))

duplicate_ordinal = copy.deepcopy(desired)
duplicate_ordinal[1]["ordinal"] = duplicate_ordinal[0]["ordinal"]
duplicate_receipts = {
    item["clientId"]: {"source": "independent-read", "issue": item}
    for item in duplicate_ordinal
}
rejects("duplicate ordinal", lambda: validate(
    [], duplicate_ordinal, duplicate_receipts, ["AC-1", "AC-2", "AC-3"]
))

evidence_current = copy.deepcopy(desired)
evidence_current[1]["evidence"] = ["pull-request:https://example.invalid/2"]
removed = [evidence_current[0], evidence_current[2]]
rejects("evidence-bearing issue removal", lambda: validate(
    evidence_current, removed, {}, ["AC-1", "AC-3"]
))

bad_parent = copy.deepcopy(desired)
bad_parent[0]["gitParent"] = client(999)
bad_parent_receipts = {
    item["clientId"]: {"source": "independent-read", "issue": item}
    for item in bad_parent
}
rejects("unrepresentable Git parent", lambda: validate(
    [], bad_parent, bad_parent_receipts, ["AC-1", "AC-2", "AC-3"]
))

print("test-linear-plan-contract: ok")
PY
