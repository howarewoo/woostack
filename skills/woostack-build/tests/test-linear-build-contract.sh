#!/usr/bin/env bash
# Structural contract for the thin canonical Linear build wrapper.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import json
import hashlib
import unicodedata
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
    "render and present complete `project-spec.md` followed by a body-free `Accept`/`Abandon` Ask",
    "pre-save drift read",
    "one bounded sync",
    "exact content read-back",
    "receipt/read-back",
    "gate-file and manifest cleanup",
    "present verified handoff and ask `Stop here`/`Execute`/`Abandon`",
    "## Exactly two approval stops",
    "projectSpecApprovalRecord",
    "executionPlanApprovalRecord",
    "candidate strict sequential direct-issue chain",
    "performs no provider read or mutation",
    "Build then asks a body-free handoff question",
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
    "exactly one JSON manifest and at most these two Markdown gate files",
    "project-spec.md",
    "execution-plan.md",
    "no-follow semantics",
    "regular",
    "byte length",
    "SHA-256",
    "fingerprintVersion",
    "deterministic",
    "regeneration",
    "Ideate, both Harden passes, and Build/Fix-delegated Plan",
    "zero Linear or other provider reads and writes",
    "complete verified Markdown bytes and their full identity",
    "For a same-process revision",
    "body-free Ask",
    "options: [\"Accept\", \"Abandon\"]",
    "immediately re-read the exact Linear targets",
    "exact content read-back",
    "canonical issue reference",
    "explicitly requested and all pagination",
    "unknown parent state",
    "exact endpoint round trip",
    "zero provider and repository mutation",
    "An unreceipted approval is consumed and cannot be replayed",
    "changed or replaced file",
    "fresh body-free Ask",
    "unlink both gate files and the manifest",
    "treat the local draft as the last approved Linear",
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
    r"complete displayed-content approval identity",
    r"complete exact local content to be saved",
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
    "renders-project-spec-file-ask",
    "renders-execution-plan-file-ask",
    "renders-one-increment-plan-with-empty-dependencies",
    "renders-same-process-revision-diff-with-fallbacks",
    "renders-gate-files-byte-exactly",
    "blocks-unreceipted-approval-replay",
    "enforces-run-manifest-boundaries",
    "blocks-unverified-manifest-cleanup",
    "validates-canonical-issue-references-before-graph-writes",
    "accepts-provider-presentation-equivalence",
    "rejects-unsupported-ordered-marker-boundaries",
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
    "rejects-unsupported-ordered-marker-boundaries",
    {
        "/status": "blocked",
        "/results": [
            {"id": "two-leading-spaces", "canonicalMatch": False, "receiptCount": 0, "freshAsk": True},
            {"id": "leading-tab", "canonicalMatch": False, "receiptCount": 0, "freshAsk": True},
            {"id": "nested-container", "canonicalMatch": False, "receiptCount": 0, "freshAsk": True},
            {"id": "fenced-code", "canonicalMatch": False, "receiptCount": 0, "freshAsk": True},
            {"id": "indented-code", "canonicalMatch": False, "receiptCount": 0, "freshAsk": True},
            {"id": "missing-whitespace", "canonicalMatch": False, "receiptCount": 0, "freshAsk": True},
            {"id": "repeated-delimiter", "canonicalMatch": False, "receiptCount": 0, "freshAsk": True},
            {"id": "unicode-digits", "canonicalMatch": False, "receiptCount": 0, "freshAsk": True},
            {"id": "ten-digit-marker", "canonicalMatch": False, "receiptCount": 0, "freshAsk": True},
            {"id": "changed-number", "canonicalMatch": False, "receiptCount": 0, "freshAsk": True},
            {"id": "changed-delimiter", "canonicalMatch": False, "receiptCount": 0, "freshAsk": True},
            {"id": "changed-text", "canonicalMatch": False, "receiptCount": 0, "freshAsk": True},
            {"id": "changed-order", "canonicalMatch": False, "receiptCount": 0, "freshAsk": True},
            {"id": "blank-line-continuation", "canonicalMatch": False, "receiptCount": 0, "freshAsk": True},
        ],
    },
)
require_eval_fields(
    "requires-fresh-ask-for-semantic-provider-change",
    {
        "/results": [
            {"id": "project-description", "approvalIdentityMatch": False, "receiptCount": 0, "freshAsk": True},
            {"id": "increment-description", "approvalIdentityMatch": False, "receiptCount": 0, "freshAsk": True},
            {"id": "issue-description", "approvalIdentityMatch": False, "receiptCount": 0, "freshAsk": True},
            {"id": "rendered-gate-file", "approvalIdentityMatch": False, "receiptCount": 0, "freshAsk": True},
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
    ordered_markers = fixture.get("orderedMarkers")
    expected_ordered_markers = {
        "zeroLeadingSpace",
        "oneLeadingSpace",
        "continuationZeroLeadingSpace",
        "continuationOneLeadingSpace",
        "zeroLeadingSpaceParen",
        "oneLeadingSpaceParen",
        "nineDigitZeroLeadingSpace",
        "nineDigitOneLeadingSpace",
        "tabWhitespaceZeroLeadingSpace",
        "tabWhitespaceOneLeadingSpace",
        "multipleWhitespaceZeroLeadingSpace",
        "multipleWhitespaceOneLeadingSpace",
        "tenDigitZeroLeadingSpace",
        "tenDigitOneLeadingSpace",
        "twoLeadingSpaces",
        "leadingTab",
        "nestedContainer",
        "fencedCode",
        "indentedCode",
        "missingWhitespace",
        "repeatedDelimiter",
        "unicodeDigits",
        "changedNumber",
        "changedDelimiter",
        "changedText",
        "changedOrder",
    }
    if (
        "terminalLf" not in fixture
        or not isinstance(semantic_mutations, dict)
        or set(marker_transitions or {}) != {"uniformDash", "uniformStar", "mixedDashStar"}
        or set(ordered_markers or {}) != expected_ordered_markers
    ):
        failures.append(f"{fixture_path}: package fixture misses mismatch forms")
    elif set(semantic_mutations) != {
        "projectDescription",
        "incrementDescription",
        "issueDescription",
        "renderedGateFile",
    }:
        failures.append(f"{fixture_path}: package fixture misses semantic surfaces")
    for gate_file in (
        fixture.get("approvedGateFile"),
        (semantic_mutations or {}).get("renderedGateFile"),
    ):
        if not isinstance(gate_file, dict) or set(gate_file) != {"identity", "utf8"}:
            failures.append(f"{fixture_path}: rendered gate-file fixture shape is incomplete")
            continue
        identity = gate_file["identity"]
        encoded = gate_file["utf8"].encode("utf-8")
        if set(identity) != {"path", "byteLength", "sha256", "fingerprintVersion"}:
            failures.append(f"{fixture_path}: rendered gate-file identity fields are incomplete")
        elif (
            identity["byteLength"] != len(encoded)
            or identity["sha256"] != f"sha256:{hashlib.sha256(encoded).hexdigest()}"
        ):
            failures.append(f"{fixture_path}: rendered gate-file length or digest is stale")

for label, eval_path, expected_id in (
    ("build", root / "skills/woostack-build/evals/evals.json", "renders-execution-plan-file-ask"),
    ("fix", root / "skills/woostack-fix/evals/evals.json", "renders-execution-plan-file-ask"),
):
    cases = json.loads(eval_path.read_text())["cases"]
    plan_case = next((case for case in cases if case["id"] == expected_id), None)
    if plan_case is None:
        failures.append(f"{label}: missing file-backed execution-plan Ask eval")
        continue
    stream = plan_case["assertions"][0]["expected"]
    identity = stream["identity"]
    gate_file = identity
    if not gate_file.get("path", "").endswith("/execution-plan.md"):
        failures.append(f"{label}: execution-plan stream does not bind its absolute file path")
    for field in ("byteLength", "sha256", "fingerprintVersion"):
        if field not in gate_file:
            failures.append(f"{label}: execution-plan stream misses identity field {field}")
    if (
        not stream.get("approvedStableTaskMappings")
        or not isinstance(stream.get("approvedDependencies"), list)
    ):
        failures.append(f"{label}: execution-plan stream misses approved mapping or complete dependency array")
    ask = plan_case["assertions"][1]["expected"]
    if ask != {"options": ["Accept", "Abandon"], "customResponseAvailable": True, "bodyFree": True}:
        failures.append(f"{label}: execution-plan Ask is not body-free Accept/Abandon")

empty_dependency_case = next(
    (case for case in evals["cases"] if case["id"] == "renders-one-increment-plan-with-empty-dependencies"),
    None,
)
if empty_dependency_case is None:
    failures.append("build: missing one-increment empty-dependency Ask eval")
else:
    empty_assertions = {
        assertion["pointer"]: assertion["expected"]
        for assertion in empty_dependency_case["assertions"]
    }
    if (
        empty_assertions.get("/artifactStream/approvedDependencies") != []
        or len(empty_assertions.get("/artifactStream/approvedStableTaskMappings", [])) != 1
    ):
        failures.append("build: one-increment stream does not preserve a complete empty dependency snapshot")

manifest_fixture = json.loads(
    (root / "skills/woostack-build/evals/fixtures/manifest-boundaries.json").read_text()
)
manifest_ids = [scenario["id"] for scenario in manifest_fixture["scenarios"]]
expected_manifest_ids = [
    "valid-atomic-update",
    "broad-directory-permissions",
    "symlinked-manifest",
    "foreign-owner",
    "gate-file-byte-length-mismatch",
    "gate-file-sha256-mismatch",
    "gate-file-changed-path",
    "gate-file-wrong-owner",
    "gate-file-wrong-mode",
    "gate-file-non-regular",
    "gate-file-symlink",
    "gate-file-changed-inode",
    "process-identity-mismatch",
    "failed-regeneration",
    "manifest-exclusive-temporary-write-failure",
    "manifest-file-flush-failure",
    "manifest-atomic-rename-failure",
    "manifest-directory-flush-failure",
    "gate-file-exclusive-temporary-write-failure",
    "gate-file-file-flush-failure",
    "gate-file-atomic-rename-failure",
    "gate-file-directory-flush-failure",
]
if manifest_ids != expected_manifest_ids:
    failures.append("build: gate-file boundary fixture is incomplete or out of order")

atomic_fields = {
    "exclusiveTemporaryWrite",
    "fileFlushed",
    "atomicRenameCompleted",
    "directoryFlushed",
}
for scenario in manifest_fixture["scenarios"]:
    if set(scenario.get("manifestAtomicWrite", {})) != atomic_fields:
        failures.append(f"build: {scenario['id']} misses manifest atomic-write evidence")
    if set(scenario.get("gateFileAtomicWrite", {})) != atomic_fields:
        failures.append(f"build: {scenario['id']} misses gate-file atomic-write evidence")
    if not isinstance(scenario.get("gateFile", {}).get("inodeMatchesApprovedSnapshot"), bool):
        failures.append(f"build: {scenario['id']} misses gate-file inode identity")

manifest_by_id = {scenario["id"]: scenario for scenario in manifest_fixture["scenarios"]}
length_case = manifest_by_id.get("gate-file-byte-length-mismatch", {}).get("gateFile", {})
sha_case = manifest_by_id.get("gate-file-sha256-mismatch", {}).get("gateFile", {})
inode_case = manifest_by_id.get("gate-file-changed-inode", {}).get("gateFile", {})
if not (
    length_case.get("byteLengthMatches") is False
    and length_case.get("sha256Matches") is True
    and length_case.get("regeneratedMatches") is True
):
    failures.append("build: byte-length mismatch is not isolated")
if not (
    sha_case.get("byteLengthMatches") is True
    and sha_case.get("sha256Matches") is False
    and sha_case.get("regeneratedMatches") is True
):
    failures.append("build: SHA-256 mismatch is not isolated")
if not (
    inode_case.get("inodeMatchesApprovedSnapshot") is False
    and inode_case.get("pathMatches") is True
    and inode_case.get("byteLengthMatches") is True
    and inode_case.get("sha256Matches") is True
    and inode_case.get("regeneratedMatches") is True
):
    failures.append("build: same-path same-byte inode replacement is not isolated")
atomic_failure_cases = [
    ("manifest-exclusive-temporary-write-failure", "manifestAtomicWrite", "exclusiveTemporaryWrite"),
    ("manifest-file-flush-failure", "manifestAtomicWrite", "fileFlushed"),
    ("manifest-atomic-rename-failure", "manifestAtomicWrite", "atomicRenameCompleted"),
    ("manifest-directory-flush-failure", "manifestAtomicWrite", "directoryFlushed"),
    ("gate-file-exclusive-temporary-write-failure", "gateFileAtomicWrite", "exclusiveTemporaryWrite"),
    ("gate-file-file-flush-failure", "gateFileAtomicWrite", "fileFlushed"),
    ("gate-file-atomic-rename-failure", "gateFileAtomicWrite", "atomicRenameCompleted"),
    ("gate-file-directory-flush-failure", "gateFileAtomicWrite", "directoryFlushed"),
]
for case_id, failed_record, failed_stage in atomic_failure_cases:
    scenario = manifest_by_id.get(case_id, {})
    failed_values = scenario.get(failed_record, {})
    other_record = (
        scenario.get("gateFileAtomicWrite", {})
        if failed_record == "manifestAtomicWrite"
        else scenario.get("manifestAtomicWrite", {})
    )
    if (
        failed_values.get(failed_stage) is not False
        or any(
            value is not True
            for stage, value in failed_values.items()
            if stage != failed_stage
        )
        or any(value is not True for value in other_record.values())
    ):
        failures.append(f"build: {case_id} does not isolate one atomic-write stage")

render_fixture = json.loads(
    (root / "skills/woostack-build/evals/fixtures/gate-file-rendering.json").read_text()
)
render_ids = [case["id"] for case in render_fixture.get("cases", [])]
if render_ids != [
    "project-spec-normalizes-unicode-and-line-endings",
    "execution-plan-sorts-issues-and-dependencies",
    "execution-plan-empty-dependencies",
]:
    failures.append("build: deterministic gate-file rendering fixture is incomplete or out of order")
renderer_eval = next(
    (case for case in evals["cases"] if case["id"] == "renders-gate-files-byte-exactly"),
    None,
)
if renderer_eval is not None:
    rendered_files = next(
        assertion["expected"]
        for assertion in renderer_eval["assertions"]
        if assertion["pointer"] == "/files"
    )
    for rendered in rendered_files:
        encoded = rendered["utf8"].encode("utf-8")
        if rendered["byteLength"] != len(encoded):
            failures.append(f"build: {rendered['id']} byte length is stale")
        if rendered["sha256"] != f"sha256:{hashlib.sha256(encoded).hexdigest()}":
            failures.append(f"build: {rendered['id']} SHA-256 is stale")
    project_input = render_fixture["cases"][0]["manifest"]["draft"]["specification"]
    plan_draft = render_fixture["cases"][1]["manifest"]["draft"]
    if "\r" not in project_input or unicodedata.normalize("NFC", project_input) == project_input:
        failures.append("build: project renderer fixture misses NFC or line-ending normalization")
    if [item["ordinal"] for item in plan_draft["increments"]] == sorted(
        item["ordinal"] for item in plan_draft["increments"]
    ):
        failures.append("build: execution-plan issue input is not deliberately unsorted")
    dependency_keys = [
        (item["predecessorTaskKey"], item["successorTaskKey"], item["kind"])
        for item in plan_draft["dependencies"]
    ]
    if dependency_keys == sorted(dependency_keys):
        failures.append("build: execution-plan dependency input is not deliberately unsorted")
    empty_render_case = next(
        (
            case
            for case in render_fixture.get("cases", [])
            if case["id"] == "execution-plan-empty-dependencies"
        ),
        None,
    )
    if empty_render_case is None:
        failures.append("build: empty-dependency renderer fixture is missing")
    else:
        empty_draft = empty_render_case.get("manifest", {}).get("draft", {})
        if (
            empty_draft.get("dependencies") != []
            or len(empty_draft.get("increments", [])) != 1
        ):
            failures.append("build: empty-dependency renderer input is not one increment with []")
    empty_rendered = next(
        (rendered for rendered in rendered_files if rendered["id"] == "execution-plan-empty-dependencies"),
        None,
    )
    if (
        empty_rendered is None
        or "## Dependencies\n\n- None.\n" not in empty_rendered.get("utf8", "")
    ):
        failures.append("build: empty-dependency renderer output misses the exact - None. sentinel")


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
    "new-task-native-success",
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

if (
    fixture["nativeOperationIdSupported"] is not False
    or fixture["operationIdentity"] != "11111111-1111-4111-8111-111111111111"
    or fixture["summaryMarker"]
    != "Woostack project mutation ID: 11111111-1111-4111-8111-111111111111"
):
    failures.append("build: project fallback identity or summary marker is not exact")
project_precreate = fixture["preCreateRead"]
if (
    project_precreate.get("complete") is not True
    or project_precreate.get("matchingOperationIds") != []
    or project_precreate.get("matchingSummaryMarkers") != []
    or not project_precreate.get("activeProjectPages")
    or not project_precreate.get("archivedProjectPages")
    or any(
        page.get("complete") is not True
        for page in project_precreate["activeProjectPages"]
        + project_precreate["archivedProjectPages"]
    )
    or project_precreate["activeProjectPages"][-1].get("nextCursor") is not None
    or project_precreate["archivedProjectPages"][-1].get("nextCursor") is not None
):
    failures.append("build: project fallback pre-create read lacks complete active/archived absence proof")
project_create = fixture["createResponse"]
project_read = fixture["independentRead"]
if (
    project_create.get("attempts") != 1
    or project_create.get("summary") != fixture["summaryMarker"]
    or project_read.get("operationIdentity") != fixture["operationIdentity"]
    or project_read.get("summary") != fixture["summaryMarker"]
    or project_read.get("markerPreserved") is not True
    or project_read.get("canonicalProjectSpecFingerprintExcludesMarker") is not True
    or project_read.get("complete") is not True
):
    failures.append("build: project fallback create or independent read-back is incomplete")
if (
    fixture["suppliedProjectSelection"]["fallbackDiscoveryPerformed"] is not False
    or fixture["suppliedProjectSelection"]["createAttempts"] != 0
    or fixture["suppliedProjectSelection"]["nativeOperationIdentityRequired"] is not False
    or fixture["suppliedProjectSelection"]["name"] != "Existing customer roadmap"
):
    failures.append("build: supplied project does not bypass fallback and preserve existing identity")
if (
    fixture["independentRead"].get("intendedSpecification")
    != {
        "description": fixture["intendedSpecification"]["description"],
        "update": fixture["intendedSpecification"]["update"],
    }
    or fixture["independentRead"].get("canonicalProjectSpecFingerprint")
    != fixture["intendedSpecification"]["canonicalProjectSpecFingerprint"]
):
    failures.append("build: project intended specification or fingerprint read-back is incomplete")
if (
    fixture["summaryOmittingUpdate"]["updateResponse"].get("summaryOmitted") is not True
    or fixture["summaryOmittingUpdate"]["independentSummaryRead"].get("markerPreserved") is not True
):
    failures.append("build: summary-omitting update does not independently preserve marker")
native_project = fixture["nativeSupportedScenario"]
if (
    native_project.get("nativeOperationIdSupported") is not True
    or native_project.get("fallbackMarkerPresent") is not False
    or native_project.get("fallbackDiscoveryPerformed") is not False
    or native_project.get("createAttempts") != 1
    or native_project.get("create", {}).get("nativeOperationId")
    != native_project.get("nativeProjectMutationId")
    or native_project.get("directRoundTrip", {}).get("nativeOperationId")
    != native_project.get("nativeProjectMutationId")
    or native_project.get("directRoundTrip", {}).get("fallbackMarkerPresent") is not False
):
    failures.append("build: native project identity fixture is incomplete or marker-bearing")
project_recovery = fixture["fallbackRecoveryCases"]
expected_project_recovery = [
    ("partial-pagination", "incomplete-project-pagination", 0, False),
    ("duplicate-marker", "duplicate-project-mutation-marker", 0, False),
    ("foreign-marker", "foreign-project-mutation-marker", 0, False),
    ("malformed-marker", "malformed-project-mutation-marker", 0, False),
    ("drifted-recovery-match", "project-mutation-marker-drift", 1, False),
    ("replacement-uuid", "replacement-mutation-identity-forbidden", 1, False),
    ("create-replay", "project-create-replay-forbidden", 1, False),
    ("unknown-outcome-partial-pagination", "incomplete-project-recovery-pagination", 1, False),
    ("unknown-outcome-duplicate-marker", "duplicate-project-mutation-marker-after-attempt", 1, False),
    ("unknown-outcome-foreign-marker", "foreign-project-mutation-marker-after-attempt", 1, False),
    ("unknown-outcome-malformed-marker", "malformed-project-mutation-marker-after-attempt", 1, False),
    ("unknown-outcome-same-marker-success", "project-mutation-recovered", 1, True),
]
if [
    (
        case.get("id"),
        case.get("reasonCode"),
        case.get("createAttempts"),
        case.get("advance"),
        case.get("replacementIdentityAllocated"),
        case.get("createReplay"),
    )
    for case in project_recovery
] != [
    (case_id, reason, attempts, advance, False, False)
    for case_id, reason, attempts, advance in expected_project_recovery
]:
    failures.append("build: project fallback recovery cases are incomplete or replayable")

issue_success = next(
    (
        scenario
        for scenario in shape_fixture["scenarios"]
        if scenario["id"] == "new-task-readback-success"
    ),
    None,
)
if issue_success is None:
    failures.append("build: successful issue fallback scenario is missing")
else:
    issue_request = issue_success["request"]
    issue_identity = "77777777-7777-4777-8777-777777777777"
    issue_title = f"Implement cache freshness [woostack-mutation:{issue_identity}]"
    issue_precreate = issue_request["preCreateRead"]
    issue_create = issue_request["create"]
    issue_read = issue_request["postCreateRead"]
    if (
        issue_request.get("nativeOperationIdSupported") is not False
        or issue_request.get("mutationIdentity") != issue_identity
        or issue_request.get("approvedTitle") != issue_title
        or issue_request.get("canonicalIncrementFingerprintIncludesSuffix") is not True
        or issue_precreate.get("complete") is not True
        or issue_precreate.get("matchingSuffixes") != []
        or issue_precreate.get("scope")
        != {"workspaceId": "workspace-woo", "teamId": "team-woo"}
        or not issue_precreate.get("activeIssuePages")
        or not issue_precreate.get("archivedIssuePages")
        or any(
            page.get("complete") is not True
            for page in issue_precreate["activeIssuePages"]
            + issue_precreate["archivedIssuePages"]
        )
        or any(
            page.get("nextCursor") is None
            for page in issue_precreate["activeIssuePages"][:-1]
            + issue_precreate["archivedIssuePages"][:-1]
        )
        or issue_precreate["activeIssuePages"][-1].get("nextCursor") is not None
        or issue_precreate["archivedIssuePages"][-1].get("nextCursor") is not None
        or issue_create.get("mutationIdentity") != issue_identity
        or issue_create.get("providerNativeIssueId") != "issue-native-149"
        or issue_create.get("title") != issue_title
        or issue_create.get("attempts") != 1
        or issue_create.get("returnedReference") != "WOO-149"
        or issue_read.get("reference") != "WOO-149"
        or issue_read.get("providerNativeIssueId") != "issue-native-149"
        or issue_read.get("title") != issue_title
        or issue_read.get("description") != issue_request["approvedDescription"]
        or issue_read.get("parentFieldRequested") is not True
        or issue_read.get("parentId") is not None
        or issue_read.get("repository") != "https://github.com/howarewoo/woostack"
        or issue_read.get("workspaceId") != "workspace-woo"
        or issue_read.get("teamId") != "team-woo"
        or issue_read.get("projectId") is not None
        or issue_read.get("preMembershipState") != "absent"
        or issue_read.get("pagesComplete") is not True
        or issue_read.get("roundTrip")
        != {
            "providerNativeIssueId": "issue-native-149",
            "reference": "WOO-149",
            "repository": "https://github.com/howarewoo/woostack",
            "workspaceId": "workspace-woo",
            "teamId": "team-woo",
            "projectId": None,
        }
    ):
        failures.append("build: issue fallback suffix, absence, create, or direct read-back is incomplete")
    issue_recovery = issue_request["fallbackRecoveryCases"]
    expected_issue_recovery = [
        ("partial-pagination", "incomplete-issue-pagination", 0, False),
        ("duplicate-suffix", "duplicate-issue-mutation-suffix", 0, False),
        ("foreign-suffix", "foreign-issue-mutation-suffix", 0, False),
        ("malformed-suffix", "malformed-issue-mutation-suffix", 0, False),
        ("drifted-readback", "issue-mutation-title-drift", 1, False),
        ("replacement-uuid", "replacement-mutation-identity-forbidden", 1, False),
        ("create-replay", "issue-create-replay-forbidden", 1, False),
        ("unknown-outcome-partial-pagination", "incomplete-issue-recovery-pagination", 1, False),
        ("unknown-outcome-duplicate-suffix", "duplicate-issue-mutation-suffix-after-attempt", 1, False),
        ("unknown-outcome-foreign-suffix", "foreign-issue-mutation-suffix-after-attempt", 1, False),
        ("unknown-outcome-malformed-suffix", "malformed-issue-mutation-suffix-after-attempt", 1, False),
        ("unknown-outcome-same-suffix-success", "issue-mutation-recovered", 1, True),
    ]
    if [
        (
            case.get("id"),
            case.get("reasonCode"),
            case.get("createAttempts"),
            case.get("advance"),
            case.get("replacementIdentityAllocated"),
            case.get("createReplay"),
        )
        for case in issue_recovery
    ] != [
        (case_id, reason, attempts, advance, False, False)
        for case_id, reason, attempts, advance in expected_issue_recovery
    ]:
        failures.append("build: issue fallback recovery cases are incomplete or replayable")
    for case in issue_recovery:
        if case["phase"] == "unknown-outcome-recovery" and case.get("recoveryIdentity") != issue_identity:
            failures.append("build: issue fallback recovery changed the mutation identity")
native_issue = next(
    (
        scenario
        for scenario in shape_fixture["scenarios"]
        if scenario["id"] == "new-task-native-success"
    ),
    None,
)
if native_issue is None:
    failures.append("build: native issue identity scenario is missing")
else:
    native_request = native_issue["request"]
    native_create = native_request["create"]
    native_read = native_request["postCreateRead"]
    if (
        native_request.get("nativeOperationIdSupported") is not True
        or native_request.get("fallbackMarkerPresent") is not False
        or native_request.get("fallbackSuffixPresent") is not False
        or native_create.get("providerNativeIssueId") != "issue-native-150"
        or native_read.get("providerNativeIssueId") != "issue-native-150"
        or native_create.get("returnedReference") != "WOO-150"
        or native_read.get("reference") != "WOO-150"
        or native_read.get("preMembershipState") != "absent"
        or native_read.get("projectId") is not None
        or native_read.get("roundTrip", {}).get("providerNativeIssueId") != "issue-native-150"
        or native_request.get("projectMembership", {}).get("projectId") != "project-build-43"
        or native_request.get("postMembershipRead", {}).get("independentlyVerified") is not True
        or native_create.get("attempts") != 1
    ):
        failures.append("build: native issue identity or membership ordering fixture is incomplete")
chain_pattern = re.compile(
    r"resolve/create canonical project and admit gate 1 baseline\s*→\s*"
    r"draft Ideate/Harden locally with zero provider calls\s*→\s*"
    r"render and present complete `project-spec\.md` followed by a body-free `Accept`/`Abandon` Ask\s*→\s*"
    r"pre-save drift read.*?receipt/read-back\s*→\s*"
    r"draft delegated Plan/Harden locally with zero provider calls\s*→\s*"
    r"render and present complete `execution-plan\.md` followed by a body-free `Accept`/`Abandon` Ask\s*→\s*"
    r"pre-save drift read.*?receipt/read-back\s*→\s*"
    r"gate-file and manifest cleanup\s*→\s*present verified handoff and ask `Stop here`/`Execute`/`Abandon`",
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
