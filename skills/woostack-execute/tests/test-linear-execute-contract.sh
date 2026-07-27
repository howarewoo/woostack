#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import json
from copy import deepcopy
from datetime import datetime, timezone
import sys
import uuid
from pathlib import Path

root = Path(sys.argv[1])
paths = {
    "execute": root / "skills/woostack-execute/SKILL.md",
    "controller": root / "skills/woostack-execute/references/controller.md",
    "inline": root / "skills/woostack-execute/references/inline-driver.md",
    "subagent": root / "skills/woostack-execute/references/subagent-driver.md",
    "worktrees": root / "skills/woostack-init/references/worktrees.md",
    "authority": root / "skills/woostack-init/references/artifact-backends.md",
    "context": root / "skills/woostack-build/references/linear-context.md",
    "commit": root / "skills/woostack-commit/references/linear-attribution.md",
    "fixture": root / "skills/woostack-execute/evals/fixtures/execution-record.json",
    "evals": root / "skills/woostack-execute/evals/evals.json",
}


def fail(message):
    raise SystemExit(f"test-linear-execute-contract: {message}")


def normalized(value):
    return " ".join(value.split())


def must(text, token, scope):
    if normalized(token) not in normalized(text):
        fail(f"{scope} missing {token!r}")


def must_not(text, token, scope):
    if normalized(token) in normalized(text):
        fail(f"{scope} unexpectedly contains {token!r}")


def ordered(text, tokens, scope):
    searchable = normalized(text)
    position = -1
    for token in tokens:
        position = searchable.find(normalized(token), position + 1)
        if position < 0:
            fail(f"{scope} missing or misorders {token!r}")


def section(text, start, end=None):
    try:
        begin = text.index(start)
        finish = len(text) if end is None else text.index(end, begin + len(start))
    except ValueError:
        fail(f"section boundary missing: {start!r} -> {end!r}")
    return text[begin:finish]


for name, path in paths.items():
    if not path.is_file():
        fail(f"required {name} file missing: {path}")
texts = {
    name: path.read_text(encoding="utf-8")
    for name, path in paths.items()
    if name != "fixture"
}
fixture = json.loads(paths["fixture"].read_text(encoding="utf-8"))

execute = texts["execute"]
controller = texts["controller"]
inline = texts["inline"]
subagent = texts["subagent"]
worktrees = texts["worktrees"]
authority = texts["authority"]
commit_contract = texts["commit"]
combined_active = "\n".join((execute, controller, inline, subagent, worktrees))
eval_cases = {
    case["id"]: case
    for case in json.loads(texts["evals"]).get("cases", [])
}
for case_id, tokens in {
    "admits-verified-independent-root": (
        "raw canonical comment record's exact six-field shape",
        "current revision/supersession chain",
        "never array position",
    ),
    "admits-verified-standalone-issue": (
        "uniquely current raw canonical assignmentAccepted revision",
        "native ID/timestamp/actor",
        "never select by array position",
    ),
    "resumes-only-after-complete-handoff": (
        "outgoing current assignment",
        "sorted recovery evidence",
        "deliberate type-aware owner change with complete issue read-back",
        "successor owner's assignmentAccepted related exactly to the handoff native comment",
        "malformed, partial, stale, foreign, missing, duplicate, temporally invalid",
    ),
}.items():
    prompt = eval_cases.get(case_id, {}).get("prompt", "")
    for token in tokens:
        must(prompt, token, f"{case_id} canonical eval contract")

# Linear issues are the only active execution authority. Old selectable/local execution paths and
# repository adapter calls may not survive as workflow instructions.
for token in (
    "Official host-exposed Linear MCP is the only development-record authority",
    "one verified role-`feature` project and its complete role-`increment` issue DAG",
    "one verified standalone role-`work-item` issue",
    "There is no local",
    "Git and GitHub remain",
    "exact Linear project UUID-or-URL",
    "exact standalone issue UUID-or-URL",
    "shared [engineer-agent authority protocol]",
):
    must(execute, token, "execute authority")
for forbidden in (
    "resolve-backend.sh",
    "linear.sh",
    "## Markdown backend",
    "named Markdown plan",
    "normalized ordered task list",
    "Tick the plan",
    "plan's checkboxes",
    "the plan file is the live progress record",
    "specDesignState",
    "LINEAR_API_KEY",
    "api.linear.app/graphql",
):
    must_not(combined_active, forbidden, "active execute surface")
for token in (
    "never reads or writes a local specification, plan, checkbox/progress record, or lifecycle mirror",
    "calls no repository Linear adapter or custom HTTP/GraphQL transport",
    "A local artifact or mutation response is never a receipt",
    "No issue description checkbox, PR body alone, commit message, local report",
):
    must(controller if token != "A local artifact or mutation response is never a receipt" else execute,
         token, "local-authority rejection")

# Mode selection must never collapse an admitted engineer pair into inline decision-maker coding.
mode = section(execute, "## Execution mode", "## Review the verified issue before work")
pair_mode_required = (
    "classify the authority envelope before selecting a driver",
    "complete engineer pair has the shared protocol's verified decision-maker profile/session",
    "separately isolated paired coding profile/session",
    "partial, stale, shared, or inferred pair is invalid and blocks",
    "available only to deliberately non-paired execution",
    "isolated paired coder implements and self-checks each task",
    "decision-maker directly performs the ordered task-scoped spec review then quality review",
    "For deliberately non-paired execution, preserve the generic route",
    "An admitted engineer pair must use its paired subagent route",
    "Reject explicit `--inline` before any worker dispatch",
    "If the host cannot spawn the exact bound paired coder, stop at that same verified boundary",
    "Never fall back to inline, let the decision-maker implement or self-review",
    "Only deliberately non-paired execution uses the generic mode resolution",
    "If explicit subagent mode is unavailable, state the degradation and either fall back to inline or stop",
    "Generic non-paired execution keeps official-MCP mutations and source-control boundaries with the controller",
    "exact post-review, controller-authorized paired-coder `woostack-commit` handoff",
)
for token in pair_mode_required:
    must(mode, token, "engineer-pair mode selection")
ordered(mode, (
    "classify the authority envelope before selecting a driver",
    "An admitted engineer pair must use its paired subagent route",
    "Reject explicit `--inline`",
    "Only deliberately non-paired execution uses the generic mode resolution",
), "engineer-pair mode precedence")

pair_mode_forbidden = (
    "An admitted engineer pair may use inline.",
    "If the paired coder spawn is unavailable, fall back to inline.",
    "The decision-maker may implement and self-review when the paired coder is unavailable.",
    "An invalid partial engineer pair may use deliberately non-paired fallback.",
)
def pair_mode_contradictions(subject):
    folded = normalized(subject)
    return tuple(token for token in pair_mode_forbidden if normalized(token) in folded)


if pair_mode_contradictions(mode):
    fail("engineer-pair mode selection contains a contradictory inline/fallback permission")

# Adversarially retain every reassuring clause while injecting one contradictory permission.
for mutation in pair_mode_forbidden:
    mutant = mode + "\n" + mutation
    if mutation not in pair_mode_contradictions(mutant):
        fail(f"engineer-pair mode adversarial mutation escaped rejection: {mutation}")

commit_mode = section(
    execute,
    "6. **Commit, submit, and attribute.**",
    "7. **Distill only durable knowledge.**",
)
for token in (
    "On deliberately non-paired execution, the controller invokes",
    "For an engineer pair, the decision-maker instead issues the subagent driver's one bounded post-review authorization",
    "paired coder invokes that same skill",
    "only its own isolated Git/Graphite/GitHub and official Linear MCP contexts",
    "appends and reads back `implementationEvidence`",
    "create or refresh and read back the exact Linear relation",
    "on initial submission only",
    "request `executing → inReview` and read the state back",
    "later update must independently confirm that the issue remains `inReview` without replaying the transition",
):
    must(commit_mode, token, "route-specific commit boundary")


# Exact project-DAG and standalone admission pin the lead, issue roles, complete relations, and
# official capability/read-back boundary.
binding = section(controller, "## 1. Discover capabilities and bind exact input", "## 2. Resolve allocation and the next issue")
for token in (
    "Discover official Linear MCP tools by advertised capability",
    "configured workspace/team",
    "exactly one pinned project lead",
    "`executionApproved` for a fresh run",
    "immutable base branch and commit SHA",
    "every project issue and page",
    "role-`increment`",
    "exactly one approved Git-parent declaration",
    "Standalone issue",
    "role-`work-item`",
    "no native project membership",
    "role-`increment` issue is not standalone",
    "Every required page and explicit empty result must be known",
):
    must(binding, token, "input binding")

allocation = section(controller, "## 2. Resolve allocation and the next issue", "## 3. Prove relation and Git ancestry readiness")
for token in (
    "project lead owns issue contracts",
    "standalone dispatcher",
    "human engineer's resolved work owner is the native assignee",
    "app engineer's resolved work owner is the native delegate",
    "neither field is a fallback",
    "Never self-claim",
    "stable `ENGINEER_NAME`, exact Linear principal kind/native ID",
    "fresh run ID",
    "currently `executing` issue already accepted by this same engineer/run",
    "`blocked` issue whose verified `unblocked` receipt",
    "lowest-ordinal `planned` issue",
    "allocation collision",
):
    must(allocation, token, "allocation and owner resolution")
ordered(allocation, (
    "currently `executing` issue already accepted",
    "`blocked` issue whose verified `unblocked` receipt",
    "optional caller-supplied issue",
    "lowest-ordinal `planned` issue",
), "issue selection precedence")

# Claim requires visible assign-then-accept and independent read-back before Git or edits.
claim = section(controller, "## 4. Accept assignment and claim lifecycle", "## 5. Discovery, collision, and recovery")
ordered(claim, (
    "Re-read the pinned project lead or dispatcher authority",
    "Require deliberate assignment",
    "Transition `planned → executing`",
    "independently read the exact issue",
    "Preallocate one stable event UUID",
    "append `assignmentAccepted` revision 1",
    "Independently list/read the issue comments",
    "before acquiring a registry entry",
), "assignment claim")
for token in (
    "matching owner kind, principal ID, stable engineer name, and run ID",
    "No branch, worktree, edit, test mutation, commit, push, or PR action may precede",
    "do not append a replacement",
    "only the pinned lead may append the single `executing` project phase event",
    "coding worker cannot perform or authorize that project mutation",
):
    must(claim, token, "assignment claim barriers")

# Relation ancestry allows independent frozen roots while forcing exact parent ancestry and merged
# non-parent dependencies.
ancestry = section(controller, "## 3. Prove relation and Git ancestry readiness", "## 4. Accept assignment and claim lifecycle")
for token in (
    "exact frozen commit SHA",
    "Graphite tracks the exact frozen base branch",
    "Two roots may proceed in parallel only when",
    "declares exactly one native dependency as its Git parent",
    "parent issue's exact branch, finalized head commit, `implementationEvidence`, canonical PR",
    "Create the child from the resulting exact parent branch/head",
    "Every other native dependency is a non-parent dependency",
    "must already be `done`",
    "responsible `acceptance`",
    "canonical GitHub merge evidence",
    "An open or merely reachable non-parent PR is not sufficient",
    "Reject a newer base tip, ordinal-derived parent",
):
    must(ancestry, token, "relation-derived ancestry")

# The sole greenfield bootstrap write is a pre-repository primary scaffold, not an implementation
# worktree or reusable escape from issue-owned isolation.
bootstrap_boundary = section(
    worktrees,
    "## Artifact-backend boundary",
    "## 1. Verified start point",
)
for token in (
    "Only `woostack-bootstrap` has a pre-repository exception",
    "may cross that boundary exactly once",
    "explicit approval",
    "official host-exposed Linear MCP/config preflight",
    "managed role-`feature` project receipt",
    "stable `designApproved` receipt",
    "No target-filesystem action or Git invocation may occur before those barriers",
    "first target action is a read-only collision check with no Git invocation",
    "absent or is a real, fully listed, empty, non-symlink, non-Git directory",
    "single initial scaffold in the primary directory",
    "It is not an issue worktree",
    "is not a reusable bypass for implementation work",
    "exception is consumed as soon as Git metadata or repository state exists",
    "every implementation write requires",
    "exact issue-owned registry, branch, and worktree lifecycle",
    "primary checkout is never an implementation workspace",
    "does not reopen the exception",
):
    must(bootstrap_boundary, token, "fresh-repository bootstrap boundary")

# Registry is exact-ID keyed, disposable, collision-aware, and never authoritative.
for token in (
    "$WOOSTACK_ROOT/.woostack/worktrees/.registry/<exact-native-linear-issue-id>/claim.json",
    "directory name is the exact native Linear issue ID",
    "exact native and stable client issue IDs",
    "exact native and stable client project IDs",
    "type-aware owner kind/principal",
    "The registry is not assignment, scope, dependency, phase, approval, evidence, acceptance, branch,",
    "Create the per-issue directory atomically",
    "A missing entry plus complete absence",
    "a collision and blocks",
    "On a verified handoff, preserve the entry and worktree",
    "machine-local",
):
    must(worktrees, token, "exact-ID registry")
for token in (
    "Discovery before create, resume, or review-reopen",
    "Fresh:",
    "Exact resume:",
    "Verified review-reopen:",
    "Collision or unknown:",
    "prior §7 teardown",
    "exact issue is still `inReview`",
    "exactly one active candidate is a current, unexpired, unconsumed",
    "canonical claim and worktree path are proven free",
    "branch is checked out nowhere",
    "no other",
    "checkout, worktree, claim, active operation, candidate authorization, or collision",
    "atomically create only the authorization-bound exact-ID claim",
    'git worktree add "$wt" "$branch"',
    "Fresh creation and exact-resume behavior are unchanged",
    "No assignee/delegate mutation or replacement",
    "Once matching rewritten `implementationEvidence` consumes the",
    "timeout or command error proves neither absence nor failure",
    "path is derived from the exact native issue ID",
    "immediately before the first tracked edit in each task",
    "before commit, before push, and before PR creation/update/submission",
    "one implementation branch, one active worktree, and at most one",
):
    must(worktrees, token, "worktree discovery and owner barriers")

# All issue evidence is a typed append-only event with stable identity and a complete independent
# comment read-back. Unknown outcomes stop at the first boundary.
evidence = section(controller, "## 7. Typed evidence cadence", "## 8. Blocked restoration and handoff")
for token in (
    "append-only `issueEvent`",
    "stable `clientId` before mutation",
    "revision + 1",
    "`supersedesId`",
    "assignmentAccepted",
    "verification",
    "precommitReview",
    "implementationEvidence",
    "decisionRequest",
    "failure",
    "blocked` / `unblocked",
    "handoff",
    "reviewResult",
    "restackAuthorized",
    "acceptance",
    "issueDone",
    "independently list/read comments through complete pagination",
    "exactly one current unsuperseded event",
    "The next side effect remains forbidden",
):
    must(evidence, token, "typed issue evidence")

for token in (
    "issue-wide spec reviewer then quality reviewer",
    "readable data contains exactly `issueId`, `actor`, `reviewerReceipts`",
    "native author/payload actor/authenticated controller",
    "It has no commit/head/PR/GitHub receipt field",
    "reverse-binds those two current receipts",
    "passing `precommitReview`",
    "pre-commit event never relates forward",
    "exclusively later post-PR evidence",
):
    must(evidence, token, "precommit review and post-PR separation")

for token in (
    "Construct the sorted canonical `relatedIds` from exactly the current `assignmentAccepted`",
    "passing `verification` native comment ID, passing `precommitReview` native comment ID",
    "A normal first or later commit has no `restackAuthorized` relation",
    "add exactly its independently verified `restackAuthorized` native comment",
    "authenticated controller, native comment author, current type-aware owner",
    "native author/authenticated controller must instead equal",
    "reverse-binds the existing `verification` and `precommitReview`",
    "never the latest event by kind",
    "`authorizationTime < completionTime <= expiresAt`",
):
    must(commit_contract, token, "canonical implementation evidence revisions")

for token in (
    "assignmentAccepted | verification | precommitReview | implementationEvidence",
    "Readers dispatch every managed issue comment solely by its canonical `event` value",
    "`precommitReview` contains exactly `issueId`, `actor`, `reviewerReceipts`",
    "`implementationEvidence` contains exactly `baseCommitSha`, `headCommitSha`",
    "passing `verification`, passing `precommitReview`",
    "No producer may relate to a future event",
    "post-PR `reviewResult` instead relates back",
):
    must(authority, token, "canonical evidence authority")
for event in (
    "assignmentAccepted", "verification", "precommitReview", "implementationEvidence",
    "restackAuthorized", "decisionRequest", "decisionResponse", "reviewResult", "failure",
    "blocked", "unblocked", "handoff", "acceptance", "issueDone",
):
    must(authority, f"- `{event}`", f"canonical {event} dispatch")

unknowns = section(controller, "## 9. Commit, PR, and lifecycle boundary", "## 10. Teardown and handback")
ordered(unknowns, (
    "finalized commit → implementationEvidence read-back",
    "push/Graphite submission",
    "canonical GitHub PR read-back",
    "exact Linear branch/PR relation read-back",
    "inReview read-back",
), "commit and attribution evidence")
for token in (
    "rechecks the type-aware owner before the commit boundary",
    "immediately before push",
    "before PR creation/update/submission",
    "On timeout/error/unknown result",
    "continue without replay",
    "partial application",
    "Never allocate a replacement event UUID",
    "Only exact PR and relation evidence permits `executing → inReview`",
):
    must(unknowns, token, "unknown outcome and owner barriers")

# Block/unblock restoration and handoff are explicit and cannot be inferred from native state or a
# local recovery claim.
restore = section(controller, "## 8. Blocked restoration and handoff", "## 9. Commit, PR, and lifecycle boundary")
ordered(restore, (
    "append/read back `blocked`",
    "exact previous semantic state",
    "transition/read back native `blocked`",
    "append/read back `unblocked`",
    "prove no unresolved blocker remains",
    "transition/read back the exact recorded prior state",
), "issue blocker restoration")
for token in (
    "`blockerOpened`",
    "native paused",
    "`blockerResolved`",
    "unchanged project phase",
    "current owner appends/read backs `handoff`",
    "changes the correct assignee/delegate",
    "new `assignmentAccepted`",
    "old run stops permanently",
):
    must(restore, token, "blocker and handoff protocol")

# Drivers retain both deliberately non-paired execution and the engineer-pair subagent route, with
# one issue per worker and no contract, allocation, gate, project-state, or acceptance authority.
for name, text in (("inline", inline), ("subagent", subagent)):
    for token in (
        "exactly one Linear issue",
        "type-aware owner",
        "assignmentAccepted",
        "Red → Green → Refactor",
        "changed-path smoke",
        "one issue",
    ):
        must(text, token, f"{name} one-issue driver")
for token in (
    "acts only as the coding worker",
    "gains no project, allocation, contract, gate",
    "Return evidence, not progress mutation",
    "never creates/edits project updates, issue contracts, acceptance criteria",
    "never commits, pushes, submits",
    "self-review is implementation evidence, never responsible acceptance",
):
    must(inline, token, "inline authority barrier")
for token in (
    "Every dispatched paired coder, generic implementer, or generic reviewer brief is self-contained",
    "names exactly one selected issue",
    "Never supply a local specification,",
    "must never load or follow `skill://woostack-review`",
    "edit the issue description, scope, acceptance criteria",
    "append project updates",
    "accept its own evidence",
    "request/write terminal `done`",
    "Implementation workers are never dispatched in parallel",
    "There is no per-task commit",
    "do not edit issue text, tick checkboxes, append local receipts, or mutate Linear",
):
    must(subagent, token, "subagent authority barrier")

# Terminal state is acceptance- and merge-aware. Execute never merges or declares a partially done
# project complete.
for token in (
    "`inReview` requires the exact implementation evidence",
    "type-aware responsible acceptance authority",
    "independently verified GitHub merge evidence",
    "Execute never merges and does not write premature `done`",
    "project may reach `done` only after every managed issue",
    "One open, blocked, unknown, unmerged, or unaccepted issue",
):
    must(execute, token, "terminal lifecycle")
for token in (
    "planned → executing → inReview → done",
    "project `inReview` only after a fresh complete DAG",
    "non-phase `progress` project event",
    "native comment ID/timestamps",
    "Project `done` additionally requires every managed issue independently `done`",
):
    must(controller, token, "controller lifecycle")

# The fixture is behavior-oriented: a small classifier proves local authority, owner/registry
# collision, unsafe dependency ancestry, incomplete receipts, and premature done all fail closed.
if fixture.get("schemaVersion") != 1:
    fail("fixture schemaVersion must be 1")
if fixture.get("repository") != "https://github.com/acme/widgets":
    fail("fixture repository must be canonical")
scenarios = fixture.get("scenarios")
if not isinstance(scenarios, list) or not scenarios:
    fail("fixture scenarios must be a non-empty list")
if len({item.get("id") for item in scenarios}) != len(scenarios):
    fail("fixture scenario IDs must be unique")


def valid_uuid(value):
    try:
        uuid.UUID(value)
        return True
    except (ValueError, TypeError, AttributeError):
        return False

CANONICAL_RECORD_FIELDS = {"actor", "createdAt", "data", "envelope", "id", "readComplete"}
ISSUE_EVENT_ENVELOPE_FIELDS = {
    "clientId", "event", "issueId", "kind", "label", "relatedIds", "repository",
    "revision", "role", "schema", "supersedesId",
}
ASSIGNMENT_DATA_FIELDS = {
    "engineerName", "issueId", "ownerKind", "ownerPrincipalId", "runId",
}
FAILURE_DATA_FIELDS = {
    "affectedIds", "boundary", "branch", "issueId", "observedResult",
    "safeNextAction", "worktreePath",
}
HANDOFF_DATA_FIELDS = {
    "branch", "issueId", "nextAction", "ownerKind", "ownerPrincipalId",
    "pullRequestUrl", "recoveryEvidenceIds", "runId", "unresolvedItems", "worktreePath",
}
REASSIGNMENT_FIELDS = {
    "actor", "changedAt", "field", "fromOwner", "issueId", "readAt",
    "readComplete", "toOwner",
}


class IncompleteReceipt(ValueError):
    pass


def instant(value):
    if not isinstance(value, str) or not value:
        raise ValueError("missing native timestamp")
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as error:
        raise ValueError("invalid native timestamp") from error
    if parsed.tzinfo is None:
        raise ValueError("native timestamp lacks timezone")
    return parsed.astimezone(timezone.utc)


def sorted_unique_strings(value):
    return (
        isinstance(value, list)
        and value == sorted(value)
        and len(value) == len(set(value))
        and all(isinstance(item, str) and item for item in value)
    )


def exact_actor(value):
    if (
        not isinstance(value, dict)
        or set(value) != {"kind", "principalId"}
        or value.get("kind") not in {"app", "human"}
        or not isinstance(value.get("principalId"), str)
        or not value["principalId"]
    ):
        raise ValueError("invalid native actor")
    return value


def event_kind(record):
    envelope = record.get("envelope")
    if isinstance(envelope, dict):
        return envelope.get("event")
    return record.get("event")


def validate_canonical_event(record, issue):
    if not isinstance(record, dict) or set(record) != CANONICAL_RECORD_FIELDS:
        raise ValueError("canonical event record fields")
    if record.get("readComplete") is not True:
        raise IncompleteReceipt("canonical event read-back incomplete")
    if not valid_uuid(record.get("id")):
        raise ValueError("native comment identity")
    instant(record.get("createdAt"))
    actor = exact_actor(record.get("actor"))
    envelope = record.get("envelope")
    if not isinstance(envelope, dict) or set(envelope) != ISSUE_EVENT_ENVELOPE_FIELDS:
        raise ValueError("canonical issue-event envelope fields")
    if (
        envelope.get("schema") != 1
        or envelope.get("kind") != "issueEvent"
        or not valid_uuid(envelope.get("clientId"))
        or envelope.get("repository") != fixture["repository"]
        or envelope.get("label") != "woostack"
        or envelope.get("role") != issue.get("role")
        or envelope.get("issueId") != issue.get("id")
        or type(envelope.get("revision")) is not int
        or envelope["revision"] < 1
        or not sorted_unique_strings(envelope.get("relatedIds"))
        or (
            envelope.get("supersedesId") is not None
            and not valid_uuid(envelope["supersedesId"])
        )
    ):
        raise ValueError("canonical issue-event envelope values")
    data = record.get("data")
    event = envelope.get("event")
    if event == "assignmentAccepted":
        if not isinstance(data, dict) or set(data) != ASSIGNMENT_DATA_FIELDS:
            raise ValueError("assignmentAccepted data fields")
        if (
            data.get("issueId") != issue.get("id")
            or data.get("ownerKind") not in {"app", "human"}
            or any(
                not isinstance(data.get(field), str) or not data[field]
                for field in ("ownerPrincipalId", "engineerName", "runId")
            )
            or actor != {
                "kind": data.get("ownerKind"),
                "principalId": data.get("ownerPrincipalId"),
            }
        ):
            raise ValueError("assignmentAccepted data or native actor")
    elif event == "failure":
        if not isinstance(data, dict) or set(data) != FAILURE_DATA_FIELDS:
            raise ValueError("failure data fields")
        if (
            data.get("issueId") != issue.get("id")
            or any(
                not isinstance(data.get(field), str) or not data[field]
                for field in ("boundary", "observedResult", "safeNextAction")
            )
            or not sorted_unique_strings(data.get("affectedIds"))
            or any(
                data.get(field) is not None
                and (not isinstance(data[field], str) or not data[field])
                for field in ("branch", "worktreePath")
            )
        ):
            raise ValueError("failure data values")
    elif event == "handoff":
        if not isinstance(data, dict) or set(data) != HANDOFF_DATA_FIELDS:
            raise ValueError("handoff data fields")
        if (
            data.get("issueId") != issue.get("id")
            or data.get("ownerKind") not in {"app", "human"}
            or any(
                not isinstance(data.get(field), str) or not data[field]
                for field in ("ownerPrincipalId", "runId", "nextAction")
            )
            or any(
                data.get(field) is not None
                and (not isinstance(data[field], str) or not data[field])
                for field in ("branch", "worktreePath", "pullRequestUrl")
            )
            or not sorted_unique_strings(data.get("unresolvedItems"))
            or not sorted_unique_strings(data.get("recoveryEvidenceIds"))
            or actor != {
                "kind": data.get("ownerKind"),
                "principalId": data.get("ownerPrincipalId"),
            }
        ):
            raise ValueError("handoff data or native actor")
    else:
        raise ValueError("unsupported canonical fixture event")
    return record


def revision_families(events, issue, kind):
    selected = [record for record in events if event_kind(record) == kind]
    families = {}
    native_ids = set()
    for record in selected:
        validate_canonical_event(record, issue)
        if record["id"] in native_ids:
            raise ValueError("duplicate native comment identity")
        native_ids.add(record["id"])
        client_id = record["envelope"]["clientId"]
        families.setdefault(client_id, []).append(record)
    for records in families.values():
        records.sort(key=lambda item: item["envelope"]["revision"])
        if [item["envelope"]["revision"] for item in records] != list(
            range(1, len(records) + 1)
        ):
            raise ValueError("gapped or duplicate revisions")
        if len({item["envelope"]["event"] for item in records}) != 1:
            raise ValueError("event kind changed across revisions")
        for index, record in enumerate(records):
            expected_supersedes = None if index == 0 else records[index - 1]["id"]
            if record["envelope"]["supersedesId"] != expected_supersedes:
                raise ValueError("broken supersession chain")
            if index and instant(records[index - 1]["createdAt"]) >= instant(record["createdAt"]):
                raise ValueError("non-monotonic revision timestamp")
    return families


def current_revisions(events, issue, kind):
    return [records[-1] for records in revision_families(events, issue, kind).values()]


def current_revisions_at(events, issue, kind, at):
    current = []
    for records in revision_families(events, issue, kind).values():
        eligible = [record for record in records if instant(record["createdAt"]) <= at]
        if eligible:
            current.append(eligible[-1])
    return current


def native_revision_current_at(events, issue, native_id, at):
    matches = [
        record
        for record in events
        if isinstance(record.get("envelope"), dict) and record.get("id") == native_id
    ]
    if len(matches) != 1:
        raise ValueError("missing or duplicate related native revision")
    record = matches[0]
    kind = event_kind(record)
    families = revision_families(events, issue, kind)
    records = families[record["envelope"]["clientId"]]
    eligible = [candidate for candidate in records if instant(candidate["createdAt"]) <= at]
    if not eligible or eligible[-1]["id"] != native_id:
        raise ValueError("related revision was not current at producer timestamp")
    return record


def assignment_matches_owner(record, owner):
    data = record["data"]
    return (
        data["ownerKind"] == owner.get("kind")
        and data["ownerPrincipalId"] == owner.get("principalId")
        and data["engineerName"] == owner.get("engineerName")
        and data["runId"] == owner.get("runId")
        and record["actor"] == {
            "kind": owner.get("kind"),
            "principalId": owner.get("principalId"),
        }
    )


def validate_initial_assignment(events, issue, owner):
    assignments = current_revisions(events, issue, "assignmentAccepted")
    if len(assignments) != 1:
        raise ValueError("assignment current-family collision")
    assignment = assignments[0]
    if assignment["envelope"]["relatedIds"] != [] or not assignment_matches_owner(
        assignment, owner
    ):
        raise ValueError("initial assignment relation or owner mismatch")
    return assignment


def validate_handoff_chain(scenario, events, issue, owner):
    summary = scenario.get("handoff")
    if (
        not isinstance(summary, dict)
        or set(summary) != {"oldOwnerStopped", "reassignment"}
        or summary.get("oldOwnerStopped") is not True
    ):
        raise ValueError("handoff summary")
    handoffs = current_revisions(events, issue, "handoff")
    if len(handoffs) != 1:
        raise ValueError("handoff current-family collision")
    handoff = handoffs[0]
    handoff_at = instant(handoff["createdAt"])
    assignments_at_handoff = current_revisions_at(
        events, issue, "assignmentAccepted", handoff_at
    )
    if len(assignments_at_handoff) != 1:
        raise ValueError("outgoing assignment was not uniquely current")
    outgoing = assignments_at_handoff[0]
    outgoing_at = instant(outgoing["createdAt"])
    if (
        outgoing_at >= handoff_at
        or outgoing["envelope"]["relatedIds"] != []
        or native_revision_current_at(events, issue, outgoing["id"], handoff_at) is not outgoing
    ):
        raise ValueError("outgoing assignment relation, revision, or timestamp")
    handoff_data = handoff["data"]
    outgoing_data = outgoing["data"]
    if (
        handoff["actor"] != outgoing["actor"]
        or handoff_data["ownerKind"] != outgoing_data["ownerKind"]
        or handoff_data["ownerPrincipalId"] != outgoing_data["ownerPrincipalId"]
        or handoff_data["runId"] != outgoing_data["runId"]
    ):
        raise ValueError("handoff not authored by outgoing owner/run")
    recovery_ids = handoff_data["recoveryEvidenceIds"]
    expected_handoff_relations = sorted([outgoing["id"], *recovery_ids])
    if handoff["envelope"]["relatedIds"] != expected_handoff_relations:
        raise ValueError("handoff relation set")
    for recovery_id in recovery_ids:
        recovery = native_revision_current_at(events, issue, recovery_id, handoff_at)
        recovery_at = instant(recovery["createdAt"])
        if not outgoing_at < recovery_at < handoff_at:
            raise ValueError("recovery evidence timestamp")
        if event_kind(recovery) == "failure":
            if (
                recovery["actor"] != outgoing["actor"]
                or recovery["envelope"]["relatedIds"]
                != sorted([outgoing["id"], *recovery["data"]["affectedIds"]])
                or recovery["data"]["branch"] != handoff_data["branch"]
                or recovery["data"]["worktreePath"] != handoff_data["worktreePath"]
            ):
                raise ValueError("recovery failure relation or identity")

    reassignment = summary.get("reassignment")
    if not isinstance(reassignment, dict) or set(reassignment) != REASSIGNMENT_FIELDS:
        raise ValueError("reassignment receipt fields")
    exact_actor(reassignment.get("actor"))
    exact_actor(reassignment.get("fromOwner"))
    exact_actor(reassignment.get("toOwner"))
    project = scenario.get("project")
    authority = (project or {}).get("lead")
    expected_authority = (
        {"kind": authority.get("kind"), "principalId": authority.get("principalId")}
        if isinstance(authority, dict)
        else None
    )
    expected_field = "assignee" if owner.get("kind") == "human" else "delegate"
    changed_at = instant(reassignment.get("changedAt"))
    read_at = instant(reassignment.get("readAt"))
    if (
        reassignment.get("readComplete") is not True
        or reassignment.get("issueId") != issue.get("id")
        or reassignment.get("field") != expected_field
        or reassignment.get("fromOwner") != outgoing["actor"]
        or reassignment.get("toOwner")
        != {"kind": owner.get("kind"), "principalId": owner.get("principalId")}
        or expected_authority is None
        or reassignment.get("actor") != expected_authority
        or not handoff_at < changed_at <= read_at
    ):
        raise ValueError("deliberate owner change or read-back")

    assignments = current_revisions(events, issue, "assignmentAccepted")
    if len(assignments) != 2 or outgoing not in assignments:
        raise ValueError("assignment family collision around handoff")
    successors = [assignment for assignment in assignments if assignment is not outgoing]
    if len(successors) != 1:
        raise ValueError("missing or duplicate successor assignment")
    successor = successors[0]
    successor_at = instant(successor["createdAt"])
    if (
        successor_at <= read_at
        or successor["envelope"]["relatedIds"] != [handoff["id"]]
        or not assignment_matches_owner(successor, owner)
        or native_revision_current_at(events, issue, handoff["id"], successor_at) is not handoff
    ):
        raise ValueError("successor assignment relation, owner, revision, or timestamp")
    return successor


def classify(scenario):
    source = scenario.get("input", {})
    if (
        source.get("source") != "official-host-exposed-linear-mcp"
        or source.get("localPlan") is not None
        or source.get("localProgress") is not None
    ):
        return {
            "status": "blocked",
            "reason": "local-development-record-is-not-authority",
            "retryAllowed": False,
        }

    issue = scenario.get("issue")
    shape = source.get("shape")
    if not isinstance(issue, dict):
        return {
            "status": "blocked",
            "reason": "missing-exact-linear-issue",
            "retryAllowed": False,
        }
    if (
        issue.get("stateReadBack") != "complete"
        or issue.get("contractReadBack") != "complete"
    ):
        return {
            "status": "blocked",
            "reason": "incomplete-issue-read-back",
            "retryAllowed": False,
        }
    if shape == "projectIssueDag":
        project = scenario.get("project")
        if (
            not isinstance(project, dict)
            or project.get("role") != "feature"
            or issue.get("role") != "increment"
            or issue.get("projectId") != project.get("id")
            or project.get("lead", {}).get("readBack") != "complete"
            or project.get("phaseReadBack") != "complete"
        ):
            return {
                "status": "blocked",
                "reason": "invalid-project-issue-dag",
                "retryAllowed": False,
            }
    elif shape == "standaloneIssue":
        if (
            scenario.get("project") is not None
            or issue.get("role") != "work-item"
            or issue.get("projectId") is not None
        ):
            return {
                "status": "blocked",
                "reason": "invalid-standalone-issue",
                "retryAllowed": False,
            }
    else:
        return {
            "status": "blocked",
            "reason": "unsupported-input-shape",
            "retryAllowed": False,
        }

    events = scenario.get("events", [])
    if not isinstance(events, list):
        return {
            "status": "blocked",
            "reason": "invalid-event-envelope",
            "retryAllowed": False,
        }
    canonical_native_ids = []
    try:
        for event in events:
            kind = event_kind(event)
            if isinstance(event.get("envelope"), dict):
                validate_canonical_event(event, issue)
                canonical_native_ids.append(event["id"])
                continue
            if kind in {"assignmentAccepted", "failure", "handoff"}:
                raise ValueError("flattened canonical event")
            if event.get("readBack") != "complete":
                raise IncompleteReceipt("legacy fixture event read-back incomplete")
            required = {
                "schema", "kind", "clientId", "repository", "label", "role", "event",
                "revision", "issueId", "relatedIds", "supersedesId", "readBack",
            }
            if (
                not required.issubset(event)
                or event["schema"] != 1
                or event["kind"] != "issueEvent"
                or not valid_uuid(event["clientId"])
                or event["repository"] != fixture["repository"]
                or event["label"] != "woostack"
                or event["role"] != issue["role"]
                or event["issueId"] != issue["id"]
                or type(event["revision"]) is not int
                or event["revision"] < 1
                or not sorted_unique_strings(event["relatedIds"])
            ):
                raise ValueError("legacy event envelope")
        if len(canonical_native_ids) != len(set(canonical_native_ids)):
            raise ValueError("duplicate native comment identity")
        for kind in {"assignmentAccepted", "failure", "handoff"}:
            revision_families(events, issue, kind)
    except IncompleteReceipt:
        return {
            "status": "blocked",
            "reason": "unknown-event-read-back",
            "retryAllowed": False,
        }
    except ValueError:
        return {
            "status": "blocked",
            "reason": "invalid-event-envelope",
            "retryAllowed": False,
        }

    terminal = scenario.get("terminal")
    if scenario.get("requestedBoundary") == "done":
        pr = (terminal or {}).get("canonicalPr", {})
        acceptance = (terminal or {}).get("acceptance", {})
        if (
            pr.get("relationReadBack") != "complete"
            or pr.get("mergeReadBack") != "complete"
            or pr.get("merged") is not True
            or acceptance.get("event") != "acceptance"
            or not acceptance.get("authority")
            or acceptance.get("readBack") != "complete"
        ):
            return {
                "status": "blocked",
                "reason": "done-requires-responsible-acceptance-and-verified-merge",
                "retryAllowed": False,
            }
        if shape == "projectIssueDag" and terminal.get("allIssuesDone") is not True:
            return {
                "status": "blocked",
                "reason": "project-done-requires-all-issues-done",
                "retryAllowed": False,
            }
        return {
            "status": "terminal-eligible",
            "reason": "acceptance-and-merge-verified",
            "retryAllowed": False,
        }

    owner = issue.get("owner", {})
    expected_field = (
        "assignee"
        if owner.get("kind") == "human"
        else "delegate"
        if owner.get("kind") == "app"
        else None
    )
    registry = scenario.get("registry")
    if (
        expected_field is None
        or owner.get("field") != expected_field
        or owner.get("readBack") != "complete"
        or owner.get("principalId") != owner.get("expectedPrincipalId")
        or not isinstance(registry, dict)
        or registry.get("collision") is not False
        or registry.get("readBack") != "complete"
        or registry.get("key") != issue.get("id")
        or registry.get("issueId") != issue.get("id")
        or registry.get("projectId") != issue.get("projectId")
        or registry.get("ownerPrincipalId") != owner.get("principalId")
        or registry.get("runId") != owner.get("runId")
    ):
        return {
            "status": "blocked",
            "reason": "ownership-or-registry-collision",
            "retryAllowed": False,
        }

    try:
        if scenario.get("handoff") is None:
            validate_initial_assignment(events, issue, owner)
        else:
            validate_handoff_chain(scenario, events, issue, owner)
    except (IncompleteReceipt, ValueError):
        return {
            "status": "blocked",
            "reason": (
                "incomplete-handoff"
                if scenario.get("handoff") is not None
                else "missing-assignment-accepted-receipt"
            ),
            "retryAllowed": False,
        }

    ancestry_record = scenario.get("ancestry", {})
    if ancestry_record.get("readBack") != "complete":
        return {
            "status": "blocked",
            "reason": "unknown-ancestry",
            "retryAllowed": False,
        }
    ancestry_kind = ancestry_record.get("kind")
    if ancestry_kind == "independentRoot":
        project = scenario.get("project", {})
        frozen = project.get("frozenBase", {})
        if (
            ancestry_record.get("startCommitSha")
            != ancestry_record.get("frozenCommitSha")
            or ancestry_record.get("startCommitSha") != frozen.get("commitSha")
            or ancestry_record.get("graphiteParent")
            != ancestry_record.get("frozenBranch")
            or ancestry_record.get("graphiteParent") != frozen.get("branch")
        ):
            return {
                "status": "blocked",
                "reason": "unsafe-root-ancestry",
                "retryAllowed": False,
            }
    elif ancestry_kind == "standalone":
        if (
            ancestry_record.get("startCommitSha")
            != ancestry_record.get("integrationCommitSha")
            or ancestry_record.get("graphiteParent")
            != ancestry_record.get("integrationBranch")
        ):
            return {
                "status": "blocked",
                "reason": "unsafe-standalone-ancestry",
                "retryAllowed": False,
            }
    elif ancestry_kind == "dependencyChild":
        parent = ancestry_record.get("parent", {})
        parent_state = parent.get("state")
        parent_state_ready = (
            parent_state == "inReview"
            or (
                parent_state == "done"
                and parent.get("mergeEvidence") == "complete"
                and parent.get("merged") is True
            )
        )
        if (
            not parent_state_ready
            or parent.get("implementationEvidence") != "complete"
            or parent.get("canonicalPr") != "complete"
            or parent.get("linearPrRelation") != "complete"
            or ancestry_record.get("startCommitSha") != parent.get("headCommitSha")
            or ancestry_record.get("graphiteParent") != parent.get("branch")
        ):
            return {
                "status": "blocked",
                "reason": "unsafe-parent-ancestry",
                "retryAllowed": False,
            }
        for dependency in ancestry_record.get("nonParentDependencies", []):
            if (
                dependency.get("state") != "done"
                or dependency.get("acceptance") != "complete"
                or dependency.get("mergeEvidence") != "complete"
                or dependency.get("merged") is not True
                or dependency.get("permittedAncestry") != "complete"
            ):
                return {
                    "status": "blocked",
                    "reason": "non-parent-dependency-is-not-merged",
                    "retryAllowed": False,
                }
    else:
        return {
            "status": "blocked",
            "reason": "unknown-ancestry",
            "retryAllowed": False,
        }

    if issue.get("state") == "blocked":
        blocked = [event for event in events if event_kind(event) == "blocked"]
        unblocked = [event for event in events if event_kind(event) == "unblocked"]
        restoration = scenario.get("blockerRestoration", {})
        if (
            len(blocked) != 1
            or len(unblocked) != 1
            or blocked[0].get("nativeCommentId")
            not in unblocked[0].get("relatedIds", [])
            or restoration.get("openBlockerNativeId")
            != blocked[0].get("nativeCommentId")
            or restoration.get("remainingOpenBlockers") != 0
            or restoration.get("priorState") != blocked[0].get("previousState")
            or restoration.get("restoredState") != restoration.get("priorState")
            or restoration.get("restoredStateReadBack") != "complete"
        ):
            return {
                "status": "blocked",
                "reason": "invalid-blocker-restoration",
                "retryAllowed": False,
            }
        return {
            "status": "proceed",
            "reason": "verified-unblock-restores-executing",
            "retryAllowed": False,
        }

    if scenario.get("handoff") is not None:
        return {
            "status": "proceed",
            "reason": "verified-handoff-successor",
            "retryAllowed": False,
        }

    if ancestry_kind == "independentRoot":
        return {
            "status": "proceed",
            "reason": "verified-independent-root",
            "retryAllowed": False,
        }
    return {
        "status": "proceed",
        "reason": "verified-standalone-resume",
        "retryAllowed": False,
    }


by_scenario_id = {scenario["id"]: scenario for scenario in scenarios}


def require_blocked_variant(name, scenario):
    result = classify(scenario)
    if result.get("status") != "blocked":
        fail(f"{name} canonical receipt variant was admitted: {result!r}")


root_receipt = by_scenario_id["verified-independent-root"]
malformed_assignment = deepcopy(root_receipt)
malformed_assignment["events"][0]["data"]["unexpected"] = "flattened-compatible"
require_blocked_variant("malformed assignment data", malformed_assignment)

partial_assignment = deepcopy(root_receipt)
partial_assignment["events"][0]["readComplete"] = False
require_blocked_variant("partial assignment read-back", partial_assignment)

foreign_assignment = deepcopy(root_receipt)
foreign_assignment["events"][0]["actor"]["principalId"] = "foreign-principal"
require_blocked_variant("foreign assignment author", foreign_assignment)

done_parent_without_merge = deepcopy(
    by_scenario_id["rejects-unmerged-non-parent-dependency"]
)
done_parent_without_merge["ancestry"]["nonParentDependencies"] = []
done_parent_without_merge["ancestry"]["parent"]["state"] = "done"
done_parent_without_merge["ancestry"]["parent"]["mergeEvidence"] = "absent"
done_parent_without_merge["ancestry"]["parent"]["merged"] = False
require_blocked_variant("done parent without merge proof", done_parent_without_merge)

accepted_but_unrepresented = deepcopy(
    by_scenario_id["rejects-unmerged-non-parent-dependency"]
)
non_parent = accepted_but_unrepresented["ancestry"]["nonParentDependencies"][0]
non_parent["state"] = "done"
non_parent["acceptance"] = "complete"
non_parent["mergeEvidence"] = "complete"
non_parent["merged"] = True
non_parent["permittedAncestry"] = "absent"
require_blocked_variant(
    "merged non-parent missing permitted ancestry",
    accepted_but_unrepresented,
)

handoff_receipt = by_scenario_id["accepts-verified-handoff-successor"]
reordered_handoff = deepcopy(handoff_receipt)
reordered_handoff["events"].reverse()
if classify(reordered_handoff) != handoff_receipt["expected"]:
    fail("canonical handoff selection depends on array order")

missing_outgoing = deepcopy(handoff_receipt)
missing_outgoing["events"] = [
    event
    for event in missing_outgoing["events"]
    if event.get("id") != "40000000-0000-4000-9000-000000000026"
]
require_blocked_variant("missing outgoing assignment", missing_outgoing)

partial_reassignment = deepcopy(handoff_receipt)
partial_reassignment["handoff"]["reassignment"]["readComplete"] = False
require_blocked_variant("partial reassignment read-back", partial_reassignment)

foreign_handoff = deepcopy(handoff_receipt)
handoff_event = next(
    event for event in foreign_handoff["events"] if event_kind(event) == "handoff"
)
handoff_event["actor"]["principalId"] = "foreign-principal"
require_blocked_variant("foreign handoff author", foreign_handoff)

extra_handoff_relation = deepcopy(handoff_receipt)
handoff_event = next(
    event for event in extra_handoff_relation["events"] if event_kind(event) == "handoff"
)
handoff_event["envelope"]["relatedIds"].append(
    "49999999-9999-4999-8999-999999999999"
)
handoff_event["envelope"]["relatedIds"].sort()
require_blocked_variant("extra handoff relation", extra_handoff_relation)

partial_successor_relation = deepcopy(handoff_receipt)
successor = next(
    event
    for event in partial_successor_relation["events"]
    if event_kind(event) == "assignmentAccepted"
    and event["data"]["ownerPrincipalId"] == "user-new-26"
)
successor["envelope"]["relatedIds"] = []
require_blocked_variant("partial successor relation", partial_successor_relation)

duplicate_successor = deepcopy(handoff_receipt)
successor = next(
    event
    for event in duplicate_successor["events"]
    if event_kind(event) == "assignmentAccepted"
    and event["data"]["ownerPrincipalId"] == "user-new-26"
)
competing = deepcopy(successor)
competing["id"] = "43333333-3333-4333-9333-333333333326"
competing["createdAt"] = "2026-07-27T10:11:00Z"
competing["envelope"]["clientId"] = "43333333-3333-4333-8333-333333333326"
duplicate_successor["events"].insert(0, competing)
require_blocked_variant("duplicate successor assignment", duplicate_successor)

stale_successor = deepcopy(handoff_receipt)
successor = next(
    event
    for event in stale_successor["events"]
    if event_kind(event) == "assignmentAccepted"
    and event["data"]["ownerPrincipalId"] == "user-new-26"
)
corrected = deepcopy(successor)
corrected["id"] = "44444444-4444-4444-9444-444444444426"
corrected["createdAt"] = "2026-07-27T10:20:00Z"
corrected["data"]["runId"] = "run-foreign-026"
corrected["envelope"]["revision"] = 2
corrected["envelope"]["supersedesId"] = successor["id"]
stale_successor["events"].insert(0, corrected)
require_blocked_variant("stale superseded successor", stale_successor)

premature_successor = deepcopy(handoff_receipt)
successor = next(
    event
    for event in premature_successor["events"]
    if event_kind(event) == "assignmentAccepted"
    and event["data"]["ownerPrincipalId"] == "user-new-26"
)
successor["createdAt"] = "2026-07-27T10:05:30Z"
require_blocked_variant("successor before reassignment read-back", premature_successor)

observed = {}
for scenario in scenarios:
    result = classify(scenario)
    observed[scenario["id"]] = result
    if result != scenario.get("expected"):
        fail(f"fixture scenario {scenario['id']!r} classified {result!r}, expected {scenario.get('expected')!r}")

required_outcomes = {
    "verified-independent-root": ("proceed", "verified-independent-root"),
    "verified-standalone-resume": ("proceed", "verified-standalone-resume"),
    "rejects-local-plan-progress-authority": ("blocked", "local-development-record-is-not-authority"),
    "rejects-owner-and-registry-collision": ("blocked", "ownership-or-registry-collision"),
    "rejects-unmerged-non-parent-dependency": ("blocked", "non-parent-dependency-is-not-merged"),
    "rejects-unknown-verification-comment-outcome": ("blocked", "unknown-event-read-back"),
    "restores-executing-after-verified-unblock": ("proceed", "verified-unblock-restores-executing"),
    "accepts-verified-handoff-successor": ("proceed", "verified-handoff-successor"),
    "rejects-premature-issue-done": ("blocked", "done-requires-responsible-acceptance-and-verified-merge"),
    "rejects-premature-project-done": ("blocked", "project-done-requires-all-issues-done"),
}
for scenario_id, (status, reason) in required_outcomes.items():
    if observed.get(scenario_id) != {"status": status, "reason": reason, "retryAllowed": False}:
        fail(f"required deterministic outcome missing for {scenario_id}")

print("test-linear-execute-contract: OK")
PY
