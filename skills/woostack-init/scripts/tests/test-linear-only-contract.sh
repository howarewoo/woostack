#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../../.." && pwd)"
export ROOT

python3 <<'PY'
import json
import os
import re
from pathlib import Path

root = Path(os.environ["ROOT"])
configs = [
    root / ".woostack/config.json",
    root / "skills/woostack-init/templates/config.json",
]
canonical_path = root / "skills/woostack-init/references/artifact-backends.md"
findings: list[str] = []

for path in configs:
    data = json.loads(path.read_text())
    if "artifacts" in data:
        findings.append(f"{path.relative_to(root)}: artifacts.specPlan/backend selector remains active")
    linear = data.get("linear")
    expected = {"repository", "workspace", "team", "projectStatuses", "issueStates"}
    if not isinstance(linear, dict) or set(linear) != expected:
        findings.append(f"{path.relative_to(root)}: linear policy keys must be exactly {sorted(expected)!r}")
        continue
    expected_project = {"backlog", "planned", "started", "paused", "completed", "canceled"}
    expected_issue = {"planned", "executing", "inReview", "done", "blocked"}
    if set(linear["projectStatuses"]) != expected_project:
        findings.append(f"{path.relative_to(root)}: projectStatuses keys are not canonical")
    if set(linear["issueStates"]) != expected_issue:
        findings.append(f"{path.relative_to(root)}: issueStates keys are not canonical")
    credential = re.compile(r"(?:api.?key|token|secret|password|authorization|credential)", re.I)
    for key in linear:
        if credential.search(key):
            findings.append(f"{path.relative_to(root)}: credential-like linear key {key!r}")


ACTIVE_FLAGS = re.I | re.S
active_patterns = (
    (re.compile(r"artifacts\.specPlan", ACTIVE_FLAGS), "backend selector"),
    (re.compile(r"resolve-backend\.sh", ACTIVE_FLAGS), "backend resolver"),
    (re.compile(r"\blinear\.sh\b", ACTIVE_FLAGS), "legacy Linear adapter"),
    (re.compile(r"\bWOOSTACK_LINEAR_ADAPTER\b", ACTIVE_FLAGS), "legacy Linear adapter override"),
    (re.compile(r"\bLINEAR_REQUEST_SH\b", ACTIVE_FLAGS), "custom Linear request override"),
    (re.compile(r"\bLINEAR_API_KEY\b", ACTIVE_FLAGS), "repository Linear credential"),
    (re.compile(r"api\.linear\.app/graphql", ACTIVE_FLAGS), "custom Linear GraphQL endpoint"),
    (re.compile(r"(?:\bLinear\b[^.!?]{0,80}\bGraphQL\b|\bGraphQL\b[^.!?]{0,80}\bLinear\b)", ACTIVE_FLAGS), "custom Linear GraphQL transport"),
    (re.compile(r"\b(?:Linear )?(?:specification )?document(?:-backed|\s+(?:owns|stores|is the source))", ACTIVE_FLAGS), "document-backed development state"),
    (re.compile(r"\bMarkdown\s+(?:is|remains|as)\s+(?:the\s+)?(?:default\s+)?(?:development\s+)?backend", ACTIVE_FLAGS), "Markdown development backend"),
    (re.compile(r"\blocal\s+(?:spec|plan|artifact)[^.;]*(?:authority|source of truth)", ACTIVE_FLAGS), "local development-record authority"),
)


def classify(relative: str, line: str, context: str) -> set[str]:
    line_offset = context.find(line)
    if line_offset < 0:
        context = line
        line_offset = 0
    def rejected(match: re.Match[str]) -> bool:
        if re.search(r"\b(?:is|are|was|were)\s+not\b", match.group(0), re.I):
            return True
        start = match.start()
        end = match.end()
        separators = list(re.finditer(r"\b(?:but|however|yet|while)\b", context, re.I))
        left = max(
            [context.rfind(mark, 0, start) for mark in ".;!?"]
            + [separator.end() - 1 for separator in separators if separator.end() <= start]
        )
        rights = [context.find(mark, end) for mark in ".;!?"]
        rights.extend(separator.start() for separator in separators if separator.start() >= end)
        right = min((position for position in rights if position >= 0), default=len(context) - 1)
        matched = re.escape(match.group(0))
        rejection = re.compile(
            rf"(?:"
            rf"\b(?:do\s+not|does\s+not|never|must\s+not|forbid(?:s|den)?|reject(?:s|ed)?)\b"
            rf".{{0,220}}{matched}|"
            rf"\bno\b.{{0,140}}{matched}|"
            rf"\b(?:remove[ds]?|removing|migrat(?:e|es|ed|ing|ion)|legacy|obsolete|"
            rf"decommission(?:ed|ing)?)\b.{{0,220}}{matched}|"
            rf"{matched}.{{0,220}}\b(?:remove[ds]?|removing|migrat(?:e|es|ed|ing|ion)|"
            rf"legacy|obsolete|forbidden|rejected)\b"
            rf")",
            re.I | re.S,
        )
        return bool(rejection.search(context[left + 1:right + 1]))

    labels: set[str] = set()
    for pattern, label in active_patterns:
        for match in pattern.finditer(context):
            if line_offset <= match.start() < line_offset + len(line) and not rejected(match):
                labels.add(label)

    linear_graphql_source = (
        relative.startswith("skills/woostack-init/scripts/artifacts/graphql/")
        or relative in {
            "skills/woostack-init/scripts/artifacts/linear.sh",
            "skills/woostack-init/scripts/artifacts/linear-request.sh",
        }
    )
    source_match = re.search(
        r"(?:\bGRAPHQL\b|\.graphql\b|--operation\s+(?:query|mutation)|"
        r"\b(?:query|mutation)\s+[A-Za-z_]|\brequest_(?:query|mutation)\b)",
        context,
        ACTIVE_FLAGS,
    )
    if (
        linear_graphql_source
        and source_match
        and line_offset <= source_match.start() < line_offset + len(line)
        and not rejected(source_match)
    ):
        labels.add("custom Linear GraphQL transport")
    return labels


# Deterministic classifier fixtures: active Linear transports fail; GitHub GraphQL and explicit
# rejection/migration prose remain legal.
self_fixtures = (
    ("skills/example/SKILL.md", "Invoke linear.sh feature-read for the selected project.", {"legacy Linear adapter"}),
    ("skills/example/SKILL.md", "POST to https://api.linear.app/graphql for project data.", {"custom Linear GraphQL endpoint"}),
    ("skills/example/SKILL.md", "Use Linear GraphQL mutations for project updates.", {"custom Linear GraphQL transport"}),
    ("skills/example/SKILL.md", "Use Linear\nGraphQL mutations for project updates.", {"custom Linear GraphQL transport"}),
    ("skills/example/SKILL.md", "Use GitHub GraphQL to resolve review threads.", set()),
    ("skills/example/SKILL.md", "Woostack never issues custom Linear GraphQL requests; GitHub GraphQL remains valid.", set()),
    ("skills/example/references/migration.md", "Migrate away from linear.sh; it is a legacy transport.", set()),
    ("skills/example/SKILL.md", "Use GitHub GraphQL for reviews and Linear GraphQL for projects.", {"custom Linear GraphQL transport"}),
    ("skills/example/SKILL.md", "Load LINEAR_API_KEY before starting work.", {"repository Linear credential"}),
    ("skills/example/SKILL.md", "Never use LINEAR_API_KEY. Invoke linear.sh feature-read.", {"legacy Linear adapter"}),
    ("skills/example/SKILL.md", "Never use LINEAR_API_KEY but invoke linear.sh feature-read.", {"legacy Linear adapter"}),
)
for fixture_path, fixture_line, expected_labels in self_fixtures:
    actual_labels = classify(fixture_path, fixture_line, fixture_line)
    if actual_labels != expected_labels:
        findings.append(
            "guard self-fixture mismatch: "
            f"{fixture_line!r}: expected {sorted(expected_labels)!r}, got {sorted(actual_labels)!r}"
        )


def active_surfaces() -> list[Path]:
    # Increment 1 pins the configuration/init/doctor authority boundary. Other workflow
    # migrations have their own contract tests and are removed in later increments.
    selected = [
        canonical_path,
        root / "skills/woostack-bootstrap/references/development.md",
        root / "skills/woostack-status/references/conventions.md",
        root / "skills/woostack-init/SKILL.md",
        root / "skills/woostack-init/references/memory.md",
        root / "skills/woostack-doctor/SKILL.md",
        root / "skills/woostack-doctor/references/checks.md",
        root / "skills/woostack-doctor/scripts/doctor.sh",
    ]
    checks = root / "skills/woostack-doctor/scripts/checks"
    selected.extend(path for path in checks.glob("*.sh") if path.is_file())
    return sorted(selected)


for path in active_surfaces():
    relative = path.relative_to(root).as_posix()
    lines = path.read_text(errors="replace").splitlines()
    for index, line in enumerate(lines):
        context = "\n".join(lines[max(0, index - 3):min(len(lines), index + 4)])
        for label in sorted(classify(relative, line, context)):
            findings.append(f"{relative}:{index + 1}: active {label}: {line.strip()}")


canonical = canonical_path.read_text()
required = [
    "official Linear MCP", "feature", "increment", "work-item",
    "designApproved", "executionApproved", "blockerResolved",
    "assignmentAccepted", "implementationEvidence", "reviewResult",
    "+++ Woostack metadata — managed, do not edit",
    "client-generated UUID", "projectStatuses", "issueStates",
    "Linear-Project: <project UUID>", "Linear-Issue: <TEAM-NUMBER>",
]
for value in required:
    if value not in canonical:
        findings.append(f"skills/woostack-init/references/artifact-backends.md: missing canonical contract value {value!r}")

if findings:
    print("Linear-only contract violations:")
    for finding in sorted(set(findings)):
        print(f"  {finding}")
    raise SystemExit(1)

print("Linear-only contract: PASS")
PY
