#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1])
paths = {
    "execute": root / "skills/woostack-execute/SKILL.md",
    "controller": root / "skills/woostack-execute/references/controller.md",
    "inline": root / "skills/woostack-execute/references/inline-driver.md",
    "subagent": root / "skills/woostack-execute/references/subagent-driver.md",
    "overnight": root / "skills/woostack-execute-overnight/SKILL.md",
    "worktrees": root / "skills/woostack-init/references/worktrees.md",
    "tdd": root / "skills/woostack-tdd/SKILL.md",
    "linear_adapter": root / "skills/woostack-init/scripts/artifacts/linear.sh",
}


def fail(message):
    raise SystemExit(f"test-linear-execute-contract: {message}")


def must(text, token, scope):
    if token not in text:
        fail(f"{scope} missing {token!r}")


def must_not(text, token, scope):
    if token in text:
        fail(f"{scope} unexpectedly contains {token!r}")


def ordered(text, tokens, scope):
    position = -1
    for token in tokens:
        position = text.find(token, position + 1)
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
texts = {name: path.read_text(encoding="utf-8") for name, path in paths.items()}

execute = texts["execute"]
controller = texts["controller"]
overnight = texts["overnight"]
linear_adapter = texts["linear_adapter"]
resolution = section(controller, "## Resolve authority and input", "## Standalone work-item path")
standalone = section(controller, "## Standalone work-item path", "## Resolve the next ready issue")
next_issue = section(controller, "## Resolve the next ready issue", "## Selection precedence")
linear_cadence = section(controller, "## Linear issue cadence", "## Failure and lifecycle truth")
failure_truth = section(controller, "## Failure and lifecycle truth", "Build execution never transitions")
resume = section(controller, "## Retry and resume", "## Linear issue cadence")
selection = section(controller, "## Selection precedence", "## Retry and resume")
linear_input = section(overnight, "### Linear overnight input and report", "## Pre-flight")
linear_tracks = section(overnight, "### Linear dependency tracks", "## Post-implementation review sweep")
terminal = section(overnight, "## Terminal state", "## Gate boundary")

# Entry classifies exact Linear authority before retaining the Markdown compatibility path.
for token in (
    "resolve-backend.sh",
    "## Markdown backend (unchanged)",
    "## Linear backend",
    "project UUID, URL, or unambiguous managed reference",
    "references/controller.md",
):
    must(execute, token, "execute entry")
for token in (
    "named Markdown plan",
    "checkboxes in place",
    "terminal `status: done`",
):
    must(execute, token, "Markdown compatibility")

for token in (
    "exact Linear UUID/URL",
    "role-`work-item` issue",
    "without invoking `resolve-backend.sh`",
    "managed role-`feature` project",
):
    must(resolution, token, "exact execution authority")
for token in (
    "stable ID and URL",
    "role `work-item`",
    "no project membership",
    "semantic state `executing`",
    "type-aware owner",
    "woostack-commit --issue <exact issue UUID-or-URL>",
    "do not run the project closure cadence",
):
    must(standalone, token, "standalone execution authority")
# The controller owns project state/evidence sequencing and exact issue identity.
ordered(linear_cadence, (
    "linear.sh spec-read",
    "linear.sh spec-write --issue-state-map",
    "`executionApproved → executing`",
    "feature-read",
    "linear.sh feature-transition ... --target executing",
    "project `ready → executing`",
    "spec `executing` / project `ready`",
    "linear.sh issue-transition ... --target executing",
    "`planned → executing`",
    "implementation branch or worktree",
    "Implement and review",
    "woostack-commit",
    "exact issue UUID/URL",
    "issue identifier is never commit identity",
    "gt submit",
    "advances the issue to `inReview`",
    "After every managed issue has verified `inReview`",
    "linear.sh spec-read",
    "linear.sh spec-write --issue-state-map",
    "managed spec `executing → inReview`",
    "feature-read",
    "linear.sh feature-transition ... --target inReview",
    "project `executing → inReview`",
    "spec `inReview` / project `executing`",
    "invoke neither",
    "leave both `executing`",
), "Linear supervised cadence")
ordered(resolution, (
    "resolve-backend.sh",
    "Markdown",
    "linear.sh preflight",
    "LINEAR_CONTEXT",
    "project UUID/URL",
    "resolve the repository-owned project through `feature-read`",
    "normalized model's project ID",
    "project `ready` / spec `ready`",
    "project `ready` / spec `executionApproved`",
    "project `executing` / spec `executing`",
    "project `inReview` / spec `inReview`",
    "project `ready` / spec `executing`",
    "project `executing` / spec `inReview`",
    "linear.sh plan-read",
    "null branch/PR evidence",
    "linear.sh spec-read",
    "linear.sh spec-write",
    '--issue-state-map "$LINEAR_ISSUE_STATES"',
    "`designState: ready`",
    "`designState: executionApproved`",
    "linear.sh feature-read` again",
    "unchanged frozen base",
    "still-null branch/PR evidence",
), "Linear execution approval and resume admission")
ordered(next_issue, (
    "Before selecting an issue",
    "project `ready` / spec `executing`",
    "remaining idempotent",
    "When every managed issue already has verified `inReview`",
    "run cadence step 5 before selection",
    "project `executing` / spec `inReview`",
    "build execution complete",
    "already at `inReview`",
    "without selecting an issue",
), "pre-selection project closure")
ordered(controller, (
    "linear.sh preflight",
    "linear.sh plan-read",
    "explicit unique ordinal",
    "native `blocked by` relations",
    "declared Git parent",
), "Linear input readiness")
ordered(selection, (
    "existing `executing` issue",
    "eligible `blocked` retry",
    "new `planned` issue",
), "Linear selection precedence")
for token in (
    "Exactly one",
    "fail closed",
):
    must(selection, token, "Linear selection ambiguity")
for token in (
    "executable Linear progress representation",
    "preserves Human-authored issue Markdown",
    "outside the managed metadata block",
    "`baseCommitSha`",
    "declared parent issue branch",
    "merged or reachable",
    "Build execution never transitions an issue or project to `done`",
    "receipt",
):
    must(controller, token, "Linear controller")
for token in (
    "Exact intended `inReview` state and exact branch/PR evidence is success",
    "response was lost",
    "observed state remains `executing` with no attribution evidence",
    "Only a later explicit resume",
    "partial or mismatched",
    "manual reconciliation",
):
    must(linear_cadence, token, "attribution unknown outcome")
must_not(controller, "Never transition a failed issue to `inReview`", "unknown attribution truth")
for token in (
    "Before attribution is attempted",
    "implementation/test/review/commit/submit failures",
    "issue `executing`",
    "move it to `blocked` only through a separate verified receipt",
):
    must(failure_truth, token, "pre-attribution failure truth")
must(" ".join(failure_truth.split()), "None of those pre-attribution failures may advance the issue to `inReview`", "pre-attribution failure truth")
for token in (
    "discovery-before-create",
    "`executing → executing`",
    "`blocked → executing`",
    "`feature/<issue-identifier-lowercase>`",
    "`$WOOSTACK_ROOT/.woostack/worktrees/feature-<issue-identifier-lowercase>`",
    "reuse",
    "never create a duplicate branch, worktree, commit, or PR",
):
    must(resume, token, "Linear retry/resume")
for token in (
    "parent issue is `inReview`",
    "attributed branch and active PR",
    "ancestor of the declared parent branch",
    "`done`",
):
    must(controller, token, "Linear dependency readiness")
for token in (
    "issue-transition",
    "native state",
    "managed `branch`",
    "`pullRequest` evidence fields",
    "does not write per-step checkboxes",
):
    must(controller, token, "supported progress writes")
for contradiction in (
    "Process the first `ready` issue",
    "Drivers may update only",
):
    must_not(controller, contradiction, "Linear controller")
# Pin controller prose to operations the shipped adapter actually implements.
issue_transition = section(linear_adapter, "command_issue_transition() {", "command_status_reconcile() {")
for token in (
    "planned:executing",
    "executing:blocked",
    "blocked:executing",
    "executing:inReview",
    '[[ \"$target\" != \"done\" ]]',
    "{stateId:$stateId}",
    "{description:$description}",
):
    must(issue_transition, token, "adapter issue transition")
for forbidden in ("api.linear.app/graphql", "query {", "mutation {"):
    must_not(controller, forbidden, "Linear controller")

# Both drivers consume the same increment-level ordered task-list shape without acquiring
# lifecycle ownership.
for name in ("inline", "subagent"):
    for token in (
        "Markdown increment's ordered task list",
        "normalized ordered task list",
        "controller.md",
        "does not transition Linear state",
    ):
        must(texts[name], token, f"{name} driver")
must(controller, "normalize the selected issue description's implementation steps", "driver task normalization")
must(controller, "same ordered task-list shape", "driver task normalization")
must(texts["inline"], "writes no issue content", "inline driver")
must(texts["subagent"], "write no issue content", "subagent driver")
must(texts["subagent"], "never dispatched in parallel", "subagent sequential policy")

# Overnight derives deterministic DAG tracks and isolates failure to the active track.
ordered(overnight, (
    "native `blocked by` relations",
    "explicit unique ordinal",
    "deterministic ready root",
    "one ready independent track at a time",
    "complete or block that track",
    "next deterministic ready track",
), "Linear overnight selection")
for token in (
    "maximal linear",
    "declared Git-parent edges",
    "At a fork",
    "every ready child",
    "separate non-root track",
    "At a join",
    "merged-or-reachable rule",
    "declared parent branch",
):
    must(linear_tracks, token, "Linear fork and join partition")
for token in (
    "only the affected track",
    "issue to `blocked` only with a verified receipt",
    "success despite a lost response",
    "unchanged `executing`",
    "separate verified `executing → blocked`",
    "halt the overnight run",
    "partial/mismatched evidence",
    "requires manual",
    "reconciliation.",
    "morning report",
):
    must(linear_tracks, token, "Linear overnight failure isolation")
for token in (
    "project UUID",
    "<run-date>-linear-<project-uuid>.md",
    "frozen `baseBranch`",
    "declared Graphite parent",
    "does not author Markdown checkboxes",
    "frontmatter",
):
    must(linear_input, token, "Linear overnight input/report")
for contradiction in (
    "<plan-path>",
    "<plan-slug>",
    "spec+plan PR",
    "`status: done`",
):
    must_not(linear_input, contradiction, "Linear overnight input/report")
must(linear_tracks, "root issue's declared Graphite parent", "Linear sweep base")
must_not(linear_tracks, "spec+plan PR", "Linear track policy")
for token in (
    "Markdown completion",
    "Linear completion",
    "never writes `done`",
):
    must(terminal, token, "backend terminal state")

# Worktree and TDD routing differ only where the backend genuinely differs.
for token in (
    "Spec/plan authoring worktrees and docs-only base branches are Markdown-only",
    "frozen root commit SHA",
    "declared parent issue branch",
):
    must(texts["worktrees"], token, "worktree backend contract")
for token in (
    "exact project UUID or URL **and** exact issue UUID or URL",
    "require both exact project and issue inputs",
    "official host-exposed Linear MCP",
    "independently read and verify project and issue identity",
    "repository attribution",
    "workspace/team",
    "`woostack` ownership metadata",
    "project membership",
    "dependencies, work owner",
    "complete issue contract",
    "An issue-only input",
    "blocks before local writes",
):
    must(texts["tdd"], token, "TDD Linear target")
for token in (
    "immutable execution input",
    "Write only tests in the local code worktree",
    "Never mutate the project",
    "report a planning defect for explicit reconciliation",
):
    must(texts["tdd"], token, "TDD read-only Linear issue")
must_not(texts["tdd"], "linear.sh plan-reconcile", "TDD execution-time mutation")

# Execution stays sequential and never absorbs terminal reconciliation or source-control authority.
combined = "\n".join(texts.values())
for token in (
    "Linear execution remains sequential",
    "never merges",
):
    must(combined, token, "global execution invariants")

print("test-linear-execute-contract: OK")
PY
