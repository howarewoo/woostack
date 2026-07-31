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

TEAM_FIXTURE="$(mktemp -d)"
trap 'rm -rf "$TEAM_FIXTURE"' EXIT
mkdir -p "$TEAM_FIXTURE/.woostack"
jq -n '{
  linear: {
    repository: "https://github.com/acme/widgets",
    workspace: "Acme",
    team: "",
    projectStatuses: {},
    issueStates: {}
  }
}' > "$TEAM_FIXTURE/.woostack/config.json"
MISSING_LOCAL_TEAM="$("$ROOT/skills/woostack-init/scripts/config/resolve-config.sh" "$TEAM_FIXTURE" | jq -r '.linear.team')"
[[ -z "$MISSING_LOCAL_TEAM" ]] || {
  printf 'test-linear-build-contract: canonical resolver changed config without a local override\n' >&2
  exit 1
}
jq -n '{linear: {team: "Platform"}}' > "$TEAM_FIXTURE/.woostack/config.local.json"
RESOLVED_TEAM="$("$ROOT/skills/woostack-init/scripts/config/resolve-config.sh" "$TEAM_FIXTURE" | jq -r '.linear.team')"
[[ "$RESOLVED_TEAM" == "Platform" ]] || {
  printf 'test-linear-build-contract: canonical resolver did not yield effective local team\n' >&2
  exit 1
}
jq -n '{linear: {team: "   "}}' > "$TEAM_FIXTURE/.woostack/config.local.json"
if "$ROOT/skills/woostack-init/scripts/config/resolve-config.sh" "$TEAM_FIXTURE" >/dev/null 2>&1; then
  printf 'test-linear-build-contract: canonical resolver accepted malformed local team\n' >&2
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
    "adapter": root / "skills/woostack-plan/references/linear-adapter.md",
    "harden": root / "skills/woostack-harden/SKILL.md",
    "router": root / "skills/using-woostack/SKILL.md",
    "execute": root / "skills/woostack-execute/SKILL.md",
    "overnight": root / "skills/woostack-execute-overnight/SKILL.md",
    "tdd": root / "skills/woostack-tdd/SKILL.md",

    "ideate": root / "skills/woostack-ideate/SKILL.md",
    "spec_template": root / "skills/woostack-build/references/spec-template.md",
    "spec_template_html": root / "skills/woostack-build/references/spec-template.html",
    "build_evals": root / "skills/woostack-build/evals/evals.json",
    "project_gates": root / "skills/woostack-build/evals/fixtures/project-gates.json",
    "project_conflicts": root / "skills/woostack-build/evals/fixtures/project-update-conflict.json",
    "project_replan": root / "skills/woostack-build/evals/fixtures/project-replan.json",
    "build_state": root / "skills/woostack-build/evals/fixtures/build-state.json",
    "plan_evals": root / "skills/woostack-plan/evals/evals.json",
    "plan_triggers": root / "skills/woostack-plan/evals/trigger-evals.json",
    "test": root / "skills/woostack-build/tests/test-linear-build-contract.sh",
    "runner": root / "skills/woostack-init/scripts/tests/run-tests.sh",
    "resolver": root / "skills/woostack-init/scripts/config/resolve-config.sh",
    "authority": root / "skills/woostack-init/references/artifact-backends.md",
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
    "build", "procedure", "context", "plan", "adapter", "harden",
))
for forbidden in (
    "resolve-backend.sh",
    "linear.sh",
    "LINEAR_API_KEY",
    "LINEAR_CONTEXT",
    "spec-write",
    "feature-transition",
    "selected backend",
    "Markdown mode",
    "Linear spec document",
    "managed spec document",
    "GraphQL adapter",
):
    if forbidden.lower() in workflow.lower():
        fail(f"workflow retains forbidden authority/transport token {forbidden!r}")

def validate_correction_contract(text):
    lowered = re.sub(r"\s+", " ", text.lower())
    correction_classes = (
        ("phase event correction", "current phase head"),
        ("non-phase project event correction", "current revision"),
        ("managed issue comment/event correction", "current revision"),
    )
    for correction_class, scope in correction_classes:
        if correction_class not in lowered or scope not in lowered:
            raise ValueError(f"correction contract missing {correction_class!r} scope")
    for required in (
        "next revision",
        "supersedesid",
        "preserve",
        "predecessor",
        "project identity",
        "project-plus-issue identity",
        "independently read",
        "before mutation",
        "explicit human-directed recovery",
        "multi-write transaction",
        "no phase-head requirement",
        "does not advance, replace, or rewrite the phase chain",
    ):
        if required not in lowered:
            raise ValueError(f"correction contract missing {required!r}")
    if len(re.findall(r"never cascades? descendant revisions", lowered)) < 2:
        raise ValueError("correction contract does not forbid descendant cascades")
    if "append corrected revisions of every descendant" in lowered:
        raise ValueError("correction contract permits a descendant cascade")


for owner in ("procedure", "adapter"):
    validate_correction_contract(texts[owner])
    cascade_mutant, replacements = re.subn(
        r"never cascades? descendant revisions",
        "append corrected revisions of every descendant",
        texts[owner],
        count=1,
        flags=re.IGNORECASE,
    )
    if replacements != 1:
        fail(f"{owner} correction contract lacks one mutable no-cascade rule")
    rejects(
        f"{owner} descendant-cascade correction mutation",
        lambda mutant=cascade_mutant: validate_correction_contract(mutant),
    )

for required in (
    "resolve-config.sh",
    "resolved JSON",
    "missing or malformed effective team",
    "committed optional team",
    "config.local.json",
    "non-secret policy/context",
    "never alternate development-record authority",
):
    must(texts["context"], required, "effective Linear team resolution")
must(texts["authority"], "local team overrides the committed default", "canonical team authority")
if not os.access(paths["resolver"], os.X_OK):
    fail("canonical config resolver is not executable")


def validate_effective_config(config):
    linear = config.get("linear")
    if not isinstance(linear, dict):
        raise ValueError("missing resolved linear policy")
    for key in ("repository", "workspace", "team", "projectStatuses", "issueStates"):
        if key not in linear:
            raise ValueError(f"missing resolved {key}")
    for key in ("repository", "workspace", "team"):
        if not isinstance(linear[key], str) or not linear[key].strip():
            raise ValueError(f"malformed resolved {key}")
    return linear["team"]

effective_fixture = {
    "linear": {
        "repository": "https://github.com/acme/widgets",
        "workspace": "Acme",
        "team": "Platform",
        "projectStatuses": {},
        "issueStates": {},
    }
}
if validate_effective_config(effective_fixture) != "Platform":
    fail("build context rejected canonical effective local team")
missing_team = copy.deepcopy(effective_fixture)
missing_team["linear"]["team"] = ""
rejects("missing effective team", lambda: validate_effective_config(missing_team))

for required in (
    "official host-exposed Linear MCP",
    "`designApproved` project update",
    "caller owns shape classification and the Linear project-update lifecycle",
):
    must(texts["ideate"], required, "ideate handoff")
for required in (
    "`specHardened` project-update body template",
    "stable event `clientId`",
    "independently read the complete event and one-head lifecycle chain back",
):
    must(texts["spec_template"], required, "specification update template")
markdown_sections = re.findall(r"^## ([0-9]+\\. .+)$", texts["spec_template"], re.MULTILINE)
html_sections = [
    value.replace("&amp;", "&")
    for value in re.findall(r"<h2>([0-9]+\\. [^<]+)</h2>", texts["spec_template_html"])
]
if markdown_sections != html_sections:
    fail(f"specification Markdown/HTML section parity differs: {markdown_sections!r} != {html_sections!r}")
markdown_placeholders = set(re.findall(r"\{\{[^{}]+\}\}", texts["spec_template"]))
html_placeholders = set(re.findall(r"\{\{[^{}]+\}\}", texts["spec_template_html"]))
if markdown_placeholders != html_placeholders:
    fail(
        "specification Markdown/HTML placeholder parity differs: "
        f"{sorted(markdown_placeholders)!r} != {sorted(html_placeholders)!r}"
    )
for legacy in ("{{STATUS}}", "{{DATE}}", "{{BRANCH}}", "{{ARTIFACT_REFERENCE}}"):
    for template_name in ("spec_template", "spec_template_html"):
        if legacy in texts[template_name]:
            fail(f"{template_name} retains legacy metadata field {legacy!r}")
for required in ("specHardened", "independent read-back"):
    must(texts["spec_template_html"], required, "specification HTML mirror")

router_rows = {
    command: next(
        (line for line in texts["router"].splitlines() if line.startswith(f"| `/{command} ")),
        "",
    )
    for command in ("woostack-execute", "woostack-execute-overnight", "woostack-tdd")
}
for command in ("woostack-execute", "woostack-execute-overnight"):
    row = router_rows[command]
    must(row, "<artifact>", f"{command} router signature")
    if "<plan-path>" in row or "Linear project UUID-or-exact-URL" in row:
        fail(f"{command} router prematurely narrows its compatibility input")
    owner = texts["execute" if command == "woostack-execute" else "overnight"]
    must(owner, f"/{command} <artifact> [--inline | --subagent]", f"{command} owner signature")
    must(owner, ".woostack/plans/", f"{command} Markdown compatibility input")
    must(owner, "project UUID", f"{command} Linear compatibility input")

must(router_rows["woostack-tdd"], "/woostack-tdd <target>", "woostack-tdd router signature")
must(
    router_rows["woostack-tdd"],
    "code, a PR, or an exact verified Linear project and issue",
    "woostack-tdd router targets",
)
for stale_target in ("spec", "plan"):
    if re.search(rf"\b{stale_target}\b", router_rows["woostack-tdd"], re.IGNORECASE):
        fail(f"woostack-tdd router retains stale {stale_target} target")
for required in (
    "/woostack-tdd <target>",
    "| **code** |",
    "| **PR** |",
    "| **Linear issue** | exact project UUID or URL **and** exact issue UUID or URL |",
):
    must(texts["tdd"], required, "woostack-tdd owner targets")
for stale_target in ("Markdown spec", "Markdown plan", "| **spec** |", "| **plan** |"):
    if stale_target in texts["tdd"]:
        fail(f"woostack-tdd owner retains stale target {stale_target!r}")

for required in (
    "Markdown is the default feature spec/plan backend",
    "routing never infers storage",
    "spec : plan : PRs = 1 : 1 : N",
):
    must(texts["router"], required, "temporary router authority")
if "official host-exposed Linear MCP is the only" in texts["router"]:
    fail("router prematurely claims Linear-only global development authority")

build_state = json.loads(texts["build_state"])
if build_state["executor"] != {
    "acceptsRetainedProjectEventContext": False,
    "legacyDependencies": ["backend-resolver", "managed-spec-document"],
}:
    fail("build compatibility fixture no longer identifies the legacy executor boundary")
for required in (
    "incompatible executor is a blocker at `ready`",
    "append no `executionApproved`",
    "create no Git artifact",
):
    must(texts["build"], required, "build compatibility barrier")

build_evals = json.loads(texts["build_evals"])
plan_evals = json.loads(texts["plan_evals"])
plan_triggers = json.loads(texts["plan_triggers"])
build_case_ids = [case["id"] for case in build_evals["cases"]]
for case_id in (
    "enforces-project-gates-and-bounded-routing",
    "fails-closed-on-project-update-conflicts",
    "refuses-unsafe-project-replan",
):
    if build_case_ids.count(case_id) != 1:
        fail(f"build evaluation corpus must own {case_id!r} exactly once")
if [case["id"] for case in plan_evals["cases"]] != [
    "reconciles-stable-increments-with-native-dependencies",
    "refuses-evidence-bearing-issue-removal",
]:
    fail("plan evaluation corpus differs from the exact reconciliation contract")
if [case["id"] for case in plan_triggers["cases"]] != [
    "verified-feature-project-needs-decomposition",
    "verified-feature-project-needs-replan",
    "unapproved-feature-idea-needs-design",
    "bounded-change-needs-direct-workflow",
]:
    fail("plan trigger corpus differs from the exact routing contract")

conflicts = json.loads(texts["project_conflicts"])
if [case["id"] for case in conflicts["cases"]] != [
    "missing-predecessor",
    "duplicate-revision",
    "multiple-phase-heads",
    "stale-update",
    "unsupported-schema",
    "failed-read-back",
]:
    fail("project conflict fixture differs from the exact fail-closed matrix")
if conflicts["expectedForEveryCase"] != {"advance": False, "repositoryEffects": []}:
    fail("project conflict fixture permits advancement or repository effects")
gates = json.loads(texts["project_gates"])
if gates["expectedRouting"] != {
    "route": "woostack-change",
    "projectCreated": False,
    "advance": False,
    "repositoryEffects": [],
}:
    fail("bounded project-gate fixture permits project creation")
replan = json.loads(texts["project_replan"])
if replan["expected"]["reasonCode"] != "evidence-bearing-issue-removal-refused":
    fail("project replan fixture permits evidence-bearing issue removal")

for required in (
    "official host-exposed Linear MCP",
    "canonical repository URL",
    "projectEvent",
    "stable event `clientId`",
    "revision",
    "predecessorId",
    "supersedesId",
    "exactly one current lifecycle chain",
    "ideate → designApproved → harden specification → specHardened → specApproved →",
    "planning → harden increment graph → ready → executionApproved → execute → inReview → done",
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
    "event UUID at exactly the next revision",
    "new `abandoned` phase event",
    "`blockerOpened`",
    "`blockerResolved`",
    "native `paused`",
    "native `canceled`",
):
    must(texts["procedure"], token, "Linear procedure")
for token in (
    "phase event correction may target only the current phase head",
    "non-head phase correction stops before mutation",
    "non-phase project event correction may target only that event's current revision",
    "managed issue comment/event correction may target only that issue event's current revision",
    "never cascades descendant revisions",
    "missing receipt",
):
    must(texts["procedure"], token, "crash-safe correction contract")
must(texts["procedure"], "uses the non-phase project event rule above, not the phase", "blocker correction")
for token in (
    "one managed `increment` issue",
    "stable client UUID",
    "native Linear relations",
    "unique positive ordinal",
    "acceptance criterion",
    "independent complete read-back",
):
    must(texts["plan"] + texts["adapter"], token, "Linear planning")
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
    expected_category = "paused" if unresolved else CATEGORY[heads[0]["event"]]
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

def current_revisions(events):
    grouped = defaultdict(list)
    for item in events:
        grouped[item["clientId"]].append(item)
    result = {}
    for client_id, revisions in grouped.items():
        revision_numbers = sorted(item["revision"] for item in revisions)
        if revision_numbers != list(range(1, len(revisions) + 1)):
            raise ValueError("skipped or duplicate revision")
        candidates = [item for item in revisions if item["revision"] == len(revisions)]
        if len(candidates) != 1:
            raise ValueError("competing current revisions")
        result[client_id] = candidates[0]
    return result


def correction_candidate(events, target_native_id, correction_class, receipt_ids):
    currents = current_revisions(events)
    targets = [item for item in currents.values() if item["id"] == target_native_id]
    if len(targets) != 1:
        raise ValueError("stale or ambiguous correction target blocked before mutation")
    target = targets[0]
    if target["id"] not in receipt_ids:
        raise ValueError("missing exact receipt blocked before mutation")
    if correction_class == "phase":
        phase_events = [item for item in currents.values() if item["event"] in PHASES]
        referenced = {item["predecessorId"] for item in phase_events if item["predecessorId"]}
        heads = [item for item in phase_events if item["id"] not in referenced]
        if len(heads) != 1 or heads[0]["id"] != target_native_id:
            raise ValueError("historical correction blocked before mutation")
    elif correction_class == "non-phase":
        if target["event"] not in NON_PHASE:
            raise ValueError("wrong non-phase correction kind")
    else:
        raise ValueError("unknown project correction class")
    return event(
        target["event"], f"{target['id']}-correction", 999,
        target["predecessorId"], related=target["relatedIds"],
        revision=target["revision"] + 1, supersedes=target["id"],
        client_id=target["clientId"],
    )


def issue_event(native_id, number, revision=1, supersedes=None, client_id=None,
                project_id=PROJECT_ID, issue_id="issue-native-1", kind="verification"):
    return {
        "schema": 1, "kind": "issueEvent", "clientId": client_id or client(number),
        "repository": REPOSITORY, "label": "woostack", "role": "increment",
        "projectId": project_id, "issueId": issue_id, "event": kind,
        "revision": revision, "relatedIds": [], "supersedesId": supersedes,
        "id": native_id,
    }


def issue_correction_candidate(events, target_native_id, receipt_ids):
    target = next((item for item in current_revisions(events).values()
                   if item["id"] == target_native_id), None)
    if target is None or target["id"] not in receipt_ids:
        raise ValueError("stale or missing-receipt issue correction")
    if (target["kind"], target["repository"], target["label"], target["role"],
            target["projectId"], target["issueId"]) != (
            "issueEvent", REPOSITORY, "woostack", "increment", PROJECT_ID, "issue-native-1"):
        raise ValueError("issue correction identity drift")
    return issue_event(
        f"{target['id']}-correction", 998, revision=target["revision"] + 1,
        supersedes=target["id"], client_id=target["clientId"],
        project_id=target["projectId"], issue_id=target["issueId"], kind=target["event"],
    )


# Append-only correction of the current phase requires its exact receipt.
corrected = make_chain(["designApproved", "specHardened", "specApproved", "planning", "ready"])
prior_ready = corrected[-1]
phase_correction = correction_candidate(corrected, prior_ready["id"], "phase", {prior_ready["id"]})
corrected.append(phase_correction)
if validate(corrected, receipts(corrected), "planned") != "ready":
    fail("valid correction did not preserve ready")
historical = make_chain(["designApproved", "specHardened", "specApproved"])
before_historical = copy.deepcopy(historical)
rejects("historical correction before mutation", lambda: correction_candidate(
    historical, historical[1]["id"], "phase", {historical[1]["id"]},
))
if historical != before_historical:
    fail("blocked historical correction mutated the chain")
rejects("phase correction missing receipt", lambda: correction_candidate(
    historical, historical[-1]["id"], "phase", set(),
))
interrupted = make_chain(["designApproved", "specHardened", "specApproved", "planning"])
pending_correction = correction_candidate(
    interrupted, interrupted[-1]["id"], "phase", {interrupted[-1]["id"]},
)
interrupted.append(pending_correction)
interrupted_receipts = receipts(interrupted[:-1])
rejects("interrupted head correction", lambda: validate(
    interrupted, interrupted_receipts, "backlog",
))

# A current non-phase blocker revision need not be phase head and cannot alter the phase chain.
blocker_chain = make_chain(["designApproved", "specHardened", "specApproved", "planning", "ready"])
blocker_head = blocker_chain[-1]
blocker = event("blockerOpened", "u-blocker-current", 995, blocker_head["id"], related=["issue-1"])
before_phase_ids = [item["id"] for item in blocker_chain]
blocker_correction = correction_candidate(
    blocker_chain + [blocker], blocker["id"], "non-phase", {blocker["id"]},
)
if blocker_correction["predecessorId"] != blocker_head["id"]:
    fail("blocker correction changed contextual phase predecessor")
if [item["id"] for item in blocker_chain] != before_phase_ids:
    fail("blocker correction altered phase chain")
rejects("stale non-phase correction", lambda: correction_candidate(
    blocker_chain + [blocker, blocker_correction], blocker["id"], "non-phase", {blocker["id"]},
))

# A managed issue-comment correction needs exact project+issue identity, not a phase head.
comment = issue_event("comment-current", 996)
comment_correction = issue_correction_candidate([comment], comment["id"], {comment["id"]})
for identity_field in ("projectId", "issueId", "event", "clientId"):
    if comment_correction[identity_field] != comment[identity_field]:
        fail(f"issue correction changed {identity_field}")
rejects("issue correction missing receipt", lambda: issue_correction_candidate(
    [comment], comment["id"], set(),
))
foreign_comment = issue_event("comment-foreign", 997, issue_id="issue-native-foreign")
rejects("issue correction wrong identity", lambda: issue_correction_candidate(
    [foreign_comment], foreign_comment["id"], {foreign_comment["id"]},
))

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
if validate(unresolved, receipts(unresolved), "paused") != "ready":
    fail("open blocker did not preserve phase under paused status")

print("test-linear-build-contract: ok")
PY
