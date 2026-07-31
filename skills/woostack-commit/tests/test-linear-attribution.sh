#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
commit_dir = root / "skills/woostack-commit"
skill = (commit_dir / "SKILL.md").read_text(encoding="utf-8")
linear = (commit_dir / "references/linear-attribution.md").read_text(encoding="utf-8")
pr_body = (commit_dir / "references/pr-body.md").read_text(encoding="utf-8")
corpus = "\n".join((skill, linear, pr_body))


def fail(message):
    raise SystemExit(f"test-linear-attribution: {message}")


def compact(value):
    return re.sub(r"\s+", " ", value).strip()


def must(text, token, scope):
    if compact(token) not in compact(text):
        fail(f"{scope} missing {token!r}")


def must_not(text, token, scope):
    if compact(token) in compact(text):
        fail(f"{scope} unexpectedly contains {token!r}")


def ordered(text, tokens, scope):
    haystack = compact(text)
    position = -1
    for token in tokens:
        position = haystack.find(compact(token), position + 1)
        if position < 0:
            fail(f"{scope} missing or misorders {token!r}")


# Clean cutover: the commit package has no Markdown attribution reader or test.
for obsolete in (
    commit_dir / "references/markdown-attribution.md",
    commit_dir / "tests/test-markdown-attribution.sh",
):
    if obsolete.exists():
        fail(f"obsolete path still exists: {obsolete.relative_to(root)}")

# Official host MCP and exact caller identities are the only Linear authority.
for token in (
    "Official host-exposed Linear MCP is the only development-record interface",
    "Linear MCP development authority",
    "/woostack-commit --issue <Linear issue UUID|exact URL>",
    "[--project <Linear project UUID|exact URL>]",
    "`--issue` is always required",
    "issue identifier such as `TEAM-123`, a title, branch name, or recent issue is never sufficient identity",
    "Discover official MCP operations by capability, not by hard-coded tool name",
    "GitHub GraphQL is permitted only for GitHub operations",
):
    must(corpus, token, "official MCP authority")

for forbidden in (
    "resolve-backend.sh",
    "linear.sh feature-read",
    "linear.sh issue-transition",
    "LINEAR_API_KEY",
    "markdown-attribution.md",
    "When the resolved backend is Markdown",
    "When the resolved backend is Linear",
    "verified `change/*` artifact-neutral",
):
    must_not(corpus, forbidden, "removed backend/adapter path")

# Role shape is exact: every PR gets one issue, only increments get one project.
for token in (
    "role `work-item`: one exact managed issue, no project argument, no native project membership",
    "role `increment`: one exact managed issue, one exact managed role-`feature` project",
    "A role-`work-item` has no project line",
    "Do not fabricate a project",
    "exactly one raw `Linear-Issue: <TEAM-NUMBER>` line",
    "exactly one raw `Linear-Project: <verified-project-uuid>` line",
    "immediately before the issue line",
    "There is no `Spec:` mention anywhere",
):
    must(corpus, token, "role-derived trailer contract")

for text, scope in ((pr_body, "PR body"), (linear, "Linear reference")):
    must(text, "Linear-Project: <verified-project-uuid>", scope)
    must(text, "Linear-Issue: <TEAM-NUMBER>", scope)

# Identity, ownership, repository, relations, ancestry, and complete reads gate every mutation.
for token in (
    "wrong `kind`/`role`",
    "foreign repository",
    "owner drift",
    "relation mismatch",
    "bad ancestry",
    "partial",
    "unknown",
    "blocks before commit",
    "type-aware resolved work owner",
    "native project membership",
    "declared parent issue branch",
    "Every additional dependency must already be merged or Git-reachable",
    "current HEAD to be descended from the retained base commit",
):
    must(corpus, token, "pre-mutation gate")

ordered(
    skill,
    (
        "### 0. Bind the caller-supplied Linear work",
        "### 1. Inspect state",
        "### 2. Enforce issue-owned branch shape before committing",
        "### 3. Run the configured pre-commit command",
        "### 4. Stage only session-relevant changes",
        "### 4.5 Verify Linear identity and proposed attribution",
        "### 5. Commit",
        "### 5.5 Record finalized implementation evidence",
        "### 6. Push or submit",
        "### 7. Resolve and attribute the PR",
        "### 8. Report",
    ),
    "root operation order",
)

# Fresh admission selects the initial-creation or existing-PR-update shape and never duplicates an
# exact commit, event, PR, relation, field edit, or state transition.
for token in (
    "Classify resume state before side effects",
    "resume at the first pending boundary",
    "never rerun `gt modify`",
    "skip UUID allocation and append",
    "Initial PR creation",
    "Existing canonical PR update",
    "revision 1 has no predecessor and no historical canonical PR relation",
    "ordinary-later or consumed-restack revision B",
    "Existing updates never mutate their stable relation",
    "skip `gh pr edit`",
    "performs neither relation nor state mutation",
    "stages 3–5 perform zero hook, PASS-helper, staging, or `gt modify` operations",
    "skip this entire step without reading the hook or invoking `change-receipt.sh`",
    "run no `git add` or `git add -p`",
):
    must(corpus, token, "resume admission")

ordered(
    linear,
    (
        "finalized local head B → implementationEvidence B",
        "initial: proven-absent submission/remote/all-state PR set",
        "later: exact sole canonical PR at A + same stable Linear relation",
        "exact PR fields at B + same stable relation",
        "inReview state",
    ),
    "resume boundary order",
)

for token in (
    "resume-admission-selected diff",
    "staged diff only on the commit-absent path",
    "verified committed base-to-head diff for that exact base/head pair",
    "Ignore every current staged, unstaged, and untracked path/content",
    "A missing in-memory draft is not a blocker",
    "Not rerun on resume; prior pre_commit result unavailable",
    "selected input identity",
):
    must(corpus, token, "resume PR drafting input")

# The finalized commit is evidenced and read back before Graphite can push or submit.
ordered(
    skill,
    (
        "commit_sha=\"$(git rev-parse HEAD)\"",
        "### 5.5 Record finalized implementation evidence",
        "commit-scoped base SHA, head SHA",
        "preallocate one stable event UUID",
        "independently read that exact comment",
        "### 6. Push or submit",
        "gt submit",
    ),
    "implementation evidence boundary",
)
for token in (
    "used only for caller PASS freshness before commit",
    "never copied into remote implementation evidence",
    "baseCommitSha",
    "headCommitSha",
    "committedDiffHash",
    "byte-safe committed base-to-head diff",
    "excludes branch-local staged, unstaged, and untracked paths, contents, and hashes",
    '"event":"implementationEvidence"',
    '"kind":"issueEvent"',
    "search by the same stable event UUID",
    "Do not append a replacement or retry in the same invocation",
    "stop before push/submission",
):
    must(corpus, token, "typed implementation evidence")

for token in (
    "current `verification` and `precommitReview` are already complete before this finalized commit",
    "Validate `precommitReview` data containing exactly `issueId`, `actor`",
    "ordered spec then quality receipts and outer verdict are PASS",
    "must contain no PR/GitHub review receipt",
    "reverse-binds both pre-commit events through `implementationEvidence`",
    "Construct the sorted canonical `relatedIds` from exactly the current `assignmentAccepted`",
    "passing `verification` native comment ID, passing `precommitReview` native comment ID",
    "Never add post-PR `reviewResult`",
    "A normal first or later commit has no `restackAuthorized` relation",
    "add exactly its independently verified `restackAuthorized` native comment ID",
    "authenticated controller, native comment author, current type-aware owner",
    "native author/authenticated controller must instead equal",
    "affectedRelationIds` is exactly empty",
    "cross-issue relation rewrite requires an exact nonempty set",
    "expired unconsumed authorization/decision is inactive history",
    "never the latest event by kind",
    "`authorizationTime < completionTime <= expiresAt`",
):
    must(linear, token, "canonical implementation evidence relation, actor, and revision")


# Initial creation stays all-state absence-only; eligible later revisions preserve the canonical
# PR identity and the stable native relation while GitHub advances A→B.
for token in (
    "every open, closed, and merged PR candidate",
    "exactly one canonical PR plus one stable Linear PR relation",
    "Resolve the prior implementation and every event it relates to as the exact native revisions current at the applicable authoritative timestamp",
    "the relation has no head field to refresh",
    "push head B and update that same PR",
    "fetch by the retained PR number",
    "preserves the exact number/URL/repository/head branch/base proven at A",
    "Perform no relation mutation",
    "native relation ID are immutable through the update",
    "A pre-existing PR cannot promote an initial revision into the later-update path",
    "enumerate the complete native dependency descendant set",
    "current unexpired unconsumed owner-authored `restackAuthorized`",
):
    must(linear, token, "existing canonical PR update contract")

# Graphite and GitHub stay source-control authorities, with independent canonical read-back.
for token in (
    "gt modify -m \"<type>: <concise subject>\"",
    "gt submit",
    "gh pr edit <number> --title \"<concise title>\" --body-file <tmp-body-file>",
    "Re-fetch with `gh pr view`",
    "A successful push is not a PR receipt",
    "do not use raw Git, `gh pr create`",
    "Never force-push",
    "Do not merge",
):
    must(corpus, token, "Graphite and GitHub boundary")

for token in (
    "After an error, timeout, or otherwise unknown Graphite result",
    "complete absence of submission, remote branch, PR, and relation permits one retry",
    "all Graphite/remote/PR surfaces still exactly at A",
    "mixed A/B state",
    "blocks without resubmission",
):
    must(corpus, token, "unknown submit admission")

# PR B read-back gates initial relation creation or stable relation retention, then state handling.
ordered(
    linear,
    (
        "## Identify, update, and verify the canonical PR",
        "independently re-fetch it by retained number with `gh pr view`",
        "## Record and read back PR relation and state",
        "The native Linear PR relation is a stable attribution record",
        "independently re-read both the preallocated native relation identity",
        "Only that stable relation plus exact GitHub-B receipt permits state handling",
    ),
    "PR relation and state boundary",
)
for token in (
    "exactly one stable matching canonical PR relation",
    "Project membership, dependency relations, role, owner, Git base, and head remain independently read authorities",
    "ordinary-later or consumed-restack update must already be exactly `inReview`",
    "never changes the feature project's phase/status",
    "never marks an issue or project `done`",
    "regardless of whether the mutation returned success, error, or timeout",
):
    must(corpus, token, "relation/state read-back")


# Executable trailer grammar. The mutation simulation below proves malformed input cannot cross
# the pre-commit boundary and valid standalone/project suffixes choose exactly one shape.
def validate_trailers(body, role, issue, project=None):
    lines = body.splitlines()
    while lines and lines[-1] == "":
        lines.pop()
    if not lines:
        raise ValueError("empty body")

    if any("Spec:" in line for line in lines):
        raise ValueError("Spec mention")

    issue_mentions = [index for index, line in enumerate(lines) if "Linear-Issue:" in line]
    project_mentions = [index for index, line in enumerate(lines) if "Linear-Project:" in line]
    expected_issue = f"Linear-Issue: {issue}"
    if len(issue_mentions) != 1 or lines[issue_mentions[0]] != expected_issue:
        raise ValueError("issue trailer count or raw form")
    if issue_mentions[0] != len(lines) - 1:
        raise ValueError("issue trailer is not final")

    if role == "work-item":
        if project is not None or project_mentions:
            raise ValueError("synthetic project")
        return [expected_issue]

    if role != "increment" or not project:
        raise ValueError("unknown role or missing project")
    expected_project = f"Linear-Project: {project}"
    if len(project_mentions) != 1 or lines[project_mentions[0]] != expected_project:
        raise ValueError("project trailer count or raw form")
    if project_mentions[0] != issue_mentions[0] - 1:
        raise ValueError("project trailer is not immediately preceding")
    return [expected_project, expected_issue]


issue = "APP-41"
project = "11111111-1111-4111-8111-111111111111"
prose = "## Goal\n\nShip the cache guard.\n\n## Summary\n\n- Add the guard."
standalone = f"{prose}\n\nLinear-Issue: {issue}\n"
increment = f"{prose}\n\nLinear-Project: {project}\nLinear-Issue: {issue}\n"

if validate_trailers(standalone, "work-item", issue) != [f"Linear-Issue: {issue}"]:
    fail("valid standalone suffix was not retained exactly")
if validate_trailers(increment, "increment", issue, project) != [
    f"Linear-Project: {project}",
    f"Linear-Issue: {issue}",
]:
    fail("valid increment suffix was not retained exactly")

malformed = {
    "Spec trailer": f"{prose}\nSpec: .woostack/fixes/cache.md\nLinear-Issue: {issue}",
    "bulleted Spec": f"{prose}\n- Spec: .woostack/fixes/cache.md\nLinear-Issue: {issue}",
    "quoted Spec": f"{prose}\n> Spec: .woostack/fixes/cache.md\nLinear-Issue: {issue}",
    "fenced Spec": (
        f"{prose}\n```text\nSpec: .woostack/fixes/cache.md\n```\nLinear-Issue: {issue}"
    ),
    "indented Spec": f"{prose}\n    Spec: .woostack/fixes/cache.md\nLinear-Issue: {issue}",
    "inline-code Spec": f"{prose}\n`Spec: .woostack/fixes/cache.md`\nLinear-Issue: {issue}",
    "duplicate issue": f"{prose}\nLinear-Issue: {issue}\nLinear-Issue: {issue}",
    "issue not final": f"{prose}\nLinear-Issue: {issue}\ntrailing text",
    "wrapped issue": f"{prose}\n- Linear-Issue: {issue}",
    "wrong issue": f"{prose}\nLinear-Issue: APP-99",
    "synthetic work-item project": increment,
    "missing increment project": standalone,
    "duplicate project": (
        f"{prose}\nLinear-Project: {project}\nLinear-Project: {project}\n"
        f"Linear-Issue: {issue}"
    ),
    "reordered pair": (
        f"{prose}\nLinear-Issue: {issue}\nLinear-Project: {project}"
    ),
    "separated pair": (
        f"{prose}\nLinear-Project: {project}\n\nLinear-Issue: {issue}"
    ),
    "wrong project": (
        f"{prose}\nLinear-Project: 99999999-9999-4999-8999-999999999999\n"
        f"Linear-Issue: {issue}"
    ),
}

for name, body in malformed.items():
    role = "work-item" if name not in {
        "missing increment project",
        "duplicate project",
        "reordered pair",
        "separated pair",
        "wrong project",
    } else "increment"
    supplied_project = None if role == "work-item" else project
    try:
        validate_trailers(body, role, issue, supplied_project)
    except ValueError:
        continue
    fail(f"malformed trailer case crossed the gate: {name}")


operation_receipts = [
    "commit",
    "comment:implementationEvidence",
    "read:implementationEvidence",
    "submit:gt",
    "write:canonical-pr",
    "read:canonical-pr",
    "write:pr-relation",
    "read:pr-relation",
    "state:inReview",
    "read:state",
]


def simulate(body, role, issue, project=None, failed_preflight=None):
    receipts = []
    if failed_preflight is not None:
        return receipts
    try:
        validate_trailers(body, role, issue, project)
    except ValueError:
        return receipts
    receipts.extend(operation_receipts)
    return receipts


if simulate(standalone, "work-item", issue) != operation_receipts:
    fail("valid standalone case did not preserve operation order")
if simulate(increment, "increment", issue, project) != operation_receipts:
    fail("valid increment case did not preserve operation order")

for name in (
    "foreign repository",
    "wrong resource kind/role",
    "owner drift",
    "bad branch/base ancestry",
    "project membership mismatch",
    "dependency relation mismatch",
    "partial read-back",
    "unknown read-back",
):
    if simulate(standalone, "work-item", issue, failed_preflight=name):
        fail(f"{name} produced a mutation receipt")

for name, body in malformed.items():
    role = "work-item" if name not in {
        "missing increment project",
        "duplicate project",
        "reordered pair",
        "separated pair",
        "wrong project",
    } else "increment"
    supplied_project = None if role == "work-item" else project
    if simulate(body, role, issue, supplied_project):
        fail(f"malformed case produced a mutation receipt: {name}")


resume_boundaries = (
    "commit",
    "implementationEvidence",
    "submission",
    "canonicalPr",
    "prFields",
    "relation",
    "inReview",
)


def classify_resume(snapshot):
    values = [snapshot[name] for name in resume_boundaries[:-1]]
    state = snapshot["inReview"]
    if any(value not in {"absent", "exact"} for value in values):
        return "blocked"
    if state not in {"executing", "inReview"}:
        return "blocked"
    normalized = values + (["exact"] if state == "inReview" else ["absent"])
    saw_absent = False
    first_absent = None
    for name, value in zip(resume_boundaries, normalized):
        if value == "absent":
            if first_absent is None:
                first_absent = name
            saw_absent = True
        elif saw_absent:
            return "blocked"
    return first_absent or "complete"


resume_cases = (
    (
        {
            "commit": "absent",
            "implementationEvidence": "absent",
            "submission": "absent",
            "canonicalPr": "absent",
            "prFields": "absent",
            "relation": "absent",
            "inReview": "executing",
        },
        "commit",
    ),
    (
        {
            "commit": "exact",
            "implementationEvidence": "absent",
            "submission": "absent",
            "canonicalPr": "absent",
            "prFields": "absent",
            "relation": "absent",
            "inReview": "executing",
        },
        "implementationEvidence",
    ),
    (
        {
            "commit": "exact",
            "implementationEvidence": "exact",
            "submission": "absent",
            "canonicalPr": "absent",
            "prFields": "absent",
            "relation": "absent",
            "inReview": "executing",
        },
        "submission",
    ),
    (
        {
            "commit": "exact",
            "implementationEvidence": "exact",
            "submission": "exact",
            "canonicalPr": "exact",
            "prFields": "exact",
            "relation": "absent",
            "inReview": "executing",
        },
        "relation",
    ),
    (
        {
            "commit": "exact",
            "implementationEvidence": "exact",
            "submission": "exact",
            "canonicalPr": "exact",
            "prFields": "exact",
            "relation": "exact",
            "inReview": "executing",
        },
        "inReview",
    ),
    (
        {
            "commit": "exact",
            "implementationEvidence": "exact",
            "submission": "exact",
            "canonicalPr": "exact",
            "prFields": "exact",
            "relation": "exact",
            "inReview": "inReview",
        },
        "complete",
    ),
)

for snapshot, expected_boundary in resume_cases:
    actual_boundary = classify_resume(snapshot)
    if actual_boundary != expected_boundary:
        fail(f"resume classified {actual_boundary!r}, expected {expected_boundary!r}")

for bad_value in ("partial", "unknown", "duplicate", "mismatched"):
    snapshot = dict(resume_cases[-1][0])
    snapshot["implementationEvidence"] = bad_value
    if classify_resume(snapshot) != "blocked":
        fail(f"resume admitted {bad_value} implementation evidence")

non_monotonic = dict(resume_cases[-1][0])
non_monotonic["implementationEvidence"] = "absent"
if classify_resume(non_monotonic) != "blocked":
    fail("resume admitted downstream evidence without implementationEvidence")



def commit_phase_counts(snapshot):
    count = 1 if classify_resume(snapshot) == "commit" else 0
    return {
        "hook": count,
        "passFreshnessHelper": count,
        "staging": count,
        "gtModify": count,
    }


expected_once = {
    "hook": 1,
    "passFreshnessHelper": 1,
    "staging": 1,
    "gtModify": 1,
}
if commit_phase_counts(resume_cases[0][0]) != expected_once:
    fail("commit-absent admission did not run hook/PASS/stage/modify exactly once")

expected_zero = {
    "hook": 0,
    "passFreshnessHelper": 0,
    "staging": 0,
    "gtModify": 0,
}
for snapshot, boundary in resume_cases[1:]:
    if commit_phase_counts(snapshot) != expected_zero:
        fail(f"resume at {boundary} replayed hook/PASS/stage/modify")


def select_pr_input(commit_state, staged_diff, committed_diff, dirty_state, draft, hook_observation):
    if commit_state == "absent":
        selected = staged_diff
        source = "staged-diff"
    elif commit_state == "exact":
        selected = committed_diff
        source = "verified-committed-base-to-head-diff"
    else:
        raise ValueError("unverified commit state")

    draft_used = bool(draft and draft.get("identity") == selected["identity"])
    hook_report = "Not rerun on resume; prior pre_commit result unavailable"
    if hook_observation and hook_observation.get("identity") == selected["identity"]:
        hook_report = hook_observation["result"]
    return {
        "source": source,
        "selectedDiff": selected["content"],
        "ignoredDirtyState": list(dirty_state),
        "draftUsed": draft_used,
        "hookReport": hook_report,
    }


resume_pr_snapshot = {
    "commit": "exact",
    "implementationEvidence": "exact",
    "submission": "exact",
    "canonicalPr": "exact",
    "prFields": "absent",
    "relation": "absent",
    "inReview": "executing",
}
if classify_resume(resume_pr_snapshot) != "prFields":
    fail("stale PR resume did not stop at PR fields")
if commit_phase_counts(resume_pr_snapshot) != expected_zero:
    fail("stale PR resume replayed hook/PASS/stage/modify")

unrelated_dirty = (
    "staged:notes/private.txt",
    "unstaged:scratch.txt",
    "untracked:tmp/output.bin",
)
draft_selection = select_pr_input(
    "exact",
    {"identity": "staged-now", "content": "UNRELATED STAGED CONTENT"},
    {"identity": "base-b45..head-c45", "content": "COMMITTED BASE-TO-HEAD DIFF"},
    unrelated_dirty,
    None,
    None,
)
if draft_selection["source"] != "verified-committed-base-to-head-diff":
    fail("post-commit PR draft did not select committed diff")
if draft_selection["selectedDiff"] != "COMMITTED BASE-TO-HEAD DIFF":
    fail("post-commit PR draft mixed unrelated dirty state")
if draft_selection["ignoredDirtyState"] != list(unrelated_dirty):
    fail("post-commit PR draft did not ignore all dirty-state classes")
if draft_selection["draftUsed"]:
    fail("post-commit PR draft fabricated or reused a lost draft")
if draft_selection["hookReport"] != "Not rerun on resume; prior pre_commit result unavailable":
    fail("post-commit PR draft inferred unavailable hook output")

mismatched_hook = select_pr_input(
    "exact",
    {"identity": "staged-now", "content": "UNRELATED STAGED CONTENT"},
    {"identity": "base-b45..head-c45", "content": "COMMITTED BASE-TO-HEAD DIFF"},
    unrelated_dirty,
    {"identity": "old-draft", "content": "stale"},
    {"identity": "old-commit", "result": "passed"},
)
if mismatched_hook["draftUsed"] or mismatched_hook["hookReport"] == "passed":
    fail("post-commit PR draft trusted identity-mismatched draft or hook output")

EXPECTED_PR_IDENTITY = {
    "count": 1,
    "number": 42,
    "url": "https://github.com/acme/widgets/pull/42",
    "repository": "https://github.com/acme/widgets",
    "branch": "feature/app-41-cache",
    "base": "main",
}
EXPECTED_STABLE_RELATION = {
    "nativeRelationId": "linear-pr-relation-42",
    "issueId": "issue-app-41",
    "repository": "https://github.com/acme/widgets",
    "pullRequestNumber": 42,
    "pullRequestUrl": "https://github.com/acme/widgets/pull/42",
    "branch": "feature/app-41-cache",
}
HEAD_A = "a" * 40
HEAD_B = "b" * 40
HEAD_C = "c" * 40


def pr_at(head, **changes):
    value = {**EXPECTED_PR_IDENTITY, "head": head}
    value.update(changes)
    return value


def stable_relation(**changes):
    value = dict(EXPECTED_STABLE_RELATION)
    value.update(changes)
    return value


def exact_record(record, expected):
    return isinstance(record, dict) and record == expected


def classify_initial_submit(graphite, remote_branch, pull_request, relation, recovering=False):
    observed = (graphite, remote_branch, pull_request, relation)
    if observed == ("absent", "absent", "absent", "absent"):
        return "retry-initial" if recovering else "submit-initial"
    if (
        recovering
        and graphite == HEAD_B
        and remote_branch == HEAD_B
        and exact_record(pull_request, pr_at(HEAD_B))
        and relation == "absent"
    ):
        return "read-back-initial-pr"
    return "blocked"


def classify_existing_update(
    mode,
    history,
    graphite,
    remote_branch,
    pull_request,
    relation,
    recovering=False,
):
    expected_history = {
        "eventId": "implementation-event-41",
        "priorNativeId": "implementation-native-a",
        "priorHead": HEAD_A,
        "currentHead": HEAD_B,
        "supersedesId": "implementation-native-a",
        "resolvedAt": (
            "authorizationTime"
            if mode == "consumed-restack"
            else "prior-evidence-authoritative-time"
        ),
        "authorizationConsumed": mode == "consumed-restack",
    }
    if mode not in {"ordinary-later", "consumed-restack"} or history != expected_history:
        return "blocked"
    if not exact_record(relation, stable_relation()):
        return "blocked"
    if (
        graphite == HEAD_A
        and remote_branch == HEAD_A
        and exact_record(pull_request, pr_at(HEAD_A))
    ):
        return "retry-same-pr" if recovering else "submit-same-pr"
    if (
        graphite == HEAD_B
        and remote_branch == HEAD_B
        and exact_record(pull_request, pr_at(HEAD_B))
    ):
        return "complete"
    return "blocked"


def history_for(mode):
    return {
        "eventId": "implementation-event-41",
        "priorNativeId": "implementation-native-a",
        "priorHead": HEAD_A,
        "currentHead": HEAD_B,
        "supersedesId": "implementation-native-a",
        "resolvedAt": (
            "authorizationTime"
            if mode == "consumed-restack"
            else "prior-evidence-authoritative-time"
        ),
        "authorizationConsumed": mode == "consumed-restack",
    }


# A first submit is fail-closed: only complete all-state absence admits creation. Existing state is
# never promoted into the update path without a prior A revision and its stable relation.
if classify_initial_submit("absent", "absent", "absent", "absent") != "submit-initial":
    fail("proven-absent initial state did not admit the sole creation path")
for observed in (
    (HEAD_A, HEAD_A, pr_at(HEAD_A), stable_relation()),
    (HEAD_B, HEAD_B, pr_at(HEAD_B), stable_relation()),
    ("absent", HEAD_A, "absent", "absent"),
    ("unknown", "unknown", "unknown", "unknown"),
):
    if classify_initial_submit(*observed) != "blocked":
        fail(f"fresh initial submission admitted pre-existing or unknown state: {observed!r}")

latest_by_kind_history = history_for("consumed-restack")
latest_by_kind_history["resolvedAt"] = "latest-event-by-kind"
if (
    classify_existing_update(
        "consumed-restack",
        latest_by_kind_history,
        HEAD_A,
        HEAD_A,
        pr_at(HEAD_A),
        stable_relation(),
    )
    != "blocked"
):
    fail("restack admission substituted latest-by-kind history for authorizationTime")


# Both eligible later modes update one immutable PR A→B while retaining one unchanged relation.
for mode in ("ordinary-later", "consumed-restack"):
    history = history_for(mode)
    if (
        classify_existing_update(
            mode, history, HEAD_A, HEAD_A, pr_at(HEAD_A), stable_relation()
        )
        != "submit-same-pr"
    ):
        fail(f"{mode} did not admit same-PR update from exact A")
    if (
        classify_existing_update(
            mode, history, HEAD_B, HEAD_B, pr_at(HEAD_B), stable_relation()
        )
        != "complete"
    ):
        fail(f"{mode} did not complete with the unchanged stable relation")


# Stale/foreign/duplicate identities and A/B mixtures cannot create or replace a PR/relation.
collision_cases = (
    (HEAD_A, HEAD_A, pr_at(HEAD_C), stable_relation()),
    (HEAD_A, HEAD_A, pr_at(HEAD_A, repository="https://github.com/evil/widgets"), stable_relation()),
    (HEAD_A, HEAD_A, pr_at(HEAD_A, count=2), stable_relation()),
    (HEAD_A, HEAD_A, pr_at(HEAD_A), stable_relation(nativeRelationId="replacement")),
    (HEAD_B, HEAD_A, pr_at(HEAD_B), stable_relation()),
)
ordinary_history = history_for("ordinary-later")
for observed in collision_cases:
    if classify_existing_update("ordinary-later", ordinary_history, *observed) != "blocked":
        fail(f"stale/foreign/duplicate existing-PR state crossed the gate: {observed!r}")


# Unknown outcomes recover only against retained identities: exact A permits the same-PR retry,
# exact B completes with the same stable relation, and partial state remains blocked.
if (
    classify_initial_submit("absent", "absent", "absent", "absent", recovering=True)
    != "retry-initial"
):
    fail("proven-absent unknown initial submit did not admit one retry")
if (
    classify_initial_submit(HEAD_B, HEAD_B, pr_at(HEAD_B), "absent", recovering=True)
    != "read-back-initial-pr"
):
    fail("verified unknown initial submit did not recover the exact B PR")
if (
    classify_existing_update(
        "ordinary-later",
        ordinary_history,
        HEAD_A,
        HEAD_A,
        pr_at(HEAD_A),
        stable_relation(),
        recovering=True,
    )
    != "retry-same-pr"
):
    fail("unknown later submit did not limit retry to the retained PR at exact A")
for relation in (
    "unknown",
    stable_relation(nativeRelationId="replacement"),
    stable_relation(branch="feature/foreign"),
):
    if (
        classify_existing_update(
            "ordinary-later",
            ordinary_history,
            HEAD_B,
            HEAD_B,
            pr_at(HEAD_B),
            relation,
            recovering=True,
        )
        != "blocked"
    ):
        fail(f"existing update accepted partial/replacement relation: {relation!r}")
for observed in (
    ("unknown", "unknown", "unknown", "unknown"),
    (HEAD_B, HEAD_A, pr_at(HEAD_B), stable_relation()),
    (HEAD_B, HEAD_B, pr_at(HEAD_B, number=99), stable_relation()),
):
    if (
        classify_existing_update(
            "ordinary-later", ordinary_history, *observed, recovering=True
        )
        != "blocked"
    ):
        fail(f"partial unknown existing-PR state admitted retry: {observed!r}")

print("test-linear-attribution: OK")
PY
