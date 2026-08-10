#!/usr/bin/env bash
# Structural contract for the thin canonical Linear build wrapper.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
paths = {
    "build": root / "skills/woostack-build/SKILL.md",
    "context": root / "skills/woostack-build/references/linear-context.md",
    "procedure": root / "skills/woostack-build/references/linear-procedure.md",
    "artifact": root / "skills/woostack-init/references/artifact-backends.md",
    "ideate": root / "skills/woostack-ideate/SKILL.md",
    "harden": root / "skills/woostack-harden/SKILL.md",
    "plan": root / "skills/woostack-plan/SKILL.md",
    "fix": root / "skills/woostack-fix/SKILL.md",
    "execute": root / "skills/woostack-execute/SKILL.md",
}
text = {name: path.read_text(encoding="utf-8") for name, path in paths.items()}
flat = {name: re.sub(r"\s+", " ", value) for name, value in text.items()}
failures = []


def require(name, needle):
    if needle not in flat[name]:
        failures.append(f"{name}: missing {needle!r}")


def forbid(name, pattern):
    if re.search(pattern, flat[name], re.I):
        failures.append(f"{name}: matches forbidden pattern {pattern!r}")


for needle in (
    "## Fixed chain",
    "admit gate 1 baseline",
    "draft Ideate/Harden locally with zero provider calls",
    "display complete exact project specification and approve",
    "pre-save drift read",
    "one bounded sync",
    "exact content read-back",
    "receipt/read-back",
    "manifest cleanup",
    "normal Execute",
    "## Exactly two approval stops",
    "projectSpecApprovalRecord",
    "executionPlanApprovalRecord",
    "candidate strict sequential direct-issue chain",
    "performs no provider read or mutation",
    "Build always invokes",
    "Build never merges",
    "last verified boundary",
    "repository association",
):
    require("build", needle)

require("build", "name starts with `[Build] `")
require("build", "Supplied projects retain their existing names")
require("context", "name starts with `[Build] `")
for needle in (
    "#### Run-scoped gated draft manifest",
    "exact Linear baseline",
    "host OS temporary-directory facility",
    "owner-only `0700`",
    "owner read/write `0600`",
    "atomically renames it over the manifest",
    "stableTaskMappings",
    "unresolvedQuestions",
    "Ideate, both Harden passes, and Build/Fix-delegated Plan",
    "zero Linear or other provider reads and writes",
    "complete exact local content to be saved",
    "not a summary or pointer-only presentation",
    "responsible user's matching approval must occur before any draft content is saved",
    "immediately re-read the exact Linear targets",
    "exact content read-back",
    "stableTaskMappings",
    "canonical issue reference",
    "explicitly requested and all pagination",
    "unknown parent state",
    "exact endpoint round trip",
    "zero provider and repository mutation",
    "An unreceipted approval is consumed and cannot be replayed",
    "different/restarted process",
    "fresh complete Ask",
    "Remove the manifest and its run-scoped temporary directory",
    "local draft as the last approved Linear boundary",
    "These Execute-era safety reads are unchanged",
    "providerPresentationCanonicalization",
    "presence or absence of exactly one terminal LF",
    "two or more terminal LFs",
    "byte-sensitive",
    "At end of string, leave the blank suffix unchanged",
):
    require("artifact", needle)
for obsolete in (
    r"gate 1 displays only the",
    r"gate 2 displays only the",
    r"Do not paste any project",
    r"After each user reply.*synchronization cycle",
    r"minimum serial read-patch-read",
):
    forbid("artifact", obsolete)
    forbid("build", obsolete)
    forbid("ideate", obsolete)

for name in ("build", "context", "procedure", "ideate", "harden", "plan"):
    require(name, "manifest")

for name in ("build", "context", "procedure"):
    require(name, "canonical issue-reference")
    require(name, "nullable-parent")

require("context", "before any direct project-membership or native-relation graph write")
require("procedure", "zero provider and repository mutation")
require("harden", "canonical issue references")

removal_first_contract = {
    "build": "safe removal/simplification analysis before additive work",
    "fix": "safe removal/simplification analysis before additive work",
    "ideate": "records viable removal opportunities before additive proposals",
    "harden": "challenges an additive draft when bounded evidence shows the same contract can be met by deletion or simplification",
    "plan": "executor-ready removal-before-addition analysis",
}
for name, needle in removal_first_contract.items():
    require(name, needle)

evals = json.loads((root / "skills/woostack-build/evals/evals.json").read_text())
eval_ids = {case["id"] for case in evals["cases"]}
for expected in (
    "renders-complete-project-spec-ask",
    "renders-complete-execution-plan-ask",
    "blocks-unreceipted-approval-replay",
    "enforces-run-manifest-boundaries",
    "blocks-unverified-manifest-cleanup",
    "validates-canonical-issue-references-before-graph-writes",
    "accepts-provider-presentation-equivalence",
    "requires-fresh-ask-for-semantic-provider-change",
    "rejects-mixed-marker-transition-canonical-mismatch",
    "rejects-terminal-lf-canonical-mismatch",
):
    if expected not in eval_ids:
        failures.append(f"build: missing eval {expected}")

def require_eval_fields(case_id, expected_values):
    case = next((item for item in evals["cases"] if item["id"] == case_id), None)
    if case is None:
        return
    assertions = {
        assertion.get("pointer"): assertion.get("expected")
        for assertion in case.get("assertions", [])
    }
    for pointer, expected in expected_values.items():
        if assertions.get(pointer) != expected:
            failures.append(f"build: {case_id} does not assert {pointer}={expected!r}")

require_eval_fields(
    "accepts-provider-presentation-equivalence",
    {
        "/approvalAskCount": 1,
        "/boundedSaveCount": 1,
        "/readBackCount": 1,
        "/receiptCount": 1,
        "/secondAskCount": 0,
    },
)
require_eval_fields(
    "requires-fresh-ask-for-semantic-provider-change",
    {
        "/results": [
            {"id": "project-description", "canonicalMatch": False, "receiptCount": 0, "freshAsk": True},
            {"id": "increment-description", "canonicalMatch": False, "receiptCount": 0, "freshAsk": True},
            {"id": "issue-description", "canonicalMatch": False, "receiptCount": 0, "freshAsk": True},
            {"id": "displayed-content", "canonicalMatch": False, "receiptCount": 0, "freshAsk": True},
        ],
    },
)
require_eval_fields(
    "rejects-mixed-marker-transition-canonical-mismatch",
    {
        "/canonicalMatch": False,
        "/receiptCount": 0,
        "/freshAsk": True,
    },
)
require_eval_fields(
    "rejects-terminal-lf-canonical-mismatch",
    {
        "/results": [
            {"id": "one-vs-two", "canonicalMatch": False, "receiptCount": 0, "freshAsk": True},
            {"id": "two-vs-three", "canonicalMatch": False, "receiptCount": 0, "freshAsk": True},
            {"id": "final-heading-two-vs-three", "canonicalMatch": False, "receiptCount": 0, "freshAsk": True},
        ],
    },
)

for fixture_path in (
    root / "skills/woostack-build/evals/fixtures/provider-presentation-canonicalization.json",
    root / "skills/woostack-fix/evals/fixtures/provider-presentation-canonicalization.json",
):
    fixture = json.loads(fixture_path.read_text())
    if "expected" in fixture:
        failures.append(f"{fixture_path}: eval fixture must not contain an oracle")
    semantic_mutations = fixture.get("semanticMutations")
    marker_transitions = fixture.get("markerTransitions")
    if (
        "terminalLf" not in fixture
        or not isinstance(semantic_mutations, dict)
        or set(marker_transitions or {}) != {"uniformDash", "uniformStar", "mixedDashStar"}
    ):
        failures.append(f"{fixture_path}: package fixture misses mismatch forms")
    elif set(semantic_mutations) != {
        "projectDescription",
        "incrementDescription",
        "issueDescription",
        "displayedContent",
    }:
        failures.append(f"{fixture_path}: package fixture misses semantic surfaces")

required_increment_fields = {
    "stableTaskKey",
    "url",
    "canonicalIssueReference",
    "ordinal",
    "outcome",
    "title",
    "description",
    "scope",
    "nonGoals",
    "targets",
    "steps",
    "acceptanceCriteria",
    "verification",
    "effects",
    "risks",
    "blockers",
    "stopMarker",
    "graphiteParent",
    "changedLineEstimate",
    "sizeRationale",
    "fingerprint",
}
for label, eval_path in (
    ("build", root / "skills/woostack-build/evals/evals.json"),
    ("fix", root / "skills/woostack-fix/evals/evals.json"),
):
    cases = json.loads(eval_path.read_text())["cases"]
    plan_case = next(
        (case for case in cases if case["id"] == "renders-complete-execution-plan-ask"),
        None,
    )
    if plan_case is None:
        failures.append(f"{label}: missing complete execution-plan Ask eval")
        continue
    increments = plan_case["assertions"][0]["expected"]["approvalAsk"]["increments"]
    for index, increment in enumerate(increments, start=1):
        missing = required_increment_fields - increment.keys()
        if missing:
            failures.append(
                f"{label}: increment {index} approval Ask misses {sorted(missing)}"
            )

manifest_fixture = json.loads(
    (root / "skills/woostack-build/evals/fixtures/manifest-boundaries.json").read_text()
)
manifest_ids = [scenario["id"] for scenario in manifest_fixture["scenarios"]]
expected_manifest_ids = [
    "valid-atomic-update",
    "broad-directory-permissions",
    "symlinked-manifest",
    "foreign-owner",
    "process-identity-mismatch",
    "non-atomic-replacement",
]
if manifest_ids != expected_manifest_ids:
    failures.append("build: manifest boundary fixture is incomplete or out of order")


shape_fixture = json.loads(
    (root / "skills/woostack-build/evals/fixtures/provider-read-shapes.json").read_text()
)
expected_shape_ids = [
    "canonical-parentless-valid-relation",
    "canonical-child-blocked",
    "parent-id-unrequested-unknown",
    "mixed-non-round-tripping-relation-endpoint",
    "canonical-parent-omitted-after-request",
    "repository-association-mismatch",
    "workspace-association-mismatch",
    "team-association-mismatch",
    "project-association-mismatch",
    "new-task-readback-failure",
    "new-task-readback-success",
]
if [scenario["id"] for scenario in shape_fixture["scenarios"]] != expected_shape_ids:
    failures.append("build: provider read-shape fixture is incomplete or out of order")
fixture = json.loads(
    (root / "skills/woostack-build/evals/fixtures/project-admission.json").read_text()
)
expected_project_name = "[Build] Bound cache freshness"
if fixture["createResponse"]["name"] != expected_project_name:
    failures.append("build: create request does not use the [Build] project prefix")
if fixture["independentRead"]["name"] != expected_project_name:
    failures.append("build: independent read does not verify the prefixed project name")

chain_pattern = re.compile(
    r"resolve/create canonical project and admit gate 1 baseline\s*→\s*"
    r"draft Ideate/Harden locally with zero provider calls\s*→\s*"
    r"display complete exact project specification and approve\s*→\s*"
    r"pre-save drift read.*?receipt/read-back\s*→\s*"
    r"draft delegated Plan/Harden locally with zero provider calls\s*→\s*"
    r"display complete exact execution plan and approve\s*→\s*"
    r"pre-save drift read.*?receipt/read-back\s*→\s*"
    r"manifest cleanup\s*→\s*normal Execute",
    re.S,
)
if not chain_pattern.search(text["build"]):
    failures.append("build: deferred synchronization chain is missing or out of order")

for pattern in (
    r"terminal choices",
    r"\*\*go\*\*",
    r"run overnight",
    r"hand off",
    r"\breplan\b",
    r"\babandon\b",
    r"parallel",
    r"parent plan",
    r"artifact-free execution handoff",
    r"buildProjectSpecApprovalRecord",
    r"buildExecutionPlanApprovalRecord",
):
    forbid("build", pattern)

require("ideate", "permission-restricted run-scoped JSON manifest")
require(
    "ideate",
    "Ask every currently known independent question together in one clearly numbered batch",
)
require(
    "ideate",
    "A batch may contain one question only when it is the sole currently eligible question",
)
require(
    "ideate",
    "atomically replace the manifest draft once",
)
require("ideate", "makes no provider call")
forbid("ideate", r"synchronization cycle")
forbid("ideate", r"read-patch-read")
require("harden", "performs zero provider reads and writes")
require("harden", "atomically replace the affected manifest draft content")
require("plan", "Delegated planning performs no provider read or mutation")
require("plan", "strict sequential chain")

if failures:
    print("thin canonical Linear build contract violations:", file=sys.stderr)
    for failure in failures:
        print(f"  - {failure}", file=sys.stderr)
    raise SystemExit(1)

print("test-linear-build-contract: ok")
PY
