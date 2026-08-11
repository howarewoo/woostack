#!/usr/bin/env bash
# Structural contract: canonical fix/build records, safe init defaults, optional artifacts elsewhere.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../../.." && pwd)"

python3 - "$ROOT" <<'PY'
import json
import re
import sys
import unicodedata
from pathlib import Path

root = Path(sys.argv[1])
failures = []

def flat(path):
    return re.sub(r"\s+", " ", path.read_text(encoding="utf-8"))

def require(label, text, pattern, message):
    if not re.search(pattern, text, re.I):
        failures.append(f"{label}: {message}")

flag_paths = list((root / "skills").glob("*/SKILL.md")) + [
    root / "AGENTS.md",
    root / "README.md",
]
for path in flag_paths:
    if re.search(r"(?<![\w-])--linear(?![\w-])", path.read_text(encoding="utf-8")):
        failures.append(f"{path.relative_to(root)}: obsolete --linear init flag remains")

init = flat(root / "skills/woostack-init/SKILL.md")
for pattern, message in (
    (r"Every run attempts automatic Linear setup", "default init does not attempt Linear setup"),
    (r"Authenticated read access is sufficient", "read-only authenticated setup is not sufficient"),
    (r"never selects artifact mode", "init setup can appear to select unrelated artifact use"),
    (r"continue ordinary local initialization", "Linear setup can appear to block local init"),
):
    require("woostack-init", init, pattern, message)

contract = flat(root / "skills/woostack-init/references/artifact-backends.md")
for pattern, message in (
    (r"canonical product records for `woostack-build` and project-backed `woostack-fix`", "canonical fix/build role missing"),
    (r"Each independently shippable increment is one direct issue in that project", "direct build issue shape missing"),
    (r"Do not create a parent plan issue", "retired build wrapper is not forbidden"),
    (r"not source-control or delivery authority", "source-control authority boundary missing"),
    (r"Run-scoped gated draft manifest", "gated manifest authority missing"),
    (r"host OS temporary-directory facility.*0700.*0600", "restricted OS-temp manifest missing"),
    (r"atomically renames it over the manifest", "atomic manifest update missing"),
    (r"zero Linear or other provider reads and writes", "provider-free gated drafting missing"),
    (r"complete project body.*complete issue descriptions remain", "complete displayed content missing"),
    (r"approval must occur before any draft content is saved", "approval-before-save ordering missing"),
    (r"immediately re-read the exact Linear targets", "immediate pre-save drift read missing"),
    (r"only after that exact content read-back, record", "read-back-before-receipt ordering missing"),
    (r"stableTaskMappings.*canonical issue reference", "canonical issue identity mapping missing"),
    (r"retained baseline issue.*explicit proposed canonical-issue-reference.*task-key mapping", "retained issue reconciliation missing"),
    (r"optimistic revision/content-identity precondition.*immediate fresh read", "mid-cycle drift protection missing"),
    (r"unreceipted approval is consumed and cannot be replayed", "unreceipted approval replay guard missing"),
    (r"restarted or different process.*fresh file render.*Ask", "process-loss invalidation missing"),
    (r"unlink both gate files and the manifest", "manifest cleanup missing"),
    (r"local draft.*never replaces.*last Linear-approved boundary", "local authority boundary missing"),
    (r"Standalone `woostack-plan`.*unchanged", "standalone Plan distinction missing"),
    (r"Execute-era safety reads are unchanged", "Execute read preservation missing"),
    (r"projectSpecApprovalRecord", "project-spec approval record missing"),
    (r"executionPlanApprovalRecord", "execution-plan approval record missing"),
    (r"project-specification change invalidates both.*issue or dependency change invalidates only", "approval invalidation rules missing"),
    (r"exact caller-supplied resource always takes precedence over creation", "exact-resource precedence safeguard missing"),
    (r"official Linear MCP's canonical issue reference.*WOO-144", "canonical issue-reference contract missing"),
    (r"bare provider issue UUID is not a canonical issue reference", "UUID-only issue endpoint prohibition missing"),
    (r"stableTaskMappings.*canonical issue reference", "stable-key canonical-reference mapping missing"),
    (r"parentId.*explicitly requested.*pagination", "nullable-parent admission contract missing"),
    (r"unknown parent state.*never becomes `null`", "unknown parent fail-closed rule missing"),
    (r"Before every direct-issue.*graph write", "graph-write preflight ordering missing"),
    (r"mixed endpoint.*non-round-tripping", "endpoint round-trip guard missing"),
    (r"zero provider mutation.*zero repository mutation", "zero-mutation blocker missing"),
    (r"provisional event.*never clears any gate", "provisional receipt non-authority missing"),
    (r"preallocated.*mutation identities", "stable operation identity safeguard missing"),
    (r"independently read back", "independent read-back safeguard missing"),
    (r"providerPresentationCanonicalization", "named provider presentation canonicalization missing"),
    (r"outside fenced and indented code", "code-boundary presentation scope missing"),
    (r"unordered `-` and `\*` list markers while retaining their transition pattern", "unordered-marker transition normalization missing"),
    (r"top-level ATX heading.*no leading indentation", "ATX heading container boundary missing"),
    (r"blank line whose expanded indentation is four or more columns", "heading indented-blank boundary missing"),
    (r"presence or absence of exactly one terminal LF.*two or more terminal LFs.*byte-sensitive", "terminal LF normalization boundary missing"),
    (r"expanded leading indentation columns.*next four-column stop", "expanded tab indentation boundary missing"),
    (r"Hard breaks.*unsupported ordered-list markers.*byte-sensitive", "presentation exclusions missing"),
    (r"Native provider bytes remain exact read-back evidence.*canonical fingerprints", "native evidence/canonical comparison missing"),
    (r"no second Ask.*fresh rendered gate file and concise Ask", "presentation approval recovery missing"),
):
    require("artifact-backends.md", contract, pattern, message)

for obsolete in (
    r"gate 1 displays only the",
    r"gate 2 displays only the",
    r"Do not paste any project",
):
    if re.search(obsolete, contract, re.I):
        failures.append(f"artifact-backends.md: obsolete approval presentation remains: {obsolete}")

presentation_fixture = root / "skills/woostack-init/scripts/tests/fixtures/provider-presentation-canonicalization.json"
try:
    presentation = json.loads(presentation_fixture.read_text(encoding="utf-8"))
except (OSError, json.JSONDecodeError) as error:
    failures.append(f"presentation fixture unreadable: {error}")
else:
    def normalize_global_markdown(value):
        value = unicodedata.normalize("NFC", value).replace("\r\n", "\n").replace("\r", "\n")
        terminal_lfs = len(value) - len(value.rstrip("\n"))
        return value.rstrip("\n") + "\n" if terminal_lfs <= 1 else value

    def canonicalize_markdown(value):
        value = normalize_global_markdown(value)
        lines = value.split("\n")
        result = []
        fence = None
        def expanded_indent_columns(line):
            columns = 0
            for character in line:
                if character == " ":
                    columns += 1
                elif character == "\t":
                    columns += 4 - (columns % 4)
                else:
                    break
            return columns
        marker_source = None
        marker_canonical = "*"
        index = 0
        while index < len(lines):
            line = lines[index]
            if expanded_indent_columns(line) >= 4:
                result.append(line)
                index += 1
                continue
            opening = re.match(r"^[ ]{0,3}(`{3,}|~{3,})", line)
            if fence is not None:
                result.append(line)
                if re.match(rf"^[ ]{{0,3}}{re.escape(fence[0])}{{{fence[1]},}}[ \t]*$", line):
                    fence = None
                index += 1
                continue
            if opening:
                result.append(line)
                fence = (opening.group(1)[0], len(opening.group(1)))
                index += 1
                continue
            if re.match(r"^#{1,6}(?:[ \t]+.*|[ \t]*)$", line):
                next_index = index + 1
                while (
                    next_index < len(lines)
                    and re.fullmatch(r"[ \t]*", lines[next_index])
                    and expanded_indent_columns(lines[next_index]) < 4
                ):
                    next_index += 1
                result.append(line)
                blocked_by_indented_blank = (
                    next_index < len(lines)
                    and re.fullmatch(r"[ \t]*", lines[next_index])
                    and expanded_indent_columns(lines[next_index]) >= 4
                )
                if next_index < len(lines) and not blocked_by_indented_blank:
                    index = next_index
                    result.append("")
                else:
                    index += 1
                continue
            ordered = re.match(r"^ ?[0-9]+[.)][ \t]+.*$", line)
            if ordered:
                line = line[1:] if line.startswith(" ") else line
            marker = re.match(r"^([ \t]*)([-*])([ \t]+)(.*)$", line)
            thematic = re.fullmatch(
                r"[ \t]{0,3}(?:-(?:[ \t]*-[ \t]*){2,}|\*(?:[ \t]*\*[ \t]*){2,})",
                line,
            )
            if marker and not thematic:
                if marker_source is not None and marker.group(2) != marker_source:
                    marker_canonical = "-" if marker_canonical == "*" else "*"
                marker_source = marker.group(2)
                line = f"{marker.group(1)}{marker_canonical}{marker.group(3)}{marker.group(4)}"
            result.append(line)
            index += 1
        return "\n".join(result)

    def canonical_record(record):
        normalized = json.loads(json.dumps(record))
        for entity in ("project", "increment", "issue"):
            normalized[entity]["description"] = canonicalize_markdown(normalized[entity]["description"])
        return normalized

    approved = presentation.get("approved")
    provider = presentation.get("provider")
    semantic = presentation.get("semanticMutation")
    expected = presentation.get("expected")
    if not all(isinstance(value, dict) for value in (approved, provider, semantic, expected)):
        failures.append("presentation fixture shape is incomplete")
    else:
        if canonical_record(approved) != canonical_record(provider):
            failures.append("provider presentation form is not canonically equivalent")
        if canonical_record(approved) == canonical_record(semantic):
            failures.append("semantic mutation was admitted as equivalent")
        if not expected.get("presentationEquivalent") or not expected.get("semanticMutationDifferent"):
            failures.append("presentation fixture expected flags are incomplete")
        transitions = presentation.get("markerTransitions")
        if not isinstance(transitions, dict):
            failures.append("marker transition fixture is missing")
        else:
            if canonicalize_markdown(transitions["uniformDash"]) != canonicalize_markdown(transitions["uniformStar"]):
                failures.append("uniform unordered markers are not canonically equivalent")
            if canonicalize_markdown(transitions["uniformDash"]) == canonicalize_markdown(transitions["mixedDashStar"]):
                failures.append("mixed unordered-marker transitions were over-normalized")
            if canonicalize_markdown(transitions["uniformDashAcrossProse"]) != canonicalize_markdown(transitions["uniformStarAcrossProse"]):
                failures.append("uniform unordered markers across prose are not canonically equivalent")
            if canonicalize_markdown(transitions["uniformDashAcrossProse"]) == canonicalize_markdown(transitions["mixedAcrossProse"]):
                failures.append("mixed unordered-marker transitions across prose were over-normalized")
            if not expected.get("uniformMarkersEquivalent") or not expected.get("mixedMarkerTransitionsSensitive"):
                failures.append("marker transition fixture expected flags are incomplete")
        ordered = presentation.get("orderedMarkers")
        if not isinstance(ordered, dict):
            failures.append("ordered marker fixture is missing")
        else:
            for left, right in (
                ("zeroLeadingSpace", "oneLeadingSpace"),
                ("zeroLeadingSpaceParen", "oneLeadingSpaceParen"),
            ):
                if canonicalize_markdown(ordered[left]) != canonicalize_markdown(ordered[right]):
                    failures.append(f"ordered marker pair is not equivalent: {left}/{right}")
            for left, right in (
                ("zeroLeadingSpace", "twoLeadingSpaces"),
                ("zeroLeadingSpace", "leadingTab"),
                ("zeroLeadingSpace", "nestedContainer"),
                ("zeroLeadingSpace", "missingWhitespace"),
                ("zeroLeadingSpace", "repeatedDelimiter"),
                ("zeroLeadingSpace", "unicodeDigits"),
                ("zeroLeadingSpace", "changedNumber"),
                ("zeroLeadingSpace", "changedDelimiter"),
                ("zeroLeadingSpace", "changedText"),
                ("zeroLeadingSpace", "changedOrder"),
            ):
                if canonicalize_markdown(ordered[left]) == canonicalize_markdown(ordered[right]):
                    failures.append(f"unsupported ordered marker boundary was normalized: {left}/{right}")
            for name in (
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
            ):
                if canonicalize_markdown(ordered[name]) != normalize_global_markdown(ordered[name]):
                    failures.append(f"unsupported ordered marker bytes changed: {name}")
            for name in ("fencedCode", "indentedCode"):
                if " 1. item" not in canonicalize_markdown(ordered[name]):
                    failures.append(f"ordered marker inside {name} was normalized")
            if canonicalize_markdown(ordered["nestedContainer"]) != "> 1. item\n":
                failures.append("container-nested ordered marker was normalized")
            if not expected.get("orderedMarkerEquivalent") or not expected.get("orderedMarkerBoundariesSensitive"):
                failures.append("ordered marker fixture expected flags are incomplete")
        headings = presentation.get("headingBoundaries")
        if not isinstance(headings, dict):
            failures.append("heading boundary fixture is missing")
        else:
            if "## Heading\n    \nBody" not in canonicalize_markdown(headings["indentedBlankAfterHeading"]):
                failures.append("indented blank line after heading was normalized away")
            if canonicalize_markdown(headings["nestedWithoutBlank"]) == canonicalize_markdown(headings["nestedWithBlank"]):
                failures.append("nested heading spacing was over-normalized")
            if not expected.get("indentedHeadingBlankSensitive") or not expected.get("nestedHeadingSpacingSensitive"):
                failures.append("heading boundary fixture expected flags are incomplete")
        canonical_provider = canonical_record(provider)
        for fragment_name, fragment in expected.get("preservedFragments", {}).items():
            if fragment not in canonical_provider["issue"]["description"]:
                failures.append(f"presentation fixture loses {fragment_name}")
        if provider["issue"]["description"] == approved["issue"]["description"]:
            failures.append("presentation fixture does not contain a provider presentation delta")
        terminal = presentation.get("terminalLf")
        if not isinstance(terminal, dict):
            failures.append("terminal LF fixture is missing")
        else:
            if canonicalize_markdown(terminal["withoutTerminalLf"]) != canonicalize_markdown(terminal["withOneTerminalLf"]):
                failures.append("one terminal LF presence is not normalized")
            if canonicalize_markdown(terminal["withTwoTerminalLfs"]) == canonicalize_markdown(terminal["withThreeTerminalLfs"]):
                failures.append("multiple terminal LFs were over-normalized")
            if not expected.get("terminalLfEquivalent") or not expected.get("multipleTerminalLfsSensitive"):
                failures.append("terminal LF fixture expected flags are incomplete")
            if canonicalize_markdown(terminal["finalHeadingWithoutTerminalLf"]) != canonicalize_markdown(terminal["finalHeadingWithOneTerminalLf"]):
                failures.append("final heading zero/one terminal LF presence is not normalized")
            if canonicalize_markdown(terminal["finalHeadingWithTwoTerminalLfs"]) == canonicalize_markdown(terminal["finalHeadingWithThreeTerminalLfs"]):
                failures.append("final heading multiple terminal LFs were over-normalized")
            if canonicalize_markdown(terminal["finalHeadingWithTwoTerminalLfs"]) == canonicalize_markdown(terminal["finalHeadingWithOneTerminalLf"]):
                failures.append("final heading multiple terminal LFs matched the one-LF form")
            if not expected.get("finalHeadingTerminalLfEquivalent") or not expected.get("finalHeadingMultipleTerminalLfsSensitive"):
                failures.append("final heading terminal LF fixture expected flags are incomplete")


build = flat(root / "skills/woostack-build/SKILL.md")
for pattern, message in (
    (r"always resolves the exact supplied project or creates exactly one project", "build project admission missing"),
    (r"exactly two content approvals", "two-approval build contract missing"),
    (r"candidate strict sequential direct-issue chain", "direct increment shape missing"),
):
    require("woostack-build", build, pattern, message)

fix = flat(root / "skills/woostack-fix/SKILL.md")
for pattern, message in (
    (r"Before root-cause proof, Fix makes no provider call", "pre-proof provider boundary missing"),
    (r"omitted, Fix creates exactly one project after root-cause proof", "plain-input project creation missing"),
    (r"exactly the two shared project-backed approval receipts", "shared Fix approvals missing"),
):
    require("woostack-fix", fix, pattern, message)
if re.search(r"fixApprovalRecord|approve-to-execute|bind exactly one issue", fix, re.I):
    failures.append("woostack-fix: retired one-issue approval contract remains")

plan = flat(root / "skills/woostack-plan/SKILL.md")
require("woostack-plan", plan, r"`--project` is mandatory", "exact-project selection boundary missing")
require("woostack-plan", plan, r"exactly one direct project issue for each execution increment", "direct-issue persistence missing")
require(
    "woostack-plan",
    plan,
    r"verification command.*repository-local script or path.*already exist.*predecessor increment.*same increment.*create",
    "planned verification existence check missing",
)

change = flat(root / "skills/woostack-change/SKILL.md")
require("woostack-change", change, r"(never reads or writes Linear|makes no Linear call)", "change is not Linear-free")

if failures:
    print("Linear authority contract violations:", file=sys.stderr)
    for failure in failures:
        print(f"  - {failure}", file=sys.stderr)
    raise SystemExit(1)

print("Linear authority contract: ok")
PY
